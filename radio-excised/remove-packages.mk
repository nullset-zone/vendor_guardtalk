# Remove cellular/RIL packages (must be included from tokay.mk, not inherit-product).
#
# T-PKG-EXCISE-WAVES P1 — IMS/IWLAN/CarrierConfig triad. With the radio/RIL
# stack excised above, IMS, IWLAN, and CarrierConfig2 have no transport and
# would only emit binders to a missing radio HAL. All three are removed
# together (atomic dependency group). Names verified as Soong modules in
# out/soong/late-tokay.mk and as PRODUCT_PACKAGES entries:
#   Iwlan                -> vendor/google_devices/tokay/tokay.mk:117
#   ImsServiceEntitlement -> build/make/target/product/telephony_product.mk:23
#   CarrierConfig2       -> vendor/adevtool/config/mk/google_devices/common/
#                           device-common.mk:63 (gated by BOARD_WITHOUT_RADIO;
#                           tokay does not set that flag, so CarrierConfig2 is
#                           pulled in). Note: CarrierConfig2 also pulls the
#                           GosTelephonyProviderOverlay + GosTelephonyOverlay
#                           RROs in the same PRODUCT_PACKAGES line — those RROs
#                           are GuardTalk keep-set-adjacent (GrapheneOS-sourced
#                           telephony overlays) and are NOT removed here. They
#                           are harmless with the radio gone (overlay targets
#                           a telephony framework that no-ops without a HAL).
# Reversible (filter-out only; Law 11).
#
# T-PKG-EXCISE-WAVE-A — Telecom call-routing framework. With radio/RIL
# fully excised above, there is no cellular transport, so Telecom has no
# calls to route. The operator has decided to REMOVE it. Verified Soong
# module: packages/services/Telecomm/Telecom ->
#   out/soong/late-tokay.mk:262156 (Telecom-android_common-*; installs
#   to system/priv-app/Telecom/Telecom.apk). PRODUCT_PACKAGES source:
#   build/make/target/product/handheld_system.mk:110,113. Dependency
# audit: SystemUI and Settings reference only the
# android.telecom.TelecomManager framework class (in frameworks/base/
# telecomm), NOT the Telecom.apk module (com.android.server.telecom).
# Removing the APK removes the call-routing service impl; the framework
# API class remains and degrades gracefully (returns null/defaults when
# no backing service). tokay.mk has no Telecom PRODUCT_PACKAGES entry.
# RRO overlay Telecom__tokay__auto_generated_rro_product also removed
# (verified at out/soong/late-tokay.mk:262414). Reversible (filter-out
# only; Law 11).
GUARDTALK_RADIO_PACKAGES := \
    android.hardware.radio-V2-ndk.vendor \
    android.hardware.radio.config-V2-ndk.vendor \
    android.hardware.radio.config@1.0.vendor \
    android.hardware.radio.config@1.1.vendor \
    android.hardware.radio.config@1.2.vendor \
    android.hardware.radio.data-V2-ndk.vendor \
    android.hardware.radio.deprecated@1.0.vendor \
    android.hardware.radio.ims-V1-ndk.vendor \
    android.hardware.radio.messaging-V2-ndk.vendor \
    android.hardware.radio.modem-V2-ndk.vendor \
    android.hardware.radio.network-V2-ndk.vendor \
    android.hardware.radio.sap-V1-ndk.vendor \
    android.hardware.radio.sim-V2-ndk.vendor \
    android.hardware.radio.voice-V2-ndk.vendor \
    android.hardware.radio@1.0.vendor \
    android.hardware.radio@1.1.vendor \
    android.hardware.radio@1.2.vendor \
    android.hardware.radio@1.3.vendor \
    android.hardware.radio@1.4.vendor \
    android.hardware.radio@1.5.vendor \
    android.hardware.radio@1.6.vendor \
    android.hardware.telephony.carrierlock.prebuilt.xml \
    android.hardware.telephony.gsm.prebuilt.xml \
    android.hardware.telephony.ims.prebuilt.xml \
    android.hardware.telephony.ims.singlereg.prebuilt.xml \
    dump_modem \
    dump_modemlog \
    google-ril \
    hardware.google.ril_ext-V1-ndk \
    libril-aidl \
    libril_gfeature \
    libril_sitril \
    libsitril \
    libsitril-audio \
    libsitril-client \
    libsitril-gps \
    libsitril-ims \
    modem_android_property_manager \
    modem_android_property_manager_impl \
    modem_clock_manager \
    modem_clock_manager_impl \
    modem_log_constants \
    modem_log_dumper \
    modem_logging_control \
    modem_ml_pw_rpc_gen \
    modem_ml_svc_sit \
    modemml-tflite-service-aidl-V1-ndk \
    com.google.pixel.modem.logmasklibrary-V1-ndk \
    libmodem_ml_svc_proto \
    libmodem_svc_proto_legacy_soong \
    adevtool_vintf_fragment_vendor_shared_modem_platform.xml \
    oemrilhook \
    ril-extension \
    rild_exynos \
    shared_modem_platform \
    OemRilService \
    OemRilHookService \
    ShannonIms \
    ShannonRcs \
    ShannonIms__tokay__auto_generated_rro_product \
    liboemservice \
    liboemservice_proxy_default \
    lassen_dmd_constants \
    adevtool_vintf_fragment_vendor_liboemservice_proxy.xml \
    vendor.samsung_slsi.telephony.hardware.oemservice@1.0 \
    vendor.samsung_slsi.telephony.hardware.oemservice@1.0.system_ext \
    vendor.samsung_slsi.telephony.hardware.radioExternal@1.0 \
    vendor.samsung_slsi.telephony.hardware.radioExternal@1.0.system_ext \
    vendor.samsung_slsi.telephony.hardware.radioExternal@1.1 \
    init.radio.sh \
    vendor.google.radio_ext-V1-ndk \
    vendor.google.radio_ext-service \
    vendor.google.radioext@1.0-service \
    vendor.radio.base \
    vendor.radio.protocol.sit.base \
    vendor.radio.protocol.sit.json \
    vendor.radio.protocol.sit.stream \
    adevtool_vintf_fragment_vendor_manifest_radioext.xml \
    adevtool_vintf_fragment_vendor_vendor.google.radio_ext-default.xml \
    com.android.phone \
    com.android.telephony.imsmedia \
    telephony-ext \
    Dialer \
    Messaging \
    cbd \
    rfsd \
    MmsService \
    PixelImsMediaService \
    EuiccGoogle \
    EuiccSupportPixel-P23 \
    EuiccGoogleOverlay \
    EuiccSupportPixelPermissions \
    EuiccSupportPixelOverlay \
    com.google.pixel.euicc.update \
    Iwlan \
    ImsServiceEntitlement \
    CarrierConfig2 \
    CarrierConfig \
    CellBroadcastReceiverOverlay \
    com.android.cellbroadcast \
    \
    Telecom \
    Telecom__tokay__auto_generated_rro_product \
    \
    PixelQualifiedNetworksService

