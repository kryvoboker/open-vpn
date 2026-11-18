# 0002. Fail fast on inaccessible PKI instead of adding capabilities

- **Date:** 2026-11-18
- **Status:** Accepted
- **Related:** [0001](0001-openvpn-server-in-docker.md), OpenSpec change `check-pki-key-readability`, Beads `open-vpn-mit`

## Context

The production container restart-looped with `Cannot pre-load keyfile (/etc/openvpn/pki/tls-crypt.key)`. `data/` had been changed to owner `1000:1000` on the host. Keys have mode `600`, and the container runs with `cap_drop: ALL`, so root inside it has no `CAP_DAC_OVERRIDE` and cannot read files it does not own.

Testing showed a second effect: Easy-RSA creates `pki/`, `pki/private`, and `pki/issued` with mode `700`. After `chown -R` of `data/`, the entrypoint's existence checks see no files and the entrypoint tries to wipe and re-create the PKI.

## Decision

The entrypoint checks access with real reads and writes and exits with a report before doing anything else:

- before PKI initialization: the data directories can be entered and listed, or created;
- before starting OpenVPN: the six PKI files used by `server.conf` exist and are readable;
- before issuing a client certificate: the same files, plus write access to `pki` and `clients`.

The report lists each failing path with its owner and mode, explains the missing capability, and gives the fix `chown -R 0:0 data`. Missing files are reported separately. `docs/deployment.md` documents the ownership rule and an ownership-preserving backup.

## Alternatives

- **A. Check and report (chosen).**
- **B. Add `CAP_CHOWN` and fix ownership on start.** Self-healing, but widens the container's privileges to cover an operator mistake.
- **C. Add `CAP_DAC_OVERRIDE`.** Works for any owner but removes the main benefit of `cap_drop: ALL`.
- **D. Documentation only (chosen together with A).** Cheap but does not help an operator who has not read it.

## Rationale

Ownership changes are rare manual mistakes. A clear message turns an opaque restart loop into a one-command fix, and container hardening stays as in ADR 0001.

## Consequences

- With correct ownership, behavior is unchanged.
- With wrong ownership, the container still restart-loops (`restart: unless-stopped`), but each attempt prints the cause and the fix, and the PKI is never re-initialized.
- The list of server PKI files in `entrypoint.sh` must be kept in sync with `server.conf`.
