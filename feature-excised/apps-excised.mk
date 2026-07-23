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
#   - VanadiumConfig                               -> KEEP (see RECLASSIFICATION
#                                                   note below; was briefly
#                                                   listed as REMOVE, corrected
#                                                   by A-REPORT-INVESTIGATE
#                                                   2026-07-02)

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
# RECLASSIFICATION (A-REPORT-INVESTIGATE, 2026-07-02): VanadiumConfig was
# delisted from GUARDTALK_APPS_PACKAGES and reclassified KEEP. It is NOT a
# filter miss — it is a legitimate `required:` dependency of the kept
# Trichrome* packages. Evidence:
#   - external/vanadium/Android.bp:43-48 — TrichromeWebView (and
#     TrichromeLibrary / TrichromeChrome / TrichromeChromeDualArch) declare
#     `required: ["VanadiumConfig"]`.
#   - out/soong/late-tokay.mk:268693-268694 — the generated install rule
#     drags VanadiumConfig in via that `required:` chain.
#   - VanadiumConfig.apk (11.6 MB) contains 22 unindexed_ruleset* binaries
#     + proto_config.pb2 — Vanadium's hardened Chromium config (JIT policy,
#     sensor gating, domain-reliability disabling). NOT an empty stub.
# Removing VanadiumConfig while keeping TrichromeWebView (GUARDTALK_WEBVIEW_KEEP
# :647-651) would leave WebView running default (unhardened) Chromium config —
# a silent security regression (Law 3, Law 13). It is now also mirrored in
# GUARDTALK_WEBVIEW_KEEP so a future careless append cannot drop it.
GUARDTALK_APPS_PACKAGES := \
    TrichromeChrome \
    TrichromeChromeDualArch \
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

# T-PKG-EXCISE-WAVE-B — Bloat / non-essential apps. Low-risk leaf removals.
# Each module name verified as present in the build's installed-files-*.txt
# (20 packages still shipped as of 2026-06-29). Pure late filter-out
# (Law 11: Reversibility); no source deletion. Idempotent (Law 8): entries
# already removed by other waves (GoogleConfigOverlay, PearlOverlay2024,
# ThemesStub — removed by Wave D) are harmless no-ops if re-listed.
#   Music                        -> product/app/Music/Music.apk
#   MusicFX                      -> system/app/MusicFX/MusicFX.apk
#   DeskClock                    -> product/app/DeskClock/DeskClock.apk
#   Gallery2                     -> product/app/Gallery2/Gallery2.apk
#   PhotoTable                   -> product/app/PhotoTable/PhotoTable.apk
#   EasterEgg                    -> product/app/EasterEgg/EasterEgg.apk
#   WallpaperCropper             -> system/app/WallpaperCropper/WallpaperCropper.apk
#   LiveWallpapersPicker         -> system/app/LiveWallpapersPicker/LiveWallpapersPicker.apk
#   WallpaperBackup              -> system/app/WallpaperBackup/WallpaperBackup.apk (idempotent w/ Wave C)
#   ThemePicker                  -> product/app/ThemePicker/ThemePicker.apk
#   BuiltInPrintService          -> system/priv-app/BuiltInPrintService/BuiltInPrintService.apk
#   MtpService                   -> system/app/MtpService/MtpService.apk
#   DeviceAsWebcam               -> system/app/DeviceAsWebcam/DeviceAsWebcam.apk
#   StorageManager               -> system/app/StorageManager/StorageManager.apk
#   DeviceDiagnostics            -> system/app/DeviceDiagnostics/DeviceDiagnostics.apk
#   AvatarPicker                 -> system/app/AvatarPicker/AvatarPicker.apk
#   SoundPicker                  -> product/app/SoundPicker/SoundPicker.apk
#   UserDictionaryProvider       -> system/app/UserDictionaryProvider/UserDictionaryProvider.apk
#   DynamicSystemInstallationService -> system/priv-app/DynamicSystemInstallationService/ (idempotent w/ Wave E)
#   InputDevices                 -> system/app/InputDevices/InputDevices.apk
# GoogleConfigOverlay, PearlOverlay2024, ThemesStub already in Wave D (idempotent).
GUARDTALK_APPS_PACKAGES += \
    Music \
    MusicFX \
    DeskClock \
    Gallery2 \
    PhotoTable \
    EasterEgg \
    WallpaperCropper \
    LiveWallpapersPicker \
    WallpaperBackup \
    ThemePicker \
    BuiltInPrintService \
    MtpService \
    DeviceAsWebcam \
    StorageManager \
    DeviceDiagnostics \
    AvatarPicker \
    SoundPicker \
    UserDictionaryProvider \
    DynamicSystemInstallationService \
    InputDevices

