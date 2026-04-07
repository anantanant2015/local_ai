#!/usr/bin/env bash
# Common functions for native (non-Docker) Ollama scripts

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_JSON="$SCRIPT_DIR/models.json"

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
  local installed_models
  installed_models="$(list_installed_models_native)"

  echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}                  Available Models                          ${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

  local i=1
  declare -g -A MODEL_MAP

  local model_keys
  model_keys=($(cat "$MODELS_JSON" | grep -o '"[^"]*": *{' | grep -o '"[^"]*"' | tr -d '"'))

  for model_key in "${model_keys[@]}"; do
    local display_name
    local size
    local memory
    local quality
    local description
    local ollama_tag

    if command -v jq > /dev/null 2>&1; then
      display_name=$(jq -r ".[\"$model_key\"].displayName" "$MODELS_JSON")
      size=$(jq -r ".[\"$model_key\"].size" "$MODELS_JSON")
      memory=$(jq -r ".[\"$model_key\"].memoryRequired" "$MODELS_JSON")
      quality=$(jq -r ".[\"$model_key\"].quality" "$MODELS_JSON")
      description=$(jq -r ".[\"$model_key\"].description" "$MODELS_JSON")
      ollama_tag=$(jq -r ".[\"$model_key\"].ollamaTag" "$MODELS_JSON")
    else
      local model_block
      model_block=$(cat "$MODELS_JSON" | awk "/\"$model_key\":/,/^\s*\}/" | head -20)
      display_name=$(echo "$model_block" | grep displayName | cut -d'"' -f4)
      size=$(echo "$model_block" | grep '"size"' | cut -d'"' -f4)
      memory=$(echo "$model_block" | grep memoryRequired | cut -d'"' -f4)
      quality=$(echo "$model_block" | grep '"quality"' | cut -d'"' -f4)
      description=$(echo "$model_block" | grep description | cut -d'"' -f4)
      ollama_tag=$(echo "$model_block" | grep ollamaTag | cut -d'"' -f4)
    fi

    local installed_marker=""
    if echo "$installed_models" | grep -q "^${ollama_tag}$"; then
      installed_marker="${GREEN}[installed]${NC}"
    fi

    echo -e "${BLUE}[$i]${NC} ${YELLOW}$display_name${NC} $installed_marker"
    echo -e "    Size: $size | Memory: $memory | Quality: $quality"
    echo -e "    $description"
    echo ""

    MODEL_MAP[$i]="$model_key"
    ((i++))
  done

  export MODEL_COUNT=$((i-1))
}
