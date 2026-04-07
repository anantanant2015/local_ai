#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils_native.sh"

install_ollama_if_missing() {
  if command -v ollama > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Ollama already installed${NC}"
    return 0
  fi

  echo -e "${YELLOW}Ollama not found. Installing...${NC}"
  curl -fsSL https://ollama.com/install.sh | sh
  echo -e "${GREEN}✅ Ollama installed${NC}"
}

echo -e "${CYAN}🚀 Native Ollama Setup (Non-Docker)${NC}\n"

install_ollama_if_missing
bash "$SCRIPT_DIR/start_ollama_native.sh"

show_model_menu_native

echo -e "${YELLOW}Recommendation for 16GB RAM:${NC}"
echo -e "  - qwen2.5-coder:7b for chat/code generation"
echo -e "  - qwen2.5-coder:3b or phi3:mini for autocomplete"
echo ""

read -p "Select models to install (e.g., '7 8' or '1'): " choices

declare -a SELECTED_MODELS
for choice in $choices; do
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$MODEL_COUNT" ]; then
    MODEL_KEY="${MODEL_MAP[$choice]}"

    if command -v jq > /dev/null 2>&1; then
      OLLAMA_TAG=$(jq -r ".[\"$MODEL_KEY\"].ollamaTag" "$MODELS_JSON")
      DISPLAY_NAME=$(jq -r ".[\"$MODEL_KEY\"].displayName" "$MODELS_JSON")
    else
      OLLAMA_TAG=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep ollamaTag | cut -d'"' -f4)
      DISPLAY_NAME=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep displayName | cut -d'"' -f4)
    fi

    SELECTED_MODELS+=("$OLLAMA_TAG|$DISPLAY_NAME")
  fi
done

if [ ${#SELECTED_MODELS[@]} -eq 0 ]; then
  echo -e "${YELLOW}No models selected. Using default: qwen2.5-coder:3b${NC}"
  SELECTED_MODELS=("qwen2.5-coder:3b|Qwen 2.5 Coder 3B")
fi

echo -e "\n${CYAN}📥 Downloading selected models...${NC}"
for model_info in "${SELECTED_MODELS[@]}"; do
  IFS='|' read -r tag name <<< "$model_info"
  if ! is_model_installed_native "$tag"; then
    pull_model_native "$tag" "$name"
  else
    echo -e "${GREEN}✅ $name already installed${NC}"
  fi
done

CHAT_MODEL=""
AUTOCOMPLETE_MODEL=""

for model_info in "${SELECTED_MODELS[@]}"; do
  IFS='|' read -r tag _ <<< "$model_info"
  CHAT_MODEL="$tag"
  break
done

for model_info in "${SELECTED_MODELS[@]}"; do
  IFS='|' read -r tag _ <<< "$model_info"
  if [[ "$tag" == *"3b"* ]] || [[ "$tag" == *"mini"* ]] || [[ "$tag" == "phi:latest" ]]; then
    AUTOCOMPLETE_MODEL="$tag"
    break
  fi
done

if [ -z "$AUTOCOMPLETE_MODEL" ]; then
  AUTOCOMPLETE_MODEL="$CHAT_MODEL"
fi

MODELS_CSV=""
for model_info in "${SELECTED_MODELS[@]}"; do
  IFS='|' read -r tag _ <<< "$model_info"
  [ -z "$MODELS_CSV" ] && MODELS_CSV="$tag" || MODELS_CSV="$MODELS_CSV,$tag"
done

bash "$SCRIPT_DIR/generate_continue_config.sh" --mode native --models "$MODELS_CSV" --chat "$CHAT_MODEL" --autocomplete "$AUTOCOMPLETE_MODEL"

echo -e "\n${GREEN}✅ Native setup complete!${NC}"
echo -e "${CYAN}Start: bash scripts/start_ollama_native.sh${NC}"
echo -e "${CYAN}Stop:  bash scripts/stop_ollama_native.sh${NC}"
