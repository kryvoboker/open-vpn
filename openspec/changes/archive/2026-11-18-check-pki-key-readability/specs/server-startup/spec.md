# Spec Delta

## Purpose

Defines the checks the container performs on its runtime data in `/etc/openvpn` before it starts the OpenVPN server or generates a client profile, and how it reports failures to the operator.

## ADDED Requirements

### Requirement: Existing PKI is never re-initialized when its directories are inaccessible
Before deciding whether the PKI must be created, the container SHALL verify that it can enter and list every existing directory among `/etc/openvpn`, `pki`, `pki/private`, `pki/issued`, and `clients`, and that it can create `pki` and `clients` when they are missing. On failure it SHALL print the access report with the `chown -R 0:0 data` hint and exit non-zero without creating, deleting, or modifying any PKI file.

#### Scenario: Whole data directory owned by another user
- **GIVEN** a complete PKI in `data/` and `chown -R 1000:1000 data` applied on the host, so `pki/` has mode `700` and owner `1000:1000`
- **WHEN** the container starts or `gen-client` runs
- **THEN** the container exits non-zero with the access report naming `/etc/openvpn/pki/` and the `chown -R 0:0 data` hint
- **AND** no PKI initialization is attempted and all PKI files remain unchanged

#### Scenario: Empty data directory owned by another user
- **GIVEN** an empty `data/` owned by `1000:1000` with mode `775`
- **WHEN** the container starts
- **THEN** the container exits non-zero with the access report and the `chown -R 0:0 data` hint instead of a `mkdir` error

#### Scenario: First start on a root-owned empty directory
- **GIVEN** `data/` does not exist and Docker creates it as root
- **WHEN** the container starts
- **THEN** the PKI is created as before

### Requirement: Server PKI files are readable before OpenVPN starts
Before starting OpenVPN, the container SHALL verify that it can read every PKI file the server configuration uses: `ca.crt`, `issued/server.crt`, `private/server.key`, `dh.pem`, `crl.pem`, and `tls-crypt.key` under `/etc/openvpn/pki`. If any file cannot be read, OpenVPN SHALL NOT be started and the container SHALL exit with a non-zero status.

#### Scenario: All PKI files readable
- **GIVEN** `data/` is owned by `0:0` and the PKI is complete
- **WHEN** the container starts
- **THEN** OpenVPN starts as before and no ownership error is printed

#### Scenario: Key file owned by another user
- **GIVEN** `data/pki/tls-crypt.key` has mode `600` and owner `1000:1000` on the host
- **WHEN** the container starts
- **THEN** the container exits with a non-zero status before OpenVPN starts
- **AND** OpenVPN's `Cannot pre-load keyfile` error does not appear in the log

### Requirement: Unreadable PKI file error names the cause and the fix
When a PKI file cannot be read, the container SHALL print, for each failing file, its path, its owner as `uid:gid`, and its mode. The message SHALL state that the container runs without `CAP_DAC_OVERRIDE` and can only read files owned by root, and SHALL give the host-side fix `chown -R 0:0 data` run from the project root.

#### Scenario: Error message for a misowned key
- **GIVEN** `data/pki/tls-crypt.key` has mode `600` and owner `1000:1000`
- **WHEN** the container starts
- **THEN** the log contains `/etc/openvpn/pki/tls-crypt.key`, `1000:1000`, and `600`
- **AND** the log contains `chown -R 0:0 data`

#### Scenario: Several files fail
- **GIVEN** `tls-crypt.key` and `private/server.key` are both unreadable
- **WHEN** the container starts
- **THEN** both files are listed in a single error report before the container exits

### Requirement: Missing PKI file is reported separately
If a file required by the server is missing, the container SHALL report it as missing rather than as an ownership problem, and SHALL exit with a non-zero status without starting OpenVPN.

#### Scenario: tls-crypt key missing
- **GIVEN** the PKI contains `ca.crt`, `issued/server.crt`, `private/server.key`, and `dh.pem` but no `tls-crypt.key`
- **WHEN** the container starts
- **THEN** the log states that `/etc/openvpn/pki/tls-crypt.key` is missing
- **AND** the log does not suggest `chown` for that file

### Requirement: Client generation checks PKI access before issuing a certificate
Before issuing a client certificate, `gen-client` SHALL verify that the server PKI files listed above are readable and that `/etc/openvpn/pki` and `/etc/openvpn/clients` are writable. On failure it SHALL print the same kind of report and exit non-zero without creating a certificate or a profile.

#### Scenario: Misowned data directory during client generation
- **GIVEN** `data/` is owned by `1000:1000` with directory mode `775`
- **WHEN** the operator runs `docker exec -it openvpn /entrypoint.sh gen-client laptop`
- **THEN** the command exits non-zero with the ownership report and the `chown -R 0:0 data` hint
- **AND** no `laptop` certificate or `laptop.ovpn` profile is created

#### Scenario: Correct ownership
- **GIVEN** `data/` is owned by `0:0`
- **WHEN** the operator runs `gen-client laptop`
- **THEN** the profile is generated as before
