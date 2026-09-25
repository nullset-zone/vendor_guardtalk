# QA Evidence — Q-REMEDIATE-B1-AVBSCRIPT

**Task:** `Q-REMEDIATE-B1-AVBSCRIPT` (retarget AVB host suite to DEC-REMEDIATE-002 SoT; pair of `T-REMEDIATE-B1-AVB` item 4)  
**Date:** 2026-09-16T16:48:09Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B1-AVB` APPROVED static; `T-REMEDIATE-B1-DURESS-USB` APPROVED static; `Q-REMEDIATE-FLASHREADY` ACCEPTED WITH FINDINGS — **not trusted**  
**DEC:** DEC-REMEDIATE-007 (suite retarget); USB/AVB product SoT = DEC-REMEDIATE-002  
**Verdict:** **PASS (host lunch + static)** — EXIT=0 FAIL=0. `BUILD_KEYS=dev-keys` **HOLD**. Signed vbmeta / lock / green **HOLD**. Device **HOLD**. **FLASH_READY=false** (not invented). **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Architect FLASHREADY ACCEPT and Backend lunch dumps were **not trusted**. Product Java/mk **not** edited. DURESS-USB suite **not** overwritten. Lunch re-run on this host. No USB GO. No `m`. No `fastboot flashing lock`. No commit. `Q-ONDEVICE` **not** started. Serial `54111FDAS000GN` **not** locked.

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML. Guardian MCP/HTTP not called (TOOL UNAVAILABLE). Memory-bank **not** edited (dispatch forbid). Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | USB duress gate = yellow OR green (`isVerifiedBootYellowOrGreen`) | **PASS** | Java L619 / L674–676; suite require_fixed + python exact body |
| 2 | `isVerifiedBootGreen` not required (identifier ABSENT) | **PASS** | `rg` no matches; python identifier ABSENT |
| 3 | komodo user `usb_duress_wipe.enabled=1` is **not** a FAIL | **PASS** | hardening.mk L48 allowed; old NEGATIVE HIT removed |
| 4 | Java unset default may still be `"0"` | **PASS** | `SystemProperties.get(..., "0")`; Java default not `"1"` |
| 5 | Independent `lunch komodo-trunk_staging-user` project AVB path / SHA256_RSA4096 | **PASS** | `BOARD_AVB_KEY_PATH=vendor/guardtalk/branding/signing-keys/avb.pem` `BOARD_AVB_ALGORITHM=SHA256_RSA4096` `BOARD_AVB_ENABLE=true` |
| 6 | `avb.pem` ABSENT; no testkey as product path; pem-absent HOLD | **PASS / HOLD** | file ABSENT; find empty; `m`/vbmeta HOLD |
| 7 | lunch user (not userdebug); no USB GO; no FLASH_READY=true | **PASS / HOLD** | variant=user; FLASH_READY=false; adb empty |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b1_avb_host.sh
# RESULT: PASS (host)  bash_PASS=56 bash_HOLD=5 PY_RC=0
# PY_COUNTS PASS_COUNT=13 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED PASS lines in log: 69  HOLD: 5  FAIL: 0  SUITE_EXIT=0
# LIVE_DEVICE_CLAIMED=false
# GREEN=HOLD
# KEYS_SIGN_LOCK=HOLD
# ITEM7_USB_SOT=DEC-002 (yellow||green; user default-on allowed; Java default 0)
# DEVICE=HOLD
# BUILD_KEYS_POSTSIGN=HOLD (dev-keys)
# FLASH_READY=false
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-AVBSCRIPT_SUITE.out`

`pytest platform/tests` N/A (AOSP BoardConfig / QA bash, not AEGIS Python platform).

DURESS-USB suite **not** re-run this stamp (already PASS; do not overwrite).

## Independent rematch (do not trust T / Architect dumps)

### USB SoT (DEC-002) — tree, this stamp

- `UsbPortSecurityHooks.java` L632–634 Java default still `"0"` (unset / userdebug stay opt-in)
- L619 gate calls `isVerifiedBootYellowOrGreen(vbootState)`
- L674–676 body `"yellow".equals(state) || "green".equals(state)`
- Identifier `isVerifiedBootGreen` **ABSENT**
- `guardtalk-production-hardening.mk` L44–48 user-gated `vendor.guardtalk.usb_duress_wipe.enabled=1`

### Lunch (user product)

This host, this stamp:

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
TARGET_BUILD_TYPE=release
PRODUCT_DEFAULT_DEV_CERTIFICATE=vendor/guardtalk/branding/signing-keys/releasekey
BUILD_KEYS=dev-keys
BOARD_AVB_ENABLE=true
BOARD_AVB_KEY_PATH=vendor/guardtalk/branding/signing-keys/avb.pem
BOARD_AVB_ALGORITHM=SHA256_RSA4096
```

Not `external/avb/test/data/testkey_rsa4096.pem`. User `PRODUCT_PACKAGES` / `PRODUCT_PACKAGES_DEBUG`: `su` / `overlay_remounter` **ABSENT**.

### Sidecar adversarial (not product truth)

`lunch komodo-trunk_staging-userdebug` → `TARGET_BUILD_VARIANT=userdebug`.  
`BOARD_AVB_KEY_PATH=` (empty dumpvar) → Makefile testkey fallback at `m`.  
`BUILD_KEYS=test-keys`. Do not lock the sidecar.

### Keys / lock / device

- `test ! -f vendor/guardtalk/branding/signing-keys/avb.pem` → PASS (ABSENT) → signed vbmeta **HOLD**
- find pem/pk8 under `vendor/guardtalk` empty; git index empty
- `fastboot flashing lock` **not** executed
- `adb devices`: header only, serial absent → device **HOLD**
- Green **not** claimed (Pixel custom-key truth yellow)

## What changed in the suite (QA script only)

Previous FLASHREADY FAIL=4 (SoT drift):

1. required `isVerifiedBootGreen` green-only
2. treated user `usb_duress_wipe.enabled=1` as NEGATIVE HIT
3. python USB gate drifted `green=False`
4. python rematch exit 1 (cascade)

Retarget: yellow\|\|green required; green-only identifier forbidden; user default-on allowed; Java default `"0"` still required. AVB path / algorithm / pem-absent / no testkey / lunch user **kept**.

## Residuals (not a flash GO)

- `avb.pem` ABSENT — keys/sign/lock HOLD
- Operator-goal `verifiedbootstate=green` HOLD (custom-key yellow)
- `BUILD_KEYS=dev-keys` until post-sign HOLD
- Empty adb — on-device / lock HOLD
- **FLASH_READY=false.** **PASS HOLD remains.** Do not claim live.

## Forbidden actions this stamp

USB GO not started. `m` not started. Flash not started. Git commit not started. Product Java/mk not edited. DURESS-USB suite not overwritten. Derived `.agent-comm/TASK_QUEUE.md` not edited. Memory-bank not edited. `Q-ONDEVICE` not started. Status **REVIEW only**. Never APPROVED. FLASH_READY **not** invented true.
