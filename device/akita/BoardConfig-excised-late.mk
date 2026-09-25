# Late board pass — include at end of vendor/google_devices/akita/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).

# T-PORT-EXCISION-MATRIX: resolve the SoC/device excision variant from DATA
# (vendor/guardtalk/feature-excised/excision-variants.mk) and fail loudly if
# akita ever loses its variant entry. GT_VARIANT=zuma_akita.
GUARDTALK_DEVICE := akita
include vendor/guardtalk/feature-excised/excision-variant-select.mk

AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-PORT-AKITA-LAYER / T-BT-FULL: zuma-correct vendor_dlkm blocklist.
# Baseline = akita-kernels grapheneos (bcmdhd4383 + goodix_brl_touch) + nitrous.
# Do NOT point akita at vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
# (that file is caimito/zumapro / tokay-oriented).
# T-PORT-EXCISION-MATRIX: this path IS the registry's canonical file for
# variant zuma_akita (GT_VARIANT_zuma_akita_BLOCKLIST) — pinned here as the
# QA-anchored literal; the call below proves it still matches the variant data.
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist

$(call gt-excision-validate-device-blocklist)
