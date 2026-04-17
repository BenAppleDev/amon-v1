#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TASK=""
WORKTREE=""
RUN_DIR=""
OUTPUT=""
CANDIDATE_ID="candidate"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="$2"; shift 2 ;;
    --worktree) WORKTREE="$2"; shift 2 ;;
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --candidate-id) CANDIDATE_ID="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$TASK" || -z "$WORKTREE" || -z "$RUN_DIR" || -z "$OUTPUT" ]]; then
  echo "Usage: ./evals/run_all.sh --task <task> --worktree <path> --run-dir <dir> --output <report.json> [--candidate-id id]" >&2
  exit 1
fi

cd "$REPO_ROOT"
PYTHON_BIN="${PYTHON:-python}"
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  PYTHON_BIN="python3"
fi
"$PYTHON_BIN" evals/evaluate_candidate.py \
  --config automation/config.toml \
  --task "$TASK" \
  --worktree "$WORKTREE" \
  --run-dir "$RUN_DIR" \
  --output "$OUTPUT" \
  --candidate-id "$CANDIDATE_ID"
