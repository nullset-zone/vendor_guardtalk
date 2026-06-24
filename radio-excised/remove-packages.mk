# Remove cellular/RIL packages (must be included from tokay.mk, not inherit-product).
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
    PixelImsMediaService

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
  $(findstring telephony,$(1)), \
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
