#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time
from typing import Any

sys.path.append(str((Path(__file__).resolve().parents[1] / "automation").resolve()))
from common import (  # noqa: E402
    load_config,
    parse_task,
    repo_rel,
    run,
    write_json,
)


def git_output(repo_root: Path, args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=str(repo_root),
        text=True,
        capture_output=True,
        check=True,
    )
    return proc.stdout


def changed_files(repo_root: Path, base_ref: str) -> list[str]:
    names: list[str] = []
    for args in (["diff", "--name-only", f"{base_ref}...HEAD"], ["diff", "--name-only"]):
        out = git_output(repo_root, args)
        names.extend(line.strip() for line in out.splitlines() if line.strip())
    return sorted(set(names))


def diff_stats(repo_root: Path, base_ref: str, generated: list[str]) -> dict[str, Any]:
    per_file: dict[str, dict[str, int]] = {}
    for args in (["diff", "--numstat", f"{base_ref}...HEAD"], ["diff", "--numstat"]):
        out = git_output(repo_root, args)
        for line in out.splitlines():
            parts = line.split("\t")
            if len(parts) != 3:
                continue
            ins, dele, file_path = parts
            if is_generated(file_path, generated):
                continue
            try:
                ins_i = int(ins)
                dele_i = int(dele)
            except ValueError:
                continue
            current = per_file.setdefault(file_path, {"insertions": 0, "deletions": 0})
            current["insertions"] += ins_i
            current["deletions"] += dele_i
    insertions = sum(item["insertions"] for item in per_file.values())
    deletions = sum(item["deletions"] for item in per_file.values())
    files = sorted(per_file.keys())
    return {
        "insertions": insertions,
        "deletions": deletions,
        "total_line_changes": insertions + deletions,
        "files_changed": files,
        "file_count": len(files),
    }


def normalize(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def is_generated(path: str, generated: list[str]) -> bool:
    normalized = normalize(path)
    for prefix in generated:
        p = normalize(prefix)
        if normalized == p or normalized.startswith(p.rstrip("/") + "/"):
            return True
    return False


def is_allowed(path: str, allowed: list[str]) -> bool:
    normalized = normalize(path)
    for prefix in allowed:
        p = normalize(prefix)
        if normalized == p or normalized.startswith(p.rstrip("/") + "/"):
            return True
    return False


def detect_docs_sync(changed: list[str]) -> tuple[float, list[str]]:
    docs_like = [
        path for path in changed
        if path.startswith("docs/")
        or path in {"README.md", "VISION.md", "ROADMAP.md", "ARCHITECTURE.md", "QUALITY_GATES.md"}
    ]
    public_surface_like = [
        path for path in changed
        if path.startswith("shared/openapi/")
        or path.startswith("backend/app/routers/")
        or path.startswith("website/src/")
        or path.startswith("ios/AmonKit/Sources/")
    ]
    notes = []
    if not public_surface_like:
        return 1.0, notes
    if docs_like:
        notes.append("Public-surface changes include docs updates.")
        return 1.0, notes
    notes.append("Public-surface-like changes detected without docs updates.")
    return 0.5, notes


def minimality_score(file_count: int, total_line_changes: int) -> float:
    file_factor = max(0.0, 1.0 - max(0, file_count - 8) / 24.0)
    line_factor = max(0.0, 1.0 - max(0, total_line_changes - 300) / 1700.0)
    return round((file_factor * 0.6 + line_factor * 0.4), 3)


def run_checks(commands: list[str], command_cwd: Path, report_root: Path, run_dir: Path, required: bool, timeout_seconds: int) -> list[dict[str, Any]]:
    reports = []
    for idx, command in enumerate(commands, start=1):
        name = f'{"required" if required else "optional"}-{idx}'
        stdout_path = run_dir / f"{name}.stdout.log"
        stderr_path = run_dir / f"{name}.stderr.log"
        start = time.time()

        executable = shlex.split(command)[0]
        if shutil.which(executable) is None:
            reports.append(
                {
                    "name": name,
                    "command": command,
                    "required": required,
                    "status": "fail" if required else "skip",
                    "duration_seconds": 0.0,
                    "stdout_path": str(repo_rel(stdout_path, report_root)),
                    "stderr_path": str(repo_rel(stderr_path, report_root)),
                    "reason": f"Executable not found on PATH: {executable}",
                }
            )
            stdout_path.write_text("", encoding="utf-8")
            stderr_path.write_text(f"Executable not found on PATH: {executable}\n", encoding="utf-8")
            continue

        try:
            proc = run(
                command,
                cwd=command_cwd,
                stdout_path=stdout_path,
                stderr_path=stderr_path,
                timeout=timeout_seconds,
                check=False,
            )
            status = "pass" if proc.returncode == 0 else "fail"
            reports.append(
                {
                    "name": name,
                    "command": command,
                    "required": required,
                    "status": status,
                    "duration_seconds": round(time.time() - start, 2),
                    "stdout_path": str(repo_rel(stdout_path, report_root)),
                    "stderr_path": str(repo_rel(stderr_path, report_root)),
                    "returncode": proc.returncode,
                }
            )
        except subprocess.TimeoutExpired:
            stderr_path.write_text("Timed out.\n", encoding="utf-8")
            reports.append(
                {
                    "name": name,
                    "command": command,
                    "required": required,
                    "status": "fail" if required else "skip",
                    "duration_seconds": round(time.time() - start, 2),
                    "stdout_path": str(repo_rel(stdout_path, report_root)),
                    "stderr_path": str(repo_rel(stderr_path, report_root)),
                    "reason": "Timed out",
                }
            )
    return reports


class SafeFormatDict(dict[str, str]):
    def __missing__(self, key: str) -> str:
        return "{" + key + "}"


def quoted(value: str) -> str:
    return shlex.quote(value)


def format_commands(
    commands: list[str],
    *,
    repo_root: Path,
    worktree: Path,
    run_dir: Path,
    checks_dir: Path,
    task: Any,
    candidate_id: str,
) -> list[str]:
    values = SafeFormatDict(
        repo_root=str(repo_root),
        repo_root_q=quoted(str(repo_root)),
        worktree=str(worktree),
        worktree_q=quoted(str(worktree)),
        run_dir=str(run_dir),
        run_dir_q=quoted(str(run_dir)),
        checks_dir=str(checks_dir),
        checks_dir_q=quoted(str(checks_dir)),
        task_id=task.task_id,
        task_id_q=quoted(task.task_id),
        lane=task.lane,
        lane_q=quoted(task.lane),
        candidate_id=candidate_id,
        candidate_id_q=quoted(candidate_id),
    )
    return [command.format_map(values) for command in commands]


def score_report(
    *,
    hard_gate_passed: bool,
    required_pass_ratio: float,
    optional_pass_ratio: float,
    architecture_score: float,
    docs_score: float,
    minimality: float,
    performance_score: float,
    weights: dict[str, float],
) -> dict[str, float]:
    correctness = required_pass_ratio
    quality_gates = (required_pass_ratio * 0.7) + (optional_pass_ratio * 0.3)
    total_weight = sum(weights.values()) or 1.0
    weighted_total = (
        weights.get("correctness", 0.0) * correctness
        + weights.get("quality_gates", 0.0) * quality_gates
        + weights.get("architecture", 0.0) * architecture_score
        + weights.get("docs_sync", 0.0) * docs_score
        + weights.get("minimality", 0.0) * minimality
        + weights.get("performance", 0.0) * performance_score
    ) / total_weight
    if not hard_gate_passed:
        weighted_total *= 0.5
    return {
        "correctness": round(correctness, 3),
        "quality_gates": round(quality_gates, 3),
        "architecture": round(architecture_score, 3),
        "docs_sync": round(docs_score, 3),
        "minimality": round(minimality, 3),
        "performance": round(performance_score, 3),
        "total_score": round(weighted_total * 100.0, 2),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate a candidate worktree against task and repo quality gates.")
    parser.add_argument("--config", default="automation/config.toml")
    parser.add_argument("--task", required=True)
    parser.add_argument("--worktree", required=True)
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--candidate-id", required=True)
    args = parser.parse_args()

    config = load_config(Path(args.config))
    task = parse_task(Path(args.task))
    repo_root = Path(args.worktree).resolve()
    run_dir = Path(args.run_dir).resolve()
    output_path = Path(args.output).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)

    raw_changed = changed_files(repo_root, task.base_ref)
    generated = list(config.generated_artifact_paths)
    changed = [path for path in raw_changed if not is_generated(path, generated)]
    stats = diff_stats(repo_root, task.base_ref, generated)

    allowed = list(task.allowed_paths) + list(config.global_allowed_paths)
    violations = [path for path in changed if not is_allowed(path, allowed)]
    architecture_ok = not violations
    architecture_score = 1.0 if architecture_ok else 0.0

    checks_dir = run_dir / "checks"
    required_commands = format_commands(
        list(config.lane_required_commands.get(task.lane, [])),
        repo_root=config.repo_root,
        worktree=repo_root,
        run_dir=run_dir,
        checks_dir=checks_dir,
        task=task,
        candidate_id=args.candidate_id,
    )
    optional_commands = format_commands(
        list(config.lane_optional_commands.get(task.lane, [])),
        repo_root=config.repo_root,
        worktree=repo_root,
        run_dir=run_dir,
        checks_dir=checks_dir,
        task=task,
        candidate_id=args.candidate_id,
    )

    required_reports = run_checks(
        required_commands,
        repo_root,
        config.repo_root,
        checks_dir,
        required=True,
        timeout_seconds=config.default_timeout_seconds,
    )
    optional_reports = run_checks(
        optional_commands,
        repo_root,
        config.repo_root,
        checks_dir,
        required=False,
        timeout_seconds=config.default_timeout_seconds,
    )

    if required_reports:
        required_total = len(required_reports)
        required_passes = sum(1 for item in required_reports if item["status"] == "pass")
        required_pass_ratio = required_passes / required_total
    else:
        required_pass_ratio = 1.0

    if optional_reports:
        optional_passes = sum(1 for item in optional_reports if item["status"] == "pass")
        optional_skips = sum(1 for item in optional_reports if item["status"] == "skip")
        effective_optional_total = max(1, len(optional_reports) - optional_skips)
        optional_pass_ratio = optional_passes / effective_optional_total
    else:
        optional_pass_ratio = 1.0

    docs_score, docs_notes = detect_docs_sync(changed)
    minimality = minimality_score(stats["file_count"], stats["total_line_changes"])
    performance_score = 0.5  # neutral placeholder until repo-specific benchmarks are wired in

    hard_gate_passed = architecture_ok and all(item["status"] == "pass" for item in required_reports)
    scores = score_report(
        hard_gate_passed=hard_gate_passed,
        required_pass_ratio=required_pass_ratio,
        optional_pass_ratio=optional_pass_ratio,
        architecture_score=architecture_score,
        docs_score=docs_score,
        minimality=minimality,
        performance_score=performance_score,
        weights=config.scoring,
    )

    failed_checks = [item for item in (required_reports + optional_reports) if item["status"] == "fail"]
    stderr_fragments = []
    for item in failed_checks[:5]:
        stderr_path = config.repo_root / item["stderr_path"]
        if stderr_path.exists():
            stderr_fragments.append(f"## {item['name']}\n{stderr_path.read_text(encoding='utf-8')[:4000]}")

    result = {
        "task_id": task.task_id,
        "task_title": task.title,
        "candidate_id": args.candidate_id,
        "lane": task.lane,
        "base_ref": task.base_ref,
        "hard_gate_passed": hard_gate_passed,
        "checks": {
            "required": required_reports,
            "optional": optional_reports,
        },
        "architecture": {
            "allowed_paths": allowed,
            "ok": architecture_ok,
            "violations": violations,
        },
        "diff": stats,
        "metrics": scores,
        "artifacts": {
            "failed_checks": [item["name"] for item in failed_checks],
            "stderr": "\n\n".join(stderr_fragments),
            "docs_notes": docs_notes,
            "changed_files": changed,
        },
    }

    write_json(output_path, result)
    print(json.dumps(result, indent=2))
    return 0 if hard_gate_passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
