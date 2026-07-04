# vendor/guardtalk/feature-excised/icon-overlays.mk
#
# T-ICON-WIRING — Consolidated wiring for the 5 GuardTalkOS icon RRO overlays.
#
# Each frontend subagent (F-ICON-SETTINGS / F-ICON-CONTACTS / F-ICON-DOCSUI /
# F-ICON-CAMERA / F-ICON-PDFVIEWER) created an icon RRO overlay that replaces
# a target app's launcher icon with the GuardTalk-branded glyph. This file is
# the SINGLE source of truth for wiring all 5 icon overlays into the build.
#
# Previously the Settings + Camera icon overlays were wired (inconsistently)
# in radio-excised/telephony-features.mk and device/emu64a/guardtalk-emu-layer.mk.
# Those scattered entries were removed in T-ICON-WIRING Step 2 and consolidated
# here so the icon overlays are wired in one consistent location alongside the
# existing GuardTalk overlays (feature-overlays.mk).
#
# Defence-in-depth against future excision: each overlay is also listed in
# GUARDTALK_OVERLAY_KEEP (apps-excised.mk), so the late product-config filter
# cannot accidentally strip them.
#
# Overlay inventory (5 icon RROs):
#   - GuardTalkSettingsIconOverlay     — target com.android.settings
#     (system_ext_specific, platform cert)
#   - GuardTalkContactsIconOverlay      — target com.android.contacts
#     (product_specific, SHARED cert — matches Contacts' signing key)
#   - GuardTalkDocumentsUIIconOverlay   — target com.android.documentsui
#     (system partition, platform cert)
#   - GuardTalkCameraIconOverlay        — target app.grapheneos.camera
#     (product_specific, platform cert)
#   - GuardTalkPdfViewerIconOverlay     — target app.grapheneos.pdfviewer
#     (product_specific, platform cert)
#
# PARTITION MATCH (T-HOME-ROOTCAUSE): OverlayManager on Android 14+ (SDK 34+)
# silently drops static RROs whose target lives in a different partition than
# the overlay. Each overlay's Android.bp sets the partition placement
# (system_ext_specific / product_specific / system) to match its target's
# partition. DEVICE_PACKAGE_OVERLAYS is NOT used here — it is a build-time
# resource resolution path, irrelevant to runtime RRO installation, and
# previously caused mis-packaging into /product/overlay where OverlayManager
# silently ignored the cross-partition static RRO. The runtime overlay
# targetPackage in the APK manifest + correct partition placement via
# *_specific in Android.bp are what matter.
PRODUCT_PACKAGES += \
    GuardTalkSettingsIconOverlay \
    GuardTalkContactsIconOverlay \
    GuardTalkDocumentsUIIconOverlay \
    GuardTalkCameraIconOverlay \
    GuardTalkPdfViewerIconOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkSettingsIconOverlay \
    vendor/guardtalk/overlays/GuardTalkContactsIconOverlay \
    vendor/guardtalk/overlays/GuardTalkDocumentsUIIconOverlay \
    vendor/guardtalk/overlays/GuardTalkCameraIconOverlay \
    vendor/guardtalk/overlays/GuardTalkPdfViewerIconOverlay
