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
#
# T-DEVICE-ALIGN-SHARED-CORE-COUPLING (DEC-DEVICE-ALIGN-004): the file is
# resolved through PRODUCT_DEVICE with a tokay fallback, mirroring the
# production-hardening resolution immediately below, so a device can own its
# ro.guardtalk.* block instead of inheriting tokay's by hardcode. ZERO
# present-day delta, verified: tokay is the only device that has a
# guardtalk-product-props.mk, so all 14 hooked products — and the
# product_config.mk late re-entry, which runs with PRODUCT_DEVICE cleared so
# $(wildcard) misses — still resolve to tokay's file exactly as the pre-card
# hardcode did. Adding vendor/guardtalk/device/<dev>/guardtalk-product-props.mk
# for a device SELECTS that file instead of tokay's (either/or, never a merge),
# so such a file must restate the whole block it wants, not just its delta.
#
# SEMANTICS — ro.guardtalk.radio.excised=1 on a BOARD_WITHOUT_RADIO product
# (tangorpro today; DEC-PORT-TANGORPRO-003). Meaningful but PARTIAL: it asserts
# that the radio/RIL USERSPACE shipped in this tree (google-ril, the radioext
# HAL, modem dump tooling, vendor_manifest_radioext, radio copy-files) was
# removed at the product layer. It does NOT assert, and must not be read as,
# "a cellular modem / baseband firmware was removed": tangorpro has no modem
# hardware and no radio.img, so the HARDWARE half of excision has no subject
# there. On any device this flag alone is a userspace/HAL claim, never a
# hardware claim. persist.radio.disabled=1 above is NOT part of this contract.
_gt_props_mk := vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-product-props.mk
ifeq ($(wildcard $(_gt_props_mk)),)
  _gt_props_mk := vendor/guardtalk/device/tokay/guardtalk-product-props.mk
endif
GT_PRODUCT_PROPS_MK := $(_gt_props_mk)
include $(_gt_props_mk)
_gt_props_mk :=

# T-SEC-P5-HARDEN / T-REMEDIATE-B1-USERBUILD: production hardening markers +
# user-profile props. Per-device mk (komodo has its own); tokay is the
# fallback pattern so other GuardTalk products keep existing wiring.
_gt_harden_mk := vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-production-hardening.mk
ifeq ($(wildcard $(_gt_harden_mk)),)
  _gt_harden_mk := vendor/guardtalk/device/tokay/guardtalk-production-hardening.mk
endif
include $(_gt_harden_mk)
_gt_harden_mk :=
