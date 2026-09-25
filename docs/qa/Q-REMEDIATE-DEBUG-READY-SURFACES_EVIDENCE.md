# QA Evidence — Q-REMEDIATE-DEBUG-READY-SURFACES

**Task:** `Q-REMEDIATE-DEBUG-READY-SURFACES` (pair of `F-REMEDIATE-DEBUG-READY-SURFACES` **APPROVED**)  
**Date:** 2026-09-19T04:27:02Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-018  
**Depends:** `grapheneos-worktree::F-REMEDIATE-DEBUG-READY-SURFACES` APPROVED  
**Verdict:** **PASS (host)** — EXIT=0 FAIL=0. **DEBUG_FLASH_READY=true** (sidecar stamp `komodo-debug-20260918-180338` only) on installer README + sidecar doc. **FLASH_READY=false**. **LIVE_FLASH_CLAIMED=false**. **USB_GO=false** / not started. Leftover SHA HOLD residual still mentioned. `komodo-latest` still → `komodo-20260915-063833`. `komodo-debug-latest` → `komodo-debug-20260918-180338`. Status → **REVIEW** (never APPROVED).

Independent rematch of DEC-018 leftover honesty surfaces. Frontend F-SURFACES dumps and Architect 2026-09-19T04:24:12Z rematch were **not trusted**. Product leftover surfaces **not** edited by this panel (installer README sha256 `18dec6ba…`; sidecar doc sha256 `63d96b14…`). No USB GO. No `m`. No retarget. No commit. `*_ondevice.sh` **not** run. Distinct from `Q-REMEDIATE-DEBUG-ADVERTISE` and `Q-REMEDIATE-DEBUG-PACK-HONESTY` (sibling scripts not overwritten).

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML (24 laws + 11 gates). Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `web-installer/README.md`: `DEBUG_FLASH_READY=true` for `komodo-debug-20260918-180338`; `USB_GO=false`; `FLASH_READY=false` | **PASS** | DEC-011/018 paragraph lines 33–39: `DEBUG_FLASH_READY` is **true**; `USB_GO` stays **false**; signed-user `FLASH_READY` stays **false**; No USB GO |
| 2 | `ENGINEERING_SIDECAR_USERDEBUG.md`: same bind | **PASS** | lines 48–51: `DEBUG_FLASH_READY=true` for 180338 / `komodo-debug-latest`; `USB_GO=false`; `FLASH_READY=false` |
| 3 | Live pointers: `komodo-debug-latest` → `180338`; `komodo-latest` → `komodo-20260915-063833` | **PASS** | `readlink` both match |
| 4 | Leftover SHA HOLD residual still mentioned; no USB GO invented | **PASS** | both leftover files name DEC-017 leftover SHA HOLD residual; no `USB_GO=true`; live A/B four SHA 4/4 |

## Packet verification commands (this host, this stamp)

```text
rg -n "DEBUG_FLASH_READY|USB_GO|FLASH_READY|HOLD residual|komodo-latest|180338" \
  vendor/guardtalk/web-installer/README.md \
  vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md

vendor/guardtalk/web-installer/README.md:33:**DEC-011 / DEC-018:** Debug sidecar flash is a **separate** channel
vendor/guardtalk/web-installer/README.md:34:(`komodo-debug-latest` → `komodo-debug-20260918-180338`). `DEBUG_FLASH_READY`
vendor/guardtalk/web-installer/README.md:35:is **true** for that sidecar stamp (Q-DEBUG-PACK APPROVED). `USB_GO` stays
vendor/guardtalk/web-installer/README.md:36:**false**. Signed-user `FLASH_READY` stays **false**. DEC-017 leftover SHA
vendor/guardtalk/web-installer/README.md:37:HOLD residual remains. Do not treat `komodo-20260915-063833` as that gate.
vendor/guardtalk/web-installer/README.md:38:Do not retarget `komodo-latest`. No new SKU. No USB GO. See

vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md:48:DEC-011 / DEC-018 debug-channel honesty (`DEBUG_FLASH_READY=true` for
vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md:49:sidecar stamp `komodo-debug-20260918-180338` / `komodo-debug-latest`;
vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md:50:`USB_GO=false`; `FLASH_READY=false`; DEC-017 leftover SHA HOLD residual;
vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md:51:do not retarget `komodo-latest`): `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md`.

readlink releases/desktop-flash/komodo-debug-latest
komodo-debug-20260918-180338

readlink releases/desktop-flash/komodo-latest
komodo-20260915-063833
```

