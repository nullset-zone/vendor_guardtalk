# Late board pass — include at end of vendor/google_devices/tokay/BoardConfig.mk
# (runs AFTER vendor/adevtool/config/mk/google_devices/common/BoardConfig-common.mk:45
# re-sets BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE, so this override sticks).
AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1

# T-BT-FULL (FR-3): override the upstream vendor_dlkm.modules.blocklist with
# the GuardTalk version that adds `blocklist nitrous` (BCM4390 BT power/rfkill
# driver). Without this, the upstream blocklist (without nitrous) is used and
# the BT kernel driver loads, keeping the BT subsystem partially alive even
# after the userspace HAL is excised. The GuardTalk blocklist mirrors the
# upstream baseline verbatim and appends the nitrous entry.
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
