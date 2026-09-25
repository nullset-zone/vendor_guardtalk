# QA Evidence — Q-REMEDIATE-DEBUG-READY

**Task:** `Q-REMEDIATE-DEBUG-READY` (pair of `F-REMEDIATE-DEBUG-READY` **APPROVED**)  
**Date:** 2026-09-19T04:20:07Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-018  
**Depends:** `grapheneos-worktree::F-REMEDIATE-DEBUG-READY` APPROVED  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. **DEBUG_FLASH_READY=true** (sidecar stamp `komodo-debug-20260918-180338` only). **FLASH_READY=false**. **LIVE_FLASH_CLAIMED=false**. **USB_GO=false** / not started. Leftover SHA HOLD residual kept (4/4). `komodo-latest` still → `komodo-20260915-063833`. `komodo-debug-latest` → `komodo-debug-20260918-180338`. Status → **REVIEW** (never APPROVED).

Independent rematch of DEC-018 advertise. Frontend F-DEBUG-READY dumps and Architect 2026-09-19T04:16:24Z rematch were **not trusted**. Product/source **not** edited (`KOMODO_DEBUG_FLASH.md` sha256 `545fe55c…`; stamp README sha256 `4675e171…` unchanged by this panel). No USB GO. No `m`. No retarget. No commit. `*_ondevice.sh` **not** run. Distinct from `Q-REMEDIATE-DEBUG-ADVERTISE` and `Q-REMEDIATE-DEBUG-PACK-HONESTY` (sibling scripts not overwritten).

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML (24 laws + 11 gates). Doctrine load 155 files across 9 tiers. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `KOMODO_DEBUG_FLASH.md`: `DEBUG_FLASH_READY=true` for `komodo-debug-20260918-180338`; `USB_GO=false`; `FLASH_READY=false` | **PASS** | table lines 16–17; header `USB_GO: false`; DEC-018 heading line 153 |
| 2 | Leftover SHA HOLD residual kept; `T-DEBUG-PACK HOLD CONFIRMED` struck | **PASS** | “DEC-018 does not erase this HOLD residual”; `~~T-DEBUG-PACK HOLD CONFIRMED~~`; no unstruck current claim |
| 3 | Stamp README same flags | **PASS** | `README-FLASH-DESKTOP.md` table `DEBUG_FLASH_READY` **true**; `FLASH_READY` **false**; `USB_GO` **false** |
| 4 | Live pointers: `komodo-debug-latest` → `180338`; `komodo-latest` → `komodo-20260915-063833` | **PASS** | `readlink` both match |
| 5 | Do not invent USB GO; do not claim `FLASH_READY=true` | **PASS** | no current-value `FLASH_READY` **true**; `USB_GO=not started`; `types.ts:119` `LIVE_FLASH_CLAIMED = false` |

## Packet verification commands (this host, this stamp)

