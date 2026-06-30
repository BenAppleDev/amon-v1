# Amon Backend

FastAPI service for Amon v1.

## What this service does

- authenticates users with a local-dev Sign in with Apple compatible flow
- stores durable account and access metadata, including auth identities, entitlements, auth sessions, product
  sessions, route-session rows, rate-limit metadata, and metadata-only protected-session ops records
- provides transient search, retrieval, compare, and research endpoints
- avoids durable storage of query text, result sets, and page content
- includes prototype internal routes used for local ops and tunnel experiments; those routes appear in the
  generated OpenAPI assets for completeness but are not a public API commitment

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
BRAVE_BASE_URL=https://api.search.brave.com
BRAVE_TIMEOUT_SECONDS=15
```

When `SEARCH_PROVIDER=brave`, the backend calls Brave on behalf of the client and normalizes the response into Amon search results. The iOS client never receives the Brave API key and never calls Brave directly.

If `SEARCH_PROVIDER=brave` is set without `BRAVE_API_KEY`, the backend falls back to deterministic mock results in development so local work stays runnable. Outside development, `/v1/search` fails clearly until the key is configured.

## Dev auth

Use the dev login endpoint:

```bash
curl -X POST http://127.0.0.1:8000/v1/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"apple_subject": "local-dev-user"}'
```

Use the returned `access_token` as a Bearer token. In the current foundation model, that token is a short-lived
product-session token layered on top of the durable account, its auth session, and the currently selected entitlement.

## Verify search with curl

Start the backend, log in, and then call search through the backend:

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:8000/v1/auth/dev-login \
  -H 'Content-Type: application/json' \
  -d '{"apple_subject": "local-dev-user"}' | python -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')

curl -X POST http://127.0.0.1:8000/v1/search \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"query": "privacy browser", "count": 5}'
```

## Test

```bash
pytest
```
