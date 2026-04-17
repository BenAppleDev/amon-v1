+++
id = "T201"
title = "Add verified Cloudflare Access JWT validation to ops identity path"
status = "failed"
priority = 96
lane = "backend"
base_ref = "main"
allowed_paths = ["backend/", "tools/", "docs/"]
eval_profile = ["lane-default", "architecture", "security"]
candidate_count = 3
generation_budget = 2
non_goals = [
  "changing public product behavior",
  "adding content inspection",
  "broad auth framework rewrites",
]
done_when = [
  "asserted Cloudflare Access identity is cryptographically or formally verified rather than only shape-checked",
  "ops session auth state clearly records verified identity source",
  "smoke tooling can validate the verified path",
  "required lane checks pass",
]
+++
## Objective

Upgrade the ops identity path from trusted asserted headers plus JWT-shape check to a real verified Cloudflare Access identity path.

## Context

Relevant files:
- `backend/app/security_ops_identity.py`
- `backend/app/security_ops_identity_cloudflare.py`
- `backend/app/security_ops.py`
- `backend/app/routers/ops_auth.py`
- `tools/deployment/track2_smoke.py`

## Acceptance signals

- Cloudflare Access asserted identity path performs meaningful verification.
- Clear failure modes exist for invalid, missing, or unverifiable assertions.
- Metadata-only auth status reflects verified asserted identity correctly.
- Transitional `shared_secret_headers` mode still works unless explicitly removed.

## Notes for Codex

Keep vendor coupling localized. The swap seam should remain clean and explicit.
