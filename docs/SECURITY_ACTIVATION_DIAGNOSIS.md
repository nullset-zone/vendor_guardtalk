# Security Activation Diagnosis (T-SEC-ACTIVATE)

**Date:** 2026-07-24  
**Source XML:** `packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml`  
**Overlay policy:** `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml`  
**Product props:** `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`

## Gate model (authoritative)

| Surface | Password required? |
|---------|-------------------|
| Open Security dashboard / browse categories | **No** |
| Read-only rows (`anti_bruteforce`, `gt_info` browse, status when post-unlock) | **No** |
| 7 mutation prefs when `config_security_mutations_require_password=true` | **Yes** (GT Config session) |
| GT Config **writes** (`gt_config_write`) | **Yes** (fail-closed) |
| Security status detail | Post-unlock only (`isPostUnlockStatusAllowed`) — not password-gated |

Mutation keys: `security_device_lock`, `security_sensor_privacy`, `security_usb_protection`, `security_lockdown`, `security_auto_reboot`, `security_duress_config`, `security_secure_wipe`.

## Per-key matrix

| Preference key | Ship status | Gate / condition | Live path (backend) | Notes / missing service |
|----------------|-------------|------------------|---------------------|-------------------------|
| `guardtalk_security_device_lock` | **AVAILABLE** | Mutation password when overlay bool true | `ChooseLockGeneric` via `ScreenLockPreferenceDetailsUtils` | Inactive/policy summary iff helper false (overlay+prop+framework all off) — not “Coming soon” |
| `guardtalk_security_sensor_privacy` | **AVAILABLE** | Mutation password | `Settings.ACTION_PRIVACY_SETTINGS` | Live summary from sensor policy helper |
| `guardtalk_security_usb_protection` | **AVAILABLE** | Mutation password | `ExploitProtectionFragment` (USB-C port mode) | Live summary from USB helper |
| `guardtalk_security_lockdown` | **AVAILABLE** | Mutation password; `DISABLED_FOR_USER` if insecure lock | Immediate lockdown (`requireStrongAuth` + `lockNow`) | Not a QS tile |
| `guardtalk_security_auto_reboot` | **AVAILABLE** | Mutation password | `ExploitProtectionFragment` (auto-reboot picker) | Live Off/Nh summary when profiles on |
| `guardtalk_security_duress` | **AVAILABLE** | Mutation password; needs secure-wipe policy | `DuressPasswordMainActivity` | Never show armed state on lockscreen |
| `guardtalk_security_anti_bruteforce` | **AVAILABLE** (info) | None (not selectable) | Live wipe@N summary from policy | Read-only; no screen |
| `guardtalk_security_secure_wipe` | **AVAILABLE** | Mutation password; needs secure-wipe policy | `GuardTalkSecureWipeActivity` → `SecureWipeEngine` | Shared wipe service required |
| `guardtalk_security_status` | **AVAILABLE** post-unlock | Post-unlock only (not password) | `GuardTalkSecurityStatusFragment` | Pre-unlock: `CONDITIONALLY_UNAVAILABLE` |
| `guardtalk_gt_config` | **AVAILABLE** | **Browse/launch ungated**; session required only for **writes** (`gt_config_write`) | `com.guardtalk.config/.ConfigActivity` | `ConfigApplier` asserts `gt_config_write` fail-closed; Settings does not require session to open ConfigActivity |
| `guardtalk_gt_info` | **AVAILABLE** (browse) | None | `com.guardtalk.validator/.ValidatorActivity` | Was stub/disabled; deep-link to GT Info app |

## Root causes of “Coming soon” / stub-dead (pre-fix)

1. **Helper false positives:** Controllers fall back to `guardtalk_security_stub_summary` (“Coming soon”) when Settings overlay bools are false **and** helpers do not OR with framework `android.guardtalk.*Policy` (product `ro.guardtalk.*` props). On products with props on but overlay not applied to the Settings process, rows look stub-dead despite live backends.
2. **GT Config write authorize gap (fixed):** Launch/browse is ungated; writes must open a session then `ConfigApplier` asserts `gt_config_write` fail-closed. Pre-fix: credential-OK without session open could show a false “unlocked” toast.
3. **GT Info stub:** `GuardTalkSecurityStubPreferenceController` + `enabled=false` left the row non-interactive even though `com.guardtalk.validator` ships.

## Non-shipping / honest gaps

| Item | Status |
|------|--------|
| Network / VPN / Wi‑Fi / Hotspot / Airplane under Security | **Must not ship** (policy) |
| Lockdown / USB / Wipe / Duress QS tiles | **Must not ship** (Phase 3 catalog is Mic/Camera/Battery Saver/Auto-reboot only) |
| Duress armed bit on lockscreen / status shell | **Must not ship** |
| Messenger APK grant e2e (`T-MSG-APK`) | HOLD — unrelated |
| User-build `build.prop` refresh (`T-SEC-P5-PROP-REFRESH`) | HOLD — flash readiness |

No Security dashboard key is blocked on a **missing** in-tree service after this activation, provided:

- `GuardTalkConfigGateService` is started (`SystemServer`)
- Product props / Settings overlay enable policies
- `GuardTalkConfig` + `GuardTalkValidator` packages are on the product

If `guardtalk_config_gate` binder is missing → writes and gated mutations **fail-closed** (deny), browse of Security remains open.

## Acceptance mapping

| Acceptance | Diagnosis verdict |
|------------|-------------------|
| Each shippable key has live path or documented non-ship | See matrix — all listed keys ship or are explicitly forbidden |
| Write-gate fail-closed | ConfigApplier + gate manager |
| Browse ungated | Dashboard open + status/anti-bruteforce/gt_info ungated |
| Helpers report live when policies on | Overlay **OR** prop **OR** framework policy |
