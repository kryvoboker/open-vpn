# Project rules

These rules apply to every change in OpenVpn. The root `AGENTS.md` / `CLAUDE.md` instructions take precedence.

## Security

1. Never commit `data/`, private keys, certificates, `.ovpn` profiles, or `tls-crypt.key`.
2. Never put real secrets or personal data in documentation, issues, or memory records. Use placeholders such as `<server-ip>`.
3. Keep the container hardening in `docker-compose.yml` (`cap_drop: ALL`, `no-new-privileges`, AppArmor profile). Add a capability only with an ADR that explains why.
4. Keep OpenVPN dropping privileges to `nobody:nogroup` after startup.
5. Do not weaken crypto settings (`tls-version-min 1.2`, AEAD data ciphers, `tls-crypt`) without an ADR.

## Consistency

1. Server settings exist in three places that must agree: `server.conf` (port, protocol, subnet), `docker-compose.yml` (published port), and the client template in `entrypoint.sh`. Change them together.
2. The VPN subnet `10.8.0.0/24` appears in `server.conf` and in the NAT rules in `entrypoint.sh`. Change both together.
3. The entrypoint must stay idempotent: restarting the container must not rebuild an existing PKI or duplicate iptables rules.

## Process

1. Track work in Beads (prefix `open-vpn`).
2. Record any change in behavior, added or removed functionality, or security posture in an ADR under `docs/adr/`.
3. Update the affected documents in `docs/` in the same change.
4. Run application tooling (OpenVPN, Easy-RSA) inside the container; run workflow tools on the host.
