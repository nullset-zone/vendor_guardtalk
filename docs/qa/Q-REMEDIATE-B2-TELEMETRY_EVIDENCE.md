# QA Evidence — Q-REMEDIATE-B2-TELEMETRY

**Task:** `Q-REMEDIATE-B2-TELEMETRY` (independent rematch of `T-REMEDIATE-B2-TELEMETRY` items **11, 14**)  
**Date:** 2026-09-16T12:39:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B2-TELEMETRY` Architect-APPROVED static (2026-09-16T12:19:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-001  
**Verdict:** **PASS (host static + user lunch)** — stale `out/target/product/komodo/vendor/build.prop` **HOLD** (Pixel `true`/`On`/`log_mask=3` until rebuild). On-device photo EXIF **HOLD**. Runtime `/data` log dirs **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host. Stale `out/.../vendor/build.prop` was **not** treated as PASS or FAIL of this card. No USB GO. No wipe. No `m`. No commit. `Q-REMEDIATE-B2-ONDEVICE` / Block 3 / USB GO / item 7 were **not** started.

GIP-0: loaded `.memory-bank/` (activeContext, progress, decisions, projectBrief, systemPatterns) and AGENTS.md + PROTOCOL/ROLES + `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Gate -1 in-process. Guardian MCP/HTTP not called (TOOL UNAVAILABLE). Gate 5 HUMAN SKIP.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | silentlog / logpersistd / persistent vendor logs not enabled on production user (source + user lunch) | **PASS** | vendor.prop `silentlog.tcp=Off`, `modem.logging.enable=false`, `ril.log_mask=0`; telemetry.mk user filter + `logd.logpersistd.enable=false`; user lunch packages ABSENT |
| 2 | Runtime `/data` logs | **HOLD** | adb empty; Q-ONDEVICE BLOCKED |
| 3 | `persist.vendor.camera.exif_reveal_make_model=false` in vendor.prop + overlay | **PASS** | vendor.prop line 55; telemetry.rc `setprop … false`; harden mk includes overlay |
| 4 | On-device photo EXIF | **HOLD** | Q-REMEDIATE-B2-ONDEVICE BLOCKED |
| 5 | `logpersist.start` and `logcatd` ABSENT from user `PRODUCT_PACKAGES`; `logd.logpersistd.enable=false` in `PRODUCT_PROPERTY_OVERRIDES` | **PASS** | independent `lunch komodo-trunk_staging-user` + `get_build_var` |
| 6 | `persist.radio.disabled=1` still set (RIL not re-enabled) | **PASS** | radio-excised.mk + user `PRODUCT_PROPERTY_OVERRIDES`; no `=0` in mk/rc/prop/bp |
| 7 | Stale `out/vendor/build.prop` not FAIL or PASS of this card | **HOLD** | still Pixel `true`/`On`/`log_mask=3`; not SoT |
| 8 | Status REVIEW only; never APPROVED; no commit; not device-fixed; PASS HOLD remains | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b2_telemetry_host.sh
# RESULT: PASS (host)  bash_PASS=47 bash_HOLD=5 PY_RC=0
# PY_COUNTS PASS_COUNT=25 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=72 HOLD_COUNT=5 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# STALE_OUT_VENDOR_BUILD_PROP=HOLD (Pixel true/On/log_mask=3)
# ONDEVICE_EXIF=HOLD
# DATA_LOG_DIRS=HOLD
# DEVICE=HOLD
# PASS_HOLD=remains
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-TELEMETRY_SUITE.out`

`pytest platform/tests` N/A (AOSP product mk / vendor.prop / init rc, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### Lunch (user product)

This host, this stamp:

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
```

User `PRODUCT_PACKAGES`: `logpersist.start` and `logcatd` **ABSENT**.  
`PRODUCT_PROPERTY_OVERRIDES` contains `logd.logpersistd.enable=false` and `persist.radio.disabled=1`.  
Does **not** contain `logd.logpersistd.enable=true` or `persist.radio.disabled=0`.  
`PRODUCT_COPY_FILES` includes `init.guardtalk.telemetry.rc`.

### Sidecar adversarial (not product truth)

`lunch komodo-trunk_staging-userdebug` → `TARGET_BUILD_VARIANT=userdebug`. Sidecar `PRODUCT_PACKAGES` still has `logpersist.start` / `logcatd`. That leftover is **not** the production lunch.

### Static source of record

- `vendor/google_devices/komodo/sysprop/vendor.prop`: `exif_reveal_make_model=false`; `silentlog.tcp=Off`; `modem.logging.enable=false`; `ril.log_mask=0`. Pixel `true`/`On`/`3` **ABSENT** from this file.
- `vendor/guardtalk/device/komodo/guardtalk-telemetry.mk`: included from `guardtalk-production-hardening.mk`; copies vendor init rc; `logd.logpersistd.enable=false`; user-gated `filter-out logpersist.start logcatd`. Does **not** `PRODUCT_PROPERTY_OVERRIDES` vendor.prop keys (duplicate sysprop would break `post_process_props.py`).
- `vendor/guardtalk/device/komodo/init.guardtalk.telemetry.rc`: `on post-fs-data` re-asserts EXIF false / silentlog Off / modem logging false / ril mask 0 / logpersistd enable false / clears `persist.logd.logpersistd`. Does **not** write `persist.radio.disabled`.
- `vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk`: `persist.radio.disabled=1` remains.
- `init.guardtalk.hardening.rc` and `apps-excised.mk`: **no** telemetry bleed (this card did not edit KERNEL/EXCISE files).

### Stale out/ (not product truth)

`out/target/product/komodo/vendor/build.prop` still:

```
persist.vendor.camera.exif_reveal_make_model=true
persist.vendor.ril.log_mask=3
persist.vendor.sys.modem.logging.enable=true
persist.vendor.sys.silentlog.tcp=On
```

**HOLD until rebuild.** Not FAIL. Not PASS. QA did not run `m`.

### Device

`adb devices` header only (empty). Serial `54111FDAS000GN` not attached. On-device EXIF and `/data` vendor log dirs **HOLD**. Never device-fixed. `Q-REMEDIATE-B2-ONDEVICE` not started.

## Residuals (not FAIL of this rematch)

- `ro.vendor.sys.modem.logging.loc=/data/vendor/slog` and `persist.vendor.ril.log.base_dir=/data/vendor/radio/sit-ril` still in vendor.prop (path leftovers; enable/mask off). Runtime emptiness **HOLD**.
- `persist.vendor.sys.modem.logging.br_num=5` still present.
- userdebug sidecar still packages `logpersist.start` / `logcatd` (documented leftover; not this product).
- First suite run FAILed `forbid_re persist.radio.disabled=0` against all of `vendor/guardtalk` because the suite/docs themselves mention the forbidden pattern. Tightened to mk/rc/prop/bp. Product assignment remains `=1` only. Not a RIL re-enable.

## Bugs found

None on host static + user lunch for items 11 and 14.

## Coverage gaps

- On-device photo EXIF make/model (Q-ONDEVICE).
- Runtime `/data/vendor/slog`, `/data/vendor/radio/sit-ril`, logpersist dirs after boot.
- Rebuilt `out/.../vendor/build.prop` after `m` (stale Pixel defaults until then).
