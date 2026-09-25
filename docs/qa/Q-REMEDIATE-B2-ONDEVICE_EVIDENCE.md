# QA Evidence — Q-REMEDIATE-B2-ONDEVICE

**Task:** `Q-REMEDIATE-B2-ONDEVICE` (independent on-device probe of Block 2 PASS HOLD lift)  
**Date:** 2026-09-16T14:31:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-003  
**Depends:** `T-REMEDIATE-B2-EXCISE` / `T-REMEDIATE-B2-KERNEL` / `T-REMEDIATE-B2-TELEMETRY` Architect-APPROVED static — **not trusted**  
**Sibling:** `Q-REMEDIATE-B1-ONDEVICE` (do **not** wait)  
**Serial:** `54111FDAS000GN`  
**Verdict:** **HOLD REVIEW** — `adb devices -l` empty. Named unit absent. Live Block 2 **not proven**. **PASS HOLD remains.** Not device-fixed. Status → **REVIEW** (never APPROVED). Empty adb = successful HOLD delivery.

Independent probe. Architect APPROVE of Block 2 T cards was **not trusted**. Product source was not edited (QA docs only). No USB GO. No flash. No lock. No wipe. No `m`. No commit. Sibling B1 not waited. Memory-bank **not edited**. Derived `.agent-comm/TASK_QUEUE.md` **not edited**.

GIP-0: loaded `.aegis/governance/` (24 laws + 11 gates). Gate -1 in-process from local YAML. Guardian MCP/HTTP / `aegis-verifier` / `ask_guardian` / `gate_enforcer` **not called**. Gate 5 HUMAN SKIP.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Probe `adb devices -l` first | **PASS** (process) | `/usr/bin/adb`; header only; artifact written |
| 2 | Named serial `54111FDAS000GN` present | **HOLD** | absent; `NAMED_STATE=absent` `ADB_EMPTY=true` |
| 3 | If empty / wrong serial: HOLD REVIEW | **PASS** (HOLD path) | empty-adb path taken; did not invent live |
| 4 | User image (`ro.build.type=user`, `ro.debuggable=0`) | **HOLD** | not read (no device) |
| 5 | If still userdebug: HOLD; do not lift PASS HOLD | **HOLD** | image class unknown; PASS HOLD not lifted |
| 6 | Location / GmsCompat packages absent | **HOLD** | `pm list packages` not run |
| 7 | `/proc/sys` paranoid / yama / bpf (documented HOLDs allowed) | **HOLD** | sysctls not read; YAMA live Image remains static HOLD |
| 8 | No persistent logs / `/data` vendor log dirs | **HOLD** | telemetry props not read |
| 9 | pktrouter / BIP not restarting | **HOLD** | ps / init.svc not read |
| 10 | Empty device-admins | **HOLD** | `dumpsys device_policy` not run; DeviceLock APEX static HOLD |
| 11 | EXIF no make/model | **HOLD** | no shutter; property not read |
| 12 | REVIEW only; never APPROVED; no USB GO / flash / lock / wipe / `m`; PASS HOLD remains | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b2_ondevice.sh
# RESULT: HOLD (documented)  PASS_COUNT=12 HOLD_COUNT=14 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# ADB_EMPTY=true
# NAMED_STATE=absent
# BUILD_TYPE=unknown
# USER_IMAGE=false
# PASS_HOLD=remains
# USB_GO=not started
# Q_B1_ONDEVICE=not waited
# GNSS_DEAD_ONDEVICE=HOLD PROC_SYS=HOLD EXIF=HOLD LOGS=HOLD
# PKT_BIP=HOLD DEVICE_ADMINS=HOLD USERDEBUG_OR_EMPTY=HOLD
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-ONDEVICE_SUITE.out`  
Artifact: `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B2-ONDEVICE_adb_devices_-l.txt`

`pytest platform/tests` N/A (on-device adb probe, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### adb

This host, this stamp:

```
adb devices -l
List of devices attached
```

`adb` binary: `/usr/bin/adb`. Serial `54111FDAS000GN` **absent**. No unauthorized/offline row. No wrong-serial unit. Empty list is the documented HOLD delivery, not a suite failure.

### User vs userdebug

Not classified. `ro.build.type` / `ro.debuggable` / fingerprint **not read**. Do not invent `user`. Do not treat the 2026-09-15 stale userdebug `out/` as a flashed image. Audit bind fingerprint remains the PASS HOLD unit (`userdebug/test-keys`) until a **user** image is on this serial.

### Block 2 live checks (all HOLD)

| Probe | Why HOLD |
|-------|----------|
| Location / FusedLocation / gnssd / GmsCompat / AppCompatConfig | no `pm list packages` |
| GNSS-dead / `dumpsys location` | LMS start is a documented **static** HOLD; live GNSS-dead **not claimed** |
| `perf_event_paranoid` | `/proc/sys` not readable without the unit |
| `yama/ptrace_scope` | documented YAMA live `Image.lz4` HOLD (`__lsm_yama` ABSENT on static rematch) |
| `unprivileged_bpf_disabled` | boot_completed write not rematched live |
| silentlog / logpersistd / `/data/vendor/slog` | no shell; no `adb root` |
| pktrouter / BIP restart | no `ps` / `init.svc.*` |
| device-admins / DeviceLockController | no `dpm`; `com.android.devicelock` APEX remains static HOLD |
| Photo EXIF make/model | no capture; property not read |

### Forbidden actions (not taken)

USB GO, flash, lock, wipe, `m`, git commit, APPROVED, live, PASS HOLD lift: **not started**. Sibling `Q-REMEDIATE-B1-ONDEVICE` **not waited**.

## Negatives (adversarial)

| Negative | Expected | Actual | Status |
|----------|----------|--------|--------|
| empty adb → invent live Block 2 PASS | forbidden | HOLD REVIEW | PASS (HOLD recorded) |
| lift PASS HOLD on empty / userdebug | forbidden | PASS HOLD remains | PASS |
| treat stale userdebug `out/` as flashed user image | forbidden | image class unknown HOLD | PASS (HOLD) |
| invent GNSS-dead | forbidden | GNSS-dead HOLD | PASS (HOLD) |
| invent `__lsm_yama` / sysctl 2/1/1 live | forbidden | /proc/sys HOLD; YAMA Image static HOLD | PASS (HOLD) |
| invent EXIF stripped on a photo | forbidden | no shutter | PASS (HOLD) |
| USB GO / flash / lock / wipe / `m` | forbidden | not started | PASS |
| wait for Q-B1-ONDEVICE | forbidden | not waited | PASS |
| claim APPROVED | forbidden | REVIEW only | PASS |

## Coverage gaps

- Named unit not attached; all live Block 2 probes remain HOLD
- No flashed **user** image on `54111FDAS000GN` this stamp
- YAMA compile-time / `__lsm_yama` still a static KERNEL HOLD
- LMS still starts (static EXCISE HOLD); DeviceLock APEX still on BCP (static HOLD)
- Stale `out/vendor/build.prop` Pixel log/EXIF defaults until rebuild (TELEMETRY HOLD)
- Photo EXIF bytes require operator-present capture on a user image
- PASS HOLD lift requires **both** Q-B1-ONDEVICE and this card on a **user** image — neither is live this stamp

## Bugs found

None. Empty adb is the documented successful HOLD delivery (EXIT 0). Device not claimed fixed.

## PQE Assessment: Code Entropy UNCHANGED (live)

No live Block 2 proof. Residual entropy is the unflashed / unattached unit. Host-static Block 2 cards remain separately APPROVED static; this probe does not convert them into device-fixed.
