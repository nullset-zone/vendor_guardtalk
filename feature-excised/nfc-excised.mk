# T-W2-I3-NFC — 5-layer graceful excision of the NFC HAL.
#
# Scope: STMicro ST21NFC NFC HAL (android.hardware.nfc-service.st), its NCI
# HAL library (nfc_nci.st21nfc.default), the NDK vendor stubs, the four
# feature-permission prebuilt XMLs (ese/hce/hcef/core), the standalone VINTF
# fragment module (nfc-service-default.xml), the bundled init .rc
# (nfc-service-default.rc, shipped via Soong init_rc on the service package),
# the PixelNfc priv-app, and the two PixelNfc overlays that target
# com.android.nfc. The libnfc-nci.conf / libnfc-hal-st.conf config copies are
# also filtered from PRODUCT_COPY_FILES since they only feed the removed HAL.
#
# Pattern: same late product-config filter-out as apps-excised.mk and
# fp-excised.mk. Idempotent and order-independent. Runs after all
# inherit-product merges (via product-config-late.mk ->
# guardtalk-feature-excised.mk), so PRODUCT_PACKAGES / PRODUCT_COPY_FILES are
# fully populated.
#
# CRITICAL INVARIANT: The AOSP/mainline Nfc app (com.android.nfc /
# com.google.android.nfc) is NOT in tokay.mk PRODUCT_PACKAGES — it is delivered
# via a mainline module (APEX) and is therefore out of reach of a
# PRODUCT_PACKAGES filter. Grace is achieved by dropping the feature-permission
# prebuilts so hasSystemFeature(FEATURE_NFC) / FEATURE_NFC_HOST_CARD_EMULATION
# / FEATURE_NFC_HOST_CARD_EMULATION_NFCF / FEATURE_NFC_ESE return false. The
# mainline Nfc stack keys off these features and stays dormant; Settings and
# SystemUI hide all NFC entry points at runtime. Verified gates:
#   - Settings: NfcAndPaymentFragmentController.getAvailabilityStatus()
#     (packages/apps/Settings/src/com/android/settings/connecteddevice/
#      NfcAndPaymentFragmentController.java:80-86) returns UNSUPPORTED_ON_DEVICE
#     when FEATURE_NFC or FEATURE_NFC_HOST_CARD_EMULATION is absent.
#   - SystemUI: NfcTile.isAvailable()
#     (frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/
#      NfcTile.java:103-110) returns false when FEATURE_NFC is absent.
#
# CRITICAL INVARIANT: ro.build.fingerprint (a build property) is UNRELATED to
# the NFC HAL. No NFC service lines exist in init.tokay.rc beyond a benign
# persist.vendor.nfc.streset property set (line 13) and init.zumapro.board.rc
# has only a benign /data/vendor/nfc mkdir (lines 664-666). Neither is a HAL
# service definition; both are harmless with the HAL gone (no consumer).
# Per Law 6 (Minimal Footprint), no filtered copies of these init files are
# created — the actual NFC HAL service .rc (nfc-service-default.rc) is bundled
# with the android.hardware.nfc-service.st package via Soong init_rc and is
# removed automatically when that package is dropped (Layer 1).
#
# Out of scope (MUST NOT touch in this increment): Bluetooth, Location,
# Fingerprint, Face biometrics.

# T-PKG-EXCISE-WAVES P0 — com.android.se / SecureElement paired with the NFC
# subsystem. com.android.se is the off-host SecureElement app (OMAPI/SIM
# access) and is functionally bound to the NFC HAL (the ST21NFC eSE channel is
# its only transport on tokay). Excising it with the NFC filter (rather than
# apps-excised.mk) keeps the SE/NFC pair atomically removed so no orphaned SE
# app references a missing HAL. Module name verified as a Soong module in
# out/soong/late-tokay.mk:242517 and as a PRODUCT_PACKAGES entry in
# build/make/target/product/handheld_system.mk:73. Reversible (filter-out only).

