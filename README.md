# Local AI Agent — Dockerized Ollama with Continue Extension

This repository contains a self-contained local AI agent setup using Dockerized Ollama integrated with the Continue VS Code extension. Run LLMs privately on your machine without internet dependencies.

## ✅ Completion Status

All setup tasks completed:

- [x] Add setup and start scripts for Dockerized Ollama
- [x] Add Continue config for local provider
- [x] Verify connection from Continue to Ollama (http://localhost:11434)
- [x] Document usage and troubleshooting steps

## Quick Start

### Prerequisites

- **Docker** (running)
- **VS Code** with Continue extension
- **~25GB disk space** (Docker image + model cache)

### Setup (One-time)

```bash
make setup
```

This will:
- Pull the Ollama Docker image
- Start the container
- Download the Mistral 7B model (~8GB)
- Listen on `http://localhost:11434`

**⏱️ First-time setup takes 10–30 minutes** (depends on internet speed for model download)

### Start Using

```bash
make start
```

Verify connectivity:
```bash
curl http://localhost:11434
```

Expected response: HTTP header with version info.

## Configure Continue in VS Code

1. **Install Continue extension** in VS Code Marketplace
2. **Copy config to VS Code settings**:
   - Linux/Mac: `cp continue_config.json ~/.continue/config.json`
   - Windows: `cp continue_config.json $env:APPDATA\.continue\config.json`
3. **Reload VS Code** and use Continue with local models

The extension will connect to `http://localhost:11434` automatically.

## Usage Commands

| Command | Purpose |
|---------|---------|
| `make setup` | First-time setup: pull image, start container, download model |
| `make start` | Start container and verify connectivity |
| `make stop` | Stop the container |
| `make logs` | View recent container logs |
| `make clean` | Stop and remove container |
| `make help` | Show all commands |

## Sharing with Others

The `local_ai_agent/` directory is **completely self-contained**:
is repository is **completely self-contained**:

1. Clone or copy this repositoryat machine
3. Their VS Code will have a local, private AI agent

No server management needed—everything is local Docker.

## Architecture

- **Container**: Ollama (official Docker image)
- **Model**: Mistral 7B (default)
- **Storage**: Docker volume `ollama-models` (persists across restarts)
- **Port**: 11434 (local only, not exposed to network)
- **API**: OpenAI-compatible REST API

## Configuration

Edit [continue_config.json](continue_config.json) to:
- Change model (e.g., `mistral` → `llama2`)
- Update API base URL
- Add slash commands or settings

## Troubleshooting

### Container won't start

```bash
# Check Docker status
docker ps -a

# View logs
make logs

# Clean and retry
make clean
make setup
```

### Model download stuck

Ensure sufficient disk space and stable internet. Model files go to Docker volume `ollama-models`.

### VS Code can't connect

- Verify container is running: `docker ps`
- Check connectivity: `curl http://localhost:11434`
- Restart Continue extension in VS Code (Cmd/Ctrl+Shift+P → Reload Window)

## Files

- `scripts/setup_ollama_docker.sh` — Full setup automation
- `scripts/start_dev_environment.sh` — Start container and verify
- `continue_config.json` — VS Code Continue configuration
- `Makefile` — Convenient command shortcuts
