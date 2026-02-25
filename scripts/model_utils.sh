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
  
  while IFS= read -r model_key; do
    local display_name=$(cat "$MODELS_JSON" | grep -A 2 "\"$model_key\"" | grep "displayName" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
    local size=$(cat "$MODELS_JSON" | grep -A 3 "\"$model_key\"" | grep "size" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
    local memory=$(cat "$MODELS_JSON" | grep -A 4 "\"$model_key\"" | grep "memoryRequired" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
    local quality=$(cat "$MODELS_JSON" | grep -A 6 "\"$model_key\"" | grep "quality" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
    local description=$(cat "$MODELS_JSON" | grep -A 7 "\"$model_key\"" | grep "description" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
    local ollama_tag=$(cat "$MODELS_JSON" | grep -A 8 "\"$model_key\"" | grep "ollamaTag" | sed 's/.*: "\(.*\)".*/\1/' | sed 's/,$//')
    
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
  done < <(cat "$MODELS_JSON" | grep -E '^\s*"[^"]+":' | sed 's/.*"\([^"]*\)".*/\1/')
  
  export MODEL_COUNT=$((i-1))
}
