# QA Evidence — Q-REMEDIATE-DEBUG-PACK-HONESTY

**Task:** `Q-REMEDIATE-DEBUG-PACK-HONESTY` (pair of `F-REMEDIATE-DEBUG-PACK-HONESTY` **APPROVED**)  
**Date:** 2026-09-18T19:05:49Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-017  
**Depends:** `grapheneos-worktree::F-REMEDIATE-DEBUG-PACK-HONESTY` APPROVED  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. **DEBUG_FLASH_READY=false** (not lifted). **FLASH_READY=false**. **LIVE_FLASH_CLAIMED=false**. `komodo-latest` still → `komodo-20260915-063833`. `komodo-debug-latest` **exists** → `komodo-debug-20260918-180338` (existence ≠ ready). Status → **REVIEW** (never APPROVED).

Independent rematch of `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` only. Frontend F-DEBUG-PACK-HONESTY dumps and Architect 2026-09-18T18:51:47Z rematch were **not trusted**. Product/source **not** edited (`KOMODO_DEBUG_FLASH.md` sha256 `940062df…` unchanged). No USB GO. No `m`. No retarget. No commit. `*_ondevice.sh` **not** run. Distinct from `Q-REMEDIATE-DEBUG-ADVERTISE` and `Q-REMEDIATE-B1-DEBUG-PACK-SUITE` (sibling scripts not overwritten).

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | DEC-017 present: SHA-identical A/B after packaging restamp is not a kernel rebuild | **PASS** | `KOMODO_DEBUG_FLASH.md` heading + body (lines 37–39, 101–122) |
| 2 | `komodo-debug-latest` may exist; that does not make `DEBUG_FLASH_READY=true` | **PASS** | Doc: pointer **exists** → `komodo-debug-20260918-180338`; table `DEBUG_FLASH_READY` **false**; live `readlink` matches |
| 3 | `komodo-latest` still documented as `komodo-20260915-063833` | **PASS** | Doc unchanged → `komodo-20260915-063833`; live `readlink` matches |
| 4 | `FLASH_READY=false`; `LIVE_FLASH_CLAIMED=false`; no USB GO | **PASS** | Honesty table **false** / **false**; `USB_GO: false`; `types.ts:119` `= false`; `adb` empty; suite `USB_GO=not started` |
| 5 | Docs do not invent a stamp or require a fake new hash | **PASS** | Names existing stamp only; “does **not** require a fake new hash”; live SHA == documented leftovers |
| 6 | Evidence written; `DEBUG_FLASH_READY` not invented true | **PASS** | this file; suite footer `DEBUG_FLASH_READY=false` |

## Packet verification commands (this host, this stamp)

```text
rg -n "DEC-017 — SHA-identical A/B after packaging restamp is not a kernel rebuild" \
  vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md
101:## DEC-017 — SHA-identical A/B after packaging restamp is not a kernel rebuild

rg -n "DEBUG_FLASH_READY" vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md | head
16:| `DEBUG_FLASH_READY` | **false** | Debug sidecar is **not** flash-ready |

readlink releases/desktop-flash/komodo-latest
komodo-20260915-063833

readlink releases/desktop-flash/komodo-debug-latest
komodo-debug-20260918-180338

rg -n "LIVE_FLASH_CLAIMED" vendor/guardtalk/web-installer/src/types.ts
119:export const LIVE_FLASH_CLAIMED = false;
```

Live SHA-256 + `cmp -s` (out/ = stamp `180338` = leftover `063833` = documented):

| File | SHA-256 |
|------|---------|
| `boot.img` | `449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc` |
| `vendor_kernel_boot.img` | `a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8` |
| `pvmfw.img` | `f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8` |
| `dtbo.img` | `742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433` |

`AB_FOUR_LEFTOVER_SHA=4`. SHA-equal is HOLD-documented, **not** a kernel rebuild claim.

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_debug_pack_honesty_host.sh
# RESULT: PASS (host)  bash_PASS=36 bash_HOLD=2 FAIL=0
# WRAPPER_EXIT=0
# LIVE_FLASH_CLAIMED=false
# FLASH_READY=false DEBUG_FLASH_READY=false FLASH_CLASS=HOLD
# KOMODO_LATEST=komodo-20260915-063833
# KOMODO_DEBUG_LATEST=komodo-debug-20260918-180338
# AB_FOUR_LEFTOVER_SHA=4
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-DEBUG-PACK-HONESTY_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Frontend / Architect)

This host, this stamp (2026-09-18T19:05:49Z):

