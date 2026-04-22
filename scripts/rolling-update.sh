#!/usr/bin/env bash
# Runs on the deploy target via SSH.

set -euo pipefail

: "${IMAGE}"
: "${SERVICE}"
: "${SHA}"

HEALTH_TIMEOUT=60
SHORT_SHA="${SHA:0:7}"
OLD_CONTAINER="${SERVICE}"
NEW_CONTAINER="${SERVICE}_${SHORT_SHA}"
DOCKER_NETWORK="app_network"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# Load runtime env vars from the deploy host's .env file
ENV_FILE="${ENV_FILE:-/opt/app/.env}"
if [ -f "${ENV_FILE}" ]; then
  # export only KEY=VALUE lines, skip comments and blanks
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
  log "Loaded env from ${ENV_FILE}"
else
  log "WARNING: ${ENV_FILE} not found — services may lack required env vars"
fi

log "Pulling ${IMAGE} ..."
docker pull "${IMAGE}"

case "${SERVICE}" in
  api)
    RUN_FLAGS="-p ${API_PORT:-8000}:8000
      -e REDIS_HOST=${REDIS_HOST:-redis}
      -e REDIS_PORT=${REDIS_PORT:-6379}
      -e REDIS_PASSWORD=${REDIS_PASSWORD}
      -e API_HOST=0.0.0.0
      -e API_PORT=${API_PORT:-8000}
      -e PYTHONDONTWRITEBYTECODE=1
      -e PYTHONUNBUFFERED=1
      --network ${DOCKER_NETWORK}"
    ;;
  worker)
    RUN_FLAGS="-e REDIS_HOST=${REDIS_HOST:-redis}
      -e REDIS_PORT=${REDIS_PORT:-6379}
      -e REDIS_PASSWORD=${REDIS_PASSWORD}
      -e PYTHONDONTWRITEBYTECODE=1
      -e PYTHONUNBUFFERED=1
      --network ${DOCKER_NETWORK}"
    ;;
  frontend)
    RUN_FLAGS="-p ${FRONTEND_PORT:-3000}:3000
      -e API_URL=${API_URL:-http://api:8000}
      -e NODE_ENV=${NODE_ENV:-production}
      --network ${DOCKER_NETWORK}"
    ;;
  *)
    log "ERROR: unknown service '${SERVICE}'" >&2
    exit 1
    ;;
esac

log "Starting new container '${NEW_CONTAINER}' ..."
# shellcheck disable=SC2086
docker run -d --name "${NEW_CONTAINER}" --restart unless-stopped ${RUN_FLAGS} "${IMAGE}"

log "Waiting up to ${HEALTH_TIMEOUT}s for health check ..."
ELAPSED=0
HEALTHY=false

while [ "${ELAPSED}" -lt "${HEALTH_TIMEOUT}" ]; do
  HEALTH=$(docker inspect \
    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
    "${NEW_CONTAINER}" 2>/dev/null || echo "inspect-error")

  log "  health=${HEALTH} (${ELAPSED}s elapsed)"

  case "${HEALTH}" in
    healthy)
      HEALTHY=true
      break
      ;;
    unhealthy)
      log "Container entered 'unhealthy' state — aborting."
      break
      ;;
    inspect-error)
      log "Could not inspect container — aborting."
      break
      ;;
  esac

  sleep 2
  ELAPSED=$(( ELAPSED + 2 ))
done

if [ "${HEALTHY}" = "true" ]; then
  log "Health check passed. Replacing '${OLD_CONTAINER}' ..."
  docker stop  "${OLD_CONTAINER}" 2>/dev/null || true
  docker rm    "${OLD_CONTAINER}" 2>/dev/null || true
  docker rename "${NEW_CONTAINER}" "${OLD_CONTAINER}"
  log "Deploy complete: ${SERVICE} is now running ${IMAGE}"
else
  log "Health check failed within ${HEALTH_TIMEOUT}s." >&2
  log "Stopping new container; leaving '${OLD_CONTAINER}' running." >&2
  docker stop "${NEW_CONTAINER}" 2>/dev/null || true
  docker rm   "${NEW_CONTAINER}" 2>/dev/null || true
  exit 1
fi
