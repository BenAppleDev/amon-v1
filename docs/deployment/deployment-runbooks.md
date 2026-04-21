# Amon Deployment Runbooks

This is the narrow runbook for the current Track 2 deployment shape.

- Public site: `www.getamon.com` on Vercel
- API: `api.getamon.com` behind Cloudflare Tunnel
- Ops: `ops.getamon.com` as the metadata-only operator surface

This document is intentionally operational and concise. For topology details, see [cloudflare-track2-topology.md](/Users/ben/amon-v1/docs/deployment/cloudflare-track2-topology.md).

## Startup Validation

The backend now fails fast on deployment-shape mistakes such as:

- non-HTTPS API or ops origins outside local development
- missing trusted-proxy bootstrap configuration for non-local ops deployments
- loopback CORS origins left enabled in staging/production
- `SameSite=None` cookies without `Secure`
- attempts to move the backend ops mount away from `/ops` before the repo supports it

If the service exits during startup, fix the env mismatch rather than weakening the validator.

## Deployment Smoke Script

The repo now includes a lightweight smoke helper:

`/Users/ben/amon-v1/tools/deployment/track2_smoke.py`

Run it from the backend virtualenv so `httpx` is available.

### Example: staging-like check

```bash
cd /Users/ben/amon-v1/backend
source .venv/bin/activate
python ../tools/deployment/track2_smoke.py \
  --api-origin https://api.getamon.com \
  --ops-origin https://ops.getamon.com \
  --ops-route-mode path-prefix \
  --trusted-upstream-mode shared-secret \
  --operator-id ops@example.com \
  --trusted-upstream-secret "$OPS_TRUSTED_PROXY_SECRET"
```

### Example: future asserted-identity check

```bash
cd /Users/ben/amon-v1/backend
source .venv/bin/activate
python ../tools/deployment/track2_smoke.py \
  --api-origin https://api.getamon.com \
  --ops-origin https://ops.getamon.com \
  --ops-route-mode path-prefix \
  --trusted-upstream-mode asserted-identity \
  --operator-id ops@example.com \
  --asserted-operator-header X-Amon-Operator-Identity
```

### Example: Cloudflare Access-style asserted-identity check

```bash
cd /Users/ben/amon-v1/backend
source .venv/bin/activate
python ../tools/deployment/track2_smoke.py \
  --api-origin https://api.getamon.com \
  --ops-origin https://ops.getamon.com \
  --ops-route-mode path-prefix \
  --trusted-upstream-mode asserted-identity \
  --trusted-upstream-provider cloudflare-access \
  --operator-id ops@example.com \
  --asserted-operator-header Cf-Access-Authenticated-User-Email \
  --cloudflare-access-jwt-header Cf-Access-Jwt-Assertion \
  --cloudflare-access-jwt-assertion header.payload.signature
```

### What it checks

- `GET /health`
- `GET /healthz`
- ops path behavior:
  - `/ops -> /ops/` for path-prefix deployments
  - or root-host expectation if you use an edge rewrite
- unauthenticated `GET /ops/auth/status`
- trusted-upstream bootstrap on `GET /ops/auth/status`
- mode-specific upstream contract checks for:
  - transitional shared-secret headers
  - future asserted-identity headers
  - Cloudflare Access-style asserted identity with both operator identity and JWT assertion headers
- secure/path-scoped ops cookie behavior
- metadata-only access to `GET /ops/api/protected-sessions/overview`
- negative bootstrap with a bad upstream secret

If you need to hit a direct origin while simulating edge headers during staging validation, the script also accepts:

- `--forwarded-host`
- `--forwarded-proto`

## Local / Dev Checklist

Use this when running everything on your machine.

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
   - `python ../tools/deployment/track2_smoke.py --api-origin http://127.0.0.1:8000 --ops-origin http://127.0.0.1:8000 --ops-route-mode path-prefix`

## Routed-Local Preflight

Use this when you want to validate the routed-local auth/bootstrap seam before live forwarding.

### Backend expectations

- `ROUTE_RELAY_SHARED_SECRET`
  - local/test default: `amon-route-relay-dev`
  - non-local: set explicitly before exposing the internal relay-validation path
- internal relay validator path:
  - `POST /internal/route-sessions/validate`
  - header: `X-Amon-Route-Relay-Secret`

### Daemon expectations

Run the laptop daemon with:

```bash
python3 /Users/ben/amon-v1/tools/tunnel/amon_tunnel_daemon.py \
  --host 0.0.0.0 \
  --port 9443 \
  --api-origin http://127.0.0.1:8000 \
  --relay-shared-secret amon-route-relay-dev
```

### Smoke flow

1. Start the backend.
2. Mint a dev auth session and a route session.
3. Start the daemon.
4. Run:

