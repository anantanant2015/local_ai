#!/usr/bin/env bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils.sh"

CONFIG_FILE="${HOME}/.continue/config.yaml"
# Fixture check: generate_continue_config.sh --output /tmp/cfg.yaml then this parser's first two lines are chat and autocomplete tags.

print_continue_from_yaml() {
  local path="${1:-$CONFIG_FILE}"
  if [ ! -f "$path" ]; then
    echo -e "${YELLOW}⚠️  No Continue config found at $path${NC}"
    return
  fi

  python3 - "$path" <<'PY'
import sys
path = sys.argv[1]
chat = None
auto = None
in_models = False
in_auto = False
with open(path, encoding="utf-8") as fh:
    for raw in fh:
        line = raw.strip()
        if line == "models:":
            in_models = True
            in_auto = False
            continue
        if line.startswith("tabAutocompleteModel:"):
            in_auto = True
            in_models = False
            continue
        if in_models and chat is None and line.startswith("model:"):
            chat = line.split(":", 1)[1].strip()
        elif in_auto and auto is None and line.startswith("model:"):
            auto = line.split(":", 1)[1].strip()
print(chat or "none")
print(auto or "none")
PY
}

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
