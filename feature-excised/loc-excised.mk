# T-W2-I5-LOC / T-LOC-FULL — 5-layer graceful excision of the GPS/GNSS HAL
# AND full removal of FEATURE_LOCATION + FEATURE_LOCATION_NETWORK + the
# NetworkLocation app.
#
# Scope: Samsung S5400 "Lassen" GNSS HAL (android.hardware.gnss-service +
# android.hardware.gnss-service.pixel), its HIDL/NDK vendor stubs
# (android.hardware.gnss-V3-ndk, .measurement_corrections@1.0/@1.1,
# .visibility_control@1.0, .gnss@1.0/@1.1/@2.0/@2.1), the vendor extension
# (vendor.google.gnss_ext-V1-ndk), the custom GNSS impl lib (libcustomgnss),
# the Lassen modem-bridge daemon + test binary + constants (gnssd, gnss_test,
# lassen_dmd_constants), the GPS feature-permission prebuilt
# (android.hardware.location.gps.prebuilt.xml), the two GNSS VINTF fragments
# (adevtool_vintf_fragment_vendor_android.hardware.gnss@lassen.xml,
# adevtool_vintf_fragment_vendor_pixel-gnss-default.xml), the two GNSS init .rc
# files (init.gnss.rc, pixel-gnss-default.rc), and the GNSS-side vendor config
# copies (vendor/etc/gnss/ca.pem, gps.cfg, hash.bin).
#
# Pattern: same late product-config filter-out as apps-excised.mk,
# fp-excised.mk, nfc-excised.mk, and bt-excised.mk. Idempotent and
# order-independent. Runs after all inherit-product merges (via
# product-config-late.mk -> guardtalk-feature-excised.mk), so PRODUCT_PACKAGES
# / PRODUCT_COPY_FILES are fully populated.
#
# CRITICAL INVARIANT (T-LOC-FULL, reconciled): FEATURE_LOCATION is now FULLY
# REMOVED, not just FEATURE_LOCATION_GPS. The two feature declarations in
# vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml
# (android.hardware.location + android.hardware.location.network) are dropped
# at the XML layer, and android.hardware.location.gps.prebuilt.xml is dropped
# from PRODUCT_PACKAGES below. hasSystemFeature(FEATURE_LOCATION),
# FEATURE_LOCATION_NETWORK, and FEATURE_LOCATION_GPS all return false.
#
# Boot-loop risk was assessed and is SAFE:
#   - LocationManagerService.Lifecycle is started UNCONDITIONALLY in
#     SystemServer (line ~2374, no feature guard), so the service always
#     boots.
#   - Inside LocationManagerService (line ~483), the FEATURE_LOCATION check
#     only gates GNSS init, NOT the service startup.
#   - The "no fused location provider" path just calls Log.wtf; it does NOT
#     crash. So removing FEATURE_LOCATION is safe: LocationManagerService
#     starts, finds no providers, logs a warning, and continues. No boot loop.
#
# CRITICAL INVARIANT: FusedLocation (com.android.location.fused) is STILL KEPT
# (out of reach of this filter — it is delivered from
# build/make/target/product/handheld_system.mk, NOT tokay.mk, and the bare
# `location` token is deliberately NOT matched by the wildcard below). It is
# harmless dead weight once FEATURE_LOCATION is gone (LocationManagerService
# simply logs that no provider is available) but removing it would be out of
# this increment's scope and would violate Law 6 (Minimal Footprint). It is
# intentionally NOT matched by the filter below.
#
# CRITICAL INVARIANT: The NetworkLocation app (app.grapheneos.networklocation,
# Soong module name `NetworkLocation`, added to PRODUCT_PACKAGES at
# build/make/target/product/handheld_system.mk:65) is NOW EXCISED. It is the
# GrapheneOS Apple-WPS network location provider; with FEATURE_LOCATION gone
# it has no consumer, so it is dropped in Layer 1 below. Its `required:`
# modules (etc_permissions_app.grapheneos.networklocation.xml,
# etc_sysconfig_app.grapheneos.networklocation.xml) ride along via Soong and
# are removed transitively. Note: the config_locationProviderPackageNames
# entry in frameworks/base/core/res/res/values/config.xml still references
# `app.grapheneos.networklocation` — that is the upstream framework, which is
# out of scope (Law 6); LocationManagerService simply finds the package
# absent at runtime and continues (graceful degradation, Law 9).
#
# CRITICAL INVARIANT: The CHRE location nanoapp is KEPT. The `location` package
# (vendor/google_devices/tokay/proprietary/Android.bp:1696, a prebuilt_etc
# shipping vendor/etc/chre/location.so) and the chre/location.napp_header
# PRODUCT_COPY_FILES entry (tokay.mk:1611) are Context Hub Runtime nanoapps,
# NOT the GNSS HAL. They feed the always-on context hub DSP low-power sensor
# fusion, not GNSS. Removing them would be collateral damage beyond the
# location-excision scope and would violate Law 6 (Minimal Footprint). They
# are intentionally NOT matched by the filter below (the bare `location` token
# is too broad and would risk matching FusedLocation; the filter is scoped to
# GNSS-only + the exact NetworkLocation app name).
#
# Out of scope (MUST NOT touch in this increment): Bluetooth, NFC, Fingerprint,
# Face biometrics, FusedLocation, CHRE nanoapps, frameworks/base source
# (LocationManagerService starts unconditionally and is safe).

