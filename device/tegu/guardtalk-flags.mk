# Per-device GuardTalk flags. Loaded by
# vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk via
# -include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk
# (see product-config-late.mk for the consumers).
#
# T-PORT-TEGU (DEC-PORT-GEN8910-001): tegu is the Pixel 9a, a zumapro /
# tegu-kernels 6.1 variant (GT_VARIANT=zumapro_tegu). Not the caimito variant —
# the registry pins the tegu kernel family (bcmdhd4383 Wi-Fi, syna_touch).
GUARDTALK_RADIO_EXCISED := true

# T-PORT-TEGU: pin the excision device identity as per-device data.
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
# docs/CAIMAN_PORT_LAYER.md §Shared-core blocker and TEGU_PORT_LAYER.md.
GUARDTALK_DEVICE := tegu
GUARDTALK_FEATURE_EXCISED_WAVE2 := true
GUARDTALK_VOICE_FILTER := true
# Face filter OFF by default (same rationale as tokay T-CAM-EXT-FIX): empty
# disables guardtalk-camera.mk (gate is `ifneq ($(GUARDTALK_FACE_FILTER),)`).
GUARDTALK_FACE_FILTER :=
# T-BRAND-PROPS (minimal rebrand): only Build.MODEL is overridden;
# *_FOR_ATTESTATION variants stay upstream so Play Integrity / keymint
# attestation still matches the signed vendor image.
# Upstream tegu.mk sets PRODUCT_MODEL := Pixel 9a.
GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 9a
