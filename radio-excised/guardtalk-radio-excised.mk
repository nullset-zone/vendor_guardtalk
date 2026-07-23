# Late product pass — must be `include`d from the device's <codename>.mk
# (not inherit-product). inherit-product clears PRODUCT_* in the child node,
# so filters would see empty lists.
#
# T-PORT-SHARED-CORE (2026-07-04): device-agnostic. The device's
# <codename>.mk must `include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk`
# AFTER it has set PRODUCT_DEVICE (which adevtool-generated <codename>.mk
# always does near the top). We pull the per-device guardtalk-flags.mk
# (GUARDTALK_PRODUCT_MODEL, GUARDTALK_VOICE_FILTER, GUARDTALK_FACE_FILTER,
# GUARDTALK_FEATURE_EXCISED_WAVE2) via PRODUCT_DEVICE so the shared late
# pass picks up per-device config without a separate include-edit per flag.
# The `-include` is a graceful no-op if the device layer has no
# guardtalk-flags.mk yet (Law 9).
GUARDTALK_RADIO_EXCISED := true
-include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk
include vendor/guardtalk/radio-excised/remove-packages.mk
include vendor/guardtalk/radio-excised/filter-copy-files.mk
include vendor/guardtalk/radio-excised/vintf-excised.mk

PRODUCT_PROPERTY_OVERRIDES += \
    persist.radio.disabled=1

# T-SEC-P4-PRIVACY (+ prior security props): live PRODUCT_PROPERTY_OVERRIDES.
# guardtalk-tokay.mk is documentation-only / not inherited — see
# vendor/guardtalk/device/tokay/guardtalk-product-props.mk.
include vendor/guardtalk/device/tokay/guardtalk-product-props.mk

# T-SEC-P5-HARDEN: production hardening markers + user-profile props.
include vendor/guardtalk/device/tokay/guardtalk-production-hardening.mk
