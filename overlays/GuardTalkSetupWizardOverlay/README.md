# GuardTalkSetupWizardOverlay

Runtime resource overlay (`package="com.guardtalk.overlay.setupwizard"`)
targeting SetupWizard2 (`targetPackage="app.grapheneos.setupwizard"`).

## F-REMEDIATE-B5-BRANDING (item 23)

Welcome + Finish screens use `@drawable/guardtalk_welcome_square`. The app
ships an **opaque RGB square** (`packages/apps/SetupWizard2/res/drawable-nodpi/`).
This overlay replaces that placeholder with a **branded RGBA PNG** (lime
chevron + wordmark on a fully transparent ground). Resource name is
unchanged so the RRO applies.

```text
res/drawable-nodpi/guardtalk_welcome_square.png
```

Master copy:
`vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/07_setup_wizard/guardtalk_welcome_square_transparent.png`

Regenerate: `python3 vendor/guardtalk/branding/scripts/render_f_remediate_b5_branding.py`

## Wiring

`vendor/guardtalk/feature-excised/feature-overlays.mk`:

```makefile
PRODUCT_PACKAGES += GuardTalkSetupWizardOverlay
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay
DEVICE_PACKAGE_OVERLAYS += vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay
```

Static RRO, priority 999, `system_ext_specific`, platform certificate (must
match SetupWizard2).

## Layout

```text
GuardTalkSetupWizardOverlay/
├── Android.bp
├── AndroidManifest.xml
└── res/
    ├── drawable-nodpi/guardtalk_welcome_square.png
    └── values/{colors,strings}.xml
```
