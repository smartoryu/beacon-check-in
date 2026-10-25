# Beacon Check-In API Reference

Base URL:

```text
Local:       http://localhost:8080/api/v1
Production:  https://beacon-check-in-api.playground.my.id/api/v1
```

Other useful endpoints:

| URL | Purpose |
| :-- | :-- |
| `GET /healthz` | API and database health check. |
| `GET /api-docs` | Interactive Scalar/Swagger UI. |
| `GET /api/openapi.json` | Raw generated OpenAPI/Swagger 2.0 JSON. |

The API is a Go/Echo service backed by PostgreSQL. All normal API routes are under `/api/v1`.

---

## Authentication

Most endpoints require a JWT access token:

```http
Authorization: Bearer <access_token>
```

Get one by signing in:

```http
POST /api/v1/auth/signin/email
Content-Type: application/json

{
  "email": "superadmin@beacon.local",
  "password": "SuperAdmin123!"
}
```

Successful response:

```json
{
  "user": {
    "id": "01a164b6-3e2a-7d70-a3ad-b6354e6c2aa3",
    "display_name": "Super Admin",
    "email": "superadmin@beacon.local",
    "role": "super_admin",
    "must_change_password": false,
    "email_verified_at": "2026-01-01T00:00:00Z",
    "created_at": "2026-01-01T00:00:00Z"
  },
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "session_id": "01a164b6-...",
  "token_expiry": "2026-01-02T00:00:00Z"
}
```

- **Access token**: signed JWT used for API calls.
- **Refresh token**: used to obtain a new access token.
- The token payload contains `user_id`, `email`, `role` and `sid` (session ID).
- Admins created from the web have `must_change_password: true` until they change their temporary password.

### Roles

| Role | Scope |
| :-- | :-- |
| `super_admin` | Full access, including admin management and beacon approvals. |
| `admin` | Event/beacon management and read-only user/dashboard access. |
| `user` | Mobile check-in and personal history. |

Role checks are enforced by the API, not just hidden in the UI.

---

## Common response conventions

### Success

- `200 OK` — read/update success.
- `201 Created` — resource created.
- `204 No Content` — used by some advanced endpoints.

### Errors

Errors are JSON objects, usually:

```json
{
  "error": "Validation failed",
  "details": {
    "title": "Title is required"
  }
}
```

or:

```json
{
  "error": "Invalid email or password",
  "details": "The email or password you entered is incorrect."
}
```

Common status codes:

| Status | Meaning |
| :-- | :-- |
| `400` | Invalid request, validation error, invalid state transition, or invalid UUID. |
| `401` | Missing/invalid access token, or invalid credentials. |
| `403` | Authenticated but not allowed for this role. |
| `404` | Resource not found. |
| `409` | Conflict: duplicate email, duplicate beacon, already checked in, pending request. |
| `429` | Rate limit exceeded. |
| `500` | Unexpected server error. Check API logs. |

---

## Auth endpoints

### `POST /auth/signin/email`

Sign in with email and password. Public.

**Body**

```json
{
  "email": "user@example.com",
  "password": "secret-password"
}
```

**Response:** `200` with user, access token and refresh token.

**Errors**

- `400` validation failed;
- `401` invalid credentials;
- `401` email not verified.

### `POST /auth/signin/username`

Same as email sign-in, but with `username`.

```json
{
  "username": "user123",
  "password": "secret-password"
}
```

### `POST /auth/signup`

Self-register a normal `user`. Public. Admin accounts cannot be created here.

```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "password": "secret-password",
  "password_confirmation": "secret-password"
}
```

**Response:** `201` with the same shape as sign-in.

**Errors**

- `400` validation failed;
- `409` email already registered.

### `POST /auth/refresh`

Exchange a refresh token for a new access token.

```json
{
  "refresh_token": "eyJ..."
}
```

**Response:** `200` with a new user/access/refresh payload.

**Errors:** `401` invalid or expired refresh token.

### `GET /auth/me`

Returns the authenticated user.

**Headers:** `Authorization: Bearer <token>`

**Response**

```json
{
  "id": "01a164b6-3e2a-7d70-a3ad-b6354e6c2aa3",
  "display_name": "Super Admin",
  "email": "superadmin@beacon.local",
  "role": "super_admin",
  "must_change_password": false,
  "created_at": "2026-01-01T00:00:00Z"
}
```

### `POST /auth/change-password`

Change the current user’s password and clear `must_change_password`.

**Headers:** `Authorization: Bearer <token>`

```json
{
  "current_password": "old-password",
  "new_password": "new-password",
  "password_confirmation": "new-password"
}
```

