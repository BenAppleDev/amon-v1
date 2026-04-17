#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Any

from common import (
    Config,
    TaskSpec,
    discover_tasks,
    ensure_dir,
    git_env,
    load_config,
    parse_task,
    read_json,
    read_text,
    repo_rel,
    run,
    sanitize_branch_fragment,
    select_task,
    timestamp,
    write_json,
    write_text,
)
from codex_runner import run_codex


def git(repo_root: Path, args: list[str], *, check: bool = True, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=str(repo_root),
        text=True,
        capture_output=True,
        check=check,
        env=env,
    )


def current_branch(repo_root: Path) -> str:
    proc = git(repo_root, ["rev-parse", "--abbrev-ref", "HEAD"])
    return proc.stdout.strip()


def worktree_branch_name(task: TaskSpec, strategy_name: str, generation: int, run_tag: str) -> str:
    return f"cand/{task.task_id}-{run_tag}-g{generation}-{sanitize_branch_fragment(strategy_name)}"


def worktree_dir(config: Config, task: TaskSpec, strategy_name: str, generation: int, run_tag: str) -> Path:
    return config.worktrees_path / f"{task.task_id}-{run_tag}-g{generation}-{sanitize_branch_fragment(strategy_name)}"


def create_or_reset_worktree(config: Config, task: TaskSpec, strategy_name: str, generation: int, run_tag: str, base_ref: str) -> tuple[Path, str]:
    path = worktree_dir(config, task, strategy_name, generation, run_tag)
    branch = worktree_branch_name(task, strategy_name, generation, run_tag)

    if path.exists():
        run(["git", "worktree", "remove", "--force", str(path)], cwd=config.repo_root, check=False)

    git(config.repo_root, ["branch", "-D", branch], check=False)
    proc = run(
        ["git", "worktree", "add", "-b", branch, str(path), base_ref],
        cwd=config.repo_root,
        env=git_env(config),
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            "Failed to create candidate worktree.\n"
            f"branch={branch}\n"
            f"path={path}\n"
            f"base_ref={base_ref}\n\n"
            f"stdout:\n{proc.stdout}\n\n"
            f"stderr:\n{proc.stderr}"
        )
    return path, branch


def cleanup_worktree(config: Config, path: Path, branch: str) -> None:
    run(["git", "worktree", "remove", "--force", str(path)], cwd=config.repo_root, check=False)
    git(config.repo_root, ["branch", "-D", branch], check=False)


def git_has_changes(repo_root: Path) -> bool:
    proc = git(repo_root, ["status", "--porcelain"], check=True)
    return bool(proc.stdout.strip())


def git_head(repo_root: Path) -> str:
    proc = git(repo_root, ["rev-parse", "HEAD"], check=True)
    return proc.stdout.strip()


def auto_commit(config: Config, repo_root: Path, message: str) -> str | None:
    if not git_has_changes(repo_root):
        return None
    env = git_env(config)
    run(["git", "add", "-A"], cwd=repo_root, env=env, check=True)
    run(["git", "commit", "-m", message], cwd=repo_root, env=env, check=True)
    return git_head(repo_root)


def read_log_excerpt(path: Path, *, limit: int = 4000) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")[-limit:].strip()


def build_prompt(
    *,
    config: Config,
    task: TaskSpec,
    strategy_prompt: str,
    previous_feedback: str | None,
    run_context: dict[str, Any],
) -> str:
    base_prompt = read_text(config.repo_root / config.base_prompt_file)
    lines = [
        base_prompt.strip(),
        "",
        task.render_prompt_block().strip(),
        "",
        strategy_prompt.strip(),
        "",
        "## Run context",
        f"- run_id: {run_context['run_id']}",
        f"- generation: {run_context['generation']}",
        f"- candidate_strategy: {run_context['strategy']}",
        "",
    ]
    if previous_feedback:
        lines.extend(["## Previous execution feedback", previous_feedback.strip(), ""])
    lines.extend(
        [
            "## Execution requirements",
            "- Make the code changes directly in the current worktree.",
            "- Run the most relevant checks for the changed surface before finishing.",
            "- If behavior changes, update or add tests where feasible.",
            "- If public docs should change, update them or explain why not.",
            "- End with the required `## Summary` block.",
            "",
        ]
    )
    return "\n".join(lines)


