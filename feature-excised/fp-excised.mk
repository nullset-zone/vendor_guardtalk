# T-PORT-SHARED-CORE-FIX — 5-layer graceful excision of the fingerprint HAL.
#
# Scope: BOTH the Qualcomm QFP fingerprint HAL AND the Goodix fingerprint HAL,
# covering every fingerprint HAL family present in the supported Pixel line-up.
#   - QFP family (tokay, caiman): android.hardware.biometrics.fingerprint-V3-ndk.
#            vendor, the qfp-daemon vendor service, its VINTF fragment, the
#            feature-permission XML, the dump tooling, and the qfp-daemon /
#            init.fingerprint.dump init .rc files.
#   - Goodix family (akita, rango,    android.hardware.biometrics.fingerprint-
#     tegu):                                service.goodix AIDL service,
#                                            libvendor.goodix.hardware.
#                                            biometrics.fingerprint@2.1, the
#                                            rango-specific goodixfingerprint /
#                                            goodix_sfps_suez / goodixbinderservice-
#                                            aidl-V1-ndk blobs, the Goodix VINTF
#                                            fragment, and the fingerprint-goodix.rc
#                                            init file.
# SetupWizard2 fingerprint enrollment step is handled in packages/apps/SetupWizard2
# (source edit).
#
# Rationale: the original filter was QFP-only. akita (zuma), rango (laguna), and
# tegu (zuma) all use the Goodix fingerprint HAL, NOT QFP (verified in
# vendor/adevtool/vendor-skels/google_devices/{akita,rango,tegu}/). On those
# devices the QFP-only filter was a silent no-op → fingerprint feature was not
# actually removed → feature parity with tokay was broken. This fix extends
# every layer to catch both HAL families. (Note: caiman is QFP, not Goodix as
# the dispatch brief claimed — verified caiman.mk has qfp-daemon, libqfp-service,
# qfp-daemon.rc and NO goodix tokens; surface for Architect.) filter-out is
# idempotent and device-agnostic: a package that is not present on the building
# device is simply not matched, so filtering both QFP and Goodix unconditionally
# is safe on every device.
#
# Pattern: same late product-config filter-out as apps-excised.mk and
# radio-excised/remove-packages.mk. Idempotent and order-independent.
#
# CRITICAL INVARIANT: android.hardware.biometrics.common-V3-ndk.vendor is KEPT.
# It is the shared biometrics common library also consumed by the virtual face
# HAL package (com.android.hardware.biometrics.face.virtual). Dropping it would
# break the face subsystem, which is OUT OF SCOPE for this increment
# (task: "Do NOT touch Bluetooth/NFC/Location" — face is similarly reserved).
# Only fingerprint-named packages are removed. The Goodix findstrings below are
# scoped to fingerprint-only tokens (vendor.goodix.hardware.biometrics.fingerprint,
# fingerprint-service.goodix, goodixfingerprint, goodix_sfps, goodixbinderservice)
# so they cannot accidentally hit a hypothetical non-fingerprint Goodix package.
#
# CRITICAL INVARIANT: ro.build.fingerprint (a build property referenced by
# init.zumapro.board.rc:523-524) is UNRELATED to the fingerprint HAL and MUST
# remain. The original init.zumapro.board.rc contains no fingerprint HAL service
# lines, so no filtered copy is required (see "init .rc layer" below).

# ---------------------------------------------------------------------------
# Layer 1 — Package layer: fingerprint HAL packages, daemons, and tools.
# ---------------------------------------------------------------------------
GUARDTALK_FP_PACKAGES := \
    android.hardware.biometrics.fingerprint-V3-ndk.vendor \
    android.hardware.fingerprint.prebuilt.xml \
    com.android.hardware.biometrics.fingerprint.virtual \
    com.google.hardware.biometrics.fingerprint.fingerprint-ext-V2-ndk \
    vendor.qti.hardware.fingerprint.aidl-V1-ndk \
    dump_fingerprint \
    qfp-daemon \
    android.hardware.biometrics.fingerprint-service.goodix \
    libvendor.goodix.hardware.biometrics.fingerprint@2.1 \
    goodixfingerprint \
    goodix_sfps_suez \
    goodixbinderservice-aidl-V1-ndk

