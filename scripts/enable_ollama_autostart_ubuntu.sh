#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

SERVICE_NAME="ollama-local-ai.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

if ! is_ubuntu; then
  echo -e "${RED}❌ This script is only supported on Ubuntu.${NC}"
  exit 1
fi

check_ollama_cli
OL_PATH="$(command -v ollama)"
RUN_USER="${SUDO_USER:-$USER}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}This script needs sudo to install a system service.${NC}"
  exec sudo -E bash "$0"
fi

cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Local AI Ollama Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$RUN_USER
Group=$RUN_USER
ExecStart=$OL_PATH serve
Restart=always
RestartSec=3
Environment=HOME=/home/$RUN_USER

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo -e "${GREEN}✅ Autostart enabled: $SERVICE_NAME${NC}"
  echo -e "${BLUE}Service status: sudo systemctl status $SERVICE_NAME${NC}"
else
  echo -e "${RED}❌ Service failed to start${NC}"
  exit 1
fi
