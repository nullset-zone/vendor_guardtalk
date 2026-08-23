# vendor/guardtalk/branding/guardtalk-theme.mk
# T-BRAND-SWEEP / T-PORT-AKITA-THEME-WIRE — shared GuardTalk theme wiring.
#
# Single source of truth for boot-animation + default-wallpaper PRODUCT_COPY_FILES
# from the vendor/guardtalk layer. Included via:
#   vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-theme.mk
# (thin per-device wrappers) from guardtalk-feature-excised.mk, with a fallback
# include of this file when a per-device wrapper is absent.
#
# All asset wiring is GATED on file existence (ifeq wildcard) so the build
# stays green when the brand kit is incomplete. No upstream-OS-branded asset
# is shipped: factory bootanimation/wallpapers are excluded by
# vendor/adevtool/config/device/common/file-exclusion.yml.

# --- Boot animation -------------------------------------------------------
# GuardTalk bootanimation asset (AOSP format, 1080x2400). Only the light/normal
# bootanimation.zip is wired (T-BOOTANIM-DEDUPE): BootAnimation.cpp falls back
# to bootanimation.zip when bootanimation-dark.zip is absent.
guardtalk_bootanim_dir := vendor/guardtalk/branding/bootanimation
guardtalk_bootanim := $(guardtalk_bootanim_dir)/bootanimation.zip
ifneq ($(wildcard $(guardtalk_bootanim)),)
PRODUCT_COPY_FILES += $(guardtalk_bootanim):$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip
endif

# T-BOOT-LOGO-FIX2 — Defensive dark-variant excision. Strips ANY
# :*/bootanimation-dark.zip copy-file entry so a stale factory dark zip cannot
# re-enter PRODUCT_COPY_FILES after adevtool rehydrate.
_gt_bootanim_dark_drop = $(findstring bootanimation-dark.zip,$(1))
_gt_filtered_bootanim_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt_bootanim_dark_drop,$(cf)),,\
    $(eval _gt_filtered_bootanim_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_filtered_bootanim_copy_files))

# --- Default wallpapers ---------------------------------------------------
# Secondary system-property fallback; primary default wallpaper is the
# GuardTalkFrameworkBrandOverlay drawable override (default_wallpaper.png).
guardtalk_wp := vendor/guardtalk/branding/wallpapers
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_default.png),)
PRODUCT_COPY_FILES += \
    $(guardtalk_wp)/wallpaper_guardtalk_default.png:system/etc/wallpaper_guardtalk_default.png
endif
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_dark.png),)
PRODUCT_COPY_FILES += \
    $(guardtalk_wp)/wallpaper_guardtalk_dark.png:system/etc/wallpaper_guardtalk_dark.png
endif
