# QA Evidence — Q-REMEDIATE-B1-DEBUG-PACK

**Task:** `Q-REMEDIATE-B1-DEBUG-PACK` (pair of `T-REMEDIATE-B1-DEBUG-PACK`)  
**Date:** 2026-09-18T19:05:47Z  
**Agent:** QA_ENGINEER (Panel 4)  
**DEC:** DEC-REMEDIATE-017  
**Depends:** `T-REMEDIATE-B1-DEBUG-PACK` **APPROVED** 2026-09-18T18:52:00Z (honesty)  
**Verdict:** **REVIEW** — independent honesty rematch **PASS**. A/B four SHA == Sept 15 leftover / STALE_BAK is **HOLD “not a kernel rebuild”**, not FAIL. **FLASH_READY=false**. **DEBUG_FLASH_READY=false** (not invented). **LIVE_FLASH_CLAIMED=false**. **USB_GO=false**. Status → **REVIEW** (never APPROVED).

Independent rematch. Architect dumps and Backend T evidence were **not** trusted as proof. Product/source **not** edited. No USB GO. No `m`. No lunch. No flash. No commit. `*_ondevice.sh` **not** run. Pem contents **not** read. STALE_BAK **compared only**, not copied.

GIP-0: Gate -1 in-process from `.aegis/governance/` YAML (gate_neg1, gate_00, laws 0/2/7/16). Guardian MCP/HTTP / aegis-verifier / gate_enforcer **not called**. Derived `.agent-comm/TASK_QUEUE.md` **not** edited.

## Scope lock (Gate 0)

| Bound | Locked |
|-------|--------|
| Owner repo | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| Authoritative queue | owner-root `TASK_QUEUE.md` |
| Rematch | stamp + pointers + SHA256SUMS + A/B four vs STALE_BAK + honesty docs + flags |
| Forbidden | product edits, doctrine, secrets, USB GO, `m`, invent `DEBUG_FLASH_READY=true`, claim APPROVED |
| Optional | `verify_remediate_debug_pack_host.sh` (does **not** lift this card) |

## Acceptance rematch (this stamp)

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `komodo-debug-latest` → `komodo-debug-20260918-180338` | **PASS** | `readlink` exact; symlink inode shared with stamp |
| 2 | `komodo-latest` → `komodo-20260915-063833` (not retargeted) | **PASS** | `readlink` exact; pointer mtime 2026-09-15 |
| 3 | Stamp `SHA256SUMS` 20/20 (`sha256sum -c`) | **PASS** | 20 lines; 20 OK; EXIT=0 |
| 4 | A/B four SHA vs STALE_BAK + leftover prefixes | **HOLD** | `cmp -s` EQUAL ×4; prefixes `449a6bc2` / `a12a9fbd` / `f7c5910e` / `742a1e19` — **not a kernel rebuild**, not FAIL |
| 5 | Stamp README + T evidence do not claim this-continue kernel rebuild | **PASS** | both deny rebuild; document leftover SHA + packaging restamp |
| 6 | `DEBUG_FLASH_READY` not invented true; `FLASH_READY=false`; no USB | **PASS** | README table false; `types.ts:119` false; `adb devices -l` empty |

## Independent rematch (do not trust Architect / Backend dumps)

Host `date -u` **2026-09-18T19:03:48Z–19:05:47Z**. Commands run on this host, this continue.

### 1. Pointers

```text
releases/desktop-flash/komodo-debug-latest -> komodo-debug-20260918-180338
releases/desktop-flash/komodo-latest       -> komodo-20260915-063833
```

`komodo-debug-latest` is a relative symlink (28 bytes, 2026-09-18 18:03Z).  
`komodo-latest` is a relative symlink (22 bytes, 2026-09-15 06:39Z). Not retargeted.

Stamp dir exists: `releases/desktop-flash/komodo-debug-20260918-180338/` (22 files including README + SHA256SUMS). Prior stamp `komodo-debug-20260918-150847` remains on disk and is **not** latest.

### 2. SHA256SUMS 20/20

```bash
cd releases/desktop-flash/komodo-debug-20260918-180338
wc -l SHA256SUMS          # 20
sha256sum -c SHA256SUMS   # 20 OK; SHA256SUMS_EXIT=0
```

All 20 listed artifacts OK: `bootloader.img` `radio.img` `boot.img` `init_boot.img` `vendor_boot.img` `vendor_kernel_boot.img` `pvmfw.img` `dtbo.img` `vbmeta.img` `vbmeta_system.img` `vbmeta_vendor.img` `system.img` `system_ext.img` `product.img` `vendor.img` `vendor_dlkm.img` `system_dlkm.img` `super_empty.img` `avb_pkmd.bin` `init.insmod.komodo.cfg`.

