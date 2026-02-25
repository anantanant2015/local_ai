#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Ollama local AI environment..."

# Start Ollama container if not running
if ! docker ps --format '{{.Names}}' | grep -q '^ollama-server$'; then
  echo "🔄 Starting Ollama container..."
  docker start ollama-server 2>/dev/null || docker run -d \
    --name ollama-server \
    -v ollama-models:/root/.ollama \
    -p 11434:11434 \
    ollama/ollama:latest
  sleep 5
fi

echo "✅ Ollama running on http://localhost:11434"
echo "In VS Code: install 'Continue' and configure local provider using continue_config.json"
