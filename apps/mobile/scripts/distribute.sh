#!/usr/bin/env bash
#
# Build a release APK and upload it to Firebase App Distribution.
#
# Usage:
#   ./scripts/distribute.sh
#   APP_BUILD_NUMBER=2 ./scripts/distribute.sh
#   RELEASE_NOTES="Sprint 4 build" ./scripts/distribute.sh
#
# Authentication:
#   - Local: `firebase login` is enough.
#   - CI/non-interactive: set FIREBASE_SERVICE_ACCOUNT_FILE to a service-account
#     JSON path with the Firebase App Distribution Admin role, or set
#     FIREBASE_TOKEN (legacy Firebase CLI token).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-env.sh
source "$SCRIPT_DIR/load-env.sh"

: "${FIREBASE_PROJECT_ID:?FIREBASE_PROJECT_ID is required in .env}"
: "${FIREBASE_ANDROID_APP_ID:?FIREBASE_ANDROID_APP_ID is required in .env}"

if [ -n "${FIREBASE_SERVICE_ACCOUNT_FILE:-}" ]; then
  if [ ! -f "$FIREBASE_SERVICE_ACCOUNT_FILE" ]; then
    echo "FIREBASE_SERVICE_ACCOUNT_FILE not found: $FIREBASE_SERVICE_ACCOUNT_FILE" >&2
    exit 1
  fi
  export GOOGLE_APPLICATION_CREDENTIALS="$FIREBASE_SERVICE_ACCOUNT_FILE"
fi

TESTER_EMAILS="${FIREBASE_TESTERS:-}"
TESTER_GROUPS="${FIREBASE_TESTER_GROUPS:-}"
if [ -z "$TESTER_EMAILS" ] && [ -z "$TESTER_GROUPS" ]; then
  echo "Set FIREBASE_TESTERS and/or FIREBASE_TESTER_GROUPS in $ENV_FILE." >&2
  exit 1
fi

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  "$SCRIPT_DIR/build-apk.sh"
fi

APK="$MOBILE_ROOT/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK" ]; then
  echo "Missing $APK. Run ./scripts/build-apk.sh first." >&2
  exit 1
fi
RELEASE_NOTES="${RELEASE_NOTES:-Beacon Check-In pre-release $(date -u +%Y-%m-%dT%H:%M:%SZ)}"

if command -v firebase >/dev/null 2>&1; then
  FIREBASE_CMD=(firebase)
else
  FIREBASE_CMD=(npx --yes firebase-tools)
fi

args=(
  appdistribution:distribute "$APK"
  --app "$FIREBASE_ANDROID_APP_ID"
  --project "$FIREBASE_PROJECT_ID"
  --release-notes "$RELEASE_NOTES"
)

if [ -n "$TESTER_EMAILS" ]; then
  args+=(--testers "$TESTER_EMAILS")
fi
if [ -n "$TESTER_GROUPS" ]; then
  args+=(--groups "$TESTER_GROUPS")
fi

"${FIREBASE_CMD[@]}" "${args[@]}"
