# QA Evidence — Q-REMEDIATE-FLASHREADY

**Task:** `Q-REMEDIATE-FLASHREADY` (independent host aggregator; pair of `A-REMEDIATE-FULL` Phase 3)  
**Date:** 2026-09-16T16:40:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-007  
**Depends:** DEC-REMEDIATE-006 host-static T/Q closed — **not trusted**; Architect preflight dumps **not trusted**  
**Verdict:** **FLASH_READY=false**. Wrapper **EXIT=1** because PRED_A failed (`verify_remediate_b1_avb_host` FAIL=4). PRED_B pem ABSENT **HOLD**. PRED_C stale `out/` userdebug + xbin su **HOLD** (not FAIL). **Not device-fixed.** On-device working **not invented**. Status → **REVIEW** (never APPROVED). **PASS HOLD remains.**

Independent rematch. Architect preflight / A-P3 ACCEPT dumps were **not trusted**. Product/source were **not** edited by QA. No USB GO. No `m`. No flash. No commit. `*_ondevice.sh` **not** run. `Q-ONDEVICE` **not** restarted.

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml` (24 laws + 11 gates). Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**.

## FLASH_READY predicates (this stamp)

| Pred | Rule | Result | Evidence |
|------|------|--------|----------|
| (a) | Every listed suite EXIT=0 and FAIL=0 (HOLD allowed) | **FAIL** | 22/23 PASS; `verify_remediate_b1_avb_host` EXIT=1 FAIL=4 |
| (b) | `avb.pem` at in-tree stem **or** `/mnt/secure/keys/guardtalk/avb.pem` | **HOLD** (false) | both stems ABSENT; `/mnt/secure` missing |
| (c) | `out/target/product/komodo` `ro.build.type=user` and no xbin su/overlay_remounter | **HOLD** (false) | system+product `ro.build.type=userdebug`; xbin su + overlay_remounter 2026-09-15 |
| FLASH_READY | true only if (a)∧(b)∧(c) | **false** | never invented true |

Pem absence and userdebug `out/` are **HOLD, not FAIL**, per dispatch. Aggregator EXIT=1 is **only** from PRED_A (AVB suite).

## Suite table (independent re-run)

| SUITE | EXIT | PASS | FAIL | HOLD | VERDICT |
|-------|------|------|------|------|---------|
| verify_remediate_b1_avb_host | 1 | 60 | 4 | 5 | **FAIL** |
| verify_remediate_b1_duress_usb_host | 0 | 60 | 0 | 4 | PASS |
| verify_remediate_b1_userbuild_host | 0 | 67 | 0 | 6 | PASS |
| verify_remediate_b2_apex_host | 0 | 48 | 0 | 9 | PASS |
| verify_remediate_b2_excise_host | 0 | 86 | 0 | 7 | PASS |
| verify_remediate_b2_lms_host | 0 | 37 | 0 | 4 | PASS |
| verify_remediate_b2_ltz_host | 0 | 47 | 0 | 5 | PASS |
| verify_remediate_b2_telemetry_host | 0 | 72 | 0 | 5 | PASS |
| verify_remediate_b2_yama_host | 0 | 20 | 0 | 9 | PASS |
| verify_remediate_b3_sensors_host | 0 | 82 | 0 | 5 | PASS |
| verify_remediate_b3_validator_host | 0 | 79 | 0 | 5 | PASS |
| verify_remediate_b3_viewer_host | 0 | 93 | 0 | 4 | PASS |
| verify_remediate_b4_checkin_host | 0 | 60 | 0 | 4 | PASS |
| verify_remediate_b4_messenger_host | 0 | 38 | 0 | 4 | PASS |
| verify_remediate_b4_messenger_ux_host | 0 | 61 | 0 | 4 | PASS |
| verify_remediate_b4_wifi_gw_host | 0 | 89 | 0 | 10 | PASS |
| verify_remediate_b5_bootzip_host | 0 | 41 | 0 | 4 | PASS |
| verify_remediate_b5_branding_host | 0 | 32 | 0 | 3 | PASS |
| verify_remediate_b5_defaults_host | 0 | 68 | 0 | 6 | PASS |
| verify_remediate_b5_mtp_host | 0 | 34 | 0 | 3 | PASS |
| verify_remediate_b2_kernel_static | 0 | 28 | 0 | 8 | PASS |
| verify_sec_p5_static | 0 | 163 | 0 | 1 | PASS |
| verify_brand_sweep_static | 0 | 18 | 0 | 3 | PASS |
| **FLASH_READY** | — | — | — | — | **false** |

Totals: **23 suites**. **22 PASS / 1 FAIL**. Summed check lines **1383 PASS / 4 FAIL / 118 HOLD**.

Skipped (not run): `verify_remediate_b1_ondevice.sh`, `verify_remediate_b2_ondevice.sh`, `verify_remediate_b3_osux_device.sh`.

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_flashready_host.sh
# RESULT: FAIL (one or more host suites EXIT!=0 or FAIL>0); FLASH_READY=false
# WRAPPER_PIPE_RC=1
# PRED_A=false PRED_B=false PRED_C=false
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-FLASHREADY_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Architect dumps)

### PRED_B — avb.pem

This host, this stamp:

- `vendor/guardtalk/branding/signing-keys/avb.pem` — **ABSENT** (`test -f` rc=1)
- `/mnt/secure/keys/guardtalk/avb.pem` — **ABSENT**
- `/mnt/secure` — **missing**
- `find vendor/guardtalk \( -name '*.pem' -o -name '*.pk8' \)` — empty

Contents of any key were **not** read. **HOLD**, not FAIL.

### PRED_C — komodo `out/` image

- `out/target/product/komodo/system/build.prop` `ro.build.type=userdebug` (L46); `ro.debuggable=1` (L72)
- `out/target/product/komodo/product/etc/build.prop` `ro.build.type=userdebug` (L48)
- `out/target/product/komodo/system/xbin/su` present (51464 bytes, 2026-09-15)
- `out/target/product/komodo/system/xbin/overlay_remounter` present (613776 bytes, 2026-09-15)

Need `ro.build.type=user` **and** no xbin su. **HOLD**, not FAIL. `m` not run.

### PRED_A — AVB suite FAIL (only FAIL)

`verify_remediate_b1_avb_host` EXIT=1. Four `FAIL:` lines (this stamp):

1. `isVerifiedBootGreen still requires verifiedbootstate=green (pattern missing in UsbPortSecurityHooks.java)`
2. `NEGATIVE HIT: USB duress default-on` — `vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk:48` `vendor.guardtalk.usb_duress_wipe.enabled=1`
3. Python `USB gate drifted flag=True green=False maybe=True`
4. `python structural rematch exit 1` (cascade)

Independent tree rematch (QA did **not** edit these files):

- `UsbPortSecurityHooks.java` L547–548 Java default still `"0"` (unset/userdebug opt-in)
- L558 komodo **user** product default-enables
- L565 / L674–676 `isVerifiedBootYellowOrGreen` = `"yellow".equals(state) || "green".equals(state)` (DEC-REMEDIATE-002)
- `isVerifiedBootGreen` green-only return **absent**
- `guardtalk-production-hardening.mk` L44–48 user-gated `usb_duress_wipe.enabled=1`

Same aggregator run: `verify_remediate_b1_duress_usb_host` EXIT=0 FAIL=0 (yellow||green + user default-on is that card's SoT).

AVB lunch on this stamp still: `TARGET_PRODUCT=komodo` `TARGET_BUILD_VARIANT=user` `BOARD_AVB_ENABLE=true` `BOARD_AVB_KEY_PATH=vendor/guardtalk/branding/signing-keys/avb.pem` `BOARD_AVB_ALGORITHM=SHA256_RSA4096` `BUILD_KEYS=dev-keys` **HOLD**. Green **not** claimed. Lock **not** executed.

This is **suite SoT drift** vs later DURESS-USB (item 7), not a reason to invent FLASH_READY. AVB suite **not** rewritten this stamp (wrapper/evidence only).

### adb / device

`adb devices -l` header only. Serial `54111FDAS000GN` absent. On-device working **not invented**.

## Residuals (not a flash GO)

- `avb.pem` ABSENT both stems — FLASH_READY HOLD (b)
- Stale userdebug `out/` + xbin su — FLASH_READY HOLD (c); T-B1-M **not** dispatched; `m` not run
- AVB host suite still encodes pre-DURESS-USB USB-gate asserts — PRED_A FAIL
- Operator-goal verifiedbootstate **green** remains HOLD (Pixel custom-key truth yellow)
- `BUILD_KEYS=dev-keys` until post-sign HOLD
- Empty adb — on-device / lock / wipe e2e HOLD
- **PASS HOLD remains.** Do not claim live. Do not claim 100% features working on device.

## Forbidden actions this stamp

USB GO not started. `m` not started. Flash not started. Git commit not started. Derived `.agent-comm/TASK_QUEUE.md` not edited. Memory-bank not edited. `Q-ONDEVICE` not restarted. Product/source not edited except QA wrapper under `vendor/guardtalk/docs/qa/`. Status **REVIEW only**. Never APPROVED. FLASH_READY **not** invented true.
