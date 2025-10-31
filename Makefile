.ONESHELL:
SHELL := /bin/bash
VENV_BIN := /opt/venv/bin
PY := $(VENV_BIN)/python
PIP := $(VENV_BIN)/pip
PIP_COMPILE := $(VENV_BIN)/pip-compile
PIP_SYNC := $(VENV_BIN)/pip-sync

.PHONY: help bootstrap dependencies lock sync test lint start restart restart-all stop stop-all status update

help: ## Show this help message
	@echo "Service Management:"
	@echo "  start         Start web service with database"
	@echo "  stop          Stop web service only"
	@echo "  stop-all      Stop web service and database"
	@echo "  restart       Stop and start just the web-service"
	@echo "  restart-all   Stop and restart web-service and database"
	@echo "  status        Check service status"
	@echo ""
	@echo "All available targets for development and service management:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'


bootstrap: dependencies ## Initialize development environment
	echo "Initializing environment..."
	chmod +x ./.devcontainer/entrypoint.sh
	./.devcontainer/entrypoint.sh
	echo "Bootstrap complete."

dependencies: ## Install and compile dependencies
	echo "Compiling requirements..."
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements.in -o requirements.txt
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements-dev.in -o requirements-dev.txt
	echo "Installing requirements..."
	$(PIP) install -r requirements.txt -r requirements-dev.txt
	$(PIP) install -e .
	pre-commit install


lock: ## Update dependency lock files
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements.in      -o requirements.txt
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements-dev.in  -o requirements-dev.txt

sync: ## Sync environment with lock files
	$(PIP_SYNC) requirements.txt requirements-dev.txt

test: ## Run test suite
	TESTING=1 PYTHONPATH=. pytest

lint: ## Run code linting
	ruff check .
	mypy --ignore-missing-imports .

start: ## Start web service with database
	@echo "🗄️ Starting PostgreSQL..."
	@bash -c 'PG_MAJOR="$$(psql -V | awk "{print \$$3}" | cut -d. -f1)" && pg_ctlcluster "$${PG_MAJOR}" main start 2>/dev/null || echo "PostgreSQL already running"'
	@echo "✅ PostgreSQL started"
	@echo "🔄 Starting database and web service..."
	@bash -c 'source .env 2>/dev/null || true; \
		export POSTGRES_USER=$${POSTGRES_USER:-app}; \
		export POSTGRES_PASSWORD=$${POSTGRES_PASSWORD:-local}; \
		export POSTGRES_DB=$${POSTGRES_DB:-appdb}; \
		export DATABASE_URL="postgresql://$${POSTGRES_USER}:$${POSTGRES_PASSWORD}@127.0.0.1:5432/$${POSTGRES_DB}"; \
		echo "🔗 DATABASE_URL=$${DATABASE_URL}"; \
		$(PY) -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload'

restart: stop start ## Restart web service with reload

restart-all: stop-all start ## Stop and re-start web-service and database services

stop: ## Stop just web service
	@echo "🛑 Stopping web service..."
	@pkill -f "uvicorn.*main:app" 2>/dev/null || echo "No uvicorn process found"
	@echo "✅ Web service stopped"

stop-all: ## Stop web service and database
	@echo "🛑 Stopping all services..."
	@pkill -f "uvicorn.*main:app" 2>/dev/null || echo "No uvicorn process found"
	@sudo -u postgres pg_ctlcluster $$(psql -V | awk '{print $$3}' | cut -d. -f1) main stop 2>/dev/null || echo "PostgreSQL already stopped"
	@echo "✅ All services stopped"

status: ## Check service status
	@echo "📊 Service Status:"
	@echo "PostgreSQL:"
	@pg_isready -h 127.0.0.1 -p 5432 -U postgres 2>/dev/null && echo "  ✅ Running" || echo "  ❌ Not running"
	@echo "Web Service:"
	@pgrep -f "[u]vicorn.*main:app" >/dev/null 2>&1 && echo "  ✅ Running (PID: $$(pgrep -f '[u]vicorn.*main:app'))" || echo "  ❌ Not running"

update: ## Show outdated packages
	$(PIP) list --outdated
