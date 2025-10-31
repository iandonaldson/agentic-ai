# Multi-stage Dockerfile supporting both development and production
FROM python:3.12-slim as base

# Common environment variables
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create virtual environment (for compatibility with devcontainer)
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install pip-tools for compiling requirements
RUN pip install pip-tools

# Copy source requirement files, preserving directory structure
COPY .devcontainer/ .devcontainer/
COPY Makefile pyproject.toml ./

# Use Makefile to handle dependency compilation and base installation
RUN make dependencies-docker

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Default command for production
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

# ============================================================================
# Development stage: Include PostgreSQL and dev dependencies
FROM base AS development

# Install PostgreSQL (use unversioned packages available in Debian repos)
RUN apt-get update && apt-get install -y \
    postgresql \
    postgresql-contrib \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Development dependencies and workspace setup will be handled by postCreateCommand
# This keeps the development image lean and lets the workspace handle editable installs

# Copy entrypoint and setup scripts
COPY .devcontainer/entrypoint.sh /entrypoint.sh
COPY .devcontainer/setup-db.sh /setup-db.sh
RUN chmod +x /entrypoint.sh /setup-db.sh

# Expose PostgreSQL port as well
EXPOSE 5432

# For devcontainer: Let postCreateCommand handle database setup
# For standalone Docker: Use entrypoint to start services
# CMD is overridable, ENTRYPOINT is not, so use CMD for flexibility
CMD ["/entrypoint.sh"]

# ============================================================================
# Production stage (minimal runtime, assumes external database)
# ============================================================================
FROM base as production

# Create non-root user for security
RUN useradd --create-home --shell /bin/bash app && \
    chown -R app:app /app
USER app

# Production command with more workers
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
