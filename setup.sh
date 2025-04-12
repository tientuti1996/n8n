#!/bin/bash

# Unmask Docker services
echo "Đang khởi tạo hệ thống"
sudo systemctl unmask docker > /dev/null 2>&1
sudo systemctl unmask docker.socket > /dev/null 2>&1
sudo systemctl start docker > /dev/null 2>&1 
sudo systemctl start docker.socket > /dev/null 2>&1
sudo systemctl unmask containerd.service > /dev/null 2>&1
sudo systemctl start containerd.service > /dev/null 2>&1
sudo systemctl start docker > /dev/null 2>&1 
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

sleep 5

docker logs cloudflared
