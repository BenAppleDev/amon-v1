# Amon Codex-Evolve System

This directory documents the repo-local autonomous improvement loop.

## What is installed

- `.codex/config.toml`
- `.codex/agents/*.toml`
- `.agents/skills/*`
- `automation/`
- `evals/`
- root control documents
- task templates
- `.worktrees/`
- `logs/runs/`

## Execution model

1. Human writes a bounded task in `tasks/`.
2. Orchestrator creates N candidate worktrees.
3. Each candidate uses Codex CLI in non-interactive mode.
4. Evaluator scores candidates and extracts artifacts.
5. Best candidate becomes the next parent branch for the next generation.
6. Optional promotion moves the winner to `integration/<task-id>`.

## Why the system is "OpenEvolve-style"

It borrows the important outer-loop ideas:

- candidate diversity
- iterative generations
- evaluator-based selection
- artifact feedback into the next generation
- multi-objective scoring

The mutation/implementation engine is Codex CLI.
