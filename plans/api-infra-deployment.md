# Plan: API production deployment (GCP e2-micro + GHCR + Caddy + Cloudflare + Supabase)

## Context

The POC API currently runs locally with Docker Compose Postgres. This phase moves the **API only** to a
public server:

- GitHub repository + GitHub Actions CI/CD
- Container image published to GHCR
- GCP `e2-micro` VM provisioned with OpenTofu
- Caddy as the TLS reverse proxy
- Cloudflare DNS in front of `beacon-check-in-api.playground.my.id`
- Supabase-hosted PostgreSQL
- All secrets supplied through local `.env` / GitHub secrets / VM env files; nothing secret committed

The web app and mobile app are **not** deployed in this phase.

## Target topology

```
GitHub push (main)
  → Actions: test → build image → push ghcr.io/<owner>/beacon-check-in-api:<sha>
  → Actions: SSH deploy to GCP VM
      → docker compose pull
      → docker run --rm api migrate:up
      → docker run --rm api bootstrap:admin   (first deploy / idempotent)
      → docker compose up -d api caddy

Internet
  → Cloudflare DNS (beacon-check-in-api.playground.my.id)
  → Caddy :443 (TLS) → api:8080 (container)
  → Supabase PostgreSQL (pooler, TLS)
```

## Proposed repository additions

```
infra/
  opentofu/
    versions.tf
    providers.tf
    backend.tf                 # partial GCS backend (bucket passed via -backend-config)
    main.tf                    # VM, static IP, firewall, startup script
    variables.tf
    outputs.tf
    terraform.tfvars.example   # non-secret values only
  deploy/
    docker-compose.yml         # api + caddy on the VM
    Caddyfile                  # DNS-01 (recommended) or HTTP-01 variant
    caddy/Dockerfile           # Caddy + caddy-dns/cloudflare (if proxied)
    .env.example               # runtime env placeholders, committed
    bootstrap.sh               # optional VM bootstrap (Docker, dirs, firewall checks)
.github/workflows/
  api-ci.yml                   # test/lint/build on PR
  api-release.yml              # build+push GHCR on main
  api-deploy.yml               # SSH deploy + migrations + bootstrap
  infra-opentofu.yml           # fmt/validate/plan/apply for infra
apps/api/
  Dockerfile                   # replaced with a lean, standalone production build
  cmd/commands/bootstrap_admin.go
  database/migrations/00001_initialize_schema.sql  # portable uuidv7() function
  .env.example                 # add production-relevant placeholders
scripts/
  deploy-keygen.sh             # optional ed25519 deploy key generator (public key + instructions)
```

## Required production hardening before deploy

These are implementation tasks, not questions:

1. **Supabase UUID compatibility.**
   The current migrations use `DEFAULT uuidv7()`, which exists natively only in PostgreSQL 18. Supabase
   commonly runs PostgreSQL 15/17. Add a portable `public.uuidv7()` PL/pgSQL function in migration
   `00001` (before user tables) using `gen_random_bytes` + timestamp bytes, and keep the same call sites.
   Verify the migration chain against a non-PG18 instance (or a local PG15/17 container) before deploy.

2. **Lean production Dockerfile.**
   Replace the moon/node-heavy template Dockerfile with a two-stage Go build:
   - builder: `golang:1.26-bookworm`, install `swag`, run `swag init`, `go mod download`, `go build -tags prod`
   - runner: distroless/nonroot or alpine with CA certs, no build tooling, no env baked into layers
   - build context: `apps/api` only, so CI does not need the whole monorepo
   - include a `HEALTHCHECK` against `/healthz` if the runtime supports it

3. **Production super-admin bootstrap.**
   The dev seeder is not appropriate for production and is debug-build-only. Add a prod-available
   `bootstrap:admin` command that reads `SUPER_ADMIN_NAME`, `SUPER_ADMIN_EMAIL`,
   `SUPER_ADMIN_PASSWORD` and creates the super admin only if the email does not already exist.
   It must be idempotent and must never log the password.

4. **Supabase connection mode.**
   Use the Supavisor **session pooler** (`...pooler.supabase.com:5432`, `sslmode=require`) for a
   long-lived API, unless the user explicitly provides a direct connection. Avoid transaction-mode
   pooler unless prepared statements are disabled. Keep `PG_MAX_POOL_SIZE` conservative (≈10).

5. **Runtime env file.**
   `.env` on the VM, mode `600`, owned by the deploy user. Never committed. `.env.example` contains
   placeholders only. `SEED_DEMO_DATA` must not be set in production. Mailer can be disabled for the
   POC by setting an empty SMTP host/port; verify the config validation path.

6. **Caddy + Cloudflare.**
   Preferred: Cloudflare **proxied** DNS + Caddy with the Cloudflare DNS-01 challenge (custom Caddy
   build with `caddy-dns/cloudflare`). This keeps the origin IP hidden and gives a valid Let's Encrypt
   cert through the proxy. Fallback: DNS-only + Caddy HTTP-01. Also possible: Cloudflare Origin
   Certificate + Full (strict). Decision needed.

7. **OpenTofu state.**
   Use a GCS backend with a bucket provided by the operator. Partial backend config:
   `tofu init -backend-config="bucket=$TF_STATE_BUCKET" -backend-config="prefix=beacon-check-in/infra"`.
   State is never committed.

8. **Secrets hygiene.**
   - `.env`, `.env.*` (except examples), `*.tfstate`, `*.tfvars`, plan files, SSH keys, and GCP
     credentials are gitignored.
   - GitHub Actions masks secrets and writes the VM `.env` with `umask 077`.
   - No secret in Docker build args or image layers.
   - Rotate `JWT_SECRET_KEY` and Supabase password if they were ever pasted into a tracked file.