def summarize_feedback(reports: list[dict[str, Any]]) -> str:
    if not reports:
        return ""
    lines = []
    for report in sorted(reports, key=lambda r: r["metrics"]["total_score"], reverse=True)[:2]:
        lines.append(f"### Candidate {report['candidate_id']}")
        lines.append(f"- total_score: {report['metrics']['total_score']}")
        lines.append(f"- hard_gate_passed: {report['hard_gate_passed']}")
        failed = report["artifacts"].get("failed_checks", [])
        if failed:
            lines.append(f"- failed_checks: {', '.join(failed)}")
        violations = report["architecture"].get("violations", [])
        if violations:
            lines.append(f"- path_violations: {', '.join(violations[:10])}")
        stderr = report["artifacts"].get("stderr", "").strip()
        if stderr:
            lines.append("- stderr_excerpt:")
            lines.append("```text")
            lines.append(stderr[:1500])
            lines.append("```")
        lines.append("")
    return "\n".join(lines).strip()


def evaluate_candidate(config: Config, task: TaskSpec, worktree: Path, candidate_run_dir: Path, candidate_id: str) -> dict[str, Any]:
    report_path = candidate_run_dir / "evaluation-report.json"
    cmd = [
        sys.executable,
        "evals/evaluate_candidate.py",
        "--config",
        str(config.repo_root / "automation/config.toml"),
        "--task",
        str(task.path),
        "--worktree",
        str(worktree),
        "--run-dir",
        str(candidate_run_dir / "eval"),
        "--output",
        str(report_path),
        "--candidate-id",
        candidate_id,
    ]
    proc = run(cmd, cwd=config.repo_root, check=False)
    if proc.returncode not in {0, 1}:
        raise RuntimeError(f"Evaluator failed unexpectedly:\n{proc.stderr}")
    report = read_json(report_path)
    return report


def rank_candidates(candidates: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        candidates,
        key=lambda item: (
            item["evaluation"]["hard_gate_passed"],
            item["evaluation"]["metrics"]["total_score"],
        ),
        reverse=True,
    )


