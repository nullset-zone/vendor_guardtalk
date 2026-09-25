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
# Boot-loop risk — CORRECTED TWICE. Read (3) before touching the LMS gate.
#
# (1) T-REMEDIATE-B2-LMS added a SystemServer FEATURE-gate around
#     LocationManagerService.Lifecycle (BT pattern), reasoning that with
#     FEATURE_LOCATION=false LMS should not start. That reasoning was
#     incomplete and has been REVERSED.
#
# (2) FALSIFIED BY MACHINE EVIDENCE (2026-09-20). The original analysis reasoned
#     only about the LMS path and the GNSS path. It missed the
#     CROSS-EXCISION INTERACTION:
#       - SystemServer starts ContextHubSystemService when FEATURE_CONTEXT_HUB
#         is present; komodo declares it, so it starts — INDEPENDENT of
#         FEATURE_LOCATION.
#       - ContextHubService.<init> -> initLocationSettingNotifications() ->
#         sendLocationSettingUpdate() called
#         mContext.getSystemService(LocationManager.class).isLocationEnabledForUser(...).
#         With LMS not started that returned null -> NPE.
#       - The NPE failed onBootPhase(PHASE_SYSTEM_SERVICES_READY=500) and killed
#         system_server in a loop.
#     Observed: komodo stuck on the boot animation, init.svc.bootanim=running,
#     sys.boot_completed unset. Capture:
#     .agent-comm/evidence/B6-CHRE-LOCATION-NPE-MACHINE-EVIDENCE.md
#
# (3) FALSIFIED AGAIN — THE BUG IS THE CONTRACT, NOT ONE CONSUMER (2026-09-21).
#     Null-guarding ContextHubService alone was whack-a-mole. Stamp
#     `komodo-debug-20260920-175743` PROVED the guard executed on device
#     (log: "ContextHubService: LocationManager absent (location feature
#     excised)"), and boot STILL failed — a different consumer threw the same
#     NPE. A full audit
#     (.agent-comm/evidence/B6-LOCATIONMANAGER-CONSUMER-AUDIT.md) established
#     that getSystemService(LocationManager.class) was returning null
#     PROCESS-WIDE, with many consumers: ContextHubService,
#     ServiceConfigAccessorImpl (timezone detector), TwilightService,
#     DevicePolicyManagerService, WifiPermissionsUtil / AfcManager,
#     Connectivity LocationPermissionChecker, telephony LocationAccessPolicy.
#
#     RESOLUTION: LocationManagerService now starts UNCONDITIONALLY — the
#     T-REMEDIATE-B2-LMS gate is REVERSED — so the LocationManager contract
#     holds framework-wide. This is safe because LMS was ALREADY
#     location-feature aware: GNSS init inside it is gated on FEATURE_LOCATION,
#     and its fused-provider branch already had a graceful null path
#     (`else { Log.wtf(TAG, "no fused location provider found"); }`) — the hard
#     `Preconditions.checkState` immediately above that branch was the only
#     blocker, and is now a warning. ServiceConfigAccessorImpl — the single
#     consumer whose capture preceded LMS start (TZD.onStart is SystemServer:2375,
#     LMS :2390) — resolves its LocationManager lazily.
#     FEATURE_LOCATION remains false, so GT Info's ValidatorActivity.kt:109-113
#     and the Settings/SystemUI gating are UNAFFECTED.
#
#   Lesson (Law 14 cascade accountability): excising a FEATURE_* contract must
#   audit every consumer of the SERVICE it also removes. When a removed service
#   has many consumers, RESTORE THE CONTRACT — do not guard each consumer; two
#   consecutive flashes proved that approach misses sites.
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
# are intentionally NOT matched by a bare `location` token (CHRE nanoapp keep).
# FusedLocation is now an exact-name drop (T-REMEDIATE-B2-EXCISE item 8).
#
# Out of scope: Bluetooth, NFC, Fingerprint, Face biometrics, CHRE nanoapps.
# NOTE (2026-09-21): T-REMEDIATE-B2-LMS's SystemServer FEATURE_LOCATION gate
# around LocationManagerService.Lifecycle has been REVERSED — LMS now starts
# unconditionally. This file still makes the GNSS HAL + FusedLocation + init
# .rc absent, and the vendor hook still makes FEATURE_LOCATION false; only the
# *service* lifecycle gate changed. See CRITICAL INVARIANT / item (3) above.

