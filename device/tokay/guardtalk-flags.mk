# Loaded first from device.mk so later inherits can branch on this flag.
GUARDTALK_RADIO_EXCISED := true
# T-PORT-SHARED-CORE (2026-07-04): per-device brand rebrand string consumed by
# vendor/guardtalk/radio-excised/product-config-late.mk. Each GuardTalkOS
# device sets its own value here; the late pass skips the rebrand when unset
# (Law 9). This is the minimal-rebrand knob (T-BRAND-PROPS option "minimal"):
# only Build.MODEL is overridden; *_FOR_ATTESTATION variants stay upstream so
# Play Integrity / keymint attestation still matches the signed vendor image.
GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 9
# Wave 2 feature excision master gate. T-W2-I1-UI-APPS currently enables only
# the non-HAL UI app removal (Browser + AppStore + Dialer) via apps-excised.mk.
# Later increments (bt/nfc/fp/loc) wire their own <sub>-excised.mk files into
# guardtalk-feature-excised.mk without flipping this flag off.
GUARDTALK_FEATURE_EXCISED_WAVE2 := true
GUARDTALK_VOICE_FILTER := true
# T-CAM-EXT-FIX: GuardTalk camera-extensions provider (androidx.camera.extensions.impl.guardtalk)
# is incompatible with Pixel Camera Services' ProxyCameraProviderService init contract -> NPE
# crash loop -> black preview. Face filter is OFF by default
# (persist.vendor.guardtalk.face.enabled=0), so the provider crashes the camera for no benefit.
# Flip to empty (NOT "false" -- the gate is `ifneq ($(GUARDTALK_FACE_FILTER),)` which treats any
# non-empty value as enabled) so guardtalk-camera.mk's block evaluates false and the extensions
# packages are not installed. Voice filter is separate and remains enabled.
GUARDTALK_FACE_FILTER :=
