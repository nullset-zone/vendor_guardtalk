# QA Evidence — Q-REMEDIATE-DEBUG-ADVERTISE

**Task:** `Q-REMEDIATE-DEBUG-ADVERTISE` (pair of `F-REMEDIATE-DEBUG-ADVERTISE` **APPROVED**)  
**Date:** 2026-09-18T10:22:34Z (host clock; Architect dispatch metadata was 10:24:00Z)  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-011  
**Depends:** `grapheneos-worktree::F-REMEDIATE-DEBUG-ADVERTISE` APPROVED  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. **DEBUG_FLASH_READY=false**. **FLASH_READY=false**. **LIVE_FLASH_CLAIMED=false**. `komodo-latest` still → `komodo-20260915-063833`. `komodo-debug-latest` **ABSENT**. Status → **REVIEW** (never APPROVED).

Independent rematch. Frontend F-DEBUG-ADVERTISE dumps and Architect 2026-09-18T10:24:00Z rematch were **not trusted**. Product/source **not** edited. No USB GO. No `m`. No retarget. No commit. `*_ondevice.sh` **not** run. Distinct from `Q-REMEDIATE-B1-DEBUG-SUITE` (`verify_remediate_b1_debug_m_host.sh` sha256 `6e3041fd…` unchanged).

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent rematch of F-DEBUG-ADVERTISE files | **PASS** | `KOMODO_DEBUG_FLASH.md` + README DEC-011 + sidecar pointer + `types.ts:119` |
| 2 | `DEBUG_FLASH_READY=false`; `FLASH_READY=false`; `LIVE_FLASH_CLAIMED=false` | **PASS** | honesty table current values **false**; `types.ts:119` `LIVE_FLASH_CLAIMED = false`; suite footer not invented true |
| 3 | `komodo-latest` still → `komodo-20260915-063833`; debug-latest ABSENT | **PASS** | `readlink` = `komodo-20260915-063833`; `komodo-debug-*` ABSENT |
| 4 | Evidence sibling written; ready flags not invented true | **PASS** | this file; `FLASH_READY=false` `DEBUG_FLASH_READY=false` `FLASH_CLASS=HOLD` |

## Packet verification commands (this host, this stamp)

```text
rg -n "DEBUG_FLASH_READY" vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md
16:| `DEBUG_FLASH_READY` | **false** | Debug sidecar is **not** flash-ready |
20:`DEBUG_FLASH_READY` stays **false** until **all** of the following are
37:| **Debug sidecar** (lab only) | ... | `DEBUG_FLASH_READY` — **false** |
83:- `DEBUG_FLASH_READY=true`

rg -n "LIVE_FLASH_CLAIMED" vendor/guardtalk/web-installer/src/types.ts
119:export const LIVE_FLASH_CLAIMED = false;

readlink releases/desktop-flash/komodo-latest
komodo-20260915-063833

ls releases/desktop-flash/komodo-debug-latest
ls: cannot access '.../komodo-debug-latest': No such file or directory
```

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_debug_advertise_host.sh
# RESULT: PASS (host)  bash_PASS=30 bash_HOLD=1 FAIL=0
# WRAPPER_EXIT=0
# LIVE_FLASH_CLAIMED=false
# FLASH_READY=false DEBUG_FLASH_READY=false FLASH_CLASS=HOLD
# KOMODO_LATEST=komodo-20260915-063833
# KOMODO_DEBUG_LATEST=ABSENT
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-DEBUG-ADVERTISE_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Frontend / Architect)

This host, this stamp (2026-09-18T10:22:34Z):

