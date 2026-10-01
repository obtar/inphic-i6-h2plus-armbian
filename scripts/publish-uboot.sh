#!/bin/bash
set -euo pipefail

BUILD_DIR="${1:?build directory required}"
IMAGE_DIR="${BUILD_DIR}/output/images"
mkdir -p "${IMAGE_DIR}"

UBOOT_SRC="$(
  find "${BUILD_DIR}/cache/sources/u-boot-worktree" \
       "${BUILD_DIR}/cache/sources/u-boot" \
       "${BUILD_DIR}/output" \
       -type f -name 'u-boot-sunxi-with-spl.bin' \
       -print -quit 2>/dev/null || true
)"

if [[ -z "${UBOOT_SRC}" ]]; then
  echo "ERROR: u-boot-sunxi-with-spl.bin was not found."
  echo "U-Boot candidates:"
  find "${BUILD_DIR}/cache/sources" -type f -iname '*u-boot*sunxi*' -print 2>/dev/null | head -50 || true
  exit 1
fi

echo "U-Boot source: ${UBOOT_SRC}"
install -Dm0644 "${UBOOT_SRC}" "${IMAGE_DIR}/u-boot-sunxi-with-spl.bin"

(
  cd "${IMAGE_DIR}"
  sha256sum * > sha256sums.txt
)

echo "Published files:"
ls -lh "${IMAGE_DIR}"