No current `DEBUG_FLASH_READY=false` / `DEBUG_FLASH_READY` is **false** on either leftover surface.

Live SHA-256 + `cmp -s` (out/ = stamp `180338` = leftover `063833` = documented in `KOMODO_DEBUG_FLASH.md`):

| File | SHA-256 |
|------|---------|
| `boot.img` | `449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc` |
| `vendor_kernel_boot.img` | `a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8` |
| `pvmfw.img` | `f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8` |
| `dtbo.img` | `742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433` |

`AB_FOUR_LEFTOVER_SHA=4`. SHA-equal is HOLD-documented, **not** a kernel rebuild claim. Leftover surfaces mention the residual in prose; they do **not** reprint the four hexes (those remain in `KOMODO_DEBUG_FLASH.md`). That is not a FAIL for this card.

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_debug_ready_host.sh
# RESULT: PASS (host)  bash_PASS=64 bash_HOLD=1 FAIL=0
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

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-DEBUG-READY-SURFACES_SUITE.out`

Suite was extended so leftover surfaces are **positive** DEC-018 binds (was HOLD residual on Q-REMEDIATE-DEBUG-READY). First run FAIL=1 on a bad `rg` `\n` literal in the installer USB_GO check (regex, not product). Fixed; rerun EXIT=0.

`pytest platform/tests` N/A (AOSP host bash, not AEGIS Python platform).

## Independent rematch (do not trust Frontend / Architect)

This host, this stamp (2026-09-19T04:27:02Z):

- `vendor/guardtalk/web-installer/README.md` exists; sha256 `18dec6ba683969b8898b5ea9f5e612ec32f53eef0afe6b2eb4dd3c975cb74d51` (QA did not edit)
- DEC-011 / DEC-018 paragraph binds `DEBUG_FLASH_READY` **true** for `komodo-debug-20260918-180338`
- `USB_GO` stays **false**; No USB GO; signed-user `FLASH_READY` stays **false**
- DEC-017 leftover SHA HOLD residual remains in prose
- Do not retarget `komodo-latest`; names `komodo-20260915-063833`
- No current `DEBUG_FLASH_READY` **false** claim
- `vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md` sha256 `63d96b14a9b1a286102d5c544cb2e4ef7bd59a62de8e61603052e94dc05942df` (QA did not edit)
- Sidecar: `DEBUG_FLASH_READY=true` for 180338 / `komodo-debug-latest`; `USB_GO=false`; `FLASH_READY=false`; leftover SHA HOLD residual; do not retarget `komodo-latest`
- Live `komodo-debug-latest` → `komodo-debug-20260918-180338`
- Live `komodo-latest` → `komodo-20260915-063833` (not retargeted)
- `LIVE_FLASH_CLAIMED=false` at `vendor/guardtalk/web-installer/src/types.ts:119`
- `KOMODO_DEBUG_FLASH.md` sha256 `545fe55cd6407b49ff53c2fef8aac61cc451d3d6c9d294a9e7beb1b29e6019d3` unchanged vs Q-REMEDIATE-DEBUG-READY
- `adb devices -l` empty
- Sibling suites unchanged: advertise `1df7a1b4…`; honesty `e5466705…`; pack-host `b9403efa…`; flash-honesty `0a6a3646…`

Does **not** invent USB GO. Does **not** claim `FLASH_READY=true`. Does **not** APPROVE this card.

## Adversarial / HOLD vs FAIL

| Case | Input | Expected | Actual | Status |
|------|-------|----------|--------|--------|
| leftover surfaces still `DEBUG_FLASH_READY` false | installer README + sidecar | FAIL (now in F-SURFACES scope) | **true** for 180338 | PASS |
| `USB_GO` true invented | leftover surfaces | FAIL | **false** / No USB GO | PASS |
| `FLASH_READY=true` invented | leftover surfaces | FAIL (`[^_]` so `DEBUG_FLASH_READY=true` is not a hit) | **false** only | PASS |
| leftover SHA residual erased | leftover surfaces | FAIL | prose residual kept; live 4/4 | PASS |
| `komodo-latest` retarget | symlink ≠ `063833` | FAIL | still `komodo-20260915-063833` | PASS |
| `komodo-debug-latest` ≠ 180338 | symlink | FAIL | → `komodo-debug-20260918-180338` | PASS |
| `LIVE_FLASH_CLAIMED=true` | `src/types.ts` | FAIL | `= false` only | PASS |
| suite invokes `m` / USB / flash | this script | FAIL | absent | PASS |
| collide with sibling suites | overwrite | FAIL | sibling sha unchanged | PASS |
| adb empty | `adb devices -l` | HOLD | empty | PASS (HOLD) |

## Coverage gaps

- Leftover surfaces mention leftover SHA HOLD residual in prose; they do not reprint `449a6bc2` / `a12a9fbd` / `f7c5910e` / `742a1e19`. Digests remain in `KOMODO_DEBUG_FLASH.md`.
- Did not rewrite DEC-011 advertise suite (`verify_remediate_debug_advertise_host.sh` still expects sidecar `DEBUG_FLASH_READY=false`). That file is a historical rematch; overwriting it would collide with `Q-REMEDIATE-DEBUG-ADVERTISE`.
- `pytest platform/tests` N/A.

## Bugs found

- None that fail DEC-018 leftover-surface AC.
- Residual HOLD only (not FAIL for this card): empty adb (host-only rematch; USB GO not started).
- Prior Q-REMEDIATE-DEBUG-READY HOLD residuals (installer README + sidecar still false) are **closed** on disk.

## Regression status

- Pre-existing sibling scripts: **not modified**
  - `verify_remediate_debug_advertise_host.sh` sha256 `1df7a1b44c89675448795fd1aaf2715769138a84d08093660961e347fc585ce0`
  - `verify_remediate_debug_pack_honesty_host.sh` sha256 `e54667056dce9d619d718526096c79b0bc063597da9e016bc7cc3f1509200398`
  - `verify_remediate_debug_pack_host.sh` sha256 `b9403efa0eb783c6f12d48820d5f7eabb3e89911c941d956c58933f90eea298d`
  - `verify_remediate_flash_honesty_host.sh` sha256 `0a6a36465224257a659c7982a940fc63673763a3aed78d968b71144a749b1302`
- Product leftover surfaces: **not modified** by QA (sha256 `18dec6ba…` / `63d96b14…`)
- `KOMODO_DEBUG_FLASH.md`: **not modified** (sha256 `545fe55c…`)
- Tests modified: `verify_remediate_debug_ready_host.sh` extended (sha256 `002c2f3a5a9e5d0d18627088324bf487ca8c54032c1fed8406dced06a681d88a`; was `b5e2560c…`)
- Tests deleted: NONE
- New files: this evidence, `Q-REMEDIATE-DEBUG-READY-SURFACES_SUITE.out`

## Governance

- Gate -1 in-process from `.aegis/governance/` (no remote verifier)
- Gate 5 HUMAN SKIP (MCP absent; score 95% not from MCP)
- Law 7: rematched live pointers + leftover surfaces + leftover SHA; did not trust Architect dumps
- Never APPROVED. No commit. No USB. No `m`. No retarget. `FLASH_READY` not invented true.

### PQE Assessment: Code Entropy LOW — leftover DEC-011 false claims rematched as DEC-018 true binds without inventing USB GO, retargeting `komodo-latest`, or lifting signed-user `FLASH_READY`. Prior installer/sidecar HOLD is closed, not silently ignored.