# T-PKG-EXCISE-WAVE-C — Privacy/ML/ads/enterprise + backup cluster.
# All operator-approved. Each entry verified as a real Soong install target via
# `out/soong/late-tokay.mk` (install-soong rule → out/target/product/tokay/...apk)
# AND as a PRODUCT_PACKAGES entry in build/make/target/product/*.mk before being
# added here. Pure late filter-out (Law 11: Reversibility); no source deletion.
#
# NOTE: GmsCompat cluster was originally part of Wave C but had to be RESTORED
# (see REGRESSION FIX comment below the package list). The framework hard-
# requires app.grapheneos.gmscompat as a system package at PMS.systemReady().
#
# Enterprise provisioning / device-management cluster (operator-approved removal):
#   ManagedProvisioning
#       -> handheld_system.mk:61  (com.android.managedprovisioning DA app)
#          install: system/priv-app/ManagedProvisioning/ManagedProvisioning.apk
#   ManagedProvisioningPixelOverlay
#       -> RRO shipped by vendor/google_devices/tokay/overlays (not in
#          build/make/target; verified as Soong module via late-tokay.mk)
#          install: product/overlay/ManagedProvisioningPixelOverlay.apk
#   CompanionDeviceManager
#       -> media_system.mk:29  (com.android.companiondevicemanager)
#          install: system/app/CompanionDeviceManager/CompanionDeviceManager.apk
#   CompanionDeviceManager__nosdcard__auto_generated_characteristics_rro
#       -> auto-generated RRO of CompanionDeviceManager (Soong-generated, not in
#          build/make/target; verified via late-tokay.mk)
#          install: product/overlay/CompanionDeviceManager__nosdcard__auto_generated_characteristics_rro.apk
#   PrivateSpace
#       -> handheld_system.mk:70  (com.android.privatespace)
#          install: system/priv-app/PrivateSpace/PrivateSpace.apk
#
# GmsCompat cluster (GrapheneOS Google-compatibility shim; operator-approved
# removal — GuardTalkOS is a no-GMS build):
#   GmsCompat      -> handheld_system.mk:56  install: GmsCompatConfig.apk (deps)
#   GmsCompatConfig -> verified via late-tokay.mk
#                     install: system/app/GmsCompatConfig/GmsCompatConfig.apk
#   GmsCompatLib   -> verified via late-tokay.mk
#                     install: system/app/GmsCompatLib/GmsCompatLib.apk
#
# Backup cluster (operator-approved removal; Seedvault + local transports):
#   Seedvault              -> media_system.mk:43  install: Seedvault.apk (deps)
#   LocalContactsBackup    -> Soong module (dependency of Seedvault; verified
#                             via late-tokay.mk) install: LocalContactsBackup.apk
#   LocalTransport         -> base_system.mk:217
#                             install: system/priv-app/LocalTransport/LocalTransport.apk
#   SharedStorageBackup    -> handheld_system.mk:74
#                             install: system/priv-app/SharedStorageBackup/SharedStorageBackup.apk
#   BackupRestoreConfirmation -> base_system.mk:37
#                             install: system/priv-app/BackupRestoreConfirmation/BackupRestoreConfirmation.apk
#   WallpaperBackup        -> base_system.mk:453/584 (idempotent: Wave B may
#                             already filter this; the duplicate filter-out is
#                             a harmless no-op per Law 11 reversibility)
#                             install: system/app/WallpaperBackup/WallpaperBackup.apk
#
# Calendar cluster (operator decision: remove Calendar app + provider, KEEP
# Contacts + ContactsProvider — see GUARDTALK_APPS_KEEP below):
#   Calendar        -> handheld_product.mk:27
#                      install: product/app/Calendar/Calendar.apk
#   CalendarProvider -> handheld_system.mk:43
#                      install: system/priv-app/Calendar/CalendarProvider.apk
GUARDTALK_APPS_PACKAGES += \
    ManagedProvisioning \
    ManagedProvisioningPixelOverlay \
    CompanionDeviceManager \
    CompanionDeviceManager__nosdcard__auto_generated_characteristics_rro \
    PrivateSpace \
    Seedvault \
    LocalContactsBackup \
    LocalTransport \
    SharedStorageBackup \
    BackupRestoreConfirmation \
    WallpaperBackup \
    Calendar \
    CalendarProvider

# REGRESSION FIX (2026-06-30 boot loop, Law 11 reversibility):
# GmsCompat / GmsCompatConfig / GmsCompatLib were removed in Wave C of the
# Deep Per-Package Audit as "GuardTalkOS is a no-GMS build". This was WRONG.
# GrapheneOS framework code unconditionally calls
#   GosPackageStatePermissions.init() -> Builder.apply(GmsCompatApp.PKG_NAME)
# during PackageManagerService.systemReady(). On userdebug builds
# (Build.IS_DEBUGGABLE == true), Builder.apply() throws
#   IllegalStateException("app.grapheneos.gmscompat is not a system package")
# when the package is absent, killing system_server -> zygote -> init
# InitFatalReboot -> boot loop (observed on tokay, 4 zygote deaths before
# boot completed). The packages are small, platform-signed, and inert when
# no GMS app invokes them, so retaining them carries negligible attack
# surface. They MUST stay in the build. Do NOT re-excise without also
# patching frameworks/base/services/core/java/com/android/server/pm/
# GosPackageStatePermission.java to tolerate a missing gmscompat package.

