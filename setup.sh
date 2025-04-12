#!/bin/bash

# Unmask Docker services
echo "Đang khởi tạo hệ thống"
sudo apt update > /dev/null 2>&1
sudo apt install -y caffeine > /dev/null 2>&1
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

echo "==== SCRIPT TỰ ĐỘNG THIẾT LẬP GIỮ SECTION ===="

read -p "Nhập URL remote bên trên  (ví dụ: https://cloudworkstations.dev/vnc.html?autoconnect=true&resize=remote: " URL

# Kiểm tra nếu URL trống
if [ -z "$URL" ]; then
    echo "Lỗi: URL không được để trống!"
    exit 1
fi

# Tạo file monitor.sh
cat > /home/user/monitor.sh << EOL
#!/bin/bash

# URL cần kết nối
URL="$URL"

# Kết nối đến URL và ghi log
curl -s "\$URL" > /dev/null 2>&1
echo "\$(date '+%Y-%m-%d %H:%M:%S') - Đã kết nối đến \$URL" >> /home/user/vnc_monitor.log

# Giữ log file không quá lớn (giữ 1000 dòng cuối cùng)
tail -n 1000 /home/user/vnc_monitor.log > /home/user/vnc_monitor.log.tmp
mv /home/user/vnc_monitor.log.tmp /home/user/vnc_monitor.log
EOL

# Cấp quyền thực thi cho script
echo "Đang cấp quyền thực thi cho script..."
sudo chmod +x /home/user/monitor.sh

# Kiểm tra nếu chmod thành công
if [ $? -ne 0 ]; then
    echo "Lỗi: Không thể cấp quyền thực thi. Vui lòng chạy lệnh sau thủ công:"
    echo "sudo chmod +x /home/user/monitor.sh"
    exit 1
fi

# Thêm vào crontab
echo "Đang thêm script vào crontab để chạy mỗi phút..."
(crontab -l 2>/dev/null | grep -v "/home/user/monitor.sh" ; echo "*/1 * * * * /home/user/monitor.sh") | crontab -

# Kiểm tra nếu crontab thành công
if [ $? -ne 0 ]; then
    echo "Lỗi: Không thể cập nhật crontab. Vui lòng chạy lệnh sau thủ công:"
    echo "crontab -e"
    echo "Sau đó thêm dòng: */1 * * * * /home/user/monitor.sh"
    exit 1
fi
sudo apt update > /dev/null 2>&1
sudo apt install -y caffeine > /dev/null 2>&1
sudo caffeine & disown > /dev/null 2>&1
docker logs cloudflared
