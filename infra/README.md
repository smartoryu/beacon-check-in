# Beacon Check-In API — production deployment

This directory contains the API-only production deployment:

- `opentofu/` — GCP `e2-micro` VM, static IP, firewall, Cloudflare DNS
- `deploy/` — Docker Compose (API + Caddy), Caddyfile, Cloudflare DNS-01 Caddy image
- `.env.example` — the runtime environment template used on the VM
- `../.github/workflows/` — CI, GHCR release, SSH deploy, OpenTofu plan/apply

## Target

| Item | Value |
| :-- | :-- |
| API hostname | `beacon-check-in-api.playground.my.id` |
| Web hostname | `admin-beacon-check-in.playground.my.id` |
| Compute | GCP `e2-micro`, `us-central1-a`, Ubuntu 24.04, 30 GB pd-standard |
| Database | Supabase PostgreSQL (session pooler, TLS) |
| Registry | `ghcr.io/smartoryu/beacon-check-in-api`, `.../beacon-check-in-caddy`, `.../beacon-check-in-web` |
| TLS | Cloudflare proxied DNS + Caddy Cloudflare DNS-01 challenge |
| Reverse proxy | Caddy → `api:8080` |
| CI/CD | GitHub Actions (public repo) |

## One-time setup

### 1. GCP project and APIs

1. Create or choose a GCP project with billing enabled.
2. Enable the Compute Engine API.
3. Create a GCS bucket for OpenTofu state, e.g. `<project-id>-tofu-state`, with
   versioning enabled. The OpenTofu workflow receives it as `TF_STATE_BUCKET`.
4. Create a service account for OpenTofu with:
   - `roles/compute.admin`
   - `roles/iam.serviceAccountUser`
   - `roles/storage.objectAdmin` on the state bucket
5. Prefer **Workload Identity Federation** for GitHub Actions. If you use a
   service-account JSON key instead, store it as `GCP_SA_KEY`.

### 2. Deploy SSH key

```bash
./scripts/generate-deploy-key.sh
```

- Add the **private** key to the GitHub secret `DEPLOY_SSH_KEY`.
- Add the **public** key to `DEPLOY_SSH_PUBLIC_KEY` and to
  `infra/opentofu/terraform.tfvars` as `ssh_public_key`.
- Set `admin_cidr` in `terraform.tfvars` to your public IP `/32` (or a narrow
  office/VPN range). Port 22 is not opened to the world.

### 3. Cloudflare

1. Confirm `playground.my.id` is an active zone in Cloudflare.
2. Create an API token with:
   - `Zone:Read`
   - `Zone.DNS:Edit` for the zone
3. Store the token as the GitHub secret `CLOUDFLARE_API_TOKEN` and locally as
   `TF_VAR_cloudflare_api_token` (or in `terraform.tfvars`). The provider reads
   `var.cloudflare_api_token`; the plain `CLOUDFLARE_API_TOKEN` env var is only
   used by Caddy's DNS-01 challenge.
4. Copy the zone ID (zone overview page) into the `CLOUDFLARE_ZONE_ID` GitHub
   variable and into `terraform.tfvars` as `cloudflare_zone_id`.
5. The OpenTofu config creates a proxied `A` record. Caddy uses the same token
   for the DNS-01 challenge, so Cloudflare SSL mode should be **Full (strict)**.

### 4. Supabase

1. Create the project in the region closest to the VM (for `us-central1`, a US
   region is best).
2. Use the **session pooler** connection string (port `5432`), not the
   transaction pooler, for a long-lived pgx pool:
   ```text
   postgresql://postgres.<project-ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres?sslmode=require
   ```
3. Make sure the `postgres` role can create `pg_trgm`, `pgcrypto`, and the
   `public.uuidv7()` function. The migration chain creates the function, so the
   database does not need PostgreSQL 18.
4. Keep `PG_MAX_POOL_SIZE` low (10 is a good start).

