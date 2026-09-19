#!/usr/bin/env bash

export KERNEL_TREE="${KERNEL_TREE:-$HOME/Documents/git-repos/linux}"
export KERNEL_OUT="${KERNEL_OUT:-$KERNEL_TREE/out}"

export ARCH="${ARCH:-arm64}"
export LLVM="${LLVM:-1}"

export KERNEL_IMAGE="${KERNEL_IMAGE:-$KERNEL_OUT/arch/arm64/boot/Image}"

export LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INITRAMFS="${INITRAMFS:-$LAB_ROOT/qemu/initramfs.cpio.gz}"
