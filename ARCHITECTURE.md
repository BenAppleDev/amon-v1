# Amon Architecture

This document explains the current prototype shape of Amon as a system, not just as a repo layout.

## Core idea

Amon is an applied AI prototype with three main boundaries:

- a public-facing explanation layer
- a backend that performs transient retrieval and synthesis work
- client-side local storage for durable user work

The design goal is to keep the backend useful without turning it into a permanent store of user content or an operator-facing surveillance surface.

## Main surfaces

### Website

`website/` contains the public-facing React site. It is informational only and is intentionally separated from the backend and ops surface.

### Backend

`backend/` contains the FastAPI service. It handles:

- local-dev auth flows
- user/session/account metadata
- search, retrieve, compare, and research endpoints
- prototype operator/session metadata endpoints

The backend is where transient AI-adjacent work happens, but it is not intended to be the durable home for user work product.

### iOS client starter

`ios/AmonKit/` and `ios/AppTemplate/` provide a Swift package and starter app shell. The client side is responsible for:

- calling the backend
- storing workspace data locally
- holding local encryption material
- exporting and importing local workspace bundles

### Ops prototype

`ops-dashboard/` is a metadata-only operator dashboard prototype. It is intentionally constrained: the goal is to support health and policy visibility without normalizing access to user page content or other sensitive work-product details.

### Shared artifacts

`shared/` contains shared schema and generated OpenAPI assets used for alignment across surfaces.

## Data boundary

### Durable backend data

The backend currently persists metadata such as:

- user/account identifiers
- auth/session lineage
- entitlements
- rate-limit windows
- metadata-only ops events and snapshots

### Transient backend data

The backend is intended to handle these transiently:

- query text
- result sets
- fetched page content
- compare/research inputs derived from live calls

### Durable client-side data

The iOS starter keeps saved workspace material locally. Export/import is built around encrypted bundles so the long-term user workspace does not have to live on the server by default.

## Request flow

1. A client authenticates with the backend.
2. The client calls search, retrieve, compare, or research endpoints.
3. The backend performs transient processing and returns normalized results.
4. If the user saves work, the durable copy belongs in the local client store or export bundle.
5. Operators can inspect metadata-only system state through the prototype ops surface.

## Operator boundary

The ops surface is intentionally narrower than the product surface.

- It is meant for metadata and health signals.
- It is not meant for page content inspection, cookie review, or a break-glass content browser.
- Internal and prototype routes exist in the codebase and generated OpenAPI assets for local development and testing, but they should not be treated as a stable public API surface.

## Repo map

- `backend/` — backend service, tests, config
- `website/` — public site
- `ios/` — Swift package and app template
- `ops-dashboard/` — prototype ops UI
- `shared/` — schemas and OpenAPI
- `tools/` — prototype tunnel and helper scripts
- `docs/` — architecture, deployment notes, and handoff material
