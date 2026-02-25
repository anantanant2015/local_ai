#!/usr/bin/env bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils.sh"

echo -e "${CYAN}🔄 Switch Active Models${NC}\n"

# Check prerequisites
check_docker
check_ollama_container

# Get installed models
INSTALLED=$(list_installed_models)

if [ -z "$INSTALLED" ]; then
  echo -e "${RED}❌ No models installed. Run 'make add-model' first.${NC}"
  exit 1
fi

echo -e "${GREEN}Installed Models:${NC}"
echo "$INSTALLED" | nl
echo ""

# Build models array for config
MODELS_ARRAY="["
FIRST=true

while IFS= read -r installed_tag; do
  # Find model key from tag
  if command -v jq &> /dev/null; then
    MODEL_KEY=$(jq -r "to_entries[] | select(.value.ollamaTag == \"$installed_tag\") | .key" "$MODELS_JSON")
    if [ -n "$MODEL_KEY" ]; then
      DISPLAY_NAME=$(jq -r ".[\"$MODEL_KEY\"].displayName" "$MODELS_JSON")
    fi
  else
    # Fallback: search for the tag and extract model key
    MODEL_KEY=$(cat "$MODELS_JSON" | grep -B 8 "\"ollamaTag\": \"$installed_tag\"" | grep -o '"[^"]*": *{' | head -1 | tr -d '": {')
    if [ -n "$MODEL_KEY" ]; then
      DISPLAY_NAME=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep displayName | cut -d'"' -f4)
    fi
  fi
  
  if [ -n "$MODEL_KEY" ]; then
    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      MODELS_ARRAY+=","
    fi
    
    MODELS_ARRAY+="
    {
      \"title\": \"$DISPLAY_NAME\",
      \"provider\": \"ollama\",
      \"model\": \"$installed_tag\",
      \"apiBase\": \"http://localhost:11434\"
    }"
  fi
done <<< "$INSTALLED"

MODELS_ARRAY+="
  ]"

# Select chat model
echo -e "${CYAN}Select model for CHAT (main interactions):${NC}"
select CHAT_TAG in $INSTALLED; do
  if [ -n "$CHAT_TAG" ]; then
    break
  fi
done

# Select autocomplete model
echo -e "\n${CYAN}Select model for AUTOCOMPLETE (tab completion):${NC}"
echo -e "${YELLOW}Tip: Choose a smaller/faster model for better autocomplete performance${NC}"
select AUTO_TAG in $INSTALLED; do
  if [ -n "$AUTO_TAG" ]; then
    break
  fi
done

# Update config
echo -e "\n${BLUE}Updating Continue configuration...${NC}"
update_continue_config "$CHAT_TAG" "$AUTO_TAG" "$MODELS_ARRAY"

echo -e "\n${GREEN}✅ Configuration updated!${NC}"
echo -e "${CYAN}Chat model: $CHAT_TAG${NC}"
echo -e "${CYAN}Autocomplete model: $AUTO_TAG${NC}"
echo -e "\n${YELLOW}Reload VS Code to apply changes${NC}"
