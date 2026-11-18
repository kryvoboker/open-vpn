# Documentation index

OpenVpn runs an OpenVPN server in a single Docker container and generates client profiles. This index lists every maintained document and its purpose.

| Document | Purpose |
|---|---|
| [setup/README.md](setup/README.md) | Host requirements, first start, workflow tool checks |
| [RULES.md](RULES.md) | Universal project rules |
| [DESCRIPTION.md](DESCRIPTION.md) | Purpose and implemented capabilities |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, runtime flow, source boundaries |
| [DOCUMENTS.md](DOCUMENTS.md) | Documentation ownership and artifact conventions |
| [configuration.md](configuration.md) | Environment variables and server settings |
| [deployment.md](deployment.md) | Build, start, stop, client generation, backups |
| [testing.md](testing.md) | Available verification and its limits |
| [adr/README.md](adr/README.md) | Architecture decision records |

Not applicable to this project (no HTTP API, no database, no application modules or internal libraries): `api.md`, OpenAPI, `modules/`, `libraries/`, `database/`. Create them only if such components appear.
