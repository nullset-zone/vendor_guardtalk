# QA Evidence — Q-FLASH-CLI-HARDEN

**Task:** `Q-FLASH-CLI-HARDEN` (independent rematch of `flash-from-remote.sh` harden + golden-file prefix)  
**Date:** 2026-09-16T06:20:13Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-FLASH-CLI-HARDEN` ✅ APPROVED (Architect 2026-09-16T06:25:00Z)  
**Verdict:** **PASS (static / host)** — USB flash **HOLD**. Overlay **HOLD**. **Not FLASH live GO.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend report was not trusted. Product scripts were not edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Both `flash-from-remote.sh` `cmp` identical | PASS | `cmp -s` EXIT=0; SHA `9d3b1e41c81bbccd15e0d2f17438e046afc682dcc64d391e19e26c9dba3ee8b6` |
| 2 | `bash -n` both copies | PASS | both EXIT=0 |
| 3 | `avb_custom_key` flash failure → `die` unless `ALLOW_AVB_KEY_FAIL=1` | PASS | fake-fastboot fail: ALLOW unset dies; `=1` continues (L690–701) |
| 4 | fastboot `< 35.0.1` dies | PASS | 35.0.1/36.0.0/35.0.2 accept; 35.0.0/34.0.5/35.0/unparseable/empty die. GOS `MIN_FASTBOOT_VERSION_STR="35.0.1"` (`device/common/generate-factory-images-common.sh` L98) |
| 5 | `REMOTE_BUILD_DIR` metacharacters rejected before ssh | PASS | `' " $ \ newline` + non-absolute die with empty ssh log; clean `/tmp/gt-qa-harden-tree/ok` reaches stub ssh |
| 6 | tokay\|akita\|komodo still erase fips | PASS | cleanup runtime log has `erase fips`; source L364 inside `tokay\|akita\|komodo` |
| 7 | rango no fips | PASS | rango cleanup uart+dpm only; `script/generate-release.sh` rango family has no `DISABLE_FIPS` |
| 8 | rescue still rango-only | PASS | production call L963 inside `FLASH_DEVICE == rango`; Pixel 9 else-branch has no `flash_rango_rescue_boot_chain` |
| 9 | no flashing lock as default | PASS | `grep flashing lock` empty |
| 10 | no `update image.zip` as default | PASS | no `--skip-reboot update` / `update image-` in CLI |
| 11 | dead inner `avb_pkmd.bin` branch gone; optional super/diag skip-ok | PASS | sibling `elif` L650; optional skip-ok L647–649 |
| 12 | golden-file prefix vs `generate-factory-images-common.sh` | PASS | tokay/akita/komodo/rango MATCH prefix (bootloader dance, radio, avb, uart, fips\|no-fips, dpm). GOS `update` sits after dpm (L267) — documented GuardTalk delta |
| 13 | USB / overlay | **HOLD** | `adb devices` empty; no browser overlay |

## Static script (suite of record)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_flash_cli_harden_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=43 HOLD_COUNT=2 FAIL=0 EXIT=0
```

Host cmp / `bash -n` / extracted-function fake-fastboot is the suite. `pytest platform/tests` N/A (AOSP flash CLI card, not AEGIS Python platform).

## Independent rematch (do not trust engineer report)

### KEEP identity

```text
cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh  → EXIT=0
bash -n scripts/flash-from-remote.sh                                          → 0
bash -n vendor/guardtalk/scripts/flash-from-remote.sh                         → 0
SHA256 both = 9d3b1e41c81bbccd15e0d2f17438e046afc682dcc64d391e19e26c9dba3ee8b6
```

### Harden line pins (root copy; vendor identical)

| Check | Lines |
|-------|-------|
| `ALLOW_AVB_KEY_FAIL=1` documented | 47 |
| `require_fastboot_min_version` | 115–132 |
| `REMOTE_BUILD_DIR` newline / `' " $ \` reject before ssh | 259–266 |
| optional `super.img` / `vendor_boot_diag.img` skip-ok | 647–649 |
| required `avb_pkmd.bin` elif (not nested) | 650–652 |
| `avb_custom_key` fail → die unless ALLOW | 690–701 |
| `erase fips` tokay\|akita\|komodo | 364 |
| rango cleanup (no fips) | 350–358 |
| production rescue | 958–963 |

