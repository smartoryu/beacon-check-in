# Beacon Check-In — Complete Guide

Beacon Check-In is an **iBeacon attendance system**. It answers one simple question:

> “Was this person physically inside the event area at the right time?”

It does that with three applications and one shared API:

| Part | Who uses it | What it does |
| :-- | :-- | :-- |
| **Web admin console** | Super admins and admins | Create events, place beacons on a floor plan, manage accounts, review approvals, inspect check-ins and triangulation results. |
| **Mobile app** | Users, admins, super admins | Users check in by scanning nearby beacons. Admins register physical beacons by scanning Bluetooth advertisements. |
| **API** | Web and mobile | Authentication, permissions, event/beacon validation, check-in validation, reporting, and all business rules. |
| **PostgreSQL** | API | Stores users, beacons, events, placements, check-ins, approvals and sessions. |

This document explains the system in plain language first, then goes deeper into each feature and its settings. The API reference is in [`API.md`](./API.md), and the interactive Swagger/OpenAPI documentation is described in [`SWAGGER.md`](./SWAGGER.md).

---

## Table of contents

1. [The 30-second explanation](#the-30-second-explanation)
2. [Technical jargon, translated](#technical-jargon-translated)
3. [How the pieces fit together](#how-the-pieces-fit-together)
4. [Roles and permissions](#roles-and-permissions)
5. [Core concepts](#core-concepts)
6. [Web admin console](#web-admin-console)
7. [Creating and editing an event](#creating-and-editing-an-event)
8. [Mobile app](#mobile-app)
9. [Check-in rules in detail](#check-in-rules-in-detail)
10. [Position estimation and the triangulation graph](#position-estimation-and-the-triangulation-graph)
11. [Data model](#data-model)
12. [Deployment and operations](#deployment-and-operations)
13. [Troubleshooting](#troubleshooting)
14. [Limitations and security notes](#limitations-and-security-notes)
15. [Documentation index](#documentation-index)

---

## The 30-second explanation

1. An **admin registers a beacon** with the mobile app. A beacon is a small Bluetooth device that constantly broadcasts an ID.
2. The admin **creates an event** on the web console and places the registered beacons on a 2D floor plan.
3. A **user opens the mobile app** during the event and taps **Check in**.
4. The phone listens for the event’s beacons for **8 seconds** and records how strong each signal is.
5. The phone **saves the check-in locally first**, even if there is no internet.
6. When the phone is online, the app sends the reading to the API.
7. The API checks the time, the beacons, the signal strength, the minimum beacon count and the optional coverage radius. It stores the result as **accepted** or **rejected**.
8. The web console shows the result, including an approximate position on the floor plan when there are enough positioned beacons.

The important idea: **the phone records the check-in first, and the server validates it later.** That is why a check-in can still succeed when the user has no signal during the event.

---

## Technical jargon, translated

| Term | Plain-English meaning | Where you see it |
| :-- | :-- | :-- |
| **API** | The “back office” program the web and mobile apps talk to. It stores and checks data. | Every screen that loads or saves data. |
| **Endpoint** | One specific operation on the API, such as “create an event” or “list beacons”. | `POST /api/v1/events`, `GET /api/v1/beacons`. |
| **iBeacon** | A standard way for a small Bluetooth device to broadcast a fixed identity. | Beacon registration and check-in scanning. |
| **BLE** | Bluetooth Low Energy. The low-power Bluetooth used by beacons and phones. | Mobile scanner, permissions, Bluetooth status banner. |
| **Advertisement** | The short radio message a beacon repeatedly broadcasts. It contains the beacon’s identity and signal calibration. | Scanner “Captured advertisement”. |
| **Proximity UUID** | The large ID that identifies a group of beacons (for example, all beacons belonging to one organization). | Beacon identity, scanner. |
| **Major / minor** | Two smaller numbers that distinguish individual beacons inside the same UUID group. | Beacon identity. |
| **Identity key** | This app’s shorthand for a beacon: `UUID:major:minor`. | Beacon tables, check-in readings, event placement. |
| **RSSI** | Received Signal Strength Indicator. A number showing how strong the beacon’s signal is at the phone. | Check-in readings, scanner cards. |
| **dBm** | The unit used for RSSI and TX power. It is negative. **Closer to 0 means a stronger signal.** `-50 dBm` is strong; `-90 dBm` is weak. | RSSI threshold, TX power. |
| **TX power / measured power** | The signal strength the beacon is expected to produce at **1 metre**. It is used to estimate distance. | Beacon registration, event distance calculation. |
| **Path-loss exponent** | A number describing how quickly the signal fades through the environment. Open space is around `2`; indoor obstacles usually need `2.5–3.5`. | Event **Coverage & floor** section. |
| **Trilateration** | Estimating a position by combining distances from several known points. Similar to “triangulation”, but based on distances rather than angles. | Event detail **Triangulation** card. |
| **Weighted centroid** | A simpler position estimate: the average of beacon positions, weighted by distance. Used when there are only 1–2 usable beacons. | Triangulation fallback. |
| **Accuracy** | The estimated error of the position in metres. Lower is better. | Triangulation graph. |
| **Floor plan / floor grid** | A rectangular coordinate system representing the event area. The top-left corner is `(0, 0)`. | Event form and event detail. |
| **Coverage radius** | An optional circle around the centre of the floor. If set, an estimated position outside the circle is rejected. | Event **Coverage & floor** section. |
| **Event window** | The `starts_at` to `ends_at` period during which a check-in is allowed. | Event form, check-in validation. |
| **Offline-first** | The app saves the action locally first, then syncs later. It does not wait for the network. | Check-in queue, history, sync chip. |
| **Queue** | A local list of check-ins waiting to be sent to the server. | Profile / History “Queued check-ins”. |
| **Idempotency** | Sending the same request twice has the same effect as sending it once. | `client_checkin_id` prevents duplicate check-ins after retries. |
| **JWT** | JSON Web Token. A signed digital pass that proves who the user is. | Bearer token in API requests. |
| **Access token** | A short-lived JWT used to call the API. | Web/mobile authentication. |
| **Refresh token** | A longer-lived token used to get a new access token without signing in again. | Session refresh. |
| **Soft delete** | Marking a record as deleted instead of physically removing it. Past check-ins and history remain intact. | Beacons and events. |
| **Approval request** | A formal request from an admin that a super admin must approve or reject. | Delete/restore beacon flow. |
| **GATT** | A Bluetooth protocol for reading extra device information, such as battery level and manufacturer details. | Mobile scanner “Read GATT details”. |
| **CORS** | A browser security rule that decides which web domains may call the API. | Web login/API errors. |
| **SPA** | Single-Page Application. The web console is one page that updates without full page reloads. | `apps/web`. |
| **UTC / timezone** | UTC is the universal time standard. The event timezone controls how times are displayed and entered. | Event form. |
| **UUID** | A long unique identifier, for example `f7826da6-4fa2-4e98-8024-bc5b71e0893e`. | IDs throughout the system. |

---

## How the pieces fit together

```text
┌──────────────────────┐          ┌──────────────────────┐
│  Mobile app          │          │  Web admin console   │
│  Flutter             │          │  React Router + Vite │
│                      │          │                      │
│  • User check-in     │          │  • Events            │
│  • Beacon scanner    │          │  • Floor placement   │
│  • Offline queue     │          │  • Beacons           │
│  • History           │          │  • Approvals         │
└──────────┬───────────┘          └──────────┬───────────┘
           │ HTTPS / JSON                     │ HTTPS / JSON
           └────────────────┬─────────────────┘
                            ▼
                 ┌─────────────────────┐
                 │  Go API             │
                 │  /api/v1            │
                 │                     │
                 │  Auth + roles       │
                 │  Beacon rules       │
                 │  Event rules        │
                 │  Check-in validation│
                 │  Trilateration      │
                 │  Dashboard          │
                 └──────────┬──────────┘
                            ▼
                 ┌─────────────────────┐
                 │  PostgreSQL         │
                 │  (Supabase in prod) │
                 └─────────────────────┘

Physical world:
  Beacon  ── Bluetooth advertisement ──▶  Phone
```

The web app never talks to Bluetooth. It only manages data and displays results.
The mobile app never decides whether a check-in is valid. It records evidence; the API makes the final decision.

---

## Roles and permissions

There are three roles:

| Role | Typical person | Main abilities |
| :-- | :-- | :-- |
| `super_admin` | System owner / organizer lead | Everything: manage admins, approve beacon changes, create events, place beacons, inspect all check-ins. |
| `admin` | Event staff | Create events, place beacons, register beacons from mobile, rename beacons, request beacon deletion/restoration. Cannot manage admins or approve requests. |
| `user` | Attendee | Register/sign in, view events, check in, view personal history. |

Permission matrix:

| Action | super_admin | admin | user |
| :-- | :--: | :--: | :--: |
| Create/edit/delete admins | ✓ | ✗ | ✗ |
| Reset an admin password | ✓ | ✗ | ✗ |
| Directly delete/restore a beacon | ✓ | ✗ | ✗ |
| Request beacon delete/restore | ✓ | ✓ | ✗ |
| Approve/reject beacon requests | ✓ | ✗ | ✗ |
| Create/edit/delete events | ✓ | ✓ | ✗ |
| Attach beacons and set coordinates | ✓ | ✓ | ✗ |
| Register a beacon from mobile | ✓ | ✓ | ✗ |
| Check in | ✗ | ✗ | ✓ |
| View all users | ✓ | ✓ | ✗ |
| View dashboard | ✓ | ✓ | ✗ |
| View own check-in history | ✓ | ✓ | ✓ |

Admins **cannot delete a beacon directly**. They submit a request with a reason, and a super admin approves or rejects it. This protects shared hardware from accidental removal.

---

## Core concepts

### 1. A beacon has three identity parts

An iBeacon identity is:

```text
proximity_uuid : major : minor
```

Example:

```text
f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:12
```

- The **UUID** groups beacons together.
- **Major** often identifies a venue or floor.
- **Minor** identifies the individual beacon.

The API stores this as `identity_key`. Two beacons with the same UUID/major/minor are considered the same physical beacon, so duplicate registration is rejected.

### 2. Events define where and when

An event has:

- a title, place, address and description;
- a timezone and a start/end time;
- a rectangular floor size;
- an RSSI threshold;
- a minimum number of beacons;
- an optional coverage radius;
- a path-loss exponent;
- one or more attached beacons with `x`/`y` coordinates.

An event is **upcoming**, **ongoing** or **past** based on the current time and its window. A soft-deleted event is hidden from normal lists.

### 3. The floor is a rectangle, not GPS

The floor plan is a simple rectangle measured in metres:

```text
(0,0) ─────────────────▶ X (floor_width_m)
  │
  │        event area
  │
  ▼
  Y (floor_height_m)
```

- `x` is the distance from the left edge.
- `y` is the distance from the top edge.
- Both are in metres.
- Beacon coordinates must stay inside `0..floor_width_m` and `0..floor_height_m`.
- The event detail page snaps drag movements to **0.5 m**. Hold **Shift** while using arrow keys for 2 m steps.

This lets the system draw a map and estimate a check-in position without GPS, which is useful indoors.

### 4. Check-ins are evidence, not just a button tap

A check-in contains:

- who checked in;
- which event;
- the device’s `recorded_at` time;
- the beacon identities the phone heard;
- several RSSI samples per beacon;
- optional device information.

The server keeps both **accepted** and **rejected** attempts. Rejected attempts are useful for debugging: they show whether the user was too far away, heard too few beacons, used the wrong event, or checked in outside the event window.

### 5. Offline-first means “record now, sync later”

When the user taps **Record check-in**:

1. The app immediately writes the attempt to a local Hive queue.
2. The UI says the check-in is recorded.
3. A sync worker tries to send it.
4. If the network is unavailable, the item stays queued and is retried with exponential backoff.
5. The server uses `client_checkin_id` to recognise retries, so a retry does not create a duplicate check-in.

The queue retries after approximately:

```text
5 seconds → 15 seconds → 1 minute → 5 minutes → 30 minutes
```

It also tries when the app launches, resumes, regains connectivity, signs in, refreshes the session, or when the user taps **Sync now**.

### 6. Approval protects shared hardware

Beacon deletion is a **soft delete**:

- The record stays in the database.
- It disappears from active lists.
- Past event placements still reference it.
- A deleted beacon can be restored.

Admins request the change with a reason. Super admins approve or reject the request. A beacon that is attached to an ongoing or upcoming event cannot be deleted.

---

## Web admin console

The web app lives at:

- Local: `http://localhost:3000`
- Production: `https://admin-beacon-check-in.playground.my.id`

It is a React Router SPA with Tailwind CSS, light/dark themes and a mobile-friendly layout.

### Sign in

Use the seeded account or the production super admin credentials. After signing in:

- A temporary-password account is redirected to **Change password**.
- A normal account goes to the **Dashboard**.
- The theme toggle is available in the sidebar (desktop), mobile header, login page and change-password page.

Temporary admin passwords are short, easy-to-read phrases, for example:

```text
cobalt-42
```

They contain one word plus a two-digit number and are at most 10 characters long. They are one-time credentials and must be changed at first sign-in.

### Dashboard

The dashboard gives a quick operational snapshot:

- number of users by role;
- number of events by status;
- active and soft-deleted beacons;
- check-ins today;
- pending approval count;
- recent check-ins;
- quick links to create events, manage beacons and review approvals;
- a user list with role, status and join date.

### Admins

Only a super admin can open this page.

**Create admin**

- **Name**: the person’s display name.
- **Email**: the sign-in address. It must be unique.
- The API creates the account and returns a temporary phrase password.
- The phrase is shown once in a modal. Copy it and send it to the admin through a safe channel.
- The new admin must change the password on first sign-in.

**Edit admin**

Changes the display name and email. It does not change the password.

**Reset password**

Generates a new temporary phrase, invalidates the admin’s existing sessions, and forces a password change on next sign-in. Use this when an admin forgets their password.

**Delete admin**

Soft-deletes the admin account and revokes sessions. Historical check-ins remain connected to the stored user record.

### Beacons

Beacons are **registered from the mobile app**, not manually typed into the web app. The web page is for inspection and lifecycle management.

What the table shows:

- **Label**: human-friendly name such as “Lobby North”.
- **Identity**: the UUID:major:minor identity.
- **Local name**: the Bluetooth device name, if advertised.
- **TX power**: the registered/measured signal calibration.
- **Last seen**: last time the scanner saw it.
- **Status**: active or deleted.

Actions:

- **Detail**: inspect the full stored advertisement, metadata, GATT information and timestamps.
- **Rename**: change only the label.
- **Delete**:
  - super admin: deletes directly;
  - admin: submits a request with a reason.
- **Restore**:
  - super admin: restores directly;
  - admin: submits a request with a reason.

Deleting a beacon is blocked while it is attached to an ongoing or upcoming event. This avoids breaking an event that is about to start.

### Approvals

Only a super admin can open this page.

The page has two parts:

1. **Pending requests** — cards showing the beacon, action (delete/restore), requester and reason. Buttons open an approve/reject dialog with an optional review note.
2. **History** — a table of past requests with action, status, requester, reviewer and review time.

Approving a delete applies the soft delete. Approving a restore makes the beacon active again.

### Events

The events page lists events with search and status filters.

Statuses:

- **Upcoming**: `starts_at` is in the future.
- **Ongoing**: now is between `starts_at` and `ends_at`.
- **Past**: `ends_at` is in the past.
- **Deleted**: soft-deleted and hidden from normal lists.

Each event card shows the place, time window, check-in count, beacon count and status. Click an event to open its detail page.

### Event detail

The event detail page contains:

- status, time window and timezone;
- RSSI threshold and minimum beacon count;
- **Beacon placement** grid;
- **Triangulation** card;
- **Check-ins** table with accepted/rejected tabs;
- edit and delete actions.

**Beacon placement**

- Drag a beacon to move it.
- Use arrow keys for fine control.
- Snap is 0.5 m by default.
- Hold Shift with arrow keys for 2 m steps.
- Click **Save layout** to persist changes.

**Triangulation**

- Select an accepted check-in with **View graph**.
- The graph shows the beacon anchors, their estimated distance circles, the estimated position and the accuracy.
- If there are fewer than three usable anchors, the position may be a weighted centroid or missing.

**Check-ins table**

- **User**: name and email.
- **Status**: accepted or rejected.
- **Recorded**: device time, shown in the event timezone.
- **Offline**: whether the server received it more than two minutes after it was recorded.
- **Beacons**: number of matched beacons above the RSSI threshold.
- **Position**: estimated `x, y` in metres.
- **Reason**: rejection reason, if any.
- **View graph**: available for accepted check-ins with a position.

Deleting an event is a soft delete. Check-ins and historical references remain.

---

## Creating and editing an event

Open **Events → Create event** (or **Edit event** on an existing event).

The page has three cards:

1. **Event details**
2. **Coverage & floor**
3. **Beacons**

### Event details

| Field | Plain meaning | Details |
| :-- | :-- | :-- |
| **Title** | The event name people will see. | Required. 1–200 characters. |
| **Place name** | The venue or area name, such as “Main Hall”. | Required. 1–200 characters. |
| **Address** | Optional street address or human-readable location. | Optional. Useful for attendees. |
| **Timezone** | The timezone used to enter and display the event times. | Default `Asia/Jakarta`. Times are stored in UTC and converted for display. |
| **Starts at** | When check-in becomes allowed. | Required. Entered in the selected timezone. |
| **Ends at** | When check-in stops being allowed. | Required. Must be after `Starts at`. |
| **Description** | Optional instructions or context for the event. | Shown in the mobile event detail screen. |

**Important:** the event window is evaluated against the device’s `recorded_at`, not the time the server receives the check-in. This is what allows an offline check-in recorded during the event to be accepted when it syncs later.

**Latitude/longitude:** the API accepts optional `latitude` and `longitude` fields, but the web form currently sends them as `null`. The POC uses the floor grid for positioning, not GPS.

### Coverage & floor

This is the most important section for check-in accuracy. It tells the system what “inside the event” means.

| Field | Plain meaning | Technical detail | Default / range | Advice |
| :-- | :-- | :-- | :-- | :-- |
| **Floor width (m)** | How wide the event area is, left to right. | Defines the X axis of the floor grid. | `20 m`; minimum `1`; step `0.5` | Measure the usable area, not the whole building. |
| **Floor height (m)** | How deep the event area is, top to bottom. | Defines the Y axis of the floor grid. | `20 m`; minimum `1`; step `0.5` | Use the same unit (metres) as the width. |
| **RSSI threshold (dBm)** | How strong a beacon signal must be to count as “heard clearly enough”. | A reading counts only if its median RSSI is **greater than or equal to** this value. Remember: `-60` is stronger than `-80`. | `-75`; allowed `-120..0` | Start around `-75`. Raise it (for example `-65`) to require the user to be closer. Lower it (for example `-85`) if the venue is large or signals are weak. |
| **Minimum beacons** | How many event beacons must pass the RSSI threshold. | Check-in is rejected with `not_enough_beacons` if fewer matched beacons pass. | `1`; must be at least 1 | Use `2` or `3` for stronger proof. If you set it higher than the number of attached beacons, every check-in will fail. |
| **Coverage radius (m)** | Optional circle around the centre of the floor. | Only applies when the server has **3 or more usable anchors**. It trilaterates a position and rejects the check-in with `outside_coverage` if the point is farther than this radius from the floor centre. If the field is empty, there is no circle check. | Empty (disabled); if set, must be positive | Use it to reject positions that are mathematically inside the rectangle but clearly outside the real audience area. Do not set it smaller than the real seating/standing area. |
| **Path-loss exponent** | How quickly the signal weakens with distance in this environment. | Used by the distance formula `d = 10^((txPower − rssi) / (10 × n))`. Higher values make distance grow faster as RSSI drops. | `2.0`; must be positive | `2.0` is free space. Indoor spaces with walls/people often work better around `2.5–3.5`. This affects position estimates, not the RSSI acceptance threshold. |

#### How coverage radius and floor size work together

- The **floor size** only defines the rectangle and validates beacon `x`/`y` positions.
- The **coverage radius** is a separate circular rule, centred on the middle of that rectangle.
- The circle rule is skipped when:
  - no radius is set;
  - fewer than three usable anchors are available (so no trilaterated point exists).
- A check-in can be inside the rectangle but outside the radius, and it will be rejected.

Example:

```text
Floor: 40 m × 30 m
Centre: (20, 15)
Coverage radius: 12 m

A trilaterated point at (20, 15) is accepted.
A point at (35, 15) is 15 m from the centre → rejected as outside_coverage.
```

#### Recommended starting values

| Situation | RSSI threshold | Min beacons | Path-loss | Coverage radius |
| :-- | :-- | :-- | :-- | :-- |
| Small room, 3+ beacons | `-70` to `-75` | `2` | `2.0–2.5` | Optional |
| Large hall, sparse beacons | `-80` to `-85` | `1–2` | `2.5–3.0` | Optional |
| High-confidence attendance | `-65` to `-70` | `3` | `2.0–2.5` | Set to real area radius |

### Beacons

The form lists all **active** registered beacons.

- Tick a beacon to attach it to the event.
- At least one beacon is required.
- When selected, set its `x` and `y` coordinates in metres.
- The coordinates must stay inside the floor width/height.
- The event detail page can fine-tune positions by dragging.
- The same beacon cannot be attached twice.

**Per-beacon TX power override (`tx_power_override`)**

The API supports an optional per-event override for the beacon’s expected signal at 1 metre. This is useful when a beacon’s advertised measured power is inaccurate. The current web form does **not** expose this input; it is available through the API/event beacon payload for advanced tuning.

### Save and validation

The form checks:

- title and place are filled;
- at least one beacon is selected;
- the event has a valid timezone;
- `ends_at` is after `starts_at`;
- the RSSI threshold is between `-120` and `0`;
- the coverage radius is positive if set;
- every beacon position is inside the floor;
- no beacon is duplicated;
- all selected beacons are active.

On success, the web app opens the event detail page.

---

## Mobile app

The Flutter app is in `apps/mobile`. It supports two experiences based on the signed-in user’s role.

### User experience

Bottom navigation: **Events**, **History**, **Profile**.

**Events**

- Shows ongoing, upcoming and recent events.
- If offline, shows cached events with an “Offline — showing cached events” notice.
- Tap an event to open its detail.

**Event detail**

- Title, place, address and description.
- Event status badge.
- List of event beacons with their floor coordinates.
- **Check in** button. It is disabled when the event is not ongoing.
- If the event is not ongoing, the button explains that check-in opens during the event.

**Check-in flow**

1. Tap **Check in**.
2. The app scans for the event’s beacon identities for **8 seconds**.
3. It keeps multiple RSSI samples per beacon and shows the median RSSI, sample count and measured power at 1 m.
4. Tap **Record check-in**.
5. The check-in is written to the local Hive queue immediately.
6. A confirmation dialog appears: **Check-in recorded**. The server result appears in History after sync.
7. The sync worker sends it when online.

**History**

- Shows local queued check-ins and server check-ins.
- Status chips: pending, syncing, synced, rejected, failed.
- Shows event name, recorded time, reason and number of readings.
- **Sync now** button forces a sync attempt.
- Queued items are visible even without internet.

**Profile**

- User name, email and role.
- Number of queued check-ins.
- **Sync now**.
- API base URL and debug-scanner status.
- Sign out.

### Admin experience

Bottom navigation: **Scanner**, **Profile**.

**Beacon Scanner**

- Shows a real-time Bluetooth status banner: adapter, permission, scanning and telemetry state.
- Displays discovered beacons with identity, label, RSSI and registration status.
- Each beacon is marked **New**, **Registered** or **Deleted**.
- For a new beacon:
  - enter a **Label**;
  - optionally enable **Read GATT details** to read Device Information (`0x180A`) and battery (`0x180F`);
  - review the captured advertisement;
  - tap **Register beacon**.
- For a deleted beacon, submit a **restore request** with a reason.
- **Refresh registration status** re-checks identities against the API.
- Debug builds have **Add simulated beacon** so the flow can be tested without hardware.

**What gets stored when a beacon is registered**

- iBeacon proximity UUID, major and minor;
- identity key;
- label;
- local Bluetooth name;
- platform device ID / MAC when available;
- device address type;
- measured TX power;
- raw advertisement bytes and manufacturer/service data;
- RSSI samples;
- optional GATT details and read timestamp;
- registration timestamps and the admin who registered it.

**Bluetooth permissions**

The app asks for the permissions required by the platform. If Bluetooth is off or permission is denied, the status banner explains what to do. On iOS, the beacon MAC address is hidden by the operating system; the identity is always UUID + major + minor.

### Offline queue and sync

The sync worker is not a background OS job. It runs while the app is active and on these triggers:

- app launch;
- app resume;
- connectivity restored;
- successful sign-in or token refresh;
- periodic timer every 30 seconds;
- **Sync now** button.

Retry backoff:

```text
attempt 1: 5 seconds
attempt 2: 15 seconds
attempt 3: 1 minute
attempt 4: 5 minutes
attempt 5+: 30 minutes
```

If the API says the check-in is rejected, the item is marked rejected and is not retried. If the API is unreachable or returns a retryable server error, the item stays pending and retries later.

### Debug simulation

Debug builds show:

- **Simulate beacon readings (debug)** on the check-in screen.
- **Add simulated beacon (debug)** on the admin scanner.

The simulated check-in uses the event’s beacons with strong synthetic RSSI values. It is only for development and is marked as simulated in `device_info`.

### Running the mobile app

See [`apps/mobile/README.md`](../apps/mobile/README.md) for Firebase App Distribution, environment variables and scripts.

Quick version:

```bash
cd apps/mobile
cp .env.example .env
./scripts/run.sh
./scripts/build-apk.sh
./scripts/distribute.sh
```

---

## Check-in rules in detail

The API validates a submitted check-in in this order:

1. **Idempotency**
   - `client_checkin_id` is a UUID generated by the mobile app.
   - If that ID already exists, the API returns the existing check-in with `duplicate: true`.
   - This makes network retries safe.

2. **Event exists**
   - The event must exist and not be deleted.

3. **Device time is plausible**
   - `recorded_at` cannot be more than `MAX_CLOCK_SKEW` (default `5m`) in the future.
   - It cannot be more than `MAX_OFFLINE_AGE` (default `24h`) in the past.
   - Rejections: `invalid_recorded_at`, `checkin_expired`.

4. **Event window**
   - `recorded_at` must be between `starts_at` and `ends_at`.
   - Rejections: `event_not_started`, `event_ended`.

5. **One accepted check-in per user/event**
   - A second accepted check-in is rejected with `already_checked_in`.

6. **Beacon matching**
   - Each reading is matched by `identity_key` to the event’s attached beacons.
   - Unknown identities are stored as unmatched readings but do not help acceptance.

7. **Signal strength**
   - The median of each reading’s `rssi_samples` is calculated.
   - A matched beacon counts if `median_rssi >= rssi_threshold_dbm`.
   - The check-in is rejected with `not_enough_beacons` if fewer than `min_beacons` count.

8. **Position and coverage**
   - If a beacon has a usable TX power, the server estimates its distance from RSSI.
   - With 3+ anchors it runs weighted trilateration.
   - With 1–2 anchors it uses a weighted centroid.
   - If `coverage_radius_m` is set and a trilaterated point exists, the distance from the floor centre must be within the radius.
   - Rejection: `outside_coverage`.

9. **Store result**
   - Accepted and rejected attempts are both stored.
   - Accepted attempts may include `estimated_x`, `estimated_y` and `accuracy_m`.

### Rejection reasons

| Reason | Meaning | What to do |
| :-- | :-- | :-- |
| `invalid_recorded_at` | Device clock is too far in the future. | Check phone time / automatic time. |
| `checkin_expired` | Check-in was recorded longer than `MAX_OFFLINE_AGE` ago. | Sync sooner or increase the limit. |
| `event_not_started` | The recorded time is before the event start. | Check the event timezone and start time. |
| `event_ended` | The recorded time is after the event end. | Check the event timezone and end time. |
| `already_checked_in` | The user already has an accepted check-in for this event. | Use history, or investigate duplicate attempts. |
| `not_enough_beacons` | Too few event beacons passed the RSSI threshold. | Move closer to beacons, raise beacon density, lower threshold, or lower `min_beacons`. |
| `outside_coverage` | Trilaterated position is outside the coverage circle. | Move inside the real area, adjust the radius, or verify beacon placement. |

---

## Position estimation and the triangulation graph

The system uses a simple indoor radio model:

```text
distance = 10 ^ ((txPower − rssi) / (10 × pathLossExponent))
```

- `txPower` is the expected RSSI at 1 metre.
- `rssi` is the measured signal strength.
- `pathLossExponent` describes the environment.

The app sends raw RSSI samples. The server takes the **median** to reduce noise.

### Anchors

An anchor is a beacon with:

- a known floor position `(x, y)`;
- a usable TX power;
- an RSSI strong enough to pass the event threshold;
- an estimated distance.

Only matched, positioned beacons with TX power become anchors.

### 3+ anchors: trilateration

The server solves a weighted least-squares problem over the anchor distances. It returns:

- `estimated_x`, `estimated_y`;
- `accuracy_m`, the RMS residual between estimated and measured distances.

If the geometry is degenerate (for example, all beacons in a straight line), it falls back to the weighted centroid.

### 1–2 anchors: weighted centroid

The position is a distance-weighted average of the anchor positions. This is less precise and is mainly useful for a rough location.

### What the graph shows

- beacon anchor points;
- distance circles for each anchor;
- the estimated check-in point;
- the accuracy/residual.

Because RSSI is noisy and indoor radio propagation is complex, the position is an **estimate**, not a precise GPS-like coordinate. Treat it as a debugging and visualisation aid.

---

## Data model

Main tables:

| Table | Purpose |
| :-- | :-- |
| `users` | Accounts, roles, display names, verification and soft-delete state. |
| `user_passwords` | One hashed password per user. |
| `sessions` | Login sessions and device metadata. |
| `refresh_tokens` | Refresh-token records. |
| `one_time_tokens` | Email verification and other one-time flows. |
| `beacons` | Registered physical beacons, identity, advertisement metadata and GATT info. |
| `beacon_change_requests` | Admin requests to delete/restore beacons and super-admin reviews. |
| `events` | Event details, time window, floor size, thresholds and coverage settings. |
| `event_beacons` | Which beacons belong to an event, with `x`/`y` placement and optional TX power override. |
| `checkins` | Accepted/rejected attempts, device time, readings, position estimate and audit data. |
| `checkin_readings` | Per-beacon readings for each check-in. |

Deleting users, beacons and events is usually a **soft delete** (`deleted_at`) so history remains readable.

---

## Deployment and operations

Production architecture:

- **API**: Go binary in Docker on a GCP `e2-micro` VM.
- **Web**: static React build served by nginx in Docker.
- **TLS**: Caddy with Cloudflare DNS-01 certificates.
- **Database**: Supabase PostgreSQL through the session pooler.
- **Registry**: GitHub Container Registry (GHCR).
- **CI/CD**: GitHub Actions workflows for API CI, Web CI, API Release, Web Release, App Deploy and OpenTofu.

Live URLs:

- Web: `https://admin-beacon-check-in.playground.my.id`
- API: `https://beacon-check-in-api.playground.my.id`
- API docs: `https://beacon-check-in-api.playground.my.id/api-docs`
- Raw OpenAPI/Swagger: `https://beacon-check-in-api.playground.my.id/api/openapi.json`

The complete infrastructure runbook is in [`infra/README.md`](../infra/README.md). No credentials are committed. Runtime configuration comes from the server `.env`, GitHub secrets and environment variables.

---

## Troubleshooting

### “I can’t see any beacons while checking in”

1. Confirm Bluetooth is on and permission is granted.
2. **Android:** allow **Location** permission and turn **Location services** on. The app uses RSSI for position estimation, so Android requires location access for BLE scans. The app must not use `neverForLocation`, because Android can filter iBeacon advertisements when that flag is present.
3. Read the scanner banner. It shows `N advertisement(s) · M iBeacon(s) · nearest RSSI`.
   - `0 advertisements`: Bluetooth/permission/location/scan problem.
   - Advertisements but `0 iBeacon(s)`: the device is advertising, but not in the iBeacon format the app understands.
4. Make sure the phone is within a few metres of a beacon.
5. Confirm the beacon is an iBeacon and its UUID/major/minor matches the event beacon.
6. Check that the beacon is attached to the event.
7. Replace the beacon battery if the signal is very weak.
8. Use the debug simulation to verify the app flow without hardware.

### “Check-in rejected: not_enough_beacons”

- Move closer to the beacons.
- Lower `RSSI threshold` (for example `-85` instead of `-70`).
- Lower `Minimum beacons` (but keep it meaningful).
- Add more beacons or reposition them.
- Confirm the event has the correct beacons attached.

### “Check-in rejected: outside_coverage”

- Move toward the centre of the event area.
- Increase the coverage radius if the real area is larger.
- Verify beacon coordinates on the floor plan.
- Remember the radius is measured from the floor centre, not from an arbitrary point.

### “Check-in rejected: event_ended / event_not_started”

- Check the event timezone.
- Check that the phone’s clock is correct.
- Remember the server validates `recorded_at`, not the sync time.

### “The web admin reset password says Admin operation failed”

This was caused by an older API version that tried to insert a second password row. The current API upserts the password. Make sure the production API is on the latest release. If it still happens, check the API logs for the underlying database error.

### “Dark mode is hard to read”

Use the sun/moon toggle in the sidebar, mobile header, login page or change-password page. The choice is stored in the browser and the app follows the OS theme by default.

### “The web app cannot reach the API”

- Check `VITE_API_BASE_URL` in `apps/web/.env`.
- Check the API `CORS_ORIGINS` value. It must be a comma-separated list, not a JSON array.
- For local web on `http://localhost:3000`, the API should allow that origin.

### “The mobile app is still using the wrong API URL”

The app reads `API_BASE_URL` from `apps/mobile/.env` through `--dart-define-from-file`. Re-run:

```bash
cd apps/mobile
./scripts/run.sh
```

You can override without editing the file:

```bash
API_BASE_URL=http://10.0.2.2:8080/api/v1 ./scripts/run.sh
```

### “A queued check-in is stuck”

Open **Profile** or **History** and tap **Sync now**. If the item is rejected, it will not retry. If it is pending, check connectivity and sign-in state. The queue retries with backoff and stops retrying on non-retryable errors.

---

## Limitations and security notes

This is a **POC**, not a hardened attendance product.

- BLE scanning is **foreground-only**. There is no OS background scanning or background sync.
- RSSI is noisy. Position estimates are approximate and should not be treated as precise location tracking.
- The web app stores JWTs in `localStorage` for simplicity. Production should prefer httpOnly cookies or a backend-for-frontend.
- The mobile queue is stored in app-private Hive storage but is not encrypted. Auth tokens use `flutter_secure_storage`.
- iOS hides the beacon MAC address; identity is UUID + major + minor.
- A beacon can be physically cloned or spoofed. Signal strength alone is not cryptographic proof of presence.
- The release APK currently uses debug signing for App Distribution. A real keystore is required before a Play Store release.
- There is no automatic event capacity, seat allocation or ticket integration.
- Email delivery is configured through SMTP; the POC default points to a local Mailpit instance.

For production, consider:

- server-side rate limiting per user/IP;
- signed beacon payloads or rotating identifiers;
- httpOnly session cookies;
- encrypted local storage;
- background sync with platform constraints;
- audit logs for admin actions;
- proper key management and secret rotation.

---

## Documentation index

- [API reference](./API.md) — every endpoint, request/response shape, roles and rejection reasons.
- [Swagger/OpenAPI guide](./SWAGGER.md) — interactive docs, raw spec, regeneration and authentication.
- [Swagger snapshot](./swagger.yaml) — generated OpenAPI/Swagger 2.0 file.
- [Root README](../README.md) — quick start, seeded accounts and commands.
- [API README](../apps/api/README.md) — Go project tasks and migrations.
- [Mobile README](../apps/mobile/README.md) — Flutter env, run/build/distribute scripts.
- [Infrastructure README](../infra/README.md) — production deployment, secrets and OpenTofu.
