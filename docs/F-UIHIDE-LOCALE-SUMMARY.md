# F-UIHIDE-LOCALE-SUMMARY — Locale System dashboard summaries

**Status:** REVIEW  
**Priority:** P0  
**QA pair:** Q-UIHIDE-BRAND-DEVICE-SMOKE  
**Depends on:** none (extends F-UIHIDE-SETTINGS EN overlay)

## Problem

EN RRO already sets:

```xml
<string name="system_dashboard_summary">Languages, keyboard, time</string>
```

Android locale resolution prefers app `values-*` over overlay default `values/`.
All **85** `packages/apps/Settings/res/values-*/strings.xml` copies still
translated the old “gestures / backup” System summary, so non-EN System tiles
advertised UI-hidden features.

## Fix (RRO preferred)

Added matching overrides under:

`vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values-*/strings.xml`

Short equivalent of “Languages, keyboard, time” per locale (keyboard term
aligned with Settings `keyboard_settings`). No gesture/backup wording.

EN default overlay string **unchanged**:
`Languages, keyboard, time`.

Translation table (machine-readable):
`F-UIHIDE-LOCALE-SUMMARY-translations.json`

## Coverage

| Set | Count |
|-----|-------|
| Settings `values-*` that define `system_dashboard_summary` | 85 |
| Overlay `values-*` overrides added | 85 |
| Uncovered Settings translators | **0** |

Locales without a Settings `values-*` entry fall back to overlay EN default
(already correct). No base Settings `strings.xml` edits.

### Required major locales (all covered)

ru, de, fr, es, it, pt (+ pt-rBR, pt-rPT), ja, zh-rCN, zh-rTW, ko, ar, hi  
Also: zh-rHK, fr-rCA, es-rUS, en-rAU/CA/GB/IN/XC, and remaining Settings locales.

## Out of scope

- Hiding unrelated Settings entries
- F-BRAND About string rework (left alone)
- Base AOSP Settings locale file edits

## Verification

```bash
rg -n 'system_dashboard_summary' vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res
# Expect: values/ + 85 values-* (86 hits)

rg -n 'system_dashboard_summary' \
  vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values-ru/strings.xml
# Expect: Языки, клавиатура, время — no резерв/жест

# Settings base still has old strings (intentional; RRO wins at runtime)
rg -n 'system_dashboard_summary' packages/apps/Settings/res/values-*/strings.xml | head -20
```

## Rollback (Law 11)

Remove `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values-*/`
overlay `strings.xml` files that contain only `system_dashboard_summary`
(or delete those locale directories). EN `values/strings.xml` override can remain.
