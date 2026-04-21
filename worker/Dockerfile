# ── Stage 1: build ─────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

RUN python -m venv /venv

COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir --upgrade pip \
 && /venv/bin/pip install --no-cache-dir -r requirements.txt

# ── Stage 2: final ─────────────────────
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN addgroup --system app \
 && adduser  --system --ingroup app --no-create-home --shell /sbin/nologin app

WORKDIR /app

COPY --from=builder --chown=app:app /venv /venv
COPY --chown=app:app worker.py .

USER app

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD /venv/bin/python -c "\
import redis, os; \
redis.Redis( \
  host=os.getenv('REDIS_HOST', 'localhost'), \
  port=int(os.getenv('REDIS_PORT', 6379)), \
  password=os.getenv('REDIS_PASSWORD') \
).ping()" \
  || exit 1

CMD ["/venv/bin/python", "worker.py"]
