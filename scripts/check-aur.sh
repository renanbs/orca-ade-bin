#!/usr/bin/env bash
# Report whether AUR_SSH_PRIVATE_KEY is accepted by the AUR. On success the AUR
# greets and closes the connection, so the exit status is 1 and the message on
# the wire is the only reliable signal.
#
# Usage: check-aur.sh [private-key-file]
# Without an argument the key is written from AUR_SSH_PRIVATE_KEY.
set -euo pipefail

key=${1:-}
if [[ -z $key ]]; then
  if [[ -z ${AUR_SSH_PRIVATE_KEY:-} ]]; then
    echo '::notice::AUR_SSH_PRIVATE_KEY is not set; the AUR push is disabled'
    exit 0
  fi
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  printf '%s\n' "$AUR_SSH_PRIVATE_KEY" >"$tmp/id"
  chmod 600 "$tmp/id"
  key=$tmp/id
fi

greeting=$(ssh -T -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=15 \
  -i "$key" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="${key}.known_hosts" \
  aur@aur.archlinux.org 2>&1 || true)
if [[ $greeting == *'Welcome to AUR'* ]]; then
  printf '%s\n' "$greeting" | grep -m1 'Welcome to AUR'
  exit 0
fi
printf '::error::AUR rejected the private key\n%s\n' "$greeting" >&2
exit 1
