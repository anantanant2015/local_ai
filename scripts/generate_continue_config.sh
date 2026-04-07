#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_JSON="$SCRIPT_DIR/models.json"
OUTPUT_FILE="${HOME}/.continue/config.yaml"
MODE="native"
MODELS_CSV=""
CHAT_MODEL=""
AUTO_MODEL=""
SINGLE_MODEL=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Generate Continue config.yaml for local Ollama.

Options:
  --mode <native|docker>      Model source (default: native)
  --models <m1,m2,...>        Models to include in config
  --chat <model_tag>          Chat model tag
  --autocomplete <model_tag>  Autocomplete model tag
  --single <model_tag>        Use one model for both chat and autocomplete
  --output <path>             Output file (default: ~/.continue/config.yaml)
  -h, --help                  Show this help

Examples:
  $(basename "$0") --mode native
  $(basename "$0") --mode native --single qwen2.5-coder:3b
  $(basename "$0") --mode docker --models phi3:mini,qwen2.5-coder:3b --chat phi3:mini --autocomplete qwen2.5-coder:3b
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --models)
      MODELS_CSV="${2:-}"
      shift 2
      ;;
    --chat)
      CHAT_MODEL="${2:-}"
      shift 2
      ;;
    --autocomplete)
      AUTO_MODEL="${2:-}"
      shift 2
      ;;
    --single)
      SINGLE_MODEL="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [ "$MODE" != "native" ] && [ "$MODE" != "docker" ]; then
  echo "Invalid --mode '$MODE'. Use 'native' or 'docker'." >&2
  exit 1
fi

if [ "$MODE" = "native" ]; then
  source "$SCRIPT_DIR/model_utils_native.sh"
  check_ollama_cli
  bash "$SCRIPT_DIR/start_ollama_native.sh" > /dev/null
  INSTALLED="$(list_installed_models_native)"
else
  source "$SCRIPT_DIR/model_utils.sh"
  check_docker
  check_ollama_container
  INSTALLED="$(list_installed_models)"
fi

if [ -z "$INSTALLED" ]; then
  echo "❌ No installed models found for mode '$MODE'." >&2
  exit 1
fi

declare -a ALL_INSTALLED
while IFS= read -r tag; do
  [ -z "$tag" ] && continue
  ALL_INSTALLED+=("$tag")
done <<< "$INSTALLED"

contains_tag() {
  local target="$1"
  shift
  for item in "$@"; do
    [ "$item" = "$target" ] && return 0
  done
  return 1
}

get_display_name() {
  local tag="$1"
  if command -v jq > /dev/null 2>&1; then
    local name
    name="$(jq -r "to_entries[] | select(.value.ollamaTag == \"$tag\") | .value.displayName" "$MODELS_JSON" 2>/dev/null | head -n 1)"
    if [ -n "$name" ] && [ "$name" != "null" ]; then
      echo "$name"
      return
    fi
  fi
  echo "$tag"
}

declare -a INCLUDED_MODELS
if [ -n "$SINGLE_MODEL" ]; then
  if ! contains_tag "$SINGLE_MODEL" "${ALL_INSTALLED[@]}"; then
    echo "❌ Model '$SINGLE_MODEL' is not installed." >&2
    exit 1
  fi
  INCLUDED_MODELS=("$SINGLE_MODEL")
  CHAT_MODEL="$SINGLE_MODEL"
  AUTO_MODEL="$SINGLE_MODEL"
elif [ -n "$MODELS_CSV" ]; then
  IFS=',' read -r -a INCLUDED_MODELS <<< "$MODELS_CSV"
else
  INCLUDED_MODELS=("${ALL_INSTALLED[@]}")
fi

if [ ${#INCLUDED_MODELS[@]} -eq 0 ]; then
  echo "❌ No models selected to include in Continue config." >&2
  exit 1
fi

for tag in "${INCLUDED_MODELS[@]}"; do
  if ! contains_tag "$tag" "${ALL_INSTALLED[@]}"; then
    echo "❌ Included model '$tag' is not installed for mode '$MODE'." >&2
    exit 1
  fi
done

if [ -z "$CHAT_MODEL" ] && [ -z "$AUTO_MODEL" ] && [ ${#INCLUDED_MODELS[@]} -gt 1 ]; then
  echo "Select model for CHAT (main interactions):"
  select CHAT_TAG in "${INCLUDED_MODELS[@]}"; do
    if [ -n "$CHAT_TAG" ]; then
      CHAT_MODEL="$CHAT_TAG"
      break
    fi
  done

  echo
  echo "Select model for AUTOCOMPLETE (tab completion):"
  select AUTO_TAG in "${INCLUDED_MODELS[@]}"; do
    if [ -n "$AUTO_TAG" ]; then
      AUTO_MODEL="$AUTO_TAG"
      break
    fi
  done
fi

if [ -z "$CHAT_MODEL" ]; then
  CHAT_MODEL="${INCLUDED_MODELS[0]}"
fi

if [ -z "$AUTO_MODEL" ]; then
  AUTO_MODEL="$CHAT_MODEL"
fi

if ! contains_tag "$CHAT_MODEL" "${INCLUDED_MODELS[@]}"; then
  echo "❌ Chat model '$CHAT_MODEL' must be present in included models." >&2
  exit 1
fi

if ! contains_tag "$AUTO_MODEL" "${INCLUDED_MODELS[@]}"; then
  echo "❌ Autocomplete model '$AUTO_MODEL' must be present in included models." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
[ -f "$OUTPUT_FILE" ] && cp "$OUTPUT_FILE" "$OUTPUT_FILE.backup"

cat > "$OUTPUT_FILE" <<EOF
name: Local Fast Agent
version: 1.1.0
schema: v1

models:
EOF

for tag in "${INCLUDED_MODELS[@]}"; do
  name="$(get_display_name "$tag")"
  cat >> "$OUTPUT_FILE" <<EOF
  - name: $name
    provider: ollama
    model: $tag
    apiBase: http://127.0.0.1:11434
    roles:
      - chat
      - edit
      - apply
      - summarize
EOF
done

cat >> "$OUTPUT_FILE" <<EOF

tabAutocompleteModel:
  name: $(get_display_name "$AUTO_MODEL")
  provider: ollama
  model: $AUTO_MODEL
  apiBase: http://127.0.0.1:11434
  completionOptions:
    temperature: 0.1
    maxTokens: 64
EOF

echo "✅ Generated Continue config: $OUTPUT_FILE"
echo "   Included models: ${INCLUDED_MODELS[*]}"
echo "   Chat model: $CHAT_MODEL"
echo "   Autocomplete model: $AUTO_MODEL"
