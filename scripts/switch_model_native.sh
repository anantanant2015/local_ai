#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

echo -e "${CYAN}🔄 Switch Active Models (Native)${NC}\n"

check_ollama_cli
bash "$SCRIPT_DIR/start_ollama_native.sh" > /dev/null

INSTALLED="$(list_installed_models_native)"

if [ -z "$INSTALLED" ]; then
  echo -e "${RED}❌ No models installed. Run 'make add-model-native' first.${NC}"
  exit 1
fi

echo -e "${GREEN}Installed Models:${NC}"
echo "$INSTALLED" | nl
echo ""

echo -e "${CYAN}Select model for CHAT (main interactions):${NC}"
select CHAT_TAG in $INSTALLED; do
  if [ -n "$CHAT_TAG" ]; then
    break
  fi
done

echo -e "\n${CYAN}Select model for AUTOCOMPLETE (tab completion):${NC}"
echo -e "${YELLOW}Tip: Choose a smaller/faster model for better autocomplete performance${NC}"
select AUTO_TAG in $INSTALLED; do
  if [ -n "$AUTO_TAG" ]; then
    break
  fi
done

echo -e "\n${BLUE}Updating Continue configuration...${NC}"
MODELS_CSV="$(echo "$INSTALLED" | tr '\n' ',' | sed 's/,$//')"
bash "$SCRIPT_DIR/generate_continue_config.sh" --mode native --models "$MODELS_CSV" --chat "$CHAT_TAG" --autocomplete "$AUTO_TAG"

echo -e "\n${GREEN}✅ Configuration updated!${NC}"
echo -e "${CYAN}Chat model: $CHAT_TAG${NC}"
echo -e "${CYAN}Autocomplete model: $AUTO_TAG${NC}"
echo -e "\n${YELLOW}Reload VS Code to apply changes${NC}"
