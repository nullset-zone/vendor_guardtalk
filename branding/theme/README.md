# GuardTalk placeholder theme contract (T-W2-I6-THEME)

This directory holds the **canonical** GuardTalk brand colors and strings.
The runtime-resource overlays under
`vendor/guardtalk/overlays/GuardTalk*/res/values/` mirror these values (each
RRO ships its own resource table because each targets a different
`targetPackage`). When the real brand kit lands, update the files in this
directory first, then propagate the same values into each overlay.

All values are tagged PLACEHOLDER and may be replaced verbatim.

## Files

- `colors.xml`  — GuardTalk brand color palette (PLACEHOLDER)
- `strings.xml` — GuardTalk brand strings (PLACEHOLDER)

## Mirror sites (keep in sync)

- `overlays/GuardTalkFrameworkBrandOverlay/res/values/colors.xml`
- `overlays/GuardTalkFrameworkBrandOverlay/res/values/strings.xml`
- `overlays/GuardTalkSettingsOverlay/res/values/colors.xml` (if brand colors needed there)
- `overlays/GuardTalkSystemUIOverlay/res/values/colors.xml` (if brand colors needed there)
- `overlays/GuardTalkSetupWizardOverlay/res/values/colors.xml`
- `overlays/GuardTalkSetupWizardOverlay/res/values/strings.xml`
