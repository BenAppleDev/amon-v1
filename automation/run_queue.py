#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import traceback
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from common import (
    ensure_dir,
    discover_tasks,
    load_config,
    parse_task,
    read_json,
    read_text,
    repo_rel,
    run,
    timestamp,
    write_json,
    write_text,
)

FRONTMATTER_RE = re.compile(r"^\+\+\+\s*\n(.*?)\n\+\+\+\s*\n(.*)$", re.DOTALL)
SCOREBOARD_RE = re.compile(r"^Final scoreboard:\s*(.+)$", re.MULTILINE)
RUN_ID_RE = re.compile(r"^Run complete:\s*(.+)$", re.MULTILINE)
VALID_QUEUE_STATUSES = {"ready", "queued", "todo"}


@dataclass
class QueueTaskResult:
    task_id: str
    task_path: str
    status_before: str
    final_status: str
    orchestrator_returncode: int
    run_id: str | None
    scoreboard_path: str | None
    promoted: bool
    winner_branch: str | None
    winner_commit_sha: str | None
    hard_gate_passed: bool | None
    total_score: float | None
    error: str | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run all selected repo tasks sequentially with the existing orchestrator, "
            "auto-promote winners if requested, and persist a queue-level audit trail."
        )
    )
    parser.add_argument("--config", default="automation/config.toml")
    parser.add_argument(
        "--task-ids",
        nargs="*",
        default=None,
        help="Explicit ordered task ids to run. Defaults to all ready/queued/todo tasks.",
    )
    parser.add_argument(
        "--statuses",
        nargs="*",
        default=["ready"],
        help="Task statuses eligible for queue selection when --task-ids is omitted. Default: ready",
    )
    parser.add_argument("--lane", default=None, help="Optional lane filter: backend, ios, website, ops")
    parser.add_argument("--max-tasks", type=int, default=None, help="Optional cap on number of queued tasks")
    parser.add_argument("--generations", type=int, default=None, help="Override per-task generation count")
    parser.add_argument("--candidate-count", type=int, default=None, help="Override per-task candidate count")
    parser.add_argument("--base-ref", default=None, help="Override per-task base_ref")
    parser.add_argument(
        "--continue-on-failure",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Continue running later tasks if a task fails. Default: true",
    )
    parser.add_argument(
        "--promote",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Promote successful winners to integration/<task-id>. Default: true",
    )
    parser.add_argument(
        "--mark-status",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Update task frontmatter status as the queue progresses. Default: true",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Only list the tasks that would run, then exit.",
    )
    return parser.parse_args()


def update_frontmatter_string(path: Path, key: str, value: str) -> None:
    text = read_text(path)
    match = FRONTMATTER_RE.match(text)
    if not match:
        raise ValueError(f"Task file is missing TOML frontmatter: {path}")
    frontmatter, body = match.groups()
    escaped = value.replace('"', '\\"')
    key_re = re.compile(rf'(?m)^(\s*{re.escape(key)}\s*=\s*)".*?"\s*$')
    replacement = rf'\1"{escaped}"'
    if key_re.search(frontmatter):
        frontmatter = key_re.sub(replacement, frontmatter, count=1)
    else:
        frontmatter = frontmatter.rstrip() + f'\n{key} = "{escaped}"\n'
    write_text(path, f"+++\n{frontmatter}\n+++\n{body}")


def selected_tasks(all_tasks: list[Any], *, task_ids: list[str] | None, statuses: list[str], lane: str | None) -> list[Any]:
    tasks = [task for task in all_tasks if "examples" not in task.path.parts]
    if task_ids:
        lookup = {task.task_id: task for task in tasks}
        missing = [task_id for task_id in task_ids if task_id not in lookup]
        if missing:
            raise ValueError(f"Could not find task ids: {', '.join(missing)}")
        ordered = [lookup[task_id] for task_id in task_ids]
    else:
        status_set = {status.lower() for status in statuses}
        unknown = status_set - VALID_QUEUE_STATUSES
        if unknown:
            raise ValueError(
                f"Unsupported queue selection status values: {', '.join(sorted(unknown))}. "
                f"Allowed: {', '.join(sorted(VALID_QUEUE_STATUSES))}"
            )
        ordered = [task for task in tasks if task.status.lower() in status_set]
        ordered = sorted(ordered, key=lambda task: (task.priority, task.task_id))
    if lane:
        ordered = [task for task in ordered if task.lane == lane]
    return ordered


