mkdir tunnel
cd tunnel
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
read -p "Nhập tên subdomain cho tunnel ***.ptha.io.vn: " domain
domain1="${domain}.ptha.io.vn"
cloudflared tunnel --origincert ./cert.pem route dns "$random_name" "$domain1"

read -p "Nhập tên và port service cần tunnel ví dụ: http://n8n:5678" localtunnel
cat <<EOF > config.yaml
tunnel: $random_name
credentials-file: $json_file

ingress:
  - hostname: $domain1
    service: $localtunnel
  - service: http_status:404
EOF

cloudflared tunnel --origincert ./cert.pem --credentials-file="./$json_file" run "$random_name" 
echo "Tunnel domain: $domain1"
