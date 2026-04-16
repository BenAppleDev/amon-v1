# Amon Ops Dashboard

First internal dashboard shell for the metadata-only Protected Session ops surface.

## What it is

- Separate operator frontend for the existing metadata-only ops APIs
- No page contents, frame contents, form values, DOM text dumps, or cookies
- Intended for local, staging, and production ops environments

## Local development

1. Start the backend with an internal admin token configured.

```bash
cd /Users/ben/amon-v1/backend
source .venv/bin/activate
export INTERNAL_ADMIN_TOKEN=amon-internal-dev
uvicorn app.main:app --reload
```

2. Visit the backend-served ops surface at [http://127.0.0.1:8000/ops/](http://127.0.0.1:8000/ops/).

3. Use one of these access paths:

- Trusted operator session:
  If you are behind a trusted proxy that injects `X-Amon-Ops-Proxy-Secret` and `X-Amon-Operator-Id`, use the `Use trusted operator session` button.
- Local/dev token exchange:
  Use the dev token form to exchange `INTERNAL_ADMIN_TOKEN` for a short-lived HttpOnly ops session cookie.

## Standalone frontend dev

You can still serve the static frontend separately on port `3000` if you want to work on the UI in isolation:

```bash
cd /Users/ben/amon-v1/ops-dashboard
python3 -m http.server 3000
```

Then open [http://127.0.0.1:3000](http://127.0.0.1:3000) and point it at `http://127.0.0.1:8000`.

The browser no longer stores the internal admin token after login. It uses a backend-issued ops session cookie.

## What the dashboard shows

- Overview summary
- Active session metadata
- Worker and fleet status
- Stream/protocol counters
- Policy/quota/termination counters
- Recent persisted metadata-only events
- Durable metadata snapshot history

## Future ops-subdomain deployment notes

For a future `ops.getamon.com` deployment:

1. Recommended first pass: keep the UI backend-served and expose it through the backend at `/ops/`.
2. Put `ops.getamon.com` behind a real operator identity layer such as Cloudflare Access, Tailscale, or another internal auth boundary.
3. Configure the backend environment for:
   - `OPS_SURFACE_ORIGIN`
   - `PUBLIC_SITE_ORIGINS`
   - `OPS_FRONTEND_ORIGINS`
   - `TRUST_PROXY_HEADERS=true`
   - `TRUSTED_HOST_PATTERNS`
4. Configure a trusted proxy or edge layer to inject:
   - `X-Amon-Ops-Proxy-Secret`
   - `X-Amon-Operator-Id`
5. Set:
   - `OPS_TRUSTED_PROXY_SECRET`
   - `OPS_ENVIRONMENT_KEY`
   - `OPS_ENVIRONMENT_LABEL`
   - `OPS_SESSION_COOKIE_SECURE=true`
   - `OPS_ALLOW_DEV_TOKEN_LOGIN=false`
6. Keep the public website on Vercel and the product APIs on `api.getamon.com`. The ops surface is meant for a distinct operator trust boundary, not a public route.

## Deliberate non-features

- No break-glass content inspection
- No session text or frame payload viewer
- No operator-side navigation or action controls
- No public exposure
