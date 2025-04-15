echo "Đang khởi tạo hệ thống"
sudo apt update > /dev/null 2>&1
sudo apt install -y caffeine > /dev/null 2>&1
docker rm -f cloudflared n8n n8n_postgres
rm -rf docker-run

sudo systemctl unmask docker > /dev/null 2>&1
sudo systemctl unmask docker.socket > /dev/null 2>&1
if ! command -v docker &> /dev/null; then
    echo "Docker chưa được cài đặt. Đang cài đặt..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo apt -f -y install
    sudo usermod -aG sudo $USER
    sudo usermod -aG docker $USER
    sudo systemctl --now enable docker
fi
sudo systemctl start docker > /dev/null 2>&1 
sudo systemctl start docker.socket > /dev/null 2>&1
sudo systemctl unmask containerd.service > /dev/null 2>&1
sudo systemctl start containerd.service > /dev/null 2>&1
sudo systemctl start docker > /dev/null 2>&1 


mkdir docker-run > /dev/null 2>&1
cd docker-run > /dev/null 2>&1
mkdir data_cloudflared > /dev/null 2>&1
cd data_cloudflared > /dev/null 2>&1 


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


random_name=$(< /dev/urandom tr -dc 'a-zA-Z0-9' | head -c8) > /dev/null 2>&1
cat <<EOF > cert.pem
-----BEGIN ARGO TUNNEL TOKEN-----
eyJ6b25lSUQiOiIyMzMzYzVkM2ZiOGNhNDMwNDRhNjhhNWE1OGExZjhiMyIsImFj
Y291bnRJRCI6IjBlYmUxOTZlZjQyMWM3ZmE5ODdmYzgyNDJmODYwMzA3IiwiYXBp
VG9rZW4iOiJITWRGQklkbzBLSERJT3ZSazFaVXVnY19Dc19xY2pXalpPSDFDOUhY
In0=
-----END ARGO TUNNEL TOKEN-----
EOF

json_file=$(cloudflared tunnel --origincert ./cert.pem create "$random_name" | grep "Tunnel credentials written to" | awk '{print $5}' | sed 's/\.$//')
read -p "Nhập tên subdomain cho tunnel ***.ptha.io.vn: " domain
domain1="${domain}.ptha.io.vn"
cloudflared tunnel --origincert ./cert.pem route dns "$random_name" "$domain1"
jsonfile="/etc/cloudflared/$json_file"

cat <<EOF > config.yml
tunnel: $random_name
credentials-file: $jsonfile

ingress:
  - hostname: $domain1
    service: http://n8n:5678
  - service: http_status:404
EOF

cd ../../

sudo mkdir -p docker-run/n8n_data > /dev/null 2>&1
sudo mkdir -p docker-run/postgres_data > /dev/null 2>&1

# Set permissions
sudo chmod -R 777 docker-run > /dev/null 2>&1
sudo chmod -R 777 docker-run/n8n_data > /dev/null 2>&1
sudo chmod -R 777 docker-run/postgres_data > /dev/null 2>&1

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
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./data_cloudflared:/etc/cloudflared

EOF

# Run docker compose without output
docker compose -f docker-run/docker-compose.yml up -d

echo "Truy cập vào N8N tại: https://$domain1"

