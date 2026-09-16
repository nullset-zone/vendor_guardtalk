# Late board pass — include at end of vendor/google_devices/komodo/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).
AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-PORT-KOMODO-LAYER / T-BT-FULL: zumapro/caimito-correct vendor_dlkm blocklist.
# Baseline = caimito-kernels grapheneos (bcmdhd4390 + syna_touch, same as tokay)
# + blocklist nitrous. Do NOT point komodo at the akita/zuma blocklist
# (bcmdhd4383 / goodix_brl_touch). Per-device copy of the shared
# feature-excised caimito+nitrous file so REGEN_HOOKS stays device-local.
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist
