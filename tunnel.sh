mkdir tunnel
cd tunnel
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

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
cloudflared tunnel route dns "$random_name" "$domain1"

read -p "Nhập tên và port service cần tunnel ví dụ: http://n8n:5678" localtunnel
cat <<EOF > config.yaml
tunnel: $random_name
credentials-file: $json_file

ingress:
  - hostname: $domain1
    service: $localtunnel
  - service: http_status:404
EOF

cloudflared tunnel run "$random_name" --credentials-file="./$json_file"
