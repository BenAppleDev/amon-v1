# Amon Handoff

This document is the fastest maintainer-oriented guide to getting the repo running, understanding where config belongs, and avoiding the most common mistakes.

## Setup checklist

- Install Python `3.11+`
- Install Node.js `18+` and `npm` if you want the website
- Install Xcode `15+` if you want the iOS starter
- Copy `backend/.env.example` to `backend/.env`
- Keep secrets and machine-specific config in `backend/.env`, not in committed files

## Local run steps

### Backend

```bash
cd /Users/ben/amon-v1/backend
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
cp .env.example .env
python -m app.bootstrap
uvicorn app.main:app --reload
```

### Backend smoke test

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/v1/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"apple_subject":"handoff-smoke-user"}' | python -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')

curl -X POST http://127.0.0.1:8000/v1/search \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"query":"privacy preserving AI tools","count":3}'
```

### Website

```bash
cd /Users/ben/amon-v1/website
npm install
npm run dev
```

### Ops dashboard

- Backend-served path: `http://127.0.0.1:8000/ops/`
- Standalone static preview:

```bash
cd /Users/ben/amon-v1/ops-dashboard
python3 -m http.server 3000
```

### iOS starter

- Open Xcode
- Create an iOS app target
- Add `ios/AmonKit` as a local package
- Copy files from `ios/AppTemplate/`
- Point the client at the local backend

## Common failure points

- `backend/.env` contains stale local values
  - Fix by re-copying from `backend/.env.example` and re-adding only the secrets you actually need locally.
- Brave search is enabled without a local key
  - Use `SEARCH_PROVIDER=mock` for the simplest demo path.
- The backend database contains old local state
  - Delete the local SQLite file and rerun `python -m app.bootstrap` if you need a clean local reset.
- Website build fails because dependencies are missing
  - Run `npm install` inside `website/`.
- Ops login does not work locally
  - Confirm the backend is running and that your local `.env` intentionally enables the path you are testing.

## Where secrets and config belong

- Keep local secrets only in ignored local files such as `backend/.env`.
- Do not commit API keys, local databases, or user-specific IDE metadata.
- Treat values such as `INTERNAL_ADMIN_TOKEN` and `ROUTE_RELAY_SHARED_SECRET` in example files as local-demo placeholders only.
- If a secret may have been exposed in a working tree or copy/paste, rotate it outside this repo.

## What a future maintainer should know

- This repo is meant to stay honest about being a prototype.
- The privacy boundary is part of the product story, not just an implementation detail.
- The generated OpenAPI assets include internal prototype routes for local testing and documentation, but those routes are not a promised public API surface.
- The ops dashboard is intentionally metadata-only and should not evolve into a routine content-inspection surface without an explicit product and policy decision.