# ---------------------------------------------------------------------------
# Layer 1 — Package layer: NFC HAL packages, daemons, apps, and overlays.
# ---------------------------------------------------------------------------
GUARDTALK_NFC_PACKAGES := \
    android.hardware.nfc-V1-ndk.vendor \
    android.hardware.nfc-service.st \
    android.hardware.nfc.ese.prebuilt.xml \
    android.hardware.nfc.hce.prebuilt.xml \
    android.hardware.nfc.hcef.prebuilt.xml \
    android.hardware.nfc.prebuilt.xml \
    nfc-service-default.xml \
    nfc_nci.st21nfc.default \
    PixelNfc \
    PixelNfcOverlayCommon \
    PixelNfcOverlayTokay \
    SecureElement

# Defence-in-depth: catch any other NFC-named packages that a future adevtool
# regen might slide into PRODUCT_PACKAGES. The wildcard match is scoped to
# NFC-only tokens so it cannot accidentally hit unrelated packages (e.g.
# ro.build.fingerprint is a property, not a package, so the fingerprint token
# is safe to ignore here). Scoped to android.hardware.nfc*, nfc_nci*,
# nfc-service*, PixelNfc*, and *Nfc* prebuilt XMLs.
define _gt-nfc-package-drop
$(or \
  $(findstring android.hardware.nfc,$(1)), \
  $(findstring nfc_nci.,$(1)), \
  $(findstring nfc-service-,$(1)), \
  $(findstring PixelNfc,$(1)), \
  $(findstring .nfc.prebuilt.xml,$(1)), \
  $(findstring libnfc-nci,$(1)), \
  $(findstring libnfc-hal,$(1)))
endef

_gt_filtered_product_packages :=
$(foreach p,$(filter-out $(GUARDTALK_NFC_PACKAGES),$(PRODUCT_PACKAGES)),\
  $(if $(call _gt-nfc-package-drop,$(p)),,\
    $(eval _gt_filtered_product_packages += $(p))))
PRODUCT_PACKAGES := $(strip $(_gt_filtered_product_packages))

# Defence-in-depth: also strip the libnfc-nci / libnfc-hal config copies from
# PRODUCT_COPY_FILES. These are HAL-side configs (libnfc-nci.conf at
# tokay.mk:1537 -> product/etc/libnfc-nci.conf, libnfc-hal-st.conf at
# tokay.mk:1760 -> vendor/etc/libnfc-hal-st.conf) that only feed the removed
# ST HAL. Leaving them would be dead weight; filtering keeps the image clean
# and prevents a stale config from reviving HAL assumptions.
define _gt-nfc-copy-file-drop
$(or \
  $(findstring libnfc-nci.conf,$(1)), \
  $(findstring libnfc-hal-st.conf,$(1)))
endef

_gt_nfc_filtered_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt-nfc-copy-file-drop,$(cf)),,\
    $(eval _gt_nfc_filtered_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_nfc_filtered_copy_files))

# ---------------------------------------------------------------------------
# Layer 2 — Feature XML layer: NFC feature declarations.
# ---------------------------------------------------------------------------
# The four android.hardware.nfc*.prebuilt.xml modules are the
# feature-permission prebuilts that declare PackageManager.FEATURE_NFC,
# FEATURE_NFC_HOST_CARD_EMULATION, FEATURE_NFC_HOST_CARD_EMULATION_NFCF, and
# FEATURE_NFC_ESE to the framework. Removing them from PRODUCT_PACKAGES
# (Layer 1 above) causes hasSystemFeature() to return false for all NFC
# features, which is what gracefully hides NFC UI in Settings, SystemUI, and
# the mainline Nfc app. No separate copy-files filter is needed because these
# prebuilts are delivered as PRODUCT_PACKAGES modules, not PRODUCT_COPY_FILES
# entries. (Verified: grep "nfc.prebuilt.xml:" in tokay.mk PRODUCT_COPY_FILES
# returns nothing; the names appear only in the PRODUCT_PACKAGES block at
# tokay.mk:241-244.)

