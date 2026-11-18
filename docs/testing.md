# Testing

There are no automated tests, linters, or CI pipelines in this repository.

## Manual verification

| Check | Command or action | Expected result |
|---|---|---|
| Compose file is valid | `docker compose -f .docker/prod/docker-compose.yml config -q` | No output, exit code 0 |
| Image builds | `make build-prod` | Build succeeds |
| Server starts | `docker logs openvpn` | `Initialization Sequence Completed` |
| PKI is reused | `make restart-prod`, then logs | `PKI exists, skipping init.` |
| NAT rules are not duplicated | `docker exec openvpn iptables -t nat -S POSTROUTING` | One MASQUERADE rule for `10.8.0.0/24` |
| Client profile works | Import `data/clients/<name>.ovpn` into a client | Connects; public IP equals the server's IP |

## Limits

- Connectivity can only be verified from a real client outside the host network.
- Firewall and cloud security group settings are outside this repository and must be checked separately.
- `shellcheck` on `entrypoint.sh` is a useful static check but is not configured.
