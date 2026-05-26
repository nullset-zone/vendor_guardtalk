# GuardTalkOS — board overrides when GUARDTALK_RADIO_EXCISED is set
ifneq ($(GUARDTALK_RADIO_EXCISED),)
  # Applied from BoardConfig.mk tail include (after AB_OTA_PARTITIONS is set)
endif
