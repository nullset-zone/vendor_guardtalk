# GuardTalk default wallpapers gap + asset spec (T-W2-I6-THEME)

> **STATUS: PLACEHOLDER.** No GuardTalk default wallpapers have been delivered.
> This file documents the gap, the spec the operator must meet, and the
> placeholder wiring that lands in the meantime so the build has a coherent
> default-wallpaper target.

## Gap

The GrapheneOS fork substitutes default wallpapers from its own vendor layer.
Per dispatch constraints we do NOT touch `vendor/google_devices/tokay/tokay.mk`
or `BoardConfig.mk`, so GuardTalk default wallpapers are wired entirely through
a `vendor/guardtalk/` hook:

- `vendor/guardtalk/device/tokay/guardtalk-theme.mk` — declares
  `PRODUCT_COPY_FILES` entries for the default wallpaper(s), `ifeq`-gated on
  each file's existence so the build stays green when the assets are absent.

The wallpaper files themselves are NOT committed in this increment (binary
assets, not yet delivered). When the operator drops them into this directory,
the build automatically picks them up with no further source change. No
GrapheneOS-branded wallpaper is shipped.

## Spec the operator must meet

| Asset                              | Filename                              | Format | Resolution |
|------------------------------------|---------------------------------------|--------|------------|
| Default wallpaper (light)          | `wallpaper_guardtalk_default.png`     | PNG    | 1080×2400+ |
| Default wallpaper (dark)           | `wallpaper_guardtalk_dark.png`        | PNG    | 1080×2400+ |

- Aspect ratio must cover 20:9 (tokay portrait) without crop artifacts.
- Must NOT contain any GrapheneOS logo, wordmark, or upstream-branding text.
- Recommended: dark-teal background (`#0E1419`) with subtle GuardTalk accent
  (`#18C2D2`) motif so the wallpaper is visually consistent with the
  placeholder theme palette in `branding/theme/colors.xml`.

## Wire path (already in place)

```makefile
# In vendor/guardtalk/device/tokay/guardtalk-theme.mk:
guardtalk_wp := vendor/guardtalk/branding/wallpapers
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_default.png),)
  PRODUCT_COPY_FILES += $(guardtalk_wp)/wallpaper_guardtalk_default.png:system/wallpaper_guardtalk_default.png
endif
ifneq ($(wildcard $(guardtalk_wp)/wallpaper_guardtalk_dark.png),)
  PRODUCT_COPY_FILES += $(guardtalk_wp)/wallpaper_guardtalk_dark.png:system/wallpaper_guardtalk_dark.png
endif
```

When both files land, the default-wallpaper RRO in
`GuardTalkFrameworkBrandOverlay` (which sets
`default_wallpaper_component` / `image_wallpaper_default`) will be updated in a
follow-up increment to point at the new paths. Until then, the AOSP default
wallpaper is used and no GrapheneOS wallpaper is shipped.
