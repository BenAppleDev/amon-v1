# Codex-Evolve Overlay Debug Report

## Scope

This report covers the overlay/orchestration layer inside `/Users/ben/amon-v1`:

- `automation/`
- `evals/`
- `.codex/`
- `.agents/`
- `tasks/`

It does not attempt to complete the product feature tasks themselves except where a rerun was needed to validate overlay behavior.

## Executive summary

The queue failure pattern was caused by the overlay, not by six unrelated feature regressions.

The primary systemic failure was that the overlay was invoking `codex exec` with unsupported CLI/config options, so every candidate aborted before making any change. That left every candidate with:

- `codex.returncode = 2`
- `commit_sha = null`
- `diff.file_count = 0`
- tightly clustered scores
- the same downstream hard-gate outcome

Once that upstream failure happened, the evaluator was only seeing untouched candidate branches and was reporting lane-check failures against unchanged code. Because all candidates were effectively identical, the stable sort always picked the first configured strategy: `minimal`.

## Evidence

### Queue-level evidence

From `logs/queues/queue-20260417-094900/SUMMARY.md`:

- every task ended with `winner did not pass the hard gate`
- every `winner_commit_sha` was null
- backend winners scored `20.0`
- iOS winners scored `23.0`
- winners were consistently `*-minimal`

### Sample backend run: T201

From `logs/runs/T201-20260417-094910/generations/g2/minimal/candidate-result.json`:

- `codex.returncode` was `2`
- `commit_sha` was `null`
- `evaluation.diff.file_count` was `0`

From `logs/runs/T201-20260417-094910/generations/g2/minimal/codex/codex.stderr.log`:

```text
error: unexpected argument '--json' found
```

### Sample iOS run: T101

From `logs/runs/T101-20260417-094926/generations/g2/minimal/candidate-result.json`:

- `codex.returncode` was `2`
- `commit_sha` was `null`
- `evaluation.diff.file_count` was `0`

From `logs/runs/T101-20260417-094926/generations/g2/minimal/codex/codex.stderr.log`:

```text
error: unexpected argument '--json' found
```

## Root causes

### 1. Codex CLI invocation was stale

`automation/codex_runner.py` was calling:

- `codex exec ... --json -`

The installed Codex CLI in this repo does not accept `--json` for `exec`. That caused every candidate generation to fail before any code edit, test run, or commit.

I also found a second invocation incompatibility during manual reruns:

- the local Codex config was resolving `model_reasoning_effort = "xhigh"`
- the installed CLI only accepts `low|medium|high|none` for `exec`

That meant even after removing `--json`, Codex could still fail early unless the overlay explicitly forced a supported reasoning value.

### 2. The overlay depended on the wrong Python entrypoint

The overlay scripts were spawning child scripts with `python3`, but in this environment:

- `python3` is Python 3.8
- `python` is Python 3.12

The overlay imports `tomllib`, so `python3 automation/orchestrator.py` is not a safe assumption here.

### 3. Hard-gate logic hid the real failure layer

Before the patch, the evaluator/hard gate only reflected lane checks + allowed paths. It did not encode:

- whether Codex execution succeeded
- whether the worktree changed
- whether a commit was actually created

That made the final failure message technically true but operationally misleading: the real failure was often upstream in candidate generation, not just downstream in testing.

### 4. Backend lane commands were not realistic enough for this repo

The backend hard gate used:

- `python -m pytest backend/tests`

That assumed globally installed test dependencies. In the recorded queue runs it failed immediately with:

```text
ModuleNotFoundError: No module named 'fastapi'
```

I first tried bootstrapping via editable install, but this repo’s backend package layout is not currently compatible with `pip install -e backend[dev]` in this environment. The realistic fix was to bootstrap a repo-local venv with the concrete runtime/test dependencies and then execute tests against the candidate worktree via `PYTHONPATH`.

After that change, the backend evaluator stopped failing on missing tooling and started reaching real backend test failures. That is the correct, truthful behavior.

### 5. iOS lane hard gate is not realistic in the current environment

The original iOS hard gate used:

- `swift test --package-path ios/AmonKit`

That failed for two separate overlay reasons:

1. stale module cache / shared `.build` path reuse across worktrees
2. SwiftPM sandbox behavior in this environment

I patched around both by using:

- isolated `--scratch-path`
- isolated module cache
- `--disable-sandbox`

That improved the failure mode substantially: the evaluator now reaches an actual compile failure instead of cache corruption.

However, the repo’s Swift package is explicitly iOS-only:

```swift
platforms: [
    .iOS(.v17)
]
```

and the source imports `UIKit`, so a generic host-side `swift test` hard gate is not a reliable unattended validator for this lane. In the current shell environment it fails with:

```text
error: no such module 'UIKit'
```

So the iOS hard gate was not just “broken in implementation”; it was also mis-specified for this repo/runtime combination.

### 6. Generated artifacts polluted scoring and diagnostics

Because `ios/AmonKit/.build/` is present in the repo/worktrees, evaluator diffs could be dominated by generated artifacts. That distorted minimality and made logs harder to interpret.

The evaluator now filters configured generated-artifact paths from diff/scoring calculations.

## Explicit answers to the requested questions

### Are candidate worktrees actually being modified?

In the recorded queue runs: no.

Evidence:

- every sampled candidate had `codex.returncode != 0`
- `diff.file_count = 0`
- `changed_files = []`

