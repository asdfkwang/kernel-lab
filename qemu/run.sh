#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_KERNEL_IMAGE="${KERNEL_IMAGE:-}"
source "$SCRIPT_DIR/../env.sh"

# Prefer the QEMU-specific build output (see scripts/build-qemu-kernel.sh)
# unless the user explicitly overrode KERNEL_IMAGE.
QEMU_OUT="${KERNEL_OUT_QEMU:-$KERNEL_TREE/out-qemu}"
QEMU_IMAGE="$QEMU_OUT/arch/arm64/boot/Image"
if [[ -z "$USER_KERNEL_IMAGE" && -f "$QEMU_IMAGE" ]]; then
    KERNEL_IMAGE="$QEMU_IMAGE"
fi

echo "Using kernel image:"
echo "  $KERNEL_IMAGE"

if [[ ! -f "$KERNEL_IMAGE" ]]; then
    echo "Kernel image not found:"
    echo "  $KERNEL_IMAGE"
    exit 1
fi

if [[ ! -f "$INITRAMFS" ]]; then
    echo "Initramfs not found:"
    echo "  $INITRAMFS"
    exit 1
fi

exec qemu-system-aarch64 \
    -machine virt,gic-version=3 \
    -cpu cortex-a72 \
    -smp 4 \
    -m 2048 \
    -nographic \
    -kernel "$KERNEL_IMAGE" \
    -initrd "$INITRAMFS" \
    -append "console=ttyAMA0 rdinit=/init panic=-1 kunit.enable=1 kunit.autorun=1"
