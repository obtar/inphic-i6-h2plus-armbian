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

The repository uses the official Armbian GitHub build action:

```text
armbian/build@main
```

Run **Actions → Build Dolphin-P1 Armbian → Run workflow**.

A push to `master` that changes `config/`, `userpatches/`, `scripts/`, `README.md`, or the workflow also starts a build.

The workflow uses:

```text
BOARD   = dolphin-p1
RELEASE = trixie
KERNEL  = current
IMAGE   = minimal
```

### Board configuration discovery

The custom board definition is stored in the repository at:

```text
config/boards/dolphin-p1.csc
```

Armbian discovers board definitions from the build framework's:

```text
build/config/boards/
```

The current `armbian/build@main` composite action copies `custom/userpatches` into `build/userpatches`, but does not copy a repository-level `config/boards/*.csc` into the framework.

The workflow therefore deliberately prepares the Armbian build checkout first and installs:

```text
config/boards/dolphin-p1.csc
        ↓
build/config/boards/dolphin-p1.csc
```

The workflow prints the installed board configuration before invoking the official build action. The action's own framework checkout uses `clean: false`, so this custom board file is retained.

The expected early build log contains the board configuration being sourced:

```text
Sourcing board configuration ... dolphin-p1.csc
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
