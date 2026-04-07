#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

echo -e "${CYAN}🤖 Native Ollama Models Overview${NC}\n"

check_ollama_cli
bash "$SCRIPT_DIR/start_ollama_native.sh" > /dev/null

show_model_menu_native

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}              Currently Configured in Continue             ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

if [ -f "$CONFIG_FILE" ]; then
  if command -v jq > /dev/null 2>&1; then
    CHAT_MODELS=$(jq -r '.models[].model' "$CONFIG_FILE" 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
    AUTO_MODEL=$(jq -r '.tabAutocompleteModel.model' "$CONFIG_FILE" 2>/dev/null)

    echo -e "${GREEN}Chat models:${NC} ${CHAT_MODELS:-none}"
    echo -e "${GREEN}Autocomplete:${NC} ${AUTO_MODEL:-none}"
  else
    echo -e "${YELLOW}Install 'jq' to see configured models${NC}"
    echo -e "Config file: $CONFIG_FILE"
  fi
else
  echo -e "${YELLOW}⚠️  No Continue config found${NC}"
fi

echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                   Runtime Information                      ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

if command -v ollama > /dev/null 2>&1; then
  echo -e "${GREEN}Active models (ollama ps):${NC}"
  ollama ps || true
fi

echo -e "\n${BLUE}Commands:${NC}"
echo -e "  ${GREEN}make add-model-native${NC}   - Download a new model"
echo -e "  ${GREEN}make switch-native${NC}      - Switch active models"
echo -e "  ${GREEN}make setup-native${NC}       - Interactive native setup"
echo ""