def promote_if_enabled(config: Config, scoreboard_path: Path) -> None:
    if not config.auto_promote:
        return
    run(
        [
            sys.executable,
            "automation/promote_winner.py",
            "--config",
            str(config.repo_root / "automation/config.toml"),
            "--scoreboard",
            str(scoreboard_path),
        ],
        cwd=config.repo_root,
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run an OpenEvolve-style Codex candidate loop in this repository.")
    parser.add_argument("--config", default="automation/config.toml")
    parser.add_argument("--task-id", default=None, help="Explicit task id from tasks/*.task.md")
    parser.add_argument("--generations", type=int, default=None, help="Override configured generation count")
    parser.add_argument("--candidate-count", type=int, default=None, help="Override configured candidate count")
    parser.add_argument("--base-ref", default=None, help="Override the task's base_ref")
    args = parser.parse_args()

    config = load_config(Path(args.config))
    ensure_dir(config.worktrees_path)
    ensure_dir(config.runs_path)

    tasks = discover_tasks(config.repo_root / "tasks")
    task = select_task(tasks, explicit_task_id=args.task_id)

    generation_count = args.generations or task.generation_budget or config.generations
    candidate_count = args.candidate_count or task.candidate_count or config.candidate_count

    if candidate_count > len(config.candidate_strategies):
        raise ValueError(
            f"Requested {candidate_count} candidates but only {len(config.candidate_strategies)} strategies are configured."
        )

    base_ref = args.base_ref or task.base_ref or config.default_base_ref
    run_stamp = timestamp()
    run_id = f"{task.task_id}-{run_stamp}"
    run_root = config.runs_path / run_id
    ensure_dir(run_root)
    ensure_dir(run_root / "generations")

    previous_reports: list[dict[str, Any]] = []
    winner_branch = base_ref

    for generation in range(1, generation_count + 1):
        generation_dir = run_root / "generations" / f"g{generation}"
        ensure_dir(generation_dir)

        strategies = config.candidate_strategies[:candidate_count]
        candidate_results: list[dict[str, Any]] = []
        previous_feedback = summarize_feedback(previous_reports)

        for strategy in strategies:
            candidate_id = f"{task.task_id}-g{generation}-{strategy.name}"
            candidate_dir = generation_dir / sanitize_branch_fragment(strategy.name)
            ensure_dir(candidate_dir)

            worktree, branch = create_or_reset_worktree(config, task, strategy.name, generation, run_stamp, winner_branch)
            strategy_prompt = read_text(config.repo_root / strategy.prompt_file)
            prompt = build_prompt(
                config=config,
                task=task,
                strategy_prompt=strategy_prompt,
                previous_feedback=previous_feedback,
                run_context={
                    "run_id": run_id,
                    "generation": generation,
                    "strategy": strategy.name,
                },
            )

            codex_dir = candidate_dir / "codex"
            codex_result = run_codex(
                config=config,
                worktree=worktree,
                run_dir=codex_dir,
                prompt_text=prompt,
            )

            had_changes_after_codex = git_has_changes(worktree)
            commit_sha = None
            commit_message = f"candidate: {task.task_id} g{generation} {strategy.name}"
            if config.auto_commit and codex_result.returncode == 0:
                commit_sha = auto_commit(config, worktree, commit_message)

            evaluation = evaluate_candidate(config, task, worktree, candidate_dir, candidate_id)
            evaluator_hard_gate_passed = bool(evaluation["hard_gate_passed"])
            codex_stderr_excerpt = read_log_excerpt(codex_result.stderr_path)
            codex_stdout_excerpt = read_log_excerpt(codex_result.stdout_path)
            hard_gate_failures: list[str] = []
            if not evaluator_hard_gate_passed:
                hard_gate_failures.append("required-checks-or-architecture")
            if codex_result.returncode != 0:
                hard_gate_failures.append("codex-exec")
            if not had_changes_after_codex:
                hard_gate_failures.append("no-worktree-changes")
            if commit_sha is None:
                hard_gate_failures.append("missing-commit")

            if codex_result.returncode != 0 and "codex-exec" not in evaluation["artifacts"]["failed_checks"]:
                evaluation["artifacts"]["failed_checks"].append("codex-exec")
            if not had_changes_after_codex and "no-worktree-changes" not in evaluation["artifacts"]["failed_checks"]:
                evaluation["artifacts"]["failed_checks"].append("no-worktree-changes")
            if commit_sha is None and "missing-commit" not in evaluation["artifacts"]["failed_checks"]:
                evaluation["artifacts"]["failed_checks"].append("missing-commit")
            if codex_stderr_excerpt:
                prefix = "## codex\n" + codex_stderr_excerpt
                current = evaluation["artifacts"].get("stderr", "").strip()
                evaluation["artifacts"]["stderr"] = f"{current}\n\n{prefix}".strip() if current else prefix

            evaluation["execution"] = {
                "codex_command": codex_result.command,
                "codex_returncode": codex_result.returncode,
                "codex_stdout_path": str(repo_rel(codex_result.stdout_path, config.repo_root)),
                "codex_stderr_path": str(repo_rel(codex_result.stderr_path, config.repo_root)),
                "codex_final_message_path": str(repo_rel(codex_result.final_message_path, config.repo_root)),
                "codex_final_message_exists": codex_result.final_message_path.exists(),
                "codex_stdout_excerpt": codex_stdout_excerpt,
                "codex_stderr_excerpt": codex_stderr_excerpt,
                "had_changes_after_codex": had_changes_after_codex,
                "commit_sha": commit_sha,
                "evaluator_hard_gate_passed": evaluator_hard_gate_passed,
                "hard_gate_failures": hard_gate_failures,
            }
            evaluation["branch"] = branch
            evaluation["worktree"] = str(repo_rel(worktree, config.repo_root))
            evaluation["commit_sha"] = commit_sha
            evaluation["hard_gate_passed"] = not hard_gate_failures

            candidate_results.append(
                {
                    "candidate_id": candidate_id,
                    "strategy": strategy.name,
                    "branch": branch,
                    "worktree": str(worktree),
                    "commit_sha": commit_sha,
                    "codex": {
                        "returncode": codex_result.returncode,
                        "prompt_path": str(repo_rel(codex_result.prompt_path, config.repo_root)),
                        "stdout_path": str(repo_rel(codex_result.stdout_path, config.repo_root)),
                        "stderr_path": str(repo_rel(codex_result.stderr_path, config.repo_root)),
                        "final_message_path": str(repo_rel(codex_result.final_message_path, config.repo_root)),
                        "command": codex_result.command,
                    },
                    "evaluation": evaluation,
                }
            )

            write_json(candidate_dir / "candidate-result.json", candidate_results[-1])

            if config.cleanup_failed_worktrees and not evaluation["hard_gate_passed"]:
                cleanup_worktree(config, worktree, branch)

        ranked = rank_candidates(candidate_results)
        winner = ranked[0]
        winner_branch = winner["branch"]
        previous_reports = [item["evaluation"] for item in ranked]

        scoreboard = {
            "run_id": run_id,
            "task": {
                "task_id": task.task_id,
                "title": task.title,
                "lane": task.lane,
                "task_path": str(repo_rel(task.path, config.repo_root)),
            },
            "generation": generation,
            "winner": {
                "candidate_id": winner["candidate_id"],
                "branch": winner["branch"],
                "commit_sha": winner["commit_sha"],
                "worktree": repo_rel(Path(winner["worktree"]), config.repo_root),
                "total_score": winner["evaluation"]["metrics"]["total_score"],
                "hard_gate_passed": winner["evaluation"]["hard_gate_passed"],
            },
            "ranked_candidates": [
                {
                    "candidate_id": item["candidate_id"],
                    "strategy": item["strategy"],
                    "branch": item["branch"],
                    "commit_sha": item["commit_sha"],
                    "total_score": item["evaluation"]["metrics"]["total_score"],
                    "hard_gate_passed": item["evaluation"]["hard_gate_passed"],
                    "failed_checks": item["evaluation"]["artifacts"]["failed_checks"],
                    "path_violations": item["evaluation"]["architecture"]["violations"],
                }
                for item in ranked
            ],
        }
        scoreboard_path = generation_dir / "scoreboard.json"
        write_json(scoreboard_path, scoreboard)

        summary_lines = [
            f"# Generation {generation} summary",
            "",
            f"- run_id: {run_id}",
            f"- task: {task.task_id} — {task.title}",
            f"- winner: {winner['candidate_id']}",
            f"- winner branch: {winner['branch']}",
            f"- winner score: {winner['evaluation']['metrics']['total_score']}",
            f"- hard gate passed: {winner['evaluation']['hard_gate_passed']}",
            "",
            "## Ranked candidates",
        ]
        for item in ranked:
            summary_lines.extend(
                [
                    f"### {item['candidate_id']}",
                    f"- branch: {item['branch']}",
                    f"- score: {item['evaluation']['metrics']['total_score']}",
                    f"- hard_gate_passed: {item['evaluation']['hard_gate_passed']}",
                    f"- codex_returncode: {item['evaluation']['execution']['codex_returncode']}",
                    f"- commit_sha: {item['commit_sha'] or 'null'}",
                ]
            )
            failed = item["evaluation"]["artifacts"]["failed_checks"]
            if failed:
                summary_lines.append(f"- failed_checks: {', '.join(failed)}")
            failures = item["evaluation"]["execution"].get("hard_gate_failures", [])
            if failures:
                summary_lines.append(f"- hard_gate_failures: {', '.join(failures)}")
            violations = item["evaluation"]["architecture"]["violations"]
            if violations:
                summary_lines.append(f"- path_violations: {', '.join(violations[:10])}")
            summary_lines.append("")
        write_text(generation_dir / "SUMMARY.md", "\n".join(summary_lines))

    final_scoreboard = scoreboard_path
    promote_if_enabled(config, final_scoreboard)

    print(f"Run complete: {run_id}")
    print(f"Final scoreboard: {final_scoreboard}")
    print(f"Winner branch: {winner_branch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
