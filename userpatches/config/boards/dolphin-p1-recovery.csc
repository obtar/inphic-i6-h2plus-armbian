# Inphic H202A / Dolphin-P1 - minimal recovery U-Boot
# Scheme 2: standalone recovery bootloader; no Linux/rootfs image is built here.

BOARD_NAME="Dolphin-P1 Recovery U-Boot"
BOARD_VENDOR="Inphic"
BOARD_MAINTAINER="community"
INTRODUCED="2026"
BOARDFAMILY="sun8i"

# Reuse the proven H2+ SPL/U-Boot target and Dolphin-P1 DRAM settings.
BOOTCONFIG="libretech_all_h3_cc_h2_plus_defconfig"
BOOT_FDT_FILE="allwinner/sun8i-h2-plus-dolphin-p1.dtb"
UBOOT_TARGET_MAP=";;u-boot-sunxi-with-spl.bin"
KERNEL_TARGET="current"
BOOTDELAY="0"

# Keep this target bootloader-only. It is not a second Linux board.
BUILD_MINIMAL="yes"
BUILD_DESKTOP="no"
INSTALL_HEADERS="no"
EXTRAWIFI="no"
KERNEL_BTF="no"
BOOT_LOGO="no"

# Dolphin-P1 stock firmware values:
#   dram_clk = 576 MHz
#   dram_zq  = 3881979
function post_config_uboot_target__dolphin_p1_recovery_features() {
    display_alert "$BOARD" "Recovery U-Boot: USB UMS/DFU/Fastboot + network recovery" "info"

    # Keep the known-good board-specific memory/eMMC selection.
    run_host_command_logged scripts/config --set-val CONFIG_DRAM_CLK "576"
    run_host_command_logged scripts/config --set-val CONFIG_DRAM_ZQ "3881979"
    run_host_command_logged scripts/config --enable CONFIG_DRAM_ODT_EN
    run_host_command_logged scripts/config --set-val CONFIG_MMC_SUNXI_SLOT_EXTRA "2"

    # eMMC/raw block access.
    run_host_command_logged scripts/config --enable CONFIG_CMD_MMC
    run_host_command_logged scripts/config --enable CONFIG_CMD_GPT
    run_host_command_logged scripts/config --enable CONFIG_CMD_PART

    # Recovery U-Boot is interactive by default.
    # UMS is enabled but MUST NOT start automatically.
    # With MMC_SUNXI_SLOT_EXTRA=2, the internal eMMC is U-Boot mmc 1.
    run_host_command_logged scripts/config --enable CONFIG_AUTOBOOT
    run_host_command_logged scripts/config --enable CONFIG_USE_BOOTCOMMAND
    run_host_command_logged 'scripts/config --set-str CONFIG_BOOTCOMMAND "echo Recovery U-Boot ready - run: ums 0 mmc 1"'
    run_host_command_logged scripts/config --set-val CONFIG_BOOTDELAY "0"
    run_host_command_logged scripts/config --enable CONFIG_USE_PREBOOT

    # H2+ uses the Allwinner MUSB OTG controller for USB peripheral mode.
    # The base LibreTech defconfig enables EHCI/OHCI host support but not
    # the MUSB gadget backend, so explicitly enable the controller and PHY.
    run_host_command_logged scripts/config --enable CONFIG_USB_MUSB_GADGET
    run_host_command_logged scripts/config --enable CONFIG_PHY_SUN4I_USB
    run_host_command_logged scripts/config --enable CONFIG_USB_MUSB_SUNXI

    # USB host/device framework and USB Mass Storage gadget (UMS).
    run_host_command_logged scripts/config --enable CONFIG_CMD_USB
    run_host_command_logged scripts/config --enable CONFIG_CMD_USB_MASS_STORAGE
    run_host_command_logged scripts/config --enable CONFIG_USB_GADGET
    run_host_command_logged scripts/config --enable CONFIG_USB_GADGET_DOWNLOAD
    run_host_command_logged scripts/config --enable CONFIG_USB_FUNCTION_MASS_STORAGE

    # USB DFU: expose MMC/RAM targets through the standard DFU protocol.
    run_host_command_logged scripts/config --enable CONFIG_CMD_DFU
    run_host_command_logged scripts/config --enable CONFIG_USB_FUNCTION_DFU
    run_host_command_logged scripts/config --enable CONFIG_DFU_MMC
    run_host_command_logged scripts/config --enable CONFIG_DFU_RAM

    # USB Fastboot: useful for partition-oriented recovery.
    run_host_command_logged scripts/config --enable CONFIG_FASTBOOT
    run_host_command_logged scripts/config --enable CONFIG_USB_FUNCTION_FASTBOOT
    run_host_command_logged scripts/config --enable CONFIG_CMD_FASTBOOT
    run_host_command_logged scripts/config --enable CONFIG_FASTBOOT_FLASH
    run_host_command_logged scripts/config --enable CONFIG_FASTBOOT_FLASH_MMC
    run_host_command_logged scripts/config --enable CONFIG_FASTBOOT_MMC_USER_SUPPORT
    run_host_command_logged scripts/config --enable CONFIG_FASTBOOT_MMC_BOOT_SUPPORT
    # Current U-Boot sunxi Kconfig maps MMC_SUNXI_SLOT_EXTRA=2 to Fastboot MMC 1.
    run_host_command_logged scripts/config --set-val CONFIG_FASTBOOT_FLASH_MMC_DEV "1"
    run_host_command_logged scripts/config --set-val CONFIG_FASTBOOT_BUF_ADDR "0x42000000"
    run_host_command_logged scripts/config --set-val CONFIG_FASTBOOT_BUF_SIZE "0x10000000"
    run_host_command_logged scripts/config --set-val CONFIG_FASTBOOT_USB_DEV "0"

    # Ethernet/network recovery.
    run_host_command_logged scripts/config --enable CONFIG_CMD_NET
    run_host_command_logged scripts/config --enable CONFIG_CMD_DHCP
    run_host_command_logged scripts/config --enable CONFIG_CMD_PING
    run_host_command_logged scripts/config --enable CONFIG_CMD_TFTPBOOT
    run_host_command_logged scripts/config --enable CONFIG_CMD_TFTPPUT
    run_host_command_logged scripts/config --enable CONFIG_CMD_WGET
    run_host_command_logged scripts/config --enable CONFIG_CMD_DNS
    run_host_command_logged scripts/config --enable CONFIG_PROT_TCP
    run_host_command_logged scripts/config --enable CONFIG_NETCONSOLE
    run_host_command_logged scripts/config --enable CONFIG_NET_RANDOM_ETHADDR

    # Static network + automatic NetConsole.
    # U-Boot client: 192.168.1.251/24
    # TFTP/NetConsole server: 192.168.1.250
    # Gateway: 192.168.1.1
    run_host_command_logged scripts/config --enable CONFIG_USE_PREBOOT
    run_host_command_logged 'scripts/config --set-str CONFIG_PREBOOT "setenv ipaddr 192.168.1.251; setenv serverip 192.168.1.250; setenv gatewayip 192.168.1.1; setenv netmask 255.255.255.0; setenv ncip 192.168.1.250:6666; ping 192.168.1.250; setenv stdin serial,nc; setenv stdout serial,nc; setenv stderr serial,nc"'

    # eMMC + SD controller support.
    run_host_command_logged scripts/config --enable CONFIG_MMC
    run_host_command_logged scripts/config --enable CONFIG_MMC_SUNXI
    run_host_command_logged scripts/config --set-val CONFIG_MMC_SUNXI_SLOT_EXTRA "2"

    # Allwinner raw NAND controller support.
    run_host_command_logged scripts/config --enable CONFIG_NAND_SUNXI
    run_host_command_logged scripts/config --enable CONFIG_CMD_NAND
    run_host_command_logged scripts/config --enable CONFIG_CMD_MTD

    # No board LED is assumed; the current physical board has no visible indicator.
}

# Export the exact recovery U-Boot produced by this build.
function pre_package_uboot_image__dolphin_p1_recovery_export() {
    local src="${uboottempdir}/usr/lib/${uboot_name}/u-boot-sunxi-with-spl.bin"
    local dst="${SRC}/output/images/u-boot-dolphin-p1-recovery-sunxi-with-spl.bin"

    if [[ ! -f "${src}" ]]; then
        exit_with_error "Dolphin-P1 recovery U-Boot artifact missing" "${src}"
    fi

    mkdir -p "${SRC}/output/images"
    run_host_command_logged install -Dm0644 "${src}" "${dst}"
    display_alert "Dolphin-P1 recovery U-Boot exported" "${dst}" "info"
}
