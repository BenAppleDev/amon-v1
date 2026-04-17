# File Layout

## Control plane
- `AGENTS.md`
- `VISION.md`
- `ROADMAP.md`
- `ARCHITECTURE.md`
- `QUALITY_GATES.md`

## Codex config
- `.codex/config.toml`
- `.codex/agents/*.toml`
- `.codex/prompts/*.md`

## Skills
- `.agents/skills/*`

## Outer loop
- `automation/common.py`
- `automation/codex_runner.py`
- `automation/orchestrator.py`
- `automation/promote_winner.py`
- `automation/bootstrap.py`

## Evaluator
- `evals/evaluate_candidate.py`
- `evals/verify_architecture.py`
- `evals/run_all.sh`

## State
- `tasks/*.task.md`
- `.worktrees/`
- `logs/runs/`
