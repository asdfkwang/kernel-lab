#!/usr/bin/env bash

export KERNEL_TREE="${KERNEL_TREE:-$HOME/Documents/git-repos/linux}"
export KERNEL_OUT="${KERNEL_OUT:-$KERNEL_TREE/out}"

export ARCH="${ARCH:-arm64}"
export LLVM="${LLVM:-1}"

export KERNEL_IMAGE="${KERNEL_IMAGE:-$KERNEL_OUT/arch/arm64/boot/Image}"

export LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INITRAMFS="${INITRAMFS:-$LAB_ROOT/qemu/initramfs.cpio.gz}"

# Raspberry Pi 5 LAN settings (see rpi5/README.md).
# Both PC and Pi live on the same LAN: Pi uses LAN DHCP (+ mDNS),
# boots its kernel from SD, and mounts rootfs over NFS from this PC.
# No dedicated link, no dnsmasq, no TFTP.
export RPI_SERVER_IP="${RPI_SERVER_IP:-192.168.0.27}"
export RPI_SSH_HOST="${RPI_SSH_HOST:-raspberrypi.local}"
export RPI_SSH_USER="${RPI_SSH_USER:-pi}"

export RPI_NFS_ROOT="${RPI_NFS_ROOT:-/srv/nfs/rpi5-root}"

# SD boot partition on the Pi (Pi OS Bookworm; Bullseye and older use /boot).
export RPI_BOOT_DIR="${RPI_BOOT_DIR:-/boot/firmware}"
