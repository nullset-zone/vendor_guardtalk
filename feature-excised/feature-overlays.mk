# vendor/guardtalk/feature-excised/feature-overlays.mk
# Overlay wiring for the GuardTalk vendor layer.
#
# This file is included from guardtalk-feature-excised.mk (gated on
# GUARDTALK_FEATURE_EXCISED_WAVE2) so the overlay packages are built and
# installed only when Wave 2 feature excision is enabled.
#
# Overlay inventory (5 RROs total):
#   - GuardTalkFrameworksBaseOverlay    — wired via radio-excised/telephony-features.mk (HAL excision grace)
#   - GuardTalkSettingsOverlay          — wired via radio-excised/telephony-features.mk (HAL excision grace)
#   - GuardTalkSystemUIOverlay          — wired HERE (T-W2-I2-FP, HAL excision grace)
#   - GuardTalkFrameworkBrandOverlay    — wired HERE (T-W2-I6-THEME, brand theme)
#   - GuardTalkSetupWizardOverlay       — wired HERE (T-W2-I6-THEME, wizard brand; ties to T-W2-I7-WIZ)
#
# The FrameworksBase + Settings overlays are intentionally NOT re-wired here
# (double-wiring PRODUCT_PACKAGES is a build warning). They are wired once via
# telephony-features.mk and are listed above for documentation only.

# T-W2-I2-FP — SystemUI overlay (HAL excision grace layer).
# PARTITION MATCH (T-HOME-ROOTCAUSE): SystemUI is system_ext_specific, so this
# overlay is system_ext_specific in its Android.bp. DEVICE_PACKAGE_OVERLAYS is
# NOT used — it is a build-time resource resolution path, irrelevant to runtime
# RRO installation, and previously caused mis-packaging into /product/overlay.
PRODUCT_PACKAGES += GuardTalkSystemUIOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkSystemUIOverlay

# T-W2-I6-THEME — GuardTalk brand theme overlays.
# GuardTalkFrameworkBrandOverlay: RRO on `android` (framework-res, in /system).
# Stays product_specific — /product/overlay CAN target /system packages on
# Android 14+ (product > system in partition hierarchy). DEVICE_PACKAGE_OVERLAYS
# is kept here for build-time resource resolution of framework branding.
PRODUCT_PACKAGES += GuardTalkFrameworkBrandOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkFrameworkBrandOverlay

DEVICE_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkFrameworkBrandOverlay

# T-W2-I6-THEME — SetupWizard brand overlay. Supplies GuardTalk brand
# colors + strings to SetupWizard2. Ties to T-W2-I7-WIZ, which adds the
# transparent-black logo source edit in packages/apps/SetupWizard2 and
# confirms the fingerprint enrollment step is removed (T-W2-I2-FP).
# PARTITION MATCH (T-HOME-ROOTCAUSE): SetupWizard2 is system_ext_specific, so
# this overlay is system_ext_specific in its Android.bp. DEVICE_PACKAGE_OVERLAYS
# is NOT used (same rationale as above).
PRODUCT_PACKAGES += GuardTalkSetupWizardOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay

# F-HOME-LAYOUT (FR-E) — Launcher3 default workspace override. Static RRO on
# com.android.launcher3 that replaces default_workspace_*.xml for ALL 9 grids
# (2x2, 3x3, 4x4, 4x5, 5x5, 5x8, 6x5, 7x3, 8x3) — see device_profiles.xml
# grid-options; the active grid for tokay/Pixel 9 is 5_by_5 but ALL grids are
# overridden so the GuardTalk layout wins regardless of which grid Launcher3
# selects at runtime. Ships ONLY GuardTalk app(s) on the default home +
# hotseat; excised apps (Auditor, ExactCalculator, InfoApp, Messaging, Dialer,
# TrichromeChrome, AppStore) are NOT pinned. Layout-only; apps remain in the
# all-apps drawer. Depends on T-RM-APPS excising those packages concurrently.
#
# PARTITION MATCH (T-HOME-ROOTCAUSE): Launcher3 is system_ext_specific, so the
# overlay is system_ext_specific in its Android.bp and installs to
# /system_ext/overlay/. DEVICE_PACKAGE_OVERLAYS / PRODUCT_PACKAGE_OVERLAYS are
# NOT used here — they are build-time resource resolution paths and are
# irrelevant to runtime RRO installation; setting them for a system_ext RRO
# previously caused the overlay to be mis-packaged into /product/overlay where
# OverlayManager silently ignored it (cross-partition static RRO filter on
# Android 14+ SDK 34+). The runtime overlay targetPackage in the APK manifest
# is what matters, plus correct partition placement via system_ext_specific.
PRODUCT_PACKAGES += GuardTalkLauncherOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkLauncherOverlay

