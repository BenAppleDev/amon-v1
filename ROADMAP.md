# Amon Roadmap

This file is the human-owned roadmap. The orchestrator should not mutate roadmap intent directly.

## Milestone 1 — Baseline quality loop

- Repo-local Codex config
- Task spec format
- Candidate worktrees
- Evaluator and scoring
- Winner promotion flow

## Milestone 2 — Backend / API hardening

- Improve correctness and test coverage in backend flows
- Keep OpenAPI and schema artifacts aligned
- Tighten auth / protected session safety

## Milestone 3 — iOS product quality

- Stabilize package-level tests
- Improve local storage / transport / privacy settings quality
- Keep app changes bounded and verifiable

## Milestone 4 — Website and GTM quality

- Improve content structure and build reliability
- Avoid committing generated artifacts unless explicitly needed
- Keep public messaging aligned with product state

## Milestone 5 — Deployment / ops safety

- Strengthen deployment checks and runbooks
- Improve smoke / rollout confidence
- Make operational surfaces safer to change

## Task ingestion rule

Only task files under `tasks/` with `status = "ready"` should be automatically selected by the orchestrator.
