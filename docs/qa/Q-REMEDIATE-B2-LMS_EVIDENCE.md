# QA Evidence — Q-REMEDIATE-B2-LMS

**Task:** `Q-REMEDIATE-B2-LMS` (independent rematch of `T-REMEDIATE-B2-LMS` item **8** residual)  
**Date:** 2026-09-16T15:25:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B2-LMS` Architect-APPROVED static (2026-09-16T15:14:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-005  
**Verdict:** **PASS (host lunch + static)** — runtime LMS-absent **HOLD**. `m` **HOLD**. adb empty **HOLD**. **Not device-fixed.** **PASS HOLD remains** (not lifted). Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. `SystemServer.java` was **not** edited. Lunch was re-run on this host (`komodo-trunk_staging-user`, not userdebug). No USB GO. No wipe. No `m`. No commit. `Q-REMEDIATE-B2-ONDEVICE` was **not** started. Sibling `verify_remediate_b2_excise_host.sh` was **not** overwritten (that card still HOLDs LMS start historically).

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP/HTTP / `aegis-verifier` / `ask_guardian` / `gate_enforcer` **not called**. Memory-bank **not** edited (dispatch FORBIDDEN).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `LocationManagerService.Lifecycle` FEATURE-gated on `FEATURE_LOCATION` the same way BT uses `FEATURE_BLUETOOTH` | **PASS** | BT startServiceFromJar only in FEATURE_BLUETOOTH else (L1787 / else L1785). LMS startService only in FEATURE_LOCATION else (L2391 / else L2389) |
| 2 | `startService` of LMS Lifecycle inside that else; unconditional start = FAIL | **PASS** | exactly one Lifecycle startService; brace matcher: inside else after `hasSystemFeature(FEATURE_LOCATION)` |
| 3 | `handheld_core_hardware.prebuilt.xml` has **no** live `<feature name="android.hardware.location*` tags | **PASS** | XML comments stripped; live tags empty. Comment-only hits at L21, L26, L89 OK |
| 4 | loc-excised still drops FusedLocation / gnssd | **PASS** | `GUARDTALK_LOC_PACKAGES` + lunch `PRODUCT_PACKAGES` ABSENT; SSA FusedLocation ABSENT |
| 5 | HTMLViewer / UniversalMediaPlayer KEEP | **PASS** | `GUARDTALK_APPS_KEEP` + lunch PRESENT |
| 6 | `persist.radio.disabled=1` still set; radios not re-enabled | **PASS** | radio-excised.mk L21; user `PRODUCT_PROPERTY_OVERRIDES` contains `=1`, not `=0` |
| 7 | Independent `lunch komodo-trunk_staging-user` → `TARGET_PRODUCT=komodo` `TARGET_BUILD_VARIANT=user` | **PASS** | this-host lunch EXIT 0; not userdebug |
| 8 | Runtime LMS-absent / `m` / adb | **HOLD** | adb empty (`List of devices attached` only); `m` not run; no system_server log. Do not invent on-device PASS |
| 9 | Status REVIEW only; never APPROVED; no commit; PASS HOLD not lifted | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b2_lms_host.sh
# RESULT: PASS (host)  bash_PASS=24 bash_FAIL=0 bash_HOLD=4 PY_RC=0
# PY_COUNTS PASS_COUNT=13 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=37 HOLD_COUNT=4 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# LMS_RUNTIME_ABSENT=HOLD M=HOLD DEVICE=HOLD
# PASS_HOLD=remains
# Q-ONDEVICE=not started
# EXCISE_SUITE_UNTOUCHED=true
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-LMS_SUITE.out`  
Dumps: `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B2-LMS_PRODUCT_{PACKAGES,SYSTEM_SERVER_APPS,PROPERTY_OVERRIDES}.txt`

`pytest platform/tests` N/A (AOSP SystemServer / vendor mk / feature XML, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### SystemServer FEATURE gate

This host, this stamp (comments stripped for brace match):

- BT: `startServiceFromJar(BLUETOOTH_SERVICE_CLASS` **only** inside `hasSystemFeature(FEATURE_BLUETOOTH)` **else** (start L1787; else opens L1785).
- LMS: `startService(LocationManagerService.Lifecycle.class)` **only** inside `hasSystemFeature(FEATURE_LOCATION)` **else** (start L2391; else opens L2389).
- No `startService(LocationManagerService.class)` without Lifecycle.
- Unconditional LMS start **not present** (would be FAIL).

### Handheld XML

Live `<feature name="android.hardware.location*` tags after comment-strip: **none**.  
Comment-only mentions remain (L21 header, L26 gps.prebuilt, L89 GPS include note).

### Lunch (user product)

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
DUMP_PKGS_BYTES=35221 DUMP_PKGS_WORDS=1392
```

| Token | Status |
|-------|--------|
| FusedLocation | **ABSENT** |
| gnssd | **ABSENT** |
| HTMLViewer | **PRESENT** (KEEP) |
| UniversalMediaPlayer | **PRESENT** (KEEP) |
| persist.radio.disabled=1 | **PRESENT** in PRODUCT_PROPERTY_OVERRIDES |
| persist.radio.disabled=0 | **ABSENT** |
| PRODUCT_SYSTEM_SERVER_APPS FusedLocation | **ABSENT** (words: SettingsProvider WallpaperBackup InputDevices KeyChain Telecom) |

### HOLD (do not invent PASS)

- Runtime LMS process / `dumpsys` / logcat **not** collected (`m` not run; no user image this stamp).
- adb: `List of devices attached` then empty. Serial `54111FDAS000GN` **absent**.
- **PASS HOLD remains.** This card does **not** lift it.
- `Q-REMEDIATE-B2-ONDEVICE` **not** started.

## Files written (QA only)

- `vendor/guardtalk/docs/qa/verify_remediate_b2_lms_host.sh` (new; does not overwrite the EXCISE suite)
- `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-LMS_EVIDENCE.md`
- `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-LMS_SUITE.out`
- `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B2-LMS_PRODUCT_*.txt`

Not touched: `SystemServer.java`, loc-excised drop lists, handheld live tags, radio-excised `persist.radio.disabled=1`, `verify_remediate_b2_excise_host.sh`, doctrine, secrets, derived `.agent-comm/TASK_QUEUE.md`, memory-bank.
