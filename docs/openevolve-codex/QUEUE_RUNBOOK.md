# Queue Runner Runbook

This adds the final wrapper layer for unattended multi-task execution.

## What it does

`automation/run_queue.py`:
- finds all selected task files
- runs them sequentially through `automation/orchestrator.py`
- writes queue-level audit logs under `logs/queues/<queue-id>/`
- marks task status transitions in the task frontmatter by default
- promotes successful winners to `integration/<task-id>` by default

This is the command you use when you want to start the system, walk away, and come back later.

## Basic usage

Run every `ready` task in priority order:

```bash
cd /Users/ben/amon-v1
python3 automation/run_queue.py
```

Run specific tasks in an explicit order:

```bash
python3 automation/run_queue.py \
  --task-ids \
  T101_ios_browse_open_orchestrator \
  T102_ios_protected_session_typed_states \
  T201_backend_cloudflare_access_jwt_verification
```

Preview the queue without executing it:

```bash
python3 automation/run_queue.py --list
```

Run only one lane:

```bash
python3 automation/run_queue.py --lane ios
```

Stop on the first failure:

```bash
python3 automation/run_queue.py --no-continue-on-failure
```

## Status behavior

By default the queue runner updates task frontmatter:

- before task start: `running`
- on success: `implemented`
- on failure: `failed`

If you do not want task files mutated, use:

```bash
python3 automation/run_queue.py --no-mark-status
```

## Audit trail

After a run, inspect:

```text
logs/queues/<queue-id>/
```

Most useful files:

- `manifest.json`
- `SUMMARY.md`
- `queue-results.json`
- `tasks/<task-id>/queue-task-result.json`
- `tasks/<task-id>/orchestrator.stdout.log`
- `tasks/<task-id>/orchestrator.stderr.log`
- `tasks/<task-id>/promote.stdout.log`
- `tasks/<task-id>/promote.stderr.log`

Each task still keeps its full per-run artifacts under:

```text
logs/runs/<task-id>-<timestamp>/
```

## Recommended first command for your current setup

```bash
cd /Users/ben/amon-v1
python3 automation/run_queue.py --list
python3 automation/run_queue.py
```