**Response**

```json
{
  "message": "Password changed successfully"
}
```

**Errors:** `400` for wrong current password, mismatched confirmation, or validation failure.

### Advanced auth endpoints

These exist for completeness and internal flows, but the web/mobile apps do not normally call them directly:

| Method | Path | Purpose |
| :-- | :-- | :-- |
| `POST` | `/auth/password` | Set a user password by `user_id` (protected). |
| `PUT` | `/auth/password/{userId}` | Update a password with current-password validation. |
| `POST` | `/auth/session` | Create a session record. |
| `PUT` | `/auth/session` | Update a session record. |
| `GET` | `/auth/session/{sessionId}` | Get a session. |
| `DELETE` | `/auth/session/{sessionId}` | Delete/revoke a session. |
| `POST` | `/auth/refresh-token` | Create a refresh-token record. |
| `PUT` | `/auth/refresh-token` | Update a refresh-token record. |
| `GET` | `/auth/refresh-token/{tokenId}` | Get a refresh-token record. |
| `DELETE` | `/auth/refresh-token/{tokenId}` | Delete a refresh-token record. |
| `POST` | `/auth/verification/email/initiate` | Start email verification. |
| `POST` | `/auth/verification/email/validate` | Validate an email token. |
| `POST` | `/auth/verification/email/resend` | Resend verification. |
| `POST` | `/auth/verification/email/revoke` | Revoke verification. |
| `GET` | `/auth/verify-email` | Validate an email link. |

---

## User endpoints

Both routes require `super_admin` or `admin`.

### `GET /users`

List users.

Query parameters:

| Parameter | Type | Description |
| :-- | :-- | :-- |
| `search` | string | Match name/email. |
| `role` | string | `super_admin`, `admin` or `user`. |
| `include_deleted` | boolean | Include soft-deleted users. |
| `limit` | integer | Page size. |
| `offset` | integer | Page offset. |

**Response:** `200` array of users.

### `GET /users/{userId}`

Get one user by UUID.

**Response:** `200` user.

**Errors:** `400` invalid UUID, `404` not found.

> There are internal handler methods for creating/updating/deleting users, but they are not registered as public API routes. Admin account creation goes through `/admins`.

---

## Admin management

All routes require `super_admin`.

### `GET /admins`

List admin/super-admin accounts.

Query parameters:

| Parameter | Type | Description |
| :-- | :-- | :-- |
| `search` | string | Match name/email. |
| `include_deleted` | boolean | Include soft-deleted admins. |

**Response:** `200` array of users.

### `POST /admins`

Create an admin with a one-time temporary password.

```json
{
  "name": "Jane Admin",
  "email": "jane@example.com"
}
```

**Response:** `201`

```json
{
  "user": {
    "id": "01a164b6-...",
    "display_name": "Jane Admin",
    "email": "jane@example.com",
    "role": "admin",
    "must_change_password": true
  },
  "temporary_password": "cobalt-42"
}
```

The temporary password is **one word + a two-digit number** and is at most 10 characters long, for example `cobalt-42`. It is shown once. The admin must change it on first sign-in.

**Errors**

- `400` validation failed;
- `409` email already registered.

### `GET /admins/{id}`

Get one admin by UUID.

### `PUT /admins/{id}`

Update name/email.

```json
{
  "name": "Jane Admin",
  "email": "jane.new@example.com"
}
```

### `DELETE /admins/{id}`

Soft-delete an admin and revoke their sessions.

**Response**

```json
{
  "message": "Admin deleted"
}
```

The seeded super admin cannot be modified/deleted.

### `POST /admins/{id}/reset-password`

Generate a new temporary phrase, replace the stored password hash, revoke the admin’s sessions, and set `must_change_password: true`.

**Response**

```json
{
  "temporary_password": "opal-97"
}
```

**Errors:** `404` admin not found, `400` cannot modify seeded super admin.

---

## Beacons and approvals

All beacon routes require `super_admin` or `admin`.

### Beacon object

```json
{
  "id": "01a167bc-...",
  "identity_key": "f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:12",
  "proximity_uuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e",
  "major": 1,
  "minor": 12,
  "label": "Lobby North",
  "local_name": "Beacon-12",
  "platform_device_id": "AA:BB:CC:DD:EE:12",
  "device_address_type": "public",
  "tx_power": -59,
  "metadata": {},
  "gatt_info": {},
  "gatt_read_at": "2026-01-01T00:00:00Z",
  "registered_by": "01a164b6-...",
  "registered_at": "2026-01-01T00:00:00Z",
  "last_seen_at": "2026-01-01T00:00:00Z",
  "deleted_at": null,
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": null
}
```

