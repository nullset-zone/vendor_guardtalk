# GuardTalkSetupWizardOverlay (T-W2-I6-THEME)

Runtime resource overlay on SetupWizard2 (`targetPackage="com.android.setupwizard"`).

## Purpose

Supplies the GuardTalk brand colors + strings the SetupWizard2 Welcome screen
and wizard pages read. **Ties to T-W2-I7-WIZ**, which adds the
transparent-black logo source edit in `packages/apps/SetupWizard2` and
confirms the fingerprint enrollment step is removed (ties to T-W2-I2-FP).

## Status

**PLACEHOLDER.** This overlay provides the color + string table the wizard
reads; the concrete logo drawable swap (transparent-black GuardTalk logo on
the Welcome screen) is delivered in T-W2-I7-WIZ via a source edit in
`packages/apps/SetupWizard2`. The overlay builds and installs green now; no
GrapheneOS wizard branding is shipped.

## Wiring

Wired by `vendor/guardtalk/feature-excised/feature-overlays.mk` (added in
T-W2-I6-THEME):

```makefile
PRODUCT_PACKAGES += GuardTalkSetupWizardOverlay
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay
DEVICE_PACKAGE_OVERLAYS += vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay
```

## Layout

```text
GuardTalkSetupWizardOverlay/
├── Android.bp
├── AndroidManifest.xml
└── res/values/
    ├── colors.xml   GuardTalk brand palette (mirrors branding/theme/colors.xml)
    └── strings.xml  GuardTalk brand strings (mirrors branding/theme/strings.xml)
```

## Out of scope (handled in T-W2-I7-WIZ)

- Transparent-black logo drawable swap in SetupWizard2 Welcome screen
- Confirmation that the fingerprint enrollment step is removed (T-W2-I2-FP)
- Source edits under `packages/apps/SetupWizard2/`
