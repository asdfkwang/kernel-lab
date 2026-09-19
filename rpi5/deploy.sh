#!/usr/bin/env bash
# Publish freshly built Image + DTB into the TFTP directory. Skeleton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

SRC_IMAGE="$KERNEL_OUT_RPI5/arch/arm64/boot/Image"
# TODO: confirm exact DTB source path in current tree.
SRC_DTB="$KERNEL_OUT_RPI5/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"

for f in "$SRC_IMAGE" "$SRC_DTB"; do
    if [[ ! -f "$f" ]]; then
        echo "Missing artifact: $f"
        echo "Build first: ./scripts/build-rpi5-kernel.sh"
        exit 1
    fi
done

mkdir -p "$RPI_TFTP_ROOT"

echo "==> Deploying to $RPI_TFTP_ROOT (atomic rename)"

# TODO: also sync config.txt / cmdline.txt from rpi5/tftp/ if desired.
cp "$SRC_IMAGE" "$RPI_TFTP_ROOT/Image.new"
mv "$RPI_TFTP_ROOT/Image.new" "$RPI_TFTP_ROOT/Image"

cp "$SRC_DTB" "$RPI_TFTP_ROOT/bcm2712-rpi-5-b.dtb.new"
mv "$RPI_TFTP_ROOT/bcm2712-rpi-5-b.dtb.new" "$RPI_TFTP_ROOT/bcm2712-rpi-5-b.dtb"

# TODO: record build identity (e.g. sha256, localversion) for boot verification.
uname_string="$(strings "$SRC_IMAGE" | grep -m1 'Linux version' || true)"
echo "$uname_string" > "$RPI_TFTP_ROOT/expected-version.txt"

echo "Deployed."
