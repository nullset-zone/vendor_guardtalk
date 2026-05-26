# VINTF: swap full tokay manifest for no-radio manifest (late include + product-config-late).
GUARDTALK_VENDOR_MANIFEST_EXCISED := vendor/guardtalk/vintf/vendor_manifest_no_radio.xml
DEVICE_MANIFEST_FILE := $(filter-out vendor/google_devices/tokay/vintf/vendor/manifest.xml,$(DEVICE_MANIFEST_FILE))
DEVICE_MANIFEST_FILE += $(GUARDTALK_VENDOR_MANIFEST_EXCISED)

PRODUCT_VENDOR_PROPERTIES += \
    ro.boot.radio.disabled=1 \
    ro.radio.noril=1