### `GET /beacons`

List registered beacons.

Query parameters:

| Parameter | Type | Description |
| :-- | :-- | :-- |
| `search` | string | Match label/identity/device id. |
| `status` | string | `active`, `deleted` or `all`. |
| `include_deleted` | boolean | Include soft-deleted beacons. |
| `limit` | integer | Page size. |
| `offset` | integer | Page offset. |

### `POST /beacons/lookup`

Batch-check scanned identities.

```json
{
  "identities": [
    "f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:12",
    "f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:13"
  ]
}
```

**Response**

```json
{
  "items": [
    {
      "identity_key": "f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:12",
      "status": "registered",
      "beacon": { "...": "..." }
    },
    {
      "identity_key": "f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:13",
      "status": "unknown"
    }
  ]
}
```

`status` is `registered`, `deleted` or `unknown`.

### `POST /beacons`

Register a scanned iBeacon.

```json
{
  "proximity_uuid": "f7826da6-4fa2-4e98-8024-bc5b71e0893e",
  "major": 1,
  "minor": 12,
  "label": "Lobby North",
  "local_name": "Beacon-12",
  "platform_device_id": "AA:BB:CC:DD:EE:12",
  "device_address_type": "public",
  "tx_power": -59,
  "metadata": {
    "manufacturer_data": "4c000215...",
    "service_uuids": []
  },
  "gatt_info": {
    "battery_level": 87,
    "manufacturer_name": "Example"
  },
  "rssi_samples": [-58, -60, -57]
}
```

**Response:** `201` beacon object.

**Errors**

- `400` validation failed;
- `409` beacon identity already exists.

### `GET /beacons/{id}`

Get one beacon.

### `PATCH /beacons/{id}`

Rename a beacon.

```json
{
  "label": "Lobby South"
}
```

### `GET /beacons/{id}/usage`

List events that use this beacon.

**Response**

```json
[
  {
    "event_id": "01a167bc-...",
    "title": "Launch Event",
    "starts_at": "2026-01-01T09:00:00Z",
    "ends_at": "2026-01-01T17:00:00Z",
    "x": 4.5,
    "y": 2,
    "deleted_at": null
  }
]
```

### `DELETE /beacons/{id}`

Delete a beacon.

- `super_admin`: deletes immediately.
- `admin`: creates an approval request.

**Body**

```json
{
  "reason": "Beacon is physically damaged and will be replaced."
}
```

**Response**

```json
{
  "mode": "deleted",
  "beacon": { "...": "..." },
  "message": "Beacon deleted"
}
```

For an admin request, `mode` is `requested` and `request` contains the pending change request.

**Errors**

- `400` beacon is in an active event;
- `400` beacon already deleted;
- `409` a pending request already exists.

### `POST /beacons/{id}/restore`

Restore a deleted beacon. Same body and response shape as delete. Super admins restore directly; admins create a request.

### `GET /beacon-requests`

List beacon change requests. Requires `super_admin`.

Query: `status=pending|approved|rejected`.

### `POST /beacon-requests`

Create a delete/restore request.

```json
{
  "beacon_id": "01a167bc-...",
  "action": "delete",
  "reason": "The beacon is damaged."
}
```

### `POST /beacon-requests/{id}/approve`

Approve a request. Requires `super_admin`.

```json
{
  "note": "Approved, replacement ordered."
}
```

### `POST /beacon-requests/{id}/reject`

Reject a request. Requires `super_admin`.

```json
{
  "note": "Beacon is still needed for next week's event."
}
```

---

## Event endpoints

### Event object

```json
{
  "id": "01a167bc-...",
  "title": "Launch Event",
  "description": "Annual product launch.",
  "place_name": "Main Hall",
  "address": "123 Example Street",
  "latitude": null,
  "longitude": null,
  "starts_at": "2026-01-01T09:00:00Z",
  "ends_at": "2026-01-01T17:00:00Z",
  "timezone": "Asia/Jakarta",
  "floor_width_m": 20,
  "floor_height_m": 20,
  "rssi_threshold_dbm": -75,
  "min_beacons": 2,
  "coverage_radius_m": 9,
  "path_loss_exponent": 2,
  "created_by": "01a164b6-...",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": null,
  "deleted_at": null,
  "beacons": [
    {
      "beacon_id": "01a167bc-...",
      "identity_key": "f7826da6-...:1:12",
      "label": "Lobby North",
      "local_name": "Beacon-12",
      "tx_power": -59,
      "tx_power_override": null,
      "x": 4.5,
      "y": 2,
      "beacon_deleted_at": null
    }
  ],
  "checkin_count": 0
}
```

