# QA Evidence — Q-SEC-P1-DEVOPTS

**Task:** `Q-SEC-P1-DEVOPTS`  
**Date:** 2026-07-22  
**Agent:** QA_ENGINEER  
**Depends:** T-SEC-P1-DEVOPTS ✅  
**Verdict:** PASS (static + artifact smoke) — runtime seven-tap **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Build number preference still available | PASS | Overlay `config_show_about_build_number=true`; `BuildNumberPreferenceController.getAvailabilityStatus` uses `GuardTalkAboutPhoneVisibility.isBuildNumberShown` |
| Seven taps cannot unlock Dev Options under GuardTalk policy | PASS | Early return in `handlePreferenceTreeClick` + defense in `enableDevelopmentSettings()` |
| Overlay bool documented | PASS | `config_guardtalk_block_developer_options_unlock=true` + `ABOUT_PHONE_DEVOPTS_POLICY.md` |
| `ro.guardtalk.block_developer_options` documented | PASS | `=1` in `guardtalk-tokay.mk` + policy doc |
| Defense beyond About taps | PASS | `DeveloperOptionsController` hides entry; `DevelopmentSettingsDashboardFragment.onCreate` finishes; `enableDeveloperOptions()` no-ops |

## Policy helper

`com.android.settings.guardtalk.GuardTalkDeveloperOptionsPolicy.isUnlockBlocked`:
- true if overlay bool **or** `ro.guardtalk.block_developer_options`

## Adversarial notes

| Attack | Result |
|--------|--------|
| Tap path after password confirm (`onActivityResult`) | PASS — `enableDevelopmentSettings()` re-checks policy |
| Deep-link to Development Settings | PASS — fragment finishes when blocked |
| System → Developer options row | PASS — `CONDITIONALLY_UNAVAILABLE` when blocked |
| Hide Build number to “solve” Dev Options | FAIL-SAFE — policy forbids; overlay keeps build_number true |
| Pre-existing `DevelopmentSettingsEnabler` true | WARN — UI entry still hidden / dashboard finishes; Global flag not cleared by P1 (document for P5) |

## Build / artifact smoke

| Artifact | Timestamp | Symbol scan |
|----------|-----------|-------------|
| `out/.../Settings.apk` | 2026-07-22 09:57 | `GuardTalkDeveloperOptionsPolicy`, `block_developer_options` FOUND |

## Coverage gaps

- No device: cannot physically seven-tap Build number.
- user vs userdebug production hardening deferred to `T-SEC-P5-HARDEN` (Settings policy independent of `ro.debuggable` — verified in docs + code).

## Gate 5 (Self-Critique)

See TO_ARCHITECT.md — **Q-SEC-P1-DEVOPTS Gate 5: 91%**.
