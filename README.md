# agentic-ai

This codebase is a version of [Agentic AI Public](https://github.com/https-deeplearning-ai/agentic-ai-public/tree/main) from deeplearning.ai refactored to follow the dev pattern in the [reproducible-dev-environments](https://github.com/iandonaldson/reproducible-dev-environments)
project.  This project is intended to facilitate reproducible dev environment via **devcontainer + venv + pip-tools**. Designed for **GitHub Codespaces** and portable to other clouds.




## Quickstart (Codespaces)

1. Open in Codespaces; the devcontainer builds automatically.
2. Dependencies are compiled & installed via `make bootstrap` (triggered by `postCreateCommand`).
3. Run tests: `make test`
4. Lint & type-check: `make lint`
5. Start API: `make run` then open <http://localhost:8000/healthz>

## Dependency Workflow

- Add a dependency to `requirements.in` (or `requirements-dev.in`).
- Rebuild lock files: `make lock`
- Sync the environment: `make sync`
- Commit: `requirements.in`, `requirements-dev.in`, and then the lock files that get made by `make lock` (requirements.txt and requirements-dev.txt) once they have been validated.
- This makes a determinative build for the next person checking out your code and trying to reproduce your work.


---
