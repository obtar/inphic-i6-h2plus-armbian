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

# Use systemd-networkd for a small Debian image.
NETWORKING_STACK="systemd-networkd"

# Keep first-boot password setup; do not bake a fixed root password into the image.
CONSOLE_AUTOLOGIN="no"

# Do not blacklist Lima globally; leave the mainline GPU driver available.
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
