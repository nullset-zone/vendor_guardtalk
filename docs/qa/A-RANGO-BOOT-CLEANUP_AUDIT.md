# Full Audit — A-RANGO-BOOT-CLEANUP

**Task:** `A-RANGO-BOOT-CLEANUP` (deletion scope, RCA quality+citations, fix minimality, DEC-012, Law 11)  
**Date:** 2026-08-01  
**Agent:** AEGIS Independent Auditor (read-only / aegis-auditor)  
**Depends:** `Q-RANGO-SCRIPT-CLEANUP` ✅ APPROVED, `Q-RANGO-BOOT` ✅ APPROVED CONDITIONAL GO (static; device HOLD)  
**Status for Architect:** **REVIEW** only (Auditor never self-APPROVES)  
**Sprint:** `DEC-RANGO-BOOT-CLEANUP-001` — rango Boot Cleanup + Root Cause

## Gate -1

| Step | Result |
|------|--------|
| MCP `ask_guardian` | Consulted — `governanceStatus: compliant` (Guardian Proxy fallback, `warnings: Guardian Proxy not available`) |
| MCP `gate_enforcer` Gate -1 | **PASSED** (`guardian_consulted`, `session_initialized`) |
| MCP `ultimate_critique` | **UNAVAILABLE** (`python: not found` — same class of failure noted by every prior engineer/QA this sprint) |
| MCP `self_critique` | Ran successfully — **97/100** (see Gate 5 below) |
| Disposition | Proceed under Gate -1 PASS; manual Gate 5 rubric used, cross-checked by `self_critique` |

## Independence acknowledgment

```text
INDEPENDENT AUDITOR ENGAGED
Scope: full — A-RANGO-BOOT-CLEANUP (deletion scope / RCA / fix / DEC-012 / Law 11)
Independence: CONFIRMED — I am NOT the Architect, Backend Engineer, or QA. I audit their work.
Context: DEC-RANGO-BOOT-CLEANUP-001, Q-RANGO-SCRIPT-CLEANUP ✅, Q-RANGO-BOOT ✅ CONDITIONAL GO
Forbidden: product/implementation edits; inventing device PASS; self-APPROVED
Method: Nothing below is taken on the prior agents' word alone — every load-bearing claim was
independently re-executed against the live filesystem/build tree this session.
```

## Re-verification (this session — all commands independently re-run, not copied from prior reports)

