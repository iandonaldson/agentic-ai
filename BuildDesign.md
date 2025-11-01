# Build Design: Dual Environment Support

This document explains how the repository architecture supports both **Codespaces (devcontainer)** and **standalone Docker** setups, while maintaining a single source of truth for dependencies and build logic.

## Design Overview

The build system is designed around a **multi-stage Dockerfile** with environment-specific orchestration through **Makefile targets** and **devcontainer configuration**. This approach eliminates dependency duplication while supporting different runtime environments.

```
┌─────────────────────────────────────────────────────────────────┐
│                     Build Architecture                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │   Codespaces    │    │ Standalone      │                    │
│  │  (devcontainer) │    │    Docker       │                    │
│  └─────────────────┘    └─────────────────┘                    │
│           │                       │                            │
│           └───────────────────────┼─────────────────────────┐  │
│                                   │                         │  │
│               ┌───────────────────▼──────────────────────┐  │  │
│               │        Dockerfile (multi-stage)         │  │  │
│               │  ┌─────────────────────────────────────┐ │  │  │
│               │  │        base stage                   │ │  │  │
│               │  │  - Python 3.12 + system deps      │ │  │  │
│               │  │  - /opt/venv virtual environment   │ │  │  │
│               │  │  - make dependencies-docker        │ │  │  │
│               │  │  - Base requirements compilation   │ │  │  │
│               │  └─────────────────────────────────────┘ │  │  │
│               │  ┌─────────────────────────────────────┐ │  │  │
│               │  │     development stage              │ │◄─┘  │
│               │  │  - Inherits from base               │ │     │
│               │  │  - PostgreSQL server + client      │ │     │
│               │  │  - Development scripts             │ │     │
│               │  │  - CMD ["/entrypoint.sh"]          │ │     │
│               │  └─────────────────────────────────────┘ │     │
│               │  ┌─────────────────────────────────────┐ │     │
│               │  │      production stage              │ │◄────┘
│               │  │  - Inherits from base               │ │
│               │  │  - Non-root user                    │ │
│               │  │  - Multi-worker uvicorn CMD        │ │
│               │  └─────────────────────────────────────┘ │
│               └─────────────────────────────────────────┘ │
│                                   │                       │
│               ┌───────────────────▼──────────────────────┐ │
│               │         Makefile (orchestration)        │ │
│               │  - dependencies-docker (build-time)     │ │
│               │  - bootstrap-codespace (runtime)        │ │
│               │  - Service management targets           │ │
│               └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Environment Differences

### Codespaces (Devcontainer) Environment

**Build Process:**
1. `devcontainer.json` builds from `Dockerfile` with `target: development`
2. Docker build runs `make dependencies-docker` (compiles and installs base requirements)
3. Container starts but **devcontainer overrides the CMD**
4. `postCreateCommand: make bootstrap-codespace` runs in the workspace

**Runtime Characteristics:**
- **CMD Override**: Devcontainer doesn't execute `/entrypoint.sh` automatically; instead it keeps the container alive and runs `postCreateCommand`
- **Workspace Mount**: Source code is mounted as a volume, so editable installs work
- **Development Focus**: Installs dev dependencies, pre-commit hooks, editable package install
- **Database Setup**: Uses `setup-db.sh` (not `entrypoint.sh`) to avoid server startup conflicts

**Key Files:**
- `.devcontainer/devcontainer.json` - Controls build and post-creation
- `.devcontainer/setup-db.sh` - DB setup without starting the server
- Makefile target: `bootstrap-codespace`

### Standalone Docker Environment

**Build Process:**
1. Docker build creates base stage with compiled requirements
2. Development or production stage adds environment-specific layers
3. Container runs with the stage's default CMD

**Runtime Characteristics:**
- **CMD Execution**: Container executes the specified CMD (`/entrypoint.sh` for dev, uvicorn for prod)
- **Self-Contained**: No workspace mounting; application code is built into the image
- **Production Ready**: Can run with external databases and proper scaling
- **Immediate Startup**: Services start automatically when container runs

**Key Files:**
- `docker-compose.yml` - Multi-service orchestration
- `.devcontainer/entrypoint.sh` - Starts PostgreSQL + FastAPI for dev containers
- Makefile targets: `docker-build`, `docker-dev`, `docker-prod`

## File Placement Rationale

### Root Directory Files

```
Dockerfile              # Multi-stage build definition (shared by both environments)
Makefile               # Build orchestration and service management
docker-compose.yml     # Standalone Docker multi-service setup
.dockerignore          # Build context filtering
pyproject.toml         # Python project metadata
requirements*.txt      # Generated dependency locks (gitignored in dev, needed for Docker)
```

**Why at root:**
- `Dockerfile` needs access to entire project context for COPY operations
- `Makefile` provides consistent interface across environments
- `docker-compose.yml` orchestrates multiple services for production deployments
- Build artifacts like `requirements.txt` are generated during Docker build

### .devcontainer/ Directory

```
.devcontainer/
├── devcontainer.json     # Devcontainer build configuration
├── requirements.in       # Source dependencies (production)
├── requirements-dev.in   # Source dependencies (development)
├── entrypoint.sh        # Full service startup (PostgreSQL + FastAPI)
└── setup-db.sh          # Database-only setup (no server start)
```

**Why in .devcontainer:**
- **Devcontainer Standard**: VS Code expects configuration in this location
- **Source of Truth**: `.in` files are the authoritative dependency specifications
- **Build Context**: Scripts need to be accessible during Docker build via `COPY .devcontainer/`
- **Environment Separation**: Keeps devcontainer-specific files organized

### src/ Directory

```
src/
├── __init__.py
├── agents.py
├── planning_agent.py
└── research_tools.py
```

**Why in src:**
- **Python Package Structure**: Enables `pip install -e .` (editable installs)
- **Import Clarity**: Clean separation of application code from configuration
- **Testing**: Facilitates proper test structure and imports

## Dependency Management Strategy

### Single Source of Truth

The dependency system uses **pip-tools** with `.in` files as the source of truth:

```
.devcontainer/requirements.in     → requirements.txt     (production)
.devcontainer/requirements-dev.in → requirements-dev.txt (development)
```

### Build-Time vs Runtime

**Build-Time (Docker)**:
```bash
make dependencies-docker  # Compiles .in → .txt, installs base requirements
```

**Runtime (Devcontainer)**:
```bash
make bootstrap-codespace  # Installs dev deps, editable package, hooks
```

This separation ensures:
- Docker images contain only necessary production dependencies
- Devcontainer workspace gets full development environment
- No duplicate compilation between build and runtime

## CMD vs ENTRYPOINT Behavior

### Why CMD instead of ENTRYPOINT

The Dockerfile uses `CMD` rather than `ENTRYPOINT` for flexibility:

```dockerfile
# Development stage
CMD ["/entrypoint.sh"]

