#!/usr/bin/env bash
#
# Generate a dedicated ed25519 deploy keypair for the API VM.
# The private key is used by GitHub Actions (DEPLOY_SSH_KEY); the public key
# is used by OpenTofu (ssh_public_key) and the VM metadata.
#
# Usage:
#   scripts/generate-deploy-key.sh [path]
#
# Never commit the private key.

set -euo pipefail

KEY_PATH="${1:-$HOME/.ssh/beacon-check-in-deploy}"

if [ -e "$KEY_PATH" ] || [ -e "${KEY_PATH}.pub" ]; then
  echo "Key already exists: $KEY_PATH" >&2
  echo "Remove it first or choose another path." >&2
  exit 1
fi

mkdir -p "$(dirname "$KEY_PATH")"
ssh-keygen -t ed25519 -C "beacon-check-in-deploy" -f "$KEY_PATH" -N ""

echo
echo "Private key (add to GitHub secret DEPLOY_SSH_KEY):"
echo "  $KEY_PATH"
echo
echo "Public key (add to GitHub secret DEPLOY_SSH_PUBLIC_KEY and terraform.tfvars):"
cat "${KEY_PATH}.pub"