### `GET /events/active`

Returns non-deleted events that have not ended. Any authenticated role.

This is the mobile app’s main event feed. It includes beacon identities and positions needed for check-in.

### `GET /events`

List events. Requires `super_admin` or `admin`.

Query parameters:

| Parameter | Type | Description |
| :-- | :-- | :-- |
| `search` | string | Match title/place/address. |
| `status` | string | `upcoming`, `ongoing`, `past`, `all`. |
| `include_deleted` | boolean | Include soft-deleted events. |
| `limit` | integer | Page size. |
| `offset` | integer | Page offset. |

### `GET /events/{id}`

Get one event with beacons and check-in count. Any authenticated role.

### `POST /events`

Create an event. Requires `super_admin` or `admin`.

```json
{
  "title": "Launch Event",
  "description": "Annual product launch.",
  "place_name": "Main Hall",
  "address": "123 Example Street",
  "latitude": null,
  "longitude": null,
  "starts_at": "2026-01-01T09:00:00Z",
  "ends_at": "2026-01-01T17:00:00Z",
  "timezone": "Asia/Jakarta",
  "floor_width_m": 20,
  "floor_height_m": 20,
  "rssi_threshold_dbm": -75,
  "min_beacons": 2,
  "coverage_radius_m": 9,
  "path_loss_exponent": 2,
  "beacons": [
    {
      "beacon_id": "01a167bc-...",
      "x": 4.5,
      "y": 2,
      "tx_power_override": null
    }
  ]
}
```

**Field notes**

| Field | Notes |
| :-- | :-- |
| `starts_at` / `ends_at` | ISO 8601 timestamps. `ends_at` must be after `starts_at`. Stored in UTC. |
| `timezone` | IANA timezone, e.g. `Asia/Jakarta`. Defaults to `Asia/Jakarta`. |
| `floor_width_m` / `floor_height_m` | Positive metres; default `20` if omitted/non-positive. |
| `rssi_threshold_dbm` | `-120..0`; default `-75` when `0`. |
| `min_beacons` | At least 1; default 1. |
| `coverage_radius_m` | Optional positive number. Enables the centre-circle check only when 3+ anchors exist. |
| `path_loss_exponent` | Positive; default `2.0`. |
| `beacons` | Required, at least 1, unique, active, and inside the floor bounds. |

**Errors**

- `400` no beacons, duplicate beacon, invalid timezone, end before start, invalid threshold/radius, out-of-bounds position, unavailable/inactive beacon;
- `401` missing/invalid token.

### `PUT /events/{id}`

Update an event. Same body as create. Replaces the event’s beacon placements.

### `DELETE /events/{id}`

Soft-delete an event. Past check-ins remain.

```json
{
  "message": "Event deleted"
}
```

### `PUT /events/{id}/beacons`

Replace only the event’s beacon set/placements.

```json
{
  "beacons": [
    {
      "beacon_id": "01a167bc-...",
      "x": 4.5,
      "y": 2,
      "tx_power_override": null
    }
  ]
}
```

---

## Check-in endpoints

### `POST /events/{id}/checkins`

Submit a check-in. Requires role `user`.

This is the core offline-first endpoint. It is **idempotent** on `client_checkin_id`.

**Body**

```json
{
  "client_checkin_id": "1c7e2a3e-4b1d-4f5a-9f4e-2f3a7c8d9e10",
  "recorded_at": "2026-01-01T10:15:00Z",
  "readings": [
    {
      "identity_key": "f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:12",
      "rssi_samples": [-58, -60, -57, -62, -59],
      "tx_power": -59,
      "platform_device_id": "AA:BB:CC:DD:EE:12"
    },
    {
      "identity_key": "f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:13",
      "rssi_samples": [-66, -64, -68, -65],
      "tx_power": -61
    }
  ],
  "device_info": {
    "platform": "android",
    "os_version": "Android 15",
    "app": "beacon-check-in-mobile",
    "simulated": false
  }
}
```

**Accepted response:** `201`

