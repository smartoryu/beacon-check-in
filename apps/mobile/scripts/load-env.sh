#!/usr/bin/env bash
# Shared env loader for the mobile scripts. Source this file, do not execute it.
#
#   ENV_FILE=/path/to/.env ./scripts/run.sh
#
# The default is apps/mobile/.env. Values already exported in the shell take
# precedence over the file, so scripts can be overridden per invocation:
#   APP_BUILD_NUMBER=2 ./scripts/distribute.sh

set -euo pipefail

MOBILE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$MOBILE_ROOT/.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE" >&2
  echo "Copy apps/mobile/.env.example to apps/mobile/.env and fill it in." >&2
  exit 1
fi

while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in
    ''|\#*) continue ;;
  esac
  if [[ "$line" != *=* ]]; then
    continue
  fi
  key="${line%%=*}"
  value="${line#*=}"
  value="${value%\"}"; value="${value#\"}"
  value="${value%\'}"; value="${value#\'}"
  if [ -z "${!key+x}" ]; then
    export "$key=$value"
  fi
done < "$ENV_FILE"

if [ -z "${API_BASE_URL:-}" ]; then
  echo "API_BASE_URL is required in $ENV_FILE" >&2
  exit 1
fi

export MOBILE_ROOT ENV_FILE
