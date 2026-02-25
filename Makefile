.PHONY: help setup start stop clean logs list-models add-model switch

help:
	@echo "📋 Local AI Agent - Available Commands"
	@echo ""
	@echo "  make setup        - Interactive setup: choose models and configure Continue"
	@echo "  make start        - Start Ollama container and verify connectivity"
	@echo "  make stop         - Stop Ollama container"
	@echo "  make logs         - Show recent container logs"
	@echo "  make clean        - Stop container and remove it"
	@echo ""
	@echo "  make list-models  - View available models and status"
	@echo "  make add-model    - Download additional models"
	@echo "  make switch       - Switch active chat/autocomplete models"
	@echo ""
	@echo "Configuration: see continue_config.json for VS Code Continue extension setup"

setup:
	@bash scripts/setup_ollama_docker.sh

start:
	@bash scripts/start_dev_environment.sh

stop:
	@echo "🛑 Stopping Ollama container..."
	@docker stop ollama-server 2>/dev/null || echo "Container not running"

logs:
	@docker logs --tail 50 -f ollama-server 2>/dev/null || echo "Container not found"

clean:
	@echo "🧹 Cleaning up Ollama container..."
	@docker stop ollama-server 2>/dev/null || true
	@docker rm ollama-server 2>/dev/null || echo "Container removed or not found"

list-models:
	@bash scripts/list_models.sh

add-model:
	@bash scripts/add_model.sh

switch:
	@bash scripts/switch_model.sh

.DEFAULT_GOAL := help
