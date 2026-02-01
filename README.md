# OPEN-VPN in Docker Container

Commands:
```bash
make build-prod  # Build the Docker image
```
```bash
make up-prod     # Start the OpenVPN server
```
```bash
make down-prod   # Stop the OpenVPN server
```
```bash
make restart-prod # Restart the OpenVPN server
```

## .env File Configuration
Write your IP address to `.docker/prod/env/.env` file: `OVPN_HOST`.

If it needs, write your `OVPN_PORT` to `.docker/prod/env/.env`.

## Generating Client Configuration
To generate a client configuration file for home use, run:
```bash
make gen-home-client
```

This command will create a client configuration file in the `./data/clients/` directory and return the config in the terminal. Then you can copy the content and create your `*.ovpn` file.