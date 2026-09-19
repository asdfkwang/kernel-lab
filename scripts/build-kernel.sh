#!/usr/bin/env bash
# Build the unified ARM64 Rust kernel: one Image boots both
# QEMU virt (initramfs) and Raspberry Pi 5 (NFS root).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

CONFIG_FRAGMENT="$LAB_ROOT/configs/arm64-rust-minimal.config"
KERNEL_IMAGE="$KERNEL_OUT/arch/arm64/boot/Image"
DTB="$KERNEL_OUT/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"

echo "==> Configuring unified ARM64 Rust kernel (defconfig + fragment)"

mkdir -p "$KERNEL_OUT"

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    defconfig

(
    cd "$KERNEL_TREE"

    ARCH="$ARCH" LLVM="$LLVM" \
        scripts/kconfig/merge_config.sh \
        -O "$KERNEL_OUT" \
        "$KERNEL_OUT/.config" \
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
echo "  $DTB"
