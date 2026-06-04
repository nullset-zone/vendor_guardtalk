# Runs from build/make/core/product_config.mk after all product inherits are merged.
# Match tokay product path: GUARDTALK_RADIO_EXCISED may not be visible here yet when
# guardtalk-flags.mk was only inherit-product-linked (deferred until import-nodes).
ifneq ($(filter %/tokay/tokay.mk,$(INTERNAL_PRODUCT)),)
  $(eval PRODUCT_PACKAGES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES))
  $(eval PRODUCT_COPY_FILES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_COPY_FILES))
  $(eval DEVICE_MANIFEST_FILE := $(PRODUCTS.$(INTERNAL_PRODUCT).DEVICE_MANIFEST_FILE))
  include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
  $(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES := $(PRODUCT_PACKAGES))
  $(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_COPY_FILES := $(PRODUCT_COPY_FILES))
  $(eval PRODUCTS.$(INTERNAL_PRODUCT).DEVICE_MANIFEST_FILE := $(DEVICE_MANIFEST_FILE))
endif
