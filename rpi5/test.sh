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
ssh -o BatchMode=yes "$TARGET" 'uname -a; cat /proc/version'

VERSION_FILE="$LAB_ROOT/rpi5/expected-version.txt"
if [[ -f "$VERSION_FILE" ]]; then
    expected_release="$(awk '{print $3}' "$VERSION_FILE")"
    booted_release="$(ssh -o BatchMode=yes "$TARGET" 'uname -r')"
    echo "Expected release: $expected_release"
    echo "Booted release:   $booted_release"
    if [[ "$booted_release" != "$expected_release" ]]; then
        echo "TEST FAILED: Pi is not running the deployed kernel (stale SD boot?)."
        exit 1
    fi
    echo "Kernel version matches deployed build."
else
    echo "No $VERSION_FILE; skipping version check (run rpi5/deploy.sh first)."
fi

echo "==> Collecting KUnit results (TODO: parse PASS/FAIL, exit non-zero on failure)"
ssh -o BatchMode=yes "$TARGET" 'dmesg | grep -E -m50 "KTAP|KUnit|^ok|not ok" || true'
