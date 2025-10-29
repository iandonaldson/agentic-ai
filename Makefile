SHELL := /bin/bash
VENV_BIN := /opt/venv/bin
PY := $(VENV_BIN)/python
PIP := $(VENV_BIN)/pip
PIP_COMPILE := $(VENV_BIN)/pip-compile
PIP_SYNC := $(VENV_BIN)/pip-sync

bootstrap:
	$(PIP_COMPILE) ./.devcontainer/requirements.in -o requirements.txt
	$(PIP_COMPILE) ./.devcontainer/requirements-dev.in -o requirements-dev.txt
	$(PIP) install -r requirements.txt -r requirements-dev.txt
	pre-commit install

lock:
	$(PIP_COMPILE) ./.devcontainer/requirements.in      -o requirements.txt
	$(PIP_COMPILE) ./.devcontainer/requirements-dev.in  -o requirements-dev.txt

sync:
	$(PIP_SYNC) requirements.txt requirements-dev.txt

test:
	pytest

lint:
	ruff check .
	mypy --ignore-missing-imports .

run:
	$(PY) -m uvicorn src.your_project.app:app --host 0.0.0.0 --port 8000

update:
	$(PIP) list --outdated
