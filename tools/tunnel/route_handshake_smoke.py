#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import socket
import sys

from amon_tunnel_daemon import HANDSHAKE_PROTOCOL, HANDSHAKE_REQUEST_TYPE


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send an authenticated routed-local bootstrap handshake to the local Amon tunnel daemon."
    )
    parser.add_argument("--host", default="127.0.0.1", help="Tunnel daemon host. Default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=9443, help="Tunnel daemon port. Default: 9443")
    parser.add_argument("--route-session-id", required=True, help="Route session id minted by the backend.")
    parser.add_argument("--route-access-token", required=True, help="Route access token minted by the backend.")
    parser.add_argument("--route-auth-session-id", required=True, help="Auth session id tied to the route session.")
    parser.add_argument("--request-id", default="smoke_route_bootstrap", help="Optional bootstrap request id.")
    parser.add_argument("--timeout-seconds", type=float, default=5.0, help="Socket timeout. Default: 5.0")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    payload = {
        "protocol": HANDSHAKE_PROTOCOL,
        "type": HANDSHAKE_REQUEST_TYPE,
        "request_id": args.request_id,
        "route_session_id": args.route_session_id,
        "route_access_token": args.route_access_token,
        "route_auth_session_id": args.route_auth_session_id,
        "requested_path": "local_routed",
        "transport_kind": "packet_tunnel",
        "client_platform": "ios",
        "app_bundle_id": "com.benappledev.Amon",
    }

    try:
        with socket.create_connection((args.host, args.port), timeout=args.timeout_seconds) as sock:
            sock.sendall(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8") + b"\n")
            response = sock.makefile("rb").readline()
    except OSError as exc:
        print(f"handshake transport error: {exc}", file=sys.stderr)
        return 1

    if not response:
        print("handshake failed: daemon closed the connection without a response", file=sys.stderr)
        return 1

    try:
        parsed = json.loads(response.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        print(f"handshake failed: malformed daemon response: {exc}", file=sys.stderr)
        print(response)
        return 1

    print(json.dumps(parsed, indent=2, sort_keys=True))
    return 0 if parsed.get("status") == "accepted" else 2


if __name__ == "__main__":
    raise SystemExit(main())