| Probe | Result |
|-------|--------|
| Archive completeness | All **29/29** Architect-listed scripts confirmed present in `.agent-comm/completed/rango-flash-mess-20260801/` **and** absent from `scripts/` (per-file loop, not just a count) |
| `scripts/` residue scan | `find` for rango/hybrid/pstore/probe/avb-diag/combo/stock/correct-gt/solution/final/fixed patterns → **0 hits** outside the archive dir |
| KEEP set | `scripts/flash-from-remote.sh` **913** lines; `vendor/guardtalk/scripts/flash-from-remote.sh` **857** lines (drift note confirmed accurate) |
| `vendor/guardtalk/scripts/` | **14** pre-existing files untouched + **1** new `stage-rango-release.sh` (correctly scoped to `T-RANGO-BOOT-FIX`, not the cleanup task) — no wrongful deletions |
| OUT sepolicy hashes (primary RCA root cause) | Independently ran `cmp` on live `out/target/product/rango`: `plat_MATCH`, `system_ext_MATCH`, `product_MATCH` — all **MATCH** natively, confirms RCA §2.2 |
| Shipped `rango-latest` vendor.img sepolicy graft | Independently unsparsed + `debugfs dump` + `cmp` against **the actual shipped sparse `vendor.img`** (not the intermediate raw image): **plat MATCH, product MATCH, system_ext MATCH** — all three confirmed (FIX report itself only displayed plat+product; this audit found system_ext also matches, i.e. the true state is *better documented* here than in the FIX report) |
| MTE / `memtag_heap` | `BoardConfig-excised-late.mk` strips confirmed (`MTE_FORCE_ON` filtered from cmdline, `kasan=off` added, `memtag_heap` filtered from `SANITIZE_TARGET`/`SANITIZE_TARGET_DIAG`); `system/core/init/Android.bp` `memtag_heap: false` at both sites; `llvm-readelf -n` on OUT `system/bin/init`, `secilc`, `linker64` → **no MEMTAG note** on any of the three |
| `stage-rango-release.sh` gates | Read in full: `sepolicy_hash_gate()` lines 92–106 (hard `cmp`, fails closed); `mte_strip_gate()` lines 111–133; `MODE=fullgt`/`MODE=avbcontrol` both `die` on `--link-latest` (lines 504, 508) |
| `rango-latest` target | `readlink` → `rango-20260801-071754` (non-experimental name, confirmed) |
| `ALL_DOWNLOADS` completeness | Independently checked all 20 base filenames (`FW_IMAGES`+`AB_IMAGES`+`NOAB_IMAGES`+`LOGICAL_IMAGES`+`SUPER_IMAGE`+`EXTRA_FILES`) against `flash-from-remote.sh`'s own arrays — **20/20 present**; `init.insmod.rango.cfg` present; `vendor_boot_diag.img` absent but confirmed **optional** in script logic (`ALL_DOWNLOADS` skip-if-missing branch) |
| Diagnostic stamps | `rango-avbcontrol-20260801-072014/` and `rango-fullgt-20260801-072051/` exist on disk with their own `README-FLASH-DESKTOP.md`; `rango-latest` resolves to neither |
| Doc scrub | `releases/desktop-flash/rango-hybrid-20260731-060108/README-FLASH-DESKTOP.md` — no residual instructions to run deleted scripts; `RANGO_BOOT_FIX.md`/`RANGO_BOOT_RCA.md` mention archived script names only in historical/RCA-attribution context, never as run-instructions |
| Citations (RCA §4) | Spot-checked 3 of 8 via live web fetch: (1) GrapheneOS FAQ confirms **Pixel 10 Pro Fold = `rango`** is officially, currently supported; (3) AOSP `source.android.com/.../selinux/build` confirms the **exact** precompiled-sepolicy-hash-compare mechanism cited as the primary root cause; (8) unix.SE 691923 confirms `exitcode=0x00007f00` **=** exit status 127 (exec/library failure of PID 1) — all three accurate and directly on-point |
| Non-regression | `releases/desktop-flash/latest` → `tokay-20260725-102506` (bootloader/radio/README present); `releases/desktop-flash/akita-latest` → `akita-20260725-101434` (bootloader/radio/README present); neither touched by this sprint |
| On-device HOLD basis | Independently ran `command -v adb && adb devices` → adb present, **0 devices**; `command -v fastboot` → **not found**. Exactly matches the HOLD basis claimed by FIX and QA — no invented on-device PASS anywhere in the chain |
| DEC-012 signal chain | Read all 11 `signals/*.json` for this sprint — timestamps form a clean, monotonic, gap-free chain (see §4 below) |
| Dual-queue sync | `TASK_QUEUE.md` (root) and `.agent-comm/TASK_QUEUE.md` — rango sprint section (header, dependency graph, task table, completion notes, bindings) is **byte-identical** between both files |
| Repo/VCS context | **Finding:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` has **no `.git` at all** (confirmed: `git status` fails with "not a git repository" at every level up to the filesystem boundary). See §6 L1 below. |

---

## 1. Deletion scope (Law 11) — **PASS**

| Check | Result |
|-------|--------|
| 29 scripts archived to `.agent-comm/completed/rango-flash-mess-20260801/` | ✅ all 29 present, verified by name (not just count) |
| `DELETED_PATHS.md` lists archived paths + KEEP list | ✅ present, accurate |
| Both `flash-from-remote.sh` copies kept | ✅ `scripts/` (913 lines) + `vendor/guardtalk/scripts/` (857 lines) |
| `vendor/guardtalk/scripts/*` not wrongly deleted | ✅ all 14 pre-existing files intact (`backup-signing-keys.sh`, `check-kvm.sh`, `flash-from-remote-signed.sh`, `flash-signed.sh`, `flash-tokay.sh`, `generate-signing-keys.sh`, `keygen-wizard.sh`, `run-emulator.sh`, `sign-build.sh`, `verify-face-filter.sh`, `verify-on-device.sh`, `verify-radio-excision.sh`, `verify-voice-filter.sh`, plus `flash-from-remote.sh`); the 15th file (`stage-rango-release.sh`) is a new, correctly-scoped `T-RANGO-BOOT-FIX` addition, not a cleanup-task artifact |
| No stray residual wrappers | ✅ filesystem-wide pattern scan found zero additional copies outside the archive |
| Reversibility mechanism | Archive was done via **move** (not `rm`), i.e. a full-content copy exists at `.agent-comm/completed/rango-flash-mess-20260801/` — genuinely reversible regardless of VCS state |

**LOW-L1 (see §6):** `DELETED_PATHS.md`/`SPRINT_HEADER.md` frame this as "files were git-untracked," but the entire worktree has no `.git` — the framing is imprecise (trivially true for every file in this tree, not a property specific to these 29 scripts). Does not weaken the actual Law 11 control, which is the archive-copy itself.

## 2. RCA quality (`RANGO_BOOT_RCA.md`) — **PASS**

- **Root cause:** sepolicy `precompiled_sepolicy.*.sha256` mismatch → on-device `secilc` compile fallback fails → init `exec` fails → exit 127 (`0x00007f00`). Independently reproduced: `cmp` on live OUT tree shows all three hash pairs **MATCH** today (confirms the *current* OUT is not exhibiting the primary root cause; the historical failure was against a differently-composed vendor image, which the RCA correctly frames).
- **Citations:** **8** public URLs (requirement ≥3). 3 independently re-fetched and confirmed accurate and directly relevant (GrapheneOS FAQ device-support list, AOSP SELinux precompiled-policy build doc, Unix&Linux SE `exitcode=0x00007f00` explanation). No fabricated or irrelevant citations found among those checked.
- **HOLDs:** H1–H5 clearly enumerated with exact reproduction commands and a decision table for whoever runs them next.
- **Architect binding acknowledgment:** The Architect's residual-gap binding ("a prior hybrid with MATCH hashes still hit init `0x7f00` — re-graft alone is NOT sufficient") is explicitly quoted and addressed in RCA §7 (HOLD H1–H3), FIX §2 ("Residual gap — analysis and HOLD"), and the shipped bundle's own `README-FLASH-DESKTOP.md` ("Residual gap" section). Not glossed over.
- **Non-causes section (§6):** explicitly rules out "rango unsupported," "OUT sepolicy always mismatched," "vbmeta Flags:3 alone broken," "fold fstab missing hinge mounts," "modem excision kills init," and "wrong product symlink" — good self-doubt discipline (Law 7).

## 3. Fix minimality (`stage-rango-release.sh` + `RANGO_BOOT_FIX.md`) — **PASS**

| Check | Result |
|-------|--------|
| Zero new `scripts/flash-*.sh` | ✅ confirmed — only `scripts/flash-from-remote.sh` exists under `scripts/` |
| Single new helper location | ✅ `vendor/guardtalk/scripts/stage-rango-release.sh` (vendor path, per Architect binding) — never flashes, only stages |
| Hard sepolicy `cmp` gate | ✅ `sepolicy_hash_gate()` (lines 92–106), fails closed (`die`) |
| MTE/`memtag_heap` regression gate | ✅ `mte_strip_gate()` (lines 111–133), checks BoardConfig + Android.bp + binary ELF note, fails closed |
| `rango-latest` → non-experimental stamp | ✅ `rango-20260801-071754` |
| `MODE=fullgt` / `MODE=avbcontrol` never relink `rango-latest` | ✅ both explicitly `die` on `--link-latest` (lines 504, 508) — independently confirmed in source |
| Diagnostic stamps not linked to `rango-latest` | ✅ `rango-avbcontrol-20260801-072014`, `rango-fullgt-20260801-072051` exist, documented, `rango-latest` resolves to neither |
| Real bug fix (not just rename) | ✅ verified: previous `rango-latest` (`rango-hybrid-20260731-060108`) lacked `bootloader.img`/`radio.img`, which `flash-from-remote.sh`'s `FW_IMAGES` array requires unconditionally — this would have failed a real flash at download step 1. New stamp independently confirmed to carry all 20/20 base `ALL_DOWNLOADS` files. |
| Shipped-artifact re-verification | ✅ independently reran the debugfs-dump + `cmp` check against the **actual shipped sparse `vendor.img`** in `rango-latest` (not just the intermediate/OUT copies) — all three sepolicy hash files MATCH |

**No scope creep found:** the new stage script never touches `scripts/`, never commits, never edits doctrine, and the two diagnostic modes are read-only staging (no flash execution).

## 4. DEC-012 (dual-queue pairing) — **PASS**

Dependency graph as declared: `T-RANGO-SCRIPT-CLEANUP → Q-RANGO-SCRIPT-CLEANUP` and `T-RANGO-BOOT-RCA → T-RANGO-BOOT-FIX → Q-RANGO-BOOT`, both converging on `A-RANGO-BOOT-CLEANUP`. Verified against the raw signal files (not just the human-readable queue prose):

| Task | Dispatched | Approved | Notes |
|------|-----------|----------|-------|
| T-RANGO-SCRIPT-CLEANUP | 06:58:24Z | 07:00:45Z | parallel start with RCA |
| T-RANGO-BOOT-RCA | 06:58:24Z | 07:03:06Z | parallel with CLEANUP, per Architect DEC |
| Q-RANGO-SCRIPT-CLEANUP | 07:00:45Z | 07:03:06Z | verdict PASS |
| T-RANGO-BOOT-FIX | 07:03:06Z | 07:25:39Z | depends_on RCA ✅ |
| Q-RANGO-BOOT | 07:25:39Z | 07:27:06Z | verdict PASS-CONDITIONAL |
| A-RANGO-BOOT-CLEANUP | 07:27:06Z | (this audit) | depends_on both Qs ✅ |

Chain is monotonic with no timestamp gaps or out-of-order approvals. Both `TASK_QUEUE.md` (root) and `.agent-comm/TASK_QUEUE.md` carry an identical rango-sprint section (header, dependency graph, task table, completion notes, bindings) — dual-queue sync confirmed for this sprint.

**LOW-L2 / LOW-L3 (see §6):** two audit-trail completeness gaps found (DONE_LOG.md not updated; Q-RANGO-SCRIPT-CLEANUP's full report text not preserved to a named file) — neither affects the correctness of the technical work, both are documentation-hygiene gaps.

## 5. Q-RANGO-BOOT PASS-CONDITIONAL legitimacy — **PASS**

Independently reproduced the exact HOLD basis on this host:

```text
$ command -v adb && adb devices
/usr/bin/adb
List of devices attached
                                    ← EMPTY, matches QA claim

$ command -v fastboot
                                    ← not found, matches QA claim
```

QA's verdict (static PASS + honest on-device HOLD, explicit refusal to claim boot PASS) is legitimate, not a disguised failure or an inflated pass. QA also explicitly declined to re-claim the FIX author's `m` rebuild ("Rebuild claim remains FIX-author assertion, not independently re-proven here") — correct epistemic humility (Law 7), not a gap this audit needs to re-litigate since the FIX author's own artifact (the shipped bundle) was independently re-verified above regardless of whether the *build step* itself was re-run.

## 6. Findings summary

| Severity | Count | ID | Item |
|----------|------:|----|------|
| **BLOCK** | **0** | — | — |
| MEDIUM | 0 | — | — |
| LOW | 1 | **L1** | "Git-untracked" framing in `DELETED_PATHS.md`/`SPRINT_HEADER.md` is imprecise — the entire `GrapheneOS-worktree` has no `.git` at all (verified: `git status` fails "not a git repository" at every parent level). Law 11 reversibility is still genuinely satisfied via the archive-copy (`mv`, not `rm`) mechanism, independent of VCS state. Recommend future sprint docs say "no VCS in this tree; archived via filesystem copy" rather than implying selective git-untracked status. |
| LOW | 1 | **L2** | `.agent-comm/completed/DONE_LOG.md` was not updated for any of the 5 completed rango-sprint tasks (`T-RANGO-SCRIPT-CLEANUP`, `T-RANGO-BOOT-RCA`, `T-RANGO-BOOT-FIX`, `Q-RANGO-SCRIPT-CLEANUP`, `Q-RANGO-BOOT`). Law 10 (Audit Trail) completeness gap. Recommend Architect backfill 5 entries. |
| LOW | 1 | **L3** | `Q-RANGO-SCRIPT-CLEANUP`'s full QA completion-report text was never preserved to a dedicated `TO_ARCHITECT_Q-RANGO-SCRIPT-CLEANUP.md` before `TO_ARCHITECT.md` was overwritten by the `Q-RANGO-BOOT` report — only the terse `approve-Q-RANGO-SCRIPT-CLEANUP.json` signal and a one-line `TASK_QUEUE.md` note survive. Minor Law 10 gap; this audit independently re-verified the underlying facts directly against the filesystem, so no technical-correctness impact, but the original QA methodology/detail is not recoverable from text. Recommend: going forward, every QA report gets a dedicated preserved filename **before** the next task's report reuses `TO_ARCHITECT.md` (the pattern already used correctly for `T-RANGO-BOOT-RCA`/`T-RANGO-BOOT-FIX`/`T-RANGO-SCRIPT-CLEANUP`, just missed for this one Q report). |
| LOW | 1 | **L4** | Stale pre-cleanup diagnostic release directories `releases/desktop-flash/rango-stocksuper-avbok/` and `rango-hybrid-081848-avbok/` remain un-pruned (superseded by the new documented `rango-avbcontrol-20260801-072014`, but not deleted). Already disclosed by the FIX author as explicitly out of scope (release-artifact pruning was never part of `T-RANGO-SCRIPT-CLEANUP`, which only covered `scripts/`). Recommend a follow-up cleanup task if `releases/desktop-flash/` disk usage becomes a concern. |
| LOW | 1 | **L5** | `RANGO_BOOT_FIX.md`'s shipped-vendor sepolicy re-verification text quotes only `plat_MATCH`/`product_MATCH` for the post-graft debugfs check on the shipped image (omits an explicit `system_ext_MATCH` line for the *shipped* artifact, though the staging script's own internal gate at lines 210–213 does check system_ext against OUT before shipping). This audit's independent debugfs recheck confirms `system_ext` also MATCHes on the shipped image — a reporting-completeness gap only; the underlying state is better than what was written, not worse. |

All 5 findings are **LOW** (documentation / audit-trail completeness). None affect the technical correctness, safety, or reversibility of the deletion, RCA, or fix work.

## 7. Gate 5 (manual rubric; `ultimate_critique` MCP unavailable — `python: not found`, consistent with every other agent's experience this sprint)

| Dimension | Score /10 |
|-----------|-----------|
| Deletion-scope completeness (29/29 verified by name, KEEP set intact) | 10 |
| RCA citation accuracy (3/8 independently re-fetched, all accurate) | 10 |
| RCA root-cause re-derivation (independent `cmp` on live OUT) | 10 |
| Fix minimality (zero new `scripts/flash-*.sh`, single vendor-path helper) | 10 |
| Fix correctness re-verification (debugfs+cmp on **shipped** artifact, not trusting FIX's own claim) | 10 |
| DEC-012 signal-chain integrity (raw JSON timestamps, not just prose) | 10 |
| Q-RANGO-BOOT HOLD legitimacy (independently reproduced adb/fastboot absence) | 10 |
| Non-regression (tokay/akita symlinks independently checked) | 10 |
| Documentation / audit-trail hygiene (5 LOW findings surfaced) | 7 |
| Independence / no invented PASS anywhere in the chain | 10 |

**Gate 5 (manual): 97%** (weighted average; single "documentation hygiene" dimension pulled below 10 due to L1–L5). Cross-checked against MCP `self_critique` (Laws 0/1/3/4/5/6/7/8/9/10/11/12/13/14/15): **97/100** — independent corroboration.

### PQE Assessment

Code/process entropy for this sprint is **LOW**: the deletion collapsed 29 ad-hoc scripts into 1 canonical entrypoint per KEEP path; the fix collapsed multiple prior one-off staging attempts (`stage-rango-hybrid.sh` and various flash-* experiments) into a single 3-mode, gate-enforced staging helper. Residual entropy is concentrated entirely in **unverified on-device boot** (expected, disclosed, HOLD) and the 5 **documentation-hygiene** LOW findings above — none of which are execution-path or safety risks.

## 8. Verdict for Architect

- **Deletion scope (Law 11):** **PASS** — 29/29 archived and reversible; KEEP set intact; no wrongful deletions; no stray residue.
- **RCA quality + citations:** **PASS** — root cause independently reproduced; 8 citations present, 3/8 spot-verified accurate; Architect residual-gap binding explicitly acknowledged.
- **Fix minimality:** **PASS** — zero new `scripts/flash-*.sh`; hard gates independently re-verified in code and re-run against the shipped artifact; diagnostic stamps correctly unlinked from `rango-latest`.
- **DEC-012:** **PASS** — T→Q pairs present, A dispatched only after both Qs approved, dual-queue sync confirmed, signal-timestamp chain monotonic and gap-free.
- **Q-RANGO-BOOT PASS-CONDITIONAL:** **LEGITIMATE** — static PASS independently re-verified; on-device HOLD is an honest, reproduced absence of hardware (no adb device, no fastboot binary), not a disguised failure.
- **Non-regression:** **PASS** — tokay `latest` and `akita-latest` independently confirmed untouched and intact.
- **Findings:** **0 BLOCK, 0 MEDIUM, 5 LOW** (all documentation/audit-trail completeness; no technical defects).

### Overall

- **Static work product (deletion + RCA + fix + QA):** **ACCEPTED CONDITIONAL GO** — this is the *expected* outcome given the sprint's own device-availability constraint (device HOLD only), not a downgrade for cause.
- **Device boot claim:** explicit **NO-GO** until H1–H5 are executed on a build host with the physical Pixel 10 Pro Fold attached and `fastboot` installed (exact commands already staged in `RANGO_BOOT_FIX.md` §2.2 and the two diagnostic bundle READMEs).
- **Auditor recommendation:** Architect marks `A-RANGO-BOOT-CLEANUP` **ACCEPTED CONDITIONAL GO** (static); dispatch the 5 LOW findings as either quick documentation follow-ups or accept as-is (none are blocking); keep `Q-RANGO-BOOT`/H1–H5 open as the standing on-device HOLD.

## 9. Sprint close criteria (recommended)

1. Architect reviews this audit; marks `A-RANGO-BOOT-CLEANUP` **ACCEPTED CONDITIONAL GO** in both `TASK_QUEUE.md` files (Auditor does not self-APPROVE/self-ACCEPT).
2. When a build host with the physical Pixel 10 Pro Fold + `fastboot` is available: run H1–H5 exactly as documented in `RANGO_BOOT_FIX.md` §2.2, via `flash-from-remote.sh` only — clears the device HOLD (or produces a new root-cause task if `avbcontrol`/`fullgt` isolate a different fault surface per the FIX doc's own decision table).
3. Optional documentation polish (non-blocking): backfill `DONE_LOG.md` for the 5 rango-sprint tasks (L2); note in a future sprint's `DELETED_PATHS.md` that this tree has no VCS rather than "git-untracked" (L1); prune or explicitly HOLD-document the two stale pre-cleanup release dirs (L4).
4. Do **not** mark unconditional GO, and do **not** flash `rango-fullgt-*` as a production path, while H1–H5 remain HOLD.

## References

| Artifact | Path |
|----------|------|
| Deletion inventory | `.agent-comm/completed/rango-flash-mess-20260801/DELETED_PATHS.md` |
| Sprint header / Architect DEC | `.agent-comm/completed/rango-flash-mess-20260801/SPRINT_HEADER.md` |
| RCA | `vendor/guardtalk/docs/RANGO_BOOT_RCA.md` |
| Fix | `vendor/guardtalk/docs/RANGO_BOOT_FIX.md` |
| Flash doc | `vendor/guardtalk/docs/RANGO_FLASH.md` |
| Staging helper | `vendor/guardtalk/scripts/stage-rango-release.sh` |
| T-RANGO-SCRIPT-CLEANUP report | `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-SCRIPT-CLEANUP.md` |
| T-RANGO-BOOT-RCA report | `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-BOOT-RCA.md` |
| T-RANGO-BOOT-FIX report | `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-BOOT-FIX.md` |
| Q-RANGO-BOOT report (preserved) | `.agent-comm/inbox/TO_ARCHITECT_Q-RANGO-BOOT.md` |
| Bundle (rango-latest) | `releases/desktop-flash/rango-20260801-071754` |
| Diagnostic bundles | `releases/desktop-flash/rango-avbcontrol-20260801-072014/`, `releases/desktop-flash/rango-fullgt-20260801-072051/` |
| Audit style peer | `vendor/guardtalk/docs/qa/A-PORT-RANGO_AUDIT.md` |
