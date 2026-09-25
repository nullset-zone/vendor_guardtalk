# Late board pass — include at end of vendor/google_devices/shiba/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).

# T-PORT-EXCISION-MATRIX: resolve the SoC/device excision variant from DATA
# (vendor/guardtalk/feature-excised/excision-variants.mk) and fail loudly if
# shiba ever loses its variant entry. GT_VARIANT=zuma_shusky (shusky-kernels
# 6.1 — the same kernel family as husky; NOT the akita baseline).
GUARDTALK_DEVICE := shiba
include vendor/guardtalk/feature-excised/excision-variant-select.mk

AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-PORT-BATCH-A / T-BT-FULL: zuma/shusky-correct vendor_dlkm blocklist.
# The resolver reads the registry, so shiba gets its own variant file
# vendor/guardtalk/feature-excised/variants/zuma_shusky/vendor_dlkm.modules.blocklist:
# the shusky-kernels grapheneos baseline (bcmdhd4398 Wi-Fi + goodix_brl_touch +
# sec_touch) + `blocklist nitrous`.
# It must NOT resolve to the akita/zuma blocklist
# (device/akita/vendor_dlkm.modules.blocklist — bcmdhd4383): handing shiba the
# akita token would silently mis-excise its Wi-Fi driver (excision-variants.mk
# SoC note; wrong-Wi-Fi-driver defect). $(call
# gt-excision-validate-device-blocklist) below proves token identity with the
# variant's canonical file and $(error)s on any drift — never a silent no-op.
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
