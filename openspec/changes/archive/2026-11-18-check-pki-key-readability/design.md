# Design

## Context

See proposal.md - Why. Relevant current state in `.docker/prod/ubuntu/entrypoint.sh`:

- `init_pki_if_needed` treats the PKI as complete when `ca.crt`, `issued/server.crt`, `private/server.key`, and `dh.pem` exist. It never checks readability, `tls-crypt.key`, or `crl.pem`.
- Normal start: `init_pki_if_needed` -> `ensure_nat_rules` -> `print_client_hint` -> `exec openvpn`.
- `gen-client`: `init_pki_if_needed` -> `gen_client` -> exit.
- The script runs with `set -euo pipefail` as root, with only `NET_ADMIN`, `SETUID`, `SETGID`, `SETPCAP` capabilities. Without `CAP_DAC_OVERRIDE` and `CAP_DAC_READ_SEARCH`, root reads only files it owns or that grant "other" access.

## Goals / Non-Goals

**Goals:**
- Fail fast with an actionable message for misowned or missing PKI files, in both the start path and `gen-client`.
- Keep the check in the existing entrypoint, in its current Bash style.

**Non-Goals:**
- Fixing ownership automatically (would need `CAP_CHOWN`; option B from the investigation, rejected).
- Changing how `init_pki_if_needed` decides whether the PKI is complete.
- Checking that `crl.pem` stays readable by `nobody` after OpenVPN drops privileges.
- Validating certificate contents or expiry.

## Decisions

### 1. Probe with a real read and a real write, not `[[ -r ]]` / `[[ -w ]]`

Read check: `head -c 1 "$f" >/dev/null 2>&1`. Write check for a directory: create and remove a temporary file in it (`mktemp -p "$dir"`).

- Rationale: the test performs the same operation OpenVPN and Easy-RSA perform, so it cannot disagree with them. `[[ -r ]]` relies on `access(2)` semantics for root with a reduced capability set, which is easy to get wrong and hard to reason about in review.
- Alternative: `[[ -r ]]` / `[[ -w ]]`. Shorter, but correctness for root without `CAP_DAC_OVERRIDE` depends on kernel credential handling in `faccessat`; not chosen.

### 2. One function, three modes, called before and after initialization

Add `check_pki_access` (name follows the existing `snake_case` helpers). Modes:

- `dirs`: before `init_pki_if_needed`, in both paths. Enters and lists each existing directory (`/etc/openvpn`, `pki`, `pki/private`, `pki/issued`, `clients`); a missing `pki` or `clients` is reported when it could not be created. Easy-RSA creates `pki/`, `pki/private`, `pki/issued` with mode `700`, so after a host-side `chown -R` the `[[ -f ]]` checks in `init_pki_if_needed` see no files and it would wipe and re-create the PKI. This mode stops that.
- `server`: after `init_pki_if_needed`, before `ensure_nat_rules`. Checks the six server files, so no iptables rules are added when startup is going to fail.
- `client`: after `init_pki_if_needed`, before `gen_client`. Same files plus writability of `pki` and `clients`, so no certificate is issued.

Writability is not required in `server` mode: a running server with an existing PKI does not write to it. The top-level `mkdir -p` becomes non-fatal so that `dirs` mode, not a bare `mkdir` error, reports an unwritable `data/`.
- The function collects all failures, prints one report, then `exit 1`. Missing files and unreadable files are reported in separate lists; the `chown` hint is printed only when the unreadable list is not empty.

### 3. Report format

Use the existing `[openvpn]` log prefix. For each unreadable file print `path (owner uid:gid, mode NNN)` from `stat -c '%u:%g %a'`. Then explain the missing `CAP_DAC_OVERRIDE` and print the fix:

```
[openvpn] Cannot read PKI files:
[openvpn]   /etc/openvpn/pki/tls-crypt.key (owner 1000:1000, mode 600)
[openvpn] The container runs with cap_drop: ALL, so root can only read files it owns.
[openvpn] Fix on the host, from the project root: chown -R 0:0 data
```

`stat` reads metadata only, which needs search permission on the parent directory, not read permission on the file, so it works in the failing case. If `stat` itself fails, print `owner unknown`.

### 4. Documentation and ADR

- `docs/deployment.md`: new "Ownership of `data/`" section: keep `0:0`; never `chown` it to a login user; copy or back up with `sudo tar --numeric-owner -cpzf` and restore with `sudo tar --numeric-owner -xpzf`; recovery steps for this error.
- `docs/ARCHITECTURE.md`: add the check to the startup and client generation flows.
- New ADR `0002`: fail fast on unreadable PKI instead of adding capabilities; listed in `docs/adr/README.md`.

## Risks / Trade-offs

- [The container still restart-loops with `restart: unless-stopped`] -> Accepted: the loop now prints the fix on every attempt, which is what the operator reads in `docker logs`.
- [A PKI directory that is accessible but genuinely incomplete and not writable still fails inside Easy-RSA] -> Accepted; `dirs` mode guarantees the completeness check sees real files, so this needs a broken PKI plus partial misownership.
- [The list of server files is duplicated from `server.conf`] -> Keep the list next to `init_pki_if_needed`'s list; `docs/RULES.md` already requires changing related settings together.
- [`mktemp` leaves a file if the script is killed between create and remove] -> Negligible; the name is clearly temporary and in a root-only directory.

## Migration Plan

1. Rebuild the image (`make build-prod`) and restart (`make restart-prod`).
2. Hosts with correct ownership see no change. Hosts with wrong ownership get the new message and apply `chown -R 0:0 data`.
3. Rollback: rebuild from the previous commit; no data format changes.
