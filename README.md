# Inphic H202A / Dolphin-P1

Armbian/Linux and standalone Recovery U-Boot support for the Inphic H202A (Dolphin-P1), based on the Allwinner H2+.

本项目以主线 Linux / U-Boot 为基础，针对 Dolphin-P1 的实际硬件参数进行适配，并提供独立的 FEL RAM Recovery U-Boot，用于在不依赖 eMMC 中现有系统的情况下恢复或重写内部 eMMC。

## Hardware

| Item | Information |
|---|---|
| SoC | Allwinner H2+ / sun8i family |
| RAM | 512 MiB DDR3 |
| Internal storage | eMMC, 8-bit, non-removable |
| Ethernet | 100 Mbps |
| Debug UART | Not identified on the current bare board; UART0/PA4/PA5 remains the firmware candidate |
| LED | No visible board indicator; PA15 is not assumed as a usable indicator |
| RTC crystal | 32.768 kHz |
| Wi-Fi | XR819 on the original board |
| BootROM recovery | Allwinner FEL |

Known Dolphin-P1 DRAM parameters:

~~~text
DRAM clock = 576 MHz
DRAM ZQ    = 3881979
DRAM ODT   = enabled
~~~

These values are retained by both the normal and Recovery U-Boot configurations.

## Project layout

~~~text
.
├── .github/
│   └── workflows/
│       └── build-recovery-uboot.yml
├── userpatches/
│   ├── config/
│   │   └── boards/
│   │       ├── dolphin-p1.csc
│   │       └── dolphin-p1-recovery.csc
│   ├── config-dolphin-p1-recovery.conf
│   └── kernel/
│       └── ...
└── README.md
~~~

Two independent build targets are provided:

~~~text
dolphin-p1
    └── normal Armbian/Linux image

dolphin-p1-recovery
    └── standalone Recovery U-Boot
~~~

The Recovery target does not build a Debian root filesystem or a complete Linux image.

# Normal Armbian

The normal board target builds an Armbian image for the Dolphin-P1.

The initial bring-up focuses on:

- U-Boot
- DRAM
- eMMC
- UART
- Ethernet
- RTC
- basic USB support

The board-specific Linux Device Tree is:

~~~text
allwinner/sun8i-h2-plus-dolphin-p1.dtb
~~~

The normal image uses the standard Armbian storage layout rather than the original Android vendor partition scheme.

## Normal build

The project uses the Armbian build framework through GitHub Actions.

Target configuration:

~~~text
BOARD   = dolphin-p1
BRANCH  = current
RELEASE = trixie
IMAGE   = minimal
~~~

The generated image and the normal U-Boot artifact are produced by the normal Armbian build workflow.

# FEL / BootROM

The Allwinner BootROM provides FEL recovery before U-Boot and Linux start.

Check FEL from the host:

~~~bash
sudo sunxi-fel ver
~~~

Load a U-Boot SPL image into RAM:

~~~bash
sudo sunxi-fel uboot u-boot-sunxi-with-spl.bin
~~~

Boot flow:

~~~text
PC
 │
 │ USB
 ▼
Allwinner BootROM
 │
 │ FEL
 ▼
SPL
 │
 │ DRAM initialization
 ▼
U-Boot
 │
 ▼
Linux or recovery operation
~~~

FEL is a BootROM function. Disabling a Linux USB Device Tree node does not disable the BootROM FEL interface.

# Standalone Recovery U-Boot

The project provides a separate Recovery U-Boot:

~~~text
u-boot-dolphin-p1-recovery-sunxi-with-spl.bin
~~~

The recovery bootloader is designed for RAM-only execution through FEL.

Primary recovery workflow:

~~~text
Allwinner BootROM / FEL
        │
        ▼
Recovery U-Boot loaded into RAM
        │
        ▼
Recovery U-Boot does not automatically start UMS
        │
        ▼
Internal eMMC exposed as USB Mass Storage
        │
        ▼
PC sees the eMMC as a block device
        │
        ▼
Write a complete image to the eMMC
~~~

The Recovery U-Boot does not depend on a working Linux installation on the eMMC.

The current physical test board is a bare, unlabelled board. No usable LED indicator or exposed/identified TTL UART header has been confirmed, so Ethernet NetConsole is treated as the primary interactive diagnostic path.

## Recovery U-Boot configuration