## Proposed steps (one task = one commit)

### 1. Plan + secret hygiene
- Add this plan.
- Extend `.gitignore` for `infra/opentofu/*.tfstate*`, `*.tfplan`, `*.tfvars` (except example),
  deploy env files, and SSH keys.
- Add `infra/deploy/.env.example` and `infra/opentofu/terraform.tfvars.example` with placeholders.
- Commit: `chore: add deployment plan and secret hygiene`.

### 2. API production build + bootstrap
- Add portable `uuidv7()` to migration 00001; verify local resets and Supabase-compatible PG.
- Replace `apps/api/Dockerfile` with the lean build.
- Add `bootstrap:admin` prod command.
- Add/adjust tests.
- Commit: `feat(api): add production image and admin bootstrap`.

### 3. OpenTofu infrastructure
- GCP provider: VM (`e2-micro`), static IP, firewall (22 restricted, 80/443), Ubuntu 24.04,
  30 GB pd-standard, startup script for Docker + swap + `/opt/beacon-check-in`.
- Cloudflare provider: A record for `beacon-check-in-api.playground.my.id`, proxy flag per decision.
- Outputs: static IP, instance name, SSH command.
- Commit: `feat(infra): provision API VM and Cloudflare DNS with OpenTofu`.

### 4. VM deployment assets
- `docker-compose.yml`: `api` image from GHCR, env_file, restart policy, healthcheck; `caddy`
  service with ports 80/443 and persistent volumes.
- `Caddyfile` with the chosen TLS mode.
- `caddy/Dockerfile` for the Cloudflare DNS module (if proxied).
- `bootstrap.sh` for Docker install/dirs (used by OpenTofu startup script or manual recovery).
- Commit: `feat(deploy): add VM compose and Caddy configuration`.

### 5. GitHub Actions CI + release
- `api-ci.yml`: Go tests, build, Docker build smoke test on PR.
- `api-release.yml`: on main, build and push GHCR with `sha-<short>` and `latest`.
- Permissions: `contents: read`, `packages: write`.
- Commit: `ci: add API test and GHCR release workflows`.

### 6. GitHub Actions deploy
- `api-deploy.yml`: deploy on successful release / push to main.
- SSH to VM with `DEPLOY_SSH_KEY`, write `.env` from secrets, login GHCR, pull, run
  `migrate:up`, run `bootstrap:admin`, `docker compose up -d`, prune old images, verify `/healthz`.
- Optional `production` GitHub environment with manual approval.
- Commit: `ci: deploy API to GCP over SSH`.

### 7. OpenTofu workflow + docs
- `infra-opentofu.yml`: fmt/validate/plan on PR, manual apply.
- GCP auth via WIF or service-account key per decision.
- README deployment section with first-deploy runbook, secret list, rollback, and DNS/TLS verification.
- Commit: `docs: add API deployment runbook and infra workflow`.

## What I need from you

Please provide secrets by creating a local **untracked** file, e.g.
`/Users/prikenang/Documents/ZOG/POC/beacon-check-in/.env.deploy` (already ignored), or add them as
GitHub secrets later. Do **not** paste passwords in chat.

### GitHub
- Repository owner/name (e.g. `smartoryu/beacon-check-in`) and visibility.
- Permission to create/push it with the already-authenticated `gh` account.
- Whether to use a `production` GitHub Environment with required reviewers.

### GCP
- Project ID, billing account availability, desired region/zone.
- Whether the VM must stay in the e2-micro free-tier US regions or may run in Singapore
  (`asia-southeast1`) for lower Supabase latency.
- Auth method for OpenTofu/CI: Workload Identity Federation (recommended) or a service-account JSON key.
- GCS state bucket name (or permission to create one).
- SSH admin CIDR for port 22 (e.g. your home/office IP), or approval to use `0.0.0.0/0` for the POC.
- Existing SSH keypair or approval to generate a dedicated deploy keypair.

### Supabase
- Project region and PostgreSQL version.
- Connection string or components: host, port, database, user, password.
  Preferred: session pooler on `:5432` with `sslmode=require`.
- Confirmation that the `postgres` role can create `pg_trgm`, `pgcrypto`, and the `uuidv7()` function.

### Cloudflare
- Zone `playground.my.id` is already in Cloudflare?
- API token with `Zone:Read` + `Zone.DNS:Edit` (and DNS challenge permission if using Caddy DNS-01).
- TLS mode decision: proxied + DNS-01 (recommended), DNS-only + HTTP-01, or proxied + Origin Certificate.
- ACME email for Let's Encrypt (if ACME is used).

### API runtime values
- `SUPER_ADMIN_NAME`, `SUPER_ADMIN_EMAIL`, `SUPER_ADMIN_PASSWORD` for first bootstrap.
- `JWT_SECRET_KEY` (or approval to generate it).
- `CORS_ORIGINS` (web domain later, or `[]` for API-only).
- SMTP: leave disabled for POC, or provide SMTP host/port/user/password.
- Whether API docs should be enabled in production.

## Verification

- `tofu fmt -check`, `tofu validate`, `tofu plan` clean.
- GCP VM reachable on 22/443; Caddy gets a valid certificate.
- `https://beacon-check-in-api.playground.my.id/healthz` returns healthy.
- `migrate:up` applies all migrations on Supabase (including portable `uuidv7()`).
- `bootstrap:admin` creates exactly one super admin; re-running it is a no-op.
- Login works with the bootstrapped super admin over HTTPS.
- Beacon/event/check-in smoke test against the deployed API.
- GitHub Actions: PR runs tests; main push publishes a GHCR image and deploys; failed deploy leaves the
  previous container running.
- No secret appears in `git status`, `git log -p`, Docker image history, or workflow logs.
