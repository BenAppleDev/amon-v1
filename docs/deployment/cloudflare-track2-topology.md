# Amon Track 2 Deployment Topology

This document describes an example deployment shape for the Track 2 product and ops surfaces using placeholder domains. It is included as architecture context for a prototype, not as a live environment description.

For deployment checklists by environment, see [deployment-runbooks.md](/Users/ben/amon-v1/docs/deployment/deployment-runbooks.md).

## Example topology

- `www.example.com`
  - public-facing website
  - built from `website/`
- `api.example.com`
  - FastAPI backend for product APIs
  - can sit behind a front-door or tunnel layer
- `ops.example.com`
  - metadata-only operator surface
  - should remain behind a stronger identity boundary than the public site

## Current repo shape

- `website/`
  - public site only
- `backend/`
  - product API backend
  - prototype internal metadata APIs
  - backend-served ops shell under `/ops/`
- `ops-dashboard/`
  - standalone operator frontend source that can also be backend-served

## Current host and path assumptions

### Public website

- The public site can stay on a static host such as Vercel.
- This repo does not require the website to move into the backend.

### API backend

- The backend exposes `GET /health` and `GET /healthz`.
- The iOS starter can be pointed at a configured backend base URL such as `https://api.example.com`.
- Browser CORS should be explicit and environment-specific.

### Ops surface

- The backend currently serves the ops shell at `/ops/`.
- Related assets and auth routes live under `/ops/...`.
- A simple first deployment shape is to keep the backend path prefix at `/ops/` and optionally use an edge rewrite if you want a cleaner root-host experience.

## Auth and session model

### Product/API auth

- Product and user auth remain backend-managed.
- This repo still includes a local development login path for demos and tests.

### Ops auth

- The browser should not carry a long-lived admin token in normal production usage.
- The prototype supports short-lived ops sessions created from a trusted upstream identity or local demo bootstrap.
- The operator surface is intended to expose metadata and health information, not routine access to user content.

## Trusted proxy and forwarded headers

The backend supports:

- `TRUST_PROXY_HEADERS`
- `TRUSTED_PROXY_IPS`
- `TRUSTED_HOST_PATTERNS`

When deploying behind a front-door, keep trusted proxy and trusted host settings explicit rather than permissive.

## Durable ops history

The prototype persists metadata-only ops history such as:

- event records
- overview snapshots
- termination or failure categories
- stream and protocol summaries

It is not intended to persist page text, cookies, DOM dumps, or similar user content.

## Recommended environment settings

### Local / dev

- `APP_ENV=development`
- `API_EXTERNAL_ORIGIN=http://127.0.0.1:8000`
- `OPS_SURFACE_ORIGIN=http://127.0.0.1:8000/ops/`
- `OPS_BACKEND_PATH_PREFIX=/ops`
- `TRUST_PROXY_HEADERS=false`

### Non-local example

- `API_EXTERNAL_ORIGIN=https://api.example.com`
- `OPS_SURFACE_ORIGIN=https://ops.example.com/ops/`
- `PUBLIC_SITE_ORIGINS=https://www.example.com,https://example.com`
- `OPS_FRONTEND_ORIGINS=https://ops.example.com`
- `TRUST_PROXY_HEADERS=true`
- `TRUSTED_HOST_PATTERNS=api.example.com,ops.example.com,...`
- `OPS_SESSION_COOKIE_SECURE=true`
- `OPS_ALLOW_DEV_TOKEN_LOGIN=false`

## Public API note

Some prototype internal routes appear in the generated OpenAPI assets and in repo documentation because they are exercised in local development and tests. They are not a stable public API surface and should not be exposed as-is.
