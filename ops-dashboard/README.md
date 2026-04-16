# Amon Ops Dashboard

First internal dashboard shell for the metadata-only Protected Session ops surface.

## What it is

- Separate operator frontend for the existing internal metadata APIs
- No page contents, frame contents, form values, DOM text dumps, or cookies
- Intended for local/trusted internal environments first

## Local development

1. Start the backend with the internal admin token configured.

```bash
cd /Users/ben/amon-v1/backend
source .venv/bin/activate
export INTERNAL_ADMIN_TOKEN=amon-internal-dev
uvicorn app.main:app --reload
```

2. Serve the dashboard on port `3000` so it matches the backend's default CORS allowlist.

```bash
cd /Users/ben/amon-v1/ops-dashboard
python3 -m http.server 3000
```

3. Open [http://127.0.0.1:3000](http://127.0.0.1:3000), then enter:

- API base URL: `http://127.0.0.1:8000`
- Internal admin token: whatever you set in `INTERNAL_ADMIN_TOKEN`

## What the dashboard shows

- Overview summary
- Active session metadata
- Worker and fleet status
- Stream/protocol counters
- Policy/quota/termination counters
- Recent metadata-only events

## Future ops-subdomain deployment notes

For a future `ops.getamon.com` deployment:

1. Host `ops-dashboard/` as a separate static site or lightweight frontend app.
2. Put the dashboard behind a real operator identity layer such as Cloudflare Access, Tailscale, or another internal auth boundary.
3. Add `https://ops.getamon.com` to the backend `CORS_ALLOW_ORIGINS`.
4. Prefer a trusted proxy or edge layer that injects the internal admin credential server-side. This current token-entry gate is acceptable for local/dev only, not as the final production auth model.

## Deliberate non-features

- No break-glass content inspection
- No session text or frame payload viewer
- No operator-side navigation or action controls
- No public exposure