- `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` exists; sha256 `940062df0c249d2bac9b982201fc9d317bb1e72af6dc92197497e7c27ea08402` (QA did not edit)
- DEC-017 heading present: SHA-identical A/B after packaging restamp is **not** a kernel rebuild
- Table current values: `DEBUG_FLASH_READY` **false**, `FLASH_READY` **false**, `LIVE_FLASH_CLAIMED` **false**
- `USB_GO: false` (header + DEC-015 + DEC-017); “no USB GO”
- Pointer **may exist**: live `komodo-debug-latest` → `komodo-debug-20260918-180338`. Existence is **not** `DEBUG_FLASH_READY=true`
- `komodo-latest` documented and live → `komodo-20260915-063833` (not retargeted)
- Docs name the existing stamp only; “does **not** invent a stamp”; “does **not** require a fake new hash”
- Documented leftover digests match live `out/` + stamp + Sept 15 leftovers (`cmp -s`)
- `LIVE_FLASH_CLAIMED=false` at `vendor/guardtalk/web-installer/src/types.ts:119`
- Served dist identical: `dist/src/types.js:11` `LIVE_FLASH_CLAIMED = false` (no `= true`)
- pem ABSENT both stems (`keys/avb/*.pem`, `/mnt/secure/*.pem`); `/mnt/secure` missing
- `adb devices -l` empty
- Sibling suites unchanged: advertise `1df7a1b4…`; pack-host `b9403efa…`; flash-honesty `0a6a3646…`

Does **not** lift `DEBUG_FLASH_READY`. Does **not** APPROVE `Q-REMEDIATE-B1-DEBUG-PACK`.

## Adversarial / HOLD vs FAIL

| Case | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| DEC-017 section absent | honesty doc | FAIL | present | PASS |
| restamp claimed as kernel rebuild | honesty doc | FAIL | denied | PASS |
| `DEBUG_FLASH_READY` table **true** | honesty doc | FAIL | **false** | PASS |
| pointer exists ⇒ ready=true | honesty doc + live pointer | FAIL | existence ≠ ready | PASS |
| `FLASH_READY` table **true** | honesty doc | FAIL | **false** | PASS |
| `LIVE_FLASH_CLAIMED=true` assignment | `src/types.ts` + dist | FAIL | absent (`= false` only) | PASS |
| `komodo-latest` retarget | symlink ≠ `063833` | FAIL | still `komodo-20260915-063833` | PASS |
| invented stamp / fake hash required | honesty doc | FAIL | existing stamp only; no fake hash | PASS |
| documented SHA ≠ live leftover | A/B four | FAIL | 4/4 equal | PASS |
| suite invokes `m` / USB / flash | this script | FAIL | absent | PASS |
| collide with sibling suites | overwrite | FAIL | sibling sha unchanged | PASS |
| invent `DEBUG_FLASH_READY=true` | suite footer | must stay false | `DEBUG_FLASH_READY=false` | PASS |
| T-PACK “HOLD CONFIRMED” vs queue APPROVED 18:52:00Z | honesty doc line 116 | HOLD residual | stale sentence | PASS (HOLD) |
| adb empty | `adb devices -l` | HOLD | empty | PASS (HOLD) |

## Coverage gaps

- Did not re-run Frontend node unit suite (F was markdown-only; no new TS). Host `rg` / `readlink` / `sha256sum` / `cmp -s` rematch is the SoT for this card.
- Did not rematch stamp README / `T-DEBUG-PACK` product files (belongs to `Q-REMEDIATE-B1-DEBUG-PACK`, a different card).
- `pytest platform/tests` N/A.

## Bugs found

- None that fail DEC-017 honesty AC.
- Residual HOLD only:
  1. Honesty doc still says `T-REMEDIATE-B1-DEBUG-PACK` is HOLD CONFIRMED (Frontend rematch 18:24:00Z). Owner-root queue later **APPROVED** T-PACK at 18:52:00Z. This panel does **not** product-edit. `DEBUG_FLASH_READY` stays correctly **false** because `Q-DEBUG-PACK` is not APPROVED.
  2. Empty adb (host-only rematch; USB GO not started).

## Regression status

- Pre-existing sibling scripts: **not modified**
  - `verify_remediate_debug_advertise_host.sh` sha256 `1df7a1b44c89675448795fd1aaf2715769138a84d08093660961e347fc585ce0`
  - `verify_remediate_debug_pack_host.sh` sha256 `b9403efa0eb783c6f12d48820d5f7eabb3e89911c941d956c58933f90eea298d`
  - `verify_remediate_flash_honesty_host.sh` sha256 `0a6a36465224257a659c7982a940fc63673763a3aed78d968b71144a749b1302`
- Product `KOMODO_DEBUG_FLASH.md`: **not modified** (sha256 `940062df…`)
- Tests modified/deleted: NONE
- New files: `verify_remediate_debug_pack_honesty_host.sh`, this evidence, `Q-REMEDIATE-DEBUG-PACK-HONESTY_SUITE.out`

## Governance

- Gate -1 in-process from `.aegis/governance/` (no remote verifier)
- Gate 5 HUMAN SKIP (MCP absent; score 94% not from MCP)
- Law 7: first suite regex required an unwrapped “Do not require a fake new hash”; the later sentence wraps after “fake new”. Rematched and fixed the **test**, not the product (same class as Q-FLASH-HONESTY).
- Never APPROVED. No commit. No USB. No `m`. No retarget. `DEBUG_FLASH_READY` not lifted.
