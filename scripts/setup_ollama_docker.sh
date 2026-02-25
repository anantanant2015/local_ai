#!/usr/bin/env bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/model_utils.sh"

echo -e "${CYAN}🚀 Interactive Ollama Setup${NC}\n"

# Check if Docker is running
check_docker

# Configure Docker daemon for optimal memory usage
echo -e "${BLUE}🔧 Configuring Docker daemon for optimal memory...${NC}"
DAEMON_JSON="/etc/docker/daemon.json"
if [ ! -f "$DAEMON_JSON" ]; then
  sudo bash -c 'echo "{}" > '"$DAEMON_JSON"
fi

# Check if memory is already configured
if ! sudo grep -q '"memory"' "$DAEMON_JSON"; then
  echo -e "${YELLOW}Setting up Docker daemon memory configuration...${NC}"
  sudo tee "$DAEMON_JSON" > /dev/null <<EOF
{
  "memory": 4294967296,
  "memswap": 10737418240,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
  echo -e "${GREEN}✅ Docker daemon configured: 4GB memory + 6GB swap${NC}"
  echo -e "${YELLOW}⚠️  Note: Restart Docker for changes to take effect${NC}"
  echo -e "${BLUE}   Run: sudo systemctl restart docker${NC}\n"
else
  echo -e "${GREEN}✅ Docker daemon already configured${NC}\n"
fi

# Pull Ollama image
echo -e "${BLUE}📥 Pulling Ollama image...${NC}"
docker pull ollama/ollama:latest

# Create volume
echo -e "${BLUE}📦 Creating Docker volume for models...${NC}"
docker volume create ollama-models || true

# Check if container exists
if docker ps -a | grep -q ollama-server; then
  echo -e "${YELLOW}⚠️  Ollama container already exists${NC}"
  read -p "Remove and recreate? (y/N): " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    docker compose down 2>/dev/null || docker rm -f ollama-server 2>/dev/null || true
  else
    echo -e "${BLUE}Starting existing container...${NC}"
    docker compose up -d 2>/dev/null || docker start ollama-server 2>/dev/null || true
    sleep 5
  fi
fi

# Start container using docker compose if not running
if ! docker ps | grep -q ollama-server; then
  echo -e "${BLUE}🔄 Starting Ollama container with docker compose...${NC}"
  docker compose up -d

  echo -e "${BLUE}⏳ Waiting for Ollama to start...${NC}"
  sleep 10
fi

echo -e "${GREEN}✅ Ollama container is running${NC}\n"

# Check Docker memory
DOCKER_MEM=$(get_docker_memory)
if [ "$DOCKER_MEM" -gt 0 ] && [ "$DOCKER_MEM" -lt 4096 ]; then
  echo -e "${YELLOW}⚠️  Warning: Docker memory limit is ${DOCKER_MEM}MB${NC}"
  echo -e "${YELLOW}   Consider increasing to 8GB for larger models${NC}"
  echo -e "${YELLOW}   Docker Desktop → Settings → Resources → Memory${NC}\n"
fi

# Model selection
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    Model Selection                         ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"

show_model_menu

echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
echo -e "${YELLOW}Recommendation: Start with Phi (fast, lightweight) for autocomplete${NC}"
echo -e "${YELLOW}                Add Mistral later for better chat quality${NC}\n"

read -p "Select models to install (e.g., '1 2' or '1' for Phi only): " choices

# Parse selections
declare -a SELECTED_MODELS
for choice in $choices; do
  if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$MODEL_COUNT" ]; then
    MODEL_KEY="${MODEL_MAP[$choice]}"

    if command -v jq &> /dev/null; then
      OLLAMA_TAG=$(jq -r ".[\"$MODEL_KEY\"].ollamaTag" "$MODELS_JSON")
      DISPLAY_NAME=$(jq -r ".[\"$MODEL_KEY\"].displayName" "$MODELS_JSON")
    else
      OLLAMA_TAG=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep ollamaTag | cut -d'"' -f4)
      DISPLAY_NAME=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep displayName | cut -d'"' -f4)
    fi

    SELECTED_MODELS+=("$OLLAMA_TAG:$DISPLAY_NAME")
  fi
done

if [ ${#SELECTED_MODELS[@]} -eq 0 ]; then
  echo -e "${YELLOW}No models selected. Using default: Phi${NC}"
  SELECTED_MODELS=("phi:latest:Phi-2")
fi

# Download selected models
echo -e "\n${CYAN}📥 Downloading selected models...${NC}"
for model_info in "${SELECTED_MODELS[@]}"; do
  IFS=':' read -r tag name <<< "$model_info"
  if ! is_model_installed "$tag"; then
    pull_model "$tag" "$name"
  else
    echo -e "${GREEN}✅ $name already installed${NC}"
  fi
done

# Configure Continue
echo -e "\n${CYAN}🔧 Configuring Continue extension...${NC}"

# Build models array
MODELS_ARRAY="["
FIRST=true
AUTOCOMPLETE_MODEL=""
SMALLEST_SIZE=999999

for model_info in "${SELECTED_MODELS[@]}"; do
  IFS=':' read -r tag name <<< "$model_info"

  # Find model key and get size
  if command -v jq &> /dev/null; then
    MODEL_KEY=$(jq -r "to_entries[] | select(.value.ollamaTag == \"$tag\") | .key" "$MODELS_JSON")
    SIZE_GB=$(jq -r ".[\"$MODEL_KEY\"].size" "$MODELS_JSON" | grep -o '[0-9.]*' | head -1)
  else
    MODEL_KEY=$(cat "$MODELS_JSON" | grep -B 8 "\"ollamaTag\": \"$tag\"" | grep -o '"[^"]*": *{' | head -1 | tr -d '": {')
    SIZE_GB=$(cat "$MODELS_JSON" | awk "/\"$MODEL_KEY\":/,/^\s*\}/" | grep '"size"' | grep -o '[0-9.]*' | head -1)
  fi

  SIZE_INT=$(echo "$SIZE_GB * 1000" | bc 2>/dev/null || echo "1000" | cut -d. -f1)

  if [ "$SIZE_INT" -lt "$SMALLEST_SIZE" ]; then
    SMALLEST_SIZE=$SIZE_INT
    AUTOCOMPLETE_MODEL=$tag
  fi

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    MODELS_ARRAY+=","
  fi

  MODELS_ARRAY+="
    {
      \"title\": \"$name\",
      \"provider\": \"ollama\",
      \"model\": \"$tag\",
      \"apiBase\": \"http://localhost:11434\"
    }"
done

MODELS_ARRAY+="
  ]"

# Use first model as chat if only one selected
CHAT_MODEL="${SELECTED_MODELS[0]%%:*}"
update_continue_config "$CHAT_MODEL" "$AUTOCOMPLETE_MODEL" "$MODELS_ARRAY"

echo -e "\n${GREEN}✅ Setup complete!${NC}"
echo -e "\n${CYAN}Next steps:${NC}"
echo -e "  1. Install Continue VS Code extension (if not already installed)"
echo -e "  2. Reload VS Code to apply configuration"
echo -e "  3. Start chatting with your local AI models!"
echo -e "\n${CYAN}Useful commands:${NC}"
echo -e "  ${GREEN}make list-models${NC} - View all available models"
echo -e "  ${GREEN}make add-model${NC}   - Download additional models"
echo -e "  ${GREEN}make switch${NC}      - Switch active models"
echo -e "  ${GREEN}make stop${NC}        - Stop Ollama container"
echo -e "\n${BLUE}Ollama API: http://localhost:11434${NC}"