```text
rg -n "DEBUG_FLASH_READY|USB_GO|FLASH_READY|T-DEBUG-PACK HOLD CONFIRMED" \
  vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md | head
16:| `DEBUG_FLASH_READY` | **true** | Debug sidecar stamp `komodo-debug-20260918-180338` ...
17:| `FLASH_READY` | **false** | Signed **user** image is **not** flash-ready ...
32:~~T-DEBUG-PACK HOLD CONFIRMED~~ — struck.

readlink releases/desktop-flash/komodo-debug-latest
komodo-debug-20260918-180338

readlink releases/desktop-flash/komodo-latest
komodo-20260915-063833

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

`AB_FOUR_LEFTOVER_SHA=4`. SHA-equal is HOLD-documented, **not** a kernel rebuild claim. Stamp `SHA256SUMS` 20/20.

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_debug_ready_host.sh
# RESULT: PASS (host)  bash_PASS=46 bash_HOLD=3 FAIL=0
# WRAPPER_EXIT=0
# LIVE_FLASH_CLAIMED=false
# FLASH_READY=false DEBUG_FLASH_READY=true FLASH_CLASS=HOLD
# KOMODO_LATEST=komodo-20260915-063833
# KOMODO_DEBUG_LATEST=komodo-debug-20260918-180338
# AB_FOUR_LEFTOVER_SHA=4
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-DEBUG-READY_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Frontend / Architect)

This host, this stamp (2026-09-19T04:20:07Z):

- `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` exists; sha256 `545fe55cd6407b49ff53c2fef8aac61cc451d3d6c9d294a9e7beb1b29e6019d3` (QA did not edit)
- DEC-018 heading present: `DEBUG_FLASH_READY=true` for stamp 180338
- Table current values: `DEBUG_FLASH_READY` **true**, `FLASH_READY` **false**, `LIVE_FLASH_CLAIMED` **false**
- `USB_GO: false` (header + DEC-015 + DEC-017 + DEC-018); “no USB GO”
- `~~T-DEBUG-PACK HOLD CONFIRMED~~` struck; no unstruck current claim
- Leftover SHA HOLD residual kept; live `out/` + stamp + Sept 15 leftovers `cmp -s` 4/4
- Stamp README `releases/desktop-flash/komodo-debug-20260918-180338/README-FLASH-DESKTOP.md` sha256 `4675e171752a680c833a926970cb41c8954702fda54ef597b378eb8bb391e7b6` (QA did not edit): same flags
- Live `komodo-debug-latest` → `komodo-debug-20260918-180338`
- Live `komodo-latest` → `komodo-20260915-063833` (not retargeted)
- `LIVE_FLASH_CLAIMED=false` at `vendor/guardtalk/web-installer/src/types.ts:119`
- Served dist identical: `dist/src/types.js` `LIVE_FLASH_CLAIMED = false` (no `= true`)
- pem ABSENT both stems (`keys/avb/*.pem`, `/mnt/secure/*.pem`); `/mnt/secure` missing
- `adb devices -l` empty
- Sibling suites unchanged: advertise `1df7a1b4…`; honesty `e5466705…`; pack-host `b9403efa…`; flash-honesty `0a6a3646…`

Does **not** invent USB GO. Does **not** claim `FLASH_READY=true`. Does **not** APPROVE this card.

## Adversarial / HOLD vs FAIL

| Case | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| DEC-018 section absent | advertise doc | FAIL | present | PASS |
| `DEBUG_FLASH_READY` table **false** | advertise doc | FAIL (DEC-018 bind) | **true** for 180338 | PASS |
| `FLASH_READY` table **true** | advertise + stamp README | FAIL | **false** | PASS |
| `USB_GO` true | both docs | FAIL | **false** / not started | PASS |
| unstruck `T-DEBUG-PACK HOLD CONFIRMED` | advertise doc | FAIL | struck only | PASS |
| leftover SHA residual erased | advertise doc | FAIL | kept + live 4/4 | PASS |
| `komodo-latest` retarget | symlink ≠ `063833` | FAIL | still `komodo-20260915-063833` | PASS |
| `komodo-debug-latest` ≠ 180338 | symlink | FAIL | → `komodo-debug-20260918-180338` | PASS |
| `LIVE_FLASH_CLAIMED=true` assignment | `src/types.ts` + dist | FAIL | absent (`= false` only) | PASS |
| suite invokes `m` / USB / flash | this script | FAIL | absent | PASS |
| collide with sibling suites | overwrite | FAIL | sibling sha unchanged | PASS |
| installer README still `DEBUG_FLASH_READY` false | `web-installer/README.md` | HOLD (out of F-DEBUG-READY scope) | DEC-011 paragraph stale | PASS (HOLD) |
| sidecar doc still `DEBUG_FLASH_READY=false` | `ENGINEERING_SIDECAR_USERDEBUG.md` | HOLD (out of F-DEBUG-READY scope) | DEC-011 pointer stale | PASS (HOLD) |
| adb empty | `adb devices -l` | HOLD | empty | PASS (HOLD) |

## Coverage gaps

- Did not re-run Frontend node unit suite (F was markdown-only; no new TS). Host `rg` / `readlink` / `sha256sum` / `cmp -s` rematch is the SoT for this card.
- Did not rewrite DEC-011 advertise suite (`verify_remediate_debug_advertise_host.sh` still expects table **false**). That file is a historical rematch; overwriting it would collide with `Q-REMEDIATE-DEBUG-ADVERTISE`.
- `pytest platform/tests` N/A.

## Bugs found

- None that fail DEC-018 advertise AC.
- Residual HOLD only (not FAIL for this card):
  1. `vendor/guardtalk/web-installer/README.md` DEC-011 paragraph still says `DEBUG_FLASH_READY` is **false** until pack APPROVED. F-DEBUG-READY scope was `KOMODO_DEBUG_FLASH.md` only. This panel does **not** product-edit.
  2. `ENGINEERING_SIDECAR_USERDEBUG.md` still says `DEBUG_FLASH_READY=false`. Same out-of-scope residual.
  3. Empty adb (host-only rematch; USB GO not started).

## Regression status

- Pre-existing sibling scripts: **not modified**
  - `verify_remediate_debug_advertise_host.sh` sha256 `1df7a1b44c89675448795fd1aaf2715769138a84d08093660961e347fc585ce0`
  - `verify_remediate_debug_pack_honesty_host.sh` sha256 `e54667056dce9d619d718526096c79b0bc063597da9e016bc7cc3f1509200398`
  - `verify_remediate_debug_pack_host.sh` sha256 `b9403efa0eb783c6f12d48820d5f7eabb3e89911c941d956c58933f90eea298d`
  - `verify_remediate_flash_honesty_host.sh` sha256 `0a6a36465224257a659c7982a940fc63673763a3aed78d968b71144a749b1302`
- Product `KOMODO_DEBUG_FLASH.md`: **not modified** (sha256 `545fe55c…`)
- Stamp README: **not modified** (sha256 `4675e171…`)
- Tests modified/deleted: NONE
- New files: `verify_remediate_debug_ready_host.sh` (sha256 `b5e2560c…`), this evidence, `Q-REMEDIATE-DEBUG-READY_SUITE.out`

## Governance

- Gate -1 in-process from `.aegis/governance/` (no remote verifier)
- Gate 5 HUMAN SKIP (MCP absent; score 95% not from MCP)
- Law 7: rematched live pointers + leftover SHA; did not trust Architect dumps
- Never APPROVED. No commit. No USB. No `m`. No retarget. `FLASH_READY` not invented true.

### PQE Assessment: Code Entropy LOW — advertise bind rematched without inventing USB GO, retargeting `komodo-latest`, or lifting signed-user `FLASH_READY`. Cascade residual on installer/sidecar docs is HOLD-documented, not silently ignored.
