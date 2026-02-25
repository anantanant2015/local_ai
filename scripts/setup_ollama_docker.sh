#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Setting up Dockerized Ollama for local AI agent..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running. Start Docker and retry."
  exit 1
fi

echo "📥 Pulling Ollama image..."
docker pull ollama/ollama:latest

echo "📦 Creating Docker volume for models..."
docker volume create ollama-models || true

echo "🔄 Starting Ollama container..."
docker run -d \
  --name ollama-server \
  -v ollama-models:/root/.ollama \
  -p 11434:11434 \
  ollama/ollama:latest || true

echo "⏳ Waiting for Ollama to start (10 seconds)..."
sleep 10

echo "📥 Pulling Mistral model (may take several minutes)..."
docker exec ollama-server ollama pull mistral || true

echo "✅ Ollama is running on http://localhost:11434"
echo "Next steps:"
echo "  1. Install the Continue VS Code extension"
echo "  2. Configure Continue to use http://localhost:11434 (see local_ai_agent/continue_config.json)"
echo "To stop: docker stop ollama-server"
