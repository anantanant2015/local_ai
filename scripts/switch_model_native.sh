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

MODELS_ARRAY="["
FIRST=true

while IFS= read -r installed_tag; do
  [ -z "$installed_tag" ] && continue

  if command -v jq > /dev/null 2>&1; then
    MODEL_KEY=$(jq -r "to_entries[] | select(.value.ollamaTag == \"$installed_tag\") | .key" "$MODELS_JSON")
    if [ -n "$MODEL_KEY" ] && [ "$MODEL_KEY" != "null" ]; then
      DISPLAY_NAME=$(jq -r ".[\"$MODEL_KEY\"].displayName" "$MODELS_JSON")
    else
      DISPLAY_NAME="$installed_tag"
    fi
  else
    MODEL_KEY=$(cat "$MODELS_JSON" | grep -B 8 "\"ollamaTag\": \"$installed_tag\"" | grep -o '"[^"]*": *{' | head -1 | tr -d '": {')
    if [ -n "$MODEL_KEY" ]; then
      DISPLAY_NAME=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep displayName | cut -d'"' -f4)
    else
      DISPLAY_NAME="$installed_tag"
    fi
  fi

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    MODELS_ARRAY+="," 
  fi

  MODELS_ARRAY+="\n    {\n      \"title\": \"$DISPLAY_NAME\",\n      \"provider\": \"ollama\",\n      \"model\": \"$installed_tag\",\n      \"apiBase\": \"http://localhost:11434\"\n    }"
done <<< "$INSTALLED"

MODELS_ARRAY+="\n  ]"

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
update_continue_config_native "$CHAT_TAG" "$AUTO_TAG" "$MODELS_ARRAY"

echo -e "\n${GREEN}✅ Configuration updated!${NC}"
echo -e "${CYAN}Chat model: $CHAT_TAG${NC}"
echo -e "${CYAN}Autocomplete model: $AUTO_TAG${NC}"
echo -e "\n${YELLOW}Reload VS Code to apply changes${NC}"
