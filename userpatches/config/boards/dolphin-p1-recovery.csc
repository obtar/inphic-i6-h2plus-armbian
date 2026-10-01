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

    # RAM-only recovery: autoboot directly into USB Mass Storage.
    # Allwinner FEL loads and executes this U-Boot entirely from RAM.
    # With MMC_SUNXI_SLOT_EXTRA=2, the internal eMMC is U-Boot mmc 1.
    # BOOTDELAY=0 is supplied as a board variable above; Armbian applies it
    # using its U-Boot configuration path and also enables the zero-delay check.
    # A UART keypress can therefore still interrupt autoboot.
    run_host_command_logged scripts/config --enable CONFIG_AUTOBOOT
    run_host_command_logged scripts/config --enable CONFIG_USE_BOOTCOMMAND
    # scripts/config in the current Armbian/U-Boot build environment does not
    # reliably preserve spaces in this string through the Armbian command runner.
    # Update the generated Kconfig value directly after the defconfig step.
    run_host_command_logged sed -i \
        -e 's#^CONFIG_BOOTCOMMAND=.*#CONFIG_BOOTCOMMAND="ums 0 mmc 1"#' \
        -e 's#^# CONFIG_BOOTCOMMAND is not set$#CONFIG_BOOTCOMMAND="ums 0 mmc 1"#' \
        .config
    run_host_command_logged sed -i 's#^CONFIG_BOOTDELAY=.*#CONFIG_BOOTDELAY=0#' .config
    if ! grep -q '^CONFIG_BOOTCOMMAND=' .config; then
        run_host_command_logged sh -c 'printf "%s\\n" "CONFIG_BOOTCOMMAND=\"ums 0 mmc 1\"" >> .config'
    fi

    # H2+ uses the Allwinner MUSB OTG controller for USB peripheral mode.
    # The base LibreTech defconfig enables EHCI/OHCI host support but not
    # the MUSB gadget backend, so explicitly enable the controller and PHY.
    run_host_command_logged scripts/config --enable CONFIG_USB_MUSB_HDRC
    run_host_command_logged scripts/config --enable CONFIG_USB_MUSB_GADGET
    run_host_command_logged scripts/config --enable CONFIG_PHY_SUN4I_USB
    run_host_command_logged scripts/config --enable CONFIG_USB_MUSB_SUNXI
    run_host_command_logged scripts/config --enable CONFIG_MUSB_PIO_ONLY

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
    run_host_command_logged scripts/config --set-val CONFIG_FASTBOOT_BUF_SIZE "0x10000000"

    # Ethernet/network recovery.
    run_host_command_logged scripts/config --enable CONFIG_CMD_NET
    run_host_command_logged scripts/config --enable CONFIG_CMD_DHCP
    run_host_command_logged scripts/config --enable CONFIG_CMD_PING
    run_host_command_logged scripts/config --enable CONFIG_CMD_TFTPBOOT
    run_host_command_logged scripts/config --enable CONFIG_CMD_WGET
    run_host_command_logged scripts/config --enable CONFIG_CMD_DNS
    run_host_command_logged scripts/config --enable CONFIG_PROT_TCP

    # Status LED framework. GPIO mapping/trigger policy is intentionally
    # deferred until the Linux bring-up confirms the hardware behaviour.
    run_host_command_logged scripts/config --enable CONFIG_LED
    run_host_command_logged scripts/config --enable CONFIG_LED_GPIO
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
