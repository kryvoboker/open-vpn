# Setup and operations

## Host requirements

- Linux host with Docker Engine and the Docker Compose plugin (`docker compose`).
- `make`.
- The `tun` kernel module available as `/dev/net/tun`.
- A public IP address or domain name reachable by clients.
- UDP port `1194` open in the host firewall and any cloud security group.

## First start

1. Set `OVPN_HOST` in `.docker/prod/env/.env` to the server's public IP or domain. See [configuration.md](../configuration.md) for all variables.
2. Build the image: `make build-prod`.
3. Start the server: `make up-prod`.
4. Check the logs: `docker logs -f openvpn`. On the first start the entrypoint creates the PKI, including DH parameters, which can take several minutes.
5. Generate a client profile: `make gen-home-client`. The profile is written to `data/clients/home.ovpn`.

Run all `make` targets from the repository root: the Compose file uses `$PWD` as the build context.

## Runtime data

`data/` on the host is mounted as `/etc/openvpn` in the container. It holds the PKI (`data/pki/`) and generated client profiles (`data/clients/`). It is ignored by Git and contains private keys. Back it up and restrict access to it.

## Logs

- Container output (entrypoint and OpenVPN, `verb 3`): `docker logs openvpn`.
- Connected clients: `docker exec openvpn cat /var/log/openvpn-status.log`. This file is inside the container and is lost when the container is recreated.

## Workflow tool health gate

Workflow tools run on the host, never inside the container. Run these checks from the repository root when onboarding or when tool health is unknown:

| Tool | Check | Expected result |
|---|---|---|
| Beads | `bd where` | `.beads` in this repository, prefix `open-vpn` |
| Local Mem0 | `local-mem0 search "openvpn"` | JSON result without errors |
| Context7 | `npx ctx7@latest library "OpenVPN" "server configuration"` | Library list |
| OpenSpec | `openspec list` | Runs in this repository (requires `openspec init` first) |
| Graphify | `graphify query "entrypoint"` | Answer (requires `graphify-out/graph.json`) |
| Entire (optional) | `entire status` | Enabled state |

As of 2026-11-18, Beads is initialized. OpenSpec, Graphify output, and `.ai-factory/` are not initialized yet.