# T-PKG-EXCISE-WAVE-C Part 2 — Mainline APEX modules: INVESTIGATE (not excised).
#
# The 5 brief items below are APEX-delivered mainline modules. They ARE listed
# in PRODUCT_PACKAGES (build/make/target/product/base_system.mk) under their
# `com.android.*` APEX module names, BUT a naive `filter-out` on
# PRODUCT_PACKAGES does NOT cleanly work: it produces a dexpreopt-check failure
# because default_art_config.mk registers the APEX service jars in
# PRODUCT_APEX_BOOT_JARS / BCP_BOOT_JARS and the build then expects
# system/framework/oat/arm64/apex@com.android.<x>@javalib@service-<x>.jar@classes.odex
# to exist. Removing only the PRODUCT_PACKAGES entry leaves these dexpreopt
# artifacts orphaned -> `dex_preopt_check.mk` hard-fails the build:
#
#   Offending entries (observed):
#     apex@com.android.adservices@...@service-adservices.jar@classes.odex/.vdex
#     apex@com.android.adservices@...@service-sdksandbox.jar@classes.odex/.vdex
#     apex@com.android.healthfitness@...@service-healthfitness.jar@classes.odex/.vdex
#     apex@com.android.ondevicepersonalization@...@service-ondevicepersonalization.jar@classes.odex/.vdex
#   (com.android.virt / com.android.compos were ALSO flagged — pre-existing,
#    NOT in Wave C scope; they appear to be unrelated dexpreopt drift.)
#
# Investigation summary (per brief step 1-3):
#   com.android.adservices
#       - PRODUCT_PACKAGES entry: base_system.mk:54  (VERIFIED)
#       - Soong APEX install target: VERIFIED in late-tokay.mk
#         (out/target/product/tokay/system/apex/com.android.adservices.apex)
#       - Bundles SdkSandbox.apk inside it
#         (out/target/product/tokay/apex/com.android.adservices/app/SdkSandbox@BP4A.260205.002/SdkSandbox.apk)
#         => removing com.android.adservices ALSO removes SdkSandbox
#       - BLOCKER: dexpreopt check fails when filtered from PRODUCT_PACKAGES
#         (service-adservices + service-sdksandbox jars are in BCP_BOOT_JARS)
#   com.android.healthfitness
#       - PRODUCT_PACKAGES entry: base_system.mk:61  (VERIFIED)
#       - Soong APEX install target: VERIFIED in late-tokay.mk
#         (out/target/product/tokay/system/apex/com.android.healthfitness.apex)
#       - Bundles HealthConnect controller APK + permission file inside it
#         (out/target/product/tokay/apex/com.android.healthfitness/etc/permissions/com.android.healthconnect.controller.xml)
#         => removing com.android.healthfitness ALSO removes HealthConnect
#       - BLOCKER: dexpreopt check fails (service-healthfitness in BCP)
#   com.android.ondevicepersonalization
#       - PRODUCT_PACKAGES entry: base_system.mk:68  (VERIFIED)
#       - Soong APEX install target: VERIFIED in late-tokay.mk
#         (out/target/product/tokay/system/apex/com.android.ondevicepersonalization.apex)
#       - Bundles FederatedCompute services inside it
#         (packages/modules/OnDevicePersonalization/federatedcompute is a
#          sub-directory; no standalone com.android.federatedcompute.apex is
#          built — VERIFIED: zero matches for that apex path in late-tokay.mk)
#         => removing com.android.ondevicepersonalization ALSO removes FederatedCompute
#       - BLOCKER: dexpreopt check fails (service-ondevicepersonalization in BCP)
#
# Conclusion: all 3 APEX modules are filterable from PRODUCT_PACKAGES in
# principle, but the dexpreopt/BCP side-config (default_art_config.mk +
# PRODUCT_APEX_BOOT_JARS) must be filtered in lockstep. That is a separate
# excision mechanism (needs edits to build/make/target/product/default_art_config.mk
# AND likely ART/dexpreopt config), which is out of scope for this Wave C
# (forbidden paths include build/make/target/product/ — only
# vendor/guardtalk/feature-excised/apps-excised.mk is editable).
#
# The APEX modules remain DORMANT in the GuardTalkOS image via the existing
# feature-permission XML removal documented in guardtalk-feature-excised.mk
# (P2 comment): hasSystemFeature() returns false for the corresponding
# PackageManager.FEATURE_* constants, so the APEX mainline stack stays
# dormant and Settings/SystemUI hide all entry points. The .apex files still
# ship but are inert. Full excision is deferred to a dedicated APEX-BCP wave.
#
# INVESTIGATE -> follow-up wave needed: edit
# build/make/target/product/default_art_config.mk (and/or PRODUCT_APEX_BOOT_JARS)
# to drop service-adservices / service-sdksandbox / service-healthfitness /
# service-ondevicepersonalization in lockstep with the PRODUCT_PACKAGES
# filter-out. Requires touching build/make (currently a forbidden path for
# Wave C), so must be a separate task with its own scope-lock.

# GUARDTALK_APPS_KEEP — packages that must NEVER be dropped by this filter, even
# if a future Wave inadvertently lists them. Listed explicitly so the filter
# below can restore them as defence-in-depth. Operator decision for Wave C:
# Contacts + ContactsProvider are KEPT (only Calendar/CalendarProvider removed).
#
# T-SEC-P1-CONTACTS: UI hide only — do NOT add Contacts / ContactsProvider to
# GUARDTALK_APPS_PACKAGES. User-facing suppression is via
# GuardTalkLauncherOverlay filtered_components + Settings
# GuardTalkContactsVisibility + PackageManagerHooks package-visibility.
# Messenger independence is a prerequisite before any APK removal.
GUARDTALK_APPS_KEEP := \
    Contacts \
    ContactsProvider


