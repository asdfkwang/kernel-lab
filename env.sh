#!/usr/bin/env bash

export KERNEL_TREE="${KERNEL_TREE:-$HOME/Documents/git-repos/linux}"
export KERNEL_OUT="${KERNEL_OUT:-$KERNEL_TREE/out}"

export ARCH="${ARCH:-arm64}"
export LLVM="${LLVM:-1}"

export KERNEL_IMAGE="${KERNEL_IMAGE:-$KERNEL_OUT/arch/arm64/boot/Image}"

export LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INITRAMFS="${INITRAMFS:-$LAB_ROOT/qemu/initramfs.cpio.gz}"

# Raspberry Pi 5 network-boot settings (see rpi5/README or task doc).
# Interface names and IPs stay configurable; do not hard-code them elsewhere.
export RPI_NET_IFACE="${RPI_NET_IFACE:-}"
export RPI_SERVER_IP="${RPI_SERVER_IP:-192.168.50.1}"
export RPI_IP="${RPI_IP:-192.168.50.10}"
export RPI_SSH_HOST="${RPI_SSH_HOST:-$RPI_IP}"
export RPI_SSH_USER="${RPI_SSH_USER:-pi}"

export RPI_TFTP_ROOT="${RPI_TFTP_ROOT:-/srv/tftp/rpi5}"
export RPI_NFS_ROOT="${RPI_NFS_ROOT:-/srv/nfs/rpi5-root}"

export KERNEL_OUT_RPI5="${KERNEL_OUT_RPI5:-$KERNEL_TREE/out-rpi5}"
