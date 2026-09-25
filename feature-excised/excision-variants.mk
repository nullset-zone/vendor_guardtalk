# GuardTalkOS — shared excision VARIANT REGISTRY (data, not per-device filter files).
#
# T-PORT-EXCISION-MATRIX (P0, DEC-PORT-GEN8910-001/002).
#
# This file is the SINGLE SOURCE OF TRUTH for "which excision variant does a
# Pixel codename use". It is pure data: it defines no filter behaviour itself.
# The resolver (excision-variant-select.mk) reads it and FAILS LOUDLY
# ($(error)) when a device has no variant entry — the exact silent-no-op defect
# that motivated T-PORT-SHARED-CORE-FIX.
#
# Why variants are keyed on the KERNEL FAMILY and not only on the SoC
# ------------------------------------------------------------------
# The dispatch card assumed "per SoC" is enough. Direct inspection of the
# upstream kernel blocklists proves it is NOT (Law 7 / Law 16 — evidence over
# assertion): the Wi-Fi module and touch driver differ *within* a SoC because
# each device family ships its own kernel tree:
#
#   zuma    : akita        -> bcmdhd4383 / goodix_brl_touch
#             shusky       -> bcmdhd4398 / goodix_brl_touch + sec_touch
#   zumapro : caimito      -> bcmdhd4390 / syna_touch + sec_touch
#             comet        -> bcmdhd4390 / goodix_brl_touch + syna_touch + sec_touch
#             tegu         -> bcmdhd4383 / syna_touch
#             stallion     -> bcmdhd4383 / focal_touch.ko
#   laguna  : muzel        -> bcmdhd4383 + bcmdhd4390 / syna_touch + focal_touch + fst2
#             rango        -> bcmdhd4383 + bcmdhd4390 / syna_touch + focal_touch + fst2
#
# A per-SoC-only table would silently hand `shiba`/`husky` the akita blocklist
# (wrong Wi-Fi driver) and `tegu`/`stallion` the caimito blocklist. Keying on
# the kernel family closes that hole. The SoC is carried as a *column* so the
# per-SoC view the card asked for is still published (see docs/EXCISION_MATRIX.md
# which renders both views).
#
# Evidence anchors (all re-derivable, see docs/EXCISION_MATRIX.md §Evidence):
#   device/google/<family>-kernels/<ver>/grapheneos[-/variant]/vendor_dlkm.modules.blocklist
#   vendor/adevtool/vendor-skels/google_devices/<dev>/<dev>.mk   (fingerprint stack)
#   vendor/adevtool/config/mk/google_devices/device/<dev>/device.mk (platform ref)

# ---------------------------------------------------------------------------
# 0. Re-include guard.
# ---------------------------------------------------------------------------
ifndef GUARDTALK_EXCISION_VARIANTS_INCLUDED
GUARDTALK_EXCISION_VARIANTS_INCLUDED := true

# ---------------------------------------------------------------------------
# 1. Variant keys (one per kernel family / excision profile).
# ---------------------------------------------------------------------------
GUARDTALK_EXCISION_VARIANTS := \
    zuma_shusky \
    zuma_akita \
    zumapro_caimito \
    zumapro_comet \
    zumapro_tegu \
    zumapro_stallion \
    laguna_muzel \
    laguna_rango

# ---------------------------------------------------------------------------
# 2. Device -> variant map. Every in-program codename MUST have a row here or
#    the resolver aborts the build. Gen 6/7 codenames are deliberately absent
#    (out of program scope, DEC-PORT-GEN8910-001 §7).
# ---------------------------------------------------------------------------
GT_DEVICE_VARIANT_shiba   := zuma_shusky
GT_DEVICE_VARIANT_husky   := zuma_shusky
GT_DEVICE_VARIANT_akita   := zuma_akita
GT_DEVICE_VARIANT_tokay   := zumapro_caimito
GT_DEVICE_VARIANT_caiman  := zumapro_caimito
GT_DEVICE_VARIANT_komodo  := zumapro_caimito
GT_DEVICE_VARIANT_comet   := zumapro_comet
GT_DEVICE_VARIANT_tegu    := zumapro_tegu
GT_DEVICE_VARIANT_stallion := zumapro_stallion
GT_DEVICE_VARIANT_frankel := laguna_muzel
GT_DEVICE_VARIANT_blazer  := laguna_muzel
GT_DEVICE_VARIANT_mustang := laguna_muzel
GT_DEVICE_VARIANT_rango   := laguna_rango

# ---------------------------------------------------------------------------
# 3. Per-variant data. Columns requested by the card:
#      SOC            — zuma | zumapro | laguna
#      KERNEL_FAMILY  — device/google/<family>-kernels
#      WIFI_MODULES   — upstream-blocklisted Wi-Fi driver(s)
#      TOUCH_MODULES  — upstream-blocklisted touch driver(s)
#      FP_STACK       — goodix | qfp   (fingerprint HAL family)
#      RADIO_SET      — modem/telephony stack excised by radio-excised/
#      BLOCKLIST      — canonical vendor_dlkm blocklist for the variant
# ---------------------------------------------------------------------------

