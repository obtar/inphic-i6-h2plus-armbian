# Inphic H202A / Dolphin-P1 Armbian

Clean Armbian/Debian build for the Inphic H202A (Dolphin-P1) based on the Allwinner H2+.

This repository is intentionally a **new implementation**. It does not preserve or recreate the Android vendor partition layout.

## Hardware basis

- Allwinner H2+ / sun8i H3 family
- 512 MiB DDR3
- Samsung 8 GB-class eMMC on MMC2, 8-bit bus, non-removable
- 100 Mbps internal Ethernet PHY
- UART0 on PA4/PA5
- PA15 power LED
- 32.768 kHz RTC crystal confirmed present on the PCB
- No RTC backup battery was identified; network time synchronization is therefore required after power loss
- XR819 Wi-Fi exists on the original board but is disabled in this first clean mainline image

The stock firmware reverse engineering established the U-Boot DRAM parameters as:

```text
dram_clk = 576 MHz
dram_zq  = 0x3b3bfb = 3881979
```

## Image layout

The generated image uses the normal Armbian partitioning machinery:

```text
Disk
├── raw Allwinner SPL/U-Boot area
├── 1 MiB-aligned partition table
├── p1  256 MiB  FAT32  LABEL=BOOT   /boot
└── p2  remaining ext4 LABEL=rootfs  /
```

There is deliberately no:

- `sunxi_mbr.fex`
- `sys_partition.fex`
- `env.fex`
- Android `boot.fex`
- `system/recovery/cache/UDISK` vendor partition set
- `partitions=` kernel command-line parameter
- `/dev/block/by-name/*`
- hard-coded Linux `mmcblk0pN` root device

The Linux root filesystem is selected using Armbian's normal filesystem identifiers, not the old Android mapping.

## Build

The repository checks out the official Armbian build framework directly and invokes its `compile.sh`. Custom board definitions and patches are supplied through the supported `userpatches/` mechanism.

Run **Actions → Build Dolphin-P1 Armbian → Run workflow**.

The workflow is manually triggered so changes can be reviewed before consuming a GitHub runner.

The workflow uses:

```text
BOARD   = dolphin-p1
RELEASE = trixie
KERNEL  = current
IMAGE   = minimal
```


### Build outputs

Each successful build publishes the normal Armbian image plus the exact mainline sunxi U-Boot produced by the same build:

```text
Armbian-*.img.xz
u-boot-sunxi-with-spl.bin
sha256sums.txt
```

The standalone `u-boot-sunxi-with-spl.bin` is intended for the initial Allwinner FEL bring-up. It is generated from the same U-Boot configuration used by the image build, including the Dolphin-P1 DRAM overrides, rather than downloading a generic H2+/H3 U-Boot.

This follows the Allwinner packaging model used by ophub's Armbian tooling: Allwinner devices use a board-specific U-Boot artifact, while platform boot files remain separate from board-specific hardware data. The upstream ophub documentation describes Allwinner U-Boot as a board-specific build artifact and uses `u-boot-sunxi-with-spl.bin` for supported Allwinner boards. citeturn1search1turn2search1

### Board configuration discovery

The custom board definitions are stored under Armbian's supported userpatches board path:

```text
userpatches/config/boards/
├── dolphin-p1.csc
└── dolphin-p1-recovery.csc
```

Current Armbian supports board definitions from `USERPATCHES_PATH/config/boards/`; the default `USERPATCHES_PATH` is `userpatches/`. The build framework therefore merges these files into the build's board configuration lookup without modifying the framework itself. citeturn1search0turn1search4

The GitHub Actions workflows explicitly merge:

```text
custom/userpatches/
        ↓
build/userpatches/
        ↓
build/userpatches/config/boards/dolphin-p1*.csc
```

The preparation step verifies the board file exists before `compile.sh` is invoked.

The expected build log then proceeds to load:

```text
dolphin-p1.csc
```

## U-Boot

U-Boot uses the upstream H2+ LibreTech configuration as the hardware initialization baseline:

```text
libretech_all_h3_cc_h2_plus_defconfig
```

The board configuration hook changes only the known Dolphin-P1 DRAM values and keeps the H2+/MMC2 support from the upstream configuration.

No hand-written U-Boot image is stored in this repository.

## Linux device tree

`userpatches/kernel/sunxi-current/0001-dolphin-p1-dts.patch` adds:

```text
sun8i-h2-plus-dolphin-p1.dtb
```

Stage 1 intentionally enables only the hardware needed for the first headless bring-up plus hardware-backed diagnostics:

```text
UART0
MMC2 / eMMC
Ethernet
PA15 LED
RTC
USB PHY
EHCI/OHCI 1 and 2 (USB-A host candidates)
thermal
watchdog
```

Stage 1 intentionally disables:

```text
MMC0 / SD
MMC1 / XR819 Wi-Fi
USB0 Linux OTG
EHCI/OHCI 0 and 3
HDMI
Audio codec
IR
I2C0/I2C1
crypto
```

The eMMC VCCQ voltage is not guessed. No `mmc-ddr-1_8v` is enabled until the physical VCCQ voltage is measured.

The CPU fixed 1.2 V regulator from the earlier draft is also intentionally absent; it was not sufficiently justified by the available hardware evidence.

## USB / FEL flashing

The board's USB used for Allwinner FEL/Phoenix flashing must be treated separately from the Linux USB-A host ports.

Before Linux starts:

```text
PC
 │
 └── USB OTG/data cable
       │
       ▼
   H2+ BootROM USB0/FEL
       │
       ├── Phoenix
       └── sunxi-fel
```

Therefore disabling the Linux node:

```dts
&usb_otg {
    status = "disabled";
};
```

