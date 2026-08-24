#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

PID_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/local_ai_ollama.pid"

is_native_service_active() {
  if ! command -v systemctl > /dev/null 2>&1; then
    return 1
  fi

  local service
  for service in ollama-local-ai.service ollama.service; do
    if systemctl list-unit-files | grep -q "^${service}" && systemctl is-active --quiet "$service"; then
      return 0
    fi
  done

  return 1
}

is_native_process_running() {
  pgrep -f '[/]ollama serve' > /dev/null 2>&1
}

echo -e "${CYAN}🛑 Stopping native Ollama...${NC}"

if command -v systemctl > /dev/null 2>&1; then
  for service in ollama-local-ai.service ollama.service; do
    if systemctl list-unit-files | grep -q "^${service}" && systemctl is-active --quiet "$service"; then
      if [ "$EUID" -eq 0 ]; then
        systemctl stop "$service" || true
      else
        sudo systemctl stop "$service" || true
      fi
    fi
  done
fi

if [ -f "$PID_FILE" ]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" > /dev/null 2>&1; then
    kill "$pid" || true
  fi
  rm -f "$PID_FILE"
fi

pkill -f '[/]ollama serve' 2>/dev/null || true
if is_native_process_running; then
  sudo pkill -f '[/]ollama serve' 2>/dev/null || true
fi

for _ in $(seq 1 5); do
  if ! is_native_service_active && ! is_native_process_running; then
    break
  fi
  sleep 1
done

if is_native_service_active || is_native_process_running; then
  echo -e "${YELLOW}⚠️ Native Ollama still appears to be running${NC}"
  exit 1
fi

if curl -sSf http://localhost:11434 > /dev/null 2>&1; then
  echo -e "${YELLOW}⚠️ Port 11434 is still responding (likely Docker or another Ollama instance).${NC}"
  echo -e "${GREEN}✅ Native Ollama stopped${NC}"
  exit 0
fi

echo -e "${GREEN}✅ Ollama stopped${NC}"