# ---------------------------------------------------------------------------
# Layer 1 — Package layer: GNSS HAL packages, daemons, libs, and the
# NetworkLocation app. FEATURE_LOCATION / FEATURE_LOCATION_NETWORK are dropped
# at the XML layer (handheld_core_hardware.prebuilt.xml); the GPS feature
# prebuilt (android.hardware.location.gps.prebuilt.xml) and the NetworkLocation
# app are dropped here at the PRODUCT_PACKAGES layer.
# ---------------------------------------------------------------------------
GUARDTALK_LOC_PACKAGES := \
    android.hardware.gnss-V3-ndk.vendor \
    android.hardware.gnss-service \
    android.hardware.gnss-service.pixel \
    android.hardware.gnss.measurement_corrections@1.0.vendor \
    android.hardware.gnss.measurement_corrections@1.1.vendor \
    android.hardware.gnss.visibility_control@1.0.vendor \
    android.hardware.gnss@1.0.vendor \
    android.hardware.gnss@1.1.vendor \
    android.hardware.gnss@2.0.vendor \
    android.hardware.gnss@2.1.vendor \
    android.hardware.location.gps.prebuilt.xml \
    adevtool_vintf_fragment_vendor_android.hardware.gnss@lassen.xml \
    adevtool_vintf_fragment_vendor_pixel-gnss-default.xml \
    gnss_test \
    gnssd \
    lassen_dmd_constants \
    libcustomgnss \
    vendor.google.gnss_ext-V1-ndk \
    NetworkLocation

# Defence-in-depth: catch any other GNSS-named packages that a future adevtool
# regen might slide into PRODUCT_PACKAGES. The wildcard match is scoped to
# GNSS-only tokens + the exact NetworkLocation app name so it cannot
# accidentally hit FusedLocation, the CHRE location nanoapp, or unrelated
# packages. Scoped to android.hardware.gnss*,
# adevtool_vintf_fragment_vendor_*gnss*, vendor.google.gnss*, libcustomgnss,
# gnssd, gnss_test, lassen_dmd_constants, and NetworkLocation. The bare
# `location` token is deliberately NOT matched (would hit FusedLocation + the
# CHRE nanoapp).
define _gt-loc-package-drop
$(or \
  $(findstring android.hardware.gnss,$(1)), \
  $(findstring android.hardware.location.gps,$(1)), \
  $(findstring adevtool_vintf_fragment_vendor_android.hardware.gnss,$(1)), \
  $(findstring adevtool_vintf_fragment_vendor_pixel-gnss,$(1)), \
  $(findstring vendor.google.gnss,$(1)), \
  $(findstring libcustomgnss,$(1)), \
  $(findstring gnssd,$(1)), \
  $(findstring gnss_test,$(1)), \
  $(findstring lassen_dmd_constants,$(1)), \
  $(findstring NetworkLocation,$(1)))