### Golden-file prefix (normalized fastboot argv; image paths dropped)

Documented GOS unix `flash-all.sh` prefix from `device/common/generate-factory-images-common.sh` with flags from `script/generate-release.sh`:

```text
flash --slot=other bootloader
--set-active=other
reboot-bootloader
flash --slot=other bootloader
--set-active=other
reboot-bootloader
flash radio
reboot-bootloader
erase avb_custom_key
flash avb_custom_key
oem uart disable
erase fips          # tokay | akita | komodo only (DISABLE_FIPS)
erase dpm_a
erase dpm_b
```

Generator cites: bootloader dance L193–208; radio L213–216; avb L229–230; uart L236; fips L256; dpm L262–263. `fastboot -w --skip-reboot update image-$PRODUCT-$VERSION.zip` is L267 **after** this prefix. GuardTalk does **not** clone it (DEC-RANGO-REMEDIATE-001 / forbidden this wave).

Extracted Step-2 functions (`flash_bootloader_ab_both_slots` + radio + avb snippet + `apply_grapheneos_firmware_cleanup`) dumped against a logging fake-fastboot. **tokay, akita, komodo, rango all MATCH** the prefix above (rango omits `erase fips`).

### Adversarial

| Test | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| fastboot 35.0.1 | `fastboot version 35.0.1-qa` | accept | accept | PASS |
| fastboot 35.0.0 | `35.0.0` | die | die | PASS |
| fastboot 35.0 (no patch) | `35.0` | die (patch 0) | die | PASS |
| fastboot unparseable | `fastboot: unknown` | die | die | PASS |
| empty version | empty stdout | die | die | PASS |
| avb fail, ALLOW unset | flash avb_custom_key rc=1 | die | die | PASS |
| avb fail, ALLOW=1 | same + env | continue | continue | PASS |
| REMOTE_BUILD_DIR `'` `"` `$` `\` newline | those paths | die before ssh | die, ssh log empty | PASS |
| REMOTE_BUILD_DIR relative | `relative/no/slash` | die | die | PASS |
| clean path | `/tmp/gt-qa-harden-tree/ok` | ssh reached | stub ssh logged | PASS |

### USB / overlay

```text
adb devices → header only (no device)
fastboot not used against hardware (PATH stub only)
overlay HOLD — no host browser this card
```

## Coverage gaps

- No live USB flash (dispatch: USB HOLD). Do not invent PASS.
- Web-installer overlay not exercised (HOLD).
- `auto_harvest_on_failure` still allows akita\|rango for pstore pull (L865). Production fastbootd rescue remains rango-only (L958–963). Not a harden FAIL.
- `ALLOW_AVB_KEY_FAIL=1` remains an explicit operator opt-out (task-required). Default is die.
- Sanitizer rejects `' " $ \` and newline only (MEDIUM-4 spec). Semicolon/space are literal inside the single-quoted ssh remote and were not required to die.
- HIGH-1 GOS `flashing lock` / MEDIUM-2 `update image.zip` remain absent **by design**.

## Bugs found

None that fail this card’s acceptance.

## Regression status

- tokay\|akita\|komodo still `erase fips`
- rango still no fips
- rescue production path still rango-only
- no `flashing lock`; no `update image.zip`
- Tests modified/deleted: **NONE** (host suite **added**)
- Product implementation: **not edited**

## Governance

GIP-0 VERIFIED: Loaded `.memory-bank/activeContext.md`, `progress.md` (tail), `decisions.md` (DEC-RANGO-REMEDIATE-001), `systemPatterns.md`, Gate -1 YAML, `AGENTS.md` laws/gates, `.agent-comm/PROTOCOL.md` + `ROLES.md` Agent 4. Governance acknowledged. Guardian MCP / HTTP: **not called** (Gate -1 in-process; dispatch no USB).
