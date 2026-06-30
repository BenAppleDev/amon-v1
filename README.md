# Amon v1 Starter

Amon is a privacy-first applied AI prototype that explores how a research or retrieval assistant can be useful without turning the server or ops layer into a full content-surveillance system. This repo packages the current prototype surfaces together so a reviewer can inspect the architecture, run a local demo, and see how product, local storage, and operator boundaries fit together.

This is an honest starter, not a production-ready deployment. It contains working backend, website, and iOS scaffolding, along with prototype ops and tunnel tooling that are useful for evaluation and handoff but should not be treated as finished public infrastructure.

## What this repo shows

- `backend/` — FastAPI backend for auth, search, retrieve, compare, and research flows
- `website/` — React + Vite public-facing site
- `ops-dashboard/` — metadata-only prototype operator dashboard
- `ios/AmonKit/` — Swift package with API client, local workspace storage, export/import, and SwiftUI scaffolding
- `ios/AppTemplate/` — minimal files to drop into an iOS target
- `shared/schema/` — SQL schema assets
- `shared/openapi/` — generated OpenAPI spec for the prototype backend
- `shared/http/` — ready-to-run local HTTP examples

## What works today

- local dev auth flow
- transient search with a mock provider and optional Brave-backed search
- transient page retrieval, compare, and research generation
- durable account/session metadata on the backend
- local SQLite-backed workspace storage on iOS
- encrypted export/import for local workspaces
- backend test coverage for current server behavior

## What is still prototype-grade

- dev login is still present for local development
- the iOS app is a starter package plus template, not a full shipped client
- the ops surface is a prototype metadata-only dashboard, not a hardened admin product
- deployment docs describe example shapes and placeholders, not a live public environment

## Privacy and operator boundary

- Query text, result sets, and page content are intended to be transient on the backend.
- Durable backend storage is limited to account, session, entitlement, rate-limit, and metadata-only ops records.
- Saved user work is intended to live in the client-side local store and export bundle.
- Prototype internal routes appear in the generated OpenAPI spec for completeness, but they are not a public API commitment and should not be exposed as-is.

## Prerequisites

- Python `3.11+` for the backend
- Node.js `18+` and `npm` if you want the website
- Xcode `15+` and an iOS `17+` simulator or device if you want to try the iOS starter

## Fastest local demo

### 1. Start the backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
cp .env.example .env
python -m app.bootstrap
uvicorn app.main:app --reload
```

The default example config is local-only and uses the mock search provider unless you add your own local Brave key.

### 2. Smoke-test the API

In another shell:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/v1/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"apple_subject":"local-demo-user"}' | python -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')

curl -X POST http://127.0.0.1:8000/v1/search \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"query":"privacy preserving AI tools","count":3}'
```

You can also open:

- Swagger UI: `http://127.0.0.1:8000/docs`
- Ops shell: `http://127.0.0.1:8000/ops/`

### 3. Optional website

```bash
cd website
npm install
npm run dev
```

### 4. Optional iOS starter

- Create a new iOS app target in Xcode.
- Add `ios/AmonKit` as a local package.
- Copy `ios/AppTemplate/AmonApp.swift` and `ios/AppTemplate/RootTabView.swift` into the target.
- Run the app against the local backend.

## Reviewer path

- Start with this file for the project story and local demo.
- Read [ARCHITECTURE.md](/Users/ben/amon-v1/ARCHITECTURE.md) for the system shape and privacy boundary.
- Read [VISION.md](/Users/ben/amon-v1/VISION.md) for the intended direction.
- Read [docs/HANDOFF.md](/Users/ben/amon-v1/docs/HANDOFF.md) for maintainer-oriented setup and troubleshooting.

## Optional portfolio assets to add

If you want this repo to read more quickly in a fellowship or portfolio review, add:

- a website screenshot
- an iOS screenshot
- an ops-dashboard screenshot
- a simple architecture diagram

## Additional docs

- [backend/README.md](/Users/ben/amon-v1/backend/README.md)
- [website/README.md](/Users/ben/amon-v1/website/README.md)
- [ios/README.md](/Users/ben/amon-v1/ios/README.md)
- [ops-dashboard/README.md](/Users/ben/amon-v1/ops-dashboard/README.md)
- [docs/deployment/cloudflare-track2-topology.md](/Users/ben/amon-v1/docs/deployment/cloudflare-track2-topology.md)
- [docs/deployment/deployment-runbooks.md](/Users/ben/amon-v1/docs/deployment/deployment-runbooks.md)
