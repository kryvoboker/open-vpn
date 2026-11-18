# Tasks

## 1. Entrypoint access check

- [x] 1.1 Add `check_pki_access` to `.docker/prod/ubuntu/entrypoint.sh` per design.md decisions 1-3 (real read probe for the six server PKI files, `mktemp` write probe for `pki/` and `clients/` in `client` mode, separate missing and unreadable lists, one report, `exit 1`); verify with `bash -n .docker/prod/ubuntu/entrypoint.sh`
- [x] 1.2 Call `check_pki_access server` after `init_pki_if_needed` and before `ensure_nat_rules` in the start path, and `check_pki_access client` after `init_pki_if_needed` and before `gen_client` in the `gen-client` branch; verify by reading the final script that no iptables rule or certificate can be created before the check
- [x] 1.3 Fix the client hint path in `print_client_hint` from `./clients/` to `./data/clients/`; verify the printed text
- [x] 1.4 Add the `dirs` mode to `check_pki_access` per design.md decision 2, call it before `init_pki_if_needed` in both paths, and make the top-level `mkdir -p` non-fatal; verify with `bash -n` and by reading that no Easy-RSA call can run before it

## 2. Manual verification on a throwaway PKI

Use a disposable `data` copy in the scratchpad, never the real `data/` with production keys. Let Docker create the disposable directory so it is owned by root, as on a fresh host. Run all of group 2 after task 1.4.

- [x] 2.1 Build the image and start a container on an empty disposable data dir; verify the PKI is created and the log reaches `Initialization Sequence Completed` (spec: all PKI files readable)
- [x] 2.2 `chown 1000:1000` and `chmod 600` the disposable `tls-crypt.key`, restart; verify the container exits non-zero, the log lists the path, `1000:1000`, `600`, and `chown -R 0:0 data`, and `Cannot pre-load keyfile` is absent
- [x] 2.3 Make `private/server.key` unreadable as well; verify both files appear in one report
- [x] 2.4 Remove `tls-crypt.key`; verify it is reported as missing without a `chown` hint
- [x] 2.5 `chown -R 1000:1000` the disposable data dir and run `gen-client laptop`; verify a non-zero exit with the report and no `issued/laptop.crt` or `clients/laptop.ovpn`
- [x] 2.6 `chown -R 0:0` the disposable data dir, restart, and run `gen-client laptop`; verify normal startup and that `clients/laptop.ovpn` is created
- [x] 2.7 With a complete disposable PKI, `chown -R 1000:1000` the data dir and start the server; verify a non-zero exit with the report naming `/etc/openvpn/pki/` and the `chown` hint, no `Initializing PKI` line, and an unchanged file list and checksums in `pki/`
- [x] 2.8 Start on an empty data dir owned by `1000:1000` with mode `775`; verify the report and `chown` hint instead of a `mkdir` error

## 3. Documentation and decision record

- [x] 3.1 Add an "Ownership of `data/`" section to `docs/deployment.md` (keep `0:0`, no `chown` to a login user, `sudo tar --numeric-owner` backup and restore, recovery steps for this error); verify the commands match the entrypoint message
- [x] 3.2 Update the startup and client generation flows in `docs/ARCHITECTURE.md` with the access check; verify they match the final script order
- [x] 3.3 Add `docs/adr/2026/11/0002-fail-fast-on-unreadable-pki.md` (context, date, status, alternatives A-D, rationale, consequences) and list it in `docs/adr/README.md`; verify the link resolves

## Workflow follow-up

- Track the work in Beads under prefix `open-vpn` and link this change.
- Run `openspec validate check-pki-key-readability` before archive.
- On the production host after deploy: `chown -R 0:0 data`, `make build-prod`, `make restart-prod`, check `docker logs openvpn`.
- Archive the change after review.
