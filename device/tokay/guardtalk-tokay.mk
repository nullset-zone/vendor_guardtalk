# GuardTalkOS — tokay product hooks (GUARDTALK_RADIO_EXCISED in guardtalk-flags.mk)
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay
PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.radio.excised=1

$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-audio.mk)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-camera.mk)

# GuardTalk Branding
PRODUCT_COPY_FILES += \
    vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip

# Early hooks (BoardConfig + base packages)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/BoardConfig-excised.mk)
$(call inherit-product-if-exists, vendor/guardtalk/radio-excised/telephony-features.mk)
