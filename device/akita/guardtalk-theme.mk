# vendor/guardtalk/device/akita/guardtalk-theme.mk
# T-PORT-AKITA-LAYER — brand theme wiring for akita.
# Asset paths are shared under vendor/guardtalk/branding/; self-gated on
# wildcard existence so the build stays green without the brand kit.
# Shared Wave 2 bridge currently includes the tokay theme makefile; this
# file is the per-device mirror for regen documentation and future
# device-parameterized includes.

# --- Boot animation -------------------------------------------------------
guardtalk_bootanim_dir := vendor/guardtalk/branding/bootanimation
guardtalk_bootanim := $(guardtalk_bootanim_dir)/bootanimation.zip
ifneq ($(wildcard $(guardtalk_bootanim)),)
PRODUCT_COPY_FILES += $(guardtalk_bootanim):$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip
endif

# Defensive dark-variant excision (same rationale as tokay T-BOOT-LOGO-FIX2).
_gt_bootanim_dark_drop = $(findstring bootanimation-dark.zip,$(1))
_gt_filtered_bootanim_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt_bootanim_dark_drop,$(cf)),,\
    $(eval _gt_filtered_bootanim_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_filtered_bootanim_copy_files))

# --- Default wallpapers ---------------------------------------------------
guardtalk_wp := vendor/guardtalk/branding/wallpapers
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_default.png),)
PRODUCT_COPY_FILES += \
    $(guardtalk_wp)/wallpaper_guardtalk_default.png:system/etc/wallpaper_guardtalk_default.png
endif
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_dark.png),)
PRODUCT_COPY_FILES += \
    $(guardtalk_wp)/wallpaper_guardtalk_dark.png:system/etc/wallpaper_guardtalk_dark.png
endif
