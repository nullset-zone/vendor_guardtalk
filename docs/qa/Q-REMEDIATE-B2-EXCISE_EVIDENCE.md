# QA Evidence — Q-REMEDIATE-B2-EXCISE

**Task:** `Q-REMEDIATE-B2-EXCISE` (independent rematch of `T-REMEDIATE-B2-EXCISE` items **8, 10, 12, 13**)  
**Date:** 2026-09-16T12:39:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B2-EXCISE` Architect-APPROVED static (2026-09-16T12:19:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-001  
**Verdict:** **PASS (host lunch + static)** — LMS start **HOLD**. `com.android.devicelock` APEX **HOLD**. `vendor.pktrouter=1` leftover **HOLD**. adb / `m` / stale out APKs **HOLD**. **Not device-fixed.** On-device GNSS-dead **not claimed**. Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host (`komodo-trunk_staging-user`, not userdebug). No USB GO. No wipe. No `m`. No commit. `Q-REMEDIATE-B2-ONDEVICE`, Block 3, USB GO, and item 7 proofs were **not** started. Sibling `verify_remediate_b2_kernel_static.sh` was **not** overwritten.

GIP-0: loaded `.memory-bank/` and `.aegis/governance/` (24 laws + 11 gates). Gate -1 in-process from local YAML. Guardian MCP/HTTP / `aegis-verifier` / `ask_guardian` / `gate_enforcer` **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent `lunch komodo-trunk_staging-user` → `TARGET_BUILD_VARIANT=user` | **PASS** | lunch banner + `get_build_var` = `user` (not userdebug) |
| 2 | `TARGET_PRODUCT=komodo` | **PASS** | `get_build_var` |
| 3 | FusedLocation / gnssd / NetworkLocation ABSENT from user `PRODUCT_PACKAGES` | **PASS** | dump token-absent; loc-excised drop list |
| 4 | FusedLocation ABSENT from `PRODUCT_SYSTEM_SERVER_APPS` | **PASS** | dump words: SettingsProvider WallpaperBackup InputDevices KeyChain Telecom |
| 5 | gnss / pkt / bip rc ABSENT from `PRODUCT_COPY_FILES` | **PASS** | `init.gnss.rc`, `pixel-gnss-default.rc`, `pktrouter.rc`, `bipchmgr.rc` |
| 6 | GmsCompat / GmsCompatConfig / GmsCompatLib / **AppCompatConfig** ABSENT (Law 0 remove, not disabled) | **PASS** | user dump ABSENT; in drop list; not in KEEP restore |
| 7 | HTMLViewer + UniversalMediaPlayer PRESENT (KEEP) | **PASS** | both tokens in user dump |
| 8 | GosPackageStatePermission log-and-return for GmsCompat even if `IS_DEBUGGABLE` | **PASS** | GmsCompat branch returns **before** `Build.IS_DEBUGGABLE` throw |
| 9 | pktrouter.rc + bipchmgr.rc have no service stanzas; rc ABSENT from COPY_FILES | **PASS** | emptied rc files; COPY_FILES drop |
| 10 | `vendor.pktrouter=1` leftover | **HOLD** (not FAIL) | `vendor/google_devices/komodo/sysprop/vendor.prop:173` (no-op without rc) |
| 11 | DeviceLockController* APK names ABSENT | **PASS** | both tokens ABSENT from user dump |
| 12 | `com.android.devicelock` APEX | **HOLD** | still PRESENT in user `PRODUCT_PACKAGES` |
| 13 | `LocationManagerService.Lifecycle` still starts | **HOLD** | `SystemServer.java:2384` unconditional start; BT is FEATURE-gated, location is not |
| 14 | Device / `m` / stale out / GNSS-dead | **HOLD** | adb empty; stale `out/.../FusedLocation` 2026-09-15; GNSS-dead not invented |
| 15 | Status REVIEW only; never APPROVED; no commit | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b2_excise_host.sh
# RESULT: PASS (host)  bash_PASS=54 bash_HOLD=5 PY_RC=0
# PY_COUNTS PASS_COUNT=31 FAIL_COUNT=0 HOLD_COUNT=3
# COMBINED: PASS_COUNT=85 HOLD_COUNT=8 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# LMS_START=HOLD DEVICELOCK_APEX=HOLD PKTRTR_PROP=HOLD
# GNSS_DEAD_ONDEVICE=HOLD DEVICE=HOLD
# Q-ONDEVICE=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-EXCISE_SUITE.out`  
Dumps: `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B2-EXCISE_PRODUCT_{PACKAGES,SYSTEM_SERVER_APPS,COPY_FILES}.txt`

