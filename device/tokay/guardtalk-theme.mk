# vendor/guardtalk/device/tokay/guardtalk-theme.mk
# T-W2-I6-THEME — GuardTalk theme wiring for the tokay product.
#
# This is the ONLY place boot-animation + default-wallpaper assets are wired
# into the tokay image from the vendor/guardtalk layer. Per dispatch
# constraints we do NOT touch vendor/google_devices/tokay/tokay.mk or
# BoardConfig.mk, so all GuardTalk theme wiring flows through this hook,
# which is included from guardtalk-tokay.mk.
#
# All asset wiring is GATED on the file's existence (ifeq wildcard) so the
# build stays green when the operator has not yet delivered the brand kit.
# When the asset lands in vendor/guardtalk/branding/, the build picks it up
# automatically with no further source change. No GrapheneOS-branded asset
# is ever shipped: the GrapheneOS bootanimation/wallpapers (if any) live only
# in the stashed change set and are NOT restored.
#
# See vendor/guardtalk/branding/README.md for the gap register + operator
# deliverable list.

# --- Boot animation -------------------------------------------------------
# GuardTalk bootanimation assets (AOSP format, stored, 1080x2400, <=30fps,
# <=8s). Two variants are wired to match AOSP's BootAnimation.cpp lookup:
#   * bootanimation.zip        -> /system/media/bootanimation.zip  (light/normal)
#   * bootanimation-dark.zip   -> /product/media/bootanimation-dark.zip (dark,
#     played when ro.boot.theme=1; see frameworks/base/cmds/bootanimation/
#   BootAnimation.cpp lines 75-77 + 719-722).
# Until delivered, the AOSP default bootanimation
# (frameworks/base/cmds/bootanimation) is used and no GrapheneOS bootanimation
# is shipped. The GrapheneOS bootanimation zips that adevtool unpacks from the
# factory image at vendor/adevtool/dl/unpacked/tokay-*/product/media/ are
# EXCLUDED from the build by vendor/adevtool/config/device/common/
# file-exclusion.yml (lines 70-71), so they never reach /product/media/.
guardtalk_bootanim_dir := vendor/guardtalk/branding/bootanimation
guardtalk_bootanim := $(guardtalk_bootanim_dir)/bootanimation.zip
guardtalk_bootanim_dark := $(guardtalk_bootanim_dir)/bootanimation-dark.zip
ifneq ($(wildcard $(guardtalk_bootanim)),)
PRODUCT_COPY_FILES += $(guardtalk_bootanim):$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip
endif
ifneq ($(wildcard $(guardtalk_bootanim_dark)),)
PRODUCT_COPY_FILES += $(guardtalk_bootanim_dark):$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation-dark.zip
endif

# --- Default wallpapers ---------------------------------------------------
# GuardTalk default wallpapers. The PRIMARY default-wallpaper wiring for
# T-WALLPAPER (FR-2) is the `default_wallpaper` drawable override in
# GuardTalkFrameworkBrandOverlay (see
# GuardTalkFrameworkBrandOverlay/res/drawable-*/default_wallpaper.png and the
# T-WALLPAPER note in res/values/config.xml). AOSP resolves the default
# wallpaper via the hardcoded `R.drawable.default_wallpaper` reference in
# WallpaperManager.openDefaultWallpaper() — there is no config key — so the
# RRO drawable override is the authoritative path for both first boot (§9)
# and factory-reset re-apply (§11, via WallpaperUpdateReceiver ->
# clearWallpaper() -> openDefaultWallpaper()).
#
# The PRODUCT_COPY_FILES entries below are a SECONDARY, system-property
# fallback: WallpaperManager.openDefaultWallpaper() consults
# `ro.config.wallpaper` (PROP_WALLPAPER) BEFORE falling back to the drawable,
# so if an operator sets ro.config.wallpaper=/system/etc/wallpaper_guardtalk_default.png
# the file path wins. They are kept gated so the build stays green if the
# operator has not delivered the PNGs. No GrapheneOS wallpaper is ever
# shipped: upstream wallpaper assets are excluded by
# vendor/adevtool/config/device/common/file-exclusion.yml.
guardtalk_wp := vendor/guardtalk/branding/wallpapers
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_default.png),)
PRODUCT_COPY_FILES += \
    $(guardtalk_wp)/wallpaper_guardtalk_default.png:system/etc/wallpaper_guardtalk_default.png
endif
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_dark.png),)
PRODUCT_COPY_FILES += \
    $(guardtalk_wp)/wallpaper_guardtalk_dark.png:system/etc/wallpaper_guardtalk_dark.png
endif
