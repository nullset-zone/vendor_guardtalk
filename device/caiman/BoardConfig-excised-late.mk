# Late board pass — include at end of vendor/google_devices/caiman/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).

# T-PORT-EXCISION-MATRIX: resolve the SoC/device excision variant from DATA
# (vendor/guardtalk/feature-excised/excision-variants.mk) and fail loudly if
# caiman ever loses its variant entry. GT_VARIANT=zumapro_caimito (same as
# tokay/komodo — Pixel 9 Pro is zumapro / caimito-kernels 6.1).
GUARDTALK_DEVICE := caiman
include vendor/guardtalk/feature-excised/excision-variant-select.mk

AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-PORT-CAIMAN-LAYER / T-BT-FULL: zumapro/caimito-correct vendor_dlkm blocklist.
# caiman has no per-device pin, so the registry-resolved
# GT_EXCISION_BLOCKLIST_FILE falls through to the zumapro_caimito canonical
# file vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist:
# the caimito-kernels grapheneos baseline (bcmdhd4390 + syna_touch + sec_touch,
# same as tokay/komodo) + `blocklist nitrous`.
# It must NOT resolve to the akita/zuma blocklist
# (device/akita/vendor_dlkm.modules.blocklist — bcmdhd4383 / goodix_brl_touch).
# $(call gt-excision-validate-device-blocklist) below proves token identity with
# the variant's canonical file and $(error)s on any drift — never a silent no-op.
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GT_EXCISION_BLOCKLIST_FILE)

$(call gt-excision-validate-device-blocklist)

# T-REMEDIATE-B1-AVB (item 4): user-image boot/vbmeta signing config points at
# the project AVB private-key path, not AOSP testkey_rsa4096.pem
# (build/make/core/Makefile falls back to that test key only when
# BOARD_AVB_KEY_PATH is unset). Operator-owned key material stays offline.
# Override on the signing host:
#   BOARD_AVB_KEY_PATH=/mnt/secure/keys/guardtalk/avb.pem
# Default in-tree stem is gitignored; the file is NOT committed.
# Unsigned lunch without the pem still reports BUILD_KEYS=dev-keys (APK
# certs). `m` cannot produce a lockable custom-key vbmeta until avb.pem
# is present at this path (or the override). userdebug sidecar keeps the
# AOSP test-key fallback (do not lock that image).
ifeq ($(TARGET_BUILD_VARIANT),user)
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_KEY_PATH ?= vendor/guardtalk/branding/signing-keys/avb.pem
endif
