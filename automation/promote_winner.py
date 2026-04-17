#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

from common import git_env, load_config, read_json, run


def main() -> int:
    parser = argparse.ArgumentParser(description="Promote a winner branch to an integration branch.")
    parser.add_argument("--config", default="automation/config.toml")
    parser.add_argument("--scoreboard", required=True, help="Path to scoreboard.json")
    parser.add_argument("--integration-branch", default=None, help="Defaults to integration/<task-id>")
    args = parser.parse_args()

    config = load_config(Path(args.config))
    scoreboard_path = Path(args.scoreboard).resolve()
    scoreboard = read_json(scoreboard_path)

    winner = scoreboard["winner"]
    task_id = scoreboard["task"]["task_id"]
    integration_branch = args.integration_branch or f"integration/{task_id}"
    winner_branch = winner["branch"]

    run(
        ["git", "branch", "-f", integration_branch, winner_branch],
        cwd=config.repo_root,
        env=git_env(config),
        check=True,
    )

    print(f"Promoted {winner_branch} -> {integration_branch}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
