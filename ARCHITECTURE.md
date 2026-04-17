# Amon Architecture Map

This file is the durable repo map for Codex and humans.

## Top-level surfaces

- `backend/` — Python backend, tests, migrations
- `ios/` — iOS app and Swift package
- `website/` — site content and frontend build
- `shared/` — shared OpenAPI/schema assets
- `tools/` — deployment/tunnel tools
- `docs/deployment/` — operational documentation
- `ops-dashboard/` — dashboard/static ops surface

## Lane ownership

### backend
Allowed default paths:
- `backend/`
- `shared/openapi/`
- `shared/schema/`

### ios
Allowed default paths:
- `ios/`

### website
Allowed default paths:
- `website/`

### ops
Allowed default paths:
- `tools/`
- `docs/deployment/`
- `ops-dashboard/`

## Global doc paths

These are allowed across lanes for docs sync:
- `docs/`
- `README.md`
- `VISION.md`
- `ROADMAP.md`
- `ARCHITECTURE.md`
- `QUALITY_GATES.md`

## Branching model for autonomous work

- Base branch: task-specific `base_ref`
- Candidate branches: `cand/<task-id>-<strategy>`
- Optional promoted branch: `integration/<task-id>`

## Rule

The orchestrator owns worktree/branch lifecycle.
Candidate Codex runs should edit the current worktree, not spawn more worktrees unless explicitly requested.
