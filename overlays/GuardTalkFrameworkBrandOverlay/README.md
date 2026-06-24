# GuardTalkFrameworkBrandOverlay (T-W2-I6-THEME)

Runtime resource overlay on the framework (`targetPackage="android"`).

## Purpose

Replaces upstream / GrapheneOS-branded framework UI surfaces with GuardTalk
brand:

- OS display name → `GuardTalkOS`
- Device display name → `GuardTalk`
- Manufacturer display string → `GuardTalk`
- Brand color palette (placeholder, see `branding/theme/colors.xml`)

## Status

**PLACEHOLDER.** All values are placeholders pending operator delivery of the
final GuardTalk brand kit. See `vendor/guardtalk/branding/README.md` for the
gap register and the operator deliverable list.

The overlay **builds and installs green** with the placeholder values; the
on-device result is a coherent dark-teal GuardTalk-styled image that is
visually distinct from upstream and contains no GrapheneOS branding.

## Wiring

Wired by `vendor/guardtalk/feature-excised/feature-overlays.mk` (added in
T-W2-I6-THEME):

```makefile
PRODUCT_PACKAGES += GuardTalkFrameworkBrandOverlay
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkFrameworkBrandOverlay
DEVICE_PACKAGE_OVERLAYS += vendor/guardtalk/overlays/GuardTalkFrameworkBrandOverlay
```

## Layout

```text
GuardTalkFrameworkBrandOverlay/
├── Android.bp
├── AndroidManifest.xml
└── res/values/
    ├── colors.xml   GuardTalk brand palette (mirrors branding/theme/colors.xml)
    ├── strings.xml  GuardTalk brand strings (mirrors branding/theme/strings.xml)
    └── config.xml   Framework config hooks (placeholder)
```

## Out of scope (handled elsewhere)

- **System properties** (`ro.product.*`): owned by `vendor/google_devices/`
  (forbidden paths). Not modified here.
- **SetupWizard2 branding**: handled by `GuardTalkSetupWizardOverlay` and the
  source edit in T-W2-I7-WIZ.
- **Boot animation + wallpapers**: wired by
  `vendor/guardtalk/device/tokay/guardtalk-theme.mk` (asset-gated).
- **HAL excision grace entries**: handled by the existing
  `GuardTalkFrameworksBaseOverlay` (NOT this brand overlay) — see I1–I5.
