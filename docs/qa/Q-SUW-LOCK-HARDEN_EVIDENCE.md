# QA Evidence — Q-SUW-LOCK-HARDEN

**Task:** `Q-SUW-LOCK-HARDEN` (H1 key-rotate + M1 lock backstop + M2 provision net-fail)  
**Date:** 2026-07-24  
**Agent:** QA_ENGINEER  
**Depends:** `T-SUW-QR-KEY-ROTATE` ✅ APPROVED, `T-SUW-LOCK-BACKSTOP` ✅ APPROVED, `T-SUW-PROVISION-NET-FAIL` ✅ APPROVED  
**Verdict:** **GO** (static + module build smoke) — device E2E **HOLD** → `Q-SUW-LOCK-DEVICE-SMOKE` (adb empty)

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| H1 | Old private seed base64 absent from `vendor/guardtalk` product tree + `SetupWizard2` | PASS | Script H1 scans (old seed constructed in parts; product globs exclude `docs/qa` detectors) |
| H1 | New private seed absent from product trees / qa artifacts | PASS | Extracted only from `.agent-comm/inbox/TO_ARCHITECT_T-SUW-QR-KEY-ROTATE.md`; absent from SUW + GT product + `docs/qa` |
| H1 | SUW + GT `TEST_PUBLIC_KEY` byte arrays identical (rotated public) | PASS | Both 32-byte arrays match `[-74, 62, …, -43]` |
| M1 | `SecurityActivity` does not call `SetupWizard.next` on insecure+no-biometric | PASS | `!hasBiometricFeature()` → `setMovingForward()` + `finish()` + return; next omitted (comment only) |
| M1 | No PIN/pattern / `ACTION_SETUP_LOCK_SCREEN` fallback | PASS | Forbidden patterns absent in `SecurityActivity.kt` |
| M2 | Wi‑Fi/VPN apply fail-closed via `NetworkProvisionException` | PASS | `applyWifi`/`applyVpn` → `Boolean`; throw on false / missing VPN creds |
| M2 | Next stays disabled on network failure | PASS | catch → `provisioned=false` + `primaryButton.isEnabled=false`; `provision_failed_network` |
| R | Prior Q-SUW-LOCK invariants (password-only, `device_password`, Ed25519) | PASS | Nested `verify_suw_lock_static.sh` **95/95 EXIT=0** |
| B | `m SetupWizard2 GuardTalkConfig` EXIT=0 | PASS | LUNCH_EXIT=0 BUILD_EXIT=0 (~03:54; ninja no-op); pin bypass→restore |
| L | No secret Log interpolation regressions | PASS | Scanned SUW/GT applier/provision/community/security paths |

## Static script

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_suw_lock_harden_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=64 FAIL_COUNT=0 EXIT=0
# (nested) verify_suw_lock_static.sh PASS_COUNT=95 FAIL_COUNT=0 EXIT=0
```

**Counts:** Harden script **64 / 64** PASS (0 FAIL), EXIT=0.  
Nested prior lock: **95 / 95** PASS, EXIT=0.  
Script: `vendor/guardtalk/docs/qa/verify_suw_lock_harden_static.sh` (executable).

Optional in-script build:

```bash
GT_QA_RUN_BUILD=1 bash vendor/guardtalk/docs/qa/verify_suw_lock_harden_static.sh
# or faster build-only regression skip:
GT_QA_SKIP_REGRESSION=1 GT_QA_RUN_BUILD=1 bash vendor/guardtalk/docs/qa/verify_suw_lock_harden_static.sh
```

## Build / artifact smoke (this QA session)

| Source | Command / note | Result |
|--------|----------------|--------|
| QA `m SetupWizard2 GuardTalkConfig` | lunch `tokay-trunk_staging-userdebug`; adevtool pin bypass → restore | **LUNCH_EXIT=0 BUILD_EXIT=0** (~03:54; `ninja: no work to do`) |
| Pin file | `vendor/google_devices/tokay/adevtool-version-check.mk` | **RESTORED** (active outdated-check present) |
| `SetupWizard2.apk` / `GuardTalkConfig.apk` | tokay out/ artifacts present | PRESENT |
| Deps | Dual queues cite three T-* **APPROVED** | cited |

## Adb

```text
List of devices attached
(empty)
```

Runtime E2E **HOLD** for `Q-SUW-LOCK-DEVICE-SMOKE` (do not invent PASS):

- Community: SecureLevel → CommunityLock → password → DateTime
- Syndicate: QR network fail keeps Next disabled; valid path sets unlock credential
- SecurityActivity backstop on non-secure no-biometric device

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Old seed in product source/docs | forbidden | absent | PASS |
| New seed in product / qa evidence | forbidden | only in Architect rotate report | PASS |
| SUW/GT public key drift | forbidden | identical 32 bytes | PASS |
| Insecure no-biometric calls `SetupWizard.next` | forbidden | omitted | PASS |
| Wi‑Fi soft-fail still enables Next | forbidden | `NetworkProvisionException` → Next off | PASS |
| VPN consent intent soft-skip | forbidden | returns false → throw | PASS |
| Log interpolates `$password` / `devicePassword` / `vpnPsk` | forbidden | none in scanned paths | PASS |
| Invent device E2E PASS without adb | forbidden | HOLD documented | PASS |

## Coverage gaps

- No device/emulator: cannot adb-verify wizard navigation, lockscreen credential, or live Wi‑Fi/VPN apply.
- Fresh bytecode rebuild was a no-op (`ninja: no work to do`) after T-* module builds; EXIT=0 still verified.
- Residual (engineer-documented): lock may already be set if network fails after `applyPasswordOrThrow` — Next still disabled (fail-closed for advance).

## Gate 5 (Self-Critique)

**Q-SUW-LOCK-HARDEN Gate 5: 94%** (manual; MCP `ultimate_critique` unavailable — `python: not found`).

### Manual Gate 5 rubric (0–10 each)

| Criterion | Score |
|-----------|------:|
| Acceptance criteria met (H1/M1/M2/R/B/L) | 10 |
| Scope compliance (qa docs/scripts only) | 10 |
| All static checks EXIT=0 | 10 |
| No invented PASS / adb HOLD honest | 10 |
| Adversarial coverage (seed leak, next bypass, soft-fail) | 9 |
| Edge cases (consent intent, netId&lt;0, key parity) | 9 |
| Independence (did not edit product) | 10 |
| Minimal footprint | 9 |
| Bug / residual documentation | 9 |
| Coverage gaps stated | 8 |
| **Total** | **94%** |

### PQE Assessment: Code Entropy LOW — key material out-of-tree; fail-closed advance paths explicit; network apply returns Boolean + typed exception; prior lock invariants retained via nested script.
