# Deployment

There is one environment, production, defined in `.docker/prod/`. Run every command from the repository root on the server host.

## Commands

| Command | Action |
|---|---|
| `make build-prod` | Build the `openvpn-server:1.0` image |
| `make up-prod` | Start the container in the background |
| `make down-prod` | Stop and remove the container (data in `data/` is kept) |
| `make restart-prod` | `down-prod` then `up-prod` |
| `make gen-home-client` | Generate the `home` client and print the profile |

For another client name: `docker exec -it openvpn /entrypoint.sh gen-client <name>`, then copy `data/clients/<name>.ovpn`. Running it again with an existing name fails because Easy-RSA refuses to reissue the certificate.

## Release flow

1. Change the source and update the docs and ADRs.
2. `make build-prod`.
3. `make restart-prod`.
4. Check `docker logs openvpn` for `Initialization Sequence Completed`.
5. Connect a client and confirm that its public IP is the server's IP.

The container uses `restart: unless-stopped`, so it starts again after a host reboot.

## Backups and recovery

- Back up `data/` (PKI and profiles). Losing `data/pki/` means every client profile must be reissued.
- To rebuild the PKI from scratch, stop the container and remove `data/pki/`; the next start creates a new CA. All existing client profiles stop working.

## Delivering profiles

A `.ovpn` file contains the client's private key. Transfer it over a secure channel and delete copies you no longer need.
