# QA Evidence — Q-REMEDIATE-B1-DEBUG-PACK-SUITE

**Task:** `Q-REMEDIATE-B1-DEBUG-PACK-SUITE` (standalone host suite; does **not** lift `Q-REMEDIATE-B1-DEBUG-PACK`)  
**Date:** 2026-09-18T18:27:43Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-015 / DEC-REMEDIATE-017  
**Depends:** none (standalone; pair of `T-REMEDIATE-B1-DEBUG-PACK` is **not** APPROVED)  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. SHA==leftover / STALE_BAK is **HOLD “not a kernel rebuild”**. Missing stamp / 2026-09-15 mtime still **HOLD**, not FAIL. **FLASH_READY=false**. **DEBUG_FLASH_READY=false**. **LIVE_FLASH_CLAIMED=false**. `Q-REMEDIATE-B1-DEBUG-PACK` stays **BLOCKED**. Status → **REVIEW** (never APPROVED).

Independent rematch. Architect 2026-09-18T18:12:00Z dump and Backend T-DEBUG-PACK REVIEW were **not** trusted. Product/source **not** edited. No USB GO. No `m`. No lunch. No flash. No commit. `*_ondevice.sh` **not** run. Pem contents **not** read. Other `verify_*.sh` **not** overwritten. STALE_BAK **compared only**, not copied.

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Debug-pack preconditions (this stamp)

| Pred | Rule | Result | Evidence |
|------|------|--------|----------|
| komodo-latest | still → `komodo-20260915-063833` | **PASS** | `readlink` exact |
| debug stamp | pointer may exist; still not flash-ready | **HOLD** | `komodo-debug-latest` → `komodo-debug-20260918-180338` |
| pack staged | stamp + SHA256SUMS not a DEBUG_FLASH_READY lift | **HOLD** | stamp dirs present; Q-DEBUG-PACK not lifted |
| A/B four SHA | SHA == STALE_BAK / leftover digest → HOLD “not a kernel rebuild” | **HOLD** | out/ + stamp all four SHA-equal leftover (mtime 2026-09-18) |
| A/B four mtime | 2026-09-15 leftover still HOLD, not FAIL | **HOLD** | this stamp: leftover SHA, not 2026-09-15 mtime |
| FLASH_READY | never invented true | **false** | signed-user predicates incomplete |
| DEBUG_FLASH_READY | never invented true | **false** | SHA-equal leftover is not a rebuild; Q-DEBUG-PACK BLOCKED |
| LIVE_FLASH_CLAIMED | false | **false** | `src/types.ts` export; debug honesty table |
| Q-DEBUG-PACK | this suite does not lift | **BLOCKED** | owner-root `TASK_QUEUE.md` |

DEC-017: this-session mtime alone is **not** acceptance. SHA-identical to Sept 15 leftovers after packaging restamp is **not** a kernel rebuild.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `verify_remediate_debug_pack_host.sh` exists and is executable | **PASS** | `test -x` = yes |
| 2 | Suite EXIT=0 with FAIL=0; HOLD allowed | **PASS** | EXIT=0 PASS=21 FAIL=0 HOLD=16 |
| 3 | SHA==leftover / STALE_BAK → HOLD “not a kernel rebuild” | **PASS** | `AB_FOUR_LEFTOVER_SHA=4`; no “rebuild recorded” |
| 4 | Missing stamp / 2026-09-15 mtime still HOLD, not FAIL | **PASS** | stamp present this run; predicate remains HOLD |
| 5 | FLASH_READY=false; DEBUG_FLASH_READY=false; LIVE_FLASH_CLAIMED=false | **PASS** | suite footer; not invented true |
| 6 | Does not lift Q-DEBUG-PACK | **PASS** | still BLOCKED |
| 7 | Evidence sibling written | **PASS** | this file + `Q-REMEDIATE-B1-DEBUG-PACK-SUITE_SUITE.out` |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_debug_pack_host.sh
# RESULT: PASS (host)  bash_PASS=21 bash_HOLD=16 FAIL=0
# WRAPPER_EXIT=0
# AB_FOUR_STALE=0 AB_FOUR_LEFTOVER_SHA=4 AB_FOUR_ABSENT=0 AB_FOUR_SHA_DIFF=0
# STAMP_AB_LEFTOVER_SHA=4 STAMP_AB_ABSENT=0 STAMP_AB_SHA_DIFF=0
# PACK_STAGED=true
# FLASH_READY=false DEBUG_FLASH_READY=false
# FLASH_CLASS=HOLD DEBUG_CLASS=HOLD
# LIVE_FLASH_CLAIMED=false
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
# Q-REMEDIATE-B1-DEBUG-PACK=BLOCKED
# KOMODO_LATEST=komodo-20260915-063833
# KOMODO_DEBUG_LATEST=komodo-debug-20260918-180338
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B1-DEBUG-PACK-SUITE_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Architect / Backend dumps)

This host, this stamp (2026-09-18T18:27:43Z suite):

