# Loaded first from device.mk so later inherits can branch on this flag.
# Also pulled by vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk via
# -include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk.
GUARDTALK_RADIO_EXCISED := true
# T-PORT-SHARED-CORE / T-BRAND-PROPS (minimal rebrand): only Build.MODEL is
# overridden; *_FOR_ATTESTATION variants stay upstream so Play Integrity /
# keymint attestation still matches the signed vendor image.
GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 8a
# Wave 2 feature excision master gate (apps/nfc/fp/bt/loc + overlays).
GUARDTALK_FEATURE_EXCISED_WAVE2 := true
GUARDTALK_VOICE_FILTER := true
# Face filter OFF by default (same rationale as tokay T-CAM-EXT-FIX): empty
# disables guardtalk-camera.mk (gate is `ifneq ($(GUARDTALK_FACE_FILTER),)`).
GUARDTALK_FACE_FILTER :=
