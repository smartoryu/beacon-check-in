#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-env.sh
source "$SCRIPT_DIR/load-env.sh"

cd "$MOBILE_ROOT"

flutter pub get
exec flutter run --dart-define-from-file="$ENV_FILE" "$@"
