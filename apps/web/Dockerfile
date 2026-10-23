# syntax=docker/dockerfile:1.7
#
# Lean production image for the Beacon Check-In web app.
# Build context: repository root
#   docker build -f apps/web/Dockerfile \
#     --build-arg VITE_API_BASE_URL=https://beacon-check-in-api.playground.my.id/api/v1 \
#     -t beacon-check-in-web .

FROM node:24-alpine AS builder

RUN corepack enable && corepack prepare pnpm@11.23.0 --activate
WORKDIR /repo

ARG VITE_API_BASE_URL=https://beacon-check-in-api.playground.my.id/api/v1
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}
ENV CI=true

# Install only the workspace metadata first for a cacheable dependency layer.
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY apps/web/package.json apps/web/package.json
COPY packages/shared-ui/package.json packages/shared-ui/package.json
RUN pnpm install --frozen-lockfile --ignore-scripts

COPY apps/web apps/web
COPY packages/shared-ui packages/shared-ui

RUN pnpm --filter web build

FROM nginx:1.27-alpine

COPY infra/deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /repo/apps/web/build/client /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz >/dev/null || exit 1
