# Amon Deployment Runbooks

This is the narrow runbook for an example Track 2 deployment shape using placeholder domains. It is intended as prototype documentation, not a live production runbook.

- Public site: `www.example.com`
- API: `api.example.com`
- Ops: `ops.example.com`

For the high-level system shape, see [cloudflare-track2-topology.md](/Users/ben/amon-v1/docs/deployment/cloudflare-track2-topology.md).

## Startup validation

The backend is designed to fail fast on deployment-shape mistakes such as:

- non-HTTPS API or ops origins outside local development
- missing trusted-proxy configuration for non-local ops deployments
- loopback CORS origins left enabled in non-local environments
- `SameSite=None` cookies without `Secure`

If startup validation fails, fix the configuration mismatch rather than loosening the validator.

## Smoke script

The repo includes a lightweight smoke helper:

`/Users/ben/amon-v1/tools/deployment/track2_smoke.py`

Run it from the backend virtualenv so `httpx` is available.

### Example

```bash
cd /Users/ben/amon-v1/backend
source .venv/bin/activate
python ../tools/deployment/track2_smoke.py \
  --api-origin https://api.example.com \
  --ops-origin https://ops.example.com \
  --ops-route-mode path-prefix
```

### What it checks

- `GET /health`
- `GET /healthz`
- ops path behavior for `/ops`
- unauthenticated ops auth status
- metadata-only access expectations on the ops surface

Prototype internal routes may appear in these checks and in the generated OpenAPI assets. They are test and prototype surfaces, not a stable public API.

## Local / dev checklist

1. Copy `/Users/ben/amon-v1/backend/.env.example` to `.env`.
2. Keep:
   - `APP_ENV=development`
   - `API_EXTERNAL_ORIGIN=http://127.0.0.1:8000`
   - `OPS_SURFACE_ORIGIN=http://127.0.0.1:8000/ops/`
   - `OPS_BACKEND_PATH_PREFIX=/ops`
   - `TRUST_PROXY_HEADERS=false`
3. If you want local dev-token ops login, set:
   - `INTERNAL_ADMIN_TOKEN=...`
   - `OPS_ALLOW_DEV_TOKEN_LOGIN=true`
4. If you want the standalone dashboard on port `3000`, set:
   - `OPS_FRONTEND_ORIGINS=http://localhost:3000,http://127.0.0.1:3000`
5. Start the backend and confirm:
   - `http://127.0.0.1:8000/docs`
   - `http://127.0.0.1:8000/ops/`

## Non-local example checklist

1. Set:
   - `APP_ENV=staging` or `APP_ENV=production`
   - `API_EXTERNAL_ORIGIN=https://api.example.com`
   - `OPS_SURFACE_ORIGIN=https://ops.example.com/ops/`
   - `OPS_BACKEND_PATH_PREFIX=/ops`
   - `TRUST_PROXY_HEADERS=true`
   - `TRUSTED_PROXY_IPS=...`
   - `OPS_TRUSTED_PROXY_SECRET=...`
   - `OPS_ALLOW_DEV_TOKEN_LOGIN=false`
   - `OPS_SESSION_COOKIE_SECURE=true`
2. Ensure `PUBLIC_SITE_ORIGINS`, `OPS_FRONTEND_ORIGINS`, and any `CORS_ALLOW_ORIGINS` values are HTTPS-only and environment-appropriate.
3. Keep the ops surface behind a stronger identity boundary than the public site.
4. Use an edge rewrite to `/ops/` if you want the ops host to feel root-mounted; do not change the backend mount path in this repo without code changes.
