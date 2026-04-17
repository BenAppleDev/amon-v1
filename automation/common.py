#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
import tomllib


@dataclass
class CandidateStrategy:
    name: str
    prompt_file: str


@dataclass
class Config:
    repo_root: Path
    codex_command: str
    candidate_count: int
    generations: int
    base_prompt_file: str
    auto_commit: bool
    auto_promote: bool
    cleanup_failed_worktrees: bool
    approval_policy: str
    sandbox_mode: str
    web_search: str
    default_base_ref: str
    worktrees_dir: str
    logs_dir: str
    global_allowed_paths: list[str] = field(default_factory=list)
    generated_artifact_paths: list[str] = field(default_factory=list)
    candidate_strategies: list[CandidateStrategy] = field(default_factory=list)
    scoring: dict[str, float] = field(default_factory=dict)
    lane_required_commands: dict[str, list[str]] = field(default_factory=dict)
    lane_optional_commands: dict[str, list[str]] = field(default_factory=dict)
    default_timeout_seconds: int = 1800
    git_author_name: str = "Codex Evolve"
    git_author_email: str = "codex-evolve@local"

    @property
    def worktrees_path(self) -> Path:
        return self.repo_root / self.worktrees_dir

    @property
    def runs_path(self) -> Path:
        return self.repo_root / self.logs_dir


@dataclass
class TaskSpec:
    path: Path
    task_id: str
    title: str
    status: str
    priority: int
    lane: str
    base_ref: str
    allowed_paths: list[str]
    eval_profile: list[str]
    candidate_count: int | None
    generation_budget: int | None
    non_goals: list[str]
    done_when: list[str]
    body: str
    metadata: dict[str, Any]

    @property
    def selectable(self) -> bool:
        return self.status.lower() in {"ready", "queued", "todo"}

    def render_prompt_block(self) -> str:
        lines = [
            f"# Task {self.task_id}: {self.title}",
            "",
            f"- lane: {self.lane}",
            f"- base_ref: {self.base_ref}",
            f"- allowed_paths: {', '.join(self.allowed_paths)}",
            f"- eval_profile: {', '.join(self.eval_profile)}",
        ]
        if self.non_goals:
            lines.extend(["", "## Non-goals"])
            lines.extend([f"- {item}" for item in self.non_goals])
        if self.done_when:
            lines.extend(["", "## Done when"])
            lines.extend([f"- {item}" for item in self.done_when])
        lines.extend(["", "## Task body", self.body.strip(), ""])
        return "\n".join(lines)


def load_toml(path: Path) -> dict[str, Any]:
    with path.open("rb") as f:
        return tomllib.load(f)


def load_config(path: Path) -> Config:
    raw = load_toml(path)
    repo_root = Path(raw.get("repo_root", path.resolve().parents[1]))
    candidate_strategies = [
        CandidateStrategy(name=item["name"], prompt_file=item["prompt_file"])
        for item in raw.get("candidate_strategies", [])
    ]
    return Config(
        repo_root=repo_root,
        codex_command=raw.get("codex_command", "codex"),
        candidate_count=int(raw.get("candidate_count", 3)),
        generations=int(raw.get("generations", 1)),
        base_prompt_file=raw.get("base_prompt_file", ".codex/prompts/base_task.md"),
        auto_commit=bool(raw.get("auto_commit", True)),
        auto_promote=bool(raw.get("auto_promote", False)),
        cleanup_failed_worktrees=bool(raw.get("cleanup_failed_worktrees", False)),
        approval_policy=raw.get("approval_policy", "never"),
        sandbox_mode=raw.get("sandbox_mode", "workspace-write"),
        web_search=raw.get("web_search", "live"),
        default_base_ref=raw.get("default_base_ref", "main"),
        worktrees_dir=raw.get("worktrees_dir", ".worktrees"),
        logs_dir=raw.get("logs_dir", "logs/runs"),
        global_allowed_paths=list(raw.get("global_allowed_paths", [])),
        generated_artifact_paths=list(raw.get("generated_artifact_paths", [])),
        candidate_strategies=candidate_strategies,
        scoring={k: float(v) for k, v in raw.get("scoring", {}).items()},
        lane_required_commands={k: list(v) for k, v in raw.get("lane_required_commands", {}).items()},
        lane_optional_commands={k: list(v) for k, v in raw.get("lane_optional_commands", {}).items()},
        default_timeout_seconds=int(raw.get("default_timeout_seconds", 1800)),
        git_author_name=raw.get("git_author_name", "Codex Evolve"),
        git_author_email=raw.get("git_author_email", "codex-evolve@local"),
    )


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    ensure_dir(path.parent)
    path.write_text(text, encoding="utf-8")


