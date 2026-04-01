#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-18389}"
METHOD="2022-blake3-aes-256-gcm"
PASSWORD="${PASSWORD:-$(openssl rand -base64 16 | tr -d '\n')}"

apt-get update -y
apt-get install -y curl wget openssl ufw

ARCH=$(uname -m)
[ "$ARCH" = "x86_64" ] && ARCH="amd64"
[ "$ARCH" = "aarch64" ] && ARCH="arm64"

TMP=$(mktemp -d)
cd $TMP

wget https://github.com/SagerNet/sing-box/releases/download/v1.11.6/sing-box_1.11.6_linux_${ARCH}.deb
dpkg -i sing-box_1.11.6_linux_${ARCH}.deb

mkdir -p /etc/sing-box

IP=$(curl -s https://api.ipify.org || echo "YOUR_IP")

cat > /etc/sing-box/config.json <<CONF
{
  "inbounds": [{
    "type": "shadowsocks",
    "listen": "::",
    "listen_port": $PORT,
    "method": "$METHOD",
    "password": "$PASSWORD",
    "network": "tcp"
  }],
  "outbounds": [{
    "type": "direct"
  }]
}
CONF

cat > /etc/systemd/system/sing-box.service <<SERV
[Unit]
Description=sing-box

[Service]
ExecStart=/usr/bin/sing-box run -c /etc/sing-box/config.json
Restart=always

[Install]
WantedBy=multi-user.target
SERV

systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

ufw allow $PORT/tcp || true

BASE64=$(echo -n "$METHOD:$PASSWORD@$IP:$PORT" | base64)

echo "DONE"
echo "ss://$BASE64#proxy-bootstrap"
