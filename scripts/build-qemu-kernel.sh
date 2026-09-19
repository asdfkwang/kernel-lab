#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

KERNEL_OUT="${KERNEL_OUT_QEMU:-$KERNEL_TREE/out-qemu}"
CONFIG_FRAGMENT="$LAB_ROOT/configs/qemu-arm64-rust.config"
KERNEL_IMAGE="$KERNEL_OUT/arch/arm64/boot/Image"

echo "==> Configuring minimal ARM64 Rust kernel for QEMU"

mkdir -p "$KERNEL_OUT"

(
    cd "$KERNEL_TREE"

    ARCH="$ARCH" LLVM="$LLVM" \
        scripts/kconfig/merge_config.sh \
        -n \
        -O "$KERNEL_OUT" \
        "$CONFIG_FRAGMENT"
)

echo "==> Building Image"

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    -j"$(nproc)" \
    Image

echo
echo "Built:"
echo "  $KERNEL_IMAGE"
