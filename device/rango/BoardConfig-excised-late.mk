# Late board pass — include at end of vendor/google_devices/rango/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).
AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# GrapheneOS armv9 (BoardConfig-armv9.mk) adds:
#   bootloader.pixel.MTE_FORCE_ON kasan.fault=panic
#   SANITIZE_TARGET := memtag_heap (binary MTE instrumentation)
# Stock factory rango vendor_boot uses kasan=off and does NOT force MTE.
# With those GrapheneOS flags, this device returns to fastboot after the Google G
# (Pixel 10 / laguna has had early MTE-caught faults in DisplayPort/Wi-Fi paths).
# Match stock for GuardTalk rango until the prebuilt kernel+DTB are verified safe
# under forced MTE on this bootloader pin (deepspace-17.1 / BP4A.260205.001).
BOARD_KERNEL_CMDLINE := $(filter-out bootloader.pixel.MTE_FORCE_ON kasan.fault=panic,$(BOARD_KERNEL_CMDLINE))
BOARD_KERNEL_CMDLINE += kasan=off

# Mirror the MTE_FORCE_ON removal at the binary level: strip memtag_heap from
# SANITIZE_TARGET. NOTE: path-based memtag (MemtagHeapAsyncIncludePaths from
# memtag-common.mk) is cleared separately in guardtalk-memtag.mk (product mk).
# Stock app_process64 also carries an ASYNC memtag note and still boots on this
# factory kernel — so notes alone are not a proven ENOEXEC→0x7f00 path here;
# we still match stock (no notes on bpfloader/netd/ip) for early-boot parity.
ifeq ($(filter memtag_heap,$(SANITIZE_TARGET)),)
else
SANITIZE_TARGET := $(filter-out memtag_heap,$(SANITIZE_TARGET))
SANITIZE_TARGET_DIAG := $(filter-out memtag_heap,$(SANITIZE_TARGET_DIAG))
endif

# T-PORT-RANGO-LAYER / T-BT-FULL: laguna-correct vendor_dlkm blocklist.
# Baseline = laguna-kernels grapheneos/rango (bcmdhd4383.ko + bcmdhd4390.ko,
# syna_touch/focal_touch/fst2/ebu-google/…) + nitrous.ko.
# Do NOT point rango at vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
# (that file is caimito/zumapro / tokay-oriented).
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist

# T-RANGO-BOOT-DEEP note (not a compile flag — RELEASE_AVF_ENABLE_EARLY_VM is a
# soong release config): apexd is built with EARLY_VM=true so kBootstrapApexes
# includes com.android.virt. Factory-boot stamps must drop
# system/apex/com.android.virt.apex in stage-rango-release.sh (MODE=gtuserspace)
# or apexd-bootstrap hits reboot_on_failure → bootloader (0xfc).
