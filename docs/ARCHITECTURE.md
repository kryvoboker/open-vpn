# Architecture

## Components

```
Client (.ovpn) ──UDP 1194──► Host :1194 ──► container "openvpn"
                                             ├─ entrypoint.sh  (PKI, NAT, client profiles)
                                             ├─ openvpn        (server.conf, tun0, 10.8.0.0/24)
                                             └─ /etc/openvpn ◄── bind mount ── ./data
                                                       │
                                     tun0 ──NAT──► default interface ──► Internet
```

| Component | Source | Responsibility |
|---|---|---|
| Image | `.docker/prod/ubuntu/Dockerfile` | Installs OpenVPN, Easy-RSA, iptables; sets timezone; copies the entrypoint |
| Entrypoint | `.docker/prod/ubuntu/entrypoint.sh` | Creates the PKI, adds NAT rules, generates client profiles, starts OpenVPN |
| Server config | `.docker/prod/ubuntu/server.conf` | OpenVPN server settings; mounted read-only |
| Compose | `.docker/prod/docker-compose.yml` | Service definition, ports, volumes, capabilities, sysctls |
| Environment | `.docker/prod/env/.env` | Public host, port, and protocol written into client profiles |
| Make targets | `Makefile` | Operator commands |
| Runtime data | `data/` (not in Git) | PKI and client profiles |

## Startup flow

1. Resolve the `easyrsa` binary.
2. Fail if `OVPN_HOST` is not set; default `OVPN_PORT=1194`, `OVPN_PROTO=udp`.
3. If `ca.crt`, `issued/server.crt`, `private/server.key`, and `dh.pem` exist, keep the PKI. Otherwise wipe `pki/` and create CA, server certificate, DH, CRL, and `tls-crypt.key`.
4. Detect the default outbound interface and add MASQUERADE and FORWARD rules if they are missing.
5. `exec openvpn --config /etc/openvpn/server.conf`. OpenVPN then drops to `nobody:nogroup`.

## Client generation flow

`docker exec -it openvpn /entrypoint.sh gen-client <name>` runs steps 1–3, issues a client certificate with Easy-RSA, and writes `/etc/openvpn/clients/<name>.ovpn` (host: `data/clients/<name>.ovpn`). It does not start a second OpenVPN process.

## Boundaries

- `server.conf` is mounted read-only over the bind-mounted `data/`; it is not stored in `data/`.
- Values from `.env` affect only client profiles. The server port and protocol come from `server.conf` and the published port from `docker-compose.yml`.
- The status log `/var/log/openvpn-status.log` is not persisted.
