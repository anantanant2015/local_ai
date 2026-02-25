#!/usr/bin/env bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils.sh"

echo -e "${CYAN}🤖 Add/Download Ollama Model${NC}\n"

# Check prerequisites
check_docker
check_ollama_container

# Show available models
show_model_menu

# Get user selection
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

# Get selected model
MODEL_KEY="${MODEL_MAP[$choice]}"
DISPLAY_NAME=$(cat "$MODELS_JSON" | grep -A 2 "\"$MODEL_KEY\"" | grep "displayName" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
OLLAMA_TAG=$(cat "$MODELS_JSON" | grep -A 8 "\"$MODEL_KEY\"" | grep "ollamaTag" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
MEMORY_REQ=$(cat "$MODELS_JSON" | grep -A 4 "\"$MODEL_KEY\"" | grep "memoryRequired" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')

# Check if already installed
if is_model_installed "$OLLAMA_TAG"; then
  echo -e "${YELLOW}⚠️  $DISPLAY_NAME is already installed${NC}"
  read -p "Do you want to re-download it? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Skipping download"
    exit 0
  fi
fi

# Check Docker memory
echo -e "\n${BLUE}ℹ️  Model requires: $MEMORY_REQ${NC}"
echo -e "${BLUE}ℹ️  Run 'docker stats --no-stream ollama-server' to check available memory${NC}\n"

read -p "Continue with download? (Y/n): " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
  echo "Download cancelled"
  exit 0
fi

# Pull the model
pull_model "$OLLAMA_TAG" "$DISPLAY_NAME"

echo -e "\n${GREEN}✅ Model added successfully!${NC}"
echo -e "${CYAN}Use 'make switch' to configure Continue to use this model${NC}"
