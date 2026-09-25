# Late board pass — include at end of vendor/google_devices/blazer/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).

# T-PORT-EXCISION-MATRIX: resolve the SoC/device excision variant from DATA
# (vendor/guardtalk/feature-excised/excision-variants.mk) and fail loudly if
# blazer ever loses its variant entry. GT_VARIANT=laguna_muzel (blazer is
# laguna, NOT zumapro — that REGEN_HOOKS debt once produced wrong blocklist
# advice).
GUARDTALK_DEVICE := blazer
include vendor/guardtalk/feature-excised/excision-variant-select.mk

AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-PORT-BATCH-B / T-RANGO-BOOT-DEEP (laguna precedent): GrapheneOS armv9
# (BoardConfig-armv9.mk, pulled in by platform/laguna/BoardConfig-common.mk)
# adds:
#   bootloader.pixel.MTE_FORCE_ON kasan.fault=panic
#   SANITIZE_TARGET := memtag_heap (binary MTE instrumentation)
# On the laguna bootloader pin (deepspace-17.1 / BP4A.260205.001) that
# combination has returned Pixel 10 / laguna to fastboot after the Google G
# (early MTE-caught faults in DisplayPort/Wi-Fi paths). Mirror rango and match
# the stock factory vendor_boot (kasan=off, no forced MTE) until the prebuilt
# kernel+DTB are verified safe under forced MTE on this pin.
BOARD_KERNEL_CMDLINE := $(filter-out bootloader.pixel.MTE_FORCE_ON kasan.fault=panic,$(BOARD_KERNEL_CMDLINE))
BOARD_KERNEL_CMDLINE += kasan=off

# Mirror the MTE_FORCE_ON removal at the binary level: strip memtag_heap from
# SANITIZE_TARGET. Path-based memtag (MemtagHeapAsyncIncludePaths from
# memtag-common.mk) is cleared separately in guardtalk-memtag.mk (product mk,
# included from blazer.mk).
ifeq ($(filter memtag_heap,$(SANITIZE_TARGET)),)
else
SANITIZE_TARGET := $(filter-out memtag_heap,$(SANITIZE_TARGET))
SANITIZE_TARGET_DIAG := $(filter-out memtag_heap,$(SANITIZE_TARGET_DIAG))
endif

# T-PORT-BATCH-B / T-BT-FULL: laguna-correct vendor_dlkm blocklist.
# Baseline = laguna-kernels grapheneos/muzel (bcmdhd4383.ko + bcmdhd4390.ko,
# syna_touch/focal_touch/fst2/ebu-google/…) + nitrous.ko.
# Do NOT point laguna at vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
# (that file is caimito/zumapro / tokay-oriented).
# T-PORT-EXCISION-MATRIX: registry-resolved (variant laguna_muzel canonical
# file is vendor/guardtalk/feature-excised/variants/laguna_muzel/
# vendor_dlkm.modules.blocklist). The call below proves token equality.
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GT_EXCISION_BLOCKLIST_FILE)

$(call gt-excision-validate-device-blocklist)
