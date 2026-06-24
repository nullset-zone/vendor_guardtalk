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
PRODUCT_PACKAGES += GuardTalkSystemUIOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkSystemUIOverlay

DEVICE_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkSystemUIOverlay

# T-W2-I6-THEME — GuardTalk brand theme overlays.
# GuardTalkFrameworkBrandOverlay: RRO on `android` (framework). Replaces
# upstream/GrapheneOS-branded framework UI surfaces (OS name, device name,
# manufacturer string, brand colors) with GuardTalk. PLACEHOLDER values until
# the operator delivers the brand kit; see vendor/guardtalk/branding/README.md.
PRODUCT_PACKAGES += GuardTalkFrameworkBrandOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkFrameworkBrandOverlay

DEVICE_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkFrameworkBrandOverlay

# T-W2-I6-THEME — SetupWizard brand overlay. Supplies GuardTalk brand
# colors + strings to SetupWizard2. Ties to T-W2-I7-WIZ, which adds the
# transparent-black logo source edit in packages/apps/SetupWizard2 and
# confirms the fingerprint enrollment step is removed (T-W2-I2-FP).
PRODUCT_PACKAGES += GuardTalkSetupWizardOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay

DEVICE_PACKAGE_OVERLAYS += \
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
# Wiring: BOTH DEVICE_PACKAGE_OVERLAYS and PRODUCT_PACKAGE_OVERLAYS are set.
# DEVICE_PACKAGE_OVERLAYS is the historical AOSP mechanism; for product-built
# apps like Launcher3 (Trebuchet/Tips) the RRO must also be reachable via the
# product overlay path. The operator reported (F-HOME-LAYOUT) that with
# DEVICE_PACKAGE_OVERLAYS alone the overlay APK shipped in the image
# (product/overlay/android/GuardTalkLauncherOverlay.apk) but the layout was
# NOT applied at runtime on the flashed Pixel 9 — stock Gallery/Contacts/
# Camera icons persisted. Adding PRODUCT_PACKAGE_OVERLAYS ensures the overlay
# is registered in the product partition's overlay lookup used by the
# Launcher3 process. Keeping both is harmless (idempotent path registration).
PRODUCT_PACKAGES += GuardTalkLauncherOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkLauncherOverlay

DEVICE_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkLauncherOverlay

PRODUCT_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkLauncherOverlay

