# Framework + Settings overlays — telephony capability flags
PRODUCT_PACKAGES += \
    GuardTalkFrameworksBaseOverlay \
    GuardTalkSettingsOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay \
    vendor/guardtalk/overlays/GuardTalkSettingsOverlay

DEVICE_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay \
    vendor/guardtalk/overlays/GuardTalkSettingsOverlay
