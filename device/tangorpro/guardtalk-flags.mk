# Loaded from vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk via
# -include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk.
# BRANDING ONLY (DEC-DEVICE-ALIGN-020): tangorpro is a radio/RIL userspace
# excision port with no modem hardware (DEC-PORT-TANGORPRO-003), so the only
# capability this file adds is the model rebrand.
#
# WHY THE VOICE AND FACE FILTERS ARE DELIBERATELY ABSENT — THIS IS NOT A BUG:
# tangorpro ships no guardtalk-audio.mk and no guardtalk-camera.mk, so declaring
# either filter here would assert a privacy filter the image does not build —
# the exact false-claim class T-DEVICE-ALIGN-VOICE-FLAG-TRUTH removed from nine
# phones. Face is additionally OFF fleet-wide by design (DEC-DEVICE-ALIGN-011).
# Do not "complete" this file by adding either one; that would be a regression.
#
# PRODUCT_BRAND / PRODUCT_MANUFACTURER and the *_FOR_* variants stay upstream
# (google/Google) exactly as on every other device: they back the hardware brand
# claim and must keep matching the signed vendor image for Play Integrity /
# keymint (radio-excised/product-config-late.mk).
GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel Tablet
