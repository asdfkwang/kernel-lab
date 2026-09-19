#!/usr/bin/env bash
# Full inner loop: build -> deploy -> reboot -> test. Skeleton.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[BUILD] Building ARM64 Raspberry Pi kernel..."
"$SCRIPT_DIR/../scripts/build-rpi5-kernel.sh"

echo "[DEPLOY] Publishing Image + DTB..."
"$SCRIPT_DIR/deploy.sh"

echo "[BOOT] Rebooting Raspberry Pi 5..."
"$SCRIPT_DIR/reboot.sh"

echo "[TEST] Waiting, verifying, collecting KUnit..."
"$SCRIPT_DIR/test.sh"
