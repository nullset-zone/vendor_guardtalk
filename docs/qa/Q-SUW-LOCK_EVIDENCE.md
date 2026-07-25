# QA Evidence — Q-SUW-LOCK

**Task:** `Q-SUW-LOCK` (Community lock + Syndicate QR `device_password` fail-closed / secrets / build smoke)  
**Date:** 2026-07-24  
**Agent:** QA_ENGINEER  
**Depends:** `T-SUW-LOCK-APPLY` ✅ APPROVED, `F-SUW-LOCK-UI` ✅ APPROVED  
**Decision:** DEC-SUW-LOCK-001  
**Verdict:** **GO** (static + module build smoke) — device E2E **HOLD** (no adb device)

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Community `SecureLevel` → `CommunityLockActivity` (not `SetupWizard.next`; not ProvisionQr) | PASS | `SecureLevelActivity.kt` else-branch `startActivity(CommunityLockActivity)` + `finish()`; no code call to `SetupWizard.next` |
| 2 | CommunityLock password+confirm + `DevicePasswordApplier`; no PIN/pattern UI | PASS | layout password+confirm `textPassword`; `applyPassword`; Next gated; no createPin/createPattern/LockPatternView |
| 3 | Community skips QR | PASS | Neither activity in `primaryUserActivities`; Community branch does not launch ProvisionQr |
| 4 | Syndicate `device_password` required; Ed25519 intact; fail-closed missing/empty/short | PASS | `validateQuality` + `applyPasswordOrThrow`; `verifyEd25519` before field use; applier Failure reasons |
| 5 | ProvisionQr Next gated; safe errors (no password echo) | PASS | Next disabled until success; `mapProvisionError` → string res; unused `%1$s` format not used |
| 6 | GuardTalkConfig parser/applier parity | PASS | `QrPayloadParser` syndicate require + GT `DevicePasswordApplier` / `ConfigApplier.applyDevicePassword` |
| 7 | No plaintext password in Log (applier/apply paths) | PASS | No Log interpolation of `$password`/`$trimmed`/`devicePassword`/etc. |
| 8 | `m SetupWizard2 GuardTalkConfig` EXIT=0 | PASS | QA session: LUNCH_EXIT=0 BUILD_EXIT=0; pin bypassed then restored |

## Static script

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_suw_lock_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=95 FAIL_COUNT=0 EXIT=0
```

**Counts:** **95 / 95** PASS (0 FAIL).  
Script: `vendor/guardtalk/docs/qa/verify_suw_lock_static.sh` (executable).

Optional in-script build:

```bash
GT_QA_RUN_BUILD=1 bash vendor/guardtalk/docs/qa/verify_suw_lock_static.sh
```

## Build / artifact smoke (this QA session)

| Source | Command / note | Result |
|--------|----------------|--------|
| QA `m SetupWizard2 GuardTalkConfig` | lunch `tokay-trunk_staging-userdebug`; adevtool pin bypass → restore | **LUNCH_EXIT=0 BUILD_EXIT=0** (~03:58; ninja no-op — modules already green from T/F) |
| Pin file | `vendor/google_devices/tokay/adevtool-version-check.mk` | **RESTORED** (active outdated-check present) |
| `SetupWizard2.apk` | symbols: `CommunityLockActivity`, `DevicePasswordApplier`, `device_password` | PRESENT |
| `GuardTalkConfig.apk` | symbols: `DevicePasswordApplier`, `device_password` | PRESENT |
| DONE_LOG | T-SUW-LOCK-APPLY / F-SUW-LOCK-UI APPROVED; F cites `m SetupWizard2 EXIT=0` | cited |

## Adb

```text
# No device attached this session — runtime E2E HOLD
```

Runtime smoke **HOLD** (optional per dispatch):

- Community SUW: SecureLevel → lock page → set password → DateTime
- Syndicate SUW: QR missing/empty/short `device_password` keeps Next disabled
- Syndicate SUW: valid signed QR enables Next; unlock credential set

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| SecureLevel Community calls `SetupWizard.next` | forbidden | only in comment; no code call | PASS |
| Community launches ProvisionQr | forbidden | else-branch → CommunityLock only | PASS |
| PIN/pattern enrollment UI | forbidden | password-only layout + createPassword | PASS |
| Log interpolates password vars | forbidden | none in applier/apply paths | PASS |
| UI `provision_failed` `%1$s` with exception | forbidden | `mapProvisionError` → fixed string res | PASS |
| Invent PASS without script EXIT=0 | forbidden | script 95/95 EXIT=0 recorded | PASS |
| Ed25519 removed / unsigned QR accepted | forbidden | verify still required before parse fields | PASS |

## Coverage gaps

- No device/emulator: cannot adb-verify wizard navigation or lockscreen credential presence after apply.
- Fresh bytecode rebuild was a no-op (`ninja: no work to do`) after F/T module builds; EXIT=0 still verified for targets.
- Out-of-tree QR mint tooling not exercised (doc-only per DEC-SUW-LOCK-001).

## Gate 5 (Self-Critique)

**Q-SUW-LOCK Gate 5: 95%** (manual; MCP `ultimate_critique` unavailable — `python: not found`). See `.agent-comm/inbox/TO_ARCHITECT.md`.

### PQE Assessment: Code Entropy LOW — edition routing is explicit; fail-closed quality gates shared; secrets not logged; password-only policy retained.
