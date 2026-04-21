# ── Build stage ─────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

RUN python -m venv /venv

COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir --upgrade pip \
 && /venv/bin/pip install --no-cache-dir -r requirements.txt


# ── Final stage ─────────────────────
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN addgroup --system app \
 && adduser  --system --ingroup app --no-create-home --shell /sbin/nologin app

WORKDIR /app

COPY --from=builder --chown=app:app /venv /venv

COPY --chown=app:app main.py .

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD /venv/bin/python -c \
      "import urllib.request; urllib.request.urlopen('http://localhost:8000/openapi.json')" \
      || exit 1

CMD ["/venv/bin/uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
