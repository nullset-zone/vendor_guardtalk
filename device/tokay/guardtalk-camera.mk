# GuardTalkOS face persona camera extension (DEC-GT-004)
ifneq ($(GUARDTALK_FACE_FILTER),)

PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/camera
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/camera/extensions
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/apps/GuardTalkFace

PRODUCT_PACKAGES += \
    libguardtalkface_jni \
    androidx.camera.extensions.impl.guardtalk \
    guardtalk_camera_extensions.xml \
    GuardTalkFace \
    privapp_whitelist_com.guardtalk.face

# Prefer GuardTalk OEM extension library over AOSP advanced sample.
PRODUCT_PACKAGES_REMOVE += \
    androidx.camera.extensions.impl.advanced \
    advancedSample_camera_extensions.xml

PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.face.filter=1 \
    persist.vendor.guardtalk.face.enabled=0 \
    persist.vendor.guardtalk.face.persona=0 \
    persist.vendor.guardtalk.face.quality=1

endif