Pointer `komodo-debug-latest/SHA256SUMS` is the **same inode** as the stamp file (200803118).

### 3. A/B four vs STALE_BAK and leftover digests (DEC-017 HOLD)

STALE_BAK present at `/tmp/t-remediate-b1-debug-pack-stale-20260915` (compare only; not copied).  
A/B four: `boot.img` `vendor_kernel_boot.img` `pvmfw.img` `dtbo.img`.

| File | prefix8 | stamp == stale == out | leftover digest match |
|------|---------|-----------------------|------------------------|
| `boot.img` | `449a6bc2` | **EQUAL** (`cmp -s`) | yes |
| `vendor_kernel_boot.img` | `a12a9fbd` | **EQUAL** (`cmp -s`) | yes |
| `pvmfw.img` | `f7c5910e` | **EQUAL** (`cmp -s`) | yes |
| `dtbo.img` | `742a1e19` | **EQUAL** (`cmp -s`) | yes |

Full SHA-256 (stamp = STALE_BAK = `out/target/product/komodo/`):

| File | SHA-256 |
|------|---------|
| `boot.img` | `449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc` |
| `vendor_kernel_boot.img` | `a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8` |
| `pvmfw.img` | `f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8` |
| `dtbo.img` | `742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433` |

Mtimes differ (stamp ~18:03:39Z; STALE_BAK 2026-09-15 04:59Z; out ~17:57–18:03Z). **This-session mtime is not a rebuild.** DEC-017: SHA-equal leftover after packaging restamp is **HOLD “not a kernel rebuild”**, not FAIL, not “rebuilt”.

### 4. Honesty docs (no this-continue kernel-rebuild claim)

`releases/desktop-flash/komodo-debug-20260918-180338/README-FLASH-DESKTOP.md`:

- Heading: “A/B four are current-tree kernel packaging **(not a this-continue rebuild)**”
- “They were **not** rebuilt as a kernel / dtbo / pvmfw compile this continue.”
- “**DEC-017: mtime alone is not a rebuild.**”
- “**not** a this-continue kernel rebuild and **not** a claim that those four were compiled again.”
- Flag table: `DEBUG_FLASH_READY` **false**; `FLASH_READY` **false**; `LIVE_FLASH_CLAIMED` **false**; `USB_GO` **false**

`vendor/guardtalk/docs/qa/T-REMEDIATE-B1-DEBUG-PACK_EVIDENCE.md`:

- “They were **not** rebuilt as a kernel / dtbo / pvmfw compile this continue.”
- “**Do not claim those four were rebuilt this continue.**”
- Documents leftover SHA table + r3/r3b `ninja: no work to do` packaging restamp
- `FLASH_READY=true` / `DEBUG_FLASH_READY=true` marked **absent**

No positive “this-continue kernel rebuild” claim found in either file.

### 5. Flags and USB

| Pred | Result | Evidence |
|------|--------|----------|
| `DEBUG_FLASH_READY` | **false** (not invented) | stamp README table; this rematch does not lift the flag |
| `FLASH_READY` | **false** | signed-user path is `komodo-latest`; pem/user predicates incomplete |
| `LIVE_FLASH_CLAIMED` | **false** | `vendor/guardtalk/web-installer/src/types.ts:119` `export const LIVE_FLASH_CLAIMED = false;` |
| USB / `adb devices -l` | empty | no devices attached |
| Pixel/Google USB | none | `lsusb` no `google`/`pixel`/`android`/`18d1` match |
| `m` this QA stamp | **not started** | no lunch/`m`/flash |

`vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` table still documents all three flags **false**. Present pointer is documented as **not** `DEBUG_FLASH_READY=true`.

### 6. Optional host suite (does not lift this card)

```bash
bash vendor/guardtalk/docs/qa/verify_remediate_debug_pack_host.sh
# RESULT: PASS (host)  bash_PASS=20 bash_HOLD=17 FAIL=0
# WRAPPER_EXIT=0
# AB_FOUR_STALE=0 AB_FOUR_LEFTOVER_SHA=4 AB_FOUR_ABSENT=0 AB_FOUR_SHA_DIFF=0
# STAMP_AB_LEFTOVER_SHA=4 STAMP_AB_ABSENT=0 STAMP_AB_SHA_DIFF=0
# PACK_STAGED=true
# FLASH_READY=false DEBUG_FLASH_READY=false
# FLASH_CLASS=HOLD DEBUG_CLASS=HOLD
# LIVE_FLASH_CLAIMED=false
# KOMODO_LATEST=komodo-20260915-063833
# KOMODO_DEBUG_LATEST=komodo-debug-20260918-180338
```

