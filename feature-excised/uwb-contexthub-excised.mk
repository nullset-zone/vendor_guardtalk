# GuardTalkOS UWB, Wi-Fi Aware/RTT, ContextHub, and CHRE nearby excision
# (F-004, F-005, F-007).
#
# Included from vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk
# after all inherit-product merges so PRODUCT_PACKAGES and PRODUCT_COPY_FILES
# are fully populated. Reversible (filter-out only; Law 11).

GUARDTALK_UWB_CHRE_PACKAGES := \
    android.hardware.qorvo.uwb-service \
    android.hardware.qorvo.uwb.service \
    android.hardware.samsung.uwb-service \
    dump_uwb \
    init_uwb_calib \
    adevtool_vintf_fragment_vendor_android.hardware.samsung.uwb-service.xml \
    adevtool_vintf_fragment_vendor_android.hardware.qorvo.uwb-service.xml \
    adevtool_vintf_fragment_vendor_qorvo.uwb-service.xml \
    android.hardware.uwb.prebuilt.xml \
    android.hardware.uwb.xml \
    android.hardware.wifi.aware.prebuilt.xml \
    android.hardware.wifi.rtt.prebuilt.xml \
    android.hardware.contexthub-service.generic \
    android.hardware.contexthub-V4-ndk.vendor \
    android.hardware.context_hub.prebuilt.xml \
    adevtool_vintf_fragment_vendor_android.hardware.contexthub-service.generic.xml \
    nearby

define _gt-uwb-chre-package-drop
$(or \
  $(findstring .uwb-service,$(1)), \
  $(findstring .uwb.service,$(1)), \
  $(findstring android.hardware.uwb,$(1)), \
  $(findstring android.hardware.contexthub,$(1)), \
  $(findstring android.hardware.context_hub,$(1)))
endef

_gt_uwb_chre_filtered_packages :=
$(foreach p,$(filter-out $(GUARDTALK_UWB_CHRE_PACKAGES),$(PRODUCT_PACKAGES)),\
  $(if $(call _gt-uwb-chre-package-drop,$(p)),,\
    $(eval _gt_uwb_chre_filtered_packages += $(p))))
PRODUCT_PACKAGES := $(strip $(_gt_uwb_chre_filtered_packages))

define _gt-uwb-chre-copy-file-drop
$(or \
  $(findstring uwb-service.rc,$(1)), \
  $(findstring uwb-calib.rc,$(1)), \
  $(findstring /etc/uwb/,$(1)), \
  $(findstring android.hardware.uwb.xml,$(1)), \
  $(findstring android.hardware.contexthub-service.generic.rc,$(1)), \
  $(findstring chre/nearby.napp_header,$(1)))
endef

_gt_uwb_chre_filtered_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt-uwb-chre-copy-file-drop,$(cf)),,\
    $(eval _gt_uwb_chre_filtered_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_uwb_chre_filtered_copy_files))

# Install SystemConfig <unavailable-feature> overrides for features declared in
# adevtool_sysconfig_* globs (including tangorpro tablet_core_hardware.xml,
# android.hardware.uwb.xml, and android.hardware.telephony.euicc*.xml).
PRODUCT_COPY_FILES += \
    vendor/guardtalk/feature-excised/guardtalk-excluded-features.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/guardtalk-excluded-features.xml
