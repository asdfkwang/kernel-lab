#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

KERNEL_OUT="$KERNEL_OUT_RPI5"
CONFIG_FRAGMENT="$LAB_ROOT/configs/rpi5-rust.config"
KERNEL_IMAGE="$KERNEL_OUT/arch/arm64/boot/Image"
# TODO: confirm exact DTB path in current tree (bcm2712-rpi-5-b.dtb)
DTB_CANDIDATE="$KERNEL_OUT/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"

echo "==> Configuring ARM64 Rust kernel for Raspberry Pi 5"

mkdir -p "$KERNEL_OUT"

(
    cd "$KERNEL_TREE"

    ARCH="$ARCH" LLVM="$LLVM" \
        scripts/kconfig/merge_config.sh \
        -n \
        -O "$KERNEL_OUT" \
        "$CONFIG_FRAGMENT"
)

echo "==> Building Image + dtbs"

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    -j"$(nproc)" \
    Image dtbs

echo
echo "Built:"
echo "  $KERNEL_IMAGE"
echo "  $DTB_CANDIDATE"
