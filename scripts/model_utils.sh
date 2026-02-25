#!/usr/bin/env bash
# Common functions for model management scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_JSON="$SCRIPT_DIR/models.json"
CONFIG_FILE="$PROJECT_ROOT/continue_config.json"

# Check if Docker is running
check_docker() {
  if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Start Docker and retry.${NC}"
    exit 1
  fi
}

# Check if Ollama container is running
check_ollama_container() {
  if ! docker ps | grep -q ollama-server; then
    echo -e "${YELLOW}⚠️  Ollama container is not running. Starting it...${NC}"
    docker start ollama-server 2>/dev/null || {
      echo -e "${RED}❌ Ollama container not found. Run 'make setup' first.${NC}"
      exit 1
    }
    echo -e "${GREEN}✅ Ollama container started${NC}"
  fi
}

# Get Docker available memory
get_docker_memory() {
  docker stats --no-stream --format "{{.MemLimit}}" ollama-server 2>/dev/null | \
    awk '{
      if ($1 ~ /GiB$/) {
        gsub(/GiB/, "", $1);
        print $1 * 1024;
      } else if ($1 ~ /MiB$/) {
        gsub(/MiB/, "", $1);
        print $1;
      } else {
        print 0;
      }
    }'
}

# List installed models
list_installed_models() {
  docker exec ollama-server ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' || echo ""
}

# Check if model is installed
is_model_installed() {
  local model_tag="$1"
  list_installed_models | grep -q "^${model_tag}$"
}

# Get model info from JSON
get_model_info() {
  local model_key="$1"
  local field="$2"
  cat "$MODELS_JSON" | grep -A 10 "\"$model_key\"" | grep "\"$field\"" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//'
}

# Pull a model
pull_model() {
  local model_tag="$1"
  local display_name="$2"
  
  echo -e "${CYAN}📥 Pulling $display_name ($model_tag)...${NC}"
  echo -e "${YELLOW}This may take several minutes depending on your internet speed.${NC}"
  
  docker exec ollama-server ollama pull "$model_tag"
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Successfully pulled $display_name${NC}"
    return 0
  else
    echo -e "${RED}❌ Failed to pull $display_name${NC}"
    return 1
  fi
}

# Update continue_config.json
update_continue_config() {
  local chat_model="$1"
  local autocomplete_model="$2"
  local all_models="$3"  # JSON array string
  
  # Backup current config
  cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
  
  # Create new config using jq if available, otherwise use sed
  if command -v jq &> /dev/null; then
    local models_array=$(echo "$all_models" | jq -c '.')
    jq --arg chat "$chat_model" \
       --arg auto "$autocomplete_model" \
       --argjson models "$models_array" \
       '.models = $models | 
        .tabAutocompleteModel.model = $auto |
        .tabAutocompleteModel.title = ($models[] | select(.model == $auto) | .title)' \
       "$CONFIG_FILE.backup" > "$CONFIG_FILE"
  else
    # Fallback: manual JSON construction
    cat > "$CONFIG_FILE" <<EOF
{
  "models": $all_models,
  "tabAutocompleteModel": {
    "title": "Autocomplete",
    "provider": "ollama",
    "model": "$autocomplete_model",
    "apiBase": "http://localhost:11434"
  },
  "slashCommands": [
    { "name": "share", "description": "Export the current chat" },
    { "name": "commit", "description": "Generate a git commit message" }
  ]
}
EOF
  fi
  
  echo -e "${GREEN}✅ Updated continue_config.json${NC}"
}

# Display model selection menu
show_model_menu() {
  local installed_models=$(list_installed_models)
  
  echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}                  Available Models                          ${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
  
  local i=1
  declare -g -A MODEL_MAP
  
  # Parse JSON properly using grep to extract each model block
  local model_keys=($(cat "$MODELS_JSON" | grep -o '"[^"]*": *{' | grep -o '"[^"]*"' | tr -d '"'))
  
  for model_key in "${model_keys[@]}"; do
    # Extract model info using jq if available, otherwise use grep
    if command -v jq &> /dev/null; then
      local display_name=$(jq -r ".[\"$model_key\"].displayName" "$MODELS_JSON")
      local size=$(jq -r ".[\"$model_key\"].size" "$MODELS_JSON")
      local memory=$(jq -r ".[\"$model_key\"].memoryRequired" "$MODELS_JSON")
      local quality=$(jq -r ".[\"$model_key\"].quality" "$MODELS_JSON")
      local description=$(jq -r ".[\"$model_key\"].description" "$MODELS_JSON")
      local ollama_tag=$(jq -r ".[\"$model_key\"].ollamaTag" "$MODELS_JSON")
    else
      # Fallback to grep/awk for systems without jq
      local model_block=$(cat "$MODELS_JSON" | awk "/\"$model_key\":/,/^\s*\}/" | head -20)
      local display_name=$(echo "$model_block" | grep displayName | cut -d'"' -f4)
      local size=$(echo "$model_block" | grep '"size"' | cut -d'"' -f4)
      local memory=$(echo "$model_block" | grep memoryRequired | cut -d'"' -f4)
      local quality=$(echo "$model_block" | grep '"quality"' | cut -d'"' -f4)
      local description=$(echo "$model_block" | grep description | cut -d'"' -f4)
      local ollama_tag=$(echo "$model_block" | grep ollamaTag | cut -d'"' -f4)
    fi
    
    local installed_marker=""
    if echo "$installed_models" | grep -q "^${ollama_tag}$"; then
      installed_marker="${GREEN}[installed]${NC}"
    fi
    
    echo -e "${BLUE}[$i]${NC} ${YELLOW}$display_name${NC} $installed_marker"
    echo -e "    Size: $size | Memory: $memory | Quality: $quality"
    echo -e "    $description"
    echo ""
    
    MODEL_MAP[$i]="$model_key"
    ((i++))
  done
  
  export MODEL_COUNT=$((i-1))
}
