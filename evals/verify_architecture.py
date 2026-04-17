#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.append(str((Path(__file__).resolve().parents[1] / "automation").resolve()))
from common import load_config, parse_task  # noqa: E402


def normalize(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def is_allowed(path: str, allowed: list[str]) -> bool:
    normalized = normalize(path)
    for prefix in allowed:
        p = normalize(prefix)
        if normalized == p or normalized.startswith(p.rstrip("/") + "/"):
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify changed files stay within allowed paths.")
    parser.add_argument("--config", default="automation/config.toml")
    parser.add_argument("--task", required=True)
    parser.add_argument("--files-json", required=True, help="JSON file containing a list of changed files")
    args = parser.parse_args()

    config = load_config(Path(args.config))
    task = parse_task(Path(args.task))
    changed_files = json.loads(Path(args.files_json).read_text(encoding="utf-8"))

    allowed = list(task.allowed_paths) + list(config.global_allowed_paths)
    violations = [path for path in changed_files if not is_allowed(path, allowed)]
    result = {
        "allowed_paths": allowed,
        "changed_files": changed_files,
        "ok": not violations,
        "violations": violations,
    }
    print(json.dumps(result, indent=2))
    return 0 if not violations else 1


if __name__ == "__main__":
    raise SystemExit(main())