# T-PKG-EXCISE-WAVE-CAT5 — A-REPORT-INVESTIGATE item 17b. With the radio/RIL
# stack fully excised above, PixelQualifiedNetworksService is dead weight:
# frameworks/base/core/api/system-current.txt:17457-17467 declares the abstract
# QualifiedNetworksService class, and
# frameworks/base/telephony/java/android/telephony/data/IQualifiedNetworksService.aidl:25
# is the AIDL for telephony IMS/data network selection. With no modem/SIM/IMS
# substrate (radio-excised/remove-packages.mk above),
# onCreateNetworkAvailabilityProvider(int slotIndex) has nothing to provide.
# Sibling telephony services (PixelImsMediaService above, ShannonIms, ShannonRcs)
# were excised on the same rationale. Operator decision (dispatched 2026-07-02):
# APPROVED for removal (LOW risk). Soong module:
# vendor/google_devices/tokay/proprietary/Android.bp:437 (android_app_import,
# system_ext/priv-app). PRODUCT_PACKAGES source:
# vendor/google_devices/tokay/tokay.mk:561. RRO audit: no
# PixelQualifiedNetworksService__tokay__auto_generated_rro_product sibling
# exists (grep vendor/google_devices/tokay/ + device/google/ returned only the
# app and its .apk; the ShannonQualifiedNetworksService variant on
# oriole/raven/bluejay is a different SoC family and not built for tokay).
# Reversible (filter-out only; Law 11).

