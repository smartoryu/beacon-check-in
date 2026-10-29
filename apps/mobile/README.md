# Beacon Check-In mobile

Flutter app for Android/iOS. Firebase is used only for **App Distribution** of
pre-release Android APKs; the app does not currently link a Firebase SDK.

## Firebase

| Item | Value |
| :-- | :-- |
| Project | `beacon-check-in-4357e` |
| Android package | `com.myplayground.beacon_check_in` |
| Android app ID | `1:842871360971:android:c771fa381b2bb7bea2fa4e` |

Runtime and distribution configuration lives in `apps/mobile/.env` (gitignored).
Copy `.env.example` for a fresh checkout:

```bash
cp .env.example .env
$EDITOR .env
```

Important values:

```dotenv
API_BASE_URL=https://beacon-check-in-api.playground.my.id/api/v1
FIREBASE_PROJECT_ID=beacon-check-in-4357e
FIREBASE_ANDROID_APP_ID=1:842871360971:android:c771fa381b2bb7bea2fa4e
FIREBASE_API_KEY=...
FIREBASE_MESSAGING_SENDER_ID=842871360971
FIREBASE_STORAGE_BUCKET=beacon-check-in-4357e.firebasestorage.app
FIREBASE_TESTERS=you@example.com
FIREBASE_TESTER_GROUPS=
FIREBASE_SERVICE_ACCOUNT_FILE=
```

`FIREBASE_TESTERS` is a comma-separated list of tester emails. Use
`FIREBASE_TESTER_GROUPS` instead if you created an App Distribution group.
This project already has a group named `testers`:

```bash
firebase appdistribution:testers:add --group-alias testers you@example.com \
  --project beacon-check-in-4357e
```

## Admin event management

Admins can switch between **Beacon Scanner** and **Event Management** with the floating action button. Event Management supports creating/editing events and selecting beacons.

Beacon GPS confirmation requires the selected beacon to be detected by the phone and a GPS position to be available. The location is stored per event + beacon; location changes are appended to an audit history.

## BLE permissions

Android requires both **Nearby devices** and **Location** permission, and Location services must be turned on. The app uses RSSI for position estimation, so the manifest must not use `usesPermissionFlags="neverForLocation"` — Android can filter iBeacon advertisements when that flag is present.

Registered beacons are sorted below new/unregistered devices, and their card title uses the registered label rather than the Bluetooth advertised name.

The scanner banner shows:

```text
N advertisement(s) · M iBeacon(s) · nearest <rssi> dBm
```

- `0 advertisements`: Bluetooth, permission, location or scan problem.
- Advertisements but `0 iBeacon(s)`: the device is not advertising in iBeacon format, or its UUID/major/minor does not match.

On iOS, allow Bluetooth when prompted; location permission is not required for CoreBluetooth scanning.

## Run

```bash
./scripts/run.sh
# or
moon run mobile:dev
```

The script loads `.env`, runs `flutter pub get`, and starts:

```bash
flutter run --dart-define-from-file=.env
```

Override the API without editing `.env`:

```bash
API_BASE_URL=http://localhost:8080/api/v1 ./scripts/run.sh
```

## Build APK

```bash
./scripts/build-apk.sh
# or
moon run mobile:build
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

Optional version override:

```bash
APP_VERSION=1.0.1 APP_BUILD_NUMBER=2 ./scripts/build-apk.sh
```

## Distribute to Firebase App Distribution

Local authentication (recommended for development):

```bash
firebase login
./scripts/distribute.sh
```

The script builds the release APK and uploads it to App Distribution using
`FIREBASE_ANDROID_APP_ID`, then distributes it to `FIREBASE_TESTERS` and/or
`FIREBASE_TESTER_GROUPS`.

For CI/non-interactive use, set a service-account JSON path with the Firebase
App Distribution Admin role:

```dotenv
FIREBASE_SERVICE_ACCOUNT_FILE=/absolute/path/to/service-account.json
```

or use the legacy `FIREBASE_TOKEN` (both are read from `.env`).

Examples:

```bash
APP_BUILD_NUMBER=2 ./scripts/distribute.sh
RELEASE_NOTES="Sprint 4 build" ./scripts/distribute.sh
SKIP_BUILD=1 ./scripts/distribute.sh   # re-upload an existing APK
moon run mobile:distribute
```

## Notes

- `google-services.json` is not needed for App Distribution only, so it is not
  committed. The script and env values are enough for the CLI upload.
- The Android release build currently uses debug signing, suitable for
  pre-release App Distribution. Add a real keystore before Play Store release.
- iOS is not distributed by these scripts.