In manual post-patch Codex reruns inside preserved worktrees, Codex still could not complete in this tool environment because `OPENAI_API_KEY` is not available here. So I could validate the invocation path and error reporting, but not a successful local mutation from this sandboxed session.

### Are commits actually being created?

In the recorded queue runs: no.

Evidence:

- every sampled `commit_sha` was `null`
- `winner_commit_sha` was `null` for every queued task

### Why is `winner_commit_sha` null?

Because no candidate reached the auto-commit path.

Before the patch:

- Codex exited before doing work
- no changes were present
- `auto_commit(...)` either never ran or had nothing to commit

### Why do all tasks fail the hard gate?

Because the overlay failed before producing candidate changes, and then the unchanged branches hit lane checks / execution eligibility rules.

Originally the hard gate only captured evaluator results, which obscured the true failure layer. The patch now records hard-gate failures such as:

- `codex-exec`
- `no-worktree-changes`
- `missing-commit`
- `required-checks-or-architecture`

### Why does `minimal` always win?

Because all candidates were effectively identical no-op branches with identical scores, and the ranking sort is stable. Since `minimal` is configured first, it consistently won ties.

### Are lane-specific eval commands realistic for this repo?

- `backend`: now substantially more realistic after bootstrapping repo-local deps and testing the candidate worktree directly
- `ios`: not fully realistic yet as a hard gate; a plain host-side `swift test` is not sufficient for this iOS-only package in this environment
- `website`: not investigated deeply during this task
- `ops`: unchanged

### Is the hard gate incorrectly designed or implemented?

It was incomplete rather than conceptually wrong.

The design intent is sound: do not promote candidates that fail required checks or violate repo policy.

The implementation was missing key execution-truth signals:

- Codex success/failure
- actual worktree mutation
- commit creation

Those are now represented explicitly and are part of effective promotion eligibility.

## Patch summary

### `automation/codex_runner.py`

- removed unsupported `--json`
- switched stdout log naming to plain-text `codex.stdout.log`
- forced a supported `model_reasoning_effort="high"`
- captured the exact Codex command used for later diagnostics

### `automation/orchestrator.py`

- switched internal child-script execution to `sys.executable`
- records execution details in each candidate evaluation:
  - Codex command
  - return code
  - stdout/stderr paths
  - stderr excerpt
  - whether the final message exists
  - whether the worktree changed
  - whether a commit exists
- hard gate now reflects execution truth, not only evaluator output
- generation summaries now surface codex return code, commit SHA, and hard-gate failure reasons

### `automation/run_queue.py`

- now launches the orchestrator/promoter with the current interpreter instead of assuming `python3`

### `automation/run_generation.sh`

- now prefers `python`, falling back to `python3`

### `evals/evaluate_candidate.py`

- supports templated lane commands using repo/worktree/run-dir paths
- includes uncommitted working-tree diffs in diagnostics
- filters configured generated artifacts from diff stats/scoring
- now resolves stderr files against the repo root correctly

### `automation/config.toml`

- backend lane commands now bootstrap repo-local test dependencies and run pytest against the candidate worktree
- iOS lane command now uses an isolated scratch path, isolated module cache, and `--disable-sandbox`
- generated-artifact paths are explicitly configured for filtering

## Validation

### What I reran

Because this Codex desktop sandbox does not permit creating new git refs/locks, I could not perform a full fresh orchestrator rerun from this session. I used the smallest truthful alternatives available:

1. manual Codex reruns in preserved candidate worktrees:
   - backend: `T202` minimal worktree
   - iOS: `T103` minimal worktree
2. direct evaluator reruns against preserved candidate worktrees:
   - backend: `logs/validation/T202-eval-2/`
   - iOS: `logs/validation/T103-eval-2/`

### What passed / improved

- the stale Codex CLI argument failure is fixed in code
- the `xhigh` reasoning-effort incompatibility is fixed in code
- interpreter selection is fixed in code
- backend lane evaluation now reaches real test execution instead of dying on missing FastAPI/pytest
- iOS lane evaluation now reaches a real compile failure instead of stale-module-cache corruption
- generated `.build` noise is removed from diff scoring
- logs now encode the actual failure layer much more clearly

### What failed / remains uncertain

- full fresh orchestrator reruns from this sandbox are blocked by git-ref write restrictions
- manual Codex reruns in this sandbox still fail because `OPENAI_API_KEY` is not available here
- backend validation currently reaches real failing backend tests on the preserved candidate branch; that is a product-code/test-state issue, not the original overlay collapse
- iOS validation still does not have a trustworthy unattended hard gate for this repo/runtime combination

## Recommendation

### Backend lane

Much closer to unattended-ready. The overlay now gets far enough to expose real backend failures instead of collapsing in the orchestration layer.

### iOS lane

Not ready for unattended promotion yet. The original hard gate was unrealistic for this repo, and while the overlay now reports that more truthfully, it still needs a lane-specific validation strategy that is actually executable in the intended environment.

### Overall queue

Do not resume broad unattended queue execution across both backend and iOS yet.

Recommended next step:

1. run one fresh backend task outside this sandbox in the real runner environment and confirm:
   - Codex makes changes
   - a commit SHA is captured
   - scoreboard hard-gate reasons are accurate
   - promotion succeeds automatically when checks pass
2. separately define a realistic iOS hard gate before re-enabling unattended iOS queue runs
