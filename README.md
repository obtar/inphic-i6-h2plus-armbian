# Inphic H202A / Dolphin-P1 Armbian

Clean Armbian/Debian build for the Inphic H202A (Dolphin-P1) based on the Allwinner H2+.

This repository is intentionally a **new implementation**. It does not preserve or recreate the Android vendor partition layout.

## Hardware basis

- Allwinner H2+ / sun8i H3 family
- 512 MiB DDR3
- 8 GB-class eMMC on MMC2, 8-bit bus
- 100 Mbps internal Ethernet PHY
- HDMI
- UART0 on PA4/PA5
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

A push to `main` that changes `userpatches/` or the workflow also starts a build.

The workflow uses:

```text
BOARD   = dolphin-p1
RELEASE = trixie
KERNEL  = current
IMAGE   = minimal
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

and registers it in the Allwinner H3 DTB Makefile.

The DT enables the eMMC on MMC2 and disables the unused SD/MMC1 Wi-Fi path.

## First boot

After writing the generated `.img` to the eMMC, boot the board and use the serial console at:

```text
115200 8N1
```

The image intentionally does not embed a permanent `root:root` password. Complete Armbian's first-boot account/password setup on the serial/HDMI console.

## Flashing

**Writing an image to an eMMC is destructive. Verify the target device before writing.**

On Linux, after identifying the eMMC device:

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
5. HDMI
6. USB
7. clean Debian/Armbian storage layout

XR819 Wi-Fi and board-specific audio routing are not required for the first boot milestone and remain conservative in this initial implementation.
