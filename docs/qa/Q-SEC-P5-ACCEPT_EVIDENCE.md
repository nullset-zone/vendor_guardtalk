# QA Evidence — Q-SEC-P5-ACCEPT

**Task:** `Q-SEC-P5-ACCEPT` (Phase-5 full §32 acceptance + production profile)  
**Date:** 2026-07-23  
**Agent:** QA_ENGINEER  
**Depends:** `T-SEC-P5-HARDEN` ✅, `T-SEC-P5-STATUS` ✅, `F-SEC-P5-STATUS-UI` ✅, Phases 1–4 APPROVED  
**Verdict:** **GO** (static + invoked p1–p4 GO) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Production hardening policy + mk wiring | PASS | `PRODUCTION_HARDENING_POLICY.md`; `guardtalk-production-hardening.mk` included from radio-excised; all hardening props |
| `production_profile` gated on `user` lunch | PASS | `ifeq ($(TARGET_BUILD_VARIANT),user)` → `ro.guardtalk.production_profile=1` |
| Hardening sysctls init | PASS | `init.guardtalk.hardening.rc` kptr/dmesg/ptrace/kexec/perf; PRODUCT_PACKAGES in feature-excised |
| `GuardTalkProductionHardeningPolicy` | PASS | PROP_* + `isProductionProfile` / `isDebuggableOff` / unknown-sources API |
| Security status API doc | PASS | `SECURITY_STATUS_API.md` post-unlock, no Duress, no network, Snapshot fields |
| Snapshot + post-unlock gate | PASS | `GuardTalkSecurityStatus.isPostUnlockStatusAllowed` (UserManager + KeyguardManager); Helper delegates |
| Status UI binds Snapshot fields | PASS | Fragment binds lock/sensor/USB/lockdown/auto-reboot/anti-BF/wipe/clipboard/tmpfs/files/hardening/profile |
| No Duress in status sources/UI | PASS | No `duressArmed` / `isDuressArmed` / status_duress keys in FW/Helper/Fragment/Keys/XML |
| No network rows under status | PASS | status XML + dashboard: no network/wifi/vpn/hotspot/airplane keys |
| Closeout: wipe / fail-closed / QS / Contacts / privacy-files | PASS | Policy docs + `GuardTalkSecureWipePolicy` present; QS four-tile + Contacts suppress + privacy/files docs |
| Phase-5 APPROVED cites | PASS | DONE_LOG / TASK_QUEUE: HARDEN, STATUS, F-STATUS-UI; EXIT=0 cites |
| Regression p1 static | PASS | `verify_sec_p1_static.sh` PASS_COUNT=93 EXIT=0 |
| Regression p2 static | PASS | `verify_sec_p2_static.sh` PASS_COUNT=95 EXIT=0 (script updated for P5 framework gate) |
| Regression p3 static | PASS | `verify_sec_p3_static.sh` PASS_COUNT=62 EXIT=0 |
| Regression p4 static | PASS | `verify_sec_p4_static.sh` PASS_COUNT=115 EXIT=0 |
| Vendor/system build.prop live props | GAP | `out/target/product/tokay/vendor/build.prop` **absent**; system build.prop **absent** |
| Messenger APK absent | DOCUMENTED | No product APK under `vendor/guardtalk/apps`; plumbing from P4 remains |
| adb runtime | DOCUMENTED | `adb devices` empty — device smoke SKIPPED |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sec_p5_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=145 FAIL_COUNT=0 EXIT=0
```

**Counts:** **145 / 145** PASS (0 FAIL).  
Created for `Q-SEC-P5-ACCEPT` (mirrors `verify_sec_p{1,2,3,4}_static.sh` style).

### Companion QA fix (same allowed path)

`verify_sec_p2_static.sh` updated: post-unlock `isUserUnlocked` / `isDeviceLocked` checks now accepted on framework `GuardTalkSecurityStatus` when Helper delegates (Phase-5 architecture). Semantic coverage unchanged.

## Regression summary (invoked)

| Script | Result | PASS_COUNT |
|--------|--------|------------|
| `verify_sec_p1_static.sh` | GO | 93 |
| `verify_sec_p2_static.sh` | GO | 95 |
| `verify_sec_p3_static.sh` | GO | 62 |
| `verify_sec_p4_static.sh` | GO | 115 |

## Artifact / build smoke (cited; no fresh `m` this session)

| Source | Command / note | Result |
|--------|----------------|--------|
| DONE_LOG / TASK_QUEUE `T-SEC-P5-HARDEN APPROVED` | user lunch + production_profile; files_* refresh | EXIT=0 (cited) |
| DONE_LOG / TASK_QUEUE `T-SEC-P5-STATUS APPROVED` | status aggregator + Helper | EXIT=0 (cited) |
| DONE_LOG / TASK_QUEUE `F-SEC-P5-STATUS-UI APPROVED` | `m Settings` | EXIT=0 (cited) |
| `out/target/product/tokay/vendor/build.prop` | live prop confirmation | **ABSENT** (GAP) |
| `out/target/product/tokay/system/build.prop` | `ro.debuggable` user lunch | **ABSENT** (GAP) |

No rebuild performed this QA session (task allows citing prior green builds + static scripts).

## Known gaps

| Gap | Status | Notes |
|-----|--------|-------|
| `adb devices` empty | DOCUMENTED | Runtime smoke deferred (status UI, hardening props on device, wipe e2e) |
| Messenger APK absent | DOCUMENTED | Grant plumbing exists (P4); no product APK — do not fake presence |
| `vendor/build.prop` / `system/build.prop` absent | DOCUMENTED | Cannot confirm live `production_profile` / `ro.debuggable=0` on disk this session; mk wiring verified |
| Release-key / AVB green | DOCUMENTED (policy) | Wiring/docs only; no private keys in git (expected) |

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime smoke **SKIPPED**:

- Post-unlock status UI on device / pre-unlock deny UX
- Production profile bit + `ro.debuggable=0` on flashed user image
- Hardening sysctls after boot
- Secure wipe / anti-bruteforce e2e
- Messenger grant e2e (blocked on APK absence)

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Duress fields on status Snapshot/UI | forbidden | no `duressArmed` / status_duress keys | PASS |
| Network keys under status XML | forbidden | none | PASS |
| Network keys under Security dashboard | forbidden | none | PASS |
| Helper gate without UserManager/Keyguard | fail-closed in framework | framework implements both; Helper delegates | PASS |
| Fake Messenger APK presence | forbidden | absent under apps/ | PASS (GAP doc) |
| Invent PASS without running p1–p4 | forbidden | scripts invoked; EXIT=0 recorded | PASS |

## Coverage gaps

- Device/runtime smoke deferred until adb device available
- Fresh `tokay-trunk_staging-user` lunch + vendor/system build.prop regeneration not re-run this session
- Messenger grant e2e blocked on APK absence
- Extreme Audit (`A-SEC-P5-EXTREME`) ✅ ACCEPTED 2026-07-23 20:00 (Architect); Phase 5 static CONDITIONAL GO

## PQE Assessment

### PQE Assessment: Code Entropy LOW — Phase-5 consolidates status into one Snapshot + framework post-unlock gate; hardening markers are prop/init thin; residual entropy is environment (missing out/ images + no device) not product structure.

## Gate 5

### Ultimate Critique Score: 94% (Gate 5)

Method: MCP `ultimate_critique` attempted; if unavailable/partial, manual fallback applied.  
Manual 0–10: acceptance 10, scope 10, tests pass 10, regressions 10, adversarial 9, edges 8, independence 10, footprint 10, bugs/docs 9, gaps 8 → **94/100**.

## GO / NO-GO

**GO** for Architect review of Phase-5 static acceptance matrix.  
Do **not** treat as production-flash ready until: (1) adb device smoke, (2) regenerate user lunch `vendor`/`system` build.prop to confirm `production_profile` + `ro.debuggable=0`, (3) Messenger APK lands for grant e2e.  
Status remains **REVIEW** — never APPROVED by QA.
