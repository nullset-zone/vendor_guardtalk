# GuardTalkOS — tokay product hooks (docs / intended inherit).
# LIVE props: vendor/guardtalk/device/tokay/guardtalk-product-props.mk
# (included from guardtalk-radio-excised.mk). LIVE packages: feature-excised bridge.
# This file is NOT currently in the product inherit chain.
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay
PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.radio.excised=1 \
    ro.guardtalk.block_developer_options=1 \
    ro.guardtalk.config_password_gate=1 \
    ro.guardtalk.password_only_lock=1 \
    ro.guardtalk.lock_after_reboot=1 \
    ro.guardtalk.max_lock_after_timeout_ms=300000 \
    ro.guardtalk.sensor_privacy_when_locked=1 \
    ro.guardtalk.lockdown_fail_closed=1 \
    ro.guardtalk.usb_protection_fail_closed=1 \
    ro.guardtalk.auto_reboot_profiles=1 \
    ro.guardtalk.auto_reboot_default_ms=28800000 \
    ro.guardtalk.secure_wipe_enabled=1 \
    ro.guardtalk.anti_bruteforce_wipe_threshold=10 \
    ro.guardtalk.permission_defaults=1 \
    ro.guardtalk.privacy_tmpfs=1 \
    ro.guardtalk.privacy_tmpfs_path=/mnt/guardtalk_privacy \
    ro.guardtalk.clipboard_clear=1 \
    ro.guardtalk.clipboard_clear_timeout_ms=60000 \
    ro.guardtalk.files_policy=1 \
    ro.guardtalk.files_trash=1 \
    ro.guardtalk.files_protect_critical=1 \
    ro.guardtalk.production_hardening=1 \
    ro.guardtalk.block_unknown_sources=1 \
    ro.guardtalk.restrict_accessibility_services=1 \
    ro.guardtalk.restrict_display_overlays=1 \
    ro.guardtalk.restrict_dynamic_code=1 \
    ro.guardtalk.selinux_enforcing_required=1 \
    ro.guardtalk.verified_boot_required=1 \
    ro.guardtalk.keymint_required=1 \
    ro.guardtalk.sysctl_hardening=1 \
    persist.security.usb_mode=2

# T-SEC-P4-PERMS: Messenger default-permissions XML (package may be absent until APK lands).
PRODUCT_PACKAGES += default-permissions-com.guardtalk.messenger

# T-SEC-P4-PRIVACY: RAM-only privacy tmpfs (logs/cache wiped across reboot).
PRODUCT_PACKAGES += init.guardtalk.privacy_tmpfs.rc

# T-SEC-P5-HARDEN: production sysctl hardening init.
PRODUCT_PACKAGES += init.guardtalk.hardening.rc

$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-audio.mk)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-camera.mk)

# T-BOOTANIM-DEDUPE: bootanimation wiring now lives ONLY in guardtalk-theme.mk
# (single source of truth). The duplicate PRODUCT_COPY_FILES entry for
# GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip was removed to
# prevent double-wiring / build conflicts with guardtalk-theme.mk.

# Early hooks (BoardConfig + base packages)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/BoardConfig-excised.mk)
$(call inherit-product-if-exists, vendor/guardtalk/radio-excised/telephony-features.mk)
