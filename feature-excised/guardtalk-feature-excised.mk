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
# Self-set the flag here (mirrors guardtalk-radio-excised.mk:3 setting
# GUARDTALK_RADIO_EXCISED := true). guardtalk-flags.mk is not yet wired into
# the device makefile chain, so without this self-set the gate would always
# be false and the entire Wave 2 excision (apps/nfc/fp/loc + overlays) would
# be inert. This self-set is harmless: the bridge is only included for the
# tokay product path (gated in product-config-late.mk), so the flag is
# effectively tokay-scoped.
GUARDTALK_FEATURE_EXCISED_WAVE2 := true

ifeq ($(GUARDTALK_FEATURE_EXCISED_WAVE2),true)

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

# Telephony overlay wiring — GuardTalkFrameworksBaseOverlay + GuardTalkSettingsOverlay.
# telephony-features.mk was originally meant to be included from
# guardtalk-tokay.mk (which is never included in the build chain), so the two
# overlays it wires were silently never built. Include it here instead so the
# full overlay set (6 RROs) is wired through the single executing bridge.
include vendor/guardtalk/radio-excised/telephony-features.mk

# T-W2-I6-THEME — GuardTalk bootanimation + wallpaper wiring. guardtalk-theme.mk
# was originally meant to be included from guardtalk-tokay.mk (never included in
# the build chain), so the GuardTalk bootanimation.zip was silently never copied
# into the image. Include it here so the brand assets (which exist in
# vendor/guardtalk/branding/bootanimation/) are picked up. The makefile is
# self-gated (ifeq wildcard) on asset existence.
include vendor/guardtalk/device/tokay/guardtalk-theme.mk

endif # GUARDTALK_FEATURE_EXCISED_WAVE2
