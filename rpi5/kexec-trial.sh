#!/usr/bin/env bash
# Trial-boot a freshly built Image via kexec WITHOUT touching the SD boot
# partition. Recovery is structural: every reboot (including panic=10
# auto-reboot) lands back on the stock kernel, because config.txt and the
# boot partition are never modified. A failed trial can never brick
# remote access; worst case is a physical power-cycle.
# See "Recovery" in rpi5/README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

TARGET="$RPI_SSH_USER@$RPI_SSH_HOST"
SRC_IMAGE="$KERNEL_OUT/arch/arm64/boot/Image"
SRC_DTB="$KERNEL_OUT/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"
# KEXEC_DTB=stock (default: the Pi's /boot/firmware DTB) or built (scp ours).
DTB_MODE="${KEXEC_DTB:-stock}"
TRIAL_TIMEOUT="${KEXEC_TIMEOUT:-150}"
REMOTE_DIR="/home/$RPI_SSH_USER/kexec-trial"
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"

if [[ ! -f "$SRC_IMAGE" ]]; then
    echo "Missing artifact: $SRC_IMAGE"
    echo "Build first: ./scripts/build-kernel.sh"
    exit 1
fi

BUILT_RELEASE="$(strings "$SRC_IMAGE" | grep -m1 'Linux version' | awk '{print $3}' || true)"
echo "==> Trial: $BUILT_RELEASE (DTB: $DTB_MODE, timeout: ${TRIAL_TIMEOUT}s)"

echo "==> Pushing Image to $TARGET:$REMOTE_DIR/ (boot partition untouched)"
$SSH "$TARGET" "mkdir -p $REMOTE_DIR"
scp -o BatchMode=yes "$SRC_IMAGE" "$TARGET:$REMOTE_DIR/Image"
if [[ "$DTB_MODE" == "built" ]]; then
    if [[ ! -f "$SRC_DTB" ]]; then
        echo "Missing artifact: $SRC_DTB"
        exit 1
    fi
    scp -o BatchMode=yes "$SRC_DTB" "$TARGET:$REMOTE_DIR/rpi5-b.dtb"
    DTB_ARG="$REMOTE_DIR/rpi5-b.dtb"
else
    DTB_ARG="/boot/firmware/bcm2712-rpi-5-b.dtb"
fi

echo "==> kexec -l + kexec -e (connection will drop)"
# panic=10: a panicking trial reboots itself back to stock in 10s.
# \$ and \" below expand on the Pi, not here.
$SSH "$TARGET" "sudo -n /sbin/kexec -l $REMOTE_DIR/Image --dtb=$DTB_ARG --append=\"\$(cat /proc/cmdline) panic=10\" && sudo -n /sbin/kexec -e" || true

echo "==> Waiting for trial kernel (max ${TRIAL_TIMEOUT}s)"
deadline=$((SECONDS + TRIAL_TIMEOUT))
until $SSH "$TARGET" true 2>/dev/null; do
    if ((SECONDS >= deadline)); then
        echo "TRIAL FAILED: Pi did not come back within ${TRIAL_TIMEOUT}s."
        echo "Power-cycle it: the SD is untouched, so it boots stock again."
        exit 1
    fi
    sleep 3
done

BOOTED_RELEASE="$($SSH "$TARGET" 'uname -r')"
echo "Booted release: $BOOTED_RELEASE"
echo "Trial release:  $BUILT_RELEASE"
if [[ "$BOOTED_RELEASE" != "$BUILT_RELEASE" ]]; then
    echo "TRIAL FAILED: trial kernel is not running (still on stock?)."
    echo "If the Pi is unresponsive, power-cycle it — the SD is untouched."
    exit 1
fi
echo "TRIAL PASSED: $BOOTED_RELEASE is running."
echo "Note: reboot/power-cycle returns to stock; commit via deploy.sh + config.txt."
