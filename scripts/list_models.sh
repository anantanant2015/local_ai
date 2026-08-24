#!/usr/bin/env bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils.sh"

CONFIG_FILE="${HOME}/.continue/config.yaml"
# Fixture check: generate_continue_config.sh --output /tmp/cfg.yaml then print_continue_from_yaml first two lines are chat and autocomplete tags.

echo -e "${CYAN}🤖 Ollama Models Overview${NC}\n"

# Check prerequisites
check_docker
check_ollama_container

# Get installed models
INSTALLED=$(list_installed_models)

# Show available models with install status
show_model_menu

# Show currently configured models
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

# Show Docker memory info
echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                   System Information                       ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}" ollama-server

echo -e "\n${BLUE}Commands:${NC}"
echo -e "  ${GREEN}make add-model${NC}  - Download a new model"
echo -e "  ${GREEN}make switch${NC}     - Switch active models"
echo -e "  ${GREEN}make setup${NC}      - Interactive setup"
echo ""
