#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

CONFIG_FILE="${HOME}/.continue/config.yaml"

echo -e "${CYAN}🤖 Native Ollama Models Overview${NC}\n"

check_ollama_cli
bash "$SCRIPT_DIR/start_ollama_native.sh" > /dev/null

show_model_menu_native

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}              Currently Configured in Continue             ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

if [ -f "$CONFIG_FILE" ]; then
  mapfile -t CONTINUE_TAGS < <(print_continue_from_yaml "$CONFIG_FILE")
  echo -e "${GREEN}Chat models:${NC} ${CONTINUE_TAGS[0]:-none}"
  echo -e "${GREEN}Autocomplete:${NC} ${CONTINUE_TAGS[1]:-none}"
else
  echo -e "${YELLOW}⚠️  No Continue config found${NC}"
  echo -e "Config file: $CONFIG_FILE"
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
