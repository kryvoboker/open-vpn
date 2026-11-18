# Proposal

## Why

On the production host the container entered a restart loop with `Cannot pre-load keyfile (/etc/openvpn/pki/tls-crypt.key)`. The cause was `data/` owned by `1000:1000` with `600` key files: the container runs with `cap_drop: ALL`, so root inside it has no `CAP_DAC_OVERRIDE` and cannot read files it does not own. The entrypoint only checks that PKI files exist, so the failure surfaces as an opaque OpenVPN error and nothing tells the operator how to fix it.

## What Changes

- The entrypoint verifies, before starting OpenVPN and before generating a client profile, that every PKI file the server reads can be read by the container process.
- When a file is unreadable, the entrypoint prints which file failed, its current owner and mode, the reason (no `CAP_DAC_OVERRIDE` under `cap_drop: ALL`), and the host-side fix (`chown -R 0:0 data`), then exits non-zero without starting OpenVPN.
- Container hardening stays unchanged: no capability is added.
- `docs/deployment.md` documents that `data/` must stay owned by root, how to copy or back up `data/` without changing ownership, and how to recover from this error.

## Capabilities

### New Capabilities
- `server-startup`: Checks the container performs on its runtime data before OpenVPN starts or a client profile is generated, and how failures are reported to the operator.

### Modified Capabilities

None. No specs exist yet.

## Impact

- Code: `.docker/prod/ubuntu/entrypoint.sh`.
- Docs: `docs/deployment.md`, `docs/ARCHITECTURE.md` (startup flow), a new ADR in `docs/adr/` with its index entry.
- Behavior: a misowned `data/` still prevents startup, but now with an actionable message. With correct ownership, startup is unchanged.
- No changes to `docker-compose.yml`, `server.conf`, the image packages, or client profiles.