does **not** disable BootROM FEL. Phoenix/sunxi-fel operates before the Linux kernel and its Device Tree are running.

The two visible USB-A connectors are treated as Linux Host candidates, currently EHCI/OHCI 1 and 2. Their exact PCB controller mapping remains a bring-up item and should be confirmed with:

```bash
lsusb
dmesg | grep -iE 'usb|ehci|ohci|phy'
dmesg -w
```

Do not infer the physical USB-A routing solely from controller numbering.

## RTC

The PCB has a confirmed 32.768 kHz RTC crystal, so the Stage-1 DTS enables the RTC:

```dts
&rtc {
    status = "okay";
};
```

The board has no identified backup battery. The RTC therefore should not be treated as a persistent time source across power loss. Network time synchronization should correct the system clock after boot.

## First boot

For FEL bring-up, connect the board's FEL-capable USB port to the host with a real USB data cable. The BootROM FEL path is independent of the Linux USB Host Device Tree.

On the host:

```bash
sudo sunxi-fel ver
sudo sunxi-fel uboot u-boot-sunxi-with-spl.bin
```

After U-Boot starts, identify the eMMC with `mmc list` and `mmc info` before writing anything. Do not assume the Linux DT `mmc2` numbering is identical to U-Boot's `mmc dev N` numbering.

After writing the generated `.img` to the eMMC, boot the board and use the serial console at:

```text
115200 8N1
```

The image intentionally does not embed a permanent `root:root` password. Complete Armbian's first-boot account/password setup on the serial console.

Initial bring-up target:

```text
U-Boot
  ↓
DRAM 576 MHz
  ↓
eMMC / MMC2
  ↓
Linux current
  ↓
rootfs
  ↓
eth0
  ↓
SSH
```

## Flashing

**Writing an image to an eMMC is destructive. Verify the target device before writing.**

For the initial Allwinner recovery/flashing path, use the board's OTG/FEL USB connection with Phoenix or `sunxi-fel`. The Linux USB Host configuration is not required for entering FEL mode.

After a Linux system can directly access the eMMC, a normal image write can be performed after identifying the correct device:

```bash
sudo umount /dev/mmcblkX* 2>/dev/null || true
xz -dc Armbian_*.img.xz | sudo dd of=/dev/mmcblkX bs=4M status=progress conv=fsync
```

Replace `mmcblkX` with the actual eMMC device. Do not blindly use `mmcblk0`.

## Current scope

The first build intentionally prioritizes:

1. DRAM initialization
2. eMMC boot
3. serial console
4. Ethernet
5. RTC
6. basic USB Host bring-up
7. clean Debian/Armbian storage layout

HDMI, audio, IR, I2C peripherals, XR819 Wi-Fi, and board-specific USB routing are deferred until the minimal boot path is proven.

## Scheme 1 status: deferred

The original Scheme 1 — detecting a physical Reset button in U-Boot and entering recovery before normal boot — is intentionally **not implemented yet**.

The first priority is to boot the normal Linux image successfully. Once Linux is running, the button GPIO can be identified and tested from Linux. Only after the actual button wiring/value is confirmed will a U-Boot Reset-to-Recovery path be considered.

This avoids guessing a GPIO from the old Android configuration.

## Scheme 2: standalone minimal recovery U-Boot

Scheme 2 is implemented as a separate U-Boot-only build target:

    config/boards/dolphin-p1-recovery.csc
    userpatches/config-dolphin-p1-recovery.conf
    .github/workflows/build-recovery-uboot.yml

Run **Actions → Build Dolphin-P1 Recovery U-Boot → Run workflow**.

This target does **not** build Debian, a kernel, or a complete Armbian image. It produces:

    u-boot-dolphin-p1-recovery-sunxi-with-spl.bin

The recovery U-Boot keeps the same known-good Dolphin-P1 initialization baseline:

    H2+ LibreTech U-Boot defconfig
    DRAM = 576 MHz
    DRAM ZQ = 3881979
    MMC_SUNXI_SLOT_EXTRA = 2

and additionally enables the recovery interfaces required for bring-up and storage recovery:

    USB UMS
    USB DFU
    USB Fastboot
    MMC/GPT/partition commands
    DHCP
    TFTP
    Ping
    Wget
    DNS/TCP support
    U-Boot LED framework

UMS is the primary method for writing a complete `.img` to the eMMC because the host sees the eMMC as a USB mass-storage block device. DFU and Fastboot are additional recovery transports for RAM/partition-oriented operations.

### Recovery U-Boot storage rule

The recovery build deliberately does **not** assume that Linux `mmc2` and U-Boot's `mmc dev N` use the same numbering.

Before any destructive operation, use U-Boot:

    mmc list
    mmc dev N
    mmc info

and identify the actual eMMC device.

The Fastboot MMC target is currently configured as U-Boot MMC device `1`, matching the current upstream U-Boot sunxi Kconfig rule for `CONFIG_MMC_SUNXI_SLOT_EXTRA=2`. This is a build-time default, not a substitute for checking the actual device with U-Boot.

### Planned recovery flow

    Allwinner BootROM / FEL
            |
            +-- normal U-Boot --> Linux
            |
            +-- recovery U-Boot
                    |
                    +-- USB UMS  --> host sees eMMC --> write full .img
                    |
                    +-- USB DFU  --> MMC/RAM recovery
                    |
                    +-- Fastboot --> partition-oriented recovery
                    |
                    +-- DHCP/TFTP/Wget --> network-assisted recovery

The recovery U-Boot is intentionally kept separate from the normal Armbian image. This makes the recovery artifact independently testable and avoids introducing recovery-specific code into the normal Linux boot path.
