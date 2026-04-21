#!/usr/bin/env python3
"""Local development tunnel daemon for the Amon iOS Packet Tunnel extension.

This daemon now terminates an authenticated bootstrap handshake before it begins
reading framed packets. It still does not forward traffic to the internet.
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import ipaddress
import json
import logging
import os
import signal
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from itertools import count
from typing import Final

LOGGER = logging.getLogger("amon_tunnel_daemon")

DEFAULT_HOST: Final[str] = "0.0.0.0"
DEFAULT_PORT: Final[int] = 9443
DEFAULT_API_ORIGIN: Final[str] = "http://127.0.0.1:8000"
DEFAULT_ROUTE_RELAY_SECRET: Final[str] = "amon-route-relay-dev"
DEFAULT_ROUTE_RELAY_SECRET_HEADER: Final[str] = "X-Amon-Route-Relay-Secret"
VALIDATION_ENDPOINT_PATH: Final[str] = "/internal/route-sessions/validate"
HANDSHAKE_PROTOCOL: Final[str] = "AMON/2"
HANDSHAKE_REQUEST_TYPE: Final[str] = "bootstrap"
HANDSHAKE_RESPONSE_TYPE: Final[str] = "bootstrap_result"
HANDSHAKE_TIMEOUT_SECONDS: Final[float] = 5.0
MAX_HANDSHAKE_LINE_BYTES: Final[int] = 8_192
DEFAULT_VALIDATION_TIMEOUT_SECONDS: Final[float] = 5.0


@dataclass
class RelayBootstrapRequest:
    request_id: str | None
    route_session_id: str | None
    route_access_token: str | None
    route_auth_session_id: str | None
    requested_path: str
    transport_kind: str
    client_platform: str | None
    app_bundle_id: str | None

    @classmethod
    def from_line(cls, line: bytes) -> "RelayBootstrapRequest":
        try:
            payload = json.loads(line.decode("utf-8"))
        except UnicodeDecodeError as exc:
            raise BootstrapProtocolError(
                code="malformed_bootstrap_request",
                message="The tunnel bootstrap request was not valid UTF-8.",
            ) from exc
        except json.JSONDecodeError as exc:
            raise BootstrapProtocolError(
                code="malformed_bootstrap_request",
                message="The tunnel bootstrap request was not valid JSON.",
            ) from exc

        if not isinstance(payload, dict):
            raise BootstrapProtocolError(
                code="malformed_bootstrap_request",
                message="The tunnel bootstrap request must be a JSON object.",
            )

        if payload.get("protocol") != HANDSHAKE_PROTOCOL:
            raise BootstrapProtocolError(
                code="unsupported_bootstrap_protocol",
                message=f"The tunnel bootstrap request must declare protocol {HANDSHAKE_PROTOCOL}.",
            )

        if payload.get("type") != HANDSHAKE_REQUEST_TYPE:
            raise BootstrapProtocolError(
                code="unsupported_bootstrap_type",
                message=f"The tunnel bootstrap request type must be {HANDSHAKE_REQUEST_TYPE}.",
            )

        return cls(
            request_id=_optional_string(payload.get("request_id")),
            route_session_id=_optional_string(payload.get("route_session_id")),
            route_access_token=_optional_string(payload.get("route_access_token")),
            route_auth_session_id=_optional_string(payload.get("route_auth_session_id")),
            requested_path=_string_or_default(payload.get("requested_path"), default="local_routed"),
            transport_kind=_string_or_default(payload.get("transport_kind"), default="packet_tunnel"),
            client_platform=_optional_string(payload.get("client_platform")),
            app_bundle_id=_optional_string(payload.get("app_bundle_id")),
        )

    @property
    def safe_summary(self) -> str:
        return (
            f"request_id={self.request_id or '<missing>'} "
            f"route_session_id={self.route_session_id or '<missing>'} "
            f"route_auth_session_id={self.route_auth_session_id or '<missing>'} "
            f"requested_path={self.requested_path} transport_kind={self.transport_kind} "
            f"client_platform={self.client_platform or '<missing>'}"
        )

    def validation_payload(self) -> dict[str, object]:
        return {
            "request_id": self.request_id,
            "route_session_id": self.route_session_id,
            "route_access_token": self.route_access_token,
            "route_auth_session_id": self.route_auth_session_id,
            "requested_path": self.requested_path,
            "transport_kind": self.transport_kind,
            "client_platform": self.client_platform,
            "app_bundle_id": self.app_bundle_id,
        }


@dataclass
class RelayValidationResult:
    status: str
    code: str
    message: str
    request_id: str | None = None
    session_id: str | None = None
    user_id: str | None = None
    auth_session_id: str | None = None
    route_kind: str | None = None
    transport_kind: str | None = None
    control_plane_kind: str | None = None
    expires_at: str | None = None

    @classmethod
    def from_payload(cls, payload: object) -> "RelayValidationResult":
        if not isinstance(payload, dict):
            raise RelayValidationUnavailableError(
                code="relay_validation_malformed_response",
                message="The backend relay validation response was not a JSON object.",
            )

        status = _string_or_default(payload.get("status"), default="")
        code = _string_or_default(payload.get("code"), default="")
        message = _string_or_default(payload.get("message"), default="")
        if status not in {"accepted", "rejected"} or not code or not message:
            raise RelayValidationUnavailableError(
                code="relay_validation_malformed_response",
                message="The backend relay validation response was missing required fields.",
            )

        return cls(
            status=status,
            code=code,
            message=message,
            request_id=_optional_string(payload.get("request_id")),
            session_id=_optional_string(payload.get("session_id")),
            user_id=_optional_string(payload.get("user_id")),
            auth_session_id=_optional_string(payload.get("auth_session_id")),
            route_kind=_optional_string(payload.get("route_kind")),
            transport_kind=_optional_string(payload.get("transport_kind")),
            control_plane_kind=_optional_string(payload.get("control_plane_kind")),
            expires_at=_optional_string(payload.get("expires_at")),
        )


@dataclass
class RelayBootstrapResponse:
    status: str
    code: str
    message: str
    relay_auth_state: str
    packet_plane_ready: bool
    forwarding_mode: str = "packet_log_only"
    forwarding_ready: bool = False
    request_id: str | None = None
    session_id: str | None = None
    user_id: str | None = None
    auth_session_id: str | None = None
    expires_at: str | None = None
    protocol: str = HANDSHAKE_PROTOCOL
    type: str = HANDSHAKE_RESPONSE_TYPE

    def to_bytes(self) -> bytes:
        payload = asdict(self)
        return json.dumps(payload, separators=(",", ":"), sort_keys=True).encode("utf-8") + b"\n"


class BootstrapProtocolError(Exception):
    def __init__(self, *, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class RelayValidationUnavailableError(Exception):
    def __init__(self, *, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class BackendRouteRelayValidator:
    def __init__(
        self,
        *,
        api_origin: str,
        shared_secret: str,
        shared_secret_header: str = DEFAULT_ROUTE_RELAY_SECRET_HEADER,
        timeout_seconds: float = DEFAULT_VALIDATION_TIMEOUT_SECONDS,
    ) -> None:
        self.validation_url = urllib.parse.urljoin(api_origin.rstrip("/") + "/", VALIDATION_ENDPOINT_PATH.lstrip("/"))
        self.shared_secret = shared_secret
        self.shared_secret_header = shared_secret_header
        self.timeout_seconds = timeout_seconds

    async def validate(self, request: RelayBootstrapRequest) -> RelayValidationResult:
        return await asyncio.to_thread(self._validate_sync, request)

    def _validate_sync(self, request: RelayBootstrapRequest) -> RelayValidationResult:
        encoded_request = json.dumps(request.validation_payload(), separators=(",", ":"), sort_keys=True).encode("utf-8")
        http_request = urllib.request.Request(
            self.validation_url,
            data=encoded_request,
            method="POST",
            headers={
                "Content-Type": "application/json",
                self.shared_secret_header: self.shared_secret,
            },
        )

        try:
            with urllib.request.urlopen(http_request, timeout=self.timeout_seconds) as response:
                body = response.read()
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RelayValidationUnavailableError(
                code="relay_validation_http_error",
                message=f"Relay validation returned HTTP {exc.code}: {detail[:200]}",
            ) from exc
        except urllib.error.URLError as exc:
            raise RelayValidationUnavailableError(
                code="relay_validation_unavailable",
                message=f"Relay validation could not reach the backend: {exc.reason}",
            ) from exc

        try:
            payload = json.loads(body.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise RelayValidationUnavailableError(
                code="relay_validation_malformed_response",
                message="Relay validation returned a malformed response.",
            ) from exc

        return RelayValidationResult.from_payload(payload)


class AmonTunnelDaemon:
    def __init__(self, host: str, port: int, *, validator: BackendRouteRelayValidator) -> None:
        self.host = host
        self.port = port
        self.validator = validator
        self._shutdown_event = asyncio.Event()
        self._next_client_id = count(1)
        self._client_writers: dict[int, asyncio.StreamWriter] = {}
        self._server: asyncio.AbstractServer | None = None

    async def run(self) -> None:
        self._install_signal_handlers()

        self._server = await asyncio.start_server(
            self._handle_client,
            host=self.host,
            port=self.port,
        )

        bound_addresses = ", ".join(_format_sockname(sock.getsockname()) for sock in self._server.sockets or [])
        LOGGER.info("Amon tunnel daemon listening on %s", bound_addresses or f"{self.host}:{self.port}")

        async with self._server:
            await self._shutdown_event.wait()

        LOGGER.info("Shutting down Amon tunnel daemon")
        self._server.close()
        await self._server.wait_closed()
        await self._close_active_connections()

    def request_shutdown(self) -> None:
        if self._shutdown_event.is_set():
            return
        LOGGER.info("Shutdown requested")
        self._shutdown_event.set()

    def _install_signal_handlers(self) -> None:
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGINT, signal.SIGTERM):
            try:
                loop.add_signal_handler(sig, self.request_shutdown)
            except NotImplementedError:
                signal.signal(sig, lambda *_: self.request_shutdown())

    async def _handle_client(
        self,
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter,
    ) -> None:
        client_id = next(self._next_client_id)
        self._client_writers[client_id] = writer

        peer = _format_peer(writer.get_extra_info("peername"))
        LOGGER.info("Client %s connected from %s", client_id, peer)

        try:
            accepted = await self._perform_handshake(client_id, reader, writer)
            if not accepted:
                return

            await self._read_packets(client_id, reader)
        except Exception:
            LOGGER.exception("Client %s crashed unexpectedly", client_id)
        finally:
            self._client_writers.pop(client_id, None)
            writer.close()
            with contextlib.suppress(ConnectionError, OSError):
                await writer.wait_closed()
            LOGGER.info("Client %s disconnected", client_id)

    async def _perform_handshake(
        self,
        client_id: int,
        reader: asyncio.StreamReader,
        writer: asyncio.StreamWriter,
    ) -> bool:
        try:
            line = await asyncio.wait_for(reader.readuntil(b"\n"), timeout=HANDSHAKE_TIMEOUT_SECONDS)
        except asyncio.TimeoutError:
            LOGGER.warning("Client %s timed out waiting for bootstrap handshake", client_id)
            await self._send_bootstrap_response(
                writer,
                RelayBootstrapResponse(
                    status="unavailable",
                    code="bootstrap_timeout",
                    message="The relay timed out waiting for the tunnel bootstrap request.",
                    relay_auth_state="unavailable",
                    packet_plane_ready=False,
                ),
            )
            return False
        except asyncio.LimitOverrunError:
            LOGGER.warning("Client %s sent oversized bootstrap handshake", client_id)
            await self._send_bootstrap_response(
                writer,
                RelayBootstrapResponse(
                    status="rejected",
                    code="malformed_bootstrap_request",
                    message="The tunnel bootstrap request exceeded the maximum allowed size.",
                    relay_auth_state="rejected",
                    packet_plane_ready=False,
                ),
            )
            return False
        except asyncio.IncompleteReadError as error:
            received = error.partial.rstrip(b"\r\n")
            LOGGER.warning("Client %s disconnected during bootstrap with %r", client_id, received)
            return False

        if len(line) > MAX_HANDSHAKE_LINE_BYTES:
            LOGGER.warning("Client %s sent bootstrap larger than %d bytes", client_id, MAX_HANDSHAKE_LINE_BYTES)
            await self._send_bootstrap_response(
                writer,
                RelayBootstrapResponse(
                    status="rejected",
                    code="malformed_bootstrap_request",
                    message="The tunnel bootstrap request exceeded the maximum allowed size.",
                    relay_auth_state="rejected",
                    packet_plane_ready=False,
                ),
            )
            return False

        request_line = line.rstrip(b"\r\n")
        try:
            bootstrap_request = RelayBootstrapRequest.from_line(request_line)
        except BootstrapProtocolError as exc:
            LOGGER.warning("Client %s rejected malformed bootstrap: %s", client_id, exc.message)
            await self._send_bootstrap_response(
                writer,
                RelayBootstrapResponse(
                    status="rejected",
                    code=exc.code,
                    message=exc.message,
                    relay_auth_state="rejected",
                    packet_plane_ready=False,
                ),
            )
            return False

        LOGGER.info("Client %s bootstrap request %s", client_id, bootstrap_request.safe_summary)

        try:
            validation = await self.validator.validate(bootstrap_request)
        except RelayValidationUnavailableError as exc:
            LOGGER.warning("Client %s relay validation unavailable: %s", client_id, exc.message)
            await self._send_bootstrap_response(
                writer,
                RelayBootstrapResponse(
                    status="unavailable",
                    code=exc.code,
                    message=exc.message,
                    relay_auth_state="unavailable",
                    packet_plane_ready=False,
                    request_id=bootstrap_request.request_id,
                ),
            )
            return False

        if validation.status != "accepted":
            LOGGER.warning(
                "Client %s relay validation rejected code=%s request_id=%s",
                client_id,
                validation.code,
                bootstrap_request.request_id or "<missing>",
            )
            await self._send_bootstrap_response(
                writer,
                RelayBootstrapResponse(
                    status="rejected",
                    code=validation.code,
                    message=validation.message,
                    relay_auth_state="rejected",
                    packet_plane_ready=False,
                    request_id=validation.request_id,
                ),
            )
            return False

        response = RelayBootstrapResponse(
            status="accepted",
            code=validation.code,
            message=validation.message,
            relay_auth_state="accepted",
            packet_plane_ready=True,
            request_id=validation.request_id,
            session_id=validation.session_id,
            user_id=validation.user_id,
            auth_session_id=validation.auth_session_id,
            expires_at=validation.expires_at,
        )
        await self._send_bootstrap_response(writer, response)
        LOGGER.info(
            "Client %s bootstrap accepted session_id=%s auth_session_id=%s user_id=%s forwarding_mode=%s",
            client_id,
            validation.session_id or "<missing>",
            validation.auth_session_id or "<missing>",
            validation.user_id or "<missing>",
            response.forwarding_mode,
        )
        return True

    async def _send_bootstrap_response(
        self,
        writer: asyncio.StreamWriter,
        response: RelayBootstrapResponse,
    ) -> None:
        writer.write(response.to_bytes())
        await writer.drain()

    async def _read_packets(self, client_id: int, reader: asyncio.StreamReader) -> None:
        while not self._shutdown_event.is_set():
            try:
                header = await reader.readexactly(2)
            except asyncio.IncompleteReadError as error:
                if error.partial:
                    LOGGER.warning(
                        "Client %s disconnected mid-frame header after %d bytes",
                        client_id,
                        len(error.partial),
                    )
                return

            packet_length = int.from_bytes(header, byteorder="big")
            if packet_length == 0:
                LOGGER.warning("Client %s sent empty packet frame", client_id)
                continue

            try:
                packet = await reader.readexactly(packet_length)
            except asyncio.IncompleteReadError as error:
                LOGGER.warning(
                    "Client %s disconnected mid-packet: expected=%d received=%d",
                    client_id,
                    packet_length,
                    len(error.partial),
                )
                return

            LOGGER.info(
                "Client %s packet length=%d %s",
                client_id,
                packet_length,
                summarize_packet(packet),
            )

    async def _close_active_connections(self) -> None:
        for client_id, writer in list(self._client_writers.items()):
            LOGGER.info("Closing client %s", client_id)
            writer.close()

        for client_id, writer in list(self._client_writers.items()):
            with contextlib.suppress(ConnectionError, OSError):
                await writer.wait_closed()
            self._client_writers.pop(client_id, None)


def summarize_packet(packet: bytes) -> str:
    if not packet:
        return "packet=empty"

    version = packet[0] >> 4
    if version == 4:
        return _summarize_ipv4_packet(packet)
    if version == 6:
        return _summarize_ipv6_packet(packet)
    return f"packet=unrecognized version={version} bytes={len(packet)}"


def _summarize_ipv4_packet(packet: bytes) -> str:
    if len(packet) < 20:
        return f"packet=ipv4-truncated bytes={len(packet)}"

    header_length = (packet[0] & 0x0F) * 4
    if header_length < 20 or len(packet) < header_length:
        return f"packet=ipv4-invalid-header header_len={header_length} bytes={len(packet)}"

    protocol = packet[9]
    src_ip = str(ipaddress.IPv4Address(packet[12:16]))
    dst_ip = str(ipaddress.IPv4Address(packet[16:20]))
    total_length = int.from_bytes(packet[2:4], byteorder="big")

    return (
        f"packet=ipv4 version=4 protocol={protocol} "
        f"src={src_ip} dst={dst_ip} total_len={total_length}"
    )


def _summarize_ipv6_packet(packet: bytes) -> str:
    if len(packet) < 40:
        return f"packet=ipv6-truncated bytes={len(packet)}"

    next_header = packet[6]
    src_ip = str(ipaddress.IPv6Address(packet[8:24]))
    dst_ip = str(ipaddress.IPv6Address(packet[24:40]))
    payload_length = int.from_bytes(packet[4:6], byteorder="big")

    return (
        f"packet=ipv6 version=6 next_header={next_header} "
        f"src={src_ip} dst={dst_ip} payload_len={payload_length}"
    )


def _optional_string(value: object) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        cleaned = value.strip()
        return cleaned or None
    return None


def _string_or_default(value: object, *, default: str) -> str:
    if isinstance(value, str):
        cleaned = value.strip()
        if cleaned:
            return cleaned
    return default


def _format_peer(peer: object) -> str:
    if isinstance(peer, tuple):
        return ":".join(str(part) for part in peer)
    return str(peer or "unknown")


def _format_sockname(sockname: object) -> str:
    if isinstance(sockname, tuple):
        return ":".join(str(part) for part in sockname[:2])
    return str(sockname)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the local Amon development tunnel daemon."
    )
    parser.add_argument("--host", default=DEFAULT_HOST, help=f"Host to bind to. Default: {DEFAULT_HOST}")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help=f"Port to listen on. Default: {DEFAULT_PORT}")
    parser.add_argument(
        "--api-origin",
        default=os.environ.get("AMON_API_ORIGIN", DEFAULT_API_ORIGIN),
        help=f"Backend origin used for route-session validation. Default: {DEFAULT_API_ORIGIN}",
    )
    parser.add_argument(
        "--relay-shared-secret",
        default=os.environ.get("ROUTE_RELAY_SHARED_SECRET", DEFAULT_ROUTE_RELAY_SECRET),
        help="Shared secret presented to the backend relay-validation endpoint.",
    )
    parser.add_argument(
        "--relay-shared-secret-header",
        default=DEFAULT_ROUTE_RELAY_SECRET_HEADER,
        help=f"Header used for relay validation auth. Default: {DEFAULT_ROUTE_RELAY_SECRET_HEADER}",
    )
    parser.add_argument(
        "--validation-timeout-seconds",
        type=float,
        default=DEFAULT_VALIDATION_TIMEOUT_SECONDS,
        help=f"Timeout for backend relay validation requests. Default: {DEFAULT_VALIDATION_TIMEOUT_SECONDS}",
    )
    parser.add_argument("--verbose", action="store_true", help="Enable debug logging.")
    return parser.parse_args()


def configure_logging(verbose: bool) -> None:
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


async def _async_main() -> int:
    args = parse_args()
    configure_logging(args.verbose)

    validator = BackendRouteRelayValidator(
        api_origin=args.api_origin,
        shared_secret=args.relay_shared_secret,
        shared_secret_header=args.relay_shared_secret_header,
        timeout_seconds=args.validation_timeout_seconds,
    )
    daemon = AmonTunnelDaemon(host=args.host, port=args.port, validator=validator)
    await daemon.run()
    return 0


def main() -> int:
    try:
        return asyncio.run(_async_main())
    except KeyboardInterrupt:
        LOGGER.info("Interrupted")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