# T-PKG-EXCISE-WAVE-D P1 — Safety / dev / regulatory apps. Each module name
# verified as a real Soong module via `out/soong/late-tokay.mk` AND as a
# PRODUCT_PACKAGES entry before being added here. No source deletion; pure
# late filter-out (Law 11: Reversibility). Idempotent (Law 8).
#   SafetyRegulatoryInfo                                -> vendor/google_devices/tokay/tokay.mk:133
#   SafetyRegulatoryInfo__tokay__auto_generated_rro_product -> vendor/google_devices/tokay/tokay.mk:525 (its RRO)
#   Traceur (com.android.traceur)                       -> build/make/target/product/handheld_system.mk:77
#   HardeningTestApp (com.android.hardeningtest.preinstalled) -> build/make/target/product/base_system.mk:576
#   LogViewer (com.android.logviewer)                    -> build/make/target/product/handheld_system.mk:60
GUARDTALK_APPS_PACKAGES += \
    SafetyRegulatoryInfo \
    SafetyRegulatoryInfo__tokay__auto_generated_rro_product \
    Traceur \
    HardeningTestApp \
    LogViewer

# T-PKG-EXCISE-WAVE-D P2 — Pixel/Google/tokay overlays. Operator-approved:
# GuardTalk-branded overlays fully supersede these, so the upstream overlays
# are excised to remove duplicated/conflicting resource definitions. Each
# module name verified against `out/soong/late-tokay.mk` (Soong module)
# before being added. Idempotent (Law 8): any entry already removed by an
# earlier wave (Wave A/B/C) is a harmless no-op here.
#
# PROTECTED (NOT in this list, MUST remain — see GUARDTALK_OVERLAY_KEEP below):
#   GuardTalkFrameworkBrandOverlay, GuardTalkFrameworksBaseOverlay,
#   GuardTalkSettingsOverlay, GuardTalkSystemUIOverlay,
#   GuardTalkSetupWizardOverlay, GuardTalkLauncherOverlay, GosOverlay,
#   NetworkStackOverlay, framework-res__tokay__auto_generated_rro_{product,vendor},
#   framework-res__nosdcard__auto_generated_characteristics_rro,
#   SettingsProvider__tokay__auto_generated_rro_{product,vendor},
#   SystemUIGoogle__tokay__auto_generated_rro_{product,vendor},
#   SettingsGoogle__tokay__auto_generated_rro_{product,vendor},
#   ConnectivityResourcesOverlayCaimitoOverride, PixelDocumentsUIGoogleOverlay.
#
# VanadiumConfig note: was previously described here as the "browser CONFIG
# flavor" paired with the excised TrichromeChrome. That framing was WRONG —
# per A-REPORT-INVESTIGATE (2026-07-02), VanadiumConfig is a `required:`
# dependency of TrichromeWebView/TrichromeLibrary (external/vanadium/Android.bp
# :43-48) and carries Vanadium's hardened Chromium config rulesets. It was
# delisted from GUARDTALK_APPS_PACKAGES and added to GUARDTALK_WEBVIEW_KEEP.
# Intentionally NOT re-added here (kept idempotent & DRY).
#
#   GoogleConfigOverlay                              (Wave B overlap — idempotent)
#   ManagedProvisioningPixelOverlay                  (Wave C overlap — idempotent)
#   PearlOverlay2024                                 (Wave B overlap — idempotent)
#   Telecom__tokay__auto_generated_rro_product       (Wave A overlap — idempotent)
#   ThemesStub                                       (Wave B overlap — idempotent)
#
# frameworks-base-overlays: phony aggregator (frameworks/base/packages/overlays/
# Android.bp) whose `required:` list pulls in AvoidAppsInCutoutOverlay,
# NoCutoutOverlay, TransparentNavigationBarOverlay, NotesRoleEnabledOverlay,
# FontNotoSerifSourceOverlay (+ the DisplayCutoutEmulation* / NavigationBarMode*
# overlays already listed above). Those 5 are NOT direct PRODUCT_PACKAGES
# entries — they install transitively via Soong's `required` mechanism, so
# filtering the individual module names is insufficient. Dropping the phony
# aggregator itself (sourced via build/make/target/product/handheld_product.mk
# :44) severs the transitive install. frameworks/ source is NOT edited (Law 6:
# minimal footprint; forbidden path) — only the late filter-out is applied.
GUARDTALK_APPS_PACKAGES += \
    GoogleConfigOverlay \
    GooglePermissionControllerOverlay \
    GooglePermissionControllerSafetyCenterOverlay \
    AvoidAppsInCutoutOverlay \
    DisplayCutoutEmulationCornerOverlay \
    DisplayCutoutEmulationDoubleOverlay \
    DisplayCutoutEmulationHoleOverlay \
    DisplayCutoutEmulationNarrowOverlay \
    DisplayCutoutEmulationTallOverlay \
    DisplayCutoutEmulationWaterfallOverlay \
    DisplayCutoutEmulationWideOverlay \
    FontNotoSerifSourceOverlay \
    GlanceableHubConfigOverlay \
    GlanceableHubSettingsConfigOverlay \
    GlanceableHubSettingsConfigOverlay2022 \
    GlanceableHubSysuiConfigOverlay \
    ManagedProvisioningPixelOverlay \
    NavigationBarMode3ButtonOverlay \
    NavigationBarModeGesturalOverlay \
    NoCutoutOverlay \
    NotesRoleEnabledOverlay \
    PearlOverlay2024 \
    PixelBatteryHealthOverlay \
    PixelBatteryLotXOverlay \
    PixelConfigOverlay2018 \
    PixelConfigOverlay2021 \
    PixelConfigOverlayCommon \
    PixelConnectivityOverlay2024 \
    PixelDisplayService__tokay__auto_generated_rro_product \
    PixelTetheringOverlay2021 \
    PixelWifiOverlay2024 \
    SettingsGoogleSyntheticOverlay \
    SettingsGoogleTokayOverlay \
    SettingsIntelligenceGoogleSyntheticOverlay \
    SettingsTokayOverlay \
    SystemUIGXOverlay \
    SystemUIGoogleSyntheticOverlay \
    Telecom__tokay__auto_generated_rro_product \
    ThemesStub \
    TrafficLightFaceOverlay \
    TransparentNavigationBarOverlay \
    UdfpsOverlay \
    UltrasonicOverlay \
    frameworks-base-overlays

