# GuardTalkOS product properties — LIVE wiring.
#
# `guardtalk-tokay.mk` is not in the product inherit chain (see comments in
# guardtalk-feature-excised.mk). This file is included from
# vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk (hooked from
# vendor/google_devices/tokay/tokay.mk) so PRODUCT_PROPERTY_OVERRIDES reach
# vendor/build.prop.
#
# Keep in sync with the PROPERTY_OVERRIDES block in guardtalk-tokay.mk
# (canonical documentation / intended future inherit).

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
    persist.security.usb_mode=2
