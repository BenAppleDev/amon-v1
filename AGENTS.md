# Amon Codex Working Agreement

This repository uses a Codex + OpenEvolve-style outer loop.

Before doing any work:

1. Read the active task file in `tasks/`.
2. Respect the task's `allowed_paths`.
3. Stay inside this repository.
4. Prefer small, reversible diffs unless the task explicitly authorizes a broader refactor.
5. Run the evaluator before claiming the task is complete.
6. Do not create or destroy Git worktrees yourself unless the parent orchestration prompt explicitly asks.
7. Do not edit secrets, keychains, shell profiles, or files outside the repo.
8. Do not commit generated artifacts like `website/node_modules/`, `website/dist/`, build products, or caches unless the task explicitly requires a release artifact.

## Repo lanes

- **backend**: `backend/`, `shared/openapi/`, `shared/schema/`
- **ios**: `ios/`
- **website**: `website/`
- **ops**: `tools/`, `docs/deployment/`, `ops-dashboard/`

## Standard expectations

- Keep changes within the active lane unless the task explicitly spans multiple lanes.
- If behavior changes, update docs or explain why docs are unchanged.
- Add or update tests when you change behavior.
- Prefer existing project conventions over new abstractions.
- Do not rewrite large unrelated areas "while you are here."

## Final response format

When you finish a task, end with this structure:

```markdown
## Summary
- Objective:
- Key changes:
- Tests/checks run:
- Risks:
- Follow-ups:
```

Keep it concise and concrete.
