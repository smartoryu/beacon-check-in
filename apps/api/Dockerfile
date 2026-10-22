# syntax=docker/dockerfile:1.7
#
# Lean production image for the Beacon Check-In API.
# Build context: apps/api
#   docker build -f apps/api/Dockerfile -t beacon-check-in-api apps/api
#
# No secrets are baked into build args or layers. All configuration is read
# from the runtime environment.

ARG GO_VERSION=1.26

FROM golang:${GO_VERSION}-trixie AS builder

WORKDIR /src

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

RUN go install github.com/swaggo/swag/cmd/swag@v1.16.6

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .

# docs/embed.go requires generated swagger files at compile time.
RUN swag init -o docs -d cmd,internal,modules --parseDependency

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build \
      -tags prod \
      -trimpath \
      -buildvcs=false \
      -ldflags="-s -w" \
      -o /out/api ./cmd

FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /out/api /srv/api

ENV APP_MODE=production \
    SERVER_HOST=0.0.0.0 \
    SERVER_PORT=8080

WORKDIR /srv
USER nonroot:nonroot
EXPOSE 8080

ENTRYPOINT ["/srv/api"]
CMD ["serve"]
