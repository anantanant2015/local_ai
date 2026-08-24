#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

CONFIG_FILE="${HOME}/.continue/config.yaml"

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
