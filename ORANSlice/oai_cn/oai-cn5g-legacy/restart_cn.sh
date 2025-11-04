docker compose -f docker-compose-legacy.yml down && docker compose -f docker-compose-legacy.yml up -d && sleep 5 && docker exec -it oai-spgwu-tiny ip addr add 12.1.2.1/24 dev tun0
