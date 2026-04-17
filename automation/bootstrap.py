#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

from common import ensure_dir, load_config


def main() -> int:
    config_path = Path(__file__).resolve().parent / "config.toml"
    config = load_config(config_path)

    paths = [
        config.repo_root / ".codex" / "state",
        config.repo_root / ".codex" / "cache",
        config.repo_root / ".worktrees",
        config.repo_root / "logs" / "runs",
        config.repo_root / "logs" / "install-backups",
        config.repo_root / "tasks",
        config.repo_root / "docs" / "openevolve-codex",
    ]

    for path in paths:
        ensure_dir(path)

    print("Bootstrapped Codex-Evolve directories:")
    for path in paths:
        print(f"  - {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
