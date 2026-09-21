#!/usr/bin/env bash
# Boot a Debian cloud rootfs (arm64) in QEMU virt with our built kernel.
# This is the default QEMU flow. The rootfs disk is never modified in
# place: first run copies the pristine daily image to a working copy.
#
#   ./qemu/run.sh
#   KERNEL_IMAGE=/path/to/Image ./qemu/run.sh   # boot a specific kernel
#   QEMU_APPEND="root=/dev/vda1 console=ttyAMA0" ./qemu/run.sh
#
# For the legacy minimal initramfs flow, see run-initramfs.sh.
#
# Quit QEMU: Ctrl-A, then X.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"

QCOW2_BASE="${DEBIAN_QCOW2_BASE:-$HOME/vm/debian/debian-14-generic-arm64-daily-20260920-2607.qcow2}"
QCOW2_WORK="${DEBIAN_QCOW2_WORK:-$HOME/vm/debian/debian-qemu.qcow2}"
QEMU_APPEND="${QEMU_APPEND:-root=/dev/vda1 console=ttyAMA0}"

if [[ ! -f "$KERNEL_IMAGE" ]]; then
    echo "Kernel image not found: $KERNEL_IMAGE"
    echo "Build first: ./scripts/build-kernel.sh"
    exit 1
fi

if [[ ! -f "$QCOW2_WORK" ]]; then
    if [[ ! -f "$QCOW2_BASE" ]]; then
        echo "Base image not found: $QCOW2_BASE"
        echo "See qemu/README.md for the download URL."
        exit 1
    fi
    echo "Creating working copy: $QCOW2_WORK"
    cp "$QCOW2_BASE" "$QCOW2_WORK"
fi

echo "Kernel: $KERNEL_IMAGE"
echo "Disk:   $QCOW2_WORK"

exec qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -smp 2 \
    -m 2048 \
    -nographic \
    -kernel "$KERNEL_IMAGE" \
    -drive "file=$QCOW2_WORK,format=qcow2,if=virtio" \
    -net nic,model=virtio-net-pci \
    -net user \
    -append "$QEMU_APPEND"
