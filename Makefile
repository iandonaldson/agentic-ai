.ONESHELL:
SHELL := /bin/bash
VENV_BIN := /opt/venv/bin
PY := $(VENV_BIN)/python
PIP := $(VENV_BIN)/pip
PIP_COMPILE := $(VENV_BIN)/pip-compile
PIP_SYNC := $(VENV_BIN)/pip-sync

.PHONY: help bootstrap dependencies lock sync test lint run run-dev run-with-db serve restart restart-dev stop start status update

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Service Management:"
	@echo "  restart       Stop and start web service"
	@echo "  restart-dev   Stop and start with reload (development)"
	@echo "  stop          Stop web service"
	@echo "  start         Start web service with database"
	@echo "  status        Check service status"

bootstrap: dependencies ## Initialize development environment
	echo "Initializing environment..."
	chmod +x ./.devcontainer/entrypoint.sh
	./.devcontainer/entrypoint.sh
	echo "Bootstrap complete."

dependencies: ## Install and compile dependencies
	echo "Compiling requirements..."
	$(PIP_COMPILE) ./.devcontainer/requirements.in -o requirements.txt
	$(PIP_COMPILE) ./.devcontainer/requirements-dev.in -o requirements-dev.txt
	echo "Installing requirements..."
	$(PIP) install -r requirements.txt -r requirements-dev.txt
	$(PIP) install -e .
	pre-commit install


lock: ## Update dependency lock files
	$(PIP_COMPILE) ./.devcontainer/requirements.in      -o requirements.txt
	$(PIP_COMPILE) ./.devcontainer/requirements-dev.in  -o requirements-dev.txt

sync: ## Sync environment with lock files
	$(PIP_SYNC) requirements.txt requirements-dev.txt

test: ## Run test suite
	PYTHONPATH=. pytest

lint: ## Run code linting
	ruff check .
	mypy --ignore-missing-imports .

run: ## Run web service (basic)
	$(PY) -m uvicorn main:app --host 0.0.0.0 --port 8000

run-dev: ## Run web service with auto-reload (development)
	$(PY) -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

serve: run-with-db ## Alias for run-with-db

run-with-db: ## Run web service with database setup (recommended)
	@echo "🔄 Starting database and web service..."
	@bash -c 'source .env 2>/dev/null || true; \
		export POSTGRES_USER=$${POSTGRES_USER:-app}; \
		export POSTGRES_PASSWORD=$${POSTGRES_PASSWORD:-local}; \
		export POSTGRES_DB=$${POSTGRES_DB:-appdb}; \
		export DATABASE_URL="postgresql://$${POSTGRES_USER}:$${POSTGRES_PASSWORD}@127.0.0.1:5432/$${POSTGRES_DB}"; \
		echo "🔗 DATABASE_URL=$${DATABASE_URL}"; \
		$(PY) -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload'

restart: stop start ## Restart web service

restart-dev: stop run-with-db ## Restart web service in development mode

stop: ## Stop web service
	@echo "🛑 Stopping web service..."
	@pkill -f "uvicorn main:app" 2>/dev/null || echo "No uvicorn process found"
	@echo "✅ Web service stopped"

start: ## Start web service with database
	@echo "🚀 Starting web service..."
	@$(MAKE) run-with-db

status: ## Check service status
	@echo "📊 Service Status:"
	@echo "PostgreSQL:"
	@pg_isready -h 127.0.0.1 -p 5432 -U postgres 2>/dev/null && echo "  ✅ Running" || echo "  ❌ Not running"
	@echo "Web Service:"
	@pgrep -f "uvicorn main:app" >/dev/null && echo "  ✅ Running (PID: $$(pgrep -f 'uvicorn main:app'))" || echo "  ❌ Not running"

update: ## Show outdated packages
	$(PIP) list --outdated
