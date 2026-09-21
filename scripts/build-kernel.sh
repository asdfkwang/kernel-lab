#!/usr/bin/env bash
# Build the ARM64 kernel: defconfig + fragment (Rust/KUnit minimal).
#
# Override the fragment with KERNEL_FRAGMENT (empty = plain defconfig):
#   KERNEL_FRAGMENT="" ./scripts/build-kernel.sh
#   KERNEL_FRAGMENT=configs/other.config ./scripts/build-kernel.sh
#
# The same Image boots QEMU virt (initramfs) and Raspberry Pi 5.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

CONFIG_FRAGMENT="${KERNEL_FRAGMENT-$LAB_ROOT/configs/arm64-rust-minimal.config}"
KERNEL_IMAGE="$KERNEL_OUT/arch/arm64/boot/Image"
DTB="$KERNEL_OUT/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb"

echo "==> Configuring ARM64 kernel (defconfig${CONFIG_FRAGMENT:+ + fragment})"

mkdir -p "$KERNEL_OUT"

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    defconfig

if [[ -n "$CONFIG_FRAGMENT" ]]; then
    [[ "$CONFIG_FRAGMENT" = /* ]] || CONFIG_FRAGMENT="$LAB_ROOT/$CONFIG_FRAGMENT"
    (
        cd "$KERNEL_TREE"

        ARCH="$ARCH" LLVM="$LLVM" \
            scripts/kconfig/merge_config.sh \
            -O "$KERNEL_OUT" \
            "$KERNEL_OUT/.config" \
            "$CONFIG_FRAGMENT"
    )
else
    echo "(plain defconfig, no fragment merged)"
fi

echo "==> Building Image + dtbs + modules"

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    -j"$(nproc)" \
    Image dtbs modules

echo "==> Installing modules into $RPI_NFS_ROOT (no sudo needed)"

mkdir -p "$RPI_NFS_ROOT"

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    INSTALL_MOD_PATH="$RPI_NFS_ROOT" \
    INSTALL_MOD_STRIP=1 \
    modules_install

echo
echo "Built:"
echo "  $KERNEL_IMAGE"
echo "  $DTB"
ls -lh "$KERNEL_IMAGE"
