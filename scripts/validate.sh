#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$ROOT/userpatches/kernel/sunxi-current/0001-dolphin-p1-dts.patch"
BOARD="$ROOT/userpatches/config/boards/dolphin-p1.csc"
CONF="$ROOT/userpatches/config-dolphin-p1.conf"
RECOVERY_BOARD="$ROOT/userpatches/config/boards/dolphin-p1-recovery.csc"
RECOVERY_CONF="$ROOT/userpatches/config-dolphin-p1-recovery.conf"

echo "== 1. Files exist =="
for file in "$PATCH" "$BOARD" "$CONF" "$RECOVERY_BOARD" "$RECOVERY_CONF"; do
    test -f "$file"
done

echo "== 2. Shell syntax =="
bash -n "$CONF"
bash -n "$BOARD"
bash -n "$RECOVERY_BOARD"
bash -n "$RECOVERY_CONF"

echo "== 3. Normal board config =="
grep -q 'BOARDFAMILY="sun8i"' "$BOARD"
grep -q 'BOOTCONFIG="libretech_all_h3_cc_h2_plus_defconfig"' "$BOARD"
grep -q 'BOOT_FDT_FILE="allwinner/sun8i-h2-plus-dolphin-p1.dtb"' "$BOARD"
grep -q '^DEFAULT_CONSOLE="serial"$' "$BOARD"
grep -q 'BOOTSIZE=256' "$BOARD"
grep -q 'CONFIG_DRAM_CLK "576"' "$BOARD"
grep -q 'CONFIG_DRAM_ZQ "3881979"' "$BOARD"
grep -q 'CONFIG_MMC_SUNXI_SLOT_EXTRA "2"' "$BOARD"
grep -q 'UBOOT_TARGET_MAP=";;u-boot-sunxi-with-spl.bin"' "$BOARD"
grep -q 'pre_package_uboot_image__dolphin_p1_export_fel_uboot' "$BOARD"

echo "== 4. Recovery U-Boot config =="
grep -q 'BOOTCONFIG="libretech_all_h3_cc_h2_plus_defconfig"' "$RECOVERY_BOARD"
grep -q 'KERNEL_TARGET="current"' "$RECOVERY_BOARD"
grep -q 'UBOOT_TARGET_MAP=";;u-boot-sunxi-with-spl.bin"' "$RECOVERY_BOARD"
grep -q 'CONFIG_DRAM_CLK "576"' "$RECOVERY_BOARD"
grep -q 'CONFIG_DRAM_ZQ "3881979"' "$RECOVERY_BOARD"
grep -q 'CONFIG_MMC_SUNXI_SLOT_EXTRA "2"' "$RECOVERY_BOARD"
grep -q 'CONFIG_BOOTCOMMAND' "$RECOVERY_BOARD"
grep -q 'ums 0 mmc 1' "$RECOVERY_BOARD"

for symbol in \
    CONFIG_USB_MUSB_GADGET \
    CONFIG_PHY_SUN4I_USB \
    CONFIG_USB_MUSB_SUNXI \
    CONFIG_CMD_MMC \
    CONFIG_CMD_GPT \
    CONFIG_CMD_PART \
    CONFIG_CMD_USB \
    CONFIG_CMD_USB_MASS_STORAGE \
    CONFIG_USB_GADGET \
    CONFIG_USB_GADGET_DOWNLOAD \
    CONFIG_USB_FUNCTION_MASS_STORAGE \
    CONFIG_CMD_DFU \
    CONFIG_USB_FUNCTION_DFU \
    CONFIG_DFU_MMC \
    CONFIG_DFU_RAM \
    CONFIG_FASTBOOT \
    CONFIG_USB_FUNCTION_FASTBOOT \
    CONFIG_CMD_FASTBOOT \
    CONFIG_FASTBOOT_FLASH \
    CONFIG_FASTBOOT_FLASH_MMC \
    CONFIG_FASTBOOT_MMC_USER_SUPPORT \
    CONFIG_FASTBOOT_MMC_BOOT_SUPPORT \
    CONFIG_FASTBOOT_FLASH_MMC_DEV \
    CONFIG_FASTBOOT_BUF_ADDR \
    CONFIG_FASTBOOT_BUF_SIZE \
    CONFIG_FASTBOOT_USB_DEV \
    CONFIG_CMD_NET \
    CONFIG_CMD_DHCP \
    CONFIG_CMD_PING \
    CONFIG_CMD_TFTPBOOT \
    CONFIG_CMD_TFTPPUT \
    CONFIG_CMD_WGET \
    CONFIG_CMD_DNS \
    CONFIG_PROT_TCP \
    CONFIG_NETCONSOLE \
    CONFIG_USE_PREBOOT \
    CONFIG_PREBOOT \
    CONFIG_NET_RANDOM_ETHADDR \
    CONFIG_MMC \
    CONFIG_MMC_SUNXI \
    CONFIG_MMC_SUNXI_SLOT_EXTRA \
    CONFIG_NAND_SUNXI \
    CONFIG_CMD_NAND \
    CONFIG_CMD_MTD; do
    grep -q "$symbol" "$RECOVERY_BOARD"
