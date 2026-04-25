# Job Processor Task

This repository runs a four-service job-processing stack:

- `redis`: internal Redis queue and job status store
- `api`: FastAPI service that creates jobs and reads job status
- `worker`: Python worker that consumes jobs from Redis and marks them completed
- `frontend`: Express web app that serves the UI and proxies job requests to the API

The easiest way to run the full stack on a clean machine is Docker Compose.

## Prerequisites

Install these before starting:

- Git
- Docker Engine or Docker Desktop
- Docker Compose v2, available as `docker compose`
- `curl`
- Python 3, used by the integration test script to parse JSON

Check the required tools:

```bash
git --version
docker --version
docker compose version
curl --version
python3 --version
```

If your system only has the legacy `docker-compose` command, use `docker-compose` anywhere this README shows `docker compose`.

## Start From A Clean Machine

Clone the repository and enter it:

```bash
git clone <repository-url>
cd HNG14-Stage2
```

Create the root environment file:

```bash
cp .env.example .env
```

Review the values:

```bash
sed -n '1,120p' .env
```

For local Docker Compose, the defaults should look like this:

```env
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=supersecretpassword123
API_HOST=0.0.0.0
API_PORT=8000
API_URL=http://api:8000
FRONTEND_PORT=3000
NODE_ENV=production
```

For a real shared environment, change `REDIS_PASSWORD` before starting the stack.

Build and start every service:

```bash
docker compose up --build -d
```

Watch startup logs:

```bash
docker compose logs -f
```

Press `Ctrl+C` to stop following logs. The containers keep running in the background.

## Verify Startup

Check container state and health:

```bash
docker compose ps
```

A successful startup shows all four services running, with health checks passing:

```text
NAME                SERVICE    STATUS
redis_service       redis      Up ... (healthy)
api_service         api        Up ... (healthy)
worker_service      worker     Up ... (healthy)
frontend_service    frontend   Up ... (healthy)
```

The host should expose:

- Frontend: http://localhost:3000
- API OpenAPI document: http://localhost:8000/openapi.json

Verify those endpoints from the command line:

```bash
curl -fsS http://localhost:3000/
curl -fsS http://localhost:8000/openapi.json
```

Run the end-to-end job test:

```bash
chmod +x scripts/integration-test.sh
./scripts/integration-test.sh
```

A successful test submits a job through the frontend, polls for completion, and ends like this:

```text
-> Submitting job to http://localhost:3000/submit ...
   job_id = <uuid>
-> Polling http://localhost:3000/status/<uuid> (timeout 30s) ...
   [0s] status=queued
   [2s] status=completed

PASS: job <uuid> completed successfully.
```

You can also test the API directly:

```bash
curl -fsS -X POST http://localhost:8000/jobs
```

That should return JSON with a `job_id`:

```json
{"job_id":"<uuid>"}
```

## Common Commands

Start the stack:

```bash
docker compose up -d
```

Rebuild images after changing code or dependencies:

```bash
docker compose up --build -d
```

Show service status:

```bash
docker compose ps
```

Follow logs for all services:

```bash
docker compose logs -f
```

Follow logs for one service:

```bash
docker compose logs -f api
docker compose logs -f worker
docker compose logs -f frontend
docker compose logs -f redis
```

Restart one service:

```bash
docker compose restart worker
```

Stop and remove containers and the Compose network:

```bash
docker compose down
```

Stop and remove containers, the network, and any volumes:

```bash
docker compose down -v
```

## Expected Service Flow

The frontend posts to the API, the API writes a queued job into Redis, and the worker consumes that job from Redis:

```text
Browser or curl
  -> frontend:3000
  -> api:8000
  -> redis:6379
  -> worker
  -> redis status becomes completed
```

Redis is intentionally not published to the host. It is only reachable by other containers on the `app_network` Docker network.

## Troubleshooting

If containers are not healthy, inspect logs:

```bash
docker compose logs
docker compose logs api
docker compose logs worker
```

If ports `3000` or `8000` are already in use, edit `.env`:

```env
FRONTEND_PORT=3001
API_PORT=8001
```

Then recreate the stack:

```bash
docker compose up -d
```

If images are stale or dependency installation failed during an earlier build:

```bash
docker compose build --no-cache
docker compose up -d
```

If the integration test cannot connect to the frontend on a custom port, pass the URL explicitly:

```bash
FRONTEND_URL=http://localhost:3001 ./scripts/integration-test.sh
```
