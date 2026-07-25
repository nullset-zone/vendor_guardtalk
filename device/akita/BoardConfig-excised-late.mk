# Late board pass — include at end of vendor/google_devices/akita/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).
AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-PORT-AKITA-LAYER / T-BT-FULL: zuma-correct vendor_dlkm blocklist.
# Baseline = akita-kernels grapheneos (bcmdhd4383 + goodix_brl_touch) + nitrous.
# Do NOT point akita at vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
# (that file is caimito/zumapro / tokay-oriented).
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist
