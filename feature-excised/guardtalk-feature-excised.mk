# vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk
#
# Wave 2 feature-excision bridge. Included from
# vendor/guardtalk/radio-excised/product-config-late.mk (which itself runs from
# build/make/core/product_config.mk after all inherit-product merges), so
# PRODUCT_PACKAGES / PRODUCT_COPY_FILES are fully populated before any
# filter-out runs here.
#
# Gating: GUARDTALK_FEATURE_EXCISED_WAVE2 (set in guardtalk-flags.mk, loaded
# first from device.mk). When false, this entire block is a no-op and the
# Wave 2 excision increments are inert.
#
# Inclusion order matters: apps/nfc/fp/loc excision files use late
# filter-out on PRODUCT_PACKAGES, so they MUST run after inherit-product
# merges (guaranteed by the product-config-late.mk hook). feature-overlays.mk
# ADDS overlay packages to PRODUCT_PACKAGES, so it runs after the filter-outs
# to guarantee the GuardTalk overlays are never accidentally stripped by a
# later excision filter.
#
# ---------------------------------------------------------------------------
# LAW 7 HONESTY POSTURE (F-EXCISE-CLAIM-HONESTY, 2026-09-26) — READ FIRST.
# Every claim in this file and the files it includes is a BUILD-SOURCE claim
# about what the late filter-outs drop from PRODUCT_PACKAGES /
# PRODUCT_COPY_FILES. It is NOT a claim about the shipped image. At this
# revision no lane has re-stamped or boot-verified (RESTAMP_PERFORMED=false,
# BOOT_VERIFIED=false), and shipped stamps have been independently shown to
# still carry artifacts (e.g. bluetooth_audio.xml present 13/13; the laguna
# vendor_dlkm blocklists carry 0 `nitrous` lines). Per A-EXCISE-AIRGAP-MATRIX a
# module present in a shipped `modules.load` and unmatched by
# `modules.blocklist` LOADS AT BOOT (Tier C); the Tier A/B/C adjudication lives
# in that audit, not here. Do not read any statement below as "removed from the
# shipped image" — a source-level excision only becomes a shipped fact after a
# re-stamp.
# ---------------------------------------------------------------------------
#
# T-REMEDIATE-B1-USERBUILD: su / overlay_remounter late filter lives in
# userbuild-excised.mk and is included from product-config-late.mk (after
# this bridge) so PRODUCT_PACKAGES_DEBUG is fully merged.
#
# Self-set the flag here (mirrors guardtalk-radio-excised.mk:3 setting
# GUARDTALK_RADIO_EXCISED := true). NOTE (corrected 2026-09-26 by
# F-EXCISE-CLAIM-HONESTY): guardtalk-flags.mk IS wired — guardtalk-radio-
# excised.mk:15 `-include`s
# vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk, which sets
# GUARDTALK_FEATURE_EXCISED_WAVE2 := true for all 13 ports, and that runs
# before this bridge from product-config-late.mk. The self-set below is a
# harmless redundant no-op kept as a defensive default for any harness that
# includes this file without the radio bridge. It is NOT tokay-scoped:
# product-config-late.mk gates on GUARDTALK_RADIO_EXCISED (device-driven,
# T-PORT-SHARED-CORE 2026-07-04) for every GuardTalkOS device.
GUARDTALK_FEATURE_EXCISED_WAVE2 := true

ifeq ($(GUARDTALK_FEATURE_EXCISED_WAVE2),true)

# T-PORT-EXCISION-MATRIX (P0): resolve the device's excision variant from the
# shared registry BEFORE any excision file runs, so the fingerprint drop-pattern
# set below is data-driven and an unregistered device fails loudly here instead
# of silently no-opping. Uses PRODUCT_DEVICE (set in generated <codename>.mk).
include vendor/guardtalk/feature-excised/excision-variant-select.mk

# T-W2-I1-UI-APPS — Non-HAL UI app excision (Browser + AppStore + Dialer +
# Messaging + Auditor + ExactCalculator + InfoApp).
include vendor/guardtalk/feature-excised/apps-excised.mk