def write_json(path: Path, data: Any) -> None:
    ensure_dir(path.parent)
    path.write_text(json.dumps(data, indent=2, sort_keys=True), encoding="utf-8")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def run(
    cmd: list[str] | str,
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    stdin_text: str | None = None,
    timeout: int | None = None,
    stdout_path: Path | None = None,
    stderr_path: Path | None = None,
    check: bool = False,
) -> subprocess.CompletedProcess[str]:
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    if stdout_path is None and stderr_path is None:
        return subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            env=env,
            input=stdin_text,
            timeout=timeout,
            text=True,
            capture_output=True,
            check=check,
        )

    ensure_dir((stdout_path or stderr_path).parent if (stdout_path or stderr_path) else Path("."))
    with (stdout_path.open("w", encoding="utf-8") if stdout_path else open(os.devnull, "w")) as out_f:
        with (stderr_path.open("w", encoding="utf-8") if stderr_path else open(os.devnull, "w")) as err_f:
            proc = subprocess.run(
                cmd,
                cwd=str(cwd) if cwd else None,
                env=env,
                input=stdin_text,
                timeout=timeout,
                text=True,
                stdout=out_f,
                stderr=err_f,
                check=check,
            )
    return proc


def parse_task(path: Path) -> TaskSpec:
    text = read_text(path)
    match = re.match(r"^\+\+\+\s*\n(.*?)\n\+\+\+\s*\n(.*)$", text, re.DOTALL)
    if not match:
        raise ValueError(f"Task file is missing TOML frontmatter: {path}")
    frontmatter, body = match.groups()
    metadata = tomllib.loads(frontmatter)
    return TaskSpec(
        path=path,
        task_id=str(metadata.get("id", path.stem)),
        title=str(metadata.get("title", path.stem)),
        status=str(metadata.get("status", "draft")),
        priority=int(metadata.get("priority", 999)),
        lane=str(metadata.get("lane", "backend")),
        base_ref=str(metadata.get("base_ref", "main")),
        allowed_paths=list(metadata.get("allowed_paths", [])),
        eval_profile=list(metadata.get("eval_profile", [])),
        candidate_count=metadata.get("candidate_count"),
        generation_budget=metadata.get("generation_budget"),
        non_goals=list(metadata.get("non_goals", [])),
        done_when=list(metadata.get("done_when", [])),
        body=body.strip(),
        metadata=metadata,
    )


def discover_tasks(tasks_dir: Path) -> list[TaskSpec]:
    task_files = sorted(tasks_dir.rglob("*.task.md"))
    tasks = [parse_task(path) for path in task_files]
    return tasks


def select_task(tasks: Iterable[TaskSpec], explicit_task_id: str | None = None) -> TaskSpec:
    tasks = list(tasks)
    if explicit_task_id:
        for task in tasks:
            if task.task_id == explicit_task_id:
                return task
        raise ValueError(f"Could not find task id: {explicit_task_id}")

    primary = [task for task in tasks if task.selectable and "examples" not in task.path.parts]
    if not primary:
        primary = [task for task in tasks if task.selectable]
    if not primary:
        raise ValueError("No selectable tasks found. Mark a task status as ready, queued, or todo.")
    return sorted(primary, key=lambda t: (t.priority, t.task_id))[0]


def repo_rel(path: Path, repo_root: Path) -> str:
    return str(path.resolve().relative_to(repo_root.resolve()))


def timestamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


def sanitize_branch_fragment(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"[^a-z0-9._/-]+", "-", value)
    value = re.sub(r"-{2,}", "-", value).strip("-")
    return value or "candidate"


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def git_env(config: Config) -> dict[str, str]:
    env = os.environ.copy()
    env.setdefault("GIT_AUTHOR_NAME", config.git_author_name)
    env.setdefault("GIT_AUTHOR_EMAIL", config.git_author_email)
    env.setdefault("GIT_COMMITTER_NAME", config.git_author_name)
    env.setdefault("GIT_COMMITTER_EMAIL", config.git_author_email)
    return env
