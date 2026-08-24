#!/usr/bin/env bash
# Native Ollama helpers. Shared catalog/RAM/Continue parse live in model_utils.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=model_utils.sh
source "$SCRIPT_DIR/model_utils.sh"

is_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu' /etc/os-release
}

check_ollama_cli() {
  if ! command -v ollama > /dev/null 2>&1; then
    echo -e "${RED}❌ Ollama is not installed.${NC}"
    echo -e "${BLUE}Install it with: curl -fsSL https://ollama.com/install.sh | sh${NC}"
    exit 1
  fi
}

wait_for_ollama() {
  local retries=20
  local sleep_seconds=1

  for _ in $(seq 1 "$retries"); do
    if curl -sSf http://localhost:11434 > /dev/null 2>&1; then
      return 0
    fi
    sleep "$sleep_seconds"
  done

  return 1
}

list_installed_models_native() {
  ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' || echo ""
}

is_model_installed_native() {
  local model_tag="$1"
  list_installed_models_native | grep -q "^${model_tag}$"
}

pull_model_native() {
  local model_tag="$1"
  local display_name="$2"

  echo -e "${CYAN}📥 Pulling $display_name ($model_tag)...${NC}"
  ollama pull "$model_tag"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully pulled $display_name${NC}"
    return 0
  fi

  echo -e "${RED}❌ Failed to pull $display_name${NC}"
  return 1
}

show_model_menu_native() {
  show_model_menu list_installed_models_native
}
