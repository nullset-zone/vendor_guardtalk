# QA Evidence — Q-SEC-ACTIVATE

**Task:** `Q-SEC-ACTIVATE` (Security activation acceptance)  
**Date:** 2026-07-24  
**Agent:** QA_ENGINEER  
**Depends:** `T-SEC-ACTIVATE` ✅ APPROVED, `F-SEC-ACTIVATE-UI` ✅ APPROVED  
**Verdict:** **GO** (static) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Diagnosis doc present + per-key matrix | PASS | `vendor/guardtalk/docs/SECURITY_ACTIVATION_DIAGNOSIS.md` — all 11 shippable keys **AVAILABLE** |
| Live controllers (not stub-only) | PASS | Dashboard XML wires 11 dedicated controllers; no `GuardTalkSecurityStubPreferenceController` |
| No false Coming soon / stub_summary in live controllers | PASS | No `R.string.guardtalk_security_stub_summary` under live Security controllers; inactive/policy summaries used |
| Browse ungated (GT Config launch) | PASS | `handleGtConfigClick` → `launchGtConfig` with no write-gate assert |
| Mutations fail-closed (`wasSessionOpened`) | PASS | `GuardTalkSecurityDashboardFragment` + `GuardTalkConfigGateClient.wasSessionOpened` |
| ConfigApplier asserts `gt_config_write` | PASS | `ConfigApplier.apply` → `assertMutationAuthorized(GT_CONFIG_WRITE)` fail-closed |
| GT Info → ValidatorActivity | PASS | `GuardTalkGtInfoPreferenceController` → `com.guardtalk.validator.ValidatorActivity` |
| No network under Security dashboard | PASS | No wifi/vpn/hotspot/airplane/network keys/controllers in `guardtalk_security_dashboard.xml` |
| Helpers OR policy | PASS | Lock/Sensor/USB/AutoReboot helpers: overlay OR prop OR framework; SecureWipe OR prop |
| T/F APPROVED + `m Settings GuardTalkConfig` EXIT=0 | PASS | Root+agent queues APPROVED; DONE_LOG + F report EXIT=0; APKs present with symbols |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sec_activate_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=132 FAIL_COUNT=0 EXIT=0
```

**Counts:** **132 / 132** PASS (0 FAIL).  
Created for `Q-SEC-ACTIVATE` (mirrors `verify_sys_hide_gesture_backup_static.sh` / `verify_sec_p*_static.sh` style).

## Build / artifact smoke (cited; no fresh `m` this session)

| Source | Command / note | Result |
|--------|----------------|--------|
| `TASK_QUEUE.md` T-SEC-ACTIVATE APPROVED | Architect APPROVED 2026-07-24; Gate 5 92%; diagnosis + write-gate | cited |
| `TASK_QUEUE.md` F-SEC-ACTIVATE-UI APPROVED | Architect APPROVED 2026-07-24; Gate 5 94% | cited |
| `.agent-comm/completed/DONE_LOG.md` | F: `m Settings GuardTalkConfig EXIT=0`; T APPROVED | cited |
| F report (pre-QA inbox) | `m Settings GuardTalkConfig -j$(nproc)` **EXIT=0** (~09:10) | cited |
| `out/.../Settings/Settings.apk` | symbols: `ValidatorActivity`, `wasSessionOpened`, `GuardTalkGtInfoPreferenceController` | PRESENT |
| `out/.../GuardTalkConfig/GuardTalkConfig.apk` | symbols: `assertMutationAuthorized`, `gt_config_write` | PRESENT |

No rebuild performed this QA session (task allows citing T/F APPROVED green build + static script).

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime smoke **SKIPPED**:

- Security dashboard preference navigation
- GT Config browse without password / write denied without session
- GT Info → ValidatorActivity launch on device

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Stub controller wired in dashboard | forbidden | not in XML | PASS |
| Live controller uses stub_summary resource | forbidden | none | PASS |
| GT Config launch asserts `gt_config_write` | forbidden | launch ungated | PASS |
| ConfigApplier missing write assert | forbidden | assert present fail-closed | PASS |
| Network key under Security XML | forbidden | none | PASS |
| Invent PASS without script | forbidden | script EXIT=0 recorded | PASS |

## Coverage gaps

- No device/emulator: cannot adb-verify preference clicks, password prompt UX, or Validator launch.
- Overlay/prop runtime merge not exercised on device (static helpers + diagnosis only).
- Fresh `m Settings GuardTalkConfig` not re-run this session (cited F APPROVED EXIT=0 + APK symbols).

## Gate 5 (Self-Critique)

See `.agent-comm/inbox/TO_ARCHITECT.md` / `TO_ARCHITECT_Q-SEC-ACTIVATE.md` — **Q-SEC-ACTIVATE Gate 5: 93%**.

### PQE Assessment: Code Entropy LOW — browse/write split honest; write fail-closed retained; false Coming soon removed; network absent from Security surface.
