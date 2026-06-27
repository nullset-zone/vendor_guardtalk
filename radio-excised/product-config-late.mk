# Runs from build/make/core/product_config.mk after all product inherits are merged.
# Match tokay product path: GUARDTALK_RADIO_EXCISED may not be visible here yet when
# guardtalk-flags.mk was only inherit-product-linked (deferred until import-nodes).
ifneq ($(filter %/tokay/tokay.mk,$(INTERNAL_PRODUCT)),)
  $(eval PRODUCT_PACKAGES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES))
  $(eval PRODUCT_COPY_FILES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_COPY_FILES))
  $(eval DEVICE_MANIFEST_FILE := $(PRODUCTS.$(INTERNAL_PRODUCT).DEVICE_MANIFEST_FILE))
  include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
  # Wave 2 feature excision (apps/nfc/fp/loc + GuardTalk overlays). Runs after
  # radio excision so the late filter-outs see the fully merged PRODUCT_ vars.
  # guardtalk-feature-excised.mk is self-gated on GUARDTALK_FEATURE_EXCISED_WAVE2.
  include vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk

  # =====================================================================
  # Wave 0 blockers (T-HCH-WIRE + T-GTINFO-WIRE)
  # =====================================================================

  # T-HCH-WIRE: replace upstream handheld_core_hardware.prebuilt.xml with the
  # GuardTalk-vendored copy that removes android.hardware.bluetooth +
  # android.hardware.location + android.hardware.location.network so
  # hasSystemFeature(FEATURE_BLUETOOTH) and FEATURE_LOCATION return false,
  # which is the grace layer that auto-hides BT/Location UI in Settings/SystemUI.
  #
  # The upstream module is a prebuilt_etc (frameworks/native/data/etc/Android.bp,
  # src: handheld_core_hardware.xml) shipped to vendor/etc/permissions/ via
  # tokay.mk:348 PRODUCT_PACKAGES entry. We cannot simply PRODUCT_COPY_FILES
  # over it (the prebuilt_etc install would win / conflict), so we filter the
  # upstream module out of PRODUCT_PACKAGES and then PRODUCT_COPY_FILES the
  # GuardTalk XML into the same path. This mirrors the loc-excised.mk Layer-1
  # pattern used for android.hardware.location.gps.prebuilt.xml.
  #
  # The GuardTalk source file lives at
  # vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml and
  # is identical to upstream except the BT + LOCATION feature declarations are
  # removed (verified by diff; comment header documents the rationale).
  PRODUCT_PACKAGES := $(filter-out handheld_core_hardware.prebuilt.xml,$(PRODUCT_PACKAGES))
  PRODUCT_COPY_FILES += \
      vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/handheld_core_hardware.prebuilt.xml

  # T-GTINFO-WIRE: ship GuardTalkValidator (the "GT Info" app) in the image.
  # The app is system_ext_specific (per Android.bp), so it lands in
  # system_ext.img. The privapp_whitelist module is declared as a `required:`
  # dependency in the Android.bp, so adding GuardTalkValidator to
  # PRODUCT_PACKAGES pulls the whitelist in automatically. The
  # PRODUCT_SOONG_NAMESPACES entry is required because vendor/guardtalk/apps/
  # is not a default namespace.
  PRODUCT_PACKAGES += GuardTalkValidator
  PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/apps/GuardTalkValidator

  # =====================================================================

  # T-BRAND-PROPS (Wave 5): rebrand the user-visible device model in Settings →
  # About phone. Settings' MyDeviceInfoScreen.kt:57 reads Build.MODEL (from
  # ro.product.model, derived from PRODUCT_MODEL) for the device-name row when
  # Settings.Global.DEVICE_NAME is unset (first boot). Overriding PRODUCT_MODEL
  # here — after tokay.mk sets it to "Pixel 9" at line 21 — rebrands that row
  # to "GuardTalk Pixel 9" without touching the *_FOR_ATTESTATION variants.
  #
  # WHY ONLY MODEL: the user chose the minimal rebrand (T-BRAND-PROPS option
  # "minimal"). PRODUCT_BRAND and PRODUCT_MANUFACTURER stay "google"/"Google"
  # because (a) the about-page manufacturer row is rarely surfaced on Pixel and
  # (b) keeping the upstream brand/manufacturer maximally preserves any
  # vendor-side check that keys on ro.product.vendor.brand=google. The
  # *_FOR_ATTESTATION vars (PRODUCT_BRAND_FOR_ATTESTATION etc.) are NEVER
  # touched here — they back the hardware-attestation brand claim and must stay
  # "google"/"Google"/"Pixel 9" so Play Integrity / keymint attestation still
  # matches the signed vendor image (Law 4: Security First).
  $(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_MODEL := GuardTalk Pixel 9)

  $(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES := $(PRODUCT_PACKAGES))
  $(eval PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_COPY_FILES := $(PRODUCT_COPY_FILES))
  $(eval PRODUCTS.$(INTERNAL_PRODUCT).DEVICE_MANIFEST_FILE := $(DEVICE_MANIFEST_FILE))
endif
