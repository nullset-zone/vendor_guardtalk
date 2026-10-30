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
    laguna_rango \
    gs201_tangorpro

# ---------------------------------------------------------------------------
# 2. Device -> variant map. Every in-program codename MUST have a row here or
#    the resolver aborts the build. Gen 6/7 codenames are deliberately absent
#    (out of program scope, DEC-PORT-GEN8910-001 §7), except `tangorpro`, which
#    is admitted by DEC-PORT-TANGORPRO-002.
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
GT_DEVICE_VARIANT_tangorpro := gs201_tangorpro

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
# BLOCKLIST: LOCATION-convention drift — device-local path, but it IS this
# variant's canonical file (no pin, nothing to drift from). Registered in
# docs/EXCISION_MATRIX.md §4.1: 9 tokens, sorted-token sha256 54996074….
GT_VARIANT_zuma_akita_BLOCKLIST     := vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist

# --- zumapro / caimito (Pixel 9, 9 Pro, 9 Pro XL) -------------------------
GT_VARIANT_zumapro_caimito_SOC           := zumapro
GT_VARIANT_zumapro_caimito_KERNEL_FAMILY := caimito
GT_VARIANT_zumapro_caimito_WIFI_MODULES  := bcmdhd4390
GT_VARIANT_zumapro_caimito_TOUCH_MODULES := syna_touch sec_touch
GT_VARIANT_zumapro_caimito_FP_STACK      := qfp
GT_VARIANT_zumapro_caimito_RADIO_SET     := shannon
# BLOCKLIST: LOCATION-convention drift — FLAT path, but it IS this variant's
# canonical file (no pin). Registered in docs/EXCISION_MATRIX.md §4.1: 14
# tokens, sorted-token sha256 4b404489…, the reference the komodo pin matches.
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
# BLOCKLIST: LOCATION-convention drift — device-local path, but it IS this
# variant's canonical file (no pin). Registered in docs/EXCISION_MATRIX.md §4.1:
# 20 tokens, sorted-token sha256 1069c4d6…, token-identical to the verified
# feature-excised/variants/laguna_rango/ mirror (kept as a second file today;
# re-pointing the registry at it needs the paired QA-gate update, §4.1).
GT_VARIANT_laguna_rango_BLOCKLIST     := vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist

# --- gs201 / tangorpro (Google Pixel Tablet) ------------------------------
# T-PORT-TANGORPRO-EXCISION-VARIANT (P1) — DEC-PORT-TANGORPRO-002 (admitted),
# DEC-PORT-TANGORPRO-003 (no modem HARDWARE, but the RIL/radioext USERSPACE
# ships). NOT copied from any phone variant. Evidence, re-derivable:
#
#   KERNEL_FAMILY  device/google/tangorpro-kernels/6.1/grapheneos/ (the only
#                  tangorpro kernel tree; RELEASE_KERNEL_TANGORPRO_DIR ->
#                  .../6.1/trunk-14096387 -> grapheneos).
#   WIFI_MODULES   NONE. This tree's vendor_dlkm.modules.blocklist has 0 Wi-Fi
#                  lines, and its vendor_dlkm.modules.load loads NO bcmdhd*.ko;
#                  the Wi-Fi driver is synadhd.ko (wlan/dhd43752p), which is NOT
#                  blocklisted. The 6 tokens in the upstream blocklist are listed
#                  verbatim under BLOCKLIST below (rt4539_bl = backlight, never a
#                  touch driver).
#   TOUCH_MODULES  NONE blocklisted: the load list carries nvt_touch.ko, and no
#                  *touch* module is blocklisted (the phones here blocklist
#                  syna_touch / focal_touch / goodix_brl_touch / sec_touch).
#   FP_STACK       goodix — adevtool vendor-skel tangorpro.mk ships
#                  fps_touch_handler/goodixfp.ko (vendor_kernel_boot + vendor_dlkm
#                  .modules.load) and `vendor.goodix.hardware.biometrics.fingerprint`.
#                  NOTE: the tablet ALSO ships the FPC42 family (service.fpc42,
#                  fingerprint-fpc42.rc, fpc42_suez, fpc_util). fp-excised.mk's
#                  token union does not catch fpc42_suez/fpc_util, so those two
#                  SURVIVE on tangorpro — the same pre-existing gap as on comet
#                  (measured: comet leaks the same two). Deliberate, escalated
#                  (Gate-5 F-1/F-2) — widening the union would change the frozen,
#                  size-asserted 13-token contract that this card may not amend.
#                  What IS covered for the FPC42 family here: the fingerprint
#                  VINTF fragment and the `fingerprint-fpc42.rc` init file (see
#                  GT_EXCISION_FP_TOKENS_COPY_FILES).
#   RADIO_SET      shannon_ext — tangorpro has NO modem hardware (no radio.img,
#                  no `require version-baseband=`), yet ships a Samsung SLIS
#                  externals-only RIL: google-ril, libgril_oem-google,
#                  vendor.google.radioext@1.0-service,
#                  adevtool_vintf_fragment_vendor_manifest_radioext.xml,
#                  modem{,_android_property_manager,_log_dumper}. The phones also
#                  carry the internal Shannon IMS/CP stack (rild_exynos, cpif,
#                  ShannonIms/ShannonRcs). Calling this `shannon` would over-claim
#                  a CP stack the device does not have (Law 7).
#   BLOCKLIST      upstream file verbatim (6 tokens) + 'blocklist nitrous': the
#                  tree DOES load bluetooth/broadcom/nitrous.ko, and T-BT-FULL
#                  FR-3 excises it. cpif/cpif_page/shm_ipc are deliberately NOT
#                  added — none of them exists in this tree (adding them would be
#                  inventing entries to imitate the phone rows).
GT_VARIANT_gs201_tangorpro_SOC           := gs201
GT_VARIANT_gs201_tangorpro_KERNEL_FAMILY := tangorpro
GT_VARIANT_gs201_tangorpro_WIFI_MODULES  :=
GT_VARIANT_gs201_tangorpro_TOUCH_MODULES :=
GT_VARIANT_gs201_tangorpro_FP_STACK      := goodix
GT_VARIANT_gs201_tangorpro_RADIO_SET     := shannon_ext
GT_VARIANT_gs201_tangorpro_BLOCKLIST     := vendor/guardtalk/feature-excised/variants/gs201_tangorpro/vendor_dlkm.modules.blocklist

