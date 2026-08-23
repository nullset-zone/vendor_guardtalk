# GuardTalkOS mic DSP voice filter (DEC-GT-003) — rango
ifneq ($(GUARDTALK_VOICE_FILTER),)
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/audio
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/apps/GuardTalkVoice

PRODUCT_PACKAGES += \
    libguardtalkvoicesw \
    guardtalk_audio_effects_config.xml \
    GuardTalkVoice \
    privapp_whitelist_com.guardtalk.voice

PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.voice.filter=1 \
    persist.vendor.guardtalk.voice.enabled=1 \
    persist.vendor.guardtalk.voice.preset=0

endif
