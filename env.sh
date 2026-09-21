#!/usr/bin/env bash

export KERNEL_TREE="${KERNEL_TREE:-$HOME/Documents/git-repos/linux}"
export KERNEL_OUT="${KERNEL_OUT:-$KERNEL_TREE/out}"

export ARCH="${ARCH:-arm64}"
export LLVM="${LLVM:-1}"

export KERNEL_IMAGE="${KERNEL_IMAGE:-$KERNEL_OUT/arch/arm64/boot/Image}"

export LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Local secrets (gitignored, see env.local.example.sh). Sourced BEFORE
# the defaults below, so precedence is: exported env > env.local.sh > default.
if [[ -f "$LAB_ROOT/env.local.sh" ]]; then
    # shellcheck source=/dev/null
    source "$LAB_ROOT/env.local.sh"
fi

export INITRAMFS="${INITRAMFS:-$LAB_ROOT/qemu/initramfs.cpio.gz}"

# Raspberry Pi 5 LAN settings (see rpi5/README.md).
# Both PC and Pi live on the same LAN. The Pi boots its kernel from SD;
# deployment is scp+ssh (no dedicated link, no dnsmasq, no TFTP).
# Machine-specific values belong in env.local.sh (gitignored);
# the defaults below are fallbacks only.
export RPI_SERVER_IP="${RPI_SERVER_IP:-192.168.0.27}"
export RPI_SSH_HOST="${RPI_SSH_HOST:-raspberrypi.local}"
export RPI_SSH_USER="${RPI_SSH_USER:-pi}"

export RPI_NFS_ROOT="${RPI_NFS_ROOT:-$HOME/nfs/rpi5-root}"

# SD boot partition on the Pi (Pi OS Bookworm; Bullseye and older use /boot).
export RPI_BOOT_DIR="${RPI_BOOT_DIR:-/boot/firmware}"
