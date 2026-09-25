# QA Evidence — Q-REMEDIATE-B1-USERBUILD

**Task:** `Q-REMEDIATE-B1-USERBUILD` (independent rematch of `T-REMEDIATE-B1-USERBUILD` items **1, 2, 3, 5**)  
**Date:** 2026-09-16T10:12:21Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B1-USERBUILD` Architect-APPROVED static (2026-09-16T10:02:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-001  
**Verdict:** **PASS (host lunch + static)** — live SPL **HOLD** (`2026-02-05`). `BUILD_KEYS=dev-keys` **HOLD**. xbin/`m`/adb **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host. No USB GO. No wipe. No commit. `Q-REMEDIATE-B1-ONDEVICE`, `Q-AVB`, and Block 2 Q were **not** started.

GIP-0: loaded `.memory-bank/` (activeContext, progress, decisions, projectBrief, systemPatterns) and `.aegis/governance/` laws + gates. Gate -1 in-process. Guardian MCP/HTTP not called (TOOL UNAVAILABLE).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent `lunch komodo-trunk_staging-user` → `TARGET_BUILD_VARIANT=user` | **PASS** | lunch banner + `get_build_var` = `user` (not userdebug) |
| 2 | `TARGET_BUILD_TYPE=release`; `TARGET_PRODUCT=komodo` | **PASS** | `get_build_var` |
| 3 | `su` / `overlay_remounter` absent from user `PRODUCT_PACKAGES` and `PRODUCT_PACKAGES_DEBUG` | **PASS** | both dumps ABSENT; late filter user-gated |
| 4 | `ro.adb.secure=1` product wiring on user (komodo harden mk) | **PASS** | user-block override + AOSP user map; debug_ramdisk `0` not product |
| 5 | `PRODUCT_DEFAULT_DEV_CERTIFICATE` is releasekey stem (not testkey) | **PASS** | `vendor/guardtalk/branding/signing-keys/releasekey` |
| 6 | `BUILD_KEYS=dev-keys` until post-sign | **HOLD** (not FAIL) | unsigned lunch; not `test-keys` |
| 7 | SPL pin of record documented; live `PLATFORM_SECURITY_PATCH` honest | **HOLD** | pin `2026-09-05`; live `2026-02-05`; flag file still `2026-02-05` |
| 8 | No `*.pem` / `*.pk8` under `vendor/guardtalk` | **PASS** | `find` empty |
| 9 | Device / xbin / `m` HOLD if not a built user image / adb empty | **HOLD** | stale xbin 2026-09-15; `m` not run; adb empty |
| 10 | Status REVIEW only; never APPROVED; no commit | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b1_userbuild_host.sh
# RESULT: PASS (host)  bash_PASS=47 bash_HOLD=6 PY_RC=0
# PY_COUNTS PASS_COUNT=20 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=67 HOLD_COUNT=6 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# ITEM5_LIVE_SPL=HOLD (2026-02-05; pin 2026-09-05)
# BUILD_KEYS_POSTSIGN=HOLD (dev-keys)
# XBIN_M=HOLD DEVICE=HOLD
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-USERBUILD_SUITE.out`

