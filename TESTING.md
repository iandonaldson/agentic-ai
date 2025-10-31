# Testing Documentation for Agentic AI

This document provides comprehensive testing procedures for validating the Agentic AI development environment in different deployment scenarios.

## 🎯 Testing Overview

The project supports three deployment methods:
1. **GitHub Codespaces/VS Code DevContainers** (Primary development)
2. **Docker Compose** (Local development and production)
3. **Standalone Docker** (Production deployment)

## 📋 Testing Scenarios

### Scenario 1: Fresh GitHub Codespace
Tests the complete setup from scratch in a new Codespace.

### Scenario 2: Existing Development Environment
Validates that existing environments still work after changes.

### Scenario 3: Docker Deployment
Tests Docker-based deployment options.

---

## 🧪 Test Scripts

### 1. Environment Validation (`scripts/validate_environment.sh`)

**Purpose**: Validates that the development environment is properly configured.

**What it tests**:
- System dependencies (Python, Make, PostgreSQL, Git)
- Python virtual environment configuration
- Required project files
- Environment variables
- Makefile targets
- Service status
- Python package installation

**Usage**:
```bash
./scripts/validate_environment.sh
```

**Expected Results**:
- All system dependencies should be found
- Python should be using `/opt/venv/bin/python`
- All required project files should exist
- Makefile targets should be valid
- Services should be manageable via `make status`

### 2. Service Integration Tests (`scripts/test_services.sh`)

**Purpose**: Tests that all services work together correctly.

**What it tests**:
- PostgreSQL connectivity
- FastAPI web service responsiveness
- Basic HTTP endpoints
- Health checks
- API functionality (if API keys configured)
- Error handling

**Usage**:
```bash
./scripts/test_services.sh
```

**Expected Results**:
- PostgreSQL should be running and accessible
- Web service should respond to HTTP requests
- All endpoints should return correct status codes
- Report generation should work (if API keys provided)

### 3. Docker Validation (`scripts/validate_docker.sh`)

**Purpose**: Tests Docker-related functionality when Docker daemon is available.

**What it tests**:
- Docker file validation
- Multi-stage build process
- Docker Compose configuration
- Image inspection
- Container startup tests
- Makefile Docker targets

**Usage**:
```bash
./scripts/validate_docker.sh
```

**Note**: This script will gracefully exit in environments without Docker (like GitHub Codespaces).

---

## 🚀 Testing Procedures

### For Fresh GitHub Codespace

1. **Create new Codespace** from the repository
2. **Wait for automatic setup** (devcontainer build + postCreateCommand)
3. **Run environment validation**:
   ```bash
   ./scripts/validate_environment.sh
   ```
4. **Start services if needed**:
   ```bash
   make start
   ```
5. **Run integration tests**:
   ```bash
   ./scripts/test_services.sh
   ```

**Expected Timeline**:
- Codespace creation: 3-5 minutes
- Environment validation: 30 seconds
- Service tests: 1-2 minutes

### For Existing Environment

1. **Pull latest changes**:
   ```bash
   git pull origin main
   ```
2. **Update dependencies**:
   ```bash
   make sync
   ```
3. **Run all validations**:
   ```bash
   ./scripts/validate_environment.sh
   ./scripts/test_services.sh
   ```

### For Docker Testing (Local Machine)

1. **Ensure Docker is running**
2. **Run Docker validation**:
   ```bash
   ./scripts/validate_docker.sh
   ```
3. **Test Docker Compose**:
   ```bash
   make docker-dev    # Development environment
   make docker-prod   # Production environment
   ```

---

## 🎛️ Make Targets for Testing

The Makefile includes several targets useful for testing:

```bash
# Environment and dependency management
make bootstrap     # Initialize environment
make dependencies  # Install dependencies
make sync          # Sync with lock files

# Service management
make start         # Start all services
make restart       # Restart services
make status        # Check service status
make stop          # Stop services

# Code quality
make test          # Run test suite
make lint          # Run linting

# Docker operations
make docker-build  # Build all Docker images
make docker-dev    # Run development environment
make docker-prod   # Run production environment
make docker-clean  # Clean up Docker resources
```

---

## ✅ Success Criteria

### Environment Validation Success
- [ ] All system dependencies found
- [ ] Python virtual environment active (`/opt/venv/bin/python`)
- [ ] All project files present
- [ ] Makefile targets functional
- [ ] Services manageable

### Service Integration Success
- [ ] PostgreSQL running and accessible
- [ ] Web service responding on port 8000
- [ ] Health endpoint returns `{"status":"ok"}`
- [ ] Basic endpoints return correct status codes
- [ ] Report generation works (with API keys)

### Docker Validation Success
- [ ] Both development and production images build successfully
- [ ] Docker Compose configurations are valid
- [ ] Containers start without errors
- [ ] Applications import successfully in containers
- [ ] Requirements are properly generated from .in files during build

---

## 🐛 Troubleshooting

### Common Issues

**1. Virtual Environment Path Issues**
```bash
# Check current Python path
which python
# Should return: /opt/venv/bin/python

# If incorrect, check if virtual environment is activated
echo $VIRTUAL_ENV
# Should contain: /opt/venv
```

**2. Service Connection Issues**
```bash
# Check service status
make status

# Start services if not running
make start

# Check if ports are open
netstat -tlnp | grep :8000
netstat -tlnp | grep :5432
```

**3. Docker Build Issues**
```bash
# Check Docker daemon
docker version

# Clean up Docker resources
make docker-clean

# Rebuild from scratch
make docker-build
```

### Getting Help

1. **Run validation scripts** to identify specific issues
2. **Check service logs**:
   ```bash
   tail -f /tmp/fastapi.log  # If running in background
   journalctl -u postgresql  # PostgreSQL logs
   ```
3. **Review environment variables**:
   ```bash
   env | grep -E "(DATABASE_URL|OPENAI|TAVILY)"
   ```

---

## 📊 Test Coverage

The validation scripts cover:

- **✅ System Dependencies**: Python, PostgreSQL, Git, Make
- **✅ Python Environment**: Virtual environment, package installation
- **✅ Project Configuration**: Files, environment variables, Makefile
- **✅ Service Integration**: Database, web service, API endpoints
- **✅ Docker Support**: Multi-stage builds, compose configurations
- **✅ Error Handling**: Invalid endpoints, missing dependencies

This comprehensive testing ensures the environment works correctly across all supported deployment methods.
