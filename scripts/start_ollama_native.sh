#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

PID_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/local_ai_ollama.pid"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/local_ai"
LOG_FILE="$LOG_DIR/ollama.log"

echo -e "${CYAN}🚀 Starting native Ollama...${NC}"
check_ollama_cli

mkdir -p "$(dirname "$PID_FILE")" "$LOG_DIR"

if curl -sSf http://localhost:11434 > /dev/null 2>&1; then
  echo -e "${GREEN}✅ Ollama already running on http://localhost:11434${NC}"
  exit 0
fi

if command -v systemctl > /dev/null 2>&1 && systemctl list-unit-files | grep -q '^ollama-local-ai.service'; then
  echo -e "${BLUE}Using systemd service: ollama-local-ai.service${NC}"
  sudo systemctl start ollama-local-ai.service
else
  echo -e "${BLUE}Starting ollama serve in background...${NC}"
  nohup ollama serve > "$LOG_FILE" 2>&1 &
  echo "$!" > "$PID_FILE"
fi

if wait_for_ollama; then
  echo -e "${GREEN}✅ Ollama running on http://localhost:11434${NC}"
else
  echo -e "${RED}❌ Ollama did not become ready in time${NC}"
  exit 1
fi
