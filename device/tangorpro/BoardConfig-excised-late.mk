# GuardTalkOS — tangorpro late board pass (T-PORT-TANGORPRO-LAYER, P0).
#
# Include at the END of vendor/google_devices/tangorpro/BoardConfig.mk, inside
# `ifneq ($(GUARDTALK_RADIO_EXCISED),)`. It runs AFTER
# vendor/adevtool/config/mk/google_devices/device/tangorpro/BoardConfig-base.mk
# -> platform/gs201/BoardConfig-common.mk -> common/BoardConfig-common.mk:45
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks.
#
# Derived from vendor/guardtalk/device/tokay/BoardConfig-excised-late.mk AS A
# REFERENCE, then CORRECTED for this device. Two of tokay's three statements
# have no subject on tangorpro and are deliberately NOT copied — see §2/§3.
#
# Reference (re-runnable evidence):
#   vendor/google_devices/tangorpro/firmware/          -> abl/bl1/bl2/bl31/bootloader/
#                                                         gsa/ldfw/pbl/tzsw .img ONLY
#                                                         (no modem.img, no radio.img)
#   vendor/google_devices/tangorpro/firmware/android-info.txt
#                                                     -> require board=tangorpro
#                                                        require version-bootloader=tangorpro-16.4-14540572
#                                                        require partition-exists=vendor_kernel_boot
#                                                        (no `require version-baseband=`)
#   vendor/google_devices/tangorpro/BoardConfig.mk:48 -> AB_OTA_PARTITIONS has NO `modem` entry
#   DEC-PORT-TANGORPRO-003 (Architect): no modem HARDWARE; the RIL/radioext
#     USERSPACE does ship and is excised at the PRODUCT layer
#     (vendor/guardtalk/radio-excised/remove-packages.mk / filter-copy-files.mk).

# ---------------------------------------------------------------------------
# 1. Excision variant resolution (IDENTICAL to tokay — device-agnostic).
#    Resolve from DATA (vendor/guardtalk/feature-excised/excision-variants.mk)
#    and fail loudly if tangorpro ever loses its row. Expected:
#    GT_VARIANT=gs201_tangorpro (T-PORT-TANGORPRO-EXCISION-VARIANT).
# ---------------------------------------------------------------------------
GUARDTALK_DEVICE := tangorpro
include vendor/guardtalk/feature-excised/excision-variant-select.mk

# ---------------------------------------------------------------------------
# 2. AB_OTA_PARTITIONS modem strip — INAPPLICABLE, intentionally omitted.
#    tokay does:  AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))
#    tangorpro's empirical AB_OTA_PARTITIONS (BoardConfig.mk:48) is
#      abl bl1 bl2 bl31 boot dtbo gsa init_boot ldfw pbl product pvmfw system
#      system_dlkm system_ext tzsw vbmeta vendor vendor_boot vendor_dlkm
#      vendor_kernel_boot
#    i.e. the set contains no `modem` token at all, so the filter would be a
#    vacuous no-op that reads as if a modem partition had been excised. Copying
#    it would be an excision claim with no subject (Law 7). Should a future
#    regen ever add a `modem` partition here, that is a NEW device fact and this
#    file must be revisited deliberately — not by silent inheritance.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 3. androidboot.radio.disabled=1 kernel cmdline — INAPPLICABLE, intentionally
#    omitted.
#    tokay does:  BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1
#    That flag suppresses the boot of the MODEM (CP) firmware. tangorpro has no
#    modem hardware and no radio.img: there is no CP interface for the kernel to
#    gate, so the parameter would be set and never read. The RIL/radioext
#    userspace is disabled where it actually exists — at the product layer, by
#    vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk (included from
#    tangorpro.mk), which sets `persist.radio.disabled=1` and drops the RIL
#    packages/copy-files/VINTF fragments.
#    Note this is board-config-time unusable for a second reason: the edit-3
#    gate (GUARDTALK_RADIO_EXCISED) is set by the PRODUCT mk, parsed after
#    BoardConfig files, so the gate is false whenever BoardConfig is read (on
#    every device, tokay included). tangorpro's BoardConfig.mk therefore carries
#    the hook UNGATED, like tokay's, so the layer is actually reached.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 4. vendor_dlkm kernel module blocklist (MEANINGFUL on this device).
#    T-BT-FULL (FR-3) + T-PORT-TANGORPRO-EXCISION-VARIANT: override the upstream
#    adevtool blocklist with the GuardTalk variant file, which adds
#    `blocklist nitrous` (BCM BT power/rfkill driver). Measured on this tree:
#      upstream device/google/tangorpro-kernels/6.1/trunk-14096387/...blocklist
#        -> 6 tokens (aoc_unit_test_dev mali_kutf mali_kutf_clk_rate_trace_test_portal
#           rt4539_bl sscoredump_sample_test.ko sscoredump_test.ko)
#      variant gs201_tangorpro -> the same 6 + nitrous
#    and device/google/tangorpro-kernels/6.1/grapheneos/vendor_dlkm.modules.load
#    DOES load bluetooth/broadcom/nitrous.ko, so the entry has a real subject.
#    GT_EXCISION_BLOCKLIST_FILE resolves through the registry to
#      vendor/guardtalk/feature-excised/variants/gs201_tangorpro/vendor_dlkm.modules.blocklist
#    (there is no GT_DEVICE_BLOCKLIST_tangorpro pin, by design — the variant
#    file IS the tangorpro evidence-derived baseline).
# ---------------------------------------------------------------------------
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GT_EXCISION_BLOCKLIST_FILE)

# Fail loudly if the file above ever drifts token-wise from variant
# gs201_tangorpro, or points at a non-existent path. Never a silent no-op.
$(call gt-excision-validate-device-blocklist)
