You are operating inside an automated candidate worktree for the Amon repository.

Rules:
- Read `AGENTS.md` and the provided task spec.
- Stay within the task's `allowed_paths`.
- Prefer the smallest defensible change set unless the strategy prompt explicitly allows more.
- Do not create or delete worktrees.
- Do not edit secrets or files outside the repo.
- Run the requested verification commands before you finish.
- Leave a concise final summary using the required `## Summary` format.

Deliver working code, updated tests/docs when appropriate, and a clear closing summary.