# T-PKG-EXCISE-WAVE-D — Protected overlay keep-list. Defence-in-depth so any
# future subsystem filter (or a careless append) cannot accidentally drop the
# GuardTalk-branded replacements or the essential framework/networking
# overlays. The restore-on-collision below mirrors the WebView keep pattern.
# Verified present as Soong modules in out/soong/late-tokay.mk:
#   GuardTalkFrameworkBrandOverlay, GuardTalkFrameworksBaseOverlay,
#   GuardTalkSettingsOverlay, GuardTalkSystemUIOverlay,
#   GuardTalkSetupWizardOverlay, GuardTalkLauncherOverlay, GosOverlay,
#   NetworkStackOverlay, framework-res__tokay__auto_generated_rro_{product,vendor},
#   framework-res__nosdcard__auto_generated_characteristics_rro,
#   SettingsProvider__tokay__auto_generated_rro_{product,vendor},
#   SystemUIGoogle__tokay__auto_generated_rro_{product,vendor},
#   SettingsGoogle__tokay__auto_generated_rro_{product,vendor},
#   ConnectivityResourcesOverlayCaimitoOverride, PixelDocumentsUIGoogleOverlay.
# (GuardTalkValidatorOverlay not present in late-tokay.mk — does not exist on
# tokay; nothing to protect there.)
#
# T-ICON-WIRING — the 5 icon RRO overlays are added here as defence-in-depth
# so a future excision wave cannot accidentally filter them out. The
# restore-on-collision line below (PRODUCT_PACKAGES += $(filter
# $(GUARDTALK_OVERLAY_KEEP),$(GUARDTALK_APPS_PACKAGES))) will re-add any
# icon overlay that a careless append to GUARDTALK_APPS_PACKAGES drops.
GUARDTALK_OVERLAY_KEEP := \
    GuardTalkFrameworkBrandOverlay \
    GuardTalkFrameworksBaseOverlay \
    GuardTalkSettingsOverlay \
    GuardTalkSystemUIOverlay \
    GuardTalkSetupWizardOverlay \
    GuardTalkLauncherOverlay \
    GuardTalkSettingsIconOverlay \
    GuardTalkContactsIconOverlay \
    GuardTalkDocumentsUIIconOverlay \
    GuardTalkCameraIconOverlay \
    GuardTalkPdfViewerIconOverlay \
    GosOverlay \
    NetworkStackOverlay \
    framework-res__tokay__auto_generated_rro_product \
    framework-res__tokay__auto_generated_rro_vendor \
    framework-res__nosdcard__auto_generated_characteristics_rro \
    SettingsProvider__tokay__auto_generated_rro_product \
    SettingsProvider__tokay__auto_generated_rro_vendor \
    SystemUIGoogle__tokay__auto_generated_rro_product \
    SystemUIGoogle__tokay__auto_generated_rro_vendor \
    SettingsGoogle__tokay__auto_generated_rro_product \
    SettingsGoogle__tokay__auto_generated_rro_vendor \
    ConnectivityResourcesOverlayCaimitoOverride \
    PixelDocumentsUIGoogleOverlay

