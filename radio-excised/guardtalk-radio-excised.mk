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

# T-PORT-EXCISION-MATRIX (P0): resolve the device's excision variant from the
# shared registry (data) and fail loudly if this product has no variant entry —
# the silent-no-op defect that motivated T-PORT-SHARED-CORE-FIX. Also exports
# GT_VARIANT_* (Wi-Fi module / touch / fingerprint stack / radio set) for the
# shared core and the REGEN_HOOKS recipe.
include vendor/guardtalk/feature-excised/excision-variant-select.mk

include vendor/guardtalk/radio-excised/remove-packages.mk
include vendor/guardtalk/radio-excised/filter-copy-files.mk
include vendor/guardtalk/radio-excised/vintf-excised.mk

PRODUCT_PROPERTY_OVERRIDES += \
    persist.radio.disabled=1

# T-SEC-P4-PRIVACY (+ prior security props) / T-REMEDIATE-B6-PROP-REACHABILITY:
# live include. ro.guardtalk.* product-policy flags inside are emitted with
# PRODUCT_SYSTEM_PROPERTIES (-> system/build.prop, loaded by `init`).
# guardtalk-tokay.mk is documentation-only / not inherited — see
# vendor/guardtalk/device/tokay/guardtalk-product-props.mk.
include vendor/guardtalk/device/tokay/guardtalk-product-props.mk

# T-SEC-P5-HARDEN / T-REMEDIATE-B1-USERBUILD: production hardening markers +
# user-profile props. Per-device mk (komodo has its own); tokay is the
# fallback pattern so other GuardTalk products keep existing wiring.
_gt_harden_mk := vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-production-hardening.mk
ifeq ($(wildcard $(_gt_harden_mk)),)
  _gt_harden_mk := vendor/guardtalk/device/tokay/guardtalk-production-hardening.mk
endif
include $(_gt_harden_mk)
_gt_harden_mk :=