# T-PKG-ARCHITECT-FIX: EuiccSupportPixel-P23 data files are delivered via
# PRODUCT_COPY_FILES (tokay.mk:1548-1550), NOT via PRODUCT_PACKAGES, so the
# filter-out above does NOT catch them. The APK itself (EuiccSupportPixel-P23)
# IS in PRODUCT_PACKAGES and IS filtered above, but the three data files
# (DKA_0302_24.up, esim-full-v1.img, Felica_Tag_66_Changer.apdu) leak through.
# Strip them from PRODUCT_COPY_FILES here (same reversibility — filter-out only).
# A-PKG-FINAL audit catch (INV-5): com.google.pixel.euicc.update APEX copy
# (tokay.mk:648) is in PRODUCT_PACKAGES, so it is now filtered above alongside
# the other Euicc* entries. Earlier this comment claimed the strip was done
# but the filter entry was missing — auditor flagged the residual APEX
# /vendor/apex/com.google.pixel.euicc.update.apex. Fixed by adding
# com.google.pixel.euicc.update to GUARDTALK_RADIO_PACKAGES.
PRODUCT_COPY_FILES := $(filter-out $(TARGET_COPY_OUT_SYSTEM_EXT)/priv-app/EuiccSupportPixel-P23/%,$(PRODUCT_COPY_FILES))
PRODUCT_COPY_FILES := $(filter-out %/EuiccSupportPixel-P23/DKA_0302_24.up,$(PRODUCT_COPY_FILES))
PRODUCT_COPY_FILES := $(filter-out %/EuiccSupportPixel-P23/esim-full-v1.img,$(PRODUCT_COPY_FILES))
PRODUCT_COPY_FILES := $(filter-out %/EuiccSupportPixel-P23/Felica_Tag_66_Changer.apdu,$(PRODUCT_COPY_FILES))

# Orphans still pulled via base_vendor.mk (libreference-ril) if late filter did not run.
GT_RADIO_ORPHAN_PACKAGES := \
    libreference-ril \
    libgooglerilaudio \
    libgooglerilmemmonitor \
    libgril_oem-google \
    libril \
    librilutils \
    android.hardware.radio@1.0 \
    android.hardware.radio@1.1 \

define _gt-package-drop
$(or \
  $(findstring android.hardware.radio,$(1)), \
  $(findstring googleril,$(1)), \
  $(findstring libgril,$(1)), \
  $(findstring libsitril,$(1)), \
  $(findstring libril,$(1)), \
  $(findstring modem_ml,$(1)), \
  $(findstring modem_%,$(1)), \
  $(findstring vendor.google.radio,$(1)), \
  $(findstring vendor.radio.,$(1)), \
  $(findstring dump_modem,$(1)), \
  $(findstring shared_modem,$(1)), \
  $(findstring rild_,$(1)), \
  $(findstring google-ril,$(1)), \
  $(findstring libreference-ril,$(1)), \
  $(findstring radio-service,$(1)), \
  $(findstring radio.config@,$(1)), \
  $(findstring Shannon,$(1)), \
  $(findstring OemRil,$(1)), \
  $(findstring liboemservice,$(1)), \
  $(findstring lassen_dmd,$(1)), \
  $(findstring radio-library,$(1)), \
  $(findstring telephony-ext,$(1)), \
  $(findstring com.android.telephony.imsmedia,$(1)), \
  $(findstring imsmedia,$(1)), \
  $(findstring ImsMedia,$(1)), \
  $(findstring Mms,$(1)), \
  $(findstring Telephony,$(1)), \
  $(findstring TeleService,$(1)))
endef

_gt_filtered_product_packages :=
$(foreach p,$(filter-out $(GUARDTALK_RADIO_PACKAGES),$(PRODUCT_PACKAGES)),\
  $(if $(call _gt-package-drop,$(p)),,\
    $(eval _gt_filtered_product_packages += $(p))))
PRODUCT_PACKAGES := $(strip $(_gt_filtered_product_packages))
PRODUCT_PACKAGES := $(filter-out $(GT_RADIO_ORPHAN_PACKAGES),$(PRODUCT_PACKAGES))