# --- zuma / shusky (Pixel 8, Pixel 8 Pro) ---------------------------------
GT_VARIANT_zuma_shusky_SOC           := zuma
GT_VARIANT_zuma_shusky_KERNEL_FAMILY := shusky
GT_VARIANT_zuma_shusky_WIFI_MODULES  := bcmdhd4398
GT_VARIANT_zuma_shusky_TOUCH_MODULES := goodix_brl_touch sec_touch
GT_VARIANT_zuma_shusky_FP_STACK      := goodix
GT_VARIANT_zuma_shusky_RADIO_SET     := shannon
GT_VARIANT_zuma_shusky_BLOCKLIST     := vendor/guardtalk/feature-excised/variants/zuma_shusky/vendor_dlkm.modules.blocklist

# --- zuma / akita (Pixel 8a) ----------------------------------------------
GT_VARIANT_zuma_akita_SOC           := zuma
GT_VARIANT_zuma_akita_KERNEL_FAMILY := akita
GT_VARIANT_zuma_akita_WIFI_MODULES  := bcmdhd4383
GT_VARIANT_zuma_akita_TOUCH_MODULES := goodix_brl_touch
GT_VARIANT_zuma_akita_FP_STACK      := goodix
GT_VARIANT_zuma_akita_RADIO_SET     := shannon
GT_VARIANT_zuma_akita_BLOCKLIST     := vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist

# --- zumapro / caimito (Pixel 9, 9 Pro, 9 Pro XL) -------------------------
GT_VARIANT_zumapro_caimito_SOC           := zumapro
GT_VARIANT_zumapro_caimito_KERNEL_FAMILY := caimito
GT_VARIANT_zumapro_caimito_WIFI_MODULES  := bcmdhd4390
GT_VARIANT_zumapro_caimito_TOUCH_MODULES := syna_touch sec_touch
GT_VARIANT_zumapro_caimito_FP_STACK      := qfp
GT_VARIANT_zumapro_caimito_RADIO_SET     := shannon
GT_VARIANT_zumapro_caimito_BLOCKLIST     := vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist

# --- zumapro / comet (Pixel 9 Pro Fold) -----------------------------------
GT_VARIANT_zumapro_comet_SOC           := zumapro
GT_VARIANT_zumapro_comet_KERNEL_FAMILY := comet
GT_VARIANT_zumapro_comet_WIFI_MODULES  := bcmdhd4390
GT_VARIANT_zumapro_comet_TOUCH_MODULES := goodix_brl_touch syna_touch sec_touch
GT_VARIANT_zumapro_comet_FP_STACK      := goodix
GT_VARIANT_zumapro_comet_RADIO_SET     := shannon
GT_VARIANT_zumapro_comet_BLOCKLIST     := vendor/guardtalk/feature-excised/variants/zumapro_comet/vendor_dlkm.modules.blocklist

# --- zumapro / tegu (Pixel 9a) --------------------------------------------
GT_VARIANT_zumapro_tegu_SOC           := zumapro
GT_VARIANT_zumapro_tegu_KERNEL_FAMILY := tegu
GT_VARIANT_zumapro_tegu_WIFI_MODULES  := bcmdhd4383
GT_VARIANT_zumapro_tegu_TOUCH_MODULES := syna_touch
GT_VARIANT_zumapro_tegu_FP_STACK      := goodix
GT_VARIANT_zumapro_tegu_RADIO_SET     := shannon
GT_VARIANT_zumapro_tegu_BLOCKLIST     := vendor/guardtalk/feature-excised/variants/zumapro_tegu/vendor_dlkm.modules.blocklist

# --- zumapro / stallion (Pixel 10a) ---------------------------------------
GT_VARIANT_zumapro_stallion_SOC           := zumapro
GT_VARIANT_zumapro_stallion_KERNEL_FAMILY := stallion
GT_VARIANT_zumapro_stallion_WIFI_MODULES  := bcmdhd4383
GT_VARIANT_zumapro_stallion_TOUCH_MODULES := focal_touch
GT_VARIANT_zumapro_stallion_FP_STACK      := goodix
GT_VARIANT_zumapro_stallion_RADIO_SET     := shannon
GT_VARIANT_zumapro_stallion_BLOCKLIST     := vendor/guardtalk/feature-excised/variants/zumapro_stallion/vendor_dlkm.modules.blocklist

