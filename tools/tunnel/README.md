# Amon Tunnel Daemon

This directory contains the local laptop-side tunnel daemon for Amon's iPhone Packet Tunnel proof of concept.

It is separate from the FastAPI backend on purpose.

## What It Is

`amon_tunnel_daemon.py` is a small asyncio TCP server that speaks the current Amon tunnel extension protocol.

It proves that:

- the iPhone Packet Tunnel extension can connect to your laptop
- the handshake succeeds
- framed IP packets are arriving from the device
- packet summaries can be inspected from your laptop logs

## What It Does

The daemon:

- listens on a configurable host and port
- accepts inbound TCP connections from the iPhone tunnel extension
- reads the expected handshake request: `AMON/1`
- sends the expected handshake response: `AMON/1 OK`
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

For this stage, it is only a local proof-of-concept endpoint.

## How To Run It

From the repo root:

```bash
python3 tools/tunnel/amon_tunnel_daemon.py
```

Optional flags:

```bash
python3 tools/tunnel/amon_tunnel_daemon.py --host 0.0.0.0 --port 9443 --verbose
```

Defaults:

- host: `0.0.0.0`
- port: `9443`

## How To Use It With Amon

Run the backend separately:

```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

Run the tunnel daemon separately:

```bash
python3 tools/tunnel/amon_tunnel_daemon.py --port 9443
```

Then in the iPhone app:

1. Open `Settings > Amon Tunnel`
2. Set the laptop IP address
3. Set the tunnel port to `9443`
4. Connect the tunnel

If the Packet Tunnel extension is correctly signed and provisioned, the daemon should log:

- client connection
- handshake acceptance
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

## Manual Handshake Test

You can test the daemon without the iPhone:

```bash
python3 - <<'PY'
import socket

with socket.create_connection(("127.0.0.1", 9443), timeout=5) as sock:
    sock.sendall(b"AMON/1\n")
    print(sock.recv(64))
PY
```

Expected response:

```text
b'AMON/1 OK\n'
```

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
