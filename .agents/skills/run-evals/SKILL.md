---
name: run-evals
description: Use when a candidate branch needs to be validated with the repository's evaluator scripts before it is scored or promoted.
---

Run the repo evaluator instead of inventing ad hoc checks.

Preferred commands:
- `./evals/run_all.sh --task <task-file> --worktree <path>`
- or `python3 evals/evaluate_candidate.py --task <task-file> --worktree <path> --output <report.json>`

Treat required failing checks and path-boundary violations as blockers.
