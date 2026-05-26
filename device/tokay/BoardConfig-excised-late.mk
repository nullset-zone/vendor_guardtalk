# Late board pass — include at end of vendor/google_devices/tokay/BoardConfig.mk
AB_OTA_PARTITIONS := $(filter-out modem,$(AB_OTA_PARTITIONS))

BOARD_KERNEL_CMDLINE += androidboot.radio.disabled=1
