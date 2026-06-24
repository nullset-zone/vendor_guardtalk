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
    InfoApp

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
