# Loaded first from device.mk so later inherits can branch on this flag.
GUARDTALK_RADIO_EXCISED := true
# Wave 2 feature excision master gate. T-W2-I1-UI-APPS currently enables only
# the non-HAL UI app removal (Browser + AppStore + Dialer) via apps-excised.mk.
# Later increments (bt/nfc/fp/loc) wire their own <sub>-excised.mk files into
# guardtalk-feature-excised.mk without flipping this flag off.
GUARDTALK_FEATURE_EXCISED_WAVE2 := true
GUARDTALK_VOICE_FILTER := true
GUARDTALK_FACE_FILTER := true
