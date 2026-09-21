#!/usr/bin/env bash
# Publish freshly built Image + DTB to the Pi's SD boot partition over SSH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

TARGET="$RPI_SSH_USER@$RPI_SSH_HOST"
SRC_IMAGE="$KERNEL_OUT/arch/arm64/boot/Image"
SRC_DTB="$KERNEL_OUT/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"
VERSION_FILE="$LAB_ROOT/rpi5/expected-version.txt"

# DTB is opt-in (default: keep the stock DTB). A wrong DTB bricks remote
# boot just like a wrong Image, and a stock DTB usually boots a new Image
# fine. Trial new DTBs via kexec first (KEXEC_DTB=built), then DEPLOY_DTB=1.
DEPLOY_DTB="${DEPLOY_DTB:-0}"

if [[ ! -f "$SRC_IMAGE" ]]; then
    echo "Missing artifact: $SRC_IMAGE"
    echo "Build first: ./scripts/build-kernel.sh"
    exit 1
fi
if [[ "$DEPLOY_DTB" == "1" && ! -f "$SRC_DTB" ]]; then
    echo "Missing artifact: $SRC_DTB"
    echo "Build first: ./scripts/build-kernel.sh"
    exit 1
fi

echo "==> Deploying to $TARGET:$RPI_BOOT_DIR"

scp -o BatchMode=yes "$SRC_IMAGE" "$TARGET:/tmp/Image.new"
if [[ "$DEPLOY_DTB" == "1" ]]; then
    echo "(including DTB: DEPLOY_DTB=1)"
    scp -o BatchMode=yes "$SRC_DTB" "$TARGET:/tmp/bcm2712-rpi-5-b.dtb.new"
else
    echo "(skipping DTB; stock DTB stays — set DEPLOY_DTB=1 to replace it)"
fi

# Back up the running kernel, then atomically switch to the new one.
# The stock kernel_2712.img / kernel8.img are never touched: removing
# `kernel=Image` from config.txt always boots stock again (see Recovery
# in rpi5/README.md).
ssh -o BatchMode=yes "$TARGET" "sudo -n sh -c '
    set -e
    if [ -f \"$RPI_BOOT_DIR/Image\" ]; then
        cp \"$RPI_BOOT_DIR/Image\" \"$RPI_BOOT_DIR/Image.prev\"
    fi
    mv /tmp/Image.new \"$RPI_BOOT_DIR/Image\"
    if [ \"$DEPLOY_DTB\" = 1 ]; then
        if [ -f \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb\" ]; then
            cp \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb\" \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb.prev\"
        fi
        mv /tmp/bcm2712-rpi-5-b.dtb.new \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb\"
    fi
'"

uname_string="$(strings "$SRC_IMAGE" | grep -m1 'Linux version' || true)"
echo "$uname_string" > "$VERSION_FILE"

echo "Deployed. Expected: $uname_string"
echo "Reboot the Pi to boot it (config.txt/cmdline.txt are managed separately, see rpi5/boot/)."
