# agentic-ai

This codebase is a refactored version of [Agentic AI Public](https://github.com/https-deeplearning-ai/agentic-ai-public/tree/main) from deeplearning.ai refactored to follow the dev pattern in the [reproducible-dev-environments](https://github.com/iandonaldson/reproducible-dev-environments)
project.  This project is intended to facilitate reproducible dev environment via **devcontainer + venv + pip-tools**. Project metadata is handled by **pyproject.toml**.  Designed for **GitHub Codespaces** and portable to other clouds.

Original authors of the Agentic AI Public project are:
* [Elías D. Niño-Ruiz](https://github.com/enino84)
* [Andres Zartab](https://github.com/andres-zartab)
* [Tommy Nelson](https://github.com/madeinglasgow)
* [Ryan](https://github.com/ryanchentw)

## Quickstart (Codespaces)

1. **Open in Codespaces** - the devcontainer builds automatically.
2. **Bootstrap environment** - dependencies are compiled & installed via `make bootstrap` (triggered by `postCreateCommand`).
3. **Set up API keys** - copy `.env_example` to `.env` and add your OpenAI and Tavily API keys.
4. **Start services** - `make start` (starts PostgreSQL + FastAPI with auto-reload)
5. **Access the app** - open the forwarded port URL (e.g., https://your-codespace-8000.app.github.dev/)
6. **Run tests** - `make test`
7. **Check code quality** - `make lint`

### Essential Service Management Commands

```bash
make help          # Show all available commands with service management overview
make start         # Start web service with database (one-command startup)
make restart       # Restart web service (quick restart for development)
make restart-all   # Stop and restart everything including database
make stop          # Stop web service only
make stop-all      # Stop web service and database
make status        # Check service status
```

## Dependency Workflow During Development

If you use this repository for continued development, you may wish to add additional dependencies.
A number of Makefile targets have been added to facilitate this process.

- **Add a dependency** to `.devcontainer/requirements.in` (or `.devcontainer/requirements-dev.in`).
- **Rebuild lock files**: `make lock`
- **Sync the environment**: `make sync`
- **Restart services**: `make restart` (to pick up new dependencies)
- **Test your changes**: `make test` and `make lint`
- **Commit**: `requirements.in`, `requirements-dev.in`, and the generated lock files (`requirements.txt`, `requirements-dev.txt`) once validated.

This ensures a deterministic build for anyone checking out your code.

### Available Make Commands

```bash
make help          # Show all available commands with service overview
make bootstrap     # Initialize development environment
make dependencies  # Install and compile dependencies
make lock          # Update dependency lock files
make sync          # Sync environment with lock files
make test          # Run test suite
make lint          # Run code linting
make start         # Start web service with database (one-command startup)
make restart       # Restart web service (quick restart for development)
make restart-all   # Stop and restart everything including database
make stop          # Stop web service only
make stop-all      # Stop web service and database
make status        # Check service status
make update        # Show outdated packages
```


---
# Reflective Research Agent (FastAPI + Postgres, single container)

A FastAPI web app that plans a research workflow, runs tool-using agents (Tavily, arXiv, Wikipedia), and stores task state/results in Postgres.
This repo includes a Docker setup that runs **Postgres + the API in one container** (for local/dev).

## Features

* `/` serves a simple UI (Jinja2 template) to kick off a research task.
* `/generate_report` kicks off a threaded, multi-step agent workflow (planner → research/writer/editor).
* `/task_progress/{task_id}` live status for each step/substep.
* `/task_status/{task_id}` final status + report.
* `/healthz` and `/api` health check endpoints for monitoring.
* `/add` simple addition endpoint for testing.

---

## Project layout (key paths)

```
├─ main.py                      # FastAPI app with database, agents coordination, and API endpoints
├─ src/
│  ├─ planning_agent.py         # planner_agent(), executor_agent_step() - orchestrates workflow
│  ├─ agents.py                 # research_agent, writer_agent, editor_agent - AI agents
│  └─ research_tools.py         # tavily_search_tool, arxiv_search_tool, wikipedia_search_tool
├─ templates/
│  └─ index.html                # Main UI page rendered by "/"
├─ static/                      # Static assets (logos and images)
│  ├─ arxiv_logo.png
│  ├─ dl_logo.png
│  ├─ how_interactions_are_performed.png
│  ├─ tavily_logo.svg
│  └─ wikipedia_logo.png
├─ .devcontainer/
│  ├─ Dockerfile               # Development container setup
│  ├─ requirements-dev.in      # Editable requirements for development - see Makefile
│  ├─ requirements.in          # Editable requirements for production  - see Makefile
│  └─ entrypoint.sh            # Container initialization script
├─ tests/
│  ├─ test_app.py              # FastAPI endpoint tests
│  └─ test_planning_agent.py   # Planning agent tests
├─ requirements.txt            # Production dependencies - autogenerated by Makefile and requirements.in
├─ requirements-dev.txt        # Development dependencies - autogenerated by Makefile and requirements-dev.in
├─ pyproject.toml              # Project configuration
├─ Makefile                    # Build and development commands
├─ .pre-commit-config.yaml     # Code quality hooks
└─ README.md                   # Project documentation
```

> Make sure `templates/index.html` and (optionally) `static/` exist and are copied into the image.

---

## Container setup process in more detail

* This repo reconfigures the original to be compatible with GitHub Codespaces.
* The setup is defined by .devcontainer/devcontainer.json which in turn . . .
* Builds a container based on .devcontainer/Dockerfile
* Sets up a virtual environment in which to build dependencies
* Calls a postCreateCommand: "make bootstrap" based on the Makefile which in turn . . .
* Compiles requirements based on .devcontainer/requirements[-dev].in and
* Writes requirements.txt and requirements-dev.txt and
* Installs requirements in the virtual environment and
* Runs the .devcontainer/entrypoint.sh script which in turn . . .
* Sets up the PostgresSQL database and FastAPI on ports 5432 and 8000 respectively.

## Prerequisites

* API keys stored in a `.env` file:

  ```
  OPENAI_API_KEY=your-open-api-key
  TAVILY_API_KEY=your-tavily-api-key
  ```
> Copy the .env_example file to .env in your dev environment and add real keys.

* Python deps are installed by Docker from `requirements.txt`:

  * `fastapi`, `uvicorn`, `sqlalchemy`, `python-dotenv`, `jinja2`, `requests`, `wikipedia`, etc.
  * Plus any libs used by your `aisuite` client.

---

## Environment variables

The app **reads only `DATABASE_URL`** at startup.

* The container’s entrypoint sets a sane default for local dev:

  ```
  postgresql://app:local@127.0.0.1:5432/appdb
  ```
* To use Tavily:

  * Provide `TAVILY_API_KEY` (via `.env` or `-e`).

Optional (if you want to override defaults done by the entrypoint):

* `POSTGRES_USER` (default `app`)
* `POSTGRES_PASSWORD` (default `local`)
* `POSTGRES_DB` (default `appdb`)

---

## Build & Run

### Option 1: Using Makefile (Recommended for Development)

After setting up your `.env` file with API keys:

```bash
# Start services (PostgreSQL + FastAPI with auto-reload)
make start

# Check status
make status

# Restart during development
make restart

# View all available commands
make help
```

The web interface will be available at the forwarded port (in Codespaces) or http://localhost:8000

### Option 2: Docker (Local/Production)

#### 1) Build

```bash
docker build -t fastapi-postgres-service .
```

#### 2) Run (foreground)

```bash
docker run --rm -it  -p 8000:8000  -p 5432:5432  --name fpsvc  --env-file .env  fastapi-postgres-service
```

You should see logs like:

```
🚀 Starting Postgres cluster 17/main...
✅ Postgres is ready
CREATE ROLE
CREATE DATABASE
🔗 DATABASE_URL=postgresql://app:local@127.0.0.1:5432/appdb
INFO:     Uvicorn running on http://0.0.0.0:8000
```

#### 3) Open the app

* UI: [http://localhost:8000/](http://localhost:8000/)
* Docs: [http://localhost:8000/docs](http://localhost:8000/docs)

---

## API quickstart

### Kick off a run

```bash
curl -X POST http://localhost:8000/generate_report \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Large Language Models for scientific discovery", "model":"openai:gpt-4o"}'
# -> {"task_id": "UUID..."}
```

### Poll progress

```bash
curl http://localhost:8000/task_progress/<TASK_ID>
```

### Final status + report

```bash
curl http://localhost:8000/task_status/<TASK_ID>
```

---

## Troubleshooting

**I open [http://localhost:8000](http://localhost:8000) and see nothing / errors**

* Confirm `templates/index.html` exists inside the container:

  ```bash
  docker exec -it fpsvc bash -lc "ls -l /app/templates && ls -l /app/static || true"
  ```
* Watch logs while you load the page:

  ```bash
  docker logs -f fpsvc
  ```

**Container asks for a Postgres password on startup**

* The entrypoint uses **UNIX socket + peer auth** for admin tasks (no password).
  Ensure you’re not calling `psql -h 127.0.0.1 -U postgres` in the script—use:

  ```bash
  su -s /bin/bash postgres -c "psql -c '...'"
  ```

**`DATABASE_URL not set` error**

* The entrypoint exports a default DSN. If you overrode it, ensure it’s valid:

  ```
  postgresql://<user>:<password>@<host>:<port>/<database>
  ```

**Tables disappear on restart**

* In your `main.py` you call `Base.metadata.drop_all(...)` on startup.
  Comment it out or guard with an env flag:

  ```python
  if os.getenv("RESET_DB_ON_STARTUP") == "1":
      Base.metadata.drop_all(bind=engine)
  ```

**Tavily / arXiv / Wikipedia errors**

* Provide `TAVILY_API_KEY` and ensure network access, provide in the root dir and `.env` file as follows:
```
# OpenAI API Key
OPENAI_API_KEY=your-open-api-key
TAVILY_API_KEY=your-tavily-api-key
```

* Wikipedia rate limits sometimes; try later or handle exceptions gracefully.

---

## Development tips

### Using the Makefile (Recommended)

* **One-command startup**: `make start`
* **Quick restart during development**: `make restart`
* **Full restart (including database)**: `make restart-all`
* **Check what's running**: `make status`
* **Clean shutdown**: `make stop` (web service only) or `make stop-all` (everything)
* **View all commands**: `make help`

### Manual Docker Development

* **Hot reload** (optional): For dev, you can run Uvicorn with `--reload` if you mount your code:

  ```bash
  docker run --rm -it -p 8000:8000 -p 5432:5432 \
    -v "$PWD":/app \
    --name fpsvc fastapi-postgres-service \
    bash -lc "pg_ctlcluster \$(psql -V | awk '{print \$3}' | cut -d. -f1) main start && uvicorn main:app --host 0.0.0.0 --port 8000 --reload"
  ```

* **Connect to DB from host:**

  ```bash
  psql "postgresql://app:local@localhost:5432/appdb"
  ```

---
