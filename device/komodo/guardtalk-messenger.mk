# GuardTalkOS komodo — Jami Messenger bake (T-REMEDIATE-B4-MESSENGER)
#
# LIVE: included from vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk
# (itself included from radio-excised via PRODUCT_DEVICE). User and userdebug
# both ship the product APK. Unknown-APK block forbids Gateway sideload, so
# PRODUCT_PACKAGES is the install path. Duplicate += with product-config-late.mk
# is idempotent.
#
# Do not add TrichromeChrome / AppStore / GmsCompat here.

ifndef GUARDTALK_MESSENGER_WIRED
GUARDTALK_MESSENGER_WIRED := true
PRODUCT_PACKAGES += GuardTalkMessenger
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/apps/GuardTalkMessenger
# T-REMEDIATE-B6-PROP-REACHABILITY: ro.* policy flag -> system/build.prop.
PRODUCT_SYSTEM_PROPERTIES += ro.guardtalk.messenger=1
endif