# Defence-in-depth: catch any other fingerprint-named packages that a future
# adevtool regen might slide into PRODUCT_PACKAGES. The wildcard match is
# scoped to fingerprint-only tokens so it cannot accidentally hit face/biometrics
# common. Virtual face (com.android.hardware.biometrics.face.virtual) and
# biometrics.common are explicitly preserved by the keep list below.
define _gt-fp-package-drop
$(or \
  $(findstring android.hardware.biometrics.fingerprint,$(1)), \
  $(findstring com.google.hardware.biometrics.fingerprint,$(1)), \
  $(findstring com.android.hardware.biometrics.fingerprint,$(1)), \
  $(findstring vendor.qti.hardware.fingerprint,$(1)), \
  $(findstring dump_fingerprint,$(1)), \
  $(findstring qfp-daemon,$(1)), \
  $(findstring android.hardware.fingerprint.prebuilt,$(1)), \
  $(findstring vendor.goodix.hardware.biometrics.fingerprint,$(1)), \
  $(findstring fingerprint-service.goodix,$(1)), \
  $(findstring libvendor.goodix.hardware.biometrics.fingerprint,$(1)), \
  $(findstring goodixfingerprint,$(1)), \
  $(findstring goodix_sfps,$(1)), \
  $(findstring goodixbinderservice,$(1)))
endef

# Packages that must NEVER be dropped by this filter. Listed explicitly so the
# wildcard defence-in-depth above cannot accidentally remove the shared
# biometrics common lib or the virtual face HAL.
GUARDTALK_FP_KEEP := \
    android.hardware.biometrics.common-V3-ndk.vendor \
    com.android.hardware.biometrics.face.virtual

_gt_filtered_product_packages :=
$(foreach p,$(filter-out $(GUARDTALK_FP_PACKAGES),$(PRODUCT_PACKAGES)),\
  $(if $(call _gt-fp-package-drop,$(p)),,\
    $(eval _gt_filtered_product_packages += $(p))))
PRODUCT_PACKAGES := $(strip $(_gt_filtered_product_packages))

# Defence-in-depth: restore any keep-list package that somehow landed in the
# drop list. (No-op in normal operation.)
PRODUCT_PACKAGES += $(filter $(GUARDTALK_FP_KEEP),$(GUARDTALK_FP_PACKAGES))

# ---------------------------------------------------------------------------
# Layer 2 — Feature XML layer: fingerprint feature declarations.
# ---------------------------------------------------------------------------
# android.hardware.fingerprint.prebuilt.xml is the feature-permission prebuilt
# that declares PackageManager.FEATURE_FINGERPRINT to the framework. Removing
# it from PRODUCT_PACKAGES (Layer 1 above) causes hasSystemFeature(FEATURE_FINGERPRINT)
# to return false, which is what gracefully hides fingerprint UI in Settings,
# SystemUI, and SetupWizard2. No separate copy-files filter is needed because
# the prebuilt is delivered as a PRODUCT_PACKAGES module, not a PRODUCT_COPY_FILES
# entry. (Verified: grep "fingerprint.prebuilt.xml:" in tokay.mk returns nothing;
# the name appears only in the PRODUCT_PACKAGES block at tokay.mk:187.)

