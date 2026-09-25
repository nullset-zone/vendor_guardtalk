# GuardTalkOS komodo user defaults (T-REMEDIATE-B5-DEFAULTS, item 24).
#
# LIVE: included from vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk
# (late radio-excised pass). Share the next user image. Do not rewrite USERBUILD
# su/SPL/AVB. Do not re-enable RIL. Do not PRODUCT_PROPERTY_OVERRIDES
# persist.security.usb_mode (already set in tokay product-props; duplicate
# sysprop error). Do not touch persist.radio.disabled.
#
# AOSP full_base_telephony.mk uses ro.com.android.dataroaming?=true. A later
# non-optional assignment overrides the optional default (post_process_props).
# persist.sys.usb.config=none on user so the persistent gadget is not mtp.
# Settings.Secure.lock_screen_show_notifications and UMS defaults land via
# GuardTalkSettingsProviderOverlay (def_lock_screen_show_notifications=0).
# Settings.Global.Wearable.bug_report is 0 on user via Build.TYPE; the
# persist.sys.bug_report=0 marker is the product-visible default.

PRODUCT_PACKAGES += GuardTalkSettingsProviderOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkSettingsProviderOverlay

PRODUCT_COPY_FILES += \
    vendor/guardtalk/device/komodo/init.guardtalk.defaults.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.guardtalk.defaults.rc

PRODUCT_PROPERTY_OVERRIDES += \
    ro.com.android.dataroaming=false

ifeq ($(TARGET_BUILD_VARIANT),user)
PRODUCT_PROPERTY_OVERRIDES += \
    persist.sys.usb.config=none \
    persist.sys.bug_report=0
endif
