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
- [x] Persistent docker-compose configuration
- [x] Docker daemon memory optimization (4GB initial + 6GB swap)
- [x] CI/CD pipeline with GitHub Actions

## Quick Start

### Prerequisites

- **Docker** (running, with compose support)
- **VS Code** with Continue extension
- **~10GB+ disk space** (Docker image + models)
- **System RAM:** 4GB minimum (8GB+ recommended for multiple models)
- **Linux/Mac/Windows** with bash support

### Memory Configuration

The setup automatically configures Docker for optimal resource usage:
- **Initial memory**: 4 GB (efficient for daily use)
- **Swap memory**: 6 GB (used only when needed)
- **Total limit**: 10 GB max
- **Config location**: `/etc/docker/daemon.json` (auto-configured during setup)

### Setup (One-time)

```bash
make setup
```

**Interactive Setup Process:**
1. Configures Docker daemon (`/etc/docker/daemon.json`): 4GB memory + 6GB swap
2. Pulls Ollama Docker image
3. Creates and starts container with `docker-compose`
4. Shows available models with specs (size, memory, quality)
5. Lets you choose which models to download
6. Configures Continue automatically for `/home/<user>/.continue/config.yaml`

**What's configured automatically:**
- ✅ Docker daemon memory limits
- ✅ Persistent `docker-compose.yml` for auto-restart
- ✅ Continue extension config with Phi-2 for autocomplete
- ✅ Swap memory as fallback

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

The setup script automatically configures Continue. To verify or manually set it up:

1. **Install Continue extension** in VS Code Marketplace
2. **Config location**: `~/.continue/config.yaml` (created automatically)
3. **Available models** in Continue:
   - **Phi-2 Local** — Fast autocomplete (default)
   - **Mistral Local** — Better reasoning & code generation
4. **Select Phi-2 Local** from Continue model dropdown:
   - Open Continue panel (left sidebar or `Ctrl+L`)
   - Click model selector at bottom
   - Choose "Phi-2 Local"
5. **Reload VS Code** if config doesn't load

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

### Docker Compose Setup

The `docker-compose.yml` provides persistent configuration:
- **Container name**: ollama-server
- **Memory limit**: 4 GB (physical)
- **Swap limit**: 10 GB total (6 GB swap)
- **Port**: 11434 (localhost only)
- **Restart policy**: always (auto-recovery)
- **Volume**: ollama-models (model persistence)

Start with compose:
```bash
make start
```

### Memory Optimization

The setup configures two levels of memory management:

**1. Docker Daemon** (`/etc/docker/daemon.json`):
```json
{
  "memory": 4294967296,
  "memswap": 10737418240
}
```

**2. Container** (`docker-compose.yml`):
```yaml
mem_limit: 4g
memswap_limit: 10g
```

**How it works:**
- Initial allocation: 4 GB (sufficient for Phi-2)
- Swap kicks in: Only when demand exceeds 4 GB
- Physical memory protected: Never uses more than 10 GB total
- Performance: Stays fast for most tasks

### Continue Extension Config

The [continue_config.json](continue_config.json) is superseded by `~/.continue/config.yaml`.

Models configured automatically:
- **Chat model**: Mistral Local (or your choice)
- **Autocomplete model**: Phi-2 Local (fast, lightweight)
- **API endpoint**: http://localhost:11434

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

- `docker-compose.yml` — Persistent container configuration (4GB memory + 6GB swap)
- `scripts/setup_ollama_docker.sh` — Interactive setup with daemon.json configuration
- `scripts/start_dev_environment.sh` — Start container using docker-compose
- `scripts/add_model.sh` — Download additional models
- `scripts/switch_model.sh` — Switch active models
- `scripts/list_models.sh` — View models and status
- `scripts/model_utils.sh` — Common model management functions
- `scripts/models.json` — Model registry with specs
- `continue_config.json` — Legacy Continue configuration (superseded by ~/.continue/config.yaml)
- `Makefile` — Convenient command shortcuts
- `.github/workflows/ci.yml` — GitHub Actions CI/CD pipeline