Suite footer still prints `Q-REMEDIATE-B1-DEBUG-PACK=BLOCKED` because the script **does not lift** this card. That string is a suite contract, not this rematch verdict. This run: Q card was `IN_PROGRESS` (HOLD “status is not BLOCKED”); T card `APPROVED` (HOLD “suite still does not lift Q”). Prior suite card recorded PASS=21 HOLD=16 while Q was BLOCKED. Count drift is the status-record HOLD, not a SHA FAIL.

`pytest platform/tests` N/A (AOSP host rematch, not AEGIS Python platform).

## Adversarial / HOLD vs FAIL

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| SHA == leftover / STALE_BAK | HOLD “not a kernel rebuild” | EQUAL ×4; prefixes match | **HOLD** (not FAIL) |
| Treat leftover SHA as rebuilt | FAIL (lie) | docs deny rebuild | **PASS** |
| `komodo-latest` retargeted | FAIL | still `komodo-20260915-063833` | **PASS** |
| SHA256SUMS mismatch | FAIL | 20/20 OK | **PASS** |
| Pointer missing / wrong stamp | FAIL | → `komodo-debug-20260918-180338` | **PASS** |
| `DEBUG_FLASH_READY=true` invented | forbidden | false | **PASS** |
| `FLASH_READY=true` invented | forbidden | false | **PASS** |
| `LIVE_FLASH_CLAIMED=true` | FAIL | false | **PASS** |
| USB / `m` / ondevice started | forbidden | not started | **PASS** |
| Optional suite lifts this card | forbidden | footer still does not lift | **PASS** |

## Coverage gaps

- Did not run `lunch` / `m` (forbidden)
- Did not USB / flash / lock / wipe
- Did not re-read r3/r3b ninja logs as acceptance (T history; SHA rematch is the SoT)
- Did not lift `DEBUG_FLASH_READY` (Architect owns that flag; this rematch forbids inventing true)
- `Q-REMEDIATE-DEBUG-PACK-HONESTY` is a different card (not this rematch)

## Bugs found

None that are FAIL.

Residual **HOLD**: A/B four SHA == Sept 15 leftover / STALE_BAK after packaging restamp is **not a kernel rebuild**. Stamp + pointer exist; that does **not** make `DEBUG_FLASH_READY=true`. Signed-user `FLASH_READY` remains false.

## Regression status

- Product files: **not** edited
- Pre-existing host suites: **not** overwritten
- Tests modified/deleted: NONE
- New file: this evidence only
- `T-REMEDIATE-B1-DEBUG-PACK` remains **APPROVED** (honesty)

## Ultimate Critique Score: 94% (Gate 5)

HUMAN SKIP — Guardian MCP / `mcp1_ultimate_critique` unavailable (dispatch: do not call Guardian). Manual Gate 5: acceptance 10, scope 10, SHA256SUMS live 10, A/B `cmp` independence 10, leftover HOLD classification 10, honesty-doc rematch 9, flags/USB 10, footprint 10, suite-optional caveat 8, coverage gaps 7. Total 94/100. Verdict: pass.

## PQE Assessment: Code Entropy LOW

Honesty rematch reduces entropy: pointers, 20/20 sums, and leftover-SHA HOLD are independently measured. Ready flags stay false. Treating SHA-equal leftovers as a rebuild would **increase** entropy; that lie was not accepted.

## GOVERNANCE COMPLIANCE CHECK (COT-006 condensed)

1. CLASSIFY: QA evidence + inbox report (no product code)
2. CORE LAWS 0-15: BLOCK checks pass (Architect dispatch; qa/ + owner queue + inbox only; no doctrine edit)
3. EXTENDED LAWS 16-23: rematch commands verified; no new deps; no PII
4. GATES: -1 in-process YAML; 0 scope lock; 3 no secrets/USB/`m`; 5 manual critique 94%; 6 REVIEW not APPROVED
5. CROSS-REFERENCE: DEC-017 honesty rematch only; `DEBUG_FLASH_READY` not invented true
6. CONFIDENCE: 9/10 (live `readlink` + `sha256sum -c` + `cmp -s` + adb empty)
7. VERDICT: PASS (honesty rematch) / HOLD (`DEBUG_FLASH_READY=false`; leftover SHA not a rebuild)