# ---------------------------------------------------------------------------
# 4. Per-device blocklist overrides.
#    A device MAY pin its own blocklist file (legacy QA-anchored paths, or a
#    verified device-local delta). When it does, the resolver requires the
#    override to be token-identical to the variant's canonical blocklist, so a
#    per-device copy can never silently drift off its variant.
#    Only overrides that DIFFER from the canonical file need a row.
#
# BLOCKLIST PATH CONVENTIONS — measured 2026-10-29 (T-DEVICE-ALIGN-REGISTRY).
# The registry above uses THREE location conventions. Counting the 9
# GT_VARIANT_*_BLOCKLIST assignments (not the files on disk):
#
#   6 x feature-excised/variants/<variant>/vendor_dlkm.modules.blocklist
#        zuma_shusky, zumapro_comet, zumapro_tegu, zumapro_stallion,
#        laguna_muzel, gs201_tangorpro                        (the convention)
#   1 x feature-excised/vendor_dlkm.modules.blocklist   (FLAT)  zumapro_caimito
#   2 x device/<codename>/vendor_dlkm.modules.blocklist (LOCAL) zuma_akita,
#                                                               laguna_rango
#   + 1 separate override mechanism: GT_DEVICE_BLOCKLIST_komodo (below), which
#     is the ONLY entry that is a *pin* (it points somewhere other than
#     GT_VARIANT_zumapro_caimito_BLOCKLIST).
#
# The flat and the two device-local paths are NOT pins: each one IS the
# variant's canonical file (GT_VARIANT_<v>_BLOCKLIST points straight at it), so
# there is no second copy to drift from. They were nevertheless undocumented, so
# a reader could not tell a sanctioned location from an accidental one. They are
# now registered in docs/EXCISION_MATRIX.md §4.1 with token counts and hashes.
#
# DO NOT re-point any of the three at feature-excised/variants/<variant>/ in
# isolation. The resolved path is anchored by
# docs/qa/verify_port_excision_matrix_static.sh case5 (zero-regression table) and
# by device/akita/BoardConfig-excised-late.mk (literal path), so a repoint must
# land together with the paired QA-gate update — see §4.1 "deferred
# normalisation". This file must stay runnable with the current QA script.
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
# Fingerprint init .rc basenames (the Layer-4 copy-file filter).
# T-PORT-TANGORPRO-EXCISION-VARIANT: the FPC42 family has TWO .rc names
# (tangorpro ships `fingerprint-fpc42.rc`, the phones ship `fingerprint-fpc42_fw49.rc`);
# only the _fw49 one was hardcoded before, so tangorpro would have kept an init
# service for a HAL binary that Layer 1 had already dropped (the G6 orphan class
# flagged on comet). fp-excised.mk now consumes this list; its literal list is
# kept only as the standalone-include fallback.
GT_EXCISION_FP_TOKENS_COPY_FILES := \
    init.fingerprint.dump.rc \
    qfp-daemon.rc \
    fingerprint-goodix.rc \
    fingerprint-fpc42.rc \
    fingerprint-fpc42_fw49.rc

# Per-variant FP token selection (data).
GT_VARIANT_zuma_shusky_FP_TOKENS       := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zuma_akita_FP_TOKENS        := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zumapro_caimito_FP_TOKENS   := $(GT_EXCISION_FP_TOKENS_QFP)
GT_VARIANT_zumapro_comet_FP_TOKENS     := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zumapro_tegu_FP_TOKENS      := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_zumapro_stallion_FP_TOKENS  := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_laguna_muzel_FP_TOKENS      := $(GT_EXCISION_FP_TOKENS_QFP)
GT_VARIANT_laguna_rango_FP_TOKENS      := $(GT_EXCISION_FP_TOKENS_GOODIX)
GT_VARIANT_gs201_tangorpro_FP_TOKENS   := $(GT_EXCISION_FP_TOKENS_GOODIX)
# `FPC` is documented here, deliberately WITHOUT feeding the drop union: that
# union is a FROZEN, size-asserted contract (verify_port_excision_matrix_static.sh
# case6 asserts exactly the 13 baseline tokens, gates_required: none for this card,
# so the guard may not be amended). Widening it is escalated as Gate-5 F-1 below.
# The separate FPC42 leak (fpc42_suez/fpc_util surviving on the FPC devices,
# including comet — a PRE-EXISTING defect) is Gate-5 F-2 and is likewise not
# fixed here.
GT_VARIANT_gs201_tangorpro_FP_FAMILY    := goodix,fpc42

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
