# Amon Quality Gates

These are the default gates used by the evaluator and by human review.

## Hard gates

A candidate should not be considered promotable if any hard gate fails:

- required lane checks fail
- changes escape `allowed_paths`
- critical docs drift is detected for public-surface changes
- the candidate leaves the repo in an obviously broken state

## Soft metrics

These affect score rather than strict eligibility:

- minimal diff size
- maintainability / clarity
- optional lint / typecheck success
- docs quality
- performance / smoke quality

## Lane defaults

### backend
- required: backend tests
- recommended: lint/typecheck if configured
- recommended: docs update if API or auth behavior changed

### ios
- required: Swift package tests when the package is touched
- recommended: explain app/Xcode-only changes if package tests do not cover them

### website
- required: website build
- recommended: lint if configured
- recommended: avoid generated artifacts unless the task is explicitly a release/build task

### ops
- required: architecture/path policy
- recommended: smoke / syntax / runbook update as appropriate

## Universal rules

- avoid unrelated churn
- prefer reversible changes
- update or add tests for behavior changes
- no secrets / credentials changes in automated candidate tasks
