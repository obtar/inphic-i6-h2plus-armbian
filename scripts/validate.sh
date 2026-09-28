#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)

bash -n "$ROOT/userpatches/config-dolphin-p1.conf"
bash -n "$ROOT/userpatches/config/boards/dolphin-p1.csc"

grep -q 'BOARD="dolphin-p1"' "$ROOT/userpatches/config-dolphin-p1.conf"
grep -q 'IMAGE_PARTITION_TABLE="msdos"' "$ROOT/userpatches/config/boards/dolphin-p1.csc"
grep -q 'BOOTFS_TYPE="fat"' "$ROOT/userpatches/config/boards/dolphin-p1.csc"
grep -q 'BOOTSIZE=256' "$ROOT/userpatches/config/boards/dolphin-p1.csc"
grep -q 'CONFIG_DRAM_CLK "576"' "$ROOT/userpatches/config/boards/dolphin-p1.csc"
grep -q 'CONFIG_DRAM_ZQ "3881979"' "$ROOT/userpatches/config/boards/dolphin-p1.csc"
grep -q '^diff --git ' "$ROOT/userpatches/kernel/sunxi-current/0001-dolphin-p1-dts.patch"
grep -q 'sun8i-h2-plus-dolphin-p1.dtb' "$ROOT/userpatches/kernel/sunxi-current/0001-dolphin-p1-dts.patch"

echo 'Dolphin-P1 configuration validation: OK'
