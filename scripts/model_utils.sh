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

parse_size_to_mb() {
  local spec="$1"
  spec="$(echo "$spec" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  local n="${spec%[a-z]*}"
  if [[ "$spec" == *gb ]] || [[ "$spec" == *g ]]; then
    awk -v n="$n" 'BEGIN { printf "%d", n * 1024 }'
  elif [[ "$spec" == *mb ]] || [[ "$spec" == *m ]]; then
    awk -v n="$n" 'BEGIN { printf "%d", n }'
  else
    echo 0
  fi
}

docker_compose_mem_limit_mb() {
  local raw
  raw="$(grep -E '^\s*mem_limit:' "$PROJECT_ROOT/docker-compose.yml" | awk '{print $2}' | head -1)"
  parse_size_to_mb "$raw"
}

host_mem_available_mb() {
  if [ -f /proc/meminfo ]; then
    awk '/MemAvailable:/ { printf "%d", $2 / 1024 }' /proc/meminfo
    return
  fi
  echo 0
}

assert_memory_available() {
  local required_spec="$1"
  local mode="$2"
  local display_name="$3"
  local req_mb cap_mb cap_label

  req_mb="$(parse_size_to_mb "$required_spec")"
  if [ "$mode" = "docker" ]; then
    cap_mb="$(docker_compose_mem_limit_mb)"
    cap_label="Docker mem_limit ${cap_mb}MB"
  else
    cap_mb="$(host_mem_available_mb)"
    cap_label="host MemAvailable ${cap_mb}MB"
  fi

  if [ "$cap_mb" -le 0 ]; then
    return 0
  fi

  if [ "$req_mb" -gt "$cap_mb" ]; then
    echo -e "${RED}Refusing $display_name: needs ${required_spec}, ${cap_label} is too small${NC}"
    return 1
  fi
  return 0
}

get_model_field_by_tag() {
  local tag="$1"
  local field="$2"
  if command -v jq &> /dev/null; then
    jq -r "to_entries[] | select(.value.ollamaTag == \"$tag\") | .value.$field" "$MODELS_JSON" | head -1
    return
  fi
  echo ""
}

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

# Display model selection menu
show_model_menu() {
  local lister="${1:-${LIST_INSTALLED_FN:-list_installed_models}}"
  local installed_models
  installed_models="$($lister)"

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
      local quantization=$(jq -r ".[\"$model_key\"].quantization" "$MODELS_JSON")
      local description=$(jq -r ".[\"$model_key\"].description" "$MODELS_JSON")
      local ollama_tag=$(jq -r ".[\"$model_key\"].ollamaTag" "$MODELS_JSON")
    else
      # Fallback to grep/awk for systems without jq
      local model_block=$(cat "$MODELS_JSON" | awk "/\"$model_key\":/,/^\s*\}/" | head -20)
      local display_name=$(echo "$model_block" | grep displayName | cut -d'"' -f4)
      local size=$(echo "$model_block" | grep '"size"' | cut -d'"' -f4)
      local memory=$(echo "$model_block" | grep memoryRequired | cut -d'"' -f4)
      local quality=$(echo "$model_block" | grep '"quality"' | cut -d'"' -f4)
      local quantization=$(echo "$model_block" | grep quantization | cut -d'"' -f4)
      local description=$(echo "$model_block" | grep description | cut -d'"' -f4)
      local ollama_tag=$(echo "$model_block" | grep ollamaTag | cut -d'"' -f4)
    fi

    local installed_marker=""
    if echo "$installed_models" | grep -q "^${ollama_tag}$"; then
      installed_marker="${GREEN}[installed]${NC}"
    fi

    echo -e "${BLUE}[$i]${NC} ${YELLOW}$display_name${NC} $installed_marker"
    echo -e "    Size: $size | Memory: $memory | Quant: $quantization | Quality: $quality"
    echo -e "    $description"
    echo ""

    MODEL_MAP[$i]="$model_key"
    ((i++))
  done

  export MODEL_COUNT=$((i-1))
}

print_continue_from_yaml() {
  local path="${1:-${CONFIG_FILE:-$HOME/.continue/config.yaml}}"
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

smoke_models() {
  local chat="$1"
  local auto="${2:-$1}"
  bash "$SCRIPT_DIR/smoke_ollama.sh" "$chat"
  if [ "$auto" != "$chat" ]; then
    bash "$SCRIPT_DIR/smoke_ollama.sh" "$auto"
  fi
}
