# GuardTalkOS — komodo production hardening (T-REMEDIATE-B1-USERBUILD).
#
# LIVE: included from vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
# via per-device $(PRODUCT_DEVICE) lookup (tokay file is the fallback pattern).
#
# Production lunch: komodo-trunk_staging-user
#   TARGET_BUILD_VARIANT=user
#   AOSP gen_build_prop.py maps user → ro.debuggable=0, ro.adb.secure=1
#   Do NOT PRODUCT-force ro.debuggable=0 (that lies about userdebug).
#
# Engineering root is NOT this product. Sidecar lunch:
#   komodo-trunk_staging-userdebug
#   See vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md
#
# Release keys: PRODUCT_DEFAULT_DEV_CERTIFICATE points at the operator-supplied
# releasekey stem (no *.pk8 / *.pem in git). Unsigned lunch reports
# BUILD_KEYS=dev-keys; post-sign (RUNBOOK) yields release-keys.
# AVB (T-REMEDIATE-B1-AVB): user BoardConfig sets BOARD_AVB_KEY_PATH to
# vendor/guardtalk/branding/signing-keys/avb.pem (gitignored; operator copies
# or overrides to the offline path). Do not invent release-keys or green boot
# on this host. Custom-key lock color is documented in RUNBOOK (Pixel custom-key
# yellow; operator-goal green HOLD). Item 7 (T-REMEDIATE-B1-DURESS-USB):
# komodo user default-enables USB duress wipe; UsbPortSecurityHooks accepts
# verifiedbootstate yellow or green. Do not PRODUCT-lie green.

# T-REMEDIATE-B6-PROP-REACHABILITY: ro.guardtalk.* product-policy flags go to
# system/build.prop (PRODUCT_SYSTEM_PROPERTIES, loaded by `init`). Using
# PRODUCT_PROPERTY_OVERRIDES on a full-treble product routes them to
# vendor/build.prop (loaded by `vendor_init`, which cannot set them).
PRODUCT_SYSTEM_PROPERTIES += \
    ro.guardtalk.production_hardening=1 \
    ro.guardtalk.block_unknown_sources=1 \
    ro.guardtalk.restrict_accessibility_services=1 \
    ro.guardtalk.restrict_display_overlays=1 \
    ro.guardtalk.restrict_dynamic_code=1 \
    ro.guardtalk.selinux_enforcing_required=1 \
    ro.guardtalk.verified_boot_required=1 \
    ro.guardtalk.keymint_required=1 \
    ro.guardtalk.sysctl_hardening=1

# SPL pin of record (bulletin pull 2026-09-16). Live PLATFORM_SECURITY_PATCH
# still comes from RELEASE_PLATFORM_SECURITY_PATCH (trunk_staging flag file is
# outside this card's target paths). See vendor/guardtalk/docs/SPL_PIN.md.
GUARDTALK_SPL_PIN := 2026-09-05
GUARDTALK_SPL_BULLETIN := https://source.android.com/docs/security/bulletin/2026/2026-09-01
GUARDTALK_SPL_PIXEL_BULLETIN := https://source.android.com/docs/security/bulletin/pixel/2026/2026-09-01

ifeq ($(TARGET_BUILD_VARIANT),user)
    PRODUCT_SYSTEM_PROPERTIES += ro.guardtalk.production_profile=1
    PRODUCT_PROPERTY_OVERRIDES += \
        ro.adb.secure=1 \
        vendor.guardtalk.usb_duress_wipe.enabled=1

# Operator-supplied cert stem. Private keys must never land in this tree.
# testkey is the AOSP default; this path is the production release-keys wiring.
PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/guardtalk/branding/signing-keys/releasekey
endif

# T-REMEDIATE-B2-TELEMETRY (items 11, 14): silentlog / logpersistd / RIL disk
# logs off; EXIF make/model false. Komodo-only; not EXCISE/KERNEL files.
include vendor/guardtalk/device/komodo/guardtalk-telemetry.mk

# T-REMEDIATE-B4-MESSENGER (item 19): bake Jami GuardTalk Messenger into the
# user image. Not a Gateway sideload (unknown-APK block). No store/browser.
include vendor/guardtalk/device/komodo/guardtalk-messenger.mk

# T-REMEDIATE-B5-DEFAULTS (item 24): roaming false, MTP off, bug_report=0,
# lock_screen_show_notifications=0. Overlay props only; su/SPL/AVB unchanged.
include vendor/guardtalk/device/komodo/guardtalk-defaults.mk

# T-REMEDIATE-B4-WIFI-GW (item 21): fail-closed gateway SSID whitelist.
# Does not open Wi-Fi. Does not re-enable RIL/BT/NFC.
include vendor/guardtalk/device/komodo/guardtalk-wifi-gateway.mk
