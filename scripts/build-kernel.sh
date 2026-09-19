#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../env.sh"

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    olddefconfig

make \
    -C "$KERNEL_TREE" \
    O="$KERNEL_OUT" \
    ARCH="$ARCH" \
    LLVM="$LLVM" \
    -j"$(nproc)" \
    Image modules
