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

if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}This script needs sudo to remove a system service.${NC}"
  exec sudo -E bash "$0"
fi

if systemctl list-unit-files | grep -q "^${SERVICE_NAME}"; then
  echo -e "${BLUE}Disabling and stopping $SERVICE_NAME...${NC}"
  systemctl disable --now "$SERVICE_NAME" || true
else
  echo -e "${YELLOW}⚠️ $SERVICE_NAME is not registered.${NC}"
fi

if [ -f "$SERVICE_PATH" ]; then
  rm -f "$SERVICE_PATH"
  echo -e "${GREEN}✅ Removed service file: $SERVICE_PATH${NC}"
fi

systemctl daemon-reload
systemctl reset-failed || true

echo -e "${GREEN}✅ Autostart rollback complete${NC}"
