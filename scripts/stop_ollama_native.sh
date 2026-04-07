#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

PID_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/local_ai_ollama.pid"

echo -e "${CYAN}🛑 Stopping native Ollama...${NC}"

if command -v systemctl > /dev/null 2>&1 && systemctl list-unit-files | grep -q '^ollama-local-ai.service'; then
  sudo systemctl stop ollama-local-ai.service || true
fi

if [ -f "$PID_FILE" ]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" > /dev/null 2>&1; then
    kill "$pid" || true
  fi
  rm -f "$PID_FILE"
fi

pkill -f '^ollama serve$' 2>/dev/null || true

if curl -sSf http://localhost:11434 > /dev/null 2>&1; then
  echo -e "${YELLOW}⚠️ Ollama still appears to be running${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Ollama stopped${NC}"
