mkdir docker-run
cd docker-run
mkdir data_cloudflared
cd data_cloudflared

if ! command -v cloudflared &> /dev/null; then
    echo "cloudflared chưa được cài đặt. Đang cài đặt..."
    
    # Tải và cài đặt cloudflared
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared-linux-amd64
    sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

    echo "cloudflared đã được cài đặt thành công."
else
    echo "cloudflared đã được cài đặt."
fi


random_name=$(< /dev/urandom tr -dc 'a-zA-Z0-9' | head -c8)
cat <<EOF > cert.pem
-----BEGIN ARGO TUNNEL TOKEN-----
eyJ6b25lSUQiOiIyMzMzYzVkM2ZiOGNhNDMwNDRhNjhhNWE1OGExZjhiMyIsImFj
Y291bnRJRCI6IjBlYmUxOTZlZjQyMWM3ZmE5ODdmYzgyNDJmODYwMzA3IiwiYXBp
VG9rZW4iOiJITWRGQklkbzBLSERJT3ZSazFaVXVnY19Dc19xY2pXalpPSDFDOUhY
In0=
-----END ARGO TUNNEL TOKEN-----
EOF

json_file=$(cloudflared tunnel --origincert ./cert.pem create "$random_name" | grep "Tunnel credentials written to" | awk '{print $5}')
read -p "Nhập tên subdomain cho tunnel ***.ptha.io.vn: \n" domain
domain1="${domain}.ptha.io.vn"
cloudflared tunnel --origincert ./cert.pem route dns "$random_name" "$domain1"

cat <<EOF > config.yaml
tunnel: $random_name
credentials-file: "$/etc/cloudflared/{json_file}"

ingress:
  - hostname: $domain1
    service: http://n8n:5678
  - service: http_status:404
EOF

cd ../../

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
    volumes:
      - ./data_cloudflared:/etc/cloudflared

EOF

# Run docker compose without output
docker compose -f docker-run/docker-compose.yml up -d > /dev/null 2>&1