```bash
python3 /Users/ben/amon-v1/tools/tunnel/route_handshake_smoke.py \
  --host 127.0.0.1 \
  --port 9443 \
  --route-session-id route_... \
  --route-access-token ... \
  --route-auth-session-id session_...
```

### Expected success signals

- backend returns `status = accepted` with `code = route_session_valid`
- daemon logs `bootstrap accepted`
- smoke output includes:
  - `status = accepted`
  - `relay_auth_state = accepted`
  - `packet_plane_ready = true`
  - `forwarding_mode = packet_log_only`

### Expected failure signals

- missing token:
  - `route_session_missing_token`
- malformed token:
  - `route_session_malformed_token`
- expired token:
  - `route_session_expired`
- revoked token:
  - `route_session_revoked`
- mismatched route/auth session:
  - `route_session_context_mismatch`
- auth session no longer valid:
  - `route_auth_session_invalid`
- backend unavailable:
  - `relay_validation_unavailable`
- malformed backend response:
  - `relay_validation_malformed_response`

## Staging-Like Checklist

Use this before a real internet-facing deployment.

1. Set:
   - `APP_ENV=staging`
   - `API_EXTERNAL_ORIGIN=https://api-staging.getamon.com` or your staging API hostname
   - `OPS_SURFACE_ORIGIN=https://ops-staging.getamon.com/ops/` or `https://ops-staging.getamon.com/` if edge-rewritten
   - `OPS_BACKEND_PATH_PREFIX=/ops`
   - `TRUST_PROXY_HEADERS=true`
   - `TRUSTED_PROXY_IPS=...`
   - `OPS_TRUSTED_PROXY_SECRET=...`
   - if using asserted identity:
     - `OPS_TRUSTED_UPSTREAM_IDENTITY_MODE=asserted_identity_headers`
     - `OPS_TRUSTED_UPSTREAM_ASSERTED_PROVIDER=generic` or `cloudflare_access`
   - `OPS_ALLOW_DEV_TOKEN_LOGIN=false`
   - `OPS_SESSION_COOKIE_SECURE=true`
2. Ensure `PUBLIC_SITE_ORIGINS`, `OPS_FRONTEND_ORIGINS`, and any `CORS_ALLOW_ORIGINS` entries are HTTPS only.
3. Ensure `TRUSTED_HOST_PATTERNS` covers the API and ops hostnames.
4. If the ops host should look root-mounted, use an edge rewrite to `/ops/`; do not change the backend mount path in this repo.
5. Verify:
   - product API requests resolve through the intended proxy/front door
   - ops auth is proxy-bootstrapped, not dev-token based
   - cookies are set as secure and path-scoped to `/ops`
   - the smoke script passes against the staging hostnames

## Production-Like Checklist

Use this before pushing real traffic.

1. Set:
   - `APP_ENV=production`
   - `API_EXTERNAL_ORIGIN=https://api.getamon.com`
   - `OPS_SURFACE_ORIGIN=https://ops.getamon.com/ops/` or `https://ops.getamon.com/` with edge rewrite
   - `OPS_BACKEND_PATH_PREFIX=/ops`
   - `TRUST_PROXY_HEADERS=true`
   - `TRUSTED_PROXY_IPS=...`
   - `OPS_TRUSTED_PROXY_SECRET=...`
   - if using asserted identity:
     - `OPS_TRUSTED_UPSTREAM_IDENTITY_MODE=asserted_identity_headers`
     - `OPS_TRUSTED_UPSTREAM_ASSERTED_PROVIDER=generic` or `cloudflare_access`
   - `OPS_ALLOW_DEV_TOKEN_LOGIN=false`
   - `OPS_SESSION_COOKIE_SECURE=true`
2. Ensure no loopback origins remain in:
   - `OPS_FRONTEND_ORIGINS`
   - `CORS_ALLOW_ORIGINS`
   - `PUBLIC_SITE_ORIGINS`
3. Keep `www.getamon.com` on Vercel and separate from the backend/ops deployment.
4. Keep `ops.getamon.com` behind a stronger identity boundary before exposing it to operators.
5. Verify the repo starts cleanly with no configuration validation error.
6. Run the smoke script against the public staging/prod hosts before you treat the deployment as credible.

## Current Ops Path Contract

Today, the backend ops surface is mounted at `/ops`.

- Cookie path: `/ops`
- Backend-served shell: `/ops/`
- Auth routes: `/ops/auth/*`
- Metadata routes: `/ops/api/protected-sessions/*`

If you want `ops.getamon.com` to look root-mounted, do it with an edge rewrite or redirect layer for now. This repo does not yet support moving the backend ops mount away from `/ops`.
