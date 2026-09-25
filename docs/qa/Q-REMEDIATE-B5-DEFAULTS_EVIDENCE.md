# QA Evidence — Q-REMEDIATE-B5-DEFAULTS

**Task:** `Q-REMEDIATE-B5-DEFAULTS` (independent rematch of `T-REMEDIATE-B5-DEFAULTS` item **24**)
**Date:** 2026-09-16T13:55:04Z
**Agent:** QA_ENGINEER (Panel 4)
**Depends:** `T-REMEDIATE-B5-DEFAULTS` Architect-APPROVED static (2026-09-16T13:40:00Z) — **not trusted**
**DEC:** DEC-REMEDIATE-002
**Verdict:** **PASS (host lunch + static)** — stale `out/` **HOLD**. Unlocked MTP (`getChargingFunctions`) **HOLD**. adb/`m` **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). PASS HOLD remains.

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host. No USB GO. No wipe. No commit. `Q-ONDEVICE` **not** started.

GIP-0: loaded `.memory-bank/activeContext.md` (read-only) and `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Gate -1 in-process. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not** called (forbidden this dispatch). Memory-bank **not** written (dispatch).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent `lunch komodo-trunk_staging-user` | **PASS** | EXIT 0; `TARGET_PRODUCT=komodo` `TARGET_BUILD_VARIANT=user` `TARGET_BUILD_TYPE=release` |
| 2 | `ro.com.android.dataroaming=false` on user lunch | **PASS** | `PRODUCT_PROPERTY_OVERRIDES`; `=true` ABSENT from komodo vendor + user dump |
| 3 | `persist.sys.usb.config=none` (not mtp) on user | **PASS** | user lunch + user-gated mk + vendor init `ro.debuggable=0` |
| 4 | `persist.sys.bug_report=0` on user | **PASS** | user lunch + vendor init |
| 5 | `GuardTalkSettingsProviderOverlay` PRESENT | **PASS** | user `PRODUCT_PACKAGES` file dump 35244 bytes; Soong + static overlay |
| 6 | Overlay `def_lock_screen_show_notifications=0` | **PASS** | `defaults.xml` integer 0 (not 1) |
| 7 | Overlay `def_usb_mass_storage_enabled=false` | **PASS** | `defaults.xml` bool false (not true) |
| 8 | `persist.radio.disabled=1` kept | **PASS** | radio-excised assignment; defaults.mk does not rewrite; user lunch still has it |
| 9 | Stale `out/` props contradict lunch | **HOLD** (not FAIL) | `out/target/product/komodo/product/etc/build.prop` still `ro.com.android.dataroaming=true` |
| 10 | Unlocked MTP impossible | **HOLD** (forbidden claim) | `UsbDeviceManager.getChargingFunctions()` still `return UsbManager.FUNCTION_MTP` when unlocked and ADB off |
| 11 | `adb devices` empty → device | **HOLD** | empty list; serial `54111FDAS000GN` absent; never device-fixed |
| 12 | Status REVIEW only; never APPROVED; no commit | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b5_defaults_host.sh
# RESULT: PASS (host)  bash_PASS=52 bash_HOLD=5 PY_RC=0
# PY_COUNTS PASS_COUNT=16 FAIL_COUNT=0 HOLD_COUNT=1
# LIVE_DEVICE_CLAIMED=false
# STALE_OUT=HOLD MTP_UNLOCKED=HOLD DEVICE=HOLD
# PASS_HOLD=remains
# EXIT=0
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B5-DEFAULTS_SUITE.out`

`pytest platform/tests` N/A (AOSP product mk / overlay / vendor init, not AEGIS Python platform).

Session-only `GIT_CONFIG_*` for `vendor/adevtool`. Did **not** `set -u` around `envsetup`/`lunch`.

## Independent rematch (do not trust T / Architect dumps)

### Lunch (user product)

This host, this stamp:

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
TARGET_BUILD_TYPE=release
ro.com.android.dataroaming=false
persist.sys.usb.config=none
persist.sys.bug_report=0
persist.radio.disabled=1
GuardTalkSettingsProviderOverlay PRESENT
init.guardtalk.defaults.rc in PRODUCT_COPY_FILES
su / overlay_remounter ABSENT
```

### Sidecar adversarial (not product truth)

`lunch komodo-trunk_staging-userdebug` → `TARGET_BUILD_VARIANT=userdebug`. Sidecar keeps `dataroaming=false` (all-variant). Sidecar does **not** set `persist.sys.usb.config=none` or `persist.sys.bug_report=0` (user-only; keeps AOSP adb).

### Static wiring

- `guardtalk-defaults.mk` included from `guardtalk-production-hardening.mk`.
- User-gated `persist.sys.usb.config=none` / `persist.sys.bug_report=0`.
- Overlay platform-signed product RRO on `com.android.providers.settings`.
- `init.guardtalk.defaults.rc` is setprop-only on `post-fs-data && ro.debuggable=0`; does not start RIL.
- USERBUILD cert/AVB/su not rewritten by defaults.mk.
- `persist.security.usb_mode` not assigned in defaults.mk.

### Stale out / frameworks / device

- Stale `out/.../product/etc/build.prop` still `ro.com.android.dataroaming=true` — **HOLD**, not product FAIL (`m` not run).
- `getChargingFunctions()` still returns MTP when unlocked with ADB off — frameworks **HOLD**; do not claim MTP impossible when unlocked.
- `adb devices`: empty → device **HOLD**.

## Harness note (not a product FAIL)

An earlier `script | tee` capture of `PRODUCT_PACKAGES` via `$()` reported overlay ABSENT. Independent file dump of the same lunch var is 35244 bytes and contains `GuardTalkSettingsProviderOverlay` (word match). The suite of record uses file redirect. First false ABSENT is **harness**, not item 24 FAIL.

## Coverage gaps

- `m` not run; on-device first-boot SettingsProvider defaults unproven.
- Unlocked charging-function MTP path is frameworks, out of this card.
- Live USB gadget / lock-screen notification UI → on-device card after user image.