# ---------------------------------------------------------------------------
# Layer 3 — VINTF fragment layer: remove fingerprint HAL from vendor manifest.
# ---------------------------------------------------------------------------
# Two fingerprint VINTF fragments exist across the supported Pixel family:
#   - QFP (tokay):     adevtool_vintf_fragment_vendor_qfp-daemon.xml
#                      declares android.hardware.biometrics.fingerprint
#                      IFingerprint/default AND vendor.qti.hardware.fingerprint
#                      IQfpExtendedFingerprint/default.
#   - Goodix (akita,  adevtool_vintf_fragment_vendor_fingerprint-goodix.xml
#     rango, tegu):   declares android.hardware.biometrics.fingerprint
#                     IFingerprint/default AND vendor.goodix.hardware.
#                     biometrics.fingerprint IGoodixFingerprintDaemon/default.
# Dropping both fragment modules from PRODUCT_PACKAGES (Layer 1 above via the
# wildcard, plus the explicit filter-out here) removes the HAL declaration so
# libvintf compatibility checks no longer expect a fingerprint HAL to be running
# on either QFP or Goodix devices. filter-out is idempotent: a fragment not
# present on the building device is simply not matched.
PRODUCT_PACKAGES := $(filter-out \
    adevtool_vintf_fragment_vendor_qfp-daemon.xml \
    adevtool_vintf_fragment_vendor_fingerprint-goodix.xml,$(PRODUCT_PACKAGES))

# ---------------------------------------------------------------------------
# Layer 4 — init .rc layer: remove fingerprint service init lines.
# ---------------------------------------------------------------------------
# Two fingerprint init .rc families exist across the supported Pixel family:
#   - QFP (tokay):   qfp-daemon.rc (service qfp-daemon /vendor/bin/hw/qfp-daemon,
#                    interface aidl android.hardware.biometrics.fingerprint) and
#                    init.fingerprint.dump.rc (creates /data/vendor/tombstones/
#                    fingerprint). Both copied into vendor/etc/init via
#                    PRODUCT_COPY_FILES in tokay.mk (lines 1708 and 1737).
#   - Goodix         fingerprint-goodix.rc (service for the
#     (akita/rango/   android.hardware.biometrics.fingerprint-service.goodix
#     tegu):          AIDL HAL). Copied into vendor/etc/init via
#                    PRODUCT_COPY_FILES in akita.mk:1640 / tegu.mk:1671 /
#                    rango.mk:1730 (verified exact name — do NOT guess
#                    init.goodix.fp.rc / init.fingerprint.goodix.rc; the actual
#                    file is fingerprint-goodix.rc).
# Filter them out of PRODUCT_COPY_FILES so init never loads any fingerprint
# service definitions on either QFP or Goodix devices. filter-out is idempotent
# (an .rc not present on the building device is simply not matched).
define _gt-fp-copy-file-drop
$(or \
  $(findstring init.fingerprint.dump.rc,$(1)), \
  $(findstring qfp-daemon.rc,$(1)), \
  $(findstring fingerprint-goodix.rc,$(1)))
endef

_gt_fp_filtered_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt-fp-copy-file-drop,$(cf)),,\
    $(eval _gt_fp_filtered_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_fp_filtered_copy_files))

# NOTE on init.zumapro.board.rc: the task brief expected fingerprint service
# init lines in init.zumapro.board.rc and asked for a filtered copy at
# feature-excised/init/init.zumapro.board.rc. Verified at baseline c2e79a1:
# init.zumapro.board.rc contains NO fingerprint HAL service lines — its only
# "fingerprint" reference is `ro.build.fingerprint` (a build property, lines
# 523-524), which is UNRELATED to the fingerprint HAL and MUST remain. The
# actual fingerprint service init lives in qfp-daemon.rc (filtered above).
# No filtered copy of init.zumapro.board.rc is therefore required; creating a
# byte-identical copy would violate Law 6 (Minimal Footprint) and add needless
# maintenance burden. Scope-assumption discrepancy surfaced for Architect
# (see report).

# ---------------------------------------------------------------------------
# Layer 5 — Framework grace layer: Settings + SystemUI overlays.
# ---------------------------------------------------------------------------
# Wired in guardtalk-feature-excised.mk -> feature-overlays.mk (created in
# this increment). The overlays set config_biometric_sensors to empty and
# config_fingerprintMaxTemplatesPerUser to 0 so that even if a stale feature
# flag lingers, the framework treats fingerprint as unsupported. See
# overlays/GuardTalkFrameworksBaseOverlay and overlays/GuardTalkSystemUIOverlay.
