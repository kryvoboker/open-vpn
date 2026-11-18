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

## Ownership of `data/`

`data/` and everything in it must stay owned by `0:0` (root). The container runs with `cap_drop: ALL`, so root inside it has no `CAP_DAC_OVERRIDE` and can only access files it owns. Easy-RSA creates keys with mode `600` and PKI directories with mode `700`.

- Never `chown` `data/` to a login user, not even to download it. Copy the archive instead (see below).
- Let Docker create `data/` on the first start, or create it with `sudo mkdir data`.

If the ownership is wrong, the container exits before starting OpenVPN or issuing a certificate and prints:

```
[openvpn] Cannot access PKI files:
[openvpn]   /etc/openvpn/pki/tls-crypt.key (owner 1000:1000, mode 600)
...
[openvpn] Fix on the host, from the project root: chown -R 0:0 data
```

Recovery, from the project root:

```bash
make down-prod
sudo chown -R 0:0 data
make up-prod
docker logs -f openvpn
```

Images built before this check fail with `Cannot pre-load keyfile (/etc/openvpn/pki/tls-crypt.key)` instead; the fix is the same.

## Backups and recovery

- Back up `data/` (PKI and profiles). Losing `data/pki/` means every client profile must be reissued.
- Create a backup without changing ownership, then make only the archive readable by your user:

  ```bash
  sudo tar --numeric-owner -cpzf /tmp/openvpn-data.tgz data
  sudo chown "$USER" /tmp/openvpn-data.tgz && chmod 600 /tmp/openvpn-data.tgz
  ```

  Download `/tmp/openvpn-data.tgz` and delete it from the server afterwards. The archive contains private keys.
- Restore from the project root with the container stopped: `sudo tar --numeric-owner -xpzf openvpn-data.tgz`.
- To rebuild the PKI from scratch, stop the container and remove `data/pki/`; the next start creates a new CA. All existing client profiles stop working.

## Delivering profiles

A `.ovpn` file contains the client's private key. Transfer it over a secure channel and delete copies you no longer need.
