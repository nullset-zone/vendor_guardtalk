# GuardTalkOS — tokay product hooks (GUARDTALK_RADIO_EXCISED in guardtalk-flags.mk)
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay
PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.radio.excised=1

$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-audio.mk)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-camera.mk)

# T-BOOTANIM-DEDUPE: bootanimation wiring now lives ONLY in guardtalk-theme.mk
# (single source of truth). The duplicate PRODUCT_COPY_FILES entry for
# GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip was removed to
# prevent double-wiring / build conflicts with guardtalk-theme.mk.

# Early hooks (BoardConfig + base packages)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/BoardConfig-excised.mk)
$(call inherit-product-if-exists, vendor/guardtalk/radio-excised/telephony-features.mk)
