#!/usr/bin/env python3
"""Local development tunnel daemon for the Amon iOS Packet Tunnel extension.

This is a proof-of-concept endpoint for local testing only. It accepts the
current extension handshake, logs incoming IP packets, and keeps the tunnel
socket open. It does not forward traffic to the internet.
"""

from __future__ import annotations

import argparse
import asyncio
import contextlib
import ipaddress
import logging
import signal
from itertools import count
from typing import Final

LOGGER = logging.getLogger("amon_tunnel_daemon")

DEFAULT_HOST: Final[str] = "0.0.0.0"
DEFAULT_PORT: Final[int] = 9443
HANDSHAKE_REQUEST: Final[bytes] = b"AMON/1"
HANDSHAKE_RESPONSE: Final[bytes] = b"AMON/1 OK\n"
HANDSHAKE_TIMEOUT_SECONDS: Final[float] = 5.0
MAX_HANDSHAKE_LINE_BYTES: Final[int] = 64


class AmonTunnelDaemon:
    def __init__(self, host: str, port: int) -> None:
        self.host = host
        self.port = port
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
            LOGGER.warning("Client %s timed out waiting for handshake", client_id)
            return False
        except asyncio.LimitOverrunError:
            discarded = await reader.read(MAX_HANDSHAKE_LINE_BYTES)
            LOGGER.warning("Client %s sent oversized handshake %r", client_id, discarded)
            return False
        except asyncio.IncompleteReadError as error:
            received = error.partial.rstrip(b"\r\n")
            LOGGER.warning("Client %s disconnected during handshake with %r", client_id, received)
            return False

        request = line.rstrip(b"\r\n")
        if request != HANDSHAKE_REQUEST:
            LOGGER.warning("Client %s rejected invalid handshake %r", client_id, request)
            return False

        writer.write(HANDSHAKE_RESPONSE)
        await writer.drain()
        LOGGER.info("Client %s handshake accepted", client_id)
        return True

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

    daemon = AmonTunnelDaemon(host=args.host, port=args.port)
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