endef

_gt_filtered_product_packages :=
$(foreach p,$(filter-out $(GUARDTALK_LOC_PACKAGES),$(PRODUCT_PACKAGES)),\
  $(if $(call _gt-loc-package-drop,$(p)),,\
    $(eval _gt_filtered_product_packages += $(p))))
PRODUCT_PACKAGES := $(strip $(_gt_filtered_product_packages))

# Defence-in-depth: also strip the GNSS-side vendor config copies and the GNSS
# init .rc files from PRODUCT_COPY_FILES. These only feed the removed GNSS HAL:
#   - vendor/etc/init/init.gnss.rc (the S5400 Lassen GNSS service .rc: defines
#     the gnssd daemon, slsi_gnss_service -> android.hardware.gnss-service,
#     and GPS data-dir/permission setup)
#   - vendor/etc/init/pixel-gnss-default.rc (the pixel.gnss-default service
#     -> android.hardware.gnss-service.pixel)
#   - vendor/etc/gnss/ca.pem, gps.cfg, hash.bin (Lassen GNSS cert + config +
#     integrity hash; no consumer once the HAL is gone)
# Leaving them would be dead weight and could let a stale config revive HAL
# assumptions after a future regen. The non-GNSS chre/location.napp_header
# (tokay.mk:1611) is intentionally NOT matched (CHRE nanoapp, kept).
define _gt-loc-copy-file-drop
$(or \
  $(findstring /etc/init/init.gnss.rc,$(1)), \
  $(findstring /etc/init/pixel-gnss-default.rc,$(1)), \
  $(findstring /etc/gnss/ca.pem,$(1)), \
  $(findstring /etc/gnss/gps.cfg,$(1)), \
  $(findstring /etc/gnss/hash.bin,$(1)))
endef

_gt_loc_filtered_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt-loc-copy-file-drop,$(cf)),,\
    $(eval _gt_loc_filtered_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_loc_filtered_copy_files))

# ---------------------------------------------------------------------------
# Layer 2 — Feature XML layer: location feature declarations.
# ---------------------------------------------------------------------------
# android.hardware.location.gps.prebuilt.xml is the feature-permission prebuilt
# that declares PackageManager.FEATURE_LOCATION_GPS to the framework. It is
# delivered as a PRODUCT_PACKAGES module (tokay.mk:224; no PRODUCT_COPY_FILES
# entry exists for it — verified: grep in tokay.mk returns only the
# PRODUCT_PACKAGES line). Dropping it in Layer 1 above causes
# hasSystemFeature(FEATURE_LOCATION_GPS) to return false, which is what
# gracefully hides GPS-specific UI and tells the framework the raw GNSS
# hardware is unavailable.
#
# T-LOC-FULL: FEATURE_LOCATION and FEATURE_LOCATION_NETWORK are now ALSO
# removed. They are declared by the vendored copy
# vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml
# (lines 38-39 in the pre-T-LOC-FULL baseline), NOT by the framework itself.
# Editing that vendored copy (Law 6: upstream untouched) makes
# hasSystemFeature(FEATURE_LOCATION) and FEATURE_LOCATION_NETWORK return false.
# This is what makes GT Info's ValidatorActivity.kt:109-113 pass
# (Kind.FAIL if FEATURE_LOCATION present) and what hides Settings' Location
# screen. The boot-loop risk was assessed as SAFE (see CRITICAL INVARIANT
# above): LocationManagerService starts unconditionally, the FEATURE_LOCATION
# check only gates GNSS init, and the "no fused provider" path logs wtf
# without crashing.