# ---------------------------------------------------------------------------
# Layer 1 — Package layer: GNSS HAL packages, daemons, libs, NetworkLocation,
# FusedLocation, and radio leftover daemons (bipchmgr / wfc-pkt-router).
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
    NetworkLocation \
    FusedLocation \
    bipchmgr \
    wfc-pkt-router

# Defence-in-depth: catch any other GNSS-named packages that a future adevtool
# regen might slide into PRODUCT_PACKAGES. The wildcard match is scoped to
# GNSS-only tokens + exact NetworkLocation / FusedLocation names + radio
# leftover daemons. The bare `location` token is deliberately NOT matched
# (would hit the CHRE nanoapp).
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
  $(findstring NetworkLocation,$(1)), \
  $(findstring FusedLocation,$(1)), \
  $(findstring bipchmgr,$(1)), \
  $(findstring wfc-pkt-router,$(1)))
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
# T-REMEDIATE-B2-EXCISE item 12: also drop radio leftover init that still
# started after RIL excision (service absent, not disabled):
#   - vendor/etc/init/pktrouter.rc  (IMS packet router; vendor.pktrouter=1)
#   - vendor/etc/init/bipchmgr.rc   (BIP channel manager daemon)
# Leaving them would be dead weight and could let a stale config revive HAL
# assumptions after a future regen. The non-GNSS chre/location.napp_header
# (tokay.mk:1611) is intentionally NOT matched (CHRE nanoapp, kept).
define _gt-loc-copy-file-drop
$(or \
  $(findstring /etc/init/init.gnss.rc,$(1)), \
  $(findstring /etc/init/pixel-gnss-default.rc,$(1)), \
  $(findstring /etc/gnss/ca.pem,$(1)), \
  $(findstring /etc/gnss/gps.cfg,$(1)), \
  $(findstring /etc/gnss/hash.bin,$(1)), \
  $(findstring /etc/init/pktrouter.rc,$(1)), \
  $(findstring /etc/init/bipchmgr.rc,$(1)))
endef

_gt_loc_filtered_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt-loc-copy-file-drop,$(cf)),,\
    $(eval _gt_loc_filtered_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_loc_filtered_copy_files))

# T-REMEDIATE-B2-EXCISE item 8: drop FusedLocation from the system_server
# app list as well as PRODUCT_PACKAGES (handheld_system.mk lists both).
# product-config-late.mk only hydrates PRODUCT_PACKAGES / COPY_FILES /
# PACKAGES_DEBUG from the PRODUCTS store — load and write back this list
# here so get_build_var sees the filter (same PRODUCTS. eval as BCP).
$(eval PRODUCT_SYSTEM_SERVER_APPS := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_SERVER_APPS))
PRODUCT_SYSTEM_SERVER_APPS := $(filter-out FusedLocation,$(PRODUCT_SYSTEM_SERVER_APPS))
$(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_SERVER_APPS := $(PRODUCT_SYSTEM_SERVER_APPS))

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
# screen. NOTE (2026-09-21): T-REMEDIATE-B2-LMS's companion change — skipping
# LocationManagerService.Lifecycle when FEATURE_LOCATION is false — has been
# REVERSED. LMS now starts unconditionally so getSystemService(LocationManager)
# is non-null framework-wide; FEATURE_LOCATION still returns false, so this
# layer's contract is unchanged. See CRITICAL INVARIANT above.

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
