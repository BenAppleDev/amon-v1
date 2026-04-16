# Amon v1 Starter

This repository is a local-development starter for Amon v1.

## Included

- `backend/` — FastAPI backend with transient search, retrieve, compare, research endpoints
- `website/` — static public-facing website for `getamon.com`
- `shared/schema/` — SQL schema files for server and local encrypted storage
- `shared/openapi/` — generated OpenAPI specification for the backend
- `shared/http/` — ready-to-run HTTP request examples for the local dev flow
- `ios/AmonKit/` — Swift Package with models, API client, storage, export/import, and SwiftUI scaffolding
- `ios/AppTemplate/` — starter app files to drop into an iOS target

## What is already functional

- dev auth flow
- user/session/entitlement/rate-limit persistence on the server
- transient search endpoint with mock provider and optional Brave provider
- transient page retrieval and lightweight extraction
- transient compare and research generation
- local SQLite-backed workspace store on iOS starter
- export/import utility using encrypted workspace bundles
- backend tests

## Recommended local flow

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

### 2. Inspect the API

- Swagger UI: `http://127.0.0.1:8000/docs`
- OpenAPI spec: `shared/openapi/amon-v1-openapi.yaml`

### 3. Start the iOS app

- Create a new iOS app target in Xcode.
- Add `ios/AmonKit` as a local package.
- Copy `ios/AppTemplate/AmonApp.swift` and `ios/AppTemplate/RootTabView.swift` into the target.
- Run the app against the local backend.

## Notes on privacy boundaries

- The backend persists only auth, entitlement, sessions, and rate-limit counters.
- Queries, result sets, and page content are handled transiently.
- Saved user work belongs in the local store and export bundle only.

## Next build steps

- add production Sign in with Apple token verification on the backend
- harden the iOS local store to full encrypted-database semantics if you want SQLCipher
- add richer clean-view parsing and workspace editing
- add CI and release automation
