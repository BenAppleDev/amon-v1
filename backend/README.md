# Amon Backend

FastAPI service for Amon v1.

## What this service does

- authenticates users with a local-dev Sign in with Apple compatible flow
- stores only auth, entitlement, session, and rate-limit metadata
- provides transient search, retrieval, compare, and research endpoints
- avoids durable storage of query text, result sets, and page content

## Local setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
cp .env.example .env
python -m app.bootstrap
uvicorn app.main:app --reload
```

## Optional Brave Search API integration

Set these in `.env`:

```bash
SEARCH_PROVIDER=brave
BRAVE_API_KEY=your_key_here
```

Without an API key, the service falls back to deterministic mock search results so the app is runnable locally.

## Dev auth

Use the dev login endpoint:

```bash
curl -X POST http://127.0.0.1:8000/v1/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"apple_subject": "local-dev-user"}'
```

Use the returned `access_token` as a Bearer token.

## Test

```bash
pytest
```