`pytest platform/tests` N/A (AOSP product mk / vendor init / PMS Java, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### Lunch (user product)

This host, this stamp:

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
DUMP_PKGS_BYTES=35175 DUMP_PKGS_WORDS=1390
```

User `PRODUCT_PACKAGES` exact tokens:

| Token | Status |
|-------|--------|
| GmsCompat | **ABSENT** |
| GmsCompatConfig | **ABSENT** |
| GmsCompatLib | **ABSENT** |
| AppCompatConfig | **ABSENT** |
| FusedLocation | **ABSENT** |
| gnssd | **ABSENT** |
| NetworkLocation | **ABSENT** |
| bipchmgr | **ABSENT** |
| wfc-pkt-router | **ABSENT** |
| DeviceLockController | **ABSENT** |
| DeviceLockControllerDebug | **ABSENT** |
| HTMLViewer | **PRESENT** (KEEP) |
| UniversalMediaPlayer | **PRESENT** (KEEP) |
| com.android.devicelock | **PRESENT** → **HOLD** |

`PRODUCT_SYSTEM_SERVER_APPS`: `SettingsProvider WallpaperBackup InputDevices KeyChain Telecom` — FusedLocation **ABSENT**.

`PRODUCT_COPY_FILES`: `/etc/init/init.gnss.rc`, `/etc/init/pixel-gnss-default.rc`, `/etc/init/pktrouter.rc`, `/etc/init/bipchmgr.rc` **ABSENT**.

### Static wiring

- `apps-excised.mk`: drop list includes GmsCompat cluster + AppCompatConfig + DeviceLockController*; KEEP = HTMLViewer + UniversalMediaPlayer; UMP `PRODUCT_PACKAGES +=` after filter-out. GmsCompat is **not** restored via KEEP.
- `loc-excised.mk`: drop FusedLocation / gnssd / NetworkLocation / bipchmgr / wfc-pkt-router; COPY_FILES drop gnss+pkt+bip rc; PRODUCTS write-back `filter-out FusedLocation` on `PRODUCT_SYSTEM_SERVER_APPS`.
- `guardtalk-feature-excised.mk`: includes apps-excised then loc-excised.
- `GosPackageStatePermission.java`: `GmsCompatApp.PKG_NAME` log-and-return precedes `if (Build.IS_DEBUGGABLE) throw`.
- `pktrouter.rc` / `bipchmgr.rc`: comment-only; no `service` stanzas.
- `handheld_core_hardware.prebuilt.xml`: no `android.hardware.location*` `<feature>` tags.
- `SystemServer.java:2384`: `mSystemServiceManager.startService(LocationManagerService.Lifecycle.class)` still unconditional → **HOLD** (not invented as GNSS-dead).
- `vendor.prop:173`: `vendor.pktrouter=1` leftover → **HOLD** (no-op without rc; TELEMETRY file not edited).

### Stale out / `m` / adb

```
out/target/product/komodo/system/priv-app/FusedLocation  2026-09-15 05:14
adb devices: List of devices attached  (empty)
```

Stale userdebug out. QA did **not** run `m`. Not a built user image. Serial `54111FDAS000GN` not on this host. Stale APKs are **not** product truth. **Never device-fixed. PASS HOLD remains.**

## Negatives (adversarial)

| Negative | Expected | Actual | Status |
|----------|----------|--------|--------|
| userdebug leftover as product truth | FAIL if lunch is userdebug | user lunch `TARGET_BUILD_VARIANT=user` | PASS |
| GmsCompat / AppCompatConfig disabled-but-present | FAIL if still in PRODUCT_PACKAGES | ABSENT (removed, not disabled) | PASS |
| HTMLViewer / UMP dropped with GmsCompat | FAIL | both PRESENT | PASS |
| GmsCompat `IS_DEBUGGABLE` still throws | FAIL if throw precedes special-case | log-and-return first | PASS |
| service stanzas left in pkt/bip rc | FAIL | no `service` stanzas | PASS |
| invent LMS excised / GNSS-dead | forbidden | LMS start HOLD; GNSS-dead not claimed | PASS (HOLD recorded) |
| invent DeviceLock APEX gone | forbidden | APEX PRESENT HOLD | PASS (HOLD recorded) |
| trust stale out FusedLocation APK | forbidden | HOLD; not product truth | PASS (HOLD recorded) |

## Coverage gaps

- No user image (`m` not run)
- On-device GNSS / fused provider / `dumpsys location` → `Q-REMEDIATE-B2-ONDEVICE` (BLOCKED; not started)
- DeviceLock APEX BCP (`com.android.devicelock`) still ships — out of this card's filter-out (SystemServiceRegistry hard-import)
- LMS still starts (forbidden path `SystemServer.java` for T-EXCISE)
- `vendor.pktrouter=1` leftover lives in TELEMETRY vendor.prop (Q-TELEMETRY sibling; not edited here)

## Bugs found

None that fail host AC for items 8, 10, 12, 13. Expected HOLDs: LMS start, DeviceLock APEX, pktrouter prop leftover, adb/`m`/stale out.

A first-pass in-memory `PRODUCT_PACKAGES` bash word flaked UniversalMediaPlayer (token is present on disk). Suite now greps dump files. Independent dump rematch: UMP **PRESENT**.

## PQE Assessment: Code Entropy REDUCED

Location HAL + FusedLocation + GmsCompat cluster are filter-out absent (not “alive but off”). Residual entropy: LMS still starts, DeviceLock APEX still on BCP, pktrouter sysprop leftover, stale out APKs.
