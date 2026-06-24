# GuardTalkOS — Integration Guide (AOSP / GrapheneOS)

How to drop each asset into the build. Paths are relative to the AOSP/GrapheneOS source root unless noted. Prefer **RRO overlays** or `PRODUCT_COPY_FILES` over editing upstream `frameworks/` in place — it keeps GrapheneOS rebases clean.

> **Conventions:** `<device>` = `shiba`/`husky` (Pixel 8/8 Pro), `comet`/`caiman`/`tokay` (Pixel 9 family) — confirm your exact codenames. `$OUT` = product out dir.

---

## 1. Boot animation  →  `01_boot_animation/bootanimation.zip`

The runtime looks for the file, in order, at:
`/system/media/bootanimation.zip` → `/oem/media/` → `/product/media/` → `/system/product/media/`.

**Recommended (vendor-clean):** copy via your device makefile so it lands in `product`:

```make
# device/google/<device>/device.mk  (or a guardtalk vendor overlay)
PRODUCT_COPY_FILES += \
    vendor/guardtalk/bootanimation/bootanimation.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip
```

**Critical:** the zip **must be STORED (no compression)** or it will not play. This pack's zip is already stored — do not re-zip with deflate. If you regenerate:
```bash
cd build_dir && zip -0 -r bootanimation.zip desc.txt part0 part1
```

- `desc.txt` is `1080 2400 24` then `p 1 0 part0` (intro, once) and `p 0 0 part1` (loop forever).
- Resolution is 1080×2400; Android scales to the panel, so it covers Pixel 8 and 9.
- **Caveat (honest):** the *bootloader* splash and the yellow **"device is unlocked"** verified-boot warning are in the bootloader and **cannot be replaced** on a Pixel without breaking Verified Boot. The boot animation is the first brandable surface *after* that screen. Do not promise otherwise.

---

## 2. Default wallpaper  →  `02_wallpapers/`

**Option A — override the AOSP default (RRO overlay, preferred):**
Provide `default_wallpaper.png` in an overlay targeting `android`:
```
vendor/guardtalk/overlay/frameworks/base/core/res/res/drawable-nodpi/default_wallpaper.png
```
Use `guardtalk_wallpaper_obsidian_aosp_default_nodpi_1440x3120.png` (rename to `default_wallpaper.png`).

**Option B — ship as selectable built-in wallpapers:** add the per-resolution PNGs to your wallpaper picker package (`packages/apps/WallpaperPicker2` / `ThemePicker` partner resources). Match the file to the panel:
| Device | File |
|---|---|
| Pixel 8 | `..._pixel8_1080x2400.png` |
| Pixel 9 | `..._pixel9_1080x2424.png` |
| Pixel 8 Pro / 9 Pro | `..._pixel8pro_9pro_1344x2992.png` |
| Pixel 9 Pro XL | `..._pixel9proxl_1280x2856.png` |

Variants: `obsidian` (default, grid + glow), `black` (OLED-minimal), `signal` (accent-tinted). The mark sits in the upper-middle so the lock-screen clock and the home dock both stay clear.

---

## 3. Launcher / system icon  →  `03_launcher_icon/res/`

Drop the `res/` tree into the target app (the launcher, or any system app whose identity is GuardTalk):

```
res/drawable/ic_launcher_background.xml      (solid Obsidian)
res/drawable/ic_launcher_foreground.xml      (Signal mark, in the 66dp safe zone)
res/drawable/ic_launcher_monochrome.xml      (Material You themed-icon layer)
res/mipmap-anydpi-v26/ic_launcher.xml        (adaptive-icon, references the three layers)
res/mipmap-anydpi-v26/ic_launcher_round.xml
res/mipmap-{mdpi…xxxhdpi}/ic_launcher.png        (legacy, pre-API 26)
res/mipmap-{mdpi…xxxhdpi}/ic_launcher_round.png
```
Manifest already-standard:
```xml
<application
    android:icon="@mipmap/ic_launcher"
    android:roundIcon="@mipmap/ic_launcher_round" ... >
```
- **Adaptive spec honoured:** 108dp canvas, content kept inside the 66dp safe circle, so any OEM mask (circle/squircle/rounded-square) crops cleanly.
- `ic_launcher_512.png` is the Play-Store / hi-res master.

