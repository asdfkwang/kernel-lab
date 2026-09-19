#!/usr/bin/env bash
# One-time host setup: export the NFS root used by the Pi. Skeleton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

echo "==> RPi5 host setup (NFS server on the LAN)"
echo "  server IP:  $RPI_SERVER_IP (this PC)"
echo "  NFS root:   $RPI_NFS_ROOT"
echo "  clients:    192.168.0.0/24 (Pi uses LAN DHCP, no fixed IP)"

# TODO (requires root, run manually once):
# 1. Install the NFS server:  apt install nfs-kernel-server
# 2. Populate $RPI_NFS_ROOT (initially: copy of a known-good Pi rootfs).
# 3. Export it to the LAN, e.g. in /etc/exports:
#      /srv/nfs/rpi5-root  192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)
# 4. Apply:  exportfs -ra ; systemctl enable --now nfs-server
# 5. Open the firewall for NFS on the LAN if one is active.
