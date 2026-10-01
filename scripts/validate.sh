*** Begin Patch
*** Update File: scripts/validate.sh
@@
 BOARD="$ROOT/config/boards/dolphin-p1.csc"
 CONF="$ROOT/userpatches/config-dolphin-p1.conf"
+RECOVERY_BOARD="$ROOT/config/boards/dolphin-p1-recovery.csc"
+RECOVERY_CONF="$ROOT/userpatches/config-dolphin-p1-recovery.conf"
@@
 test -f "$BOARD"
 test -f "$CONF"
+test -f "$RECOVERY_BOARD"
+test -f "$RECOVERY_CONF"
@@
 bash -n "$BOARD"
+bash -n "$RECOVERY_BOARD"
+bash -n "$RECOVERY_CONF"
@@
 grep -q 'u-boot-sunxi-with-spl.bin' "$BOARD"
+
+echo "== 4. Recovery U-Boot config sanity =="
+grep -q 'BOARD="dolphin-p1-recovery"' "$RECOVERY_CONF"
+grep -q 'BRANCH="current"' "$RECOVERY_CONF"
+grep -q 'BOOTCONFIG="libretech_all_h3_cc_h2_plus_defconfig"' "$RECOVERY_BOARD"
+grep -q 'UBOOT_TARGET_MAP=";;u-boot-sunxi-with-spl.bin"' "$RECOVERY_BOARD"
+grep -q 'CONFIG_DRAM_CLK "576"' "$RECOVERY_BOARD"
+grep -q 'CONFIG_DRAM_ZQ "3881979"' "$RECOVERY_BOARD"
+grep -q 'CONFIG_MMC_SUNXI_SLOT_EXTRA "2"' "$RECOVERY_BOARD"
+for symbol in \
+    CONFIG_CMD_MMC \
+    CONFIG_CMD_GPT \
+    CONFIG_CMD_PART \
+    CONFIG_CMD_USB \
+    CONFIG_CMD_USB_MASS_STORAGE \
+    CONFIG_USB_GADGET \
+    CONFIG_USB_GADGET_DOWNLOAD \
+    CONFIG_USB_FUNCTION_MASS_STORAGE \
+    CONFIG_CMD_DFU \
+    CONFIG_USB_FUNCTION_DFU \
+    CONFIG_DFU_MMC \
+    CONFIG_DFU_RAM \
+    CONFIG_FASTBOOT \
+    CONFIG_USB_FUNCTION_FASTBOOT \
+    CONFIG_CMD_FASTBOOT \
+    CONFIG_FASTBOOT_FLASH \
+    CONFIG_FASTBOOT_FLASH_MMC_DEV \
+    CONFIG_CMD_NET \
+    CONFIG_CMD_DHCP \
+    CONFIG_CMD_PING \
+    CONFIG_CMD_TFTPBOOT \
+    CONFIG_CMD_WGET \
+    CONFIG_CMD_DNS \
+    CONFIG_PROT_TCP \
+    CONFIG_LED \
+    CONFIG_LED_GPIO; do
+    grep -q "CONFIG_${symbol#CONFIG_}" "$RECOVERY_BOARD"
+done
+grep -q 'CONFIG_FASTBOOT_FLASH_MMC_DEV "2"' "$RECOVERY_BOARD"
+grep -q 'u-boot-dolphin-p1-recovery-sunxi-with-spl.bin' "$RECOVERY_BOARD"
 
-echo "== 4. Build config sanity =="
+echo "== 5. Build config sanity =="
@@
-echo "== 5. Patch header/path sanity =="
+echo "== 6. Patch header/path sanity =="
@@
-echo "== 6. DTS content sanity =="
+echo "== 7. DTS content sanity =="
@@
-echo "== 7. Makefile continuation sanity =="
+echo "== 8. Makefile continuation sanity =="
*** End Patch