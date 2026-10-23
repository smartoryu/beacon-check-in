#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-env.sh
source "$SCRIPT_DIR/load-env.sh"

cd "$MOBILE_ROOT"

flutter pub get

args=(build apk --release --dart-define-from-file="$ENV_FILE")
if [ -n "${APP_VERSION:-}" ]; then
  args+=(--build-name="$APP_VERSION")
fi
if [ -n "${APP_BUILD_NUMBER:-}" ]; then
  args+=(--build-number="$APP_BUILD_NUMBER")
fi

flutter "${args[@]}"

APK="$MOBILE_ROOT/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK" ]; then
  echo "APK was not produced at $APK" >&2
  exit 1
fi

echo
echo "APK: $APK"
