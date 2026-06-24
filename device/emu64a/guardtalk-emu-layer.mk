# GuardTalkOS userspace on Goldfish ARM64 (emu64a).
# Skips tokay radio excision, Pixel vendor HALs, and vintf stripping — those are
# device-specific and cannot run on the emulator anyway.

GUARDTALK_VOICE_FILTER := true
GUARDTALK_FACE_FILTER := true

# GuardTalk Branding
PRODUCT_COPY_FILES += \
    vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip

# Framework + Settings overlays (telephony flag tweaks; safe on emulator)
PRODUCT_PACKAGES += \
    GuardTalkFrameworksBaseOverlay \
    GuardTalkSettingsOverlay

PRODUCT_SOONG_NAMESPACES += \
    vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay \
    vendor/guardtalk/overlays/GuardTalkSettingsOverlay

DEVICE_PACKAGE_OVERLAYS += \
    vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay \
    vendor/guardtalk/overlays/GuardTalkSettingsOverlay

$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-audio.mk)
$(call inherit-product-if-exists, vendor/guardtalk/device/tokay/guardtalk-camera.mk)

PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.emulator=1 \
    ro.guardtalk.radio.excised=0