# T-PKG-EXCISE-WAVE-E — Virtualization + miscellaneous unused packages. Pure
# late filter-out (Law 11: Reversibility). Idempotent (Law 8): any entry already
# removed by an earlier wave is a harmless no-op here. Each module name verified
# as a real Soong module via `out/soong/late-tokay.mk` AND as a PRODUCT_PACKAGES
# entry (via `get_build_var PRODUCT_PACKAGES`) before being added.
#
# P1 — Plain PRODUCT_PACKAGES apps (APK install targets):
#   DynamicSystemInstallationService
#       -> late-tokay.mk:151511 install target
#          out/target/product/tokay/system/priv-app/DynamicSystemInstallationService/
#          source: frameworks/base/packages/DynamicSystemInstallationService/
#          NOTE: already excised by Wave B (apps-excised.mk:286). Re-listed here
#          is a harmless no-op (idempotent); kept for Wave E completeness per
#          the brief.
#   CameraExtensionsProxy
#       -> late-tokay.mk:34688 install target
#          out/target/product/tokay/system/app/CameraExtensionsProxy/
#          source: frameworks/base/packages/services/CameraExtensionsProxy/
#          (AOSP camera extensions proxy — com.android.cameraextensions)
#          CRITICAL KEEP VERIFIED: this is NOT PixelCameraServicesConnectivityClient.
#          PixelCameraServicesConnectivityClient is a DIFFERENT module:
#            - source: vendor/google_devices/tokay/proprietary/
#            - install: out/target/product/tokay/product/priv-app/PixelCameraServicesConnectivityClient/
#            - pulled in via vendor.google_devices.tokay.proprietary-* Soong rule
#              (late-tokay.mk:2863674), NOT via frameworks/base/packages/services/.
#          CameraExtensionsProxy (system/app/) and PixelCameraServicesConnectivityClient
#          (product/priv-app/) are distinct install paths and distinct Soong modules.
#          See T-CAM-BLACK comment below for why PixelCameraServicesConnectivityClient
#          MUST be KEPT (camera HAL bridge). CameraExtensionsProxy is the AOSP
#          camera extensions UI proxy — safe to drop; the Pixel camera HAL does
#          NOT depend on it.
#   StatementService (com.android.statementservice)
#       -> late-tokay.mk:249635 install target
#          out/target/product/tokay/product/priv-app/StatementService/
#          source: frameworks/base/packages/StatementService/
#          (Digital Asset Links resolver — unused on a non-installer phone)
#   CredentialManager (com.android.credentialmanager)
#       -> late-tokay.mk:54071 install target
#          out/target/product/tokay/system/priv-app/CredentialManager/
#          source: frameworks/base/packages/CredentialManager/
#          (Android 14+ credential selector UI — unused; no passkeys on
#          GuardTalkOS, no third-party credential providers enabled.)
#
# P2 — Virtualization APEX modules. The brief listed these by the names of
# their *internal* payloads, which are NOT PRODUCT_PACKAGES entries themselves:
#   5. virtualization.terminal   -> VmTerminalApp (com.android.virtualization.terminal)
#      NOT a PRODUCT_PACKAGES entry on tokay (verified: zero matches for
#      `VmTerminalApp-(soong|install-soong)` in late-tokay.mk; the Android.bp
#      at packages/modules/Virtualization/tests/Terminal/Android.bp is a
#      test-only `android_test`). NOT shipped on tokay — nothing to filter.
#   6. virtualmachine.res       -> android.system.virtualmachine.res (an APK
#      bundled INSIDE com.android.virt APEX at
#      out/target/product/tokay/apex/com.android.virt/app/android.system.virtualmachine.res@*/)
#      NOT a standalone PRODUCT_PACKAGES entry.
#   7. compos.payload           -> CompOSPayloadApp (an APK bundled INSIDE
#      com.android.compos APEX at
#      out/target/product/tokay/apex/com.android.compos/app/CompOSPayloadApp@*/)
#      NOT a standalone PRODUCT_PACKAGES entry.
#   8. microdroid.empty_payload -> EmptyPayloadApp (an APK bundled INSIDE
#      com.android.virt APEX at
#      out/target/product/tokay/apex/com.android.virt/app/EmptyPayloadApp@*/)
#      NOT a standalone PRODUCT_PACKAGES entry.
#
# Per Wave C investigation (see the INVESTIGATE comment block above for
# adservices/healthfitness/ondevicepersonalization, which were NOT filtered
# because that wave was forbidden from touching build/make/), APEX modules
# listed in PRODUCT_PACKAGES ARE reachable by the late filter-out in principle
# — filtering the APEX module name drops the whole .apex (and every internal
# payload with it). BUT a naive PRODUCT_PACKAGES-only filter is INSUFFICIENT:
# default_art_config.mk also registers the APEX service/framework jars in
# PRODUCT_APEX_SYSTEM_SERVER_JARS and PRODUCT_APEX_BOOT_JARS, and
# dexpreopt_check.mk hard-fails the build if the corresponding
# apex@<apex>@javalib@<jar>.jar@classes.{odex,vdex} artifacts are missing.
#
# Wave E attempted the lockstep BCP filter (filtering PRODUCT_APEX_*_JARS in
# this file via PRODUCTS-store write-back). That cleared the dexpreopt error
# but exposed a SECOND, harder blocker: Soong's bootclasspath_fragment module
# (build/soong/java/bootclasspath_fragment.go:675) validates that each
# `contents:` entry of a bootclasspath_fragment is declared in
# PRODUCT_APEX_BOOT_JARS. The com.android.virt-bootclasspath_fragment at
# packages/modules/Virtualization/build/apex/Android.bp:320 hard-codes
# `contents: ["framework-virtualization"]`, so removing
# com.android.virt:framework-virtualization from PRODUCT_APEX_BOOT_JARS fails
# Soong bootstrap. Editing that Android.bp is OUT OF SCOPE for Wave E
# (packages/modules/ is a forbidden path). See the INVESTIGATE block below for
# the full conclusion.
#
# The parent APEXes that bundle items 6/7/8 ARE in PRODUCT_PACKAGES (verified
# via `get_build_var PRODUCT_PACKAGES`):
#   com.android.virt  -> build/make/target/product/base_system.mk:79
#                       (bundles android.system.virtualmachine.res [6] and
#                        EmptyPayloadApp/microdroid.empty_payload [8] inside it)
#                       install: out/target/product/tokay/system/apex/com.android.virt.apex
#                       BCP jars (verified via get_build_var):
#                         PRODUCT_APEX_SYSTEM_SERVER_JARS: com.android.virt:service-virtualization
#                         PRODUCT_APEX_BOOT_JARS:          com.android.virt:framework-virtualization
#   com.android.compos -> system_ext_specific non-updatable APEX
#                       (packages/modules/Virtualization/build/compos/Android.bp:29-41)
#                       (bundles CompOSPayloadApp/compos.payload [7] inside it)
#                       install: out/target/product/tokay/system_ext/apex/com.android.compos.apex
#                       BCP jars (verified via get_build_var):
#                         PRODUCT_APEX_SYSTEM_SERVER_JARS: com.android.compos:service-compos
#                         PRODUCT_APEX_BOOT_JARS:          (none — compos has no framework jar)
# These 2 parent APEX modules are NOT filtered in Wave E (see INVESTIGATE
# below); they remain in PRODUCT_PACKAGES and ship in the image (dormant).
#
# Item 5 (virtualization.terminal / VmTerminalApp) is NOT shipped on tokay and
# therefore requires no filter entry — documented as INVESTIGATE-NOOP below.
#
# INVESTIGATE (items 6/7/8 — com.android.virt + com.android.compos APEXes):
# The two parent APEXes ARE in PRODUCT_PACKAGES and ARE reachable by the late
# filter-out in principle, BUT a clean excision from this file's scope alone is
# NOT possible. Two coupled Soong/make side-configs must be filtered in
# lockstep, and one of them lives in a forbidden path:
#
#   (a) dexpreopt_check.mk fails if the APEX BCP jars remain in
#       PRODUCT_APEX_SYSTEM_SERVER_JARS / PRODUCT_APEX_BOOT_JARS after the
#       APEX .apex is dropped from PRODUCT_PACKAGES (orphaned
#       apex@<apex>@javalib@<jar>.jar@classes.{odex,vdex} artifacts).
#       -> This side-config IS mutable from this file (the variables are
#          written back to the PRODUCTS store below).
#   (b) BUT filtering PRODUCT_APEX_BOOT_JARS triggers a SEPARATE Soong-level
#       validation in build/soong/java/bootclasspath_fragment.go:675:
#         `error: packages/modules/Virtualization/build/apex/Android.bp:320:1:
#          module "com.android.virt-bootclasspath-fragment": [framework-virtualization]
#          in contents must also be declared in PRODUCT_APEX_BOOT_JARS`
#       The `bootclasspath_fragment` module defined at
#       packages/modules/Virtualization/build/apex/Android.bp:320 hard-codes
#       `contents: ["framework-virtualization"]` and Soong validates that each
#       content jar is declared in PRODUCT_APEX_BOOT_JARS. Removing the jar
#       from PRODUCT_APEX_BOOT_JARS while leaving the fragment module defined
#       (which we cannot edit — packages/modules/ is a forbidden path) fails
#       Soong bootstrap. Verified empirically: the build attempt with the BCP
#       filter applied failed at Soong bootstrap with exactly this error.
#
# Conclusion: full excision of the virtualization APEXes requires either
#   - editing packages/modules/Virtualization/build/apex/Android.bp to drop
#     the bootclasspath_fragment (forbidden path), OR
#   - a Soong-level mechanism (e.g. a product flag) to skip the fragment
#     validation when the APEX is not in PRODUCT_PACKAGES, OR
#   - editing build/make/target/product/default_art_config.mk to drop the
#     BCP jar entries (forbidden path — build/make/).
# All three are outside the editable scope of Wave E
# (vendor/guardtalk/feature-excised/apps-excised.mk only). Deferred to a
# dedicated APEX-virtualization wave with an expanded scope-lock that permits
# touching packages/modules/Virtualization/ and/or build/make/.
#
# The virtualization APEXes remain DORMANT on GuardTalkOS: AVF (Android
# Virtualization Framework) requires explicit hasSystemFeature(FEATURE_VIRTUALIZATION_FRAMEWORK)
# to be invoked, and no app on GuardTalkOS uses it. The ~100 MB com.android.virt.apex
# still ships but is inert. Items 5-8 are reported as INVESTIGATE per the brief's
# acceptance criteria.
GUARDTALK_APPS_PACKAGES += \
    DynamicSystemInstallationService \
    CameraExtensionsProxy \
    StatementService \
    CredentialManager

