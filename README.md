# Local AI Agent — Dockerized Ollama with Continue Extension

This repository contains a self-contained local AI agent setup using Dockerized Ollama integrated with the Continue VS Code extension. Run LLMs privately on your machine without internet dependencies.

## ✅ Completion Status

All setup tasks completed:

- [x] Add setup and start scripts for Dockerized Ollama
- [x] Add Continue config for local provider
- [x] Verify connection from Continue to Ollama (http://localhost:11434)
- [x] Document usage and troubleshooting steps
- [x] Interactive model selection during setup
- [x] Model management commands (add/switch/list)
- [x] Support for multiple models (Phi, Mistral, CodeLlama, etc.)
- [x] Memory-aware model recommendations

## Quick Start

### Prerequisites

- **Docker** (running)
- **VS Code** with Continue extension
- **~10GB+ disk space** (Docker image + models)
- **Recommended:** 8GB+ Docker memory for larger models

### Setup (One-time)

```bash
make setup
```

**Interactive Setup Process:**
1. Pulls Ollama Docker image
2. Creates and starts the container
3. Shows available models with specs (size, memory, quality)
4. Lets you choose which models to download
5. Configures Continue automatically

**Default recommendation:** Start with Phi (1.6GB, fast) for autocomplete

**⏱️ First-time setup:** 5–30 minutes depending on models selected and internet speed

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

### Basic Operations

| Command | Purpose |
|---------|---------|  
| `make setup` | Interactive setup: choose models and configure Continue |
| `make start` | Start container and verify connectivity |
| `make stop` | Stop the container |
| `make logs` | View recent container logs |
| `make clean` | Stop and remove container |
| `make help` | Show all commands |

### Model Management

| Command | Purpose |
|---------|---------|  
| `make list-models` | View available models and installation status |
| `make add-model` | Download additional models interactively |
| `make switch` | Switch active chat and autocomplete models |

The `local_ai_agent/` directory is **completely self-contained**:
is repository is **completely self-contained**:

1. Clone or copy this repositoryat machine
3. Their VS Code will have a local, private AI agent

No server management needed—everything is local Docker.

## Architecture

- **Container**: Ollama (official Docker image)
- **Models**: Multiple supported (Phi-2, Mistral, CodeLlama, Llama2, etc.)
- **Storage**: Docker volume `ollama-models` (persists across restarts)
- **Port**: 11434 (local only, not exposed to network)
- **API**: OpenAI-compatible REST API

## Available Models

| Model | Size | Memory | Best For |
|-------|------|--------|----------|
| **Phi-2** | 1.6 GB | 2.5 GB | Autocomplete, fast responses |
| **Mistral 7B** | 4.4 GB | 5.0 GB | Complex reasoning, code generation |
| **CodeLlama 7B** | 3.8 GB | 4.5 GB | Code-specific tasks |
| **Llama2 7B** | 3.8 GB | 4.5 GB | General conversation |
| **Neural Chat 7B** | 4.1 GB | 4.8 GB | Dialogue optimization |
| **Orca Mini 3B** | 1.9 GB | 3.0 GB | Lightweight alternative |

## Configuration

The [continue_config.json](continue_config.json) is automatically managed by setup/switch commands. Manual editing is supported for:
- Advanced model parameters
- Custom slash commands
- API configuration

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

- `scripts/setup_ollama_docker.sh` — Interactive setup automation
- `scripts/start_dev_environment.sh` — Start container and verify
- `scripts/add_model.sh` — Download additional models
- `scripts/switch_model.sh` — Switch active models
- `scripts/list_models.sh` — View models and status
- `scripts/model_utils.sh` — Common model management functions
- `scripts/models.json` — Model registry with specs
- `continue_config.json` — VS Code Continue configuration (auto-generated)
- `Makefile` — Convenient command shortcuts
