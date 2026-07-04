# GuardTalkCameraIconOverlay

**Task:** F-ICON-CAMERA
**Target:** `app.grapheneos.camera` (GrapheneOS Camera, prebuilt APK)
**Partition:** `product` (`product_specific: true`)
**Certificate:** `platform`

## Purpose

Replaces the default Camera app launcher icon with the GuardTalkOS-themed
Camera glyph (obsidian background + guard-tinted lens). Static runtime
resource overlay — applies at boot, no user action required.

## Verified icon resource names

Extracted from `external/Camera/prebuilt/Camera.apk` via `aapt2 dump resources`:

| Resource ID   | Type        | Name                          | Notes                                    |
|---------------|-------------|-------------------------------|------------------------------------------|
| `0x7f0f0000`  | `mipmap`    | `ic_launcher`                 | Main launcher icon; adaptive (`res/E4.xml`) |
| `0x7f0800b8`  | `drawable`  | `ic_launcher_foreground`      | Foreground glyph                         |
| `0x7f060060`  | `color`     | `ic_launcher_background`      | Background color ref                     |

The stock `mipmap/ic_launcher` (`res/E4.xml`) is an `<adaptive-icon>` that
references `@color/ic_launcher_background` (background) and
`@drawable/ic_launcher_foreground` (foreground + monochrome). This overlay
replaces the whole `mipmap/ic_launcher` entry with a themed adaptive icon
pointing at our own `@drawable/ic_launcher_background` and
`@drawable/ic_launcher_foreground`, so the override wins regardless of the
target's internal references.

## Camera source path

`external/Camera/` — prebuilt APK import (`android_app_import` in
`external/Camera/Android.bp`, `product_specific: true`, no `certificate:` field
→ Soong default = platform). The APK ships in `/product/app/Camera/Camera.apk`.

## Partition + certificate rationale

- **Partition match (T-HOME-ROOTCAUSE class):** Camera is `product_specific`,
  so the overlay MUST be `product_specific` to land in `/product/overlay/`. On
  Android 14+ (SDK 34+), OverlayManager silently drops cross-partition static
  RROs.
- **Certificate:** Camera is signed with the platform key (Soong default for
  the prebuilt import). `mipmap/ic_launcher` is NOT declared `<overlayable>`,
  so a test-key static RRO would be silently dropped at boot. Signing with
  `platform` matches Camera's cert so OverlayManager enables the override.

## Files

```
GuardTalkCameraIconOverlay/
├── Android.bp                                              # RRO module (product_specific, platform cert)
├── AndroidManifest.xml                                     # targetPackage=app.grapheneos.camera, static, priority 999
└── res/
    ├── mipmap-anydpi-v26/ic_launcher.xml                   # adaptive-icon (API 26+)
    ├── drawable-xxxhdpi/
    │   ├── ic_launcher_background.png                      # 432px obsidian background
    │   └── ic_launcher_foreground.png                      # 432px foreground glyph
    ├── mipmap-mdpi/ic_launcher.png                         # 48px legacy
    ├── mipmap-hdpi/ic_launcher.png                         # 72px legacy
    ├── mipmap-xhdpi/ic_launcher.png                        # 96px legacy
    ├── mipmap-xxhdpi/ic_launcher.png                       # 144px legacy
    └── mipmap-xxxhdpi/ic_launcher.png                      # 192px legacy
```

## Wiring

Registered in `vendor/guardtalk/radio-excised/telephony-features.mk` alongside
`GuardTalkSettingsIconOverlay` (sibling icon RRO):
`PRODUCT_PACKAGES += GuardTalkCameraIconOverlay` +
`PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkCameraIconOverlay`.
