# Amon Tunnel Daemon

This directory contains the local laptop-side tunnel daemon for Amon's iPhone Packet Tunnel proof of concept.

It is separate from the FastAPI backend on purpose.

The bootstrap and validation routes used here are prototype local contracts for development and testing. They are not a stable public API surface.

## What It Is

`amon_tunnel_daemon.py` is a small asyncio TCP server that speaks the current Amon tunnel extension protocol.

It proves that:

- the iPhone Packet Tunnel extension can connect to your laptop
- the authenticated route bootstrap succeeds or fails with explicit machine-readable reasons
- framed IP packets are arriving from the device
- packet summaries can be inspected from your laptop logs

## What It Does

The daemon:

- listens on a configurable host and port
- accepts inbound TCP connections from the iPhone tunnel extension
- reads a newline-delimited JSON bootstrap request using protocol `AMON/2`
- validates the presented routed-local route session against the backend control plane
- sends a newline-delimited JSON bootstrap result indicating `accepted`, `rejected`, or `unavailable`
- reads framed packets:
  - 2-byte big-endian packet length
  - raw IP packet bytes
- logs connection lifecycle and packet summaries
- exits cleanly on `Ctrl+C`, `SIGINT`, or `SIGTERM`

## What It Does Not Do Yet

This is not a full VPN server.

It does not:

- create a TUN interface
- forward traffic to the internet
- implement NAT
- return packet frames back to the iPhone
- replace the FastAPI backend
- provide production-grade VPN security or routing
- validate live traffic forwarding end to end

For this stage, it is only a local proof-of-concept endpoint.

## How To Run It

From the repo root:

```bash
python3 tools/tunnel/amon_tunnel_daemon.py
```

Optional flags:

```bash
python3 tools/tunnel/amon_tunnel_daemon.py \
  --host 0.0.0.0 \
  --port 9443 \
  --api-origin http://127.0.0.1:8000 \
  --relay-shared-secret amon-route-relay-dev \
  --verbose
```

Defaults:

- host: `0.0.0.0`
- port: `9443`
- API origin: `http://127.0.0.1:8000`
- relay shared secret: `amon-route-relay-dev`

## How To Use It With Amon

Run the backend separately:

```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

Run the tunnel daemon separately:

```bash
python3 tools/tunnel/amon_tunnel_daemon.py \
  --port 9443 \
  --api-origin http://127.0.0.1:8000 \
  --relay-shared-secret amon-route-relay-dev
```

Then in the iPhone app:

1. Open `Settings > Amon Tunnel`
2. Set the laptop IP address
3. Set the tunnel port to `9443`
4. Connect the tunnel

If the Packet Tunnel extension is correctly signed and provisioned, the daemon should log:

- client connection
- bootstrap acceptance or rejection with a route-session reason code
- incoming packet frames

## Example Checks

Check whether the daemon is listening:

```bash
lsof -nP -iTCP:9443 -sTCP:LISTEN
```

Basic port check:

```bash
nc -vz 127.0.0.1 9443
```

## Manual Bootstrap Test

The daemon now expects a structured bootstrap request instead of the old `AMON/1` line handshake.

### 1. Mint a route session

From the repo root, use the backend dev flow:

```bash
ACCESS_TOKEN=$(curl -s http://127.0.0.1:8000/v1/auth/dev-login \
  -H 'content-type: application/json' \
  -d '{"apple_subject":"tunnel-smoke"}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')

curl -s http://127.0.0.1:8000/v1/route-sessions \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

That response includes:

- `session_id`
- `access_token`
- `auth_session_id`

### 2. Send the bootstrap request to the daemon

Use the repo helper:

```bash
python3 tools/tunnel/route_handshake_smoke.py \
  --host 127.0.0.1 \
  --port 9443 \
  --route-session-id route_... \
  --route-access-token ... \
  --route-auth-session-id ...
```

Expected success shape:

```json
{
  "code": "route_session_valid",
  "forwarding_mode": "packet_log_only",
  "forwarding_ready": false,
  "packet_plane_ready": true,
  "relay_auth_state": "accepted",
  "status": "accepted"
}
```

Common failure codes:

- `route_session_missing_token`
- `route_session_malformed_token`
- `route_session_expired`
- `route_session_revoked`
- `route_session_context_mismatch`
- `route_auth_session_invalid`
- `relay_validation_unavailable`
- `relay_validation_malformed_response`

## Packet Logging

When packets arrive, the daemon logs lightweight summaries.

For IPv4 it logs:

- version
- protocol
- source IP
- destination IP

For IPv6 it logs:

- version
- next header
- source IP
- destination IP

Malformed or short packets are logged safely and do not crash the daemon.