# T-W2-I2-FP — Fingerprint HAL excision.
# Re-enabled 2026-06-26: the boot failure that caused these to be disabled was
# the SELinux denial on UserRecoveryManagerService, now FIXED (committed in
# system/sepolicy: user_recovery_service type + service_contexts entry). All 4
# HAL excision files run together in this consolidated build.
include vendor/guardtalk/feature-excised/fp-excised.mk

# T-W2-I3-NFC — NFC HAL excision.
include vendor/guardtalk/feature-excised/nfc-excised.mk

# T-W2-I4-BT / T-BT-FULL — Bluetooth HAL excision (userspace layer; the
# kernel-side nitrous blocklist is wired via BoardConfig-excised-late.mk).
include vendor/guardtalk/feature-excised/bt-excised.mk

# T-W2-I5-LOC / T-LOC-FULL — Location/GNSS HAL excision.
include vendor/guardtalk/feature-excised/loc-excised.mk

# T-W2-I6-THEME / F-HOME-LAYOUT — GuardTalk overlay wiring (SystemUI,
# FrameworkBrand, SetupWizard, Launcher). Adds PRODUCT_PACKAGES entries for
# the GuardTalk RROs. Runs AFTER the excision filter-outs above so the
# overlays are never stripped.
include vendor/guardtalk/feature-excised/feature-overlays.mk

# T-ICON-WIRING — GuardTalk icon RRO overlays (5 overlays). Consolidated
# wiring for all icon overlays; runs AFTER the excision filter-outs (same
# rationale as feature-overlays.mk above) so the icon RROs are never
# accidentally stripped. See icon-overlays.mk for the per-overlay rationale.
include vendor/guardtalk/feature-excised/icon-overlays.mk