# Production stage
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

**Devcontainer Override:**
- Devcontainer can override `CMD` to keep container alive without running services
- `postCreateCommand` handles environment setup after workspace is mounted
- Allows debugging and development without automatic service startup

**Standalone Docker:**
- `CMD` executes normally when no override is provided
- Services start automatically for production deployment
- Can still be overridden for debugging: `docker run ... /bin/bash`

### Script Separation

**entrypoint.sh** - Full startup (PostgreSQL + FastAPI):
```bash
# Starts PostgreSQL cluster
# Creates database and user
# Starts FastAPI with uvicorn (blocking)
```

**setup-db.sh** - Database-only setup:
```bash
# Starts PostgreSQL cluster
# Creates database and user
# Exports DATABASE_URL
# Does NOT start FastAPI server
```

This separation allows:
- Devcontainer to prepare database without starting the server
- Standalone Docker to run full service stack
- Flexible development workflows

## Build Context Management

### .dockerignore Strategy

```
# Ignore most files
*

# Re-include what's needed for build
!/src/
!/templates/
!/static/
!/main.py
!/pyproject.toml
!/Makefile
!/.devcontainer/requirements*.in
!/.devcontainer/entrypoint.sh
!/.devcontainer/setup-db.sh
!/.devcontainer/devcontainer.json
!/.devcontainer/Dockerfile
```

**Benefits:**
- Minimal build context reduces build time and size
- Explicit inclusion prevents accidental inclusion of secrets or build artifacts
- Supports both devcontainer builds (need devcontainer files) and standalone builds

## Validation and Testing

The repository includes comprehensive validation scripts:

```
scripts/
├── validate_environment.sh  # Check development environment setup
├── validate_docker.sh       # Test Docker functionality
└── test_services.sh         # Integration testing
```

**Integration Points:**
- `make validate-all` runs environment and service tests
- `make validate-docker` tests Docker builds (when Docker is available)
- CI/CD can use these for automated validation

## Summary

This dual-environment design provides:

1. **Single Source of Truth**: Dependencies defined once in `.in` files
2. **Environment Flexibility**: Same codebase works in Codespaces and standalone Docker
3. **Optimized Builds**: No duplicate dependency compilation
4. **Development Experience**: Rich devcontainer with all tools, lean production containers
5. **Operational Simplicity**: Consistent Makefile interface across environments

The architecture balances development productivity with production requirements while maintaining clear separation of concerns between build-time and runtime operations.