# ---------------------------------------------------------------------------
# Layer 3 — VINTF fragment layer: remove GNSS HAL from vendor manifest.
# ---------------------------------------------------------------------------
# The GNSS HAL is declared to the vendor manifest via TWO adevtool vintf
# fragment modules (NOT inlined in vendor_manifest.xml):
#   - adevtool_vintf_fragment_vendor_pixel-gnss-default.xml
#       (src: vendor/google/gnss/aidl_service/pixel-gnss-default.xml;
#        declares android.hardware.gnss IGnss/vendor)
#   - adevtool_vintf_fragment_vendor_android.hardware.gnss@lassen.xml
#       (src: vendor/samsung_slsi/gps/s5400/android.hardware.gnss@lassen.xml;
#        declares android.hardware.gnss IGnss/default)
# Both are defined as prebuilt_etc modules at
# vendor/google_devices/tokay/vintf/vendor/manifest/Android.bp:32,184 and are
# wired into PRODUCT_PACKAGES at tokay.mk:63,89. Dropping both from
# PRODUCT_PACKAGES (Layer 1 above) removes the HAL declarations so libvintf
# compatibility checks no longer expect a GNSS HAL to be running. No new
# vendor_manifest_no_*.xml variant is required (unlike Bluetooth, whose HAL
# entries were inlined in vendor_manifest_no_radio.xml and needed a
# vendor_manifest_no_bt.xml swap); GNSS comes entirely via these two
# per-HAL fragment modules, so the PRODUCT_PACKAGES drop is sufficient.

# ---------------------------------------------------------------------------
# Layer 4 — init .rc layer: remove GNSS service init lines.
# ---------------------------------------------------------------------------
# The GNSS HAL services are started by two .rc files shipped via
# PRODUCT_COPY_FILES (NOT bundled via Soong init_rc on the service packages):
#   - init.gnss.rc (tokay.mk:1710): defines `service gnssd /vendor/bin/hw/gnssd`
#     and `service slsi_gnss_service /vendor/bin/hw/android.hardware.gnss-service`
#     plus GPS data-dir/permission setup. With this .rc filtered out (Layer 1
#     copy-files filter above), init never loads the gnssd or
#     slsi_gnss_service definitions and the daemons never start.
#   - pixel-gnss-default.rc (tokay.mk:1731): defines
#     `service pixel.gnss-default /vendor/bin/hw/android.hardware.gnss-service.pixel`
#     (started on boot when persist.vendor.gps.hal.service.name=vendor). With
#     this .rc filtered out, init never loads the pixel.gnss-default service
#     definition and the daemon never starts.
# Both .rc files are filtered in Layer 1 above (via the _gt-loc-copy-file-drop
# wildcard), so no separate DEVICE_INIT_RC or Soong-package drop is needed.
#
# NOTE on init.tokay.rc / init.zumapro.board.rc: the task brief expected GNSS
# service init lines in these files. Verified at baseline: neither file
# contains a GNSS HAL service definition (the GNSS services live entirely in
# init.gnss.rc and pixel-gnss-default.rc, handled above). Creating filtered
# copies of these board init files purely to drop non-existent GNSS lines
# would violate Law 6 (Minimal Footprint) with no functional benefit.
# Scope-assumption discrepancy surfaced for Architect (see report).

# ---------------------------------------------------------------------------
# Layer 5 — Framework grace layer: Settings + SystemUI overlays.
# ---------------------------------------------------------------------------
# Wired in guardtalk-feature-excised.mk -> feature-overlays.mk (created in
# T-W2-I2-FP; the Settings + FrameworksBase overlays are already wired via
# radio-excised/telephony-features.mk, and the SystemUI overlay via
# feature-overlays.mk). T-LOC-FULL changed the contract: FEATURE_LOCATION is
# now ABSENT (not just FEATURE_LOCATION_GPS), so:
#   - Settings: the Location screen is now HIDDEN at runtime by Settings'
#     base controller gating the Location screen on FEATURE_LOCATION (which
#     now returns false). No separate Settings overlay entry is required for
#     this; the runtime hasSystemFeature check is authoritative. The overlay
#     documents the contract.
#   - SystemUI: the QS `location` tile is now hidden because SystemUI gates
#     the location tile on FEATURE_LOCATION (now false). No GNSS-specific
#     SystemUI overlay entry is required. BluetoothTile/NfcTile grace entries
#     from I3/I4 are untouched.
