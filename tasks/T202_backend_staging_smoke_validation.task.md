+++
id = "T202"
title = "Runbook-grade staging validation support for api and ops surfaces"
status = "implemented"
priority = 84
lane = "backend"
base_ref = "main"
allowed_paths = ["backend/", "tools/", "docs/"]
eval_profile = ["lane-default", "architecture"]
candidate_count = 2
generation_budget = 1
non_goals = [
  "full IaC automation",
  "changing DNS or external infrastructure directly",
]
done_when = [
  "deployment smoke tooling covers api and ops staging flows clearly",
  "docs describe exact expected staging success/failure signals",
  "required lane checks pass",
]
+++
## Objective

Turn the current smoke support into a reliable staging runbook for validating `api.getamon.com` and `ops.getamon.com`.

## Context

Relevant files:
- `tools/deployment/track2_smoke.py`
- `docs/deployment/deployment-runbooks.md`
- `docs/deployment/cloudflare-track2-topology.md`
- `backend/app/routers/health.py`

## Acceptance signals

- Smoke tooling covers:
  - `/health`
  - `/healthz`
  - `/ops` → `/ops/`
  - ops auth/bootstrap
  - cookie/session behavior
  - bad-config/failure cases
- Docs explain how to run against local, staging-like, and real staged environments.
- Output is actionable for a human deployment check.

## Notes for Codex

No infrastructure automation required. This is about validation, not provisioning.
