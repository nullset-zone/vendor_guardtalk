# Framework + Settings overlays — telephony capability flags
# PARTITION MATCH (T-HOME-ROOTCAUSE):
#   - GuardTalkFrameworksBaseOverlay targets `android` (framework-res, in
#     /system). Stays product_specific — /product/overlay CAN target /system
#     packages on Android 14+. DEVICE_PACKAGE_OVERLAYS kept for build-time
#     resource resolution.
#   - GuardTalkSettingsOverlay targets Settings (system_ext_specific). The
#     overlay is system_ext_specific in its Android.bp. DEVICE_PACKAGE_OVERLAYS
#     is NOT set for it — it is a build-time resource resolution path that
#     previously caused mis-packaging into /product/overlay where
#     OverlayManager silently ignored the cross-partition static RRO.
PRODUCT_PACKAGES += \
    GuardTalkFrameworksBaseOverlay \
    GuardTalkSettingsOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay \
    vendor/guardtalk/overlays/GuardTalkSettingsOverlay

DEVICE_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay
