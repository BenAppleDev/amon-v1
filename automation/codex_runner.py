#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import shutil

from common import Config, ensure_dir, run


@dataclass
class CodexRunResult:
    returncode: int
    command: list[str]
    prompt_path: Path
    stdout_path: Path
    stderr_path: Path
    final_message_path: Path


def run_codex(
    *,
    config: Config,
    worktree: Path,
    run_dir: Path,
    prompt_text: str,
    sandbox_mode: str | None = None,
    approval_policy: str | None = None,
    web_search: str | None = None,
) -> CodexRunResult:
    if shutil.which(config.codex_command) is None:
        raise FileNotFoundError(
            f"Could not find Codex CLI executable '{config.codex_command}' on PATH. "
            "Install it and authenticate before running the orchestrator."
        )

    ensure_dir(run_dir)
    prompt_path = run_dir / "prompt.md"
    stdout_path = run_dir / "codex.stdout.log"
    stderr_path = run_dir / "codex.stderr.log"
    final_message_path = run_dir / "codex-final-message.md"
    prompt_path.write_text(prompt_text, encoding="utf-8")

    cmd = [
        config.codex_command,
        "exec",
        "-C",
        str(worktree),
        "--sandbox",
        sandbox_mode or config.sandbox_mode,
        "-c",
        f'approval_policy="{approval_policy or config.approval_policy}"',
        "-c",
        f'web_search="{web_search or config.web_search}"',
        "-c",
        'model_reasoning_effort="high"',
        "--output-last-message",
        str(final_message_path),
        "--color",
        "never",
        "-",
    ]

    proc = run(
        cmd,
        cwd=worktree,
        stdin_text=prompt_text,
        stdout_path=stdout_path,
        stderr_path=stderr_path,
        check=False,
    )
    return CodexRunResult(
        returncode=proc.returncode,
        command=cmd,
        prompt_path=prompt_path,
        stdout_path=stdout_path,
        stderr_path=stderr_path,
        final_message_path=final_message_path,
    )
