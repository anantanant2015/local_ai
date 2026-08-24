#!/usr/bin/env bash
set -euo pipefail

# Unloads any currently resident Ollama models to free host RAM.
if ! command -v ollama > /dev/null 2>&1; then
  echo "❌ Ollama CLI not found."
  exit 1
fi

if ! pgrep -x ollama > /dev/null 2>&1; then
  echo "ℹ️ Ollama is not running. Nothing to unload."
  exit 0
fi

LOADED_MODELS=$(ollama ps 2>/dev/null | awk 'NR>1 && NF>0 {print $1}')

if [ -z "${LOADED_MODELS}" ]; then
  echo "✅ No models are currently loaded."
  exit 0
fi

echo "🧹 Unloading loaded models from RAM..."
while IFS= read -r model; do
  [ -z "$model" ] && continue
  echo "  - unloading $model"
  # Keep-alive 0 asks Ollama to unload this model immediately.
  curl -sS http://127.0.0.1:11434/api/generate \
    -d "{\"model\":\"$model\",\"prompt\":\"\",\"keep_alive\":0}" > /dev/null || true
done <<< "$LOADED_MODELS"

echo "✅ Unload request sent. Current loaded models:"
ollama ps || true
