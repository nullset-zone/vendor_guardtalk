# Per-device GuardTalk flags. Loaded by
# vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk via
# -include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk
# (see product-config-late.mk for the consumers).
#
# T-PORT-BATCH-A (DEC-PORT-GEN8910-001): husky is the Pixel 8 Pro, a zuma /
# shusky-kernels 6.1 variant (GT_VARIANT=zuma_shusky). husky shares the shusky
# kernel family with shiba: bcmdhd4398 Wi-Fi, goodix_brl_touch + sec_touch,
# Goodix fingerprint stack. It is NOT the akita (zuma_akita) variant — the
# registry pins the shusky kernel family (see excision-variants.mk SoC note),
# so shiba/husky never inherit the akita bcmdhd4383 blocklist.
GUARDTALK_RADIO_EXCISED := true

# T-PORT-BATCH-A: pin the excision device identity as per-device data.
# The shared resolver (feature-excised/excision-variant-select.mk) is included
# from guardtalk-radio-excised.mk, which is re-entered from
# radio-excised/product-config-late.mk (build/make/core/product_config.mk:269).
# In that second context PRODUCT_DEVICE/TARGET_DEVICE are empty and the board
# GUARDTALK_DEVICE (BoardConfig-excised-late.mk) has not been evaluated yet, so
# the resolver's $(or $(GUARDTALK_DEVICE),$(PRODUCT_DEVICE),$(TARGET_DEVICE))
# sees no identity and $(error)s. This file is `-include`d by
# guardtalk-radio-excised.mk while PRODUCT_DEVICE is still set, so a pin here
# survives into the late pass and keeps registry resolution deterministic.
# Fix belongs in the shared resolver (re-include guard); see
# docs/CAIMAN_PORT_LAYER.md §Shared-core blocker.
GUARDTALK_DEVICE := husky
GUARDTALK_FEATURE_EXCISED_WAVE2 := true
GUARDTALK_VOICE_FILTER := true
# Face filter OFF by default (same rationale as tokay T-CAM-EXT-FIX): empty
# disables guardtalk-camera.mk (gate is `ifneq ($(GUARDTALK_FACE_FILTER),)`).
GUARDTALK_FACE_FILTER :=
# T-BRAND-PROPS (minimal rebrand): only Build.MODEL is overridden;
# *_FOR_ATTESTATION variants stay upstream so Play Integrity / keymint
# attestation still matches the signed vendor image.
# Upstream husky.mk sets PRODUCT_MODEL := Pixel 8 Pro.
GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 8 Pro