### 5. OpenTofu variables

```bash
cd infra/opentofu
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

`terraform.tfvars` is gitignored. It holds project IDs, region, SSH public
key, admin CIDR, domain, and the Cloudflare zone ID. The Cloudflare API token
is the one secret in play: either keep it in `terraform.tfvars`
(`cloudflare_api_token`, gitignored) or leave it out and export it as
`TF_VAR_cloudflare_api_token`.

For local apply, authenticate with Application Default Credentials:

```bash
# Only needed if you use a service account instead of `gcloud auth application-default login`
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

# Optional alternative to storing the token in terraform.tfvars
export TF_VAR_cloudflare_api_token=...
export TF_STATE_BUCKET=...

tofu init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="prefix=beacon-check-in/infra"
tofu plan -out=tfplan
tofu apply tfplan
```

`terraform.tfvars` is loaded automatically; `-var-file` is redundant.

Check a token before a long debug loop. Use `/zones`, not
`/user/tokens/verify`: account-owned tokens (`cfat_...`) return
`401 / Invalid API Token (1000)` from the verify endpoint even when they work
perfectly, so that endpoint will send you chasing a phantom.

```bash
curl -s -H "Authorization: Bearer $TF_VAR_cloudflare_api_token" \
  https://api.cloudflare.com/client/v4/zones \
  | jq -r '.success, (.result[]?.name), (.errors[]?.message)'
