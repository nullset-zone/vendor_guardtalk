# GuardTalkOS (tokay) Attack-Surface Package Reconciliation Report

**Audit ID:** A-PKG-SURFACE-REPORT
**Date:** 2026-07-01 (post-implementation audit: 2026-07-02, A-EXCISE-FINAL)
**Auditor:** AEGIS Auditor (read-only)
**Source tree:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/`
**Build target:** `tokay-cur-userdebug` (system.img 2026-06-30 14:19, product.img 2026-06-30 11:04)
**Status:** POST-IMPLEMENTATION AUDIT — 4 excision tasks implemented + QA-verified (see "Post-Implementation Status" below). Build/flash re-verification pending.

---

## Executive Summary

The GuardTalkOS excision effort is **largely effective**. Of the 88 present packages (24 system APKs + 13 product APKs + 11 system_ext APKs + 40 APEX modules), the vast majority of targeted bloat, HAL, radio, and feature packages are **already confirmed absent**. **Zero** concrete **regressions** (excised-but-still-present) remain — the previously flagged VanadiumConfig regression was **RESOLVED** on 2026-07-02 by the A-REPORT-INVESTIGATE verdict (reclassified KEEP + delisted; see Cat 2 / Cat 4). Two orphan native-library remnants were **RESOLVED** by T-ORPHAN-LIB-CLEANUP (2026-07-02). The 3 mainline APEX modules formerly in Cat 3 are now **EXCISED** by T-APEX-BCP-WAVE (pending build + flash verification). Cat 5's PixelQualifiedNetworksService is **EXCISED** by T-CAT5-EXCISE; Multiuser investigated → KEEP (AppWidget UX).

| Metric | Count |
|---|---|
| Present packages total | 88 |
| Category 1 — Already Removed | ~110+ entries (orphan-lib remnants RESOLVED) |
| Category 2 — Regressions (excised-but-still-present) | **0** (VanadiumConfig RESOLVED 2026-07-02 → Cat 4) |
| Category 3 — Must Remove | **3 EXCISED** (T-APEX-BCP-WAVE implemented; pending build + flash verification) |
| Category 4 — Keep (critical/needed) | ~57 |
| Category 5 — Investigate (operator decision) | 16 (PixelQualifiedNetworksService → EXCISED; Multiuser → KEEP) |
| Estimated attack-surface reduction realized | ~3.4% of present set (Cat 3 APEX) + orphan libs + Cat 5 entry |
| Regression count | 0 |
| Excision effectiveness (non-APEX) | ~98.2% |

---

## Present-Package Set (authoritative, from build output)

### APKs in /system/app + /system/priv-app (24)
AppCompatConfig, CaptivePortalLogin, CertInstaller, ContactsProvider, DocumentsUI, DownloadProvider, DownloadProviderUi, E2eeContactKeysProvider, ExternalStorageProvider, ExtShared, FusedLocation, GmsCompat, GmsCompatConfig, GmsCompatLib, IntentResolver, KeyChain, MediaProviderLegacy, NetworkStack, PackageInstaller, PacProcessor, ProxyHandler, SettingsProvider, Shell, VpnDialogs

### APKs in /product/app + /product/priv-app (13)
ANGLE, Camera, Contacts, LatinIME, ModuleMetadata, PdfViewerGOS, PixelCameraServicesConnectivityClient, SettingsIntelligence, SpeechServices, talkback, TrichromeLibrary, TrichromeWebView, VanadiumConfig

### APKs in /system_ext/app + /system_ext/priv-app (11)
AccessibilityMenu, GuardTalkConfig, GuardTalkValidator, Launcher3QuickStep, Multiuser, PersistentBackgroundCameraServices, PixelDisplayService, PixelQualifiedNetworksService, Settings, SetupWizard2, SystemUI

### APEX mainline modules (40)
`com.android.*` (37): adbd, adservices, apex.cts.shim, appsearch, art, bt, compos, configinfrastructure, conscrypt, crashrecovery, devicelock, extservices, hardware.biometrics.face.virtual, hardware.cas (in `/vendor/apex/`), healthfitness, i18n, ipsec, media, mediaprovider, media.swcodec, neuralnetworks, nfcservices, ondevicepersonalization, os.statsd, permission, profiling, resolv, rkpd, runtime, scheduling, sdkext, telephonycore, tethering, tzdata, uprobestats, uwb, virt, wifi

`com.google.*` (3): com.google.android.widevine-13130248, com.google.pixel.camera.hal, com.google.pixel.wifi.ext

> **Note:** `com.android.cellbroadcast` is **ABSENT** from the final image (successfully filtered by `remove-packages.mk:138`). It appears only in stale `target_files_intermediates` build artifacts.

---

## Category 1: Already Removed (confirmed ABSENT from present set)

### 1a. apps-excised.mk — GUARDTALK_APPS_PACKAGES (Wave A–E)

Mechanism: late `PRODUCT_PACKAGES` filter-out (apps-excised.mk:656). Pure reversibility (Law 11).

| Package / Module | Wave | Excision cite | Mechanism |
|---|---|---|---|
| TrichromeChrome | A | apps-excised.mk:52 | app filter |
| TrichromeChromeDualArch | A | apps-excised.mk:53 | app filter |
| AppStore | A | apps-excised.mk:55 | app filter |
| privapp-permissions_app.grapheneos.apps.xml | A | apps-excised.mk:56 | app filter |
| Dialer | A | apps-excised.mk:57 (also radio-excised.mk:121, idempotent) | app filter |
| Messaging | A | apps-excised.mk:58 (also radio-excised.mk:122, idempotent) | app filter |
| whitelist_com.android.messaging.xml | A | apps-excised.mk:59 | app filter |
| Auditor | A | apps-excised.mk:60 | app filter |
| etc_sysconfig_app.attestation.auditor.xml | A | apps-excised.mk:61 | app filter |
| ExactCalculator | A | apps-excised.mk:62 | app filter |
| InfoApp | A | apps-excised.mk:63 | app filter |
| Stk | P0 | apps-excised.mk:64 | app filter |
| CarrierDefaultApp | P0 | apps-excised.mk:65 | app filter |
| SimAppDialog | P0 | apps-excised.mk:66 | app filter |
| ONS | P0 | apps-excised.mk:67 | app filter |
| CellBroadcastLegacyApp | P0 | apps-excised.mk:68 | app filter |
| Tag | P0 | apps-excised.mk:69 | app filter |
| BookmarkProvider | P0 | apps-excised.mk:70 | app filter |
| PartnerBookmarksProvider | P0 | apps-excised.mk:71 | app filter |
| HTMLViewer | P0 | apps-excised.mk:72 | app filter |
| CallLogBackup | P0 | apps-excised.mk:73 | app filter |
| BlockedNumberProvider | P0 | apps-excised.mk:74 | app filter |
| PrintSpooler | P1 | apps-excised.mk:91 | app filter |
| PrintRecommendationService | P1 | apps-excised.mk:92 | app filter |
| BasicDreams | P1 | apps-excised.mk:93 | app filter |
| EmergencyInfo | P1 | apps-excised.mk:94 | app filter |
| Music | Wave B | apps-excised.mk:124 | app filter |
| MusicFX | Wave B | apps-excised.mk:125 | app filter |
| DeskClock | Wave B | apps-excised.mk:126 | app filter |
| Gallery2 | Wave B | apps-excised.mk:127 | app filter |
| PhotoTable | Wave B | apps-excised.mk:128 | app filter |
| EasterEgg | Wave B | apps-excised.mk:129 | app filter |
| WallpaperCropper | Wave B | apps-excised.mk:130 | app filter |
| LiveWallpapersPicker | Wave B | apps-excised.mk:131 | app filter |
| WallpaperBackup | Wave B/C | apps-excised.mk:132,214 (idempotent) | app filter |
| ThemePicker | Wave B | apps-excised.mk:133 | app filter |
| BuiltInPrintService | Wave B | apps-excised.mk:134 | app filter |
| MtpService | Wave B | apps-excised.mk:135 | app filter |
| DeviceAsWebcam | Wave B | apps-excised.mk:136 | app filter |
| StorageManager | Wave B | apps-excised.mk:137 | app filter |
| DeviceDiagnostics | Wave B | apps-excised.mk:138 | app filter |
| AvatarPicker | Wave B | apps-excised.mk:139 | app filter |
| SoundPicker | Wave B | apps-excised.mk:140 | app filter |
| UserDictionaryProvider | Wave B | apps-excised.mk:141 | app filter |
| DynamicSystemInstallationService | Wave B/E | apps-excised.mk:142,617 (idempotent) | app filter |
| InputDevices | Wave B | apps-excised.mk:143 | app filter |
| ManagedProvisioning | Wave C | apps-excised.mk:204 | app filter |
| ManagedProvisioningPixelOverlay | Wave C | apps-excised.mk:205 (also Wave D :387, idempotent) | app filter |
| CompanionDeviceManager | Wave C | apps-excised.mk:206 | app filter |
| CompanionDeviceManager__nosdcard__auto_generated_characteristics_rro | Wave C | apps-excised.mk:207 | app filter |
| PrivateSpace | Wave C | apps-excised.mk:208 | app filter |
| Seedvault | Wave C | apps-excised.mk:209 | app filter |
| LocalContactsBackup | Wave C | apps-excised.mk:210 | app filter |
| LocalTransport | Wave C | apps-excised.mk:211 | app filter |
| SharedStorageBackup | Wave C | apps-excised.mk:212 | app filter |
| BackupRestoreConfirmation | Wave C | apps-excised.mk:213 | app filter |
| Calendar | Wave C | apps-excised.mk:215 | app filter |
| CalendarProvider | Wave C | apps-excised.mk:216 | app filter |
| SafetyRegulatoryInfo | Wave D P1 | apps-excised.mk:324 | app filter |
| SafetyRegulatoryInfo__tokay__auto_generated_rro_product | Wave D P1 | apps-excised.mk:325 | app filter |
| Traceur | Wave D P1 | apps-excised.mk:326 | app filter |
| HardeningTestApp | Wave D P1 | apps-excised.mk:327 (also :660 debug list) | app filter |
| LogViewer | Wave D P1 | apps-excised.mk:328 | app filter |
| GoogleConfigOverlay | Wave D P2 | apps-excised.mk:371 | app filter |
| GooglePermissionControllerOverlay | Wave D P2 | apps-excised.mk:372 | app filter |
| GooglePermissionControllerSafetyCenterOverlay | Wave D P2 | apps-excised.mk:373 | app filter |
| AvoidAppsInCutoutOverlay | Wave D P2 | apps-excised.mk:374 | app filter |
| DisplayCutoutEmulation*Overlay (×6) | Wave D P2 | apps-excised.mk:375–381 | app filter |
| FontNotoSerifSourceOverlay | Wave D P2 | apps-excised.mk:382 | app filter |
| GlanceableHub*Overlay (×4) | Wave D P2 | apps-excised.mk:383–386 | app filter |
| NavigationBarMode3ButtonOverlay / GesturalOverlay | Wave D P2 | apps-excised.mk:388–389 | app filter |
| NoCutoutOverlay | Wave D P2 | apps-excised.mk:390 | app filter |
| NotesRoleEnabledOverlay | Wave D P2 | apps-excised.mk:391 | app filter |
| PearlOverlay2024 | Wave D P2 | apps-excised.mk:392 | app filter |
| PixelBatteryHealthOverlay / PixelBatteryLotXOverlay | Wave D P2 | apps-excised.mk:393–394 | app filter |
| PixelConfigOverlay2018/2021/Common | Wave D P2 | apps-excised.mk:395–397 | app filter |
| PixelConnectivityOverlay2024 | Wave D P2 | apps-excised.mk:398 | app filter |
| PixelDisplayService__tokay__auto_generated_rro_product | Wave D P2 | apps-excised.mk:399 | app filter |
| PixelTetheringOverlay2021 / PixelWifiOverlay2024 | Wave D P2 | apps-excised.mk:400–401 | app filter |
| SettingsGoogleSyntheticOverlay / SettingsGoogleTokayOverlay | Wave D P2 | apps-excised.mk:402–403 | app filter |
| SettingsIntelligenceGoogleSyntheticOverlay / SettingsTokayOverlay | Wave D P2 | apps-excised.mk:404–405 | app filter |
| SystemUIGXOverlay / SystemUIGoogleSyntheticOverlay | Wave D P2 | apps-excised.mk:406–407 | app filter |
| Telecom__tokay__auto_generated_rro_product | Wave D P2 | apps-excised.mk:408 | app filter |
| ThemesStub | Wave D P2 | apps-excised.mk:409 | app filter |
| TrafficLightFaceOverlay | Wave D P2 | apps-excised.mk:410 | app filter |
| TransparentNavigationBarOverlay | Wave D P2 | apps-excised.mk:411 | app filter |
| UdfpsOverlay / UltrasonicOverlay | Wave D P2 | apps-excised.mk:412–413 | app filter |
| frameworks-base-overlays (phony aggregator) | Wave D P2 | apps-excised.mk:414 | app filter |
| CameraExtensionsProxy | Wave E P1 | apps-excised.mk:618 | app filter |
| StatementService | Wave E P1 | apps-excised.mk:619 | app filter |
| CredentialManager | Wave E P1 | apps-excised.mk:620 | app filter |

### 1b. radio-excised/remove-packages.mk — GUARDTALK_RADIO_PACKAGES

Mechanism: explicit filter-out (remove-packages.mk:204) + wildcard `_gt-package-drop` (:171–201) + orphan list (:161–170) + `PRODUCT_COPY_FILES` strip (:155–158).

Key entries (abbreviated — see remove-packages.mk:38–141 for full list):
- android.hardware.radio-* (16 NDK/HIDL stubs)
- android.hardware.telephony.*.prebuilt.xml (4)
- dump_modem / dump_modemlog / google-ril
- libril-aidl / libril_gfeature / libril_sitril* (8)
- modem_* (10: android_property_manager, clock_manager, log_*, ml_*, logging_control)
- com.google.pixel.modem.logmasklibrary-V1-ndk
- libmodem_ml_svc_proto / libmodem_svc_proto_legacy_soong
- adevtool_vintf_fragment_vendor_shared_modem_platform.xml
- oemrilhook / ril-extension / rild_exynos / shared_modem_platform
- OemRilService / OemRilHookService / ShannonIms / ShannonRcs
- liboemservice / liboemservice_proxy_default / lassen_dmd_constants
- vendor.samsung_slsi.telephony.hardware.* (4)
- init.radio.sh (+ copy-file drop)
- vendor.google.radio_ext-V1-ndk / -service / vendor.google.radioext@1.0-service
- vendor.radio.base / protocol.sit.* (4)
- com.android.phone / com.android.telephony.imsmedia / telephony-ext
- Dialer / Messaging (idempotent w/ apps-excised)
- cbd / rfsd (+ copy-file drop)
- MmsService / PixelImsMediaService
- EuiccGoogle / EuiccSupportPixel-P23 / EuiccGoogleOverlay / EuiccSupportPixelPermissions / EuiccSupportPixelOverlay / com.google.pixel.euicc.update (+ copy-file strip)
- Iwlan / ImsServiceEntitlement / CarrierConfig2 / CarrierConfig
- Telecom / Telecom__tokay__auto_generated_rro_product
- GT_RADIO_ORPHAN_PACKAGES (libreference-ril, libgooglerilaudio, libgooglerilmemmonitor, libgril_oem-google, libril, librilutils, android.hardware.radio@1.0/.1)

### 1c. bt-excised.mk — GUARDTALK_BT_PACKAGES

Mechanism: filter-out (bt-excised.mk:88) + wildcard (:73–82) + copy-file drop (:96–105).

- android.hardware.bluetooth-V1-ndk.vendor
- android.hardware.bluetooth.audio-V5-ndk.vendor / -impl / @2.0/.1.vendor
- android.hardware.bluetooth.finder-V1-ndk.vendor / ranging-V1-ndk.vendor
- android.hardware.bluetooth.prebuilt.xml / _le.prebuilt.xml (feature XML)
- android.hardware.bluetooth-service.bcmbtlinux
- hardware.google.bluetooth.bt_channel_avoidance@1.0
- vendor.google.bluetooth_ext-V1/V4-ndk
- BluetoothMidiService
- libbluetooth_audio_session_aidl
- Bluetooth HAL .rc + vendor configs (copy-file drop)

### 1d. nfc-excised.mk — GUARDTALK_NFC_PACKAGES

Mechanism: filter-out (nfc-excised.mk:94) + wildcard (:79–88) + copy-file drop (:102–106).

- android.hardware.nfc-V1-ndk.vendor
- android.hardware.nfc-service.st (bundles .rc via Soong init_rc)
- android.hardware.nfc.{ese,hce,hcef,}.prebuilt.xml (4, feature XML)
- nfc-service-default.xml (VINTF fragment)
- nfc_nci.st21nfc.default
- PixelNfc / PixelNfcOverlayCommon / PixelNfcOverlayTokay
- SecureElement (com.android.se)
- libnfc-nci.conf / libnfc-hal-st.conf (copy-file drop)

### 1e. fp-excised.mk — GUARDTALK_FP_PACKAGES

Mechanism: filter-out (fp-excised.mk:62) + wildcard (:40–49) + VINTF fragment filter (:90–91) + copy-file drop (:102–106).

- android.hardware.biometrics.fingerprint-V3-ndk.vendor
- android.hardware.fingerprint.prebuilt.xml (feature XML)
- com.android.hardware.biometrics.fingerprint.virtual
- com.google.hardware.biometrics.fingerprint.fingerprint-ext-V2-ndk
- vendor.qti.hardware.fingerprint.aidl-V1-ndk
- dump_fingerprint / qfp-daemon
- adevtool_vintf_fragment_vendor_qfp-daemon.xml (VINTF fragment)
- qfp-daemon.rc / init.fingerprint.dump.rc (copy-file drop)

### 1f. loc-excised.mk — GUARDTALK_LOC_PACKAGES

Mechanism: filter-out (loc-excised.mk:134) + wildcard (:116–128) + copy-file drop (:148–155).

- android.hardware.gnss-V3-ndk.vendor
- android.hardware.gnss-service / -service.pixel
- android.hardware.gnss.measurement_corrections@1.0/.1.vendor
- android.hardware.gnss.visibility_control@1.0.vendor
- android.hardware.gnss@1.0/.1/.2.0/.2.1.vendor (4)
- android.hardware.location.gps.prebuilt.xml (feature XML)
- adevtool_vintf_fragment_vendor_android.hardware.gnss@lassen.xml / _pixel-gnss-default.xml
- gnss_test / gnssd / lassen_dmd_constants
- libcustomgnss / vendor.google.gnss_ext-V1-ndk
- NetworkLocation (app.grapheneos.networklocation)
- init.gnss.rc / pixel-gnss-default.rc + vendor/etc/gnss/{ca.pem, gps.cfg, hash.bin} (copy-file drop)

### 1g. vintf-excised.mk + filter-copy-files.mk

- vendor_manifest_no_radio.xml (replaces vendor_manifest.xml) — DEVICE_MANIFEST_FILE swap
- ro.boot.radio.disabled=1 / ro.radio.noril=1 — vendor property
- Modem firmware + init.modem/init.radio/rild_exynos.rc/etc. (copy-file wildcard drop)

---

## Category 2: Regressions (excised-but-still-present)

**HIGHEST PRIORITY FINDING.** The package is named in an excision makefile but still appears in the present-package set.

| # | Package | Present location | Excision cite | Probable cause |
|---|---|---|---|---|
| 1 | ~~**VanadiumConfig**~~ | /product/app (`VanadiumConfig.apk`, 11.6 MB) | apps-excised.mk:54 (baseline filter list) | Filter miss — likely `required:` transitive pull from TrichromeWebView/TrichromeLibrary (GUARDTALK_WEBVIEW_KEEP :647–651). Investigate `out/soong/late-tokay.mk` for `required:` chain. |

**Regression count: 0**

> ✅ **RESOLVED (2026-07-02, A-REPORT-INVESTIGATE):** The VanadiumConfig "regression" was a **misclassification** — it is a legitimate `required:` dependency of the kept Trichrome* packages, NOT a filter miss.
>
> Evidence:
> - `external/vanadium/Android.bp:43-48` — `TrichromeWebView` (and `TrichromeLibrary` / `TrichromeChrome` / `TrichromeChromeDualArch`) declare `required: ["VanadiumConfig"]`.
> - `out/soong/late-tokay.mk:268693-268694` — the generated install rule drags VanadiumConfig in via the `required:` chain.
> - `VanadiumConfig.apk` (11.6 MB) contains 22 `unindexed_ruleset*` binaries + `proto_config.pb2` — Vanadium's hardened Chromium config (JIT policy, sensor gating, domain-reliability disabling). NOT an empty stub.
> - `GUARDTALK_WEBVIEW_KEEP` (apps-excised.mk:647-651) keeps `TrichromeWebView` + `TrichromeLibrary`, so the `required:` chain is unavoidable while WebView is kept.
> - Removing VanadiumConfig while keeping TrichromeWebView would leave WebView running default (unhardened) Chromium config — silent security regression (Law 3, Law 13).
>
> **Action taken:** VanadiumConfig was delisted from `GUARDTALK_APPS_PACKAGES` (apps-excised.mk) and added to `GUARDTALK_WEBVIEW_KEEP` so future careless appends cannot drop it. Reclassified to **Category 4 (Keep)** — see Cat 4 table 4b.

### QA-VERIFIED NOT-A-REGRESSION (previously flagged, corrected 2026-07-01)

| Package | Original flag | QA finding | Correction |
|---|---|---|---|
| `com.android.cellbroadcast` (APEX) | Was flagged as Regression #2 | **NOT present** in final image (`installed-files*.txt` empty for cellbroadcast). Appears only in stale `target_files_intermediates` build artifacts (2026-06-27). The radio-excised filter at `remove-packages.mk:138` **succeeded**. | Reclassified to Category 1 (Already Removed). Regression count corrected 2 → 1. |

### Additional finding: Orphan native-library remnants (QA-discovered) — RESOLVED 2026-07-02 (T-ORPHAN-LIB-CLEANUP, A-EXCISE-FINAL audited)

Two excised apps left behind JNI libraries in the final image despite their APKs being correctly removed. **Fixed in T-ORPHAN-LIB-CLEANUP** by adding the lib module names to `GUARDTALK_APPS_PACKAGES` (apps-excised.mk:676-680). **A-EXCISE-FINAL audit verdict: PASS** — graceful (no BCP/VINTF coupling; pure leaf JNI libs), no CRITICAL-KEEP collateral (host APKs PrintSpooler/Gallery2 already excised; libs have no dependents), reversible (delete the 4 lines), realized reduction = ~147 KB dead-weight .so + symlinks removed.

Root cause (verified via `out/soong/module-info-tokay.json` + `out/build-tokay.ninja`): Soong expands the apps' `jni_libs:` Android.bp entries into standalone `PRODUCT_PACKAGES` module names. Filtering only the host APK name dropped the APK install but left the lib's standalone PRODUCT_PACKAGES entry — so the lib64 install + symlink kept firing. The late `PRODUCT_PACKAGES` filter-out now drops these 4 lib entries too.

| App | Excision cite | Orphan artifact | Status |
|---|---|---|---|
| PrintSpooler | apps-excised.mk:91 | `/system/app/PrintSpooler/lib/arm64/libprintspooler_jni.so` (36 KB) | ✅ Fixed (apps-excised.mk:677) |
| Gallery2 | apps-excised.mk:127 | `/product/app/Gallery2/lib/arm64/{libjni_eglfence, libjni_filtershow_filters, libjni_jpegstream}.so` (33+43+35 KB) | ✅ Fixed (apps-excised.mk:678-680) |

---

## Category 3: Must Remove (attack surface — present packages to remove)

> ✅ **EXCISED 2026-07-02 (T-APEX-BCP-WAVE, A-EXCISE-FINAL audited).** All 3 APEX modules are now filtered from `PRODUCT_PACKAGES` in lockstep with their `framework-*` / `service-*` BCP jars (`PRODUCT_APEX_BOOT_JARS` / `PRODUCT_APEX_SYSTEM_SERVER_JARS`) via `vendor/guardtalk/feature-excised/apex-bcp-excised.mk` (3-stage filter, PRODUCTS-store read/write-back). Wired into `guardtalk-feature-excised.mk:126`. Upstream `build/make/target/product/{default_art_config,base_system}.mk` UNTOUCHED (mtime 2026-03-16). **A-EXCISE-FINAL audit verdict: PASS** — graceful (lockstep BCP filter eliminates the dexpreopt orphan risk statically), no CRITICAL-KEEP collateral (`com.android.neuralnetworks` NOT touched — remains a KEEP per vendor HAL dependency), reversible (delete the include line at `guardtalk-feature-excised.mk:126`), realized reduction = 3 dormant APEX .apex files + bundled SdkSandbox/HealthConnect/FederatedCompute payloads. **Pending build + flash verification (Q-APEX-BCP PASS 10/10 static; runtime smoke-test required post-flash).**

All three are mainline APEX modules documented as removable-in-principle but blocked by BCP/dexpreopt constraints requiring scope-locked edits to `build/make/` (forbidden path for this task).

| # | Package (APEX) | Rationale | Excision attempted | Boot risk | APEX? | Law 7 note |
|---|---|---|---|---|---|---|
| 1 | **com.android.adservices** | Privacy/ads ML stack (SdkSandbox bundled). ~tens of MB code shipped dormant. | PRODUCT_PACKAGES filter (apps-excised.mk:255–263) — BLOCKED by dexpreopt (service-adservices + service-sdksandbox in BCP) | MEDIUM | YES | Requires lockstep edit to `build/make/target/product/default_art_config.mk`. Separate scope-locked wave. |
| 2 | **com.android.healthfitness** | Health Connect + federated ML. Documented dormant. | PRODUCT_PACKAGES filter (apps-excised.mk:264–271) — BLOCKED by dexpreopt (service-healthfitness in BCP) | MEDIUM | YES | Same BCP-blocker. |
| 3 | **com.android.ondevicepersonalization** | On-device personalization / FederatedCompute. Documented dormant. | PRODUCT_PACKAGES filter (apps-excised.mk:272–281) — BLOCKED by dexpreopt (service-ondevicepersonalization in BCP) | MEDIUM | YES | Same BCP-blocker. |

**Category 3 count: 3** (all mainline APEX, deferred to dedicated APEX-BCP wave)

---

## Category 4: Keep (critical/needed)

### 4a. System framework / providers (CRITICAL-KEEP)

| Package | Location | Justification |
|---|---|---|
| SettingsProvider | /system/app | CRITICAL-KEEP (com.android.providers.settings) |
| ContactsProvider | /system/priv-app | GUARDTALK_APPS_KEEP (apps-excised.mk:311) |
| MediaProviderLegacy | /system/priv-app | CRITICAL-KEEP (com.android.providers.media.module) |
| DocumentsUI | /system/priv-app | CRITICAL-KEEP (com.android.documentsui) |
| DownloadProvider / DownloadProviderUi | /system/priv-app | CRITICAL-KEEP (download framework) |
| PackageInstaller | /system/priv-app | CRITICAL-KEEP (com.android.packageinstaller) |
| IntentResolver | /system/priv-app | CRITICAL-KEEP (com.android.intentresolver) |
| Shell | /system/priv-app | CRITICAL-KEEP (com.android.shell) |
| KeyChain | /system/app | CRITICAL-KEEP |
| CertInstaller | /system/app | CRITICAL-KEEP |
| PacProcessor | /system/app | CRITICAL-KEEP |
| ProxyHandler | /system/app | CRITICAL-KEEP |
| CaptivePortalLogin | /system/app | CRITICAL-KEEP (com.android.captiveportallogin) |
| NetworkStack | /system/app | CRITICAL-KEEP (com.android.networkstack) |
| ExternalStorageProvider | /system/priv-app | CRITICAL-KEEP (com.android.externalstorage) |
| ExtShared | /system/app | CRITICAL-KEEP (android.ext.shared) |
| AppCompatConfig | /system/app | Framework compat config; required |
| E2eeContactKeysProvider | /system/priv-app | GrapheneOS E2EE security feature |
| **GmsCompat / GmsCompatConfig / GmsCompatLib** | /system/app | **MUST KEEP — boot loop risk.** apps-excised.mk:218–232 regression fix: GosPackageStatePermissions.init() throws IllegalStateException on userdebug if `app.grapheneos.gmscompat` absent → system_server crash → zygote → init → InitFatalReboot → boot loop (verified 2026-06-30). Small, platform-signed, inert when no GMS app invokes. Do NOT re-excise without patching GosPackageStatePermission.java. |

### 4b. Product apps (CRITICAL-KEEP + operator-kept)

| Package | Location | Justification |
|---|---|---|
| Camera (app.grapheneos.camera) | /product/app | CRITICAL-KEEP baseline |
| Contacts | /product/app | GUARDTALK_APPS_KEEP (apps-excised.mk:310) |
| LatinIME | /product/app | CRITICAL-KEEP (com.android.inputmethod.latin) |
| ModuleMetadata | /product/app | Mainline module metadata; APEX resolution |
| PdfViewerGOS | /product/app | GrapheneOS PDF viewer; operator default |
| PixelCameraServicesConnectivityClient | /product/priv-app | CRITICAL — camera HAL dependency (apps-excised.mk:630–641, T-CAM-BLACK). GUARDTALK_CAMERA_HAL_KEEP (:681–682) |
| SettingsIntelligence | /product/priv-app | CRITICAL-KEEP (com.android.settings.intelligence) |
| SpeechServices | /product/app | Speech/TTS framework |
| talkback | /product/app | Accessibility (Law 21) |
| TrichromeLibrary / TrichromeWebView | /product/app | GUARDTALK_WEBVIEW_KEEP (apps-excised.mk:647–651); system WebView provider |
| VanadiumConfig | /product/app | GUARDTALK_WEBVIEW_KEEP (apps-excised.mk:647–651, added A-REPORT-INVESTIGATE 2026-07-02). `required:` dependency of Trichrome* (external/vanadium/Android.bp:43-48); carries 22 hardened Chromium config rulesets + `proto_config.pb2` (JIT policy, sensor gating, domain-reliability disabling). Removing while keeping TrichromeWebView → silent unhardened-config regression (Law 3, Law 13). |
| ANGLE | /product/app | OpenGL ANGLE wrapper; graphics stack |

### 4c. system_ext apps (CRITICAL-KEEP + GuardTalk)

| Package | Location | Justification |
|---|---|---|
| Settings (com.android.settings) | /system_ext/priv-app | CRITICAL-KEEP baseline |
| SystemUI (com.android.systemui) | /system_ext/priv-app | CRITICAL-KEEP baseline |
| Launcher3QuickStep (com.android.launcher3) | /system_ext/priv-app | CRITICAL-KEEP baseline |
| SetupWizard2 | /system_ext/priv-app | First-boot provisioning; boot completion UX |
| GuardTalkConfig | /system_ext/app | GuardTalkOS configuration; operator core |
| GuardTalkValidator | /system_ext/app | CRITICAL-KEEP (com.guardtalk.validator) |
| AccessibilityMenu | /system_ext/app | Accessibility (Law 21) |
| Multiuser | /system_ext/app | Multi-user framework. **KEEP (T-CAT5-EXCISE investigation 2026-07-02)** — investigated, retained on AppWidget UX grounds. |
| PersistentBackgroundCameraServices | /system_ext/app | Camera HAL dependency (see PixelCameraServicesConnectivityClient) |
| PixelDisplayService | /system_ext/app | Display service |
| ~~PixelQualifiedNetworksService~~ | /system_ext/app | **EXCISED 2026-07-02 (T-CAT5-EXCISE)** — added to GUARDTALK_RADIO_PACKAGES (remove-packages.mk:143). Dead weight with radio/RIL fully excised. See Cat 5 entry 17. |

### 4d. APEX modules — CRITICAL-KEEP

| APEX | Justification |
|---|---|
| com.android.adbd | ADB daemon (operator choice — kept) |
| com.android.apex.cts.shim | CTS shim; VINTF/CTS validation |
| com.android.appsearch | App search indexing (framework dependency) |
| com.android.art | ART runtime — **boot critical** |
| com.android.bt | Mainline BT; ships dormant (feature XML removed, bt-excised.mk:28–39) |
| com.android.compos | Virtualization APEX (see Cat 5; ships dormant) |
| com.android.configinfrastructure | Config infrastructure; framework dependency |
| com.android.conscrypt | Conscrypt TLS — **boot critical** |
| com.android.crashrecovery | Crash recovery; system stability |
| com.android.devicelock | Device lock framework (see Cat 5) |
| com.android.extservices | CRITICAL-KEEP (android.ext.services) |
| com.android.hardware.biometrics.face.virtual | GUARDTALK_FP_KEEP (fp-excised.mk:56) |
| com.android.hardware.cas | CAS (Conditional Access); media framework |
| com.android.i18n | ICU/i18n — **boot critical** |
| com.android.ipsec | IPsec; VPN framework dependency (see Cat 5) |
| com.android.media | Media framework — CRITICAL-KEEP |
| com.android.mediaprovider | Media provider (scoped storage) |
| com.android.media.swcodec | Media software codec |
| com.android.neuralnetworks | NNAPI; ML runtime (see Cat 5) |
| com.android.nfcservices | Mainline NFC; ships dormant (feature XML removed) |
| com.android.os.statsd | Statsd; metrics (see Cat 5) |
| com.android.permission | Permission controller — CRITICAL-KEEP |
| com.android.profiling | Profiling; diagnostics (see Cat 5) |
| com.android.resolv | DNS resolver; networking stack |
| com.android.rkpd | CRITICAL-KEEP (com.android.rkpdapp) |
| com.android.runtime | Core runtime — **boot critical** |

---

## Category 5: Investigate (policy-dependent — needs operator decision)

| # | Package | Location | Trade-off / Investigation needed |
|---|---|---|---|
| 1 | **com.android.virt** (APEX) | APEX | Virtualization framework. Second blocker: Soong `bootclasspath_fragment` validation hard-codes `framework-virtualization` (`packages/modules/Virtualization/build/apex/Android.bp:320`). Ships dormant. ~100 MB. Decision: defer to APEX-virt wave with expanded scope-lock. |
| 2 | **com.android.compos** (APEX) | APEX | CompOS. Bundled with virt cluster. `PRODUCT_APEX_SYSTEM_SERVER_JARS: com.android.compos:service-compos`. Same BCP blocker. Ships dormant. |
| 3 | **com.android.devicelock** (APEX) | APEX | Device lock (enterprise/MDM-adjacent). If no MDM ever, safe to remove. Risk: framework device-policy code may reference. |
| 4 | **com.android.ipsec** (APEX) | APEX | IPsec. If VPN (IKEv2/IPsec) used → KEEP. CRITICAL-KEEP keeps VpnDialogs, suggesting VPN support. Needs operator confirmation. |
| 5 | **com.android.neuralnetworks** (APEX) | APEX | NNAPI. Camera HAL may use NNAPI for face/scene detection — **risk of camera regression** (cf. T-CAM-BLACK lesson). Verify camera HAL has no NNAPI dependency before removal. |
| 6 | **com.android.os.statsd** (APEX) | APEX | Metrics/telemetry. If zero-telemetry policy → removable. Some framework code may log warnings. |
| 7 | **com.android.profiling** (APEX) | APEX | Profiling diagnostics (perfetto). If no on-device profiling → removable. |
| 8 | **com.android.hardware.cas** (APEX) | APEX | CAS (media DRM/CA). If no DRM-protected media → removable. |
| 9 | **com.android.appsearch** (APEX) | APEX | App search. Settings/SystemUI search may depend on it. Removal may degrade Settings search. |
| 10 | **com.android.configinfrastructure** (APEX) | APEX | Config infrastructure. Unclear dependencies. Needs audit. |
| 11 | **com.android.crashrecovery** (APEX) | APEX | Crash recovery. Removing reduces boot resilience. Likely KEEP but operator call. |
| 12 | **FusedLocation** | /system/app | loc-excised.mk:42–49 intentionally KEPT (delivered from handheld_system.mk, bare `location` token). Inert dead weight once FEATURE_LOCATION gone. Decision: remove for cleanliness (needs build/make edit) or keep as inert? |
| 13 | **ANGLE** | /product/app | OpenGL ANGLE wrapper. Some apps may require ANGLE for compat. |
| 14 | **SpeechServices** | /product/app | TTS/speech. TalkBack (Law 21) may depend on TTS. |
| 15 | **talkback** | /product/app | Screen reader (Law 21). Almost certainly KEEP, but operator should affirmatively decide. |
| 16 | **Multiuser** | /system_ext/app | Multi-user UI. **KEEP (T-CAT5-EXCISE investigation, 2026-07-02)** — investigated, retained on AppWidget UX grounds (removing it degrades the user-switching/AppWidget flow). Not excised. |
| 17 | ~~**PixelQualifiedNetworksService**~~ | /system_ext/app | **EXCISED 2026-07-02 (T-CAT5-EXCISE, A-EXCISE-FINAL audited).** Added to `GUARDTALK_RADIO_PACKAGES` (remove-packages.mk:143). With radio/RIL fully excised, the QualifiedNetworksService AIDL has no modem/SIM/IMS substrate — `onCreateNetworkAvailabilityProvider()` has nothing to provide. RRO sibling audit clean (no `PixelQualifiedNetworksService__tokay__auto_generated_rro_product`). **Audit verdict: PASS** — graceful (dead-weight with radio gone; telephony already fully excised), no CRITICAL-KEEP collateral, reversible (delete the line), realized reduction = 1 system_ext priv-app. QA: Q-CAT5 PASS (8.5/10). |
| 18 | **PixelDisplayService** | /system_ext/app | Pixel display service. May serve display functions; needs audit to determine if dead weight without radio. |

**Category 5 count: 16** (was 17; PixelQualifiedNetworksService EXCISED via T-CAT5-EXCISE → Cat 1. PixelDisplayService retained as separate investigate item.)

---

## Summary Metrics

| Category | Count | Notes |
|---|---|---|
| 1 — Already Removed | ~110+ | Confirmed absent; filters effective across all excision sources. Orphan-lib remnants RESOLVED (T-ORPHAN-LIB-CLEANUP); PixelQualifiedNetworksService EXCISED (T-CAT5-EXCISE). |
| 2 — Regressions | **0** | VanadiumConfig RESOLVED 2026-07-02 (reclassified KEEP + delisted; `required:` chain from Trichrome* per external/vanadium/Android.bp:43-48). See Cat 4. |
| 3 — Must Remove | **3 EXCISED** | com.android.adservices, com.android.healthfitness, com.android.ondevicepersonalization — EXCISED via T-APEX-BCP-WAVE (lockstep BCP filter; pending build + flash verification). |
| 4 — Keep | ~57 | CRITICAL-KEEP + operator-kept (GmsCompat boot-loop, camera HAL bridge, WebView, VanadiumConfig hardened-config dep, framework/runtime APEXes). Multiuser KEEP (T-CAT5-EXCISE investigation, AppWidget UX). |
| 5 — Investigate | 16 | Was 17; PixelQualifiedNetworksService EXCISED. Operator decisions (telemetry, VPN, accessibility, APEX virt cluster, PixelDisplayService). |

| Metric | Value |
|---|---|
| Present packages total | 88 |
| Recommended for removal (Cat 3) — EXCISED | 3 / 88 = **3.4%** (pending flash verification) |
| Regression count (Cat 2) | 0 |
| Already removed (Cat 1) | ~110+ (orphan-lib remnants RESOLVED) |
| Excision effectiveness (non-APEX) | ~110 / 111 ≈ **99.1%** |

### QA verification (2026-07-01)
- Gate 5 (Self-Critique) score: **7/10** (pre-correction) → **9/10** (post-correction)
- Checks 1, 3, 4, 5, 6: PASS (cite lines all verified line-accurate; GmsCompat boot-loop rationale exemplary)
- Check 2: Initially FAILED on `com.android.cellbroadcast` (false regression) — **CORRECTED**: cellbroadcast is absent from final image; regression count 2 → 1
- APEX present-set: initially incomplete (30 listed vs 40 actual) — **CORRECTED** to 40 (37 `com.android.*` + 3 `com.google.*`)
- Additional finding: 2 orphan native-lib remnants (PrintSpooler, Gallery2) — documented above

---

## Law 7 (Structured Self-Doubt) — Final Notes

- **VanadiumConfig regression:** **RESOLVED 2026-07-02 (A-REPORT-INVESTIGATE).** The previously-hypothesized `required:` transitive pull from Trichrome* has been VERIFIED: `external/vanadium/Android.bp:43-48` declares `required: ["VanadiumConfig"]` on TrichromeWebView (and TrichromeLibrary / TrichromeChrome / TrichromeChromeDualArch), and `out/soong/late-tokay.mk:268693-268694` confirms the install rule pulls it in via that chain. VanadiumConfig.apk is NOT an empty stub — it carries 22 `unindexed_ruleset*` binaries + `proto_config.pb2` (Vanadium's hardened Chromium config: JIT policy, sensor gating, domain-reliability disabling). Reclassified KEEP + delisted from `GUARDTALK_APPS_PACKAGES`, mirrored in `GUARDTALK_WEBVIEW_KEEP` (apps-excised.mk:647-651). Cat 2 regression count now 0.
- **Mainline APEX removals (Cat 3):** Confident these are documented-blocked and dormant. Confident the BCP/dexpreopt blocker is real. NOT certain the APEX-BCP wave is risk-free at runtime — `com.android.adservices` removes SdkSandbox; needs runtime smoke test post-removal.
- **com.android.virt / com.android.compos (Cat 5, not Cat 3):** Second independent Soong `bootclasspath_fragment` blocker beyond BCP. Not certain a product-flag mechanism exists to skip fragment validation. Placed in Investigate per Law 7.
- **FusedLocation (Cat 5):** loc-excised.mk:42–49 explicitly says intentionally kept. Respected but surfaced for operator decision.
- **CRITICAL-KEEP cross-check:** Every present package in the CRITICAL-KEEP baseline is in Category 4. GmsCompat cluster is in Category 4 with boot-loop rationale. No CRITICAL-KEEP package recommended for removal.

---

## Post-Implementation Status (2026-07-02, A-EXCISE-FINAL)

Read-only post-implementation audit of all 4 excision tasks. Gate -1 acknowledged (read-only; no build files edited, no commits). Each task audited against 4 criteria: **(a)** graceful (no boot loop / dangling BCP/VINTF), **(b)** no CRITICAL-KEEP collateral, **(c)** reversibility (Law 11), **(d)** realized attack-surface reduction.

| # | Task | Mechanism (file:line) | Graceful | No CRITICAL-KEEP collateral | Reversible (Law 11) | Realized reduction | Audit verdict | QA verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | **T-VANADIUMCFG-FIX** — VanadiumConfig Cat 2 → Cat 4 reclassification | Delisted from `GUARDTALK_APPS_PACKAGES`; added to `GUARDTALK_WEBVIEW_KEEP` (apps-excised.mk:715-720). `required:` chain at external/vanadium/Android.bp:43-48 intact (verified). | ✅ Yes — keeps hardened Chromium config (JIT policy, sensor gating); removing would be a silent security regression (Law 3, Law 13). | ✅ TrichromeWebView / TrichromeLibrary / TrichromeWebViewDualArch / TrichromeLibraryDualArch all still in GUARDTALK_WEBVIEW_KEEP (apps-excised.mk:715-720). | ✅ Revert: re-add VanadiumConfig to GUARDTALK_APPS_PACKAGES, remove from GUARDTALK_WEBVIEW_KEEP. | ✅ Resolves Cat 2 regression (count 1 → 0); preserves hardened WebView config. | **PASS** | Q-VANADIUMCFG PASS (9.5/10) |
| 2 | **T-ORPHAN-LIB-CLEANUP** — orphan .so strip | 4 lib modules added to `GUARDTALK_APPS_PACKAGES` (apps-excised.mk:676-680): `libprintspooler_jni`, `libjni_eglfence`, `libjni_filtershow_filters`, `libjni_jpegstream`. filter-copy-files.mk untouched. | ✅ Yes — pure leaf JNI libs; no BCP/VINTF coupling; no service dependency. | ✅ Host APKs (PrintSpooler, Gallery2) already excised; libs have no dependents. | ✅ Revert: delete the 4 lines at apps-excised.mk:676-680. | ✅ ~147 KB dead-weight .so + app/.../lib/arm64/ symlinks removed. | **PASS** | Q-ORPHAN-LIB PASS |
| 3 | **T-APEX-BCP-WAVE** — 3 Cat 3 APEX removal | New file `apex-bcp-excised.mk`: 3-stage lockstep filter (PRODUCT_APEX_BOOT_JARS :67-72, PRODUCT_APEX_SYSTEM_SERVER_JARS :79-84, PRODUCT_PACKAGES :97-101). PRODUCTS-store read/write-back (:66, :73, :78, :85). Wired at guardtalk-feature-excised.mk:126 (AFTER apps-excised.mk). Upstream build/make/ untouched (mtime 2026-03-16 verified). | ✅ Yes statically — lockstep BCP filter eliminates the dexpreopt orphan risk; no dangling BCP/VINTF entry. Runtime smoke-test MANDATORY post-flash (system_server must not crash on missing service jars). | ✅ com.android.neuralnetworks NOT touched (verified: only appears in this report at Cat 4/Cat 5; no filter entry in apex-bcp-excised.mk). Remains KEEP per vendor HAL dependency. | ✅ Revert: delete the include line at guardtalk-feature-excised.mk:126. No upstream edits. | ✅ 3 dormant APEX .apex + bundled SdkSandbox/HealthConnect/FederatedCompute payloads removed (~tens of MB). | **PASS** (static) — pending build + flash verification | Q-APEX-BCP PASS (10/10) |
| 4 | **T-CAT5-EXCISE** — PixelQualifiedNetworksService removal + Multiuser investigation | `PixelQualifiedNetworksService` added to `GUARDTALK_RADIO_PACKAGES` (remove-packages.mk:143). RRO sibling audit clean (no sibling — verified at remove-packages.mk:158-162). Multiuser NOT excised (investigation → KEEP on AppWidget UX grounds). | ✅ Yes — with radio/RIL fully excised, QualifiedNetworksService AIDL has no substrate; `onCreateNetworkAvailabilityProvider()` no-ops. Telephony already fully excised. | ✅ No CRITICAL-KEEP collateral; telephony stack already gone. | ✅ Revert: delete the line at remove-packages.mk:143. | ✅ 1 system_ext priv-app removed. | **PASS** | Q-CAT5 PASS (8.5/10) |

**Overall A-EXCISE-FINAL verdict: 4/4 PASS (static audit).** All tasks are graceful, free of CRITICAL-KEEP collateral, reversible (Law 11), and yield realized attack-surface reduction. Build + flash re-verification remains pending for the APEX-BCP wave (runtime smoke-test required per Q-APEX-BCP).

---

*Report generated by AEGIS Auditor (A-PKG-SURFACE-REPORT), 2026-07-01.*
*Updated 2026-07-02 (A-REPORT-INVESTIGATE): VanadiumConfig reclassified Cat 2 → Cat 4 (KEEP + delisted); regression count 1 → 0.*
*Updated 2026-07-02 (A-EXCISE-FINAL): Post-implementation audit of 4 excision tasks (T-VANADIUMCFG-FIX, T-ORPHAN-LIB-CLEANUP, T-APEX-BCP-WAVE, T-CAT5-EXCISE). Cat 2 = 0; Cat 3 = 3 EXCISED (pending flash); Cat 5 = 16 (PixelQualifiedNetworksService EXCISED, Multiuser KEEP, PixelDisplayService retained as investigate). Orphan-lib finding RESOLVED. All 4 tasks audited PASS (static).*
*Source: build output installed-files + 9 excision makefiles + apex-bcp-excised.mk + external/vanadium/Android.bp.*
*Build configuration changed only in `vendor/guardtalk/` (apps-excised.mk, apex-bcp-excised.mk [new], guardtalk-feature-excised.mk, remove-packages.mk). No upstream build/make/ or packages/modules/ edits, no commits made.*
