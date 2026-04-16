# Amon Deployment Runbooks

This is the narrow runbook for the current Track 2 deployment shape.

- Public site: `www.getamon.com` on Vercel
- API: `api.getamon.com` behind Cloudflare Tunnel
- Ops: `ops.getamon.com` as the metadata-only operator surface

This document is intentionally operational and concise. For topology details, see [cloudflare-track2-topology.md](/Users/ben/amon-v1/docs/deployment/cloudflare-track2-topology.md).

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
   - `OPS_ALLOW_DEV_TOKEN_LOGIN=false`
   - `OPS_SESSION_COOKIE_SECURE=true`
2. Ensure `PUBLIC_SITE_ORIGINS`, `OPS_FRONTEND_ORIGINS`, and any `CORS_ALLOW_ORIGINS` entries are HTTPS only.
3. Ensure `TRUSTED_HOST_PATTERNS` covers the API and ops hostnames.
4. If the ops host should look root-mounted, use an edge rewrite to `/ops/`; do not change the backend mount path in this repo.
5. Verify:
   - product API requests resolve through the intended proxy/front door
   - ops auth is proxy-bootstrapped, not dev-token based
   - cookies are set as secure and path-scoped to `/ops`

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
   - `OPS_ALLOW_DEV_TOKEN_LOGIN=false`
   - `OPS_SESSION_COOKIE_SECURE=true`
2. Ensure no loopback origins remain in:
   - `OPS_FRONTEND_ORIGINS`
   - `CORS_ALLOW_ORIGINS`
   - `PUBLIC_SITE_ORIGINS`
3. Keep `www.getamon.com` on Vercel and separate from the backend/ops deployment.
4. Keep `ops.getamon.com` behind a stronger identity boundary before exposing it to operators.
5. Verify the repo starts cleanly with no configuration validation error.

## Current Ops Path Contract

Today, the backend ops surface is mounted at `/ops`.

- Cookie path: `/ops`
- Backend-served shell: `/ops/`
- Auth routes: `/ops/auth/*`
- Metadata routes: `/ops/api/protected-sessions/*`

If you want `ops.getamon.com` to look root-mounted, do it with an edge rewrite or redirect layer for now. This repo does not yet support moving the backend ops mount away from `/ops`.
