# Amon Track 2 Deployment Topology

This document describes the intended deployment shape for the Track 2 product and ops surfaces.

## Topology

- `www.getamon.com`
  - public-facing marketing/product website
  - deployed on Vercel from `website/`
- `api.getamon.com`
  - FastAPI backend
  - reached through Cloudflare Tunnel to the backend origin
  - serves product APIs used by iOS and any future browser-safe product clients
- `ops.getamon.com`
  - internal metadata-only operator surface
  - intended to sit behind a stronger identity boundary later, such as Cloudflare Access
  - should remain operationally separate from the public site and product app surfaces
- GoDaddy
  - remains the registrar
- Cloudflare
  - handles DNS, Tunnel, and front-door/security concerns for `api` and `ops`

## Current repo shape

- `website/`
  - public site only
- `backend/`
  - API backend
  - internal metadata APIs
  - ops auth/session boundary
  - backend-served ops shell under `/ops/`
- `ops-dashboard/`
  - standalone operator frontend source
  - can be served by the backend or worked on independently

## Current host and path assumptions

### Public website

- `www.getamon.com` stays on Vercel.
- This pass does not redesign the public site or move it into the backend.

### API backend

- The iOS app already expects `https://api.getamon.com`.
- The backend should be reachable behind Cloudflare Tunnel on that host.
- Browser CORS should allow:
  - public website origins
  - ops origins
  - explicit local/dev origins

### Ops surface

- The backend currently serves the ops shell at:
  - `/ops/`
  - `/ops/assets/*`
  - `/ops/auth/*`
  - `/ops/api/protected-sessions/*`
- For an initial `ops.getamon.com` deployment, the simplest shape is:
  - point `ops.getamon.com` to the same backend origin through Cloudflare
  - keep the backend ops path prefix as `/ops/`
  - optionally add an edge redirect or path normalization later if you want a cleaner root-host UX

## Auth and session model

### Product/API auth

- Product/user auth remains unchanged.
- This pass does not change Standard, Clean View, or Protected Session behavior.

### Ops auth

The browser should not carry the long-lived internal admin token in normal production usage.

Current code now supports:

- trusted proxy bootstrap
  - the browser hits `/ops/auth/status`
  - a trusted edge or proxy may inject:
    - `X-Amon-Ops-Proxy-Secret`
    - `X-Amon-Operator-Id`
  - the backend then creates a short-lived HttpOnly ops session cookie
- local/dev token exchange
  - still available for local development when enabled
  - uses the internal admin token only to mint the short-lived ops session

The ops session cookie is:

- HttpOnly
- path-scoped to `/ops`
- configurable for secure/domain/same-site behavior

## Trusted proxy and forwarded headers

The backend now supports:

- `TRUST_PROXY_HEADERS`
- `TRUSTED_PROXY_IPS`
- `TRUSTED_HOST_PATTERNS`

For Cloudflare Tunnel:

- enable trusted proxy headers in deployed environments
- set trusted proxy IPs/hosts to match the actual origin-facing proxy shape you run
- keep trusted host patterns explicit for:
  - `api.getamon.com`
  - `ops.getamon.com`
  - local hosts used in development

## Durable ops history

The repo now persists metadata-only ops history in the backend database:

- event records
- overview snapshots
- termination/failure reason categories
- stream/protocol metadata summaries

It does not persist:

- page text
- page links/forms
- cookies
- DOM dumps
- frame documents
- break-glass content access

## Recommended environment settings

### Local / dev

- `APP_ENV=development`
- `API_EXTERNAL_ORIGIN=http://127.0.0.1:8000`
- `OPS_SURFACE_ORIGIN=http://127.0.0.1:8000/ops/`
- `TRUST_PROXY_HEADERS=false`
- `OPS_ALLOW_DEV_TOKEN_LOGIN=true` or rely on development default behavior

### Staging / production

- `API_EXTERNAL_ORIGIN=https://api.getamon.com`
- `OPS_SURFACE_ORIGIN=https://ops.getamon.com/ops/` or your chosen edge-routed equivalent
- `PUBLIC_SITE_ORIGINS=https://www.getamon.com,https://getamon.com`
- `OPS_FRONTEND_ORIGINS=https://ops.getamon.com`
- `TRUST_PROXY_HEADERS=true`
- `TRUSTED_HOST_PATTERNS=api.getamon.com,ops.getamon.com,...`
- `OPS_SESSION_COOKIE_SECURE=true`
- `OPS_ALLOW_DEV_TOKEN_LOGIN=false`
- `OPS_TRUSTED_PROXY_SECRET=...`

## What is still manual outside the repo

### Cloudflare

- create the Tunnel and connect it to the backend origin
- map `api.getamon.com` to the backend origin
- map `ops.getamon.com` to the backend origin
- later, put `ops.getamon.com` behind Cloudflare Access or another operator identity layer
- optionally add redirect/rewrite rules if you want `ops.getamon.com/` to feel cleaner than `/ops/`

### Vercel

- keep `www.getamon.com` attached to the public site project
- keep public-site deployment separate from backend/ops concerns

### DNS / registrar

- GoDaddy stays the registrar
- Cloudflare manages DNS for the relevant records used by `www`, `api`, and `ops`

## Deliberate non-features

- no operator content inspection
- no ops access to page text, form values, cookies, or frame documents
- no runtime-scope expansion in this pass
- no infrastructure rewrite beyond config, docs, and deployment-shape prep
