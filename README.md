# Beacon Check-In

An iBeacon attendance POC built as a ZOG monorepo.

- **Admins** register physical iBeacon devices from a Flutter app, attach them to events on the web app and place them on a 2D floor grid.
- **Users** self-register in the Flutter app and check in to an ongoing event. The check-in is recorded locally first (offline-first) and validated when the phone can hear the event's beacon(s).
- The **web app** manages admins, events, beacons and the super-admin approval queue, and renders a triangulation graph for accepted check-ins.

## Repository layout

```
beacon-check-in/
├── apps/
│   ├── api/       # go-modular: auth, admin, user, beacon, event, checkin, dashboard
│   ├── web/       # React Router 7 SPA (Tailwind CSS)
│   └── mobile/    # Flutter: admin scanner, user check-in, offline queue
├── packages/
│   └── shared-ui/ # ZOG shared React UI package (generated template; web currently uses plain Tailwind)
├── compose.yaml   # Postgres 18, Mailpit, pgweb, optional instrumentation
├── .moon/         # moonrepo workspace + tasks
└── pnpm-workspace.yaml
```

## Prerequisites

- Node.js 24+, pnpm 11+
- Go 1.26+ (`GOTOOLCHAIN=auto` can fetch the template's toolchain)
- Flutter 3.47+ with Android and/or iOS toolchains
- Docker + Docker Compose

Go tooling used by the moon tasks:

```bash
go install github.com/swaggo/swag/cmd/swag@v1.16.6   # OpenAPI generation
go install gotest.tools/gotestsum@latest             # api:test
# watchexec is used by api:dev for live reload: https://github.com/watchexec/watchexec
```

## Quick start

```bash
# 1. Install JS dependencies
pnpm install

# 2. Start local infrastructure (Postgres 18 on :5432, pgweb on :54321)
pnpm compose:up

# 3. Configure the API
cp apps/api/.env.example apps/api/.env
# edit JWT_SECRET_KEY and any other values

# 4. Migrate + seed (1 super admin, 2 admins, 2 users, optional demo beacons/event)
moon run api:run -- migrate:reset --up --seed --force
# or, to include the demo event + 3 demo beacons:
# SEED_DEMO_DATA=true moon run api:run -- migrate:reset --up --seed --force

# 5. Run the apps
moon run api:dev        # API on http://localhost:8080
moon run web:dev        # web on http://localhost:3000

# 6. Mobile (Android emulator default API URL is http://10.0.2.2:8080/api/v1)
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
# iOS simulator:
# flutter run --dart-define=API_BASE_URL=http://localhost:8080/api/v1
```

## Seeded accounts

| Role | Email | Password |
| :-- | :-- | :-- |
| `super_admin` | `superadmin@beacon.local` | `SuperAdmin123!` |
| `admin` | `admin1@beacon.local` | `Admin123!` |
| `admin` | `admin2@beacon.local` | `Admin123!` |
| `user` | `user1@beacon.local` | `User123!` |
| `user` | `user2@beacon.local` | `User123!` |

Seeded accounts are email-verified and are not forced to change passwords. Admins created from the web app receive a one-time temporary password and must change it on first sign-in.

Optional demo data (`SEED_DEMO_DATA=true`) adds:

- 3 beacons with proximity UUID `00000000-0000-4000-8000-000000000001`, major `1`, minors `1`–`3`
- one ongoing **Demo Check-In Event** with a 20×20 m grid and beacon positions

## Roles and permissions

| Action | super_admin | admin | user |
| :-- | :--: | :--: | :--: |
| Create/edit/delete admins | ✓ | ✗ | ✗ |
| Approve beacon delete/restore | ✓ | ✗ | ✗ |
| Direct beacon delete/restore | ✓ | ✗ | ✗ |
| Request beacon delete/restore | ✓ | ✓ | ✗ |
| Create/edit/delete events | ✓ | ✓ | ✗ |
| Attach beacons / set coordinates | ✓ | ✓ | ✗ |
| Rename beacon label | ✓ | ✓ | ✗ |
| Register beacon (mobile) | ✓ | ✓ | ✗ |
| Check in (mobile) | ✗ | ✗ | ✓ |

Admins cannot delete beacons directly. They submit a request with a reason; the super admin approves or rejects it on the **Approvals** page. Beacon deletion is a soft delete and is blocked while the beacon is attached to an ongoing/upcoming event, so past events keep their snapshot.

## How check-in works

1. The user opens an ongoing event in the mobile app.
2. The app scans for the event's iBeacon identities (UUID + major + minor) for 8 seconds and keeps an RSSI sample window per beacon.
3. The attempt is written to a local Hive queue immediately — before any network call. The UI shows “check-in recorded”.
4. A sync worker posts the attempt to `POST /api/v1/events/:id/checkins` when connectivity is available. `client_checkin_id` makes retries idempotent.
5. The API validates:
   - `recorded_at` (device time) is inside the event window;
   - `recorded_at` is not more than `MAX_CLOCK_SKEW` in the future and not older than `MAX_OFFLINE_AGE`;
   - the user has not already checked in;
   - at least `min_beacons` event beacons have median RSSI ≥ `rssi_threshold_dbm`;
   - with 3+ positioned beacons, the trilaterated point is inside `coverage_radius_m` when set.
6. Accepted and rejected attempts are both stored for audit and triangulation debugging.

The mobile queue retries with exponential backoff and syncs on launch, resume, connectivity restore, successful login/refresh, or **Sync now**. No OS background job is implemented in the POC.

## Beacon registration (mobile admin)

1. Sign in on mobile as an admin or super admin.
2. Open **Beacon Scanner**. The real-time Bluetooth banner shows adapter, permission, scan and telemetry state.
3. Move near an iBeacon. Each discovered beacon is parsed from the standard Apple manufacturer data (`4C 00 02 15 …`).
4. The app batch-checks identities against the API and flags each as **New**, **Registered** or **Deleted**.
5. For a new beacon, enter a label and optionally enable **Read GATT details** (Device Information `0x180A` + battery `0x180F`). Registering is admin-only and duplicate identities are rejected.
6. For a deleted beacon, submit a restore request for super-admin approval.

The registration stores the full advertisement (raw bytes, manufacturer/service data, local name, iBeacon measured power, generic BLE TX power when exposed, device id/MAC when available, RSSI samples) plus optional GATT details.

## Web app walkthrough

1. Sign in at `http://localhost:3000` as `superadmin@beacon.local`.
2. **Dashboard** shows counts, recent check-ins and pending approvals.
3. **Admins** (super admin only): create an admin, copy the one-time temporary password.
4. **Beacons**: inspect metadata, rename, delete/restore (super admin direct; admin request).
5. **Approvals** (super admin only): approve/reject beacon delete/restore requests.
6. **Events**: create an event, attach at least one active beacon, set floor size, RSSI threshold, min beacons and optional coverage radius.
7. **Event detail**: drag beacons on the floor grid (0.5 m snap, arrow keys, shift = 2 m), save the layout, view accepted/rejected check-ins and select a check-in to render the triangulation graph.
8. Deleting an event soft-deletes it; check-ins and beacon references remain.

## Demo without hardware

- Use `SEED_DEMO_DATA=true` to get three demo beacons and an ongoing demo event.
- In a **debug** mobile build (`flutter run`), check-in screens show **Simulate beacon readings (debug)** and the admin scanner shows **Add simulated beacon (debug)**.
- This lets you exercise the full flow — registration, event creation, placement, local queue, sync, server validation and the triangulation graph — without physical beacons.

## Useful commands

| Command | Description |
| :-- | :-- |
| `moon run api:dev` | API with live reload |
| `moon run api:test` | Go tests |
| `moon run api:migration-up` | Apply goose migrations |
| `moon run api:migration-status` | Migration status |
| `moon run api:seed` | Run seeders |
| `moon run web:dev` | Web dev server |
| `moon run web:test` | Web unit tests |
| `moon run web:typecheck` | TypeScript check |
| `moon run web:build` | Web production build |
| `moon run mobile:pub-get` | Flutter dependency install |
| `moon run mobile:analyze` | Flutter analyzer |
| `moon run mobile:test` | Flutter tests |
| `moon run mobile:build` | Debug APK build |
| `pnpm compose:up` / `down` / `cleanup` | Local infrastructure |

## Production deployment

The API deployment assets live in [`infra/`](./infra/README.md):

- OpenTofu provisions a GCP `e2-micro` VM, static IP, firewall and Cloudflare DNS.
- Caddy terminates TLS with the Cloudflare DNS-01 challenge.
- GitHub Actions runs tests, publishes API + Caddy images to GHCR, and deploys
  over SSH.
- PostgreSQL is hosted on Supabase via its session pooler.

See [`infra/README.md`](./infra/README.md) for the complete runbook and the
GitHub variables/secrets checklist. No credentials are committed; runtime
configuration comes from the VM `.env`, GitHub secrets, and environment
variables.

## API

- OpenAPI docs: `http://localhost:8080/api-docs`
- Raw spec: `http://localhost:8080/api/openapi.json`
- Health: `http://localhost:8080/healthz`
- Base path: `/api/v1`

Key configuration (see `apps/api/.env.example`):

| Variable | Default | Purpose |
| :-- | :-- | :-- |
| `SERVER_PORT` | `8080` | API port |
| `DATABASE_URL` | local Postgres | pgx connection |
| `JWT_SECRET_KEY` | — | JWT signing secret |
| `CORS_ORIGINS` | `[http://localhost:3000]` | Web origin |
| `MAX_OFFLINE_AGE` | `24h` | Maximum age of a queued check-in |
| `MAX_CLOCK_SKEW` | `5m` | Tolerated future device clock skew |

## Notes and limitations

- Check-in validation uses the device `recorded_at`, not the sync time, so an offline check-in made during the event remains valid when synced later. Device clock drift is the remaining risk; the app stores the last-known server offset where available.
- BLE scanning is foreground-only. No background ranging/OS background sync is implemented.
- iOS hides the beacon MAC; identity is always the iBeacon UUID + major + minor.
- RSSI is noisy; trilateration is approximate and reports `accuracy_m`. Event-level path-loss exponent and per-beacon TX-power overrides are supported.
- The mobile queue is stored in app-private Hive storage (not encrypted in the POC). Auth tokens use `flutter_secure_storage`.
- The web stores JWTs in `localStorage` for POC simplicity; production should use httpOnly cookies or a BFF.
- Registering a soft-deleted physical beacon requires a restore request; its identity remains unique.
