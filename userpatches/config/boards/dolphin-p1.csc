# Inphic H202A / Dolphin-P1 - Allwinner H2+
# Clean Debian/Armbian eMMC image; no vendor partition layout.

BOARD_NAME="Dolphin-P1"
BOARD_VENDOR="Inphic"
BOARD_MAINTAINER="community"
INTRODUCED="2026"
BOARDFAMILY="sun8i"

# Mainline U-Boot configuration for H2+ on the LibreTech H3-CC reference.
# The board hook below changes only the DRAM parameters known from the stock firmware.
BOOTCONFIG="libretech_all_h3_cc_h2_plus_defconfig"

# sunxi_common.inc normally supplies this target for sun8i/sunxi boards.
# Keep it explicit so the expected FEL-capable SPL/U-Boot artifact is retained.
UBOOT_TARGET_MAP=";;u-boot-sunxi-with-spl.bin"

# Mainline Linux DTB added by userpatches/kernel/sunxi-current.
BOOT_FDT_FILE="allwinner/sun8i-h2-plus-dolphin-p1.dtb"

# Clean Armbian image layout:
#   p1 = 256 MiB FAT32 /boot
#   p2 = remaining space ext4 /
IMAGE_PARTITION_TABLE="msdos"
BOOTFS_TYPE="fat"
BOOTSIZE=256
BOOT_FS_LABEL="BOOT"
ROOT_FS_LABEL="rootfs"

KERNEL_TARGET="current"
DEFAULT_CONSOLE="current"
SERIALCON="ttyS0"

BUILD_MINIMAL="yes"
BUILD_DESKTOP="no"
INSTALL_HEADERS="no"
EXTRAWIFI="no"
KERNEL_BTF="no"
BOOT_LOGO="no"

# The board has no usable SD card slot in this design; eMMC is MMC2.
# Do not disable the Linux MMC controller here: the DTB does that explicitly.

NETWORKING_STACK="systemd-networkd"
CONSOLE_AUTOLOGIN="no"
MODULES_BLACKLIST="sunxi_cedrus"

# U-Boot DRAM values taken from the reverse-engineered stock H2+ firmware:
#   dram_clk = 576 MHz
#   dram_zq  = 0x3b3bfb = 3881979
function post_config_uboot_target__dolphin_p1_dram() {
    display_alert "$BOARD" "Dolphin-P1 U-Boot DRAM: 576 MHz / ZQ 3881979" "info"
    run_host_command_logged scripts/config --set-val CONFIG_DRAM_CLK "576"
    run_host_command_logged scripts/config --set-val CONFIG_DRAM_ZQ "3881979"
    run_host_command_logged scripts/config --enable CONFIG_DRAM_ODT_EN
    run_host_command_logged scripts/config --set-val CONFIG_MMC_SUNXI_SLOT_EXTRA "2"
}

# Export the exact U-Boot binary produced by this build as a release artifact.
function pre_package_uboot_image__dolphin_p1_export_fel_uboot() {
    local src="${uboottempdir}/usr/lib/${uboot_name}/u-boot-sunxi-with-spl.bin"
    local dst="${SRC}/output/images/u-boot-sunxi-with-spl.bin"

    if [[ ! -f "${src}" ]]; then
        exit_with_error "Dolphin-P1 U-Boot artifact missing" "${src}"
    fi

    mkdir -p "${SRC}/output/images"
    run_host_command_logged install -Dm0644 "${src}" "${dst}"
    display_alert "Dolphin-P1 FEL U-Boot exported" "${dst}" "info"
}
