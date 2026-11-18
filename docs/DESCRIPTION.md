# Project description

## Purpose

OpenVpn is a self-hosted OpenVPN server packaged as one Docker container. It gives a small number of personal devices a full-tunnel VPN: all client traffic goes through the server to the internet.

## Implemented capabilities

- Docker image based on Ubuntu 24.04 with OpenVPN, Easy-RSA, and iptables.
- Automatic PKI creation on first start: CA, server certificate, DH parameters, CRL, and `tls-crypt` key. All keys are created without passphrases.
- Reuse of an existing PKI on restart; an incomplete PKI is wiped and recreated.
- Server on UDP `1194`, subnet `10.8.0.0/24`, full tunnel (`redirect-gateway def1`), DNS `1.1.1.1` and `8.8.8.8` pushed to clients.
- NAT (MASQUERADE) and forwarding rules from `tun0` to the default outbound interface, added without duplicates.
- Client profile generation (`gen-client <name>`) producing a single inline `.ovpn` file with CA, certificate, key, and `tls-crypt` key.
- CRL verification on the server.
- Container hardening: all capabilities dropped except `NET_ADMIN`, `SETUID`, `SETGID`, `SETPCAP`; `no-new-privileges`; AppArmor `docker-default`.
- `make` targets for build, start, stop, restart, and generating the `home` client.

## Not implemented

- Client certificate revocation command (the CRL exists but there is no wrapper to revoke and regenerate it).
- Client profile listing or removal.
- TCP transport or a configurable server port (see [configuration.md](configuration.md)).
- Monitoring, automated backups, automated tests.
