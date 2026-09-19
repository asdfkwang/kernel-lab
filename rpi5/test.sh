#!/usr/bin/env bash
# Wait for SSH, verify the expected kernel booted, collect KUnit logs. Skeleton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

TARGET="$RPI_SSH_USER@$RPI_SSH_HOST"
BOOT_TIMEOUT="${RPI_BOOT_TIMEOUT:-120}"

echo "==> Waiting for $TARGET (max ${BOOT_TIMEOUT}s)"
deadline=$((SECONDS + BOOT_TIMEOUT))
until ssh -o BatchMode=yes -o ConnectTimeout=2 "$TARGET" true 2>/dev/null; do
    if ((SECONDS >= deadline)); then
        echo "TEST FAILED: Pi did not come back within ${BOOT_TIMEOUT}s"
        exit 1
    fi
    sleep 2
done
echo "Pi is online."

echo "==> Verifying booted kernel"
# TODO: compare against expected-version.txt recorded at deploy time.
# A reachable Pi is NOT enough; SD fallback must be reported as failure.
ssh -o BatchMode=yes "$TARGET" 'uname -a; cat /proc/version'

echo "==> Collecting KUnit results (TODO: parse PASS/FAIL, exit non-zero on failure)"
ssh -o BatchMode=yes "$TARGET" 'dmesg | grep -E -m50 "KTAP|KUnit|^ok|not ok" || true'