def resolve_output_path(repo_root: Path, raw_path: str) -> Path:
    path = Path(raw_path.strip())
    if path.is_absolute():
        return path
    return repo_root / path


def parse_orchestrator_stdout(stdout_text: str, repo_root: Path) -> tuple[str | None, Path | None]:
    run_id_match = RUN_ID_RE.search(stdout_text)
    scoreboard_match = SCOREBOARD_RE.search(stdout_text)
    run_id = run_id_match.group(1).strip() if run_id_match else None
    scoreboard_path = resolve_output_path(repo_root, scoreboard_match.group(1)) if scoreboard_match else None
    return run_id, scoreboard_path


def queue_summary_markdown(queue_id: str, results: list[QueueTaskResult]) -> str:
    implemented = sum(1 for item in results if item.final_status == "implemented")
    failed = sum(1 for item in results if item.final_status == "failed")
    skipped = sum(1 for item in results if item.final_status == "skipped")
    lines = [
        f"# Queue summary: {queue_id}",
        "",
        f"- implemented: {implemented}",
        f"- failed: {failed}",
        f"- skipped: {skipped}",
        f"- total: {len(results)}",
        "",
        "## Task results",
    ]
    for item in results:
        lines.extend(
            [
                f"### {item.task_id}",
                f"- task_path: {item.task_path}",
                f"- status_before: {item.status_before}",
                f"- final_status: {item.final_status}",
                f"- orchestrator_returncode: {item.orchestrator_returncode}",
            ]
        )
        if item.run_id:
            lines.append(f"- run_id: {item.run_id}")
        if item.scoreboard_path:
            lines.append(f"- scoreboard_path: {item.scoreboard_path}")
        if item.winner_branch:
            lines.append(f"- winner_branch: {item.winner_branch}")
        if item.winner_commit_sha:
            lines.append(f"- winner_commit_sha: {item.winner_commit_sha}")
        if item.total_score is not None:
            lines.append(f"- total_score: {item.total_score}")
        if item.hard_gate_passed is not None:
            lines.append(f"- hard_gate_passed: {item.hard_gate_passed}")
        lines.append(f"- promoted: {item.promoted}")
        if item.error:
            lines.append("- error:")
            lines.append("```text")
            lines.append(item.error.strip())
            lines.append("```")
        lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    config = load_config(Path(args.config))

    queue_id = f"queue-{timestamp()}"
    queue_root = config.repo_root / "logs" / "queues" / queue_id
    ensure_dir(queue_root)
    ensure_dir(queue_root / "tasks")

    tasks = discover_tasks(config.repo_root / "tasks")
    queue_tasks = selected_tasks(tasks, task_ids=args.task_ids, statuses=args.statuses, lane=args.lane)
    if args.max_tasks is not None:
        queue_tasks = queue_tasks[: args.max_tasks]

    if not queue_tasks:
        print("No tasks matched the queue selection criteria.", file=sys.stderr)
        return 1

    manifest = {
        "queue_id": queue_id,
        "repo_root": str(config.repo_root),
        "selected_task_ids": [task.task_id for task in queue_tasks],
        "task_paths": [str(repo_rel(task.path, config.repo_root)) for task in queue_tasks],
        "promote": args.promote,
        "mark_status": args.mark_status,
        "continue_on_failure": args.continue_on_failure,
        "overrides": {
            "generations": args.generations,
            "candidate_count": args.candidate_count,
            "base_ref": args.base_ref,
            "lane": args.lane,
            "statuses": args.statuses,
            "max_tasks": args.max_tasks,
        },
    }
    write_json(queue_root / "manifest.json", manifest)

    if args.list:
        print(f"Queue preview: {queue_id}")
        for task in queue_tasks:
            print(f"- {task.task_id} [{task.status}] lane={task.lane} path={repo_rel(task.path, config.repo_root)}")
        print(f"Manifest: {queue_root / 'manifest.json'}")
        return 0

    results: list[QueueTaskResult] = []

    for task in queue_tasks:
        task_dir = queue_root / "tasks" / task.task_id
        ensure_dir(task_dir)
        task_stdout = task_dir / "orchestrator.stdout.log"
        task_stderr = task_dir / "orchestrator.stderr.log"
        task_status_before = task.status
        task_error: str | None = None
        promoted = False
        orchestrator_returncode = 0
        run_id: str | None = None
        scoreboard_path: Path | None = None
        winner_branch: str | None = None
        winner_commit_sha: str | None = None
        hard_gate_passed: bool | None = None
        total_score: float | None = None
        final_status = "skipped"

        if args.mark_status:
            update_frontmatter_string(task.path, "status", "running")

        try:
            cmd = [sys.executable, "automation/orchestrator.py", "--config", str(Path(args.config))]
            cmd.extend(["--task-id", task.task_id])
            if args.generations is not None:
                cmd.extend(["--generations", str(args.generations)])
            if args.candidate_count is not None:
                cmd.extend(["--candidate-count", str(args.candidate_count)])
            if args.base_ref is not None:
                cmd.extend(["--base-ref", args.base_ref])

            proc = run(cmd, cwd=config.repo_root, stdout_path=task_stdout, stderr_path=task_stderr, check=False)
            orchestrator_returncode = proc.returncode
            stdout_text = task_stdout.read_text(encoding="utf-8") if task_stdout.exists() else ""
            stderr_text = task_stderr.read_text(encoding="utf-8") if task_stderr.exists() else ""

            run_id, scoreboard_path = parse_orchestrator_stdout(stdout_text, config.repo_root)

            if orchestrator_returncode != 0:
                final_status = "failed"
                task_error = (
                    f"orchestrator exited with code {orchestrator_returncode}\n\n"
                    f"stdout:\n{stdout_text[-4000:]}\n\n"
                    f"stderr:\n{stderr_text[-4000:]}"
                )
            elif scoreboard_path is None or not scoreboard_path.exists():
                final_status = "failed"
                task_error = (
                    "orchestrator completed but no readable scoreboard was found\n\n"
                    f"stdout:\n{stdout_text[-4000:]}\n\n"
                    f"stderr:\n{stderr_text[-4000:]}"
                )
            else:
                scoreboard = read_json(scoreboard_path)
                winner = scoreboard.get("winner", {})
                winner_branch = winner.get("branch")
                winner_commit_sha = winner.get("commit_sha")
                hard_gate_passed = bool(winner.get("hard_gate_passed"))
                total_score = float(winner.get("total_score", 0))
                if hard_gate_passed:
                    final_status = "implemented"
                    if args.promote:
                        promote_stdout = task_dir / "promote.stdout.log"
                        promote_stderr = task_dir / "promote.stderr.log"
                        promote_proc = run(
                            [
                                sys.executable,
                                "automation/promote_winner.py",
                                "--config",
                                str(Path(args.config)),
                                "--scoreboard",
                                str(scoreboard_path),
                            ],
                            cwd=config.repo_root,
                            stdout_path=promote_stdout,
                            stderr_path=promote_stderr,
                            check=False,
                        )
                        promoted = promote_proc.returncode == 0
                        if not promoted:
                            final_status = "failed"
                            task_error = (
                                "promotion failed\n\n"
                                f"stdout:\n{promote_stdout.read_text(encoding='utf-8') if promote_stdout.exists() else ''}\n\n"
                                f"stderr:\n{promote_stderr.read_text(encoding='utf-8') if promote_stderr.exists() else ''}"
                            )
                else:
                    final_status = "failed"
                    task_error = "winner did not pass the hard gate"

        except Exception as exc:  # pragma: no cover - defensive wrapper
            orchestrator_returncode = orchestrator_returncode or 1
            final_status = "failed"
            task_error = f"{exc}\n\n{traceback.format_exc()}"

        if args.mark_status:
            update_frontmatter_string(task.path, "status", final_status)

        result = QueueTaskResult(
            task_id=task.task_id,
            task_path=str(repo_rel(task.path, config.repo_root)),
            status_before=task_status_before,
            final_status=final_status,
            orchestrator_returncode=orchestrator_returncode,
            run_id=run_id,
            scoreboard_path=str(repo_rel(scoreboard_path, config.repo_root)) if scoreboard_path else None,
            promoted=promoted,
            winner_branch=winner_branch,
            winner_commit_sha=winner_commit_sha,
            hard_gate_passed=hard_gate_passed,
            total_score=total_score,
            error=task_error,
        )
        results.append(result)
        write_json(task_dir / "queue-task-result.json", result.__dict__)

        if final_status == "failed" and not args.continue_on_failure:
            break

    queue_summary = queue_summary_markdown(queue_id, results)
    write_text(queue_root / "SUMMARY.md", queue_summary)
    write_json(queue_root / "queue-results.json", [item.__dict__ for item in results])

    print(f"Queue complete: {queue_id}")
    print(f"Summary: {queue_root / 'SUMMARY.md'}")
    print(f"Results: {queue_root / 'queue-results.json'}")

    failed = [item for item in results if item.final_status == "failed"]
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
