# GuardTalkOS — tokay product hooks (GUARDTALK_RADIO_EXCISED in guardtalk-flags.mk)
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay
PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.radio.excised=1

# Early hooks (BoardConfig + base packages)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/BoardConfig-excised.mk)
$(call inherit-product-if-exists, vendor/guardtalk/radio-excised/telephony-features.mk)
