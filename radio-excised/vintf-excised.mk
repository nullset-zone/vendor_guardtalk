# VINTF: swap full device vendor manifest for no-radio manifest
# (late include + product-config-late).
#
# T-PORT-AKITA-FLASH: tokay's excised manifest declares IGiaService (Pixel 9),
# which is absent from akita's product FCM and fails check_vintf. Select a
# per-device excised manifest.
#
# T-PORT-RANGO-FLASH: tokay's excised manifest inlines media.c2
# IComponentStore/default, but rango also packages
# adevtool_vintf_fragment_vendor_manifest_media_c2_cnm.xml with the same
# FqInstance → check_vintf conflict. Use a rango-derived excised manifest
# (no media.c2; CNM fragment owns default) and preserve foldable
# touchflow_outer.
#
# IMPORTANT: product-config-late.mk re-includes this file after restoring
# DEVICE_MANIFEST_FILE from PRODUCTS.*, but PRODUCT_DEVICE is often unset in
# that context. Fall back to TARGET_DEVICE / TARGET_PRODUCT / INTERNAL_PRODUCT
# so the late pass cannot silently re-apply the tokay excised manifest.
_gt_vintf_device := $(PRODUCT_DEVICE)
ifeq ($(_gt_vintf_device),)
  _gt_vintf_device := $(TARGET_DEVICE)
endif
ifeq ($(_gt_vintf_device),)
  _gt_vintf_device := $(TARGET_PRODUCT)
endif
ifeq ($(_gt_vintf_device),)
  _gt_vintf_device := $(INTERNAL_PRODUCT)
endif

ifneq ($(filter akita,$(_gt_vintf_device)),)
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_akita.xml
else ifneq ($(filter rango,$(_gt_vintf_device)),)
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_rango.xml
else ifneq ($(filter frankel blazer mustang,$(_gt_vintf_device)),)
  # T-PORT-BATCH-B: frankel/blazer/mustang are laguna muzel (non-foldable). The
  # shared tokay-derived excised manifest inlines media.c2 IComponentStore/default,
  # which collides with adevtool_vintf_fragment_vendor_manifest_media_c2_cnm.xml
  # (packaged by these devices) -> check_vintf Conflicting FqInstance. Use a
  # device-derived manifest (same fix as rango, T-PORT-RANGO-FLASH).
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_laguna_muzel.xml
else ifneq ($(filter stallion,$(_gt_vintf_device)),)
  # T-PORT-FINISH-WAVE: stallion is Pixel 10a / zumapro. The tokay-derived
  # excised manifest declares vendor.google.bluetooth_ext @4, which stallion's
  # target-level 202404 FCM does not cover -> check_vintf incompatibility.
  # Use a stallion-derived manifest (same class as T-PORT-AKITA-FLASH).
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_stallion.xml
else ifneq ($(filter shiba,$(_gt_vintf_device)),)
  # T-PORT-FINISH-WAVE: shiba is Pixel 8 / zuma. The tokay-derived excised
  # manifest declares com.google.input.gia.core/IGiaService (@2), absent from
  # shiba's FCM -> check_vintf incompatibility. Use a shiba-derived manifest.
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_shiba.xml
else ifneq ($(filter husky,$(_gt_vintf_device)),)
  # T-PORT-FINISH-WAVE: husky is Pixel 8 Pro / zuma. Same gia.core (@2)
  # incompatibility as shiba -> use a husky-derived manifest.
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio_husky.xml
else
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio.xml
endif

DEVICE_MANIFEST_FILE := $(filter-out \
    vendor/google_devices/tokay/vintf/vendor/manifest.xml \
    vendor/google_devices/akita/vintf/vendor/manifest.xml \
    vendor/google_devices/rango/vintf/vendor/manifest.xml \
    vendor/google_devices/frankel/vintf/vendor/manifest.xml \
    vendor/google_devices/blazer/vintf/vendor/manifest.xml \
    vendor/google_devices/mustang/vintf/vendor/manifest.xml \
    vendor/google_devices/stallion/vintf/vendor/manifest.xml \
    vendor/google_devices/shiba/vintf/vendor/manifest.xml \
    vendor/google_devices/husky/vintf/vendor/manifest.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_akita.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_rango.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_laguna_muzel.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_stallion.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_shiba.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_husky.xml \
    ,$(DEVICE_MANIFEST_FILE))
DEVICE_MANIFEST_FILE += $(GUARDTALK_VENDOR_MANIFEST_EXCISED)

PRODUCT_VENDOR_PROPERTIES += \
    ro.boot.radio.disabled=1 \
    ro.radio.noril=1