# T-ORPHAN-LIB-CLEANUP — Strip orphan JNI libraries left behind by the excised
# PrintSpooler + Gallery2 APKs. Discovered by Q-PKG-REPORT-VERIFY (2026-07-01):
# the host APKs were correctly removed by the entries above (PrintSpooler at
# Wave P1 line ~110, Gallery2 at Wave B line ~146), but their bundled JNI
# shared libraries kept shipping in the final image as unreachable dead-weight
# (and minor attack surface).
#
# Root cause (verified via out/soong/module-info-tokay.json + build-tokay.ninja):
# the JNI libs are cc_library_shared Soong modules declared in the apps'
# Android.bp `jni_libs:` lists (PrintSpooler/Android.bp:39 -> libprintspooler_jni;
# Gallery2/Android.bp:37-41 -> libjni_eglfence / libjni_filtershow_filters /
# libjni_jpegstream). Soong expands the `jni_libs:` (a `required:`-style chain)
# into standalone PRODUCT_PACKAGES entries at config time, emitting per-module
# phony targets (`build libjni_eglfence: phony device_libjni_eglfence_all_targets`
# at build-tokay.ninja:1197792, etc.) that install the .so to <partition>/lib64/.
# A separate packaging rule then symlinks that lib64 copy into
# <partition>/app/<APK>/lib/arm64/ (e.g. rule25149 at build-tokay.ninja:213429
# creates app/Gallery2/lib/arm64/libjni_eglfence.so -> /product/lib64/libjni_eglfence.so).
# Filtering only the host APK name from PRODUCT_PACKAGES drops the APK install
# rule but leaves the lib's standalone PRODUCT_PACKAGES entry in place, so the
# lib64 install (and its app/.../lib/arm64/ symlink) still fires. The 4 libs
# below are filtered here so the late PRODUCT_PACKAGES filter-out drops the
# standalone lib entries too, severing both the lib64 install and the symlink.
#
# Shipped orphans (out/target/product/tokay/installed-files*.txt, 2026-06-30 build):
#   /system/app/PrintSpooler/lib/arm64/libprintspooler_jni.so            (36 KB)
#   /product/app/Gallery2/lib/arm64/libjni_eglfence.so                   (33 KB)
#   /product/app/Gallery2/lib/arm64/libjni_filtershow_filters.so         (43 KB)
#   /product/app/Gallery2/lib/arm64/libjni_jpegstream.so                 (35 KB)
# The lib64 standalone copies are NOT shipped (intermediate build artifacts only).
#
# No source-tree Android.bp is touched (Law 6: Minimal Footprint; forbidden path).
# Pure late filter-out, idempotent (Law 8) and reversible (Law 11).
GUARDTALK_APPS_PACKAGES += \
    libprintspooler_jni \
    libjni_eglfence \
    libjni_filtershow_filters \
    libjni_jpegstream

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
#
# VanadiumConfig (added A-REPORT-INVESTIGATE 2026-07-02): a `required:`
# dependency of TrichromeWebView/TrichromeLibrary (external/vanadium/Android.bp
# :43-48) carrying Vanadium's hardened Chromium config rulesets (22
# unindexed_ruleset* binaries + proto_config.pb2). Was briefly (and
# incorrectly) listed in GUARDTALK_APPS_PACKAGES; delisted and mirrored here
# so a future careless append to the drop list cannot silently strip
# hardened WebView config (Law 3, Law 13).
GUARDTALK_WEBVIEW_KEEP := \
    TrichromeWebView \
    TrichromeWebViewDualArch \
    TrichromeLibrary \
    TrichromeLibraryDualArch \
    VanadiumConfig