`pytest platform/tests` N/A (AOSP product mk, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### Lunch (user product)

This host, this stamp:

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
TARGET_BUILD_TYPE=release
PRODUCT_DEFAULT_DEV_CERTIFICATE=vendor/guardtalk/branding/signing-keys/releasekey
PLATFORM_SECURITY_PATCH=2026-02-05
BUILD_KEYS=dev-keys
```

`cmds-for-envsetup.sh` still `unset PLATFORM_SECURITY_PATCH_komodo`. Lunch banner also prints `PLATFORM_SECURITY_PATCH=2026-02-05`.

User `PRODUCT_PACKAGES` and `PRODUCT_PACKAGES_DEBUG`: `su` and `overlay_remounter` **ABSENT**.

`PRODUCT_PROPERTY_OVERRIDES` contains `ro.adb.secure=1` and does **not** contain `ro.adb.secure=0` or a `ro.debuggable=` PRODUCT force.

### Sidecar adversarial (not product truth)

`lunch komodo-trunk_staging-userdebug` → `TARGET_BUILD_VARIANT=userdebug`. Sidecar `PRODUCT_PACKAGES_DEBUG` still has `su` / `overlay_remounter`. That leftover is **not** the production lunch. Sidecar `PRODUCT_DEFAULT_DEV_CERTIFICATE` was empty this dump (AOSP default path; not claimed as product cert).

### Static wiring

- `vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk`: user-gated `ro.adb.secure=1` + releasekey stem; `GUARDTALK_SPL_PIN := 2026-09-05`; no `PLATFORM_SECURITY_PATCH :=`; no PRODUCT `ro.debuggable`; no `su` package add.
- `vendor/guardtalk/feature-excised/userbuild-excised.mk`: user-gated `filter-out` of `su` `overlay_remounter` from `PRODUCT_PACKAGES` and `PRODUCT_PACKAGES_DEBUG`.
- `product-config-late.mk` includes `userbuild-excised.mk` after `guardtalk-feature-excised.mk`.
- `guardtalk-radio-excised.mk` includes per-device harden mk (`$(PRODUCT_DEVICE)`; komodo file wins).
- AOSP `build/soong/scripts/gen_build_prop.py`: user → `ro.adb.secure=1` and `enable_target_debugging = False` → `ro.debuggable=0`.
- `system/core/rootdir/adb_debug.prop.in`: `ro.adb.secure=0` under `/force_debuggable` ramdisk — **not** user product truth.
- `build/release/flag_values/trunk_staging/RELEASE_PLATFORM_SECURITY_PATCH.textproto` still `string_value: "2026-02-05"`.

### SPL (item 5)

| Layer | Value | Status |
|-------|-------|--------|
| Pin of record `GUARDTALK_SPL_PIN` | `2026-09-05` | documented (`SPL_PIN.md` + harden mk); bulletin URLs present |
| Live `get_build_var PLATFORM_SECURITY_PATCH` | `2026-02-05` | **HOLD** (expected; `build/release/` out of USERBUILD target paths) |
| Invent live `2026-09-05` | forbidden | **not claimed** |

Bulletin URLs of record (docs, not re-fetched as a live bulletin parse this stamp):

- https://source.android.com/docs/security/bulletin/2026/2026-09-01
- https://source.android.com/docs/security/bulletin/pixel/2026/2026-09-01

### xbin / `m` / adb

```
out/target/product/komodo/system/xbin/overlay_remounter  2026-09-15 04:58
out/target/product/komodo/system/xbin/su                 2026-09-15 04:58
adb devices: List of devices attached  (empty)
```

Stale userdebug out. QA did **not** run `m`. Not a built user image. Serial `54111FDAS000GN` not on this host. **Never device-fixed. PASS HOLD remains.**

## Negatives (adversarial)

| Negative | Expected | Actual | Status |
|----------|----------|--------|--------|
| userdebug leftover as product truth | FAIL if lunch is userdebug | user lunch `TARGET_BUILD_VARIANT=user`; sidecar is separate | PASS |
| silent ADB (`ro.adb.secure=0` as product) | FAIL | product user override `=1`; debug_ramdisk `0` not treated as product | PASS |
| test-keys as product cert stem | FAIL | releasekey stem; `BUILD_KEYS=dev-keys` HOLD not FAIL | PASS |
| claim live SPL `2026-09-05` | FAIL | live `get_build_var` is `2026-02-05` | PASS (HOLD recorded) |

## Coverage gaps

- No user image (`m` not run)
- On-device props (`ro.build.type`, `ro.debuggable`, ADB RSA prompt) → `Q-REMEDIATE-B1-ONDEVICE` (BLOCKED)
- AVB green / lock → `Q-REMEDIATE-B1-AVB` (BLOCKED; not started)
- Sidecar `BUILD_KEYS` not dumped (cert stem empty; not product)
- Bulletin pages not re-fetched over the network this stamp (pin + flag file rematched)

## Bugs found

None that fail host AC for items 1, 2, 3, 5. Expected HOLDs: live SPL, post-sign keys, xbin/`m`, adb.

## PQE Assessment: Code Entropy REDUCED

Production lunch is explicit `user`; su/overlay cannot ride `PRODUCT_PACKAGES_DEBUG` onto that variant; SPL lie avoided by documenting pin vs live flag. Residual entropy: unsigned `dev-keys`, stale xbin, empty adb.
