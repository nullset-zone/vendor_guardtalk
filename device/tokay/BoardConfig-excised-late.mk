# Late board pass — include at end of vendor/google_devices/tokay/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk:45
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).

# T-PORT-EXCISION-MATRIX: resolve the SoC/device excision variant from DATA
# (vendor/guardtalk/feature-excised/excision-variants.mk) and fail loudly if
# tokay ever loses its variant entry. GT_VARIANT=zumapro_caimito.
GUARDTALK_DEVICE := tokay
include vendor/guardtalk/feature-excised/excision-variant-select.mk

AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-BT-FULL (FR-3): override the upstream vendor_dlkm.modules.blocklist with
# the GuardTalk version that adds `blocklist nitrous` (BCM4390 BT power/rfkill
# driver). Without this, the upstream blocklist (without nitrous) is used and
# the BT kernel driver loads, keeping the BT subsystem partially alive even
# after the userspace HAL is excised. The GuardTalk blocklist mirrors the
# upstream baseline verbatim and appends the nitrous entry.
# T-PORT-EXCISION-MATRIX: registry-resolved (variant zumapro_caimito canonical).
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GT_EXCISION_BLOCKLIST_FILE)

$(call gt-excision-validate-device-blocklist)
