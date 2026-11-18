# 0001. OpenVPN server in a single Docker container with Easy-RSA PKI

- **Date:** 2026-11-18
- **Status:** Accepted (records the design already in the repository at commit `8f4b988`)

## Context

The project needs a personal full-tunnel VPN that is easy to rebuild on a new host and keeps its keys between restarts.

## Decision

- Run OpenVPN in one container built from `ubuntu:24.04` and started with Docker Compose.
- Create the PKI with Easy-RSA inside the container on first start and keep it in a bind-mounted `data/` directory.
- Use certificate authentication with `tls-crypt`, TLS 1.2+, and AEAD data ciphers; keys have no passphrases so the server starts unattended.
- Route all client traffic through the server with NAT added by the entrypoint.
- Drop all container capabilities except `NET_ADMIN`, `SETUID`, `SETGID`, `SETPCAP`.
- Generate inline `.ovpn` client profiles through the entrypoint.

## Alternatives

- **Prebuilt images (e.g. kylemanna/openvpn):** less code to maintain, but less control over the base image and settings.
- **WireGuard:** simpler and faster, but not chosen for this project.
- **OpenVPN on the host without Docker:** harder to reproduce and isolate.

## Consequences

- `data/` holds all key material and must be backed up and protected.
- Keys without passphrases mean anyone with access to `data/` can impersonate the server or clients.
- Port, protocol, and subnet are duplicated across `server.conf`, `docker-compose.yml`, and `entrypoint.sh` and must be changed together.
- Client revocation is supported by the server (CRL) but has no operator command yet.
