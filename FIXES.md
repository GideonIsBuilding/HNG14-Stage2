### 1. `api/main.py` 
Line 8: The localhost was hardcoded
The redis client was constructed with the host set as localhost. This will only work if the API and redis are on the same machine and may cause problems in a multi-container setup.
So I replaced the the hardcoded string with `host=os.getenv("REDIS_HOST", "localhost")` so that it is used via an env variable in docker compose.

### 2. `api/main.py`
Line 8: redis password was not considered
The password is defined in the `env` file but the Redis client was constructed with no `password` argument.
I added `password=os.getenv("REDIS_PASSWORD")` to the `redis.Redis(...)` call. When the env var is absent it evaluates to `None` and is treated as "no auth" so unauthenticated local Redis continues to work.

### 3. `api/main.py`
Line 8: hardcoded port as `6379`
This makes it impossible to override the port in environments if redis is exposed on the non-default port.
I added `port=int(os.getenv("REDIS_PORT", 6379))` alongside the host fix.

### 4. `worker/worker.py` 
Line 8: The localhost was hardcoded as in issue 1
The redis client was constructed with the host set as localhost. This will only work if the API and redis are on the same machine and may cause problems in a multi-container setup.
So I replaced the the hardcoded string with `host=os.getenv("REDIS_HOST", "localhost")` so that it is used via an env variable in docker compose.

### 5. `worker/worker.py`
Line 8: redis password was not considered as in issue 2
The password is defined in the `env` file but the Redis client was constructed with no `password` argument.
I added `password=os.getenv("REDIS_PASSWORD")` to the `redis.Redis(...)` call. When the env var is absent it evaluates to `None` and is treated as "no auth" so unauthenticated local Redis continues to work.

### 6. `worker/worker.py`
Line 8: hardcoded port as `6379` as in issue 3
This makes it impossible to override the port in environments if redis is exposed on the non-default port.
I added `port=int(os.getenv("REDIS_PORT", 6379))` alongside the host fix.

### 7. `worker/worker.py`
Line 4: signal is imported but not used
`import signal` appears at the top of the file but the module was never referenced in the code. This means that graceful shutdown was intended but never implemented. In a container environment this is a real operational bug: Docker sends `SIGTERM` to a container when you run `docker stop` or a scheduler drains a node. With no signal handler the worker's `while True` loop ignores `SIGTERM`, Docker waits for the grace period of 10 s, then sends `SIGKILL`. Any job being processed at that moment is aborted mid-flight and its status is never written back to Redis, leaving it permanently stuck in `"queued"`.
I:
- Added `running = True` flag.
- Registered a `handle_shutdown` function for both `SIGTERM` and `SIGINT` that sets `running = False`.
- Changed `while True:` to `while running:` so the loop exits cleanly after the current `brpop` timeout when a shutdown signal is received.

### 8. `frontend/app.js` 
Line 6: Hardcoded `localhost` API URL
`const API_URL = "http://localhost:8000"` is hardcoded. When the frontend runs in its own container, `localhost` refers to the frontend container, not the API container. Every call to `/submit` and `/status/:id` that proxies through to `axios.post/get(API_URL + ...)` gets a `ECONNREFUSED` and the frontend always returns `500 { error: "something went wrong" }`.
I changed that to `const API_URL = process.env.API_URL || "http://localhost:8000"`. The `|| "http://localhost:8000"` fallback preserves existing local-dev behavior; in containers you set `API_URL=http://api:8000` (or whatever the service name is).

### 9. `frontend/views/index.html`
Line 26: No error handling after `POST /submit`
The `submitJob` function renders `data.job_id` unconditionally. If the API returns `{ "error": "something went wrong" }` when Redis is down, `data.job_id` is `undefined`, the page displays `"Submitted: undefined"`, and `pollJob(undefined)` is called, which fires an infinite stream of `GET /status/undefined` requests.
I added an explicit check for `data.job_id`. If false, display the error message and return early without starting the poll loop.

### 10. `frontend/views/index.html` 
Line 35: Polling never stops on API error
`pollJob` renders `data.status` and reschedules itself whenever `data.status !== 'completed'`. If the API returns `{ "error": "not found" }`, `data.status` is `undefined`, which is never equal to `'completed'`, so the poll loop runs forever. This fills the browser with an unbounded number of scheduled callbacks and hammers the server indefinitely.
i added an early-return guard at the top of `pollJob` — if `data.error` is present, render the error in the job element and return without rescheduling.

### 11. `api/.env`
Credentials committed to version control
`api/.env` is tracked by git and contains a plaintext password (`REDIS_PASSWORD=supersecretpassword123`). Anyone with read access to the repository has the credential. This file should never be committed.
I:
1. Add `.env` to `.gitignore`.
2. Remove the file from git history (`git rm --cached api/.env`).
3. Rotate the Redis password immediately since it is already in the commit history.
4. Provide an `api/.env.example` with placeholder values to document which variables are required.