# QA Evidence — Q-REMEDIATE-FLASH-HONESTY

**Task:** `Q-REMEDIATE-FLASH-HONESTY` (pair of `F-REMEDIATE-FLASH-HONESTY` **APPROVED**)  
**Date:** 2026-09-18T09:44:09Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-010  
**Depends:** `grapheneos-worktree::F-REMEDIATE-FLASH-HONESTY` APPROVED  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. **LIVE_FLASH_CLAIMED=false**. **FLASH_READY=false** (not invented). `komodo-latest` still → `komodo-20260915-063833`. Status → **REVIEW** (never APPROVED).

Independent rematch. Frontend F-HONESTY dumps and Architect 2026-09-18T09:35:54Z rematch were **not trusted**. Product/source **not** edited. No USB GO. No `m`. No retarget. No commit. `*_ondevice.sh` **not** run.

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML. Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent rematch `LIVE_FLASH_CLAIMED=false` | **PASS** | `src/types.ts:119` and `dist/src/types.js:11` `export const LIVE_FLASH_CLAIMED = false;` |
| 2 | README/advertise do not claim `FLASH_READY=true` or user-signed for `20260915-063833` | **PASS** | stamp README `FLASH_READY=false` / not user-signed; `KOMODO_STAMP_HONESTY`; wizard `data-dec="010"` |
| 3 | `komodo-latest` still → `komodo-20260915-063833` | **PASS** | `readlink` = `komodo-20260915-063833` |
| 4 | tokay+akita+komodo listed; no new SKU | **PASS** | `WIZARD_DEVICES` + `ALLOWED_PRODUCTS`; no shiba/husky/caiman/tegu/comet |
| 5 | Evidence file written; `FLASH_READY` not invented true | **PASS** | this file; `FLASH_READY=false` `FLASH_CLASS=HOLD` |

## Packet verification commands (this host, this stamp)

```text
rg -n "LIVE_FLASH_CLAIMED" vendor/guardtalk/web-installer/src/types.ts
119:export const LIVE_FLASH_CLAIMED = false;

rg -n "FLASH_READY" releases/desktop-flash/komodo-20260915-063833/README-FLASH-DESKTOP.md
15:This stamp is **not** a signed **user** FLASH_READY image.
18:- `FLASH_READY=false`. Not user-signed.
20:- A `komodo-latest` pointer at this stamp is **not** a FLASH_READY claim.
27:not as FLASH_READY.

readlink releases/desktop-flash/komodo-latest
komodo-20260915-063833
```

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_flash_honesty_host.sh
# RESULT: PASS (host)  bash_PASS=32 bash_HOLD=2 FAIL=0
# WRAPPER_EXIT=0
# LIVE_FLASH_CLAIMED=false
# FLASH_READY=false FLASH_CLASS=HOLD
# KOMODO_LATEST=komodo-20260915-063833
# LIVE_DEVICE_CLAIMED=false
# PASS_HOLD=remains
# M_BUILD=not started
# USB_GO=not started
# ONDEVICE=not started
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-FLASH-HONESTY_SUITE.out`

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Frontend / Architect)

This host, this stamp (2026-09-18T09:44:09Z):

- `LIVE_FLASH_CLAIMED=false` at `vendor/guardtalk/web-installer/src/types.ts:119`
- Served dist identical: `dist/src/types.js:11` `LIVE_FLASH_CLAIMED = false` (no `= true`)
- Stamp README Honesty (DEC-REMEDIATE-010) denies signed-user FLASH_READY; `FLASH_READY=false`
- `KOMODO_STAMP_HONESTY` names `komodo-20260915-063833` as userdebug/test-keys, not a signed user FLASH_READY image
- Wizard `data-dec="010"` banner: `FLASH_READY=false` `LIVE_FLASH_CLAIMED=false`
- `FLASH_READY=true` **absent** from stamp README + installer advertise sources
- `FLASH_READY=true` only as `assert.doesNotMatch` in three negative tests
- `readlink releases/desktop-flash/komodo-latest` → `komodo-20260915-063833` (not retargeted)
- Advertised ids: tokay + akita + komodo + rango (experimental / boot HOLD). No new SKU.
- `adb devices -l` empty

Confirms Architect rematch 2026-09-18T09:35:54Z independently: honesty claims hold; FLASH_READY not invented.

## Adversarial / HOLD vs FAIL

| Case | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| `LIVE_FLASH_CLAIMED=true` assignment | `src/types.ts` + dist | FAIL | absent (`= false` only) | PASS |
| `FLASH_READY=true` on advertise | README / offered-devices / wizard / early-steps | FAIL | absent | PASS |
| `FLASH_READY=true` as positive test claim | `test/*.ts` | FAIL | only `doesNotMatch` | PASS |
| `komodo-latest` retarget | symlink target ≠ stamp | FAIL | still `komodo-20260915-063833` | PASS |
| new SKU (shiba/husky/caiman/tegu/comet) | `WIZARD_DEVICES` ids | FAIL | none | PASS |
| signed-user claim for `20260915-063833` | stamp + installer README | FAIL | denied | PASS |
| suite invokes `m` / USB / flash | this script | FAIL | absent | PASS |
| installer README denies rango | stale vs live picker | HOLD residual | HOLD | PASS (HOLD) |
| adb empty | `adb devices -l` | HOLD | empty | PASS (HOLD) |
| invent `FLASH_READY=true` | suite footer | must stay false | `FLASH_READY=false` | PASS |

## Coverage gaps

- Did not re-run Frontend node unit suite (F claimed 329 PASS). Host `rg`/`readlink` rematch is the SoT for this card.
- Installer `README.md` allowlist still says `rango` is not offered. Live picker offers rango as experimental / boot HOLD (DEC-WEBINSTALL-015 residual). Not a FLASH_READY lie; not a new SKU. Architect follow-up optional.

## Bugs found

- None that fail DEC-010 advertise honesty.
- Residual HOLD only: installer README rango allowlist drift (pre-existing vs live picker).

## Regression status

- Pre-existing `verify_remediate_*_host.sh` files: not modified
- Tests modified/deleted: NONE
- New files: `verify_remediate_flash_honesty_host.sh`, this evidence, `Q-REMEDIATE-FLASH-HONESTY_SUITE.out`

## Governance

- Gate -1 in-process from `.aegis/governance/` (no remote verifier)
- Gate 5 HUMAN SKIP (MCP absent; score 94% not from MCP)
- Law 7: first suite regex missed a wrapped README line (`**not** a` / `signed user`); rematched and fixed the **test**, not the product
- Never APPROVED. No commit. No USB. No `m`. No retarget.