~~~text
BOOTCONFIG             = libretech_all_h3_cc_h2_plus_defconfig
BOOT_FDT_FILE          = allwinner/sun8i-h2-plus-dolphin-p1.dtb
UBOOT_TARGET           = u-boot-sunxi-with-spl.bin
DRAM clock             = 576 MHz
DRAM ZQ                = 3881979
DRAM ODT               = enabled
MMC_SUNXI_SLOT_EXTRA   = 2
~~~

UMS is enabled but is **not** started automatically.

The Recovery U-Boot starts an interactive prompt and prints:

~~~text
Recovery U-Boot ready - run: ums 0 mmc 1
~~~

Run UMS manually when the host should receive the eMMC as a USB disk:

~~~text
ums 0 mmc 1
~~~

BOOTDELAY=0 runs the harmless default command immediately and returns to the interactive U-Boot prompt.

## eMMC numbering

With:

~~~text
CONFIG_MMC_SUNXI_SLOT_EXTRA=2
~~~

the current U-Boot configuration maps the internal eMMC to:

~~~text
U-Boot: mmc 1
~~~

Linux device numbering is separate and must not be assumed to match U-Boot.

Before destructive operations in an interactive U-Boot session:

~~~text
mmc list
mmc dev 1
mmc info
~~~

Always verify the actual device on the board.

# USB Recovery Interfaces

The Recovery U-Boot enables several recovery transports.

## USB Mass Storage

Primary recovery mechanism:

~~~text
ums 0 mmc 1
~~~

This exposes the eMMC block device through USB Mass Storage.

On a Linux host:

~~~bash
lsusb
lsblk
dmesg
~~~

Identify the newly appeared disk before writing anything.

A complete Armbian image can then be written after identifying the correct USB disk:

~~~bash
xz -dc Armbian_*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
~~~

Replace /dev/sdX with the actual Recovery U-Boot USB disk.

**Writing an image is destructive. Verify the device before running dd.**

## USB DFU

DFU support is enabled for RAM and MMC recovery.

Relevant features:

~~~text
CONFIG_CMD_DFU
CONFIG_USB_FUNCTION_DFU
CONFIG_DFU_MMC
CONFIG_DFU_RAM
~~~

DFU is an additional recovery mechanism; UMS remains the primary whole-disk recovery path.

## USB Fastboot

Fastboot support is enabled for partition-oriented recovery, but Fastboot is **not started automatically**.

Enter Fastboot manually from the U-Boot prompt:

~~~text
fastboot usb 0
~~~

The current build provides MMC flash support and uses U-Boot MMC device 1 as its default MMC target. The Fastboot download buffer is:

~~~text
address = 0x42000000
size    = 0x10000000 (256 MiB)
USB     = 0
~~~

On the host, verify that the device appears:

~~~bash
fastboot devices
fastboot getvar all
~~~

For a partition that exists in the eMMC partition table, flashing uses the normal Fastboot syntax:

~~~bash
fastboot flash <partition> <image>
~~~

Verify the actual device and partition before destructive operations.

## Network recovery / NetConsole

The Recovery U-Boot uses a fixed recovery network:

~~~text
U-Boot client : 192.168.1.251/24
TFTP server   : 192.168.1.250
Gateway       : 192.168.1.1
NetConsole    : 192.168.1.250:6666/UDP
~~~

NetConsole is enabled automatically during U-Boot preboot. Serial remains in the console multiplexer as a fallback:

~~~text
stdin=serial,nc
stdout=serial,nc
stderr=serial,nc
~~~

On the host, listen with the U-Boot NetConsole tool:

~~~bash
tools/netconsole 192.168.1.251
~~~

The build also enables:

~~~text
DHCP
Ping
TFTP download
TFTP upload (tftpput)
Wget
DNS
TCP
~~~

TFTP upload example:

~~~text
tftpput ${loadaddr} ${filesize} ${serverip}:recovery.bin
~~~

The TFTP server at 192.168.1.250 must permit writes for uploads.

# Recovery Build

Recovery U-Boot is built separately from the normal Armbian image.

Configuration files:

~~~text
userpatches/config/boards/dolphin-p1-recovery.csc
userpatches/config-dolphin-p1-recovery.conf
.github/workflows/build-recovery-uboot.yml
~~~

The workflow invokes:

~~~bash
./compile.sh uboot \
  BOARD="dolphin-p1-recovery" \
  BRANCH="current" \
  KERNEL_CONFIGURE="no"
~~~

