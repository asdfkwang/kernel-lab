#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"

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
    -append "console=ttyAMA0 rdinit=/init panic=-1"