# Late product-config filter. Runs after all inherit-product merges (via
# product-config-late.mk -> guardtalk-feature-excised.mk), so PRODUCT_PACKAGES
# is fully populated. The filter-out is idempotent and order-independent.
PRODUCT_PACKAGES := $(filter-out $(GUARDTALK_APPS_PACKAGES),$(PRODUCT_PACKAGES))

# HardeningTestApp ships via PRODUCT_PACKAGES_DEBUG (not PRODUCT_PACKAGES),
# so the filter above doesn't catch it. Filter it from the debug list too.
PRODUCT_PACKAGES_DEBUG := $(filter-out $(GUARDTALK_APPS_PACKAGES),$(PRODUCT_PACKAGES_DEBUG))

# Defence-in-depth: if any of the WebView-provider packages somehow landed in
# the drop list above, restore them. (No-op in normal operation.)
PRODUCT_PACKAGES += $(filter $(GUARDTALK_WEBVIEW_KEEP),$(GUARDTALK_APPS_PACKAGES))

# Defence-in-depth (Wave C): if any of the KEEP packages (Contacts,
# ContactsProvider) somehow landed in the drop list above, restore them.
# (No-op in normal operation.)
PRODUCT_PACKAGES += $(filter $(GUARDTALK_APPS_KEEP),$(GUARDTALK_APPS_PACKAGES))

# Defence-in-depth (Wave D): if any protected GuardTalk/essential overlay
# somehow landed in the drop list above, restore them. (No-op in normal
# operation; guards against a future careless append to GUARDTALK_APPS_PACKAGES.)
PRODUCT_PACKAGES += $(filter $(GUARDTALK_OVERLAY_KEEP),$(GUARDTALK_APPS_PACKAGES))

# Defence-in-depth (Wave E): if PixelCameraServicesConnectivityClient somehow
# landed in the drop list above (e.g. a future careless append confusing the
# AOSP CameraExtensionsProxy with the Pixel camera HAL bridge), restore it.
# CRITICAL KEEP — see T-CAM-BLACK comment above: the camera HAL depends on this
# package; dropping it yields a black preview. (No-op in normal operation.)
GUARDTALK_CAMERA_HAL_KEEP := \
    PixelCameraServicesConnectivityClient
PRODUCT_PACKAGES += $(filter $(GUARDTALK_CAMERA_HAL_KEEP),$(GUARDTALK_APPS_PACKAGES))