# --- laguna / muzel (Pixel 10, 10 Pro, 10 Pro XL) -------------------------
GT_VARIANT_laguna_muzel_SOC           := laguna
GT_VARIANT_laguna_muzel_KERNEL_FAMILY := laguna
GT_VARIANT_laguna_muzel_WIFI_MODULES  := bcmdhd4383 bcmdhd4390
GT_VARIANT_laguna_muzel_TOUCH_MODULES := syna_touch focal_touch fst2
GT_VARIANT_laguna_muzel_FP_STACK      := qfp
GT_VARIANT_laguna_muzel_RADIO_SET     := shannon
GT_VARIANT_laguna_muzel_BLOCKLIST     := vendor/guardtalk/feature-excised/variants/laguna_muzel/vendor_dlkm.modules.blocklist

# --- laguna / rango (Pixel 10 Pro Fold) -----------------------------------
GT_VARIANT_laguna_rango_SOC           := laguna
GT_VARIANT_laguna_rango_KERNEL_FAMILY := laguna
GT_VARIANT_laguna_rango_WIFI_MODULES  := bcmdhd4383 bcmdhd4390
GT_VARIANT_laguna_rango_TOUCH_MODULES := syna_touch focal_touch fst2
GT_VARIANT_laguna_rango_FP_STACK      := goodix
GT_VARIANT_laguna_rango_RADIO_SET     := shannon
GT_VARIANT_laguna_rango_BLOCKLIST     := vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist

# ---------------------------------------------------------------------------
# 4. Per-device blocklist overrides.
#    A device MAY pin its own blocklist file (legacy QA-anchored paths, or a
#    verified device-local delta). When it does, the resolver requires the
#    override to be token-identical to the variant's canonical blocklist, so a
#    per-device copy can never silently drift off its variant.
#    Only overrides that DIFFER from the canonical file need a row.
# ---------------------------------------------------------------------------
GT_DEVICE_BLOCKLIST_komodo := vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist

# ---------------------------------------------------------------------------
# 5. Fingerprint tokens per variant.
#    The shared fp-excised.mk filter applies the UNION of these (plus COMMON)
#    so that adding a variant automatically extends the filter — the filter is
#    data-driven, never hand-maintained in two places. filter-out is
#    idempotent, so a superset is safe (T-PORT-SHARED-CORE-FIX invariant).
# ---------------------------------------------------------------------------
GT_EXCISION_FP_TOKENS_COMMON := \
    android.hardware.biometrics.fingerprint \
    com.google.hardware.biometrics.fingerprint \
    com.android.hardware.biometrics.fingerprint \
    android.hardware.fingerprint.prebuilt

GT_EXCISION_FP_TOKENS_QFP := \
    vendor.qti.hardware.fingerprint \
    dump_fingerprint \
    qfp-daemon

GT_EXCISION_FP_TOKENS_GOODIX := \
    vendor.goodix.hardware.biometrics.fingerprint \
    fingerprint-service.goodix \
    libvendor.goodix.hardware.biometrics.fingerprint \
    goodixfingerprint \
    goodix_sfps \
    goodixbinderservice

# Per-variant FP token selection (data).
GT_VARIANT_zuma_shusky_FP_TOKENS       := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zuma_akita_FP_TOKENS        := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zumapro_caimito_FP_TOKENS   := $(GT_EXCISION_FP_TOKENS_QFP)
GT_VARIANT_zumapro_comet_FP_TOKENS     := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zumapro_tegu_FP_TOKENS      := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zumapro_stallion_FP_TOKENS  := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_laguna_muzel_FP_TOKENS      := $(GT_EXCISION_FP_TOKENS_QFP)
GT_VARIANT_laguna_rango_FP_TOKENS      := $(GT_EXCISION_FP_TOKENS_GOODIX)

# Derived union used by fp-excised.mk (deterministic; sorted).
GT_EXCISION_FP_DROP_PATTERNS := $(sort \
    $(GT_EXCISION_FP_TOKENS_COMMON) \
    $(foreach _gt_v,$(GUARDTALK_EXCISION_VARIANTS),$(GT_VARIANT_$(_gt_v)_FP_TOKENS)))
_gt_v :=

# Frozen baseline pattern set that fp-excised.mk shipped BEFORE this card.
# The union derived above MUST cover it; the resolver errors if it does not,
# so a future registry edit can never silently narrow the fingerprint excision.
GT_EXCISION_FP_DROP_BASELINE := \
    android.hardware.biometrics.fingerprint \
    com.google.hardware.biometrics.fingerprint \
    com.android.hardware.biometrics.fingerprint \
    vendor.qti.hardware.fingerprint \
    dump_fingerprint \
    qfp-daemon \
    android.hardware.fingerprint.prebuilt \
    vendor.goodix.hardware.biometrics.fingerprint \
    fingerprint-service.goodix \
    libvendor.goodix.hardware.biometrics.fingerprint \
    goodixfingerprint \
    goodix_sfps \
    goodixbinderservice

endif # GUARDTALK_EXCISION_VARIANTS_INCLUDED