# ---------------------------------------------------------------------------
# Layer 3 — VINTF fragment layer: remove NFC HAL from vendor manifest.
# ---------------------------------------------------------------------------
# The ST NFC HAL VINTF fragment (nfc-service-default.xml) declares
# android.hardware.nfc INfc/default to the vendor manifest. It is defined as a
# Soong vintf_fragment module at hardware/st/nfc/aidl/Android.bp:64-68 and is
# also wired as vintf_fragment_modules on the android.hardware.nfc-service.st
# package (Android.bp:40). Dropping both the service package and the explicit
# nfc-service-default.xml PRODUCT_PACKAGES entry (Layer 1 above) removes the
# HAL declaration so libvintf compatibility checks no longer expect an NFC HAL
# to be running. No adevtool_vintf_fragment_vendor_*nfc* fragment exists in
# vendor/google_devices/tokay/vintf/vendor/manifest/ (verified: the manifest
# fragment directory contains no NFC-named file and no fragment references
# android.hardware.nfc), so no DEVICE_MANIFEST_FILE filter is required here.
# The existing radio-excised/vintf-excised.mk handles the radio manifest swap
# and is intentionally NOT extended for NFC (NFC has no adevtool fragment to
# filter).

# ---------------------------------------------------------------------------
# Layer 4 — init .rc layer: remove NFC service init lines.
# ---------------------------------------------------------------------------
# The NFC HAL service is started by nfc-service-default.rc:
#     service nfc_hal_service /vendor/bin/hw/android.hardware.nfc-service.st
#         class hal
#         user nfc
#         group nfc
# This .rc is shipped via Soong init_rc on the android.hardware.nfc-service.st
# package (hardware/st/nfc/aidl/Android.bp:39). Dropping that package (Layer 1
# above) removes the .rc from the build, so init never loads the NFC service
# definition. No PRODUCT_COPY_FILES entry exists for nfc-service-default.rc
# (verified: grep in tokay.mk returns nothing), so no copy-files filter is
# needed for the service .rc.
#
# NOTE on init.tokay.rc and init.zumapro.board.rc: the task brief expected NFC
# service init lines in these files. Verified at baseline:
#   - init.tokay.rc:13 sets `persist.vendor.nfc.streset libstreset24` (a
#     benign property; no consumer once the HAL is gone).
#   - init.zumapro.board.rc:664-666 mkdir /data/vendor/nfc 0770 nfc nfc (a
#     benign data dir; no consumer once the HAL is gone).
# Neither is a HAL service definition. Creating filtered copies of these init
# files purely to drop two benign lines would violate Law 6 (Minimal Footprint)
# and add maintenance burden with no functional benefit (the NFC service never
# starts because its .rc is gone). Scope-assumption discrepancy surfaced for
# Architect (see report). The libnfc-nci.conf / libnfc-hal-st.conf config
# copies (the only NFC-related PRODUCT_COPY_FILES) are filtered in Layer 1.

# ---------------------------------------------------------------------------
# Layer 5 — Framework grace layer: Settings + SystemUI overlays.
# ---------------------------------------------------------------------------
# Wired in guardtalk-feature-excised.mk -> feature-overlays.mk (created in
# T-W2-I2-FP; the Settings + FrameworksBase overlays are already wired via
# radio-excised/telephony-features.mk, and the SystemUI overlay via
# feature-overlays.mk). The overlays add NFC-specific grace entries below so
# that even if a stale feature flag lingers, Settings and SystemUI treat NFC
# as unsupported. The real hiding is the runtime hasSystemFeature() check
# (Layer 2), but these overlays are defence-in-depth:
#   - Settings: no NFC-specific config boolean exists to override (Settings
#     gates NFC UI on PackageManager.FEATURE_NFC, verified at
#     NfcAndPaymentFragmentController.java:80-86). The overlay documents the
#     contract and pins the connected-device NFC preference key.
#   - SystemUI: the QS tile stock list (quick_settings_tiles_stock) includes
#     an `nfc` token; the NfcTile.isAvailable() check already short-circuits
#     on the missing feature, but the overlay also strips `nfc` from the
#     stock tile list so the tile is never even considered for auto-add.
