#!/usr/bin/env bash
# The job of this script is to submit a job through the frontend, poll until the worker
# marks it completed, and exit non-zero if it never does.
set -euo pipefail

FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}"
MAX_WAIT=30
INTERVAL=2

# Submit Job
echo "→ Submitting job to ${FRONTEND_URL}/submit ..."
RESPONSE=$(curl -sf -X POST "${FRONTEND_URL}/submit" \
           -H "Content-Type: application/json")

JOB_ID=$(printf '%s' "${RESPONSE}" \
         | python3 -c "import sys, json; print(json.load(sys.stdin)['job_id'])" \
         2>/dev/null || true)

if [ -z "${JOB_ID}" ]; then
  echo "FAIL: no job_id in response: ${RESPONSE}" >&2
  exit 1
fi

echo "   job_id = ${JOB_ID}"

# Poll for completion
echo "→ Polling ${FRONTEND_URL}/status/${JOB_ID} (timeout ${MAX_WAIT}s) ..."

ELAPSED=0
STATUS="unknown"

while [ "${ELAPSED}" -lt "${MAX_WAIT}" ]; do
  POLL=$(curl -sf "${FRONTEND_URL}/status/${JOB_ID}" || echo '{}')
  STATUS=$(printf '%s' "${POLL}" \
           | python3 -c "import sys,json; d=json.load(sys.stdin); \
                         print(d.get('status') or d.get('error','unknown'))" \
           2>/dev/null || echo "parse-error")

  echo "   [${ELAPSED}s] status=${STATUS}"

  if [ "${STATUS}" = "completed" ]; then
    echo ""
    echo "PASS: job ${JOB_ID} completed successfully."
    exit 0
  fi

  if [ "${STATUS}" = "not found" ] || [ "${STATUS}" = "parse-error" ]; then
    echo "FAIL: unexpected status '${STATUS}'" >&2
    exit 1
  fi

  sleep "${INTERVAL}"
  ELAPSED=$(( ELAPSED + INTERVAL ))
done

echo ""
echo "FAIL: job ${JOB_ID} did not reach 'completed' within ${MAX_WAIT}s." \
     "Last status: ${STATUS}" >&2
exit 1