- `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` exists
- Table current values: `DEBUG_FLASH_READY` **false**, `FLASH_READY` **false**, `LIVE_FLASH_CLAIMED` **false**
- Two-channel table names `komodo-trunk_staging-user` (signed user / `FLASH_READY`) vs `komodo-trunk_staging-userdebug` (debug sidecar / `DEBUG_FLASH_READY`)
- Stale `komodo-20260915-063833` denied as the DEC-011 debug flash gate
- `LIVE_FLASH_CLAIMED=false` at `vendor/guardtalk/web-installer/src/types.ts:119`
- Served dist identical: `dist/src/types.js:11` `LIVE_FLASH_CLAIMED = false` (no `= true`)
- `FLASH_READY` is **not** a `types.ts` export; documentary `FLASH_READY=false` in honesty docs (not invented true)
- Installer `README.md` **DEC-011** paragraph: debug channel separate; `DEBUG_FLASH_READY` **false**; do not retarget `komodo-latest`
- `ENGINEERING_SIDECAR_USERDEBUG.md` pointer: `DEBUG_FLASH_READY=false`; do not retarget
- `readlink releases/desktop-flash/komodo-latest` → `komodo-20260915-063833` (not retargeted)
- `komodo-debug-latest` **ABSENT**; no `komodo-debug-*` stamp invented
- `DEBUG_FLASH_READY=true` / `FLASH_READY=true` / `LIVE_FLASH_CLAIMED=true` appear only as denied-claim bullets
- `adb devices -l` empty
- Sibling suite `verify_remediate_b1_debug_m_host.sh` sha256 `6e3041fd4209651039741180b2ecbac15fb00ad17ae2f7935737bf293727299d` unchanged

Confirms Architect rematch independently: honesty claims hold; ready flags not invented.

## Adversarial / HOLD vs FAIL

| Case | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| `DEBUG_FLASH_READY` table **true** | `KOMODO_DEBUG_FLASH.md` | FAIL | **false** | PASS |
| `FLASH_READY` table **true** | `KOMODO_DEBUG_FLASH.md` | FAIL | **false** | PASS |
| `LIVE_FLASH_CLAIMED=true` assignment | `src/types.ts` + dist | FAIL | absent (`= false` only) | PASS |
| `komodo-latest` retarget | symlink target ≠ stamp | FAIL | still `komodo-20260915-063833` | PASS |
| invented `komodo-debug-latest` | pointer or `komodo-debug-*` | FAIL | ABSENT | PASS |
| signed-user claim for debug channel | honesty note | FAIL | denied | PASS |
| stale stamp as this gate | `20260915-063833` | FAIL if claimed | denied | PASS |
| suite invokes `m` / USB / flash | this script | FAIL | absent | PASS |
| collide with debug-m suite | overwrite sibling | FAIL | sibling sha unchanged | PASS |
| invent `DEBUG_FLASH_READY=true` | suite footer | must stay false | `DEBUG_FLASH_READY=false` | PASS |
| invent `FLASH_READY=true` | suite footer | must stay false | `FLASH_READY=false` | PASS |
| adb empty | `adb devices -l` | HOLD | empty | PASS (HOLD) |

## Coverage gaps

- Did not re-run Frontend node unit suite (F was markdown-only; no new TS). Host `rg`/`readlink` rematch is the SoT for this card.
- Installer `README.md` allowlist still says `rango` is not offered (DEC-WEBINSTALL-015 residual from Q-FLASH-HONESTY). Not a DEBUG_FLASH_READY lie; not this card.
- New userdebug `m` / pack not rematched (belongs to T/Q-DEBUG-M and T/Q-DEBUG-PACK). This card must not start `m`.

## Bugs found

- None that fail DEC-011 debug-advertise honesty.
- Residual HOLD only: empty adb (host-only rematch; USB GO not started).

## Regression status

- Pre-existing `verify_remediate_b1_debug_m_host.sh`: **not modified** (sha256 `6e3041fd…`)
- Tests modified/deleted: NONE
- New files: `verify_remediate_debug_advertise_host.sh`, this evidence, `Q-REMEDIATE-DEBUG-ADVERTISE_SUITE.out`

## Governance

- Gate -1 in-process from `.aegis/governance/` (no remote verifier)
- Gate 5 HUMAN SKIP (MCP absent; score 96% not from MCP)
- Law 7: `types.ts:119` is `LIVE_FLASH_CLAIMED=false` only; `FLASH_READY=false` is documentary, not a TS constant
- Never APPROVED. No commit. No USB. No `m`. No retarget. No invented debug stamp.
