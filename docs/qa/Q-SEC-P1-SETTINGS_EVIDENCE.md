# QA Evidence — Q-SEC-P1-SETTINGS

**Task:** `Q-SEC-P1-SETTINGS`  
**Date:** 2026-07-22  
**Agent:** QA_ENGINEER  
**Depends:** T-SEC-P1-SETTINGS ✅, T-SEC-P1-GTGATE ✅  
**Verdict:** PASS (static + artifact smoke) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Security dashboard skeleton present | PASS | `packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml` + `GuardTalkSecurityDashboardFragment` |
| Overlay enables GuardTalk Security dashboard | PASS | `config_use_guardtalk_security_dashboard=true` in GuardTalkSettingsOverlay |
| No network/VPN/Wi‑Fi/Hotspot/Airplane under Security | PASS | Dashboard XML has zero network prefs (comment forbid only); Settings `security/guardtalk/` sources have no wifi/vpn/hotspot/airplane refs |
| GT Config gate fail-closed (no session ⇒ mutation denied) | PASS | Service + Manager + Client (see below) |
| Settings/services build smoke | PASS* | Prior tokay artifacts contain symbols (see Build smoke) |

\* Fresh `m Settings services` not re-run this session (`TARGET_PRODUCT` unset; lunch heavy). Prior artifacts independently scanned.

## Security skeleton

Stub categories/rows (disabled): device lock, sensor privacy, USB, lockdown, auto-reboot, duress, status, GT Info.  
Interactive: `guardtalk_gt_config` → password confirm via `GuardTalkConfigGateClient`.

## GT Config fail-closed (static)

| Case | Expected | Code path |
|------|----------|-----------|
| No binder | unauthorized / throw | `GuardTalkConfigGateManager`: null service → `false` / `SecurityException` |
| No session | mutation denied | `GuardTalkConfigGateService.isMutationAuthorizedInternal` → `hasActiveSessionLocked` |
| Unknown mutation key | denied | `KNOWN_MUTATIONS` membership check |
| Safe mode | denied | `ro.sys.safemode` / `persist.sys.safemode` |
| Shell/root session open | `SecurityException` | `enforcePrivilegedCallerForSessionOpen` |
| No secure lock | session open returns false | `LockPatternUtils.isSecure` |
| Screen off | sessions cleared | `ACTION_SCREEN_OFF` receiver |
| Service registration | present | `SystemServer` → `startService(GuardTalkConfigGateService.class)` |
| Product prop | `ro.guardtalk.config_password_gate=1` | `vendor/guardtalk/device/tokay/guardtalk-tokay.mk` |

## Build / artifact smoke

| Artifact | Timestamp | Symbol scan |
|----------|-----------|-------------|
| `out/.../Settings.apk` | 2026-07-22 09:57 | `GuardTalkSecurityDashboard`, `GuardTalkConfigGateClient`, `guardtalk_security_dashboard` FOUND |
| `out/.../services.jar` | 2026-07-22 10:06 | `GuardTalkConfigGate`, `guardtalk_config_gate` FOUND |

## Adversarial notes

| Test | Result |
|------|--------|
| Network prefs smuggled into Security XML | PASS — none |
| Mutation without session | PASS — denied |
| Missing binder | PASS — fail-closed |
| Escape hatch `ro.guardtalk.config_password_gate=0` | WARN — documented bring-up fail-open; residual risk until P5 |

## Coverage gaps

- No device/emulator: cannot adb-verify UI hierarchy or live binder deny.
- No instrumentation unit test executed in this session (static script + docs only).

## Gate 5 (Self-Critique)

See TO_ARCHITECT.md — **Q-SEC-P1-SETTINGS Gate 5: 90%**.
