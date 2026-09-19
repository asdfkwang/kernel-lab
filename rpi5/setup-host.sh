#!/usr/bin/env bash
# One-time host setup: dedicated link, dnsmasq (DHCP+TFTP), NFS. Skeleton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$LAB_ROOT/env.sh"

echo "==> RPi5 host setup (skeleton, TODO: fill in after manual proof)"
echo "  iface:      ${RPI_NET_IFACE:-<unset>}"
echo "  server IP:  $RPI_SERVER_IP"
echo "  TFTP root:  $RPI_TFTP_ROOT"
echo "  NFS root:   $RPI_NFS_ROOT"

# TODO:
# 1. Configure $RPI_NET_IFACE with $RPI_SERVER_IP/24 (requires root).
# 2. Install + configure dnsmasq for DHCP/TFTP serving rpi5/tftp/.
# 3. Install + export $RPI_NFS_ROOT via NFS server.
# 4. Verify services; never touch the Pi SD card here.
