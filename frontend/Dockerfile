# ── Stage 1: dependencies ──────────────
FROM node:20-alpine AS deps

WORKDIR /build

COPY package.json package-lock.json ./

RUN npm ci --omit=dev --ignore-scripts


# ── Stage 2: final ─────────────────────
FROM node:20-alpine

RUN addgroup -S app && adduser -S -G app -H -s /sbin/nologin app

WORKDIR /app

COPY --from=deps  --chown=app:app /build/node_modules ./node_modules

COPY --chown=app:app app.js package.json ./
COPY --chown=app:app views ./views

USER app

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/ > /dev/null || exit 1

CMD ["node", "app.js"]
