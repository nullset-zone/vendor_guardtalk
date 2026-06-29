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
# T-PKG-EXCISE-WAVES P0 — Safe leaf removals. Each module name verified as a real
# Soong module via `out/soong/late-tokay.mk` and as a PRODUCT_PACKAGES entry in
# build/make/target/product/*.mk before being added here. No source deletion;
# pure late filter-out (Law 11: Reversibility). Package-name → module-name
# mapping confirmed per-module (see completion report for the verification grep
# of each name):
#   Stk                      -> build/make/target/product/generic_system.mk:36
#   CarrierDefaultApp        -> build/make/target/product/telephony_system.mk:22
#   SimAppDialog             -> build/make/target/product/handheld_system.mk:75
#   ONS                      -> build/make/target/product/telephony_system.mk:21
#   CellBroadcastLegacyApp   -> build/make/target/product/telephony_system.mk:25
#                              (legacy com.android.cellbroadcastreceiver app;
#                               the com.android.cellbroadcast mainline APEX is
#                               out of PRODUCT_PACKAGES reach — see P2 below)
#   Tag                      -> build/make/target/product/generic_system.mk:37
#   BookmarkProvider         -> build/make/target/product/handheld_system.mk:41
#   PartnerBookmarksProvider -> build/make/target/product/generic_system.mk:34
#   HTMLViewer               -> build/make/target/product/media_system.mk:32
#   CallLogBackup            -> build/make/target/product/telephony_system.mk:23
#   BlockedNumberProvider    -> build/make/target/product/handheld_system.mk:39
# NOTE: com.android.se / SecureElement is paired with the NFC subsystem and is
# therefore excised in nfc-excised.mk (not here) — see that file.
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
    Stk \
    CarrierDefaultApp \
    SimAppDialog \
    ONS \
    CellBroadcastLegacyApp \
    Tag \
    BookmarkProvider \
    PartnerBookmarksProvider \
    HTMLViewer \
    CallLogBackup \
    BlockedNumberProvider

# T-PKG-EXCISE-WAVES P1 — Print subsystem + BasicDreams (dependency-checked).
# All three print-related modules are removed together: no printer drivers ship
# on a phone and the print framework degrades gracefully (no Spooler → no
# print UI; user can reinstall if needed). Names verified as Soong modules in
# out/soong/late-tokay.mk and as PRODUCT_PACKAGES entries in
# build/make/target/product/handheld_system.mk:38/68/69.
#   PrintSpooler              -> handheld_system.mk:69
#   PrintRecommendationService -> handheld_system.mk:68
#   BasicDreams               -> handheld_system.mk:38 (PhotoTable already kept
#                               as the dream; screensaver is non-essential)
# "Bips" from the brief is NOT a Soong module — it is the java package name
# (com.android.bips) of BuiltInPrintService. BuiltInPrintService is NOT excised
# here (conservative: it is the system print-service implementation; removing
# the spooler + recommendation service is sufficient to disable the print UI).
GUARDTALK_APPS_PACKAGES += \
    PrintSpooler \
    PrintRecommendationService \
    BasicDreams \
    EmergencyInfo

# T-APP-RM-EMERGENCY (Settings Reduction v3): EmergencyInfo (com.android.emergency)
# excised above. The emergency info app (medical info, emergency contacts, SOS
# from lock screen settings). Paired with config_show_emergency_settings=false
# overlay which hides the Safety & Emergency Settings entry + dashboard. The
# lock-screen emergency DIALER (frameworks/com.android.phone) is SEPARATE and
# is NOT affected by this removal. Verified: no hard dependency on this app
# from Settings (the dashboard is gated by the overlay bool) or from SystemUI.

# T-CAM-BLACK (camera black preview): PixelCameraServicesConnectivityClient is
# INTENTIONALLY NOT excised. Initial assumption (T-CAM-CRASH) was that its
# ProxyCameraProviderService NPE on missing BT/Location features was fatal and
# that excising the app was safe. On-device logcat proved this wrong: the camera
# HAL (com.google.pixel.camera.hal APEX) depends on PersistentBackgroundCamera
# Services, which in turn binds to ICameraProvider exported by this package.
# Removing the package → "proxy_camera_provider.cc: Not bound to ICameraProvider
# service" → "Unable to get proxy camera IDs" → capture-session configureStreams
# times out after 5000ms → ANR → black preview. The original ProxyCameraProvider
# NPE was a non-fatal background-service crash; the app must stay installed for
# the main camera pipeline to work. The NPE in the connectivity.service is
# non-fatal (caught/recovered) and does not affect the main camera path.

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
