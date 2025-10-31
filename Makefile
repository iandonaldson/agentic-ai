.ONESHELL:
SHELL := /bin/bash
VENV_BIN := /opt/venv/bin
PY := $(VENV_BIN)/python
PIP := $(VENV_BIN)/pip
PIP_COMPILE := $(VENV_BIN)/pip-compile
PIP_SYNC := $(VENV_BIN)/pip-sync

.PHONY: help bootstrap bootstrap-codespace dependencies dependencies-docker lock sync test lint start restart restart-all stop stop-all status update docker-build docker-dev docker-prod docker-clean validate validate-env validate-services validate-docker validate-all

help: ## Show this help message
	@echo "Service Management:"
	@echo "  start         Start web service with database"
	@echo "  stop          Stop web service only"
	@echo "  stop-all      Stop web service and database"
	@echo "  restart       Stop and start just the web-service"
	@echo "  restart-all   Stop and restart web-service and database"
	@echo "  status        Check service status"
	@echo ""
	@echo "Docker Management:"
	@echo "  docker-build  Build Docker images"
	@echo "  docker-dev    Run development environment with Docker"
	@echo "  docker-prod   Run production environment with Docker"
	@echo "  docker-clean  Clean up Docker resources"
	@echo ""
	@echo "Validation & Testing:"
	@echo "  validate-env  Validate development environment"
	@echo "  validate-services Test service integration"
	@echo "  validate-docker Test Docker functionality (requires Docker)"
	@echo "  validate-all  Run all validation tests"
	@echo ""
	@echo "All available targets for development and service management:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'


bootstrap: dependencies ## Initialize development environment
	echo "Initializing environment..."
	chmod +x ./.devcontainer/entrypoint.sh
	./.devcontainer/entrypoint.sh
	echo "Bootstrap complete."

bootstrap-codespace: ## Initialize environment for Codespace (deps already compiled)
	echo "Installing workspace-specific dependencies..."
	$(PIP) install -r requirements-dev.txt  # Only install dev deps (base already in image)
	$(PIP) install -e .                      # Editable install in workspace
	pre-commit install                       # Hooks in workspace
	chmod +x ./.devcontainer/setup-db.sh
	./.devcontainer/setup-db.sh              # Setup database without starting server
	echo "Codespace bootstrap complete."

dependencies: ## Install and compile dependencies
	echo "Compiling requirements..."
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements.in -o requirements.txt
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements-dev.in -o requirements-dev.txt
	echo "Installing requirements..."
	$(PIP) install -r requirements.txt -r requirements-dev.txt
	$(PIP) install -e .
	pre-commit install

dependencies-docker: ## Compile requirements and install base dependencies (for Docker build)
	echo "Compiling requirements for Docker build..."
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements.in -o requirements.txt
	$(PIP_COMPILE) --strip-extras ./.devcontainer/requirements-dev.in -o requirements-dev.txt
	echo "Installing base requirements..."
	$(PIP) install -r requirements.txt


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

# ============================================================================
# Docker Management
# ============================================================================

docker-build: ## Build Docker images for development and production
	docker build --target development -t agentic-ai:dev .
	docker build --target production -t agentic-ai:prod .

docker-dev: ## Run development environment with Docker Compose
	@echo "🐳 Starting development environment with Docker..."
	docker-compose --profile dev up --build

docker-prod: ## Run production environment with Docker Compose
	@echo "🐳 Starting production environment with Docker..."
	docker-compose --profile prod up --build -d

docker-clean: ## Clean up Docker resources
	@echo "🧹 Cleaning up Docker resources..."
	docker-compose down --volumes --remove-orphans
	docker system prune -f

# ============================================================================
# Validation & Testing
# ============================================================================

validate-env: ## Validate development environment setup
	@echo "🔍 Validating development environment..."
	./scripts/validate_environment.sh

validate-services: ## Test service integration and functionality
	@echo "🔧 Testing service integration..."
	./scripts/test_services.sh

validate-docker: ## Test Docker functionality (requires Docker daemon)
	@echo "🐳 Validating Docker setup..."
	./scripts/validate_docker.sh

validate-all: validate-env validate-services ## Run all validation tests (except Docker)
	@echo "✅ All validation tests completed successfully!"

validate: validate-all ## Alias for validate-all
