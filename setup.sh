#!/bin/bash

# Unmask Docker services
sudo systemctl unmask docker
echo "1"
sudo systemctl unmask docker.socket
echo "2"
sudo systemctl start docker
echo "3"
sudo systemctl start docker.socket
echo "4"
sudo systemctl unmask containerd.service
echo "5"
sudo systemctl start containerd.service
echo "6"
sudo systemctl start docker
# Create directories
sudo mkdir -p docker-run/n8n_data
sudo mkdir -p docker-run/postgres_data

# Set permissions
sudo chmod -R 777 docker-run
sudo chmod -R 777 docker-run/n8n_data
sudo chmod -R 777 docker-run/postgres_data

# Create docker-compose.yml
cat << 'EOF' > docker-run/docker-compose.yml
services:
  postgres:
    image: postgres:15
    container_name: n8n_postgres
    restart: always
    environment:
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: n8npass
      POSTGRES_DB: n8ndb
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8ndb
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=n8npass
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=changeme123
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - TZ=Asia/Ho_Chi_Minh
    volumes:
      - ./n8n_data:/home/node/.n8n
    depends_on:
      - postgres
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: always
    command: tunnel --url http://n8n:5678
EOF

# Run docker compose without output
docker compose -f docker-run/docker-compose.yml up -d > /dev/null 2>&1

# Get logs from cloudflared
sleep 5  # Wait a bit for the container to start

# Get logs and extract the tunnel URL
LOGS=$(docker logs cloudflared)
TUNNEL_URL=$(echo "$LOGS" | grep -o "https://[a-zA-Z0-9\-]*\.trycloudflare\.com" | head -1)

echo "N8N is now running!"
echo "Cloudflared tunnel URL: $TUNNEL_URL"
echo "You can access the n8n interface at this URL"
echo "Default credentials: admin / changeme123"
