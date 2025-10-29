FROM python:3.12-slim

# System libs commonly needed by DS/LLM projects
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl ca-certificates \
    libssl-dev libffi-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

# (Optional) git-lfs (large-file support) for models/datasets - keep Dockerimage small until needed
# RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
#    apt-get update && apt-get install -y git-lfs && git lfs install && \
#    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
    
# Create an isolated venv inside the container
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip + install build tooling + pip-tools
# note the explicit path to the venv
RUN /opt/venv/bin/pip install --upgrade pip wheel setuptools pip-tools

# Compile lock files and install will be run by Makefile (make bootstrap)
# as part of the postCreateCommand.  
# This Dockerfile is only used to construct the base image during development.
# Additional dependencies can be added during development using 
# requirements.in.txt, requirements-dev.in.txt (this directory) and then
# make lock && make sync.
# For production, construct a new Dockerfile based of the final configuration.

