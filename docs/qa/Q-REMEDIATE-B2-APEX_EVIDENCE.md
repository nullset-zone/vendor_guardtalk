# QA Evidence — Q-REMEDIATE-B2-APEX (item 13 residual)

**Task:** `Q-REMEDIATE-B2-APEX` (independent rematch of `T-REMEDIATE-B2-APEX`)  
**Date:** 2026-09-16T15:25:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** T-REMEDIATE-B2-APEX APPROVED static 2026-09-16T15:14:00Z (Architect). **Not trusted.**  
**DEC:** DEC-REMEDIATE-005  
**Verdict:** **PASS (host lunch + static)** — BCP/SSR DeviceLock jars **HOLD** (PRESENT, intentional Zygote). Stale `out/` APEX **HOLD**. adb empty **HOLD**. On-device / Zygote **not claimed**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). **PASS HOLD remains.** `m` not run. EXCISE suite **not overwritten**.

Independent rematch. Backend and Architect lunch dumps were **not trusted**. Product source was not edited. Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP / HTTP / aegis-verifier / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `devicelock-apex-excised.mk` included from `guardtalk-feature-excised.mk` AFTER apps-excised KEEP | **PASS** | include apps-excised.mk line 37; KEEP restore inside that file; include `devicelock-apex-excised.mk` line 151 |
| 2 | `lunch komodo-trunk_staging-user` (session-only GIT_CONFIG `safe.directory` for `vendor/adevtool`; `set +u` around envsetup) | **PASS** | EXIT 0; `TARGET_PRODUCT=komodo` `TARGET_BUILD_VARIANT=user` (not userdebug) |
| 3 | PRODUCT_PACKAGES: `com.android.devicelock` ABSENT, `com.android.devicelock-debug` ABSENT, DeviceLockController ABSENT, Gallery2 ABSENT, GmsCompat ABSENT | **PASS** | exact-token rematch on `_artifacts/Q-REMEDIATE-B2-APEX_PRODUCT_PACKAGES.txt` (1392 words) |
| 4 | PRODUCT_PACKAGES: HTMLViewer PRESENT, UniversalMediaPlayer PRESENT | **PASS** | same dump; KEEP list unchanged in `apps-excised.mk` |
| 5 | BCP `com.android.devicelock:framework-devicelock` and SSR `com.android.devicelock:service-devicelock` still PRESENT is HOLD (do not FAIL; do not strip BCP) | **HOLD** | `PRODUCT_APEX_BOOT_JARS` + `PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS` dumps; APEX mk active code does not touch those lists |
| 6 | Stale `out/target/product/komodo` APEX HOLD. adb empty HOLD. Do not invent on-device/Zygote PASS. Do not lift PASS HOLD. Do not `m` | **HOLD** | stale `.apex` 3723264 bytes 2026-09-15; `adb devices` empty list; `LIVE_DEVICE_CLAIMED=false` |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b2_apex_host.sh
# RESULT: PASS (host)  bash_PASS=35 bash_HOLD=7 PY_RC=0
# Combined: 48 PASS / 0 FAIL / 9 HOLD  (PY_COUNTS PASS_COUNT=13 FAIL_COUNT=0 HOLD_COUNT=2)
# EXIT=0
```

`pytest platform/tests`: N/A (AOSP product makefiles).

First suite run FAILed on comment-only `PRODUCT_APEX_BOOT_JARS` / `PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS` strings in `devicelock-apex-excised.mk` (documentation of why BCP is **not** stripped). Suite now ignores `#` comments. **Not a product FAIL.** Second run EXIT 0.

## Independent rematch (do not trust T/Architect)

### Include order

- `vendor/guardtalk/feature-excised/apps-excised.mk` at `guardtalk-feature-excised.mk:37` (KEEP HTMLViewer / UniversalMediaPlayer).
- Dedicated `vendor/guardtalk/feature-excised/devicelock-apex-excised.mk` at `:151` (after KEEP restore; after `apex-bcp-excised.mk`).
- Drop list: `com.android.devicelock`, `com.android.devicelock-debug` from `PRODUCT_PACKAGES` and `PRODUCT_PACKAGES_DEBUG` only.

### Lunch packages (komodo user)

- `com.android.devicelock` ABSENT
- `com.android.devicelock-debug` ABSENT
- `DeviceLockController` / `DeviceLockControllerDebug` ABSENT
- `Gallery2` ABSENT (not un-excised)
- `GmsCompat` ABSENT (drop stanza not used as the APEX filter)
- `HTMLViewer` PRESENT (KEEP)
- `UniversalMediaPlayer` PRESENT (KEEP)

### BCP / SSR (intentional Zygote HOLD)

- `PRODUCT_APEX_BOOT_JARS`: `com.android.devicelock:framework-devicelock` **PRESENT** → **HOLD** (not FAIL)
- `PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS`: `com.android.devicelock:service-devicelock` **PRESENT** → **HOLD** (not FAIL)
- `SystemServiceRegistry` still imports/calls `DeviceLockFrameworkInitializer` (BCP required)
- APEX mk active code does **not** strip BCP/SSR. `apex-bcp-excised.mk` has no active DeviceLock strip.

### Stale out / device

- `out/target/product/komodo/system/apex/com.android.devicelock.apex` present (mtime 2026-09-15 05:14) → **HOLD** (not product truth; `m` not run)
- `out/target/product/komodo/apex/com.android.devicelock/` present → **HOLD**
- `adb devices`: empty list → device HOLD
- On-device / Zygote DeviceLock-absent **not claimed**. PASS HOLD **not lifted**.

## Residuals (not FAIL)

- BCP/SSR DeviceLock jars remain on Zygote classpath until a future SSR+BCP lockstep (not this card).
- Stale userdebug `out/` APEX remains until a user `m`.
- Device serial `54111FDAS000GN` not attached.
- Next `m` may dexpreopt-fail until BCP+SSR lockstep (documented HOLD, not FAIL).