# Telephony overlay wiring — GuardTalkFrameworksBaseOverlay + GuardTalkSettingsOverlay.
# telephony-features.mk was originally meant to be included from
# guardtalk-tokay.mk (which is never included in the build chain), so the two
# overlays it wires were silently never built. Include it here instead so the
# full overlay set (6 RROs) is wired through the single executing bridge.
include vendor/guardtalk/radio-excised/telephony-features.mk

  # T-W2-I6-THEME / T-BRAND-SWEEP / T-PORT-AKITA-THEME-WIRE — GuardTalk
  # bootanimation + wallpaper wiring via PRODUCT_DEVICE (not tokay-hardcoded).
  # Per-device wrappers under device/<codename>/guardtalk-theme.mk include the
  # shared branding/guardtalk-theme.mk. Fallback to the shared file if a
  # per-device wrapper is missing so lunch stays green for new ports.
  _gt_theme_mk := vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-theme.mk
  ifeq ($(wildcard $(_gt_theme_mk)),)
    _gt_theme_mk := vendor/guardtalk/branding/guardtalk-theme.mk
  endif
  ifneq ($(wildcard $(_gt_theme_mk)),)
    include $(_gt_theme_mk)
  endif


  # T-SEC-P4-PRIVACY / T-SEC-P4-PERMS — packages that lived only in
  # guardtalk-tokay.mk (never inherited). Wire through this live bridge so they
  # enter PRODUCT_PACKAGES for the image (props are live via
  # guardtalk-product-props.mk included from guardtalk-radio-excised.mk).
  PRODUCT_PACKAGES += init.guardtalk.privacy_tmpfs.rc
  PRODUCT_PACKAGES += init.guardtalk.hardening.rc
  PRODUCT_PACKAGES += default-permissions-com.guardtalk.messenger

  # =====================================================================
  # T-PKG-EXCISE-WAVES P2 — APEX-dormant feature-gates (documentation only).
  # No PRODUCT_PACKAGES filter (APEX modules are delivered via mainline and
  # are out of reach of a PRODUCT_PACKAGES filter-out). Grace is achieved via
  # the feature-permission prebuilt XML removal done in prior waves:
  #   - com.android.bluetooth       -> bt-excised.mk (BT feature prebuilts dropped)
  #   - com.android.nfcservices     -> nfc-excised.mk (NFC feature prebuilts dropped)
  #   - com.android.cellbroadcast    -> radio-excised (radio/IMS excision; the
  #                                    legacy CellBroadcastLegacyApp is also
  #                                    filtered in apps-excised.mk P0)
  #   - com.android.adservices       -> feature-permission XML already absent
  #   - com.android.healthfitness     -> feature-permission XML already absent
  #   - com.android.ondevicepersonalization -> feature-permission XML already absent
  #   - com.android.uwb              -> feature-permission XML already absent
  #   - com.android.profiling        -> feature-permission XML already absent
  #   - com.android.uprobestats      -> feature-permission XML already absent
  #   - com.android.devicelock       -> PRODUCT_PACKAGES filter in
  #                                    devicelock-apex-excised.mk (T-REMEDIATE-B2-APEX);
  #                                    feature-permission XML already absent (defence)
  # With the feature declarations gone, hasSystemFeature() returns false for
  # each corresponding PackageManager.FEATURE_* constant, so the APEX mainline
  # stack stays dormant (its components key off the feature flags at runtime)
  # and Settings/SystemUI hide all entry points. No further action required.
  #
  # KEPT ACTIVE (conservative): com.android.appsearch. SettingsIntelligence may
  # depend on AppSearch for search indexing; excising it risks breaking the
  # Settings search UI. Left in place pending a dedicated dependency audit.
  #
  # T-APEX-BCP-WAVE (2026-07-02) — Cat 3 lockstep BCP excision was DESIGNED to
  # drop the 3 APEX above (adservices, healthfitness,
  # ondevicepersonalization), but it is DISABLED: the 2026-07-04 tokay
  # userdebug Zygote NoClassDefFoundError boot loop forced a revert, and every
  # stage in apex-bcp-excised.mk is marked [DISABLED — see note above].
  # HONEST POSTURE (Law 7, corrected 2026-09-26 by F-EXCISE-CLAIM-HONESTY):
  # these 3 APEX are feature-gated DORMANT, not removed — the APEX is present
  # in the built/shipped image on 13/13 (umbrella §5 `apex_dormant_set` =
  # Tier B; A-EXCISE-HONESTY F-1; pre-finding E-16). The feature-permission
  # XML removal above is the dormancy mechanism, not defence-in-depth behind a
  # deletion. See apex-bcp-excised.mk for the DISABLED rationale, the
  # prerequisites to re-enable (SystemServiceRegistry optional imports), and
  # the runtime smoke-test requirement (Q-APEX-BCP). Source-level only: no
  # re-stamp, RESTAMP_PERFORMED=false, BOOT_VERIFIED=false (DEC-009).
  # =====================================================================

# T-APEX-BCP-WAVE — Cat 3 mainline APEX lockstep BCP excision. MUST run
# AFTER apps-excised.mk (so its PRODUCT_PACKAGES filter-out has already
# fired) and AFTER all upstream inherit-product merges (guaranteed by the
# product-config-late.mk hook that pulls this bridge in).
#
# NOTE: uses `include` (not `inherit-product-if-exists`) because this bridge
# runs from product-config-late.mk AFTER import-nodes has already processed
# the INHERIT_PRODUCTS chain — a late `inherit-product-if-exists` would
# silently never fire. Matches the proven pattern used by every sibling
# excision file in this directory (apps-excised.mk, nfc-excised.mk, etc.).
include vendor/guardtalk/feature-excised/apex-bcp-excised.mk

# T-REMEDIATE-B2-APEX — DeviceLock APEX PRODUCT_PACKAGES filter. Dedicated
# file (not the GmsCompat stanza). After apps-excised KEEP restore so
# HTMLViewer/UMP cannot be stripped here.
include vendor/guardtalk/feature-excised/devicelock-apex-excised.mk

endif # GUARDTALK_FEATURE_EXCISED_WAVE2
