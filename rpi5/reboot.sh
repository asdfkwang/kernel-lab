#!/usr/bin/env bash
# Reboot the Pi after verifying it is the right target. Skeleton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

TARGET="$RPI_SSH_USER@$RPI_SSH_HOST"

echo "==> Verifying target before reboot"
# TODO: compare hostname / machine-id against a stored expected ID.
ssh -o BatchMode=yes -o ConnectTimeout=5 "$TARGET" \
    'hostname; cat /etc/machine-id; uname -m' || {
    echo "Target verification failed; refusing to reboot."
    exit 1
}

echo "==> Rebooting $TARGET"
ssh -o BatchMode=yes "$TARGET" 'sudo reboot' || {
    echo "Reboot command failed."
    exit 1
}
