#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting Ollama local AI environment..."

# Start Ollama container using docker compose if not running
if ! docker ps --format '{{.Names}}' | grep -q '^ollama-server$'; then
  echo "🔄 Starting Ollama container with docker compose..."
  docker compose up -d 2>/dev/null || {
    echo "⚠️  docker-compose not available, falling back to docker..."
    docker start ollama-server 2>/dev/null || docker run -d \
      --name ollama-server \
      --memory=4g \
      --memory-swap=10g \
      -v ollama-models:/root/.ollama \
      -p 11434:11434 \
      ollama/ollama:latest
  }
  sleep 5
fi

# Verify connectivity
if curl -s http://localhost:11434 > /dev/null 2>&1; then
  echo "✅ Ollama running on http://localhost:11434"
else
  echo "⚠️  Waiting for Ollama to respond..."
  sleep 5
fi

echo "📝 In VS Code: install 'Continue' and use Phi-2 Local model"
