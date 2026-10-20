# BLS Vanguard — production image
# Multi-stage: build once, ship only what runs.
FROM node:22-alpine AS deps
WORKDIR /app
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
RUN npm ci

FROM node:22-alpine AS builder
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
# DATABASE_URL is only needed at runtime; a placeholder keeps the build happy.
ENV DATABASE_URL=postgresql://placeholder:placeholder@127.0.0.1:5432/placeholder
RUN npm run build

FROM node:22-alpine AS runner
WORKDIR /app
RUN apk add --no-cache libc6-compat curl
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/next.config.ts ./next.config.ts
COPY --from=builder /app/src/db ./src/db
COPY --from=builder /app/drizzle.config.ts ./drizzle.config.ts
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD curl -fsS http://127.0.0.1:3000/api/health || exit 1
CMD ["npm", "start"]
