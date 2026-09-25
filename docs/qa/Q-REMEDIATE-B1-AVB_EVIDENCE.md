# QA Evidence — Q-REMEDIATE-B1-AVB

**Task:** `Q-REMEDIATE-B1-AVB` (independent rematch of `T-REMEDIATE-B1-AVB` **item 4**)  
**Date:** 2026-09-16T10:51:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B1-AVB` Architect-APPROVED static wiring / green HOLD (2026-09-16T10:18:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-001  
**Verdict:** **PASS (host lunch + static)** — `BUILD_KEYS=dev-keys` **HOLD**. Signed vbmeta / lock / green **HOLD**. Item **7 HOLD**. Device **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host. No USB GO. No `fastboot flashing lock`. No commit. `Q-REMEDIATE-B1-ONDEVICE` and Block 2 Q were **not** started. Serial `54111FDAS000GN` was **not** locked.

GIP-0: loaded `.memory-bank/` (activeContext, progress, decisions, projectBrief, systemPatterns, GUARDIAN_MANDATORY) and `.aegis/governance/` laws + gates. Gate -1 in-process. Guardian MCP/HTTP not called (TOOL UNAVAILABLE).

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent `lunch komodo-trunk_staging-user` shows project AVB key path (not AOSP testkey) | **PASS** | `BOARD_AVB_KEY_PATH=vendor/guardtalk/branding/signing-keys/avb.pem` |
| 2 | `BOARD_AVB_ALGORITHM=SHA256_RSA4096`; `BOARD_AVB_ENABLE=true` | **PASS** | independent `get_build_var` |
| 3 | `test ! -f vendor/guardtalk/branding/signing-keys/avb.pem`; find pem/pk8 empty | **PASS** | file ABSENT; `find` empty; `git ls-files` empty |
| 4 | Komodo lock procedure exists (RUNBOOK §12) | **PASS** | §12 / §12c `fastboot flashing lock`; do-not-lock `54111FDAS000GN` |
| 5 | Green not claimed; yellow documented as Pixel custom-key truth | **PASS / HOLD green** | RUNBOOK §12d + POLICY + `SECURITY_FASTBOOT_PROT_REPORT.md` §4.1 |
| 6 | USB duress not flipped to default-on | **PASS / HOLD item 7** | default `"0"`; `isVerifiedBootGreen` still requires `"green"` |
| 7 | Device HOLD if adb empty; REVIEW only; never APPROVED | **HOLD / PASS** | `adb devices` header only; no lock; no APPROVED |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b1_avb_host.sh
# RESULT: PASS (host)  bash_PASS=54 bash_HOLD=5 PY_RC=0
# PY_COUNTS PASS_COUNT=10 FAIL_COUNT=0 HOLD_COUNT=0
# COMBINED: PASS_COUNT=64 HOLD_COUNT=5 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# GREEN=HOLD
# KEYS_SIGN_LOCK=HOLD
# ITEM7=HOLD
# DEVICE=HOLD
# BUILD_KEYS_POSTSIGN=HOLD (dev-keys)
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-AVB_SUITE.out`

`pytest platform/tests` N/A (AOSP BoardConfig / docs, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### Lunch (user product)

This host, this stamp (`ended_at` 2026-09-16T10:50:31Z):

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

Not `external/avb/test/data/testkey_rsa4096.pem`. AOSP Makefile still has that fallback **when unset** (`build/make/core/Makefile` ~4685–4690). User lunch sets the project path, so the fallback is not the product key.

User `PRODUCT_PACKAGES` / `PRODUCT_PACKAGES_DEBUG`: `su` / `overlay_remounter` **ABSENT** (USERBUILD not regressed).

### Sidecar adversarial (not product truth)

`lunch komodo-trunk_staging-userdebug` → `TARGET_BUILD_VARIANT=userdebug`.  
`BOARD_AVB_KEY_PATH=` (empty dumpvar) → Makefile testkey fallback at `m`.  
`BUILD_KEYS=test-keys`. Do not lock the sidecar.

### Keys

- `test ! -f vendor/guardtalk/branding/signing-keys/avb.pem` → PASS (ABSENT)
- `find vendor/guardtalk \( -name '*.pem' -o -name '*.pk8' \)` → empty
- `git ls-files` pem/pk8/avb.pem under `vendor/guardtalk` → empty
- `vendor/guardtalk/branding/signing-keys/.gitignore` covers `*.pem` `*.pk8` `avb.pem`

### Lock procedure and color

- RUNBOOK **§12** Komodo (Pixel 9 Pro XL) — T-REMEDIATE-B1-AVB
- **§12c** lock sequence includes `fastboot flash avb_custom_key` + `fastboot flashing lock`
- Production-custody serial `54111FDAS000GN` — **do not lock** without operator GO
- **§12d:** operator-goal `green` is **HOLD**. Pixel custom-key lock reports **yellow** (`SECURITY_FASTBOOT_PROT_REPORT.md` §4.1). This stamp does **not** claim green.
- POLICY Verified Boot row: custom-key color = **yellow** (HOLD vs operator-goal green)

### USB duress (item 7 still HOLD)

`UsbPortSecurityHooks.java`:

- `SystemProperties.get(USB_DURESS_WIPE_ENABLED_PROP, "0")` — default opt-in **off**
- `isVerifiedBootGreen()` still `"green".equals(ro.boot.verifiedbootstate)`
- No `vendor/guardtalk` `*.mk`/`*.prop` assigns `usb_duress_wipe.enabled=1`

Custom-key **yellow** cannot satisfy the USB `green` gate. Item 7 remains HOLD pending operator Gate 0. QA did not start USB GO.

### Device / lock

```
adb devices
List of devices attached
(empty)
```

Device HOLD. `fastboot flashing lock` **not** executed. Serial `54111FDAS000GN` **not** locked. `LIVE_DEVICE_CLAIMED=false`.

## Adversarial rematch

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| user lunch path is AOSP `testkey_rsa4096.pem` | fail | project `avb.pem` path | PASS |
| empty user `BOARD_AVB_KEY_PATH` (silent testkey fallback) | fail | path set | PASS |
| `avb.pem` present on host / in git | fail | ABSENT; git empty | PASS |
| sidecar inherits project AVB path | fail (user-gate broken) | empty dumpvar | PASS |
| RUNBOOK/POLICY claim custom-key **is** green | fail (Law 7) | yellow documented; green HOLD | PASS |
| PRODUCT-force `verifiedbootstate=green` | fail | absent in komodo device tree | PASS |
| USB default `"1"` / product `enabled=1` | fail | still `"0"`; no mk assign | PASS |
| empty adb → device-fixed / lock / green | forbidden | HOLD | PASS (HOLD) |

## Coverage gaps

- `m` not run; no signed `vbmeta.img` / `avb_pkmd.bin` this stamp
- No live `fastboot flashing lock` / no `getprop ro.boot.verifiedbootstate`
- `Q-REMEDIATE-B1-ONDEVICE` still BLOCKED (not started)
- Block 2 Q not started
- Residual: `vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md` still has older tokay language that treats custom-key lock as green. **Not** a FAIL of this card’s T-REMEDIATE files (RUNBOOK/POLICY/late mk). Architect follow-on if desired.

## Bugs found

None that fail host AC for item 4. Expected HOLDs recorded. Green not invented.

## Regression status

- Product makefiles / USB Java: **not edited by QA**
- `doctrine/` / `governance/laws/` / `governance/gates/`: **untouched**
- Tests modified/deleted: **NONE**
- Pre-existing pytest: N/A
