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

for f in "$SRC_IMAGE" "$SRC_DTB"; do
    if [[ ! -f "$f" ]]; then
        echo "Missing artifact: $f"
        echo "Build first: ./scripts/build-kernel.sh"
        exit 1
    fi
done

echo "==> Deploying to $TARGET:$RPI_BOOT_DIR"

scp -o BatchMode=yes "$SRC_IMAGE" "$TARGET:/tmp/Image.new"
scp -o BatchMode=yes "$SRC_DTB" "$TARGET:/tmp/bcm2712-rpi-5-b.dtb.new"

# Back up the running kernel, then atomically switch to the new one.
ssh -o BatchMode=yes "$TARGET" "sudo sh -c '
    set -e
    if [ -f \"$RPI_BOOT_DIR/Image\" ]; then
        cp \"$RPI_BOOT_DIR/Image\" \"$RPI_BOOT_DIR/Image.prev\"
    fi
    if [ -f \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb\" ]; then
        cp \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb\" \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb.prev\"
    fi
    mv /tmp/Image.new \"$RPI_BOOT_DIR/Image\"
    mv /tmp/bcm2712-rpi-5-b.dtb.new \"$RPI_BOOT_DIR/bcm2712-rpi-5-b.dtb\"
'"

uname_string="$(strings "$SRC_IMAGE" | grep -m1 'Linux version' || true)"
echo "$uname_string" > "$VERSION_FILE"

echo "Deployed. Expected: $uname_string"
echo "Reboot the Pi to boot it (config.txt/cmdline.txt are managed separately, see rpi5/boot/)."
