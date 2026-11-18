# Configuration

## Environment file

Docker Compose loads `.docker/prod/env/.env` into the container.

| Variable | Required | Default | Used by | Effect |
|---|---|---|---|---|
| `OVPN_HOST` | Yes | — | `entrypoint.sh` | Public IP or domain written as `remote` in client profiles. The container exits if it is unset |
| `OVPN_PORT` | No | `1194` | `entrypoint.sh` | Port written in client profiles only |
| `OVPN_PROTO` | No | `udp` | `entrypoint.sh` | Protocol written in client profiles only |
| `UMASK` | No | `0002` | `entrypoint.sh` | File creation mask for the entrypoint |
| `UID`, `GID` | No | — | Nothing | Present in the file but not used by Compose or the entrypoint |

> The `.env` file is ignored by Git. Create it on each host with the variables above. Earlier commits still contain a copy of it.

### Changing the port or protocol

`OVPN_PORT` and `OVPN_PROTO` do not change the server. To serve on another port or protocol, change all three places together:

1. `port` and `proto` in `.docker/prod/ubuntu/server.conf`.
2. `ports` in `.docker/prod/docker-compose.yml`.
3. `OVPN_PORT` / `OVPN_PROTO` in `.env`, then regenerate client profiles.

## Server settings (`server.conf`)

| Setting | Value |
|---|---|
| Transport | UDP `1194`, `dev tun`, `topology subnet` |
| VPN subnet | `10.8.0.0/24` (also hard-coded in NAT rules in `entrypoint.sh`) |
| Routing | `redirect-gateway def1 bypass-dhcp` (full tunnel) |
| DNS pushed | `1.1.1.1`, `8.8.8.8` |
| Crypto | `tls-crypt`, `tls-version-min 1.2`, `auth SHA256`, data ciphers `AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305` |
| Revocation | `crl-verify /etc/openvpn/pki/crl.pem` |
| Privileges | `user nobody`, `group nogroup` |
| Logging | `verb 3`, status in `/var/log/openvpn-status.log` |

To give clients access to Docker or local networks, add a `push "route ..."` line (an example is commented at the end of `server.conf`).

## Image settings

- Base image: `ubuntu:24.04`.
- Timezone: `TZ=Europe/Kyiv` in the Dockerfile.
- Image tag: `openvpn-server:1.0`; container name: `openvpn`.
