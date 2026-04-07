#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

echo -e "${CYAN}🤖 Add/Download Ollama Model (Native)${NC}\n"

check_ollama_cli
bash "$SCRIPT_DIR/start_ollama_native.sh"

show_model_menu_native

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
read -p "Select model to download (1-$MODEL_COUNT) or 'q' to quit: " choice

if [[ "$choice" == "q" ]]; then
  echo "Exiting..."
  exit 0
fi

if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$MODEL_COUNT" ]; then
  echo -e "${RED}❌ Invalid selection${NC}"
  exit 1
fi

MODEL_KEY="${MODEL_MAP[$choice]}"

if command -v jq > /dev/null 2>&1; then
  DISPLAY_NAME=$(jq -r ".[\"$MODEL_KEY\"].displayName" "$MODELS_JSON")
  OLLAMA_TAG=$(jq -r ".[\"$MODEL_KEY\"].ollamaTag" "$MODELS_JSON")
  MEMORY_REQ=$(jq -r ".[\"$MODEL_KEY\"].memoryRequired" "$MODELS_JSON")
else
  DISPLAY_NAME=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep displayName | cut -d'"' -f4)
  OLLAMA_TAG=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep ollamaTag | cut -d'"' -f4)
  MEMORY_REQ=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep memoryRequired | cut -d'"' -f4)
fi

if is_model_installed_native "$OLLAMA_TAG"; then
  echo -e "${YELLOW}⚠️  $DISPLAY_NAME is already installed${NC}"
  read -p "Do you want to re-download it? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Skipping download"
    exit 0
  fi
fi

echo -e "\n${BLUE}ℹ️  Model requires: $MEMORY_REQ${NC}"
read -p "Continue with download? (Y/n): " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
  echo "Download cancelled"
  exit 0
fi

pull_model_native "$OLLAMA_TAG" "$DISPLAY_NAME"

echo -e "\n${GREEN}✅ Model added successfully!${NC}"
echo -e "${CYAN}Use 'make switch-native' to configure Continue to use this model${NC}"
