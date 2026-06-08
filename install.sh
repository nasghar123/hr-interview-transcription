#!/usr/bin/env bash
# One-time VPS setup for Whisper API (Ubuntu 22.04+).
# Run on the VPS as root: bash install.sh

set -euo pipefail

APP_DIR="/opt/whisper-api"
API_PORT="${API_PORT:-8001}"
NGINX_PORT="${NGINX_PORT:-8080}"
API_KEY="${API_KEY:-$(openssl rand -hex 24)}"

echo "==> Installing system packages..."
apt-get update
apt-get install -y python3 python3-pip python3-venv ffmpeg nginx

echo "==> Creating app directory at ${APP_DIR}..."
mkdir -p "${APP_DIR}"

if [[ ! -f "${APP_DIR}/server.py" ]]; then
  echo "ERROR: ${APP_DIR}/server.py not found."
  echo "Upload files first: scp -r ./* root@YOUR_VPS_IP:${APP_DIR}/"
  exit 1
fi

echo "==> Creating Python virtualenv..."
python3 -m venv "${APP_DIR}/.venv"
"${APP_DIR}/.venv/bin/pip" install --upgrade pip "setuptools<81" wheel
"${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt" --no-build-isolation

echo "==> Installing systemd service (port ${API_PORT})..."
cat > /etc/systemd/system/whisper-api.service <<EOF
[Unit]
Description=HR Interview Whisper API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${APP_DIR}
Environment=WHISPER_MODEL=base
Environment=API_KEY=${API_KEY}
ExecStart=${APP_DIR}/.venv/bin/uvicorn server:app --host 127.0.0.1 --port ${API_PORT} --workers 1
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable whisper-api
systemctl restart whisper-api

echo "==> Configuring nginx reverse proxy on port ${NGINX_PORT}..."
cat > /etc/nginx/sites-available/whisper-api <<EOF
server {
    listen ${NGINX_PORT};
    listen [::]:${NGINX_PORT};
    server_name _;

    client_max_body_size 200M;

    location / {
        proxy_pass http://127.0.0.1:${API_PORT};
        proxy_read_timeout 600s;
        proxy_connect_timeout 60s;
        proxy_send_timeout 600s;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/whisper-api /etc/nginx/sites-enabled/whisper-api
nginx -t
systemctl reload nginx

if command -v ufw >/dev/null 2>&1; then
  ufw allow "${NGINX_PORT}/tcp" || true
fi

echo ""
echo "============================================"
echo "Whisper API deployed."
echo "API URL:  http://YOUR_VPS_IP:${NGINX_PORT}/transcribe"
echo "Health:   http://YOUR_VPS_IP:${NGINX_PORT}/health"
echo "API Key:  ${API_KEY}"
echo "Save the API key — use it in n8n as X-API-Key header."
echo "============================================"
