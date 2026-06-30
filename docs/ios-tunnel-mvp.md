# Amon iOS Tunnel MVP

This document describes the proof-of-concept tunnel layer wired into the iOS app.

The tunnel bootstrap and validation paths described here are prototype internal
contracts used for local development and testing. They are not a stable public
API surface.

## What is in the repo

- `ios/AmonApp/Amon/Amon/Tunnel/TunnelManager.swift`
  - App-side manager around `NETunnelProviderManager`
  - Owns status, connect, disconnect, and preference installation
- `ios/AmonApp/Amon/AmonTunnelExtension/PacketTunnelProvider.swift`
  - Packet Tunnel extension entry point
  - Opens the transport connection to the laptop endpoint
  - Applies packet-tunnel network settings
  - Moves raw IP packets between `packetFlow` and the endpoint socket
- `ios/AmonKit/Sources/AmonKit/Models/TransportSettings.swift`
  - Durable local transport settings
- `ios/AmonKit/Sources/AmonKit/Views/TransportSettingsView.swift`
  - In-app status and control surface
- `tools/tunnel/amon_tunnel_daemon.py`
  - Local laptop-side development daemon for handshake and packet logging

The FastAPI backend remains separate. This tunnel code does not replace or absorb `backend/app`.

## Current protocol between the iPhone extension and the laptop endpoint

This stage now uses an authenticated bootstrap protocol so the iPhone-side integration reaches the relay-auth boundary.

1. The extension opens a TCP connection to the configured laptop host and port.
2. The extension sends one newline-delimited JSON bootstrap request:

```json
{
  "protocol": "AMON/2",
  "type": "bootstrap",
  "request_id": "...",
  "route_session_id": "route_...",
  "route_access_token": "...",
  "route_auth_session_id": "session_...",
  "requested_path": "local_routed",
  "transport_kind": "packet_tunnel",
  "client_platform": "ios",
  "app_bundle_id": "com.benappledev.Amon"
}
```

3. The laptop endpoint validates the route session against the backend control plane at `POST /internal/route-sessions/validate`.
4. The laptop endpoint replies with one newline-delimited JSON bootstrap result:

```json
{
  "protocol": "AMON/2",
  "type": "bootstrap_result",
  "status": "accepted",
  "code": "route_session_valid",
  "message": "The routed-local session is valid for relay bootstrap.",
  "relay_auth_state": "accepted",
  "packet_plane_ready": true,
  "forwarding_mode": "packet_log_only",
  "forwarding_ready": false
}
```

5. After an `accepted` bootstrap result, packets are exchanged as:
   - 2-byte big-endian packet length
   - raw IP packet bytes

Rejection and availability failures use the same response envelope with:

- `status = rejected` for auth/context failures such as expired, revoked, malformed, or mismatched route sessions
- `status = unavailable` for backend/validation-path failures such as the control plane being offline or returning malformed data

The extension currently installs:

- client address: `10.44.0.2`
- remote address: `10.44.0.1`
- subnet mask: `255.255.255.0`
- default route included
- DNS servers from app settings
- MTU from app settings

These are development defaults only and can be changed in-app.

## What the laptop must run

The laptop needs a separate tunnel endpoint service. It is not part of the FastAPI backend.

For this MVP, that service must:

1. Listen on the configured TCP port, for example `9443`
2. Accept the `AMON/2` bootstrap request
3. Validate the presented route session against the backend control/auth path
4. Return `accepted`, `rejected`, or `unavailable` bootstrap results
5. Read the length-prefixed packet frames after acceptance
6. Log packet summaries safely
7. Stay running while the device tunnel is connected

The repo now includes a stage-1 daemon in `tools/tunnel/amon_tunnel_daemon.py` for this purpose. It is still separate from Amon's backend and it still does not provide real internet forwarding.

## Relationship to the backend

Keep the services separate on the laptop:

- FastAPI backend: for auth, search, retrieval, compare, research
- FastAPI backend: now issues short-lived routed-local route sessions and validates them for relay bootstrap
- Tunnel endpoint: for routed-local bootstrap and packet carriage only

Recommended local split:

- backend: `http://<laptop-ip>:8000`
- tunnel endpoint: `tcp://<laptop-ip>:9443`

The tunnel endpoint must not be implemented inside the FastAPI app.

## App behavior in this MVP

- After sign-in, Amon can offer to connect the tunnel
- After session restore, Amon can reconnect automatically if enabled
- Logging out disconnects the tunnel
- Backgrounding does not force disconnect
- The in-app settings screen shows:
  - `Connected`
  - `Connecting`
  - `Disconnected`
  - `Couldn't connect`

The tunnel is additive. Search, retrieval, workspace, and privacy flows remain separate.

## Apple capability and provisioning requirements

The repo now includes:

- app entitlement file
- extension entitlement file
- packet tunnel extension target in the Xcode project

That is necessary but not sufficient for device testing.

You still need:

1. A paid Apple Developer team
2. Network Extension capability approved for your app ID / provisioning profile
3. Xcode signing configured for both the app target and the tunnel extension target
4. A physical iPhone for tunnel validation

The simulator build should compile, but real tunnel establishment needs a device.

## Local device test checklist

1. Start the backend on the laptop:

```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

2. Start the separate laptop tunnel endpoint on another port, such as `9443`:

```bash
python3 tools/tunnel/amon_tunnel_daemon.py \
  --port 9443 \
  --api-origin http://127.0.0.1:8000 \
  --relay-shared-secret amon-route-relay-dev
```
3. Install the iOS app on a physical iPhone signed with the same Apple team as the extension
4. In Amon Settings > Amon Tunnel:
   - set the laptop IP
   - set the tunnel port
   - decide whether to auto-connect when signed in
5. Sign in with the dev flow
6. Accept the tunnel prompt or connect manually
7. Confirm the status changes to `Connected`
8. Open sites from search results and inspect the laptop endpoint logs
9. Log out and confirm the tunnel disconnects

## Known MVP limits

- This is not a production VPN service
- There is no kill switch
- The backend now exposes the route-session mint/refresh/revoke surface and an internal relay-validation endpoint, but this still stops at the auth/bootstrap boundary
- There is no full forwarding relay or real internet carriage
- There is no DNS privacy path yet
- The repo still includes only a stage-2 laptop endpoint for relay auth and packet logging
- `forwarding_mode` is currently `packet_log_only`, so live traffic forwarding is still intentionally unimplemented
