# T-W2-I1-UI-APPS — Non-HAL UI app excision (Browser + AppStore + Dialer).
#
# Scope: Vanadium browser (TrichromeChrome), GrapheneOS AppStore, and Dialer.
# This is a non-HAL, boot-chain-safe removal — it only drops PRODUCT_PACKAGES
# entries via the late product-config filter (same proven pattern as
# radio-excised/remove-packages.mk).
#
# CRITICAL INVARIANT: TrichromeWebView (the system WebView provider) and its
# DualArch variant MUST remain in PRODUCT_PACKAGES. Only the Chrome (browser)
# flavor of the Trichrome split is removed. See external/vanadium/Android.bp:
#   - TrichromeLibrary / TrichromeLibraryDualArch  -> KEEP (shared lib)
#   - TrichromeWebView / TrichromeWebViewDualArch  -> KEEP (WebView provider)
#   - TrichromeChrome  / TrichromeChromeDualArch   -> REMOVE (browser APK)
#   - VanadiumConfig                               -> REMOVE (browser config)

# Packages to drop. Dialer is listed here (not in radio-excised) because at
# baseline c2e79a1 radio-excised/remove-packages.mk does not yet include it;
# Dialer is a UI app and belongs with the UI-apps excision increment. Future
# radio-excision work may relocate it, in which case the duplicate filter-out
# is a harmless no-op.
#
# Messaging (T-MSG-REMOVE): the AOSP Messaging app (external/Messaging) is a
# product-specific android_app_import whose sysconfig whitelist
# (whitelist_com.android.messaging.xml) is pulled in as a `required` dependency.
# Both are PRODUCT_PACKAGES entries (sourced via aosp_base_telephony.mk /
# aosp_product.mk), so the late filter-out removes the APK and its whitelist
# in the same pass. Mirrors the proven Dialer/AppStore filter pattern.
#
# PixelCameraServicesConnectivityClient (T-CAM-CRASH): the proprietary
# com.google.android.apps.camera.services app (product/priv-app/
# PixelCameraServicesConnectivityClient/) contains
# ProxyCameraProviderService in its connectivity.service package. After Wave 0's
# T-HCH-WIRE fix (handheld_core_hardware override removes
# android.hardware.bluetooth + android.hardware.location feature
# declarations), the service NPEs at construction:
#   java.lang.NullPointerException: Attempt to invoke virtual method
#   'java.lang.Class java.lang.Object.getClass()' on a null object reference
#     at dsx.b -> dsv.a -> hda.d (obfuscated connectivity init)
# Root cause: ProxyCameraProviderService.onCreate queries a manager
# (BluetoothManager.getAdapter() / LocationManager) that returns null because
# FEATURE_BLUETOOTH / FEATURE_LOCATION are now absent. The app has no config
# flag to disable the service, and patching a proprietary prebuilt APK is not
# viable. Excising the entire app is safe: it provides camera-to-camera
# connectivity (e.g. using the phone as a webcam / connecting to external/BT
# cameras) — functionality that is moot now that BT is excised. The main
# Google Camera app uses the AIDL android.hardware.camera.provider@2.7 HAL
# (vendor/google_devices/tokay/vintf/vendor/manifest/
# android.hardware.camera.provider@2.7-service-google-apex.xml), NOT this
# connectivity client, so camera functionality is unaffected.
GUARDTALK_APPS_PACKAGES := \
    TrichromeChrome \
    TrichromeChromeDualArch \
    VanadiumConfig \
    AppStore \
    privapp-permissions_app.grapheneos.apps.xml \
    Dialer \
    Messaging \
    whitelist_com.android.messaging.xml \
    Auditor \
    etc_sysconfig_app.attestation.auditor.xml \
    ExactCalculator \
    InfoApp \
    PixelCameraServicesConnectivityClient

# WebView provider packages that must NEVER be dropped by any feature-excision
# filter. Listed explicitly so future subsystem filters (bt/nfc/fp/loc) can
# guard against accidental removal via a $(filter $(1),$(GUARDTALK_WEBVIEW_KEEP))
# short-circuit. This file itself does not remove them.
GUARDTALK_WEBVIEW_KEEP := \
    TrichromeWebView \
    TrichromeWebViewDualArch \
    TrichromeLibrary \
    TrichromeLibraryDualArch

# Late product-config filter. Runs after all inherit-product merges (via
# product-config-late.mk -> guardtalk-feature-excised.mk), so PRODUCT_PACKAGES
# is fully populated. The filter-out is idempotent and order-independent.
PRODUCT_PACKAGES := $(filter-out $(GUARDTALK_APPS_PACKAGES),$(PRODUCT_PACKAGES))

# Defence-in-depth: if any of the WebView-provider packages somehow landed in
# the drop list above, restore them. (No-op in normal operation.)
PRODUCT_PACKAGES += $(filter $(GUARDTALK_WEBVIEW_KEEP),$(GUARDTALK_APPS_PACKAGES))
