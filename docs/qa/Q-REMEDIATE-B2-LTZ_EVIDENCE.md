# QA Evidence — Q-REMEDIATE-B2-LTZ

**Task:** `Q-REMEDIATE-B2-LTZ` (independent rematch of `T-REMEDIATE-B2-LTZ` item **8** residual)  
**Date:** 2026-09-16T15:55:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B2-LTZ` Architect-APPROVED static (2026-09-16T15:46:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-006  
**Verdict:** **PASS (host lunch + static)** — runtime LTZ/CountryDetector-absent **HOLD**. `m` **HOLD**. adb empty **HOLD**. **Not device-fixed.** **PASS HOLD remains** (not lifted). Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. `SystemServer.java` was **not** edited. Lunch was re-run on this host (`komodo-trunk_staging-user`, not userdebug). No USB GO. No wipe. No `m`. No commit. `Q-REMEDIATE-B2-ONDEVICE` was **not** started. Sibling `verify_remediate_b2_lms_host.sh` and `verify_remediate_b2_excise_host.sh` were **not** overwritten (SHA256 unchanged).

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP/HTTP / `aegis-verifier` / `ask_guardian` / `gate_enforcer` **not called**. Memory-bank **not** edited (dispatch FORBIDDEN).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | FEATURE-gate `CountryDetectorService` on `FEATURE_LOCATION` (LMS/BT shape); construct + addService inside else | **PASS** | construct L2402 + addService L2403 only inside FEATURE else (else opens L2399). Unconditional construct would FAIL |
| 2 | FEATURE-gate `LocationTimeZoneManagerService.Lifecycle` on `FEATURE_LOCATION` (LMS/BT shape); start inside else | **PASS** | startService L2433 only inside FEATURE else (else opens L2430). Unconditional start would FAIL |
| 3 | LMS FEATURE_LOCATION gate L2383–2393 still present; not rewritten into this card's block | **PASS** | window still has LMS Lifecycle start + else; no CountryDetector / LTZ / GNSS tokens |
| 4 | GNSS still behind `config_enableGnssTimeUpdateService` (default false); do not invent GNSS start | **PASS** | start L2443 behind bool L2440; not inside FEATURE_LOCATION else; AOSP config.xml `false`; no vendor/guardtalk xml/mk/java overlay |
| 5 | HTMLViewer / UniversalMediaPlayer KEEP | **PASS** | `GUARDTALK_APPS_KEEP` + lunch PRESENT |
| 6 | Radios not re-enabled | **PASS** | `persist.radio.disabled=1` present, `=0` absent; lunch Bluetooth ABSENT |
| 7 | Independent `lunch komodo-trunk_staging-user` → `TARGET_PRODUCT=komodo` `TARGET_BUILD_VARIANT=user` | **PASS** | this-host lunch EXIT 0; not userdebug |
| 8 | Runtime LTZ-absent / CountryDetector-absent / `m` / adb | **HOLD** | adb empty; `m` not run; no system_server log. Do not invent on-device PASS |
| 9 | Status REVIEW only; never APPROVED; no commit; PASS HOLD not lifted | **PASS** | this stamp |

BT reference (same shape): `startServiceFromJar(BLUETOOTH_SERVICE_CLASS` only inside `FEATURE_BLUETOOTH` else (start L1787; else L1785).

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b2_ltz_host.sh
# RESULT: PASS (host)  bash_PASS=24 bash_FAIL=0 bash_HOLD=5 PY_RC=0
# PY_COUNTS PASS_COUNT=23 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=47 HOLD_COUNT=5 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# LTZ_RUNTIME_ABSENT=HOLD COUNTRYDETECTOR_RUNTIME_ABSENT=HOLD
# M=HOLD DEVICE=HOLD PASS_HOLD=remains
# Q-ONDEVICE=not started
# LMS_SUITE_UNTOUCHED=true EXCISE_SUITE_UNTOUCHED=true
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-LTZ_SUITE.out`  
Dumps: `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B2-LTZ_PRODUCT_{PACKAGES,PROPERTY_OVERRIDES}.txt`

`pytest platform/tests` N/A (AOSP SystemServer / vendor mk / feature XML, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

This host, this stamp (comments stripped for brace match):

- BT: `startServiceFromJar(BLUETOOTH_SERVICE_CLASS` **only** inside `hasSystemFeature(FEATURE_BLUETOOTH)` **else** (start L1787; else opens L1785).
- LMS: `startService(LocationManagerService.Lifecycle.class)` **only** inside `hasSystemFeature(FEATURE_LOCATION)` **else** (start L2391; else opens L2389). Window L2383–2393 **not** rewritten with LTZ/CD/GNSS.
- CountryDetector: `new CountryDetectorService` L2402 and `ServiceManager.addService(Context.COUNTRY_DETECTOR` L2403 **only** inside FEATURE_LOCATION else (else L2399). Ready-path still `if (countryDetectorF != null)`.
- LTZ: `startService(LocationTimeZoneManagerService.Lifecycle.class)` **only** inside FEATURE_LOCATION else (start L2433; else L2430).
- GNSS: `startService(GnssTimeUpdateService.Lifecycle.class)` L2443 still behind `config_enableGnssTimeUpdateService` (AOSP default **false**). **Not** nested in a FEATURE_LOCATION else (not an invented GNSS start).
- Exactly one start/construct site each.

### Lunch (user product)

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
DUMP_PKGS_BYTES=35221 DUMP_PKGS_WORDS=1392
```

| Token | Status |
|-------|--------|
| HTMLViewer | **PRESENT** (KEEP) |
| UniversalMediaPlayer | **PRESENT** (KEEP) |
| Bluetooth | **ABSENT** |
| persist.radio.disabled=1 | **PRESENT** |
| persist.radio.disabled=0 | **ABSENT** |

LMS suite SHA256 `65055734bd4e097e9806563baec204324a4e5731a8efa0f7a58f99cef8c33a46` unchanged.  
EXCISE suite SHA256 `1c2bc3c630828634c31129aba57694329eb89c892cd8e740dcfb246b4e6b7f7a` unchanged.