---

## 4. GuardTalk app icons  →  `04_app_icons/{guardtalk_messenger,guardtalk_admin}/res/`

Same structure as §3, one set per app. Visual coding:
- **Messenger** — Signal-green background, Obsidian mark (bright, approachable).
- **Admin** — Obsidian background, Signal mark (dark, technical).

Drop each `res/` into the corresponding app module.

---

## 5. Status-bar / notification icon  →  `05_notification_status/res/`

```
res/drawable/ic_stat_guardtalk.xml         (white silhouette, 24dp, tintable)
res/drawable-{mdpi…xxxhdpi}/ic_stat_guardtalk.png
```
Use it as the small icon:
```java
new NotificationCompat.Builder(ctx, CH)
    .setSmallIcon(R.drawable.ic_stat_guardtalk) ...
```
- **Must be white-on-transparent** (the system tints it). Already correct here — do not add colour.
- For system status (SystemUI), the analogous override path is `frameworks/base/packages/SystemUI/res/drawable*` via an overlay.

---

## 6. Settings → About phone  →  `06_settings_about/res/`

- `res/drawable/ic_guardtalk_logo.xml` — compact mark vector for the About row.
- `res/drawable-*/ic_guardtalk_about_banner.png` — horizontal lockup banner.
Override in a `packages/apps/Settings` overlay:
```
vendor/guardtalk/overlay/packages/apps/Settings/res/drawable*/...
```
Settings renders the live version string itself; the asset is logo-only by design.

---

## 7. Setup-wizard welcome  →  `07_setup_wizard/`

GrapheneOS uses its own first-run flow (AOSP `Provision` is minimal; Google's SetupWizard is closed). Place `guardtalk_welcome_*.png` (or the SVG → VectorDrawable) into your setup/provision app's `res/drawable*` and reference it on the welcome screen. `welcome_square_1024` suits a centered hero; the portrait sizes suit full-bleed.

---

## 8. Material You themed icon + brand accent

- **Themed-icon layer:** `08_themed_icon/ic_launcher_monochrome.xml` is already wired into every adaptive icon's `<monochrome>` slot — Android tints it from the system palette automatically. No extra step beyond shipping the adaptive icons.
- **Pin the system accent to Signal (optional):** `00_brand_reference/material_you_accent_overlay.xml` overrides `system_accent1_*`. Ship as an RRO targeting `android`:
```
vendor/guardtalk/overlay/frameworks/base/core/res/res/values/colors_device_defaults.xml
```
This makes Quick Settings, toggles, and the clock use Signal regardless of wallpaper. Leave it out if you want wallpaper-derived dynamic colour instead.
- **Brand colours for any app/overlay:** `00_brand_reference/colors.xml` → `res/values/colors.xml`.

---

## Build / QA checklist
- [ ] `bootanimation.zip` is **STORED** (verify: `unzip -v` shows `Stored`, not `Defl`).
- [ ] Adaptive icons render under circle **and** squircle masks (Settings → see all masks).
- [ ] Notification icon is pure white on transparent (no colour bleed when tinted).
- [ ] `default_wallpaper.png` overlay resolves (Settings → Wallpaper shows GuardTalk).
- [ ] Themed icons follow the system tint (enable "Themed icons" in launcher).
- [ ] No off-palette colour introduced; wordmark used as supplied vector, never re-typeset.
- [ ] Bootloader/"unlocked" warning left unchanged (cannot be branded; documented).

## Where each upstream graphic normally lives (quick reference)
| Asset | Stock location |
|---|---|
| Boot animation | `frameworks/base/data/bootanimation/` → built `bootanimation.zip`; runtime `/product/media/` |
| Default wallpaper | `frameworks/base/core/res/res/drawable-nodpi/default_wallpaper.png` |
| Launcher icon | per-app `res/mipmap-*` + `mipmap-anydpi-v26/ic_launcher.xml` |
| Status icons | per-app `res/drawable*`; system in `SystemUI/res/drawable*` |
| About branding | `packages/apps/Settings/res/drawable*` |
| System accent | generated by Monet; override via RRO `system_accent1_*` |