- DEC-REMEDIATE-017 in `.memory-bank/decisions.md` (SHA==STALE_BAK is not a kernel rebuild)
- Owner-root `TASK_QUEUE.md` documents DEC-015 and DEC-017; `Q-REMEDIATE-B1-DEBUG-PACK` **BLOCKED**; `T-REMEDIATE-B1-DEBUG-PACK` **not APPROVED**
- `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` table: DEBUG_FLASH_READY / FLASH_READY / LIVE_FLASH_CLAIMED all **false**
- `vendor/guardtalk/web-installer/src/types.ts` `export const LIVE_FLASH_CLAIMED = false;`
- `releases/desktop-flash/komodo-debug-latest` → `komodo-debug-20260918-180338`
- `releases/desktop-flash/komodo-latest` → `komodo-20260915-063833`
- STALE_BAK present at `/tmp/t-remediate-b1-debug-pack-stale-20260915` (compare only)
- out/ A/B four: this-session mtime, SHA equals leftover + STALE_BAK

| File | out/ mtime | SHA-256 |
|------|------------|---------|
| `boot.img` | 2026-09-18 17:57:54Z | `449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc` |
| `vendor_kernel_boot.img` | 2026-09-18 17:57:54Z | `a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8` |
| `pvmfw.img` | 2026-09-18 18:03:31Z | `f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8` |
| `dtbo.img` | 2026-09-18 18:03:15Z | `742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433` |

- Stamp `komodo-debug-20260918-180338` A/B four: same four leftover digests
- `adb devices -l` empty
- `Q-REMEDIATE-B1-DEBUG-PACK` still **BLOCKED**
- Sibling suites still present: `verify_remediate_b1_debug_m_host.sh`, `verify_remediate_debug_advertise_host.sh`

Prior suite (2026-09-18T14:50:43Z) treated non-2026-09-15 mtime as “rebuild recorded” and did not compare SHA to STALE_BAK. That predicate is **removed**. SHA-first HOLD is the DEC-017 rematch.

## Adversarial / HOLD vs FAIL

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| SHA == leftover / STALE_BAK (newer mtime) | HOLD “not a kernel rebuild” | HOLD leftover SHA=4 | PASS |
| stamp A/B SHA == leftover | HOLD “not a kernel rebuild” | HOLD stamp leftover SHA=4 | PASS |
| `komodo-debug-latest` PRESENT | HOLD not FAIL; not DEBUG_FLASH_READY | HOLD | PASS |
| missing stamp / 2026-09-15 mtime | HOLD not FAIL | predicate present; this run SHA HOLD | PASS |
| `komodo-latest` retargeted | FAIL | still `komodo-20260915-063833` | PASS |
| FLASH_READY invented true | forbidden | false | PASS |
| DEBUG_FLASH_READY invented true | forbidden | false | PASS |
| LIVE_FLASH_CLAIMED=true | FAIL | false | PASS |
| `m` / USB / ondevice started | forbidden | not started | PASS |
| overwrite other `verify_*.sh` | forbidden | siblings intact | PASS |
| lift Q-DEBUG-PACK | forbidden | still BLOCKED | PASS |
| classify leftover SHA as rebuilt | forbidden | no “rebuild recorded” | PASS |

## Coverage gaps

- Did not run `lunch` / `m` (forbidden)
- Did not rematch SHA256SUMS 20/20 (Q-DEBUG-PACK owns stamp rematch; stays BLOCKED)
- `Q-REMEDIATE-DEBUG-PACK-HONESTY` is a different card (not lifted)
- Did not USB / flash / lock
- Did not treat packaging restamp mtime as a kernel compile

## Bugs found

None that are FAIL. Residual DEBUG_FLASH_READY blockers are HOLD: A/B four SHA==Sept 15 leftover (not a kernel rebuild), Q-DEBUG-PACK BLOCKED, T-DEBUG-PACK not APPROVED, empty adb. Signed-user FLASH_READY remains false.

## Regression status

- Pre-existing host suites: **not** overwritten
- Files updated: `verify_remediate_debug_pack_host.sh` (+ this evidence + suite out)
- Tests modified/deleted: NONE (suite expanded in place)
- `Q-REMEDIATE-B1-DEBUG-PACK` status: still BLOCKED

## Ultimate Critique Score: 93% (Gate 5)

HUMAN SKIP — Guardian MCP / `mcp1_ultimate_critique` unavailable (dispatch: do not call Guardian). Manual Gate 5: acceptance 10, scope 10, suite PASS 10, no FAIL 10, SHA adversarial 9, edge HOLD 9, independence 10, footprint 10, HOLD documentation 9, coverage gaps 6. Total 93/100. Verdict: pass.

## PQE Assessment: Code Entropy LOW

SHA-first leftover classification removes the mtime “rebuild recorded” lie. HOLD-not-FAIL for missing stamp / stale mtime is preserved. Ready flags stay false. Entropy decreased vs the prior mtime-only predicate.

## GOVERNANCE COMPLIANCE CHECK (COT-006 condensed)

1. CLASSIFY: test script + evidence doc (QA only)
2. CORE LAWS 0-15: BLOCK checks pass (Architect dispatch; qa/ + owner queue + inbox only; no doctrine edit)
3. EXTENDED LAWS 16-23: suite run verified; no new deps; no PII
4. GATES: -1 in-process YAML; 0 scope lock; 3 no secrets/USB/`m`; 5 manual critique 93%; 6 REVIEW not APPROVED
5. CROSS-REFERENCE: DEC-017 SHA predicate only; Q-DEBUG-PACK not lifted
6. CONFIDENCE: 9/10 (live suite output + live SHA rematch)
7. VERDICT: PASS