# true + playground.my.id -> usable, zone scope correct
# false + Invalid API Token (1000) -> revoked, mistyped, or not a token value
```

A bad token is invisible at `tofu plan` time: the plan is computed locally and
only fails once `tofu apply` calls the Cloudflare API (`Authentication error
(10000)`).

Or run the **Infra OpenTofu** workflow manually.

### 6. GitHub repository variables and secrets

Repository → Settings → Secrets and variables → Actions.

**Variables** (non-secret):

| Variable | Example |
| :-- | :-- |
| `GCP_PROJECT_ID` | `my-gcp-project` |
| `GCP_REGION` | `us-central1` |
| `GCP_ZONE` | `us-central1-a` |
| `API_INSTANCE_NAME` | `beacon-check-in-api` |
| `API_MACHINE_TYPE` | `e2-micro` |
| `API_DISK_SIZE_GB` | `30` |
| `API_IMAGE_FAMILY` | `ubuntu-2404-lts-amd64` |
| `DEPLOY_USER` | `deploy` |
| `ADMIN_CIDR` | `203.0.113.10/32` |
| `API_DOMAIN` | `beacon-check-in-api.playground.my.id` |
| `WEB_DOMAIN` | `admin-beacon-check-in.playground.my.id` |
| `CLOUDFLARE_ZONE_NAME` | `playground.my.id` (informational; records key off the ID) |
| `CLOUDFLARE_ZONE_ID` | `aacb6e1de8db2fb5963a35d6865265f8` |

**Secrets**:

| Secret | Purpose |
| :-- | :-- |
| `DEPLOY_SSH_KEY` | Private ed25519 deploy key |
| `DEPLOY_SSH_PUBLIC_KEY` | Same keypair's public key for OpenTofu |
| `VM_HOST` | Static IP output from OpenTofu (or the hostname) |
| `VM_USER` | `deploy` |
| `VM_PORT` | `22` (optional; defaults to 22) |
| `DEPLOY_KNOWN_HOSTS` | Optional pinned `known_hosts` entry |
| `API_ENV_FILE` | Full runtime `.env` content (see below) |
| `TF_STATE_BUCKET` | GCS bucket for OpenTofu state |
| `CLOUDFLARE_API_TOKEN` | Zone:Read + Zone.DNS:Edit |
| `GCP_SA_KEY` | Service-account JSON (only if not using WIF) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider resource name (if using WIF) |
| `GCP_SERVICE_ACCOUNT` | Deploy service-account email (if using WIF) |

### 7. `API_ENV_FILE`

This secret is the complete runtime `.env` for the VM. Start from
`infra/deploy/.env.example` and fill in real values. It must include at least:

```dotenv
DOMAIN=beacon-check-in-api.playground.my.id
WEB_DOMAIN=admin-beacon-check-in.playground.my.id
CORS_ORIGINS=[https://admin-beacon-check-in.playground.my.id]
ACME_EMAIL=you@example.com
CLOUDFLARE_API_TOKEN=...
APP_MODE=production
APP_BASE_URL=https://beacon-check-in-api.playground.my.id
JWT_SECRET_KEY=...
DATABASE_URL=postgresql://...pooler.supabase.com:5432/postgres?sslmode=require
SUPER_ADMIN_NAME=...
SUPER_ADMIN_EMAIL=...
SUPER_ADMIN_PASSWORD=...
```

The deploy workflow appends the immutable `GHCR_IMAGE` and `GHCR_CADDY_IMAGE`
tags automatically. Do not put those two lines in the secret.

## Deploying

1. Push to `main`.
2. **API Release** runs only for `apps/api/**` (plus Caddy/config changes) and publishes the API + Caddy images.
3. **Web Release** runs only for `apps/web/**`, `packages/shared-ui/**` and `infra/deploy/web/**`, and publishes the web image.
4. **App Deploy** runs after either release and deploys only the affected service + Caddy:
   - writes `/opt/beacon-check-in/.env` with mode `600`,
   - copies `docker-compose.yml` and `Caddyfile`,
   - logs in to GHCR with the workflow token,
   - pulls the new images,
   - runs `migrate:up`,
   - runs `bootstrap:admin` (idempotent),
   - restarts the API, web and Caddy, and
   - checks both `https://<api-domain>/healthz` and `https://<web-domain>/healthz`.

First deployment only:

```bash
gh workflow run "API Release"
gh workflow run "App Deploy" -f service=api
gh workflow run "Web Release"
gh workflow run "App Deploy" -f service=web
```

After OpenTofu creates the VM, set the `VM_HOST` secret to the `static_ip`
output. The VM's first boot installs Docker, creates the `deploy` user, adds a
2 GB swap file, and prepares `/opt/beacon-check-in`.

## Verification

```bash
# DNS / proxy
dig +short beacon-check-in-api.playground.my.id

# Health over HTTPS
curl -fsS https://beacon-check-in-api.playground.my.id/healthz
curl -fsS https://admin-beacon-check-in.playground.my.id/healthz

# API docs (only if ENABLE_API_DOCS=true)
curl -I https://beacon-check-in-api.playground.my.id/api-docs
```

On the VM:

```bash
ssh deploy@<static-ip>
cd /opt/beacon-check-in
docker compose ps
docker compose logs -f api
docker compose logs -f caddy
```

## Rollback

The release workflow publishes immutable `sha-<short>` tags. Re-run **API
Deploy** with an older tag:

```bash
gh workflow run "App Deploy" -f service=api -f image_tag=sha-<old-sha>
# or for the web app:
gh workflow run "App Deploy" -f service=web -f image_tag=sha-<old-sha>
```

Migrations are forward-only. If a release contains a destructive migration,
restore the Supabase database from a backup before rolling back the image.

## Security notes

- `.env`, `terraform.tfvars`, `tfstate`, `tfplan`, SSH keys, and GCP
  credentials are gitignored.
- The deploy workflow writes the VM `.env` with `umask 077` and mode `600`.
- No secret is passed as a Docker build arg.
- The Cloudflare API token is scoped to DNS only and is not baked into images.
- SSH is restricted to `admin_cidr`; HTTP/HTTPS are restricted to Cloudflare
  edge ranges when proxying is enabled.
- Rotate `JWT_SECRET_KEY` and the Supabase password if they were ever exposed.
- The `bootstrap:admin` command never logs the password and is idempotent.