```json
{
  "checkin": {
    "id": "01a167bc-...",
    "client_checkin_id": "1c7e2a3e-...",
    "event_id": "01a167bc-...",
    "user_id": "01a164b6-...",
    "user_name": "Jane Doe",
    "user_email": "jane@example.com",
    "status": "accepted",
    "reject_reason": null,
    "recorded_at": "2026-01-01T10:15:00Z",
    "received_at": "2026-01-01T10:15:04Z",
    "is_offline": false,
    "estimated_x": 6.2,
    "estimated_y": 4.8,
    "accuracy_m": 1.7,
    "used_beacon_count": 2,
    "readings": [
      {
        "beacon_id": "01a167bc-...",
        "identity_key": "f7826da6-...:1:12",
        "matched": true,
        "median_rssi": -59,
        "tx_power": -59,
        "distance_m": 1.0,
        "rssi_samples": [-58, -60, -57, -62, -59],
        "platform_device_id": "AA:BB:CC:DD:EE:12"
      }
    ],
    "device_info": {
      "platform": "android",
      "os_version": "Android 15"
    },
    "created_at": "2026-01-01T10:15:04Z"
  },
  "duplicate": false,
  "observed_beacons": ["f7826da6-...:1:12", "f7826da6-...:1:13"]
}
```

**Rejected response:** `200` (the attempt is stored for audit)

```json
{
  "checkin": {
    "status": "rejected",
    "reject_reason": "not_enough_beacons",
    "...": "..."
  },
  "reason": "not_enough_beacons",
  "observed_beacons": ["f7826da6-...:1:12"]
}
```

**Duplicate response:** `200` with the existing check-in and `"duplicate": true`.

**Error responses**

- `400` invalid event ID, invalid payload, validation failure;
- `401` unauthorized;
- `404` event not found;
- `409` race/duplicate accepted check-in;
- `500` unexpected server error.

### `GET /events/{id}/checkins`

List check-ins for an event. Requires `super_admin` or `admin`.

Query: `status=accepted|rejected|all`, `limit`, `offset`.

### `GET /me/checkins`

List the authenticated user’s check-ins. Any authenticated role.

Query: `status=accepted|rejected|all`, `limit`, `offset`.

---

## Dashboard

### `GET /dashboard/summary`

Requires `super_admin` or `admin`.

```json
{
  "user_counts": {
    "super_admin": 1,
    "admin": 2,
    "user": 8
  },
  "event_counts": {
    "upcoming": 2,
    "ongoing": 1,
    "past": 4
  },
  "active_beacons": 5,
  "deleted_beacons": 1,
  "checkins_today": 14,
  "pending_approvals": 1,
  "recent_checkins": [
    {
      "id": "01a167bc-...",
      "event_id": "01a167bc-...",
      "event_title": "Launch Event",
      "user_name": "Jane Doe",
      "status": "accepted",
      "recorded_at": "2026-01-01T10:15:00Z"
    }
  ]
}
```

---

## Health

### `GET /healthz`

Public health check. Checks the API process and PostgreSQL connectivity.

```json
{
  "status": "up",
  "checks": {
    "database": {
      "status": "up"
    }
  }
}
```

The exact health payload comes from the `alexliesenfeld/health` library.

---

## Check-in rejection reasons

| Code | Meaning |
| :-- | :-- |
| `invalid_recorded_at` | `recorded_at` is too far in the future (`MAX_CLOCK_SKEW`). |
| `checkin_expired` | `recorded_at` is older than `MAX_OFFLINE_AGE` (default 24h). |
| `event_not_started` | Recorded before the event start. |
| `event_ended` | Recorded after the event end. |
| `already_checked_in` | User already has an accepted check-in for this event. |
| `not_enough_beacons` | Fewer than `min_beacons` matched beacons passed the RSSI threshold. |
| `outside_coverage` | Trilaterated position is outside `coverage_radius_m` from the floor centre. |

---

## Configuration that affects the API

| Variable | Default | Effect |
| :-- | :-- | :-- |
| `SERVER_PORT` | `8080` | API port. |
| `DATABASE_URL` | local Postgres | PostgreSQL connection string. |
| `JWT_SECRET_KEY` | — | JWT signing key. |
| `CORS_ORIGINS` | `http://localhost:3000` | Comma-separated allowed web origins. |
| `MAX_OFFLINE_AGE` | `24h` | Maximum allowed age of a queued check-in. |
| `MAX_CLOCK_SKEW` | `5m` | Allowed future clock skew. |
| `RATE_LIMIT_REQUESTS` | see `.env.example` | Rate-limit request count. |
| `RATE_LIMIT_BURST_SIZE` | see `.env.example` | Rate-limit burst size. |

---

## Swagger / OpenAPI

- Interactive docs: `/api-docs`
- Raw spec: `/api/openapi.json`
- Generated source: [`apps/api/docs/swagger.yaml`](../apps/api/docs/swagger.yaml)
- Snapshot: [`docs/swagger.yaml`](./swagger.yaml)
- Regenerate: `moon run api:generate-swagger`

See [`SWAGGER.md`](./SWAGGER.md) for authentication in the UI and regeneration details.
