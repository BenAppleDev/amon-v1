# Runbook

## 1. Install

```bash
./INSTALL_INTO_AMON_V1.sh
cd /Users/ben/amon-v1
python3 automation/bootstrap.py
```

## 2. Make sure Codex CLI exists

```bash
codex --help
```

If that fails, install or upgrade it, then sign in.

## 3. Create a real task

```bash
cp tasks/TEMPLATE.task.md tasks/T010_backend_auth_hardening.task.md
```

Edit the file:
- set a real `id`
- set `status = "ready"`
- define `allowed_paths`
- make the task bounded and testable

## 4. Run one generation set

```bash
python3 automation/orchestrator.py --task-id T010
```

Outputs land under:

```text
logs/runs/<task-id>-<timestamp>/
```

## 5. Inspect the result

Look at:
- `scoreboard.json`
- `SUMMARY.md`
- each candidate's `evaluation-report.json`
- each candidate's `codex-final-message.md`

## 6. Promote the winner to an integration branch

```bash
python3 automation/promote_winner.py \
  --scoreboard logs/runs/<run>/generations/g2/scoreboard.json
```

This creates or moves:

```text
integration/<task-id>
```

It does **not** merge to `main`.

## 7. Review in the Codex app

Open `/Users/ben/amon-v1` in the Codex app.
Use the winner or integration branch/worktree to continue manually or hand off to a new thread.
