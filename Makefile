.PHONY: help setup start stop clean logs list-models add-model switch setup-native start-native stop-native enable-autostart-ubuntu

help:
	@echo "📋 Local AI Agent - Available Commands"
	@echo ""
	@echo "  make setup        - Interactive setup: configure Docker daemon + docker-compose"
	@echo "  make start        - Start Ollama container with persistent configuration"
	@echo "  make stop         - Stop Ollama container"
	@echo "  make logs         - Show recent container logs"
	@echo "  make clean        - Stop container and remove it"
	@echo ""
	@echo "  make setup-native - Interactive non-Docker setup (installs ollama + pulls models)"
	@echo "  make start-native - Start native ollama serve"
	@echo "  make stop-native  - Stop native ollama serve"
	@echo "  make enable-autostart-ubuntu - Enable Ubuntu boot autostart via systemd"
	@echo ""
	@echo "  make list-models  - View available models and status"
	@echo "  make add-model    - Download additional models"
	@echo "  make switch       - Switch active chat/autocomplete models"
	@echo ""
	@echo "🔧 Configuration:"
	@echo "  - Docker daemon: /etc/docker/daemon.json (4GB memory + 6GB swap)"
	@echo "  - Docker Compose: ./docker-compose.yml (persistent setup)"
	@echo "  - Continue config: ~/.continue/config.yaml"

setup:
	@bash scripts/setup_ollama_docker.sh

start:
	@bash scripts/start_dev_environment.sh

stop:
	@echo "🛑 Stopping Ollama container..."
	@docker compose down 2>/dev/null || docker stop ollama-server 2>/dev/null || echo "Container not running"

logs:
	@docker compose logs -f --tail 50 ollama-server 2>/dev/null || docker logs --tail 50 -f ollama-server 2>/dev/null || echo "Container not found"

clean:
	@echo "🧹 Cleaning up Ollama container..."
	@docker compose down -v 2>/dev/null || { docker stop ollama-server 2>/dev/null || true ; docker rm ollama-server 2>/dev/null || true ; }

list-models:
	@bash scripts/list_models.sh

add-model:
	@bash scripts/add_model.sh

switch:
	@bash scripts/switch_model.sh

setup-native:
	@bash scripts/setup_ollama_native.sh

start-native:
	@bash scripts/start_ollama_native.sh

stop-native:
	@bash scripts/stop_ollama_native.sh

enable-autostart-ubuntu:
	@bash scripts/enable_ollama_autostart_ubuntu.sh

.DEFAULT_GOAL := help
