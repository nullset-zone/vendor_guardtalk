# VINTF: swap full device vendor manifest for no-radio manifest
# (late include + product-config-late).
#
# T-PORT-AKITA-FLASH: tokay's excised manifest declares IGiaService (Pixel 9),
# which is absent from akita's product FCM and fails check_vintf. Select a
# per-device excised manifest.
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
else
  GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio.xml
endif

DEVICE_MANIFEST_FILE := $(filter-out \
    vendor/google_devices/tokay/vintf/vendor/manifest.xml \
    vendor/google_devices/akita/vintf/vendor/manifest.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio.xml \
    vendor/guardtalk/vintf/vendor_manifest_no_radio_akita.xml \
    ,$(DEVICE_MANIFEST_FILE))
DEVICE_MANIFEST_FILE += $(GUARDTALK_VENDOR_MANIFEST_EXCISED)

PRODUCT_VENDOR_PROPERTIES += \
    ro.boot.radio.disabled=1 \
    ro.radio.noril=1
