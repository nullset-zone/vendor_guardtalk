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
# GuardTalk bootanimation asset (AOSP format, stored, 1080x2400, <=30fps,
# <=8s). Only the light/normal bootanimation.zip is wired.
#
# T-BOOTANIM-DEDUPE: the dark variant (bootanimation-dark.zip, played when
# ro.boot.theme=1) was REMOVED. On dark-mode reboots the dark variant was
# playing a second, GuardTalk-branded animation -> "second boot logo" symptom.
# AOSP's BootAnimation.cpp (frameworks/base/cmds/bootanimation, ~lines 75-77 +
# 719-722) falls back to bootanimation.zip when bootanimation-dark.zip is
# absent, so a single light variant is sufficient and consistent across
# light/dark reboots.
#
# This file is the SINGLE source of truth for bootanimation wiring from the
# vendor/guardtalk layer. The duplicate PRODUCT_COPY_FILES entry that used to
# live in guardtalk-tokay.mk (from GuardTalkOS_Brand_Assets/) has been removed
# to prevent double-wiring / build conflicts.
# Until delivered, the AOSP default bootanimation
# (frameworks/base/cmds/bootanimation) is used and no GrapheneOS bootanimation
# is shipped. The GrapheneOS bootanimation zips that adevtool unpacks from the
# factory image at vendor/adevtool/dl/unpacked/tokay-*/product/media/ are
# EXCLUDED from the build by vendor/adevtool/config/device/common/
# file-exclusion.yml (lines 70-71), so they never reach /product/media/.
guardtalk_bootanim_dir := vendor/guardtalk/branding/bootanimation
guardtalk_bootanim := $(guardtalk_bootanim_dir)/bootanimation.zip
ifneq ($(wildcard $(guardtalk_bootanim)),)
PRODUCT_COPY_FILES += $(guardtalk_bootanim):$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip
endif

# T-BOOT-LOGO-FIX2 — Defensive dark-variant excision. Even though T-BOOTANIM-DEDUPE
# removed the local wiring of bootanimation-dark.zip, a GrapheneOS-branded
# bootanimation-dark.zip (505234 bytes, desc.txt "1080 2400 30 / p 1 0 part0")
# was still leaking into the built tokay-target_files.zip via stale adevtool
# unpacked artifacts (vendor/adevtool/dl/unpacked/tokay-*/product/media/).
# On second boot, when the bootloader sets ro.boot.theme=1 (dark mode),
# BootAnimation.cpp:719-722 (frameworks/base/cmds/bootanimation) selects
# PRODUCT_BOOTANIMATION_DARK_FILE ("bootanimation-dark.zip") instead of
# PRODUCT_BOOTANIMATION_FILE ("bootanimation.zip"), so the GrapheneOS dark
# animation played — the "second-boot GrapheneOS logo" regression.
#
# vendor/adevtool/config/device/common/file-exclusion.yml:70 already excludes
# product/media/bootanimation-dark.zip from the adevtool copy, but that filter
# only runs at adevtool-extract time. If the unpacked tree is rehydrated from a
# stale cache (or a future operator re-runs adevtool without the exclusion),
# the dark zip would silently re-enter PRODUCT_COPY_FILES. This late filter runs
# in product-config-late.mk context (after all inherit-product merges) and
# strips ANY :*/bootanimation-dark.zip copy-file entry regardless of source,
# making the single-source-of-truth guarantee from T-BOOTANIM-DEDUPE robust.
_gt_bootanim_dark_drop = $(findstring bootanimation-dark.zip,$(1))
_gt_filtered_bootanim_copy_files :=
$(foreach cf,$(PRODUCT_COPY_FILES),\
  $(if $(call _gt_bootanim_dark_drop,$(cf)),,\
    $(eval _gt_filtered_bootanim_copy_files += $(cf))))
PRODUCT_COPY_FILES := $(strip $(_gt_filtered_bootanim_copy_files))

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
