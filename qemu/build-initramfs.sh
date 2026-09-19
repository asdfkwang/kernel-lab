#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
ROOTFS="$WORK_DIR/rootfs"
EXTRACTED="$WORK_DIR/extracted"
OUTPUT="$SCRIPT_DIR/initramfs.cpio.gz"

BUSYBOX_VERSION="1.37.0-6+b9"
BUSYBOX_DEB="busybox-static_${BUSYBOX_VERSION}_arm64.deb"
BUSYBOX_URL="https://deb.debian.org/debian/pool/main/b/busybox/${BUSYBOX_DEB}"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$ROOTFS"/{bin,sbin,etc,proc,sys,dev,tmp,root}
mkdir -p "$EXTRACTED"

echo "[1/4] Downloading ARM64 BusyBox..."

curl -fL \
    "$BUSYBOX_URL" \
    -o "$WORK_DIR/$BUSYBOX_DEB"

echo "[2/4] Extracting package..."

dpkg-deb -x \
    "$WORK_DIR/$BUSYBOX_DEB" \
    "$EXTRACTED"

BUSYBOX="$EXTRACTED/usr/bin/busybox"

if [[ ! -f "$BUSYBOX" ]]; then
    echo "ERROR: ARM64 BusyBox binary not found:"
    echo "  $BUSYBOX"
    exit 1
fi

cp "$BUSYBOX" "$ROOTFS/bin/busybox"
chmod +x "$ROOTFS/bin/busybox"

echo
echo "BusyBox binary:"
file "$ROOTFS/bin/busybox"
ls -lh "$ROOTFS/bin/busybox"
echo

echo "[3/4] Creating init..."

cat > "$ROOTFS/init" <<'EOF'
#!/bin/busybox sh

/bin/busybox --install -s /bin

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo
echo "================================="
echo " Rust for Linux - QEMU ARM64"
echo "================================="
uname -a
echo

exec /bin/sh
EOF

chmod +x "$ROOTFS/init"

echo "[4/4] Packing initramfs..."

(
    cd "$ROOTFS"

    find . -print0 \
        | cpio --null --create --format=newc 2>/dev/null \
        | gzip -9
) > "$OUTPUT"

echo
echo "Created:"
echo "  $OUTPUT"
echo

echo "Archive contents:"
gzip -dc "$OUTPUT" \
    | cpio -itv 2>/dev/null \
    | grep -E 'init$|bin/busybox$'

echo
ls -lh "$OUTPUT"