done

grep -q 'CONFIG_FASTBOOT_FLASH_MMC_DEV "1"' "$RECOVERY_BOARD"
grep -q 'CONFIG_FASTBOOT_BUF_ADDR "0x42000000"' "$RECOVERY_BOARD"
grep -q 'CONFIG_FASTBOOT_BUF_SIZE "0x10000000"' "$RECOVERY_BOARD"
grep -q 'CONFIG_FASTBOOT_USB_DEV "0"' "$RECOVERY_BOARD"
grep -q 'u-boot-dolphin-p1-recovery-sunxi-with-spl.bin' "$RECOVERY_BOARD"

echo "== 5. Build config =="
grep -q 'BOARD="dolphin-p1"' "$CONF"
grep -q 'BRANCH="current"' "$CONF"
grep -q 'RELEASE="trixie"' "$CONF"
grep -q 'BOARD="dolphin-p1-recovery"' "$RECOVERY_CONF"
grep -q 'BRANCH="current"' "$RECOVERY_CONF"

echo "== 6. DTS patch sanity =="
head -1 "$PATCH" | grep -q '^From '
grep -q '^diff --git ' "$PATCH"
grep -q 'sun8i-h2-plus-dolphin-p1.dts' "$PATCH"
grep -q 'sun8i-h2-plus-dolphin-p1.dtb' "$PATCH"
grep -q 'bus-width = <8>' "$PATCH"
grep -q 'non-removable' "$PATCH"
grep -q 'cap-mmc-hw-reset' "$PATCH"
grep -q 'phy-mode = "mii"' "$PATCH"
grep -q 'uart0_pa_pins' "$PATCH"
grep -q '&rtc' "$PATCH"
grep -q '&usb_otg' "$PATCH"
grep -q '&ehci1 { status = "okay"; };' "$PATCH"
grep -q '&ohci1 { status = "okay"; };' "$PATCH"
grep -q '&ehci2 { status = "okay"; };' "$PATCH"
grep -q '&ohci2 { status = "okay"; };' "$PATCH"
grep -q '&ehci0 { status = "disabled"; };' "$PATCH"
grep -q '&ohci0 { status = "disabled"; };' "$PATCH"
grep -q '&ehci3 { status = "disabled"; };' "$PATCH"
grep -q '&ohci3 { status = "disabled"; };' "$PATCH"
! grep -q 'reg_vdd_cpux' "$PATCH"
! grep -q 'cpu-supply = <&reg_vdd_cpux>' "$PATCH"

echo "== 7. Makefile continuation sanity =="
ADDED_LINE="$(grep -m1 '^+.*sun8i-h2-plus-dolphin-p1.dtb' "$PATCH" || true)"
test -n "$ADDED_LINE"
if [[ "$ADDED_LINE" != *'\\' ]]; then
    echo "ERROR: added DTB Makefile line has no continuation backslash"
    exit 1
fi
if [[ "$ADDED_LINE" == *'\\\\' ]]; then
    echo "ERROR: doubled backslash in added DTB Makefile line"
    exit 1
fi

echo
echo "Dolphin-P1 static validation: OK"
echo "(Full patch applicability and DTB compilation are verified during CI.)"
