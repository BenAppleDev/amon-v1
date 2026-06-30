# Amon Ops Dashboard

Prototype metadata-only dashboard for Amon's operator surface.

## What it is

- Separate operator frontend for the existing metadata-only ops APIs
- No page contents, frame contents, form values, DOM text dumps, or cookies
- Intended for local testing and architecture evaluation

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

## Public-repo note

This repo keeps the ops dashboard code because it demonstrates the intended
operator boundary, but it should still be treated as prototype infrastructure.
If you adapt it outside local development, use placeholder domains such as
`ops.example.com`, put it behind a real identity layer, and avoid treating the
current prototype routes as a stable public admin API.

## Deliberate non-features

- No break-glass content inspection
- No session text or frame payload viewer
- No operator-side navigation or action controls
- No public exposure
