up-prod:
	docker compose -f .docker/prod/docker-compose.yml up -d

down-prod:
	docker compose -f .docker/prod/docker-compose.yml down

build-prod:
	docker compose -f .docker/prod/docker-compose.yml build

restart-prod: down-prod up-prod

gen-home-client:
	docker exec -it openvpn /entrypoint.sh gen-client home && cat ./data/clients/home.ovpn