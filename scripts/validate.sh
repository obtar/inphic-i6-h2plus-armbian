#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PATCH="$ROOT/userpatches/kernel/sunxi-current/0001-dolphin-p1-dts.patch"
BOARD="$ROOT/config/boards/dolphin-p1.csc"
CONF="$ROOT/userpatches/config-dolphin-p1.conf"
RECOVERY_BOARD="$ROOT/config/boards/dolphin-p1-recovery.csc"
RECOVERY_CONF="$ROOT/userpatches/config-dolphin-p1-recovery.conf"

echo "== 1. Files exist =="
test -f "$PATCH"
test -f "$BOARD"
test -f "$CONF"
test -f "$RECOVERY_BOARD"
test -f "$RECOVERY_CONF"

echo "== 2. Shell syntax =="
bash -n "$CONF"
bash -n "$BOARD"
bash -n "$RECOVERY_BOARD"
bash -n "$RECOVERY_CONF"

echo "== 3. Board config sanity =="
grep -q 'BOARDFAMILY="sun8i"' "$BOARD"
grep -q 'BOOTCONFIG="libretech_all_h3_cc_h2_plus_defconfig"' "$BOARD"
grep -q 'BOOT_FDT_FILE="allwinner/sun8i-h2-plus-dolphin-p1.dtb"' "$BOARD"
grep -q 'IMAGE_PARTITION_TABLE="msdos"' "$BOARD"
grep -q 'BOOTFS_TYPE="fat"' "$BOARD"
grep -q 'BOOTSIZE=256' "$BOARD"
grep -q 'CONFIG_DRAM_CLK "576"' "$BOARD"
grep -q 'CONFIG_DRAM_ZQ "3881979"' "$BOARD"
grep -q 'CONFIG_MMC_SUNXI_SLOT_EXTRA "2"' "$BOARD"
grep -q 'UBOOT_TARGET_MAP=";;u-boot-sunxi-with-spl.bin"' "$BOARD"
grep -q 'pre_package_uboot_image__dolphin_p1_export_fel_uboot' "$BOARD"
grep -q 'u-boot-sunxi-with-spl.bin' "$BOARD"

echo "== 4. Recovery U-Boot config sanity =="
grep -q 'BOARD="dolphin-p1-recovery"' "$RECOVERY_CONF"
grep -q 'BRANCH="current"' "$RECOVERY_CONF"
grep -q 'BOOTCONFIG="libretech_all_h3_cc_h2_plus_defconfig"' "$RECOVERY_BOARD"
grep -q 'KERNEL_TARGET="current"' "$RECOVERY_BOARD"
grep -q 'UBOOT_TARGET_MAP=";;u-boot-sunxi-with-spl.bin"' "$RECOVERY_BOARD"
grep -q 'CONFIG_DRAM_CLK "576"' "$RECOVERY_BOARD"
grep -q 'CONFIG_DRAM_ZQ "3881979"' "$RECOVERY_BOARD"
grep -q 'CONFIG_MMC_SUNXI_SLOT_EXTRA "2"' "$RECOVERY_BOARD"
for symbol in \
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
    CONFIG_CMD_NET \
    CONFIG_CMD_DHCP \
    CONFIG_CMD_PING \
    CONFIG_CMD_TFTPBOOT \
    CONFIG_CMD_WGET \
    CONFIG_CMD_DNS \
    CONFIG_PROT_TCP \
    CONFIG_LED \
    CONFIG_LED_GPIO; do
    grep -q "$symbol" "$RECOVERY_BOARD"
done
grep -q 'CONFIG_FASTBOOT_FLASH_MMC_DEV "1"' "$RECOVERY_BOARD"
grep -q 'u-boot-dolphin-p1-recovery-sunxi-with-spl.bin' "$RECOVERY_BOARD"

echo "== 5. Build config sanity =="
grep -q 'BOARD="dolphin-p1"' "$CONF"
grep -q 'BRANCH="current"' "$CONF"
grep -q 'RELEASE="trixie"' "$CONF"

echo "== 6. Patch header/path sanity =="
head -1 "$PATCH" | grep -q '^From '
grep -q '^diff --git ' "$PATCH"
grep -q 'sun8i-h2-plus-dolphin-p1.dts' "$PATCH"
grep -q 'sun8i-h2-plus-dolphin-p1.dtb' "$PATCH"

echo "== 7. DTS content sanity =="
grep -q 'bus-width = <8>' "$PATCH"
grep -q 'non-removable' "$PATCH"
grep -q 'cap-mmc-hw-reset' "$PATCH"
grep -q 'phy-mode = "mii"' "$PATCH"
grep -q 'uart0_pa_pins' "$PATCH"
grep -q 'gpios = <&pio 0 15 GPIO_ACTIVE_LOW>' "$PATCH"
grep -q '&rtc' "$PATCH"
grep -q 'status = "disabled"' "$PATCH"
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

echo "== 8. Makefile continuation sanity =="
ADDED_LINE="$(grep -m1 '^+.*sun8i-h2-plus-dolphin-p1\.dtb' "$PATCH" || true)"
test -n "$ADDED_LINE"
TRAILING_BS=0
[[ "${ADDED_LINE: -1}" == "\" ]] && TRAILING_BS=1
[[ "${ADDED_LINE: -2:1}" == "\" ]] && TRAILING_BS=2
if [ "$TRAILING_BS" -eq 1 ]; then
    echo "OK: added Makefile line ends with one backslash"
elif [ "$TRAILING_BS" -eq 2 ]; then
    echo "ERROR: doubled backslash in added Makefile line"
    exit 1
else
    echo "ERROR: added Makefile line has no continuation backslash"
    exit 1
fi

for name in 'dtb-$(CONFIG_MACH_SUN8I_H3) +=' 'sun8i-h2-plus-libretech-all-h3-cc.dtb' 'sun8i-h2-plus-orangepi-r1.dtb' 'sun8i-h2-plus-orangepi-zero.dtb'; do
    line="$(grep -m1 -F "$name" "$PATCH" || true)"
    test -n "$line"
done

echo
echo "Dolphin-P1 static validation: OK"
echo "(Full patch applicability and DTB compilation are verified during CI.)"