Expected artifact:

~~~text
build/output/images/
└── u-boot-dolphin-p1-recovery-sunxi-with-spl.bin
~~~

A SHA-256 checksum is generated alongside the artifact.

## GitHub Actions

The Recovery U-Boot workflow is **manual only**.

Trigger it from:

~~~text
Actions
  → Build Dolphin-P1 Recovery U-Boot
  → Run workflow
~~~

There is intentionally no automatic push trigger for this workflow.

The workflow:

1. Checks out this repository.
2. Checks out the Armbian build framework.
3. Installs build requirements.
4. Installs the custom Dolphin-P1 Recovery board configuration.
5. Builds only U-Boot.
6. Verifies the generated Recovery U-Boot.
7. Generates SHA-256 checksums.
8. Uploads the Recovery U-Boot as an Actions artifact.
9. Publishes a prerelease containing the Recovery U-Boot.

# Recovery Procedure

## 1. Connect FEL USB

Connect the PC to the board's FEL-capable USB port.

~~~bash
sudo sunxi-fel ver
~~~

## 2. Load Recovery U-Boot

~~~bash
sudo sunxi-fel uboot u-boot-dolphin-p1-recovery-sunxi-with-spl.bin
~~~

The SPL initializes DRAM and then starts U-Boot from RAM.

## 3. Select a recovery transport

The Recovery U-Boot does not automatically enter UMS or Fastboot mode.

For whole-disk access, start UMS manually:

~~~text
ums 0 mmc 1
~~~

For Fastboot partition recovery, start USB Fastboot manually:

~~~text
fastboot usb 0
~~~

Choose only one USB gadget mode at a time. The internal eMMC is the target storage for both recovery paths.

On Linux:

~~~bash
dmesg -w
lsblk
~~~

Identify the newly appeared disk.

## 4. Write the image

For an Armbian compressed image:

~~~bash
xz -dc Armbian_*.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
~~~

Then safely disconnect the USB disk from the host before rebooting the board.

# Serial Console

UART0 at PA4/PA5 remains the current firmware candidate:

~~~text
115200 baud
8 data bits
No parity
1 stop bit
~~~

However, the current physical board is unlabelled and no UART header/pins have been identified. Do not assume a visible serial connector exists.

For current bring-up, use Ethernet NetConsole first.

Useful U-Boot commands:

~~~text
version
bdinfo
mmc list
mmc info
usb start
printenv
~~~

If autoboot is interrupted, the U-Boot console can be used to inspect the hardware before starting a recovery operation.

# Important Safety Notes

- Recovery U-Boot operates directly on the internal eMMC.
- UMS gives the host direct block-level access to the eMMC.
- A wrong dd target can destroy another disk.
- Always verify the device with lsblk before writing.
- Do not assume Linux mmcblk0, U-Boot mmc 0, and U-Boot mmc 1 refer to the same physical device.
- Do not interrupt an active eMMC write.
- Keep a known-good FEL connection available during development.
- The Recovery U-Boot is intended for development and recovery, not as the normal persistent bootloader configuration.

# Current Scope

Implemented:

- Dolphin-P1 H2+ board definition
- Dolphin-P1 DRAM parameters
- eMMC support
- mainline Linux Device Tree integration
- normal Armbian image build
- standalone Recovery U-Boot build
- FEL RAM boot
- manual eMMC UMS
- USB DFU
- USB Fastboot
- network recovery commands
- manual-only Recovery U-Boot GitHub Actions workflow

Not currently part of the Recovery U-Boot:

- automatic Reset-button detection
- Reset-button-triggered recovery
- persistent recovery boot selection
- automatic repartitioning without host confirmation
- automatic UMS startup
- NAND UMS

The recovery design intentionally starts with:

~~~text
FEL → RAM U-Boot → NetConsole / manual UMS
~~~

because this path does not depend on the existing eMMC software installation.

# Development Direction

The recovery path is kept independent from the normal Linux image:

~~~text
                    ┌───────────────┐
                    │ Allwinner FEL │
                    └───────┬───────┘
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
        Normal U-Boot          Recovery U-Boot
                 │                     │
                 ▼                     ▼
              Linux              USB UMS / DFU /
                 │                Fastboot / Network
                 ▼                     │
             Armbian                  ▼
                                  eMMC recovery
~~~

This separation keeps the Recovery U-Boot independently buildable and testable while the normal Armbian image evolves separately.
