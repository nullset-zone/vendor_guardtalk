# Per-device GuardTalk flags. Loaded by
# vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk via
# -include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk
# (see product-config-late.mk for the consumers).
#
# T-PORT-BATCH-B (DEC-PORT-GEN8910-002): frankel is the Pixel 10, the same
# laguna / muzel variant as blazer/mustang (GT_VARIANT=laguna_muzel,
# laguna-kernels 6.6). Do NOT key this on zumapro — that REGEN_HOOKS debt once
# produced wrong blocklist advice for laguna.
GUARDTALK_RADIO_EXCISED := true

# T-PORT-BATCH-B: pin the excision device identity as per-device data.
# The shared resolver (feature-excised/excision-variant-select.mk) is included
# from guardtalk-radio-excised.mk, which is re-entered from
# radio-excised/product-config-late.mk (build/make/core/product_config.mk).
# In that second context PRODUCT_DEVICE/TARGET_DEVICE are empty and the board
# GUARDTALK_DEVICE (BoardConfig-excised-late.mk) has not been evaluated yet, so
# the resolver's $(or $(GUARDTALK_DEVICE),$(PRODUCT_DEVICE),$(TARGET_DEVICE))
# sees no identity and $(error)s. This file is `-include`d by
# guardtalk-radio-excised.mk while PRODUCT_DEVICE is still set, so a pin here
# survives into the late pass and keeps registry resolution deterministic.
# (Same fix as caiman guardtalk-flags.mk:22; the durable fix belongs in the
# shared resolver once it grows its own re-include guard.)
GUARDTALK_DEVICE := frankel
GUARDTALK_FEATURE_EXCISED_WAVE2 := true
GUARDTALK_VOICE_FILTER := true
# Face filter OFF by default (same rationale as tokay T-CAM-EXT-FIX): empty
# disables guardtalk-camera.mk (gate is `ifneq ($(GUARDTALK_FACE_FILTER),)`).
GUARDTALK_FACE_FILTER :=
# T-BRAND-PROPS (minimal rebrand): only Build.MODEL is overridden;
# *_FOR_ATTESTATION variants stay upstream so Play Integrity / keymint
# attestation still matches the signed vendor image.
# Upstream frankel.mk sets PRODUCT_MODEL := Pixel 10.
GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 10
