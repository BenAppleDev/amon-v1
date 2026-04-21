from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.tunnel.amon_tunnel_daemon import (
    AmonTunnelDaemon,
    HANDSHAKE_PROTOCOL,
    HANDSHAKE_REQUEST_TYPE,
    RelayBootstrapRequest,
    RelayValidationResult,
    RelayValidationUnavailableError,
)


class StaticValidator:
    def __init__(
        self,
        *,
        result: RelayValidationResult | None = None,
        error: RelayValidationUnavailableError | None = None,
    ) -> None:
        self.result = result
        self.error = error
        self.requests: list[RelayBootstrapRequest] = []

    async def validate(self, request: RelayBootstrapRequest) -> RelayValidationResult:
        self.requests.append(request)
        if self.error is not None:
            raise self.error
        assert self.result is not None
        return self.result


def test_daemon_accepts_validated_bootstrap_and_keeps_packet_plane_open():
    async def run_test() -> None:
        validator = StaticValidator(
            result=RelayValidationResult(
                status="accepted",
                code="route_session_valid",
                message="validated",
                request_id="req_accept",
                session_id="route_123",
                user_id="user_123",
                auth_session_id="session_123",
                expires_at="2030-01-01T00:00:00Z",
            )
        )
        response = await _roundtrip(
            validator=validator,
            payload={
                "protocol": HANDSHAKE_PROTOCOL,
                "type": HANDSHAKE_REQUEST_TYPE,
                "request_id": "req_accept",
                "route_session_id": "route_123",
                "route_access_token": "a" * 32,
                "route_auth_session_id": "session_123",
                "requested_path": "local_routed",
                "transport_kind": "packet_tunnel",
                "client_platform": "ios",
            },
            packet_after_handshake=b"\x00\x14" + (b"\x45" + b"\x00" * 19),
        )

        assert response["status"] == "accepted"
        assert response["relay_auth_state"] == "accepted"
        assert response["packet_plane_ready"] is True
        assert response["forwarding_ready"] is False
        assert validator.requests[0].route_session_id == "route_123"

    asyncio.run(run_test())


def test_daemon_rejects_malformed_bootstrap_without_calling_validator():
    async def run_test() -> None:
        validator = StaticValidator(
            result=RelayValidationResult(
                status="accepted",
                code="route_session_valid",
                message="validated",
            )
        )
        response = await _roundtrip_raw(
            validator=validator,
            raw_line=b'{"protocol":"AMON/2","type":"bootstrap"\n',
        )

        assert response["status"] == "rejected"
        assert response["code"] == "malformed_bootstrap_request"
        assert validator.requests == []

    asyncio.run(run_test())


def test_daemon_surfaces_relay_rejection_and_unavailability():
    async def run_test() -> None:
        rejected = await _roundtrip(
            validator=StaticValidator(
                result=RelayValidationResult(
                    status="rejected",
                    code="route_session_expired",
                    message="expired",
                    request_id="req_reject",
                )
            ),
            payload=_valid_payload(request_id="req_reject"),
        )
        assert rejected["status"] == "rejected"
        assert rejected["code"] == "route_session_expired"

        unavailable = await _roundtrip(
            validator=StaticValidator(
                error=RelayValidationUnavailableError(
                    code="relay_validation_unavailable",
                    message="backend offline",
                )
            ),
            payload=_valid_payload(request_id="req_unavailable"),
        )
        assert unavailable["status"] == "unavailable"
        assert unavailable["code"] == "relay_validation_unavailable"

    asyncio.run(run_test())


async def _roundtrip(
    *,
    validator: StaticValidator,
    payload: dict[str, object],
    packet_after_handshake: bytes | None = None,
) -> dict[str, object]:
    return await _roundtrip_raw(
        validator=validator,
        raw_line=json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8") + b"\n",
        packet_after_handshake=packet_after_handshake,
    )


async def _roundtrip_raw(
    *,
    validator: StaticValidator,
    raw_line: bytes,
    packet_after_handshake: bytes | None = None,
) -> dict[str, object]:
    server = await asyncio.start_server(
        AmonTunnelDaemon(host="127.0.0.1", port=0, validator=validator)._handle_client,
        host="127.0.0.1",
        port=0,
    )
    try:
        sockname = server.sockets[0].getsockname()
        reader, writer = await asyncio.open_connection(sockname[0], sockname[1])
        try:
            writer.write(raw_line)
            await writer.drain()
            response = await reader.readline()
            if packet_after_handshake is not None:
                writer.write(packet_after_handshake)
                await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()
    finally:
        server.close()
        await server.wait_closed()

    return json.loads(response.decode("utf-8"))


def _valid_payload(*, request_id: str) -> dict[str, object]:
    return {
        "protocol": HANDSHAKE_PROTOCOL,
        "type": HANDSHAKE_REQUEST_TYPE,
        "request_id": request_id,
        "route_session_id": "route_123",
        "route_access_token": "a" * 32,
        "route_auth_session_id": "session_123",
        "requested_path": "local_routed",
        "transport_kind": "packet_tunnel",
        "client_platform": "ios",
    }
