# Caddy with the Cloudflare DNS-01 challenge module.
# Built in GitHub Actions and published to GHCR.
#
#   docker build -t beacon-check-in-caddy infra/deploy/caddy

FROM caddy:2-builder AS builder

RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
