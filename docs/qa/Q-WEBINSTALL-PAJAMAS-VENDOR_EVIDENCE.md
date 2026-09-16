# Q-WEBINSTALL-PAJAMAS-VENDOR Evidence

**Task:** Q-WEBINSTALL-PAJAMAS-VENDOR  
**QA run:** 2026-08-23T15:00:00Z–2026-08-23T15:13:22Z (independent re-run; did **not** trust T or Architect 291/1)  
**Artifact under test:** `vendor/guardtalk/web-installer/design/pajamas/` + `scripts/build-site.sh` (read-only) + emitted `dist/site`  
**Depends on:** T-WEBINSTALL-PAJAMAS-VENDOR APPROVED  
**QA wrote:** `vendor/guardtalk/web-installer/test/pajamas-vendor.test.ts` (9 tests), this file  
**Not edited:** `routes/`, `scripts/build-site.sh`, `lib/`, `src/`, doctrine, governance laws/gates, secrets  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**QA status:** **REVIEW only** (never APPROVED)

## Governance

- GIP-0 VERIFIED: workflow `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q cards, PROTOCOL/ROLES, memory-bank (`activeContext.md`, `progress.md` tail, `decisions.md` DEC-010/011/012, `systemPatterns.md`, `projectBrief.md`), AGENTS.md.
- Prompt-injection shield: **TOOL UNAVAILABLE** (`Not connected`). Manual scan: no role-override / delimiter / encoding injection in the packet. Dispatch is Architect-authoritative (ADR-016).
- Gate -1: `gate_enforcer` **TOOL UNAVAILABLE** (`Not connected`). Packet + human skip of `ultimate_critique` in force. Proceeded with manual Gate -1 acknowledgment. Did **not** call `ultimate_critique`. Did **not** fabricate a Gate 5 score.
- Packet path lock: writes only under `vendor/guardtalk/docs/qa/`, `vendor/guardtalk/web-installer/test/`, `.agent-comm/inbox/`, both `TASK_QUEUE.md`. Memory-bank write skipped (not in packet allowlist).

## Environment

| Item | Independent observation |
|------|-------------------------|
| Host | Linux, cwd `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer` |
| Node | `/home/openstatestack/.local/node/bin/node` v22.12.0 (`npm` 10.9.2) |
| Git root | `vendor/guardtalk` (AOSP `.repo` project). Workspace root has no `.git`. |
| Command PATH | `export PATH=/home/openstatestack/.local/node/bin:$PATH` |
| Live device | **none** |
| Parallel agent | F-WEBINSTALL-PAJAMAS-TEMPLATES was editing `routes/`, `wizard/styles.css`, `lib/ui/` during this run |

---

## Verdict

**PASS with HOLD**

T-WEBINSTALL-PAJAMAS-VENDOR claims were independently re-proven: vendor tree is real `--gl-*` (114 unique), SOURCE.txt hashes rematch recomputed sha256 **and** a live fetch of `index-BFboFyqJ.css`, `routes:build` fail-closes with the missing-tree error, fresh `dist/site` has zero remote design/font imports, D-006 is exact in every emitted HTML, flash/custody paths are untouched, `LIVE_FLASH_CLAIMED === false`.

**HOLD (not a T-VENDOR fail):**

- Full suite is **not** green: `# tests 301` `# pass 298` `# fail 2` `# skipped 1`. Both fails are F-TEMPLATES restyle collisions (see C12), not flash/custody/vendor-tree defects.
- No live-flash PASS (honesty).
- `reset.css` header still says it is **not** concatenated; current `build-site.sh` **does** concatenate it (F edited the script after T). Fail-closed still covers `reset.css`. Residual for Architect / F, not a missing vendor tree.

---

## Check matrix

| ID | Check | Expected | Actual | Verdict |
|----|-------|----------|--------|---------|
| C1 | SOURCE.txt URLs + date 2026-08-23 + file list/hashes | present | 4 URLs; Fetch date 2026-08-23; 8 hashed files | **PASS** |
| C2 | Recompute sha256 compiled CSS + tokens + templates + components | match SOURCE.txt | all 4 match (plus reset/catalog/tokens.json) | **PASS** |
| C3 | Live fetch compiled CSS vs vendor | identical | `CMP_COMPILED_CSS_IDENTICAL`; HTML sha256 + ETag also match SOURCE.txt | **PASS** |
| C4 | Unique `--gl-*` in tokens.css | real `--gl-*` tokens | **114** unique; tokens.json also 114 | **PASS** |
| C5 | Extracted CSS has no `url(http`, `@import url(http`, `design.guardtalk.io`, `fonts.googleapis` | zero | empty rg on tokens/templates/components/reset/compiled CSS | **PASS** |
| C6 | `npm run routes:build` with vendor dir aside | exit 1 + missing-tree error | `NPM_FAILCLOSED_EXIT=1`; `error: missing Pajamas vendor tree: …/design/pajamas`; restored | **PASS** |
| C7 | Restore + rebuild | exit 0 | `REBUILD_EXIT=0`; `site written to …/dist/site` | **PASS** |
| C8 | grep `dist/site` remote design/font imports | zero | empty; emitted CSS has 1212 `--gl-` refs | **PASS** |
| C9 | D-006 exact in every emitted HTML | 6/6 | all 6 `D006_OK` | **PASS** |
| C10 | git name-only avb/fastboot/keys/install-state/flash-runner | empty | empty (from `vendor/guardtalk`) | **PASS** |
| C11 | `npx tsc --noEmit` | exit 0 | `TSC_EXIT=0` (final run) | **PASS** |
| C12 | Existing `test/*.test.ts` still green | fail 0 | 298 pass / 2 fail / 1 skip. Fails: D-005 `\bdefault\b` vs `gl-button--default-dashed`; update step-3 expected 2 flow buttons, got 0. Both F restyle. New vendor tests **9/9**. | **HOLD** |
| C13 | No live-flash PASS | honesty | none run; `LIVE_FLASH_CLAIMED === false` | **HOLD** (honesty) |
| C14 | CATALOG.txt may cite source URL (docs, not CSS) | docs-only | `templates/CATALOG.txt:2` Source URL; not imported at runtime | **PASS** (note) |

**Overall (host/mocked):** **PASS** with **HOLD** (suite-green contaminated by parallel F; no live-flash).

---

## SOURCE.txt + recomputed hashes

SOURCE.txt records (fetched 2026-08-23):

```text
https://design.guardtalk.io/pajamas/
https://design.guardtalk.io/pajamas/#/templates/
https://design.guardtalk.io/pajamas/assets/index-BFboFyqJ.css
https://design.guardtalk.io/pajamas/assets/index-D1E98FVb.js
```

Independent `sha256sum` (QA, not copied from the T report):

```text
6628d695ba3eb77f4113ccc2b5d9db64b8b13039effe0662a609ce60f16d6a46  design/pajamas/compiled/index-BFboFyqJ.css
01d2c7c66184ffef36a0ccfe05d6d1c1c4405bf3d1a9d97b89c0a2a19c7566f4  design/pajamas/tokens.css
99d463b0fc63a85bfd4af47321bc5b2698a83ebf6582eb6983e9d31e81194d67  design/pajamas/templates.css
cc6634cb0df3b788b97b378e5b4881bd2cbe6352416202954561fae56e4288e3  design/pajamas/components.css
071b14e2acbf1e35fb74b8e019a93a82f15a695c4c6026bd783b50e229bbcc5e  design/pajamas/reset.css
90664fe417af2cd5983531218528c5f025b9462c07d8f91ad94789cea4a65cb1  design/pajamas/tokens.json
ef9412eb279e285eb9ab48d4a3ed9c64a43d439290656d6a72fc370abeaa4146  design/pajamas/templates/CATALOG.json
08978f524bd8b7f4b8638fbcc1174af4d577a0e4949d604f0ec9136825120f65  design/pajamas/templates/CATALOG.txt
```

Byte sizes also match SOURCE.txt (150350 / 5521 / 13843 / 133075 / 770 / 5573 / 3904 / 2650).

Live fetch 2026-08-23T15:00Z:

```text
curl_html_exit=0
89c9066261d2a7dd49419b74620f7e0a66fcadd06db26d5b4ca1f588bbbd186c  /tmp/q-pajamas-index.html
etag: "9e73b6a2abb29681279da7528804f668-ssl"
content-length: 936
curl_css_exit=0
6628d695ba3eb77f4113ccc2b5d9db64b8b13039effe0662a609ce60f16d6a46  /tmp/q-pajamas-index-BFboFyqJ.css
content-length: 150350
CMP_COMPILED_CSS_IDENTICAL
```

Published HTML still has Google Fonts `<link>`s (googleapis / gstatic). SOURCE.txt correctly says those were **not** vendored. Live compiled CSS has **zero** `url(http` / `@import url(http` / `fonts.googleapis`.

Unique `--gl-*` in `tokens.css`: **114** (same count in `tokens.json`).

---

## Raw command output (final independent run)

Working directory: `vendor/guardtalk/web-installer`  
`export PATH=/home/openstatestack/.local/node/bin:$PATH`  
Timestamp: **2026-08-23T15:13:00Z–15:13:22Z**

```text
===== TSC =====
TSC_EXIT=0
===== EXACT npm run routes:build FAIL-CLOSED =====
MOVED design/pajamas aside

> @guardtalk/web-installer-flashcore@0.1.0 routes:build
> bash scripts/build-site.sh

error: missing Pajamas vendor tree: /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer/design/pajamas
NPM_FAILCLOSED_EXIT=1
RESTORED design/pajamas
PAJAMAS_RESTORED=yes
===== REBUILD =====

> @guardtalk/web-installer-flashcore@0.1.0 routes:build
> bash scripts/build-site.sh

site written to /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer/dist/site
REBUILD_EXIT=0
===== DIST GREP =====
DIST_GREP_DONE
===== D-006 =====
D006_OK dist/site/index.html
D006_OK dist/site/install/index.html
D006_OK dist/site/install/recover/index.html
D006_OK dist/site/install/update/index.html
D006_OK dist/site/install/verify-device/index.html
D006_OK dist/site/threat-model/index.html
===== EMITTED CSS has --gl- and no remote =====
1212
EMITTED_CSS_NO_REMOTE
===== FULL SUITE =====
# tests 301
# pass 298
# fail 2
# skipped 1
TEST_EXIT=1
===== SHA256 REQUIRED =====
6628d695ba3eb77f4113ccc2b5d9db64b8b13039effe0662a609ce60f16d6a46  design/pajamas/compiled/index-BFboFyqJ.css
01d2c7c66184ffef36a0ccfe05d6d1c1c4405bf3d1a9d97b89c0a2a19c7566f4  design/pajamas/tokens.css
99d463b0fc63a85bfd4af47321bc5b2698a83ebf6582eb6983e9d31e81194d67  design/pajamas/templates.css
cc6634cb0df3b788b97b378e5b4881bd2cbe6352416202954561fae56e4288e3  design/pajamas/components.css
```

`rg -n "design.guardtalk.io|@import url\\(http|fonts.googleapis" dist/site` printed nothing (DIST_GREP_DONE with no hits).

D-006 canonical string confirmed in every emitted HTML:

`default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'`

---

## Earlier fail-closed attempts (honest residue)

While F had unused `GL_BTN_*` imports, `npx tsc -p tsconfig.routes.json` failed first (`TSC_EXIT=2` / `NPM_FAILCLOSED_EXIT=2`) so the missing-tree branch was not reached. That is **F WIP**, not a fail-open vendor check.

A tsc-shim probe of the **actual** `scripts/build-site.sh` (npx tsc no-op only) also produced:

```text
SHIM_FAILCLOSED_EXIT=1
error: missing Pajamas vendor tree: /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer/design/pajamas
RESTORED design/pajamas
```

The final un-shimmed `npm run routes:build` probe (C6) is the AC-authoritative one.

---

## Git name-only (flash / custody / machine)

From `vendor/guardtalk` (`git rev-parse --show-toplevel` = that project):

```text
git diff --name-only -- \
  web-installer/src \
  web-installer/lib/avb \
  web-installer/lib/fastboot \
  web-installer/lib/keys \
  web-installer/lib/install-state \
  web-installer/routes/install/flash-runner.ts
# (empty)
NO_FLASH_CUSTODY_IN_DIFF
NO_FLASH_CUSTODY_STAGED
NO_UNTRACKED_FLASH_CUSTODY
```

T-VENDOR-touched (this session):

```text
 M web-installer/NOTICE
 M web-installer/scripts/build-site.sh
?? web-installer/design/pajamas/
?? web-installer/test/pajamas-vendor.test.ts
```

F-TEMPLATES was also dirty during the run (`lib/ui/chips.ts`, `lib/ui/rail.ts`, `lib/ui/pajamas.ts`, `routes/install/styles-route.css`, `wizard/styles.css`). Those are **not** avb/fastboot/keys/install-state/flash-runner.

`src/types.ts:119` `export const LIVE_FLASH_CLAIMED = false;`

---

## New tests

`vendor/guardtalk/web-installer/test/pajamas-vendor.test.ts` — **9/9 pass**

1. SOURCE.txt URLs / 2026-08-23 / file-list hashes  
2. Recomputed sha256 + byte sizes  
3. 114 unique `--gl-*`  
4. No remote refs in extracted/compiled CSS  
5. `build-site.sh` fail-closed text (missing tree / empty file / no `--gl-*` / remote grep)  
6. Vendor tree file set  
7. D-006 exact in CSP constant + build script + route shells  
8. `LIVE_FLASH_CLAIMED === false`  
9. Extracted fail-closed **block** spawned with a missing path → exit 1 + missing-tree stderr  

Did **not** restyle product pages. Did **not** move the vendor tree inside the test runner (node:test files can run in parallel).

---

## Existing suite (final)

```text
# tests 301
# pass 298
# fail 2
# skipped 1
TEST_EXIT=1
```

| # | File | Result |
|---|------|--------|
| skip | `keys.test.ts` `pagehide hook: installs and uninstalls cleanly when window exists` | `# SKIP` (no `window` in Node) — same skip class as Architect 291/1 |
| fail | `route-install-early.test.ts` `step 3: no card pre-selected anywhere in the markup (D-005)` | F added `gl-button--default-dashed`; test forbids `/\bdefault\b/i` |
| fail | `route-update.test.ts` `step 3 markup contains zero generate-flow affordances and the lockout reason` | expected 2 flow buttons, got 0 (F restyle of update step 3) |

New vendor tests are included in the 301. Pre-existing flash/custody/orchestrator/avb/keys tests stayed green.

---

## Self-critique note (no Gate 5 score)

Human directive: skip `ultimate_critique`; do not fabricate a Gate 5 score. **No score is reported.**

Manual COT-006:

1. CLASSIFY: QA evidence + new tests  
2. CORE LAWS: Law 0 (Architect dispatch only); Law 2 (allowed paths only); Law 3 (fail-closed proven); Law 4 (remote-ref / CSP adversarial); Law 7 (did not trust T; live-fetched CSS; moved the tree); Law 11 (tests removable); Law 12 (doctrine/governance untouched); Law 13 (no harmful fixtures)  
3. EXTENDED: Law 16 (vendor tests pass; suite HOLD on F collisions); Law 17 (no PII); Law 19 (this file)  
4. GATES: Gate -1 MCP unavailable; Gate 5 `ultimate_critique` skipped by human; no fabricated score  
5. SCOPE: matches Q card  
6. CONFIDENCE: 8/10 on T-VENDOR proofs; 7/10 on “suite green” (explicit HOLD)  
7. VERDICT: **PASS / HOLD**

`hallucination_guard` / `self_critique` MCP: **TOOL UNAVAILABLE** (`Not connected`). Every numeric claim above was copied from command output in this session.

### PQE Assessment: Code Entropy **LOW** (vendor tree) / **MEDIUM** (build vs F)

Vendor CSS is static, hashed, fail-closed at build. Entropy rise: F is mutating `build-site.sh` (now concatenates `reset.css` while `reset.css` header still says it does not) and route class names, which broke two existing tests.

---

## AC checklist

- [x] Evidence file PASS/FAIL/HOLD + raw command output  
- [x] Vendor tree + SOURCE.txt independently inspected (hashes recomputed; live CSS matched)  
- [x] `routes:build` fail-closed probe (missing tree, exit 1)  
- [x] grep `dist/site` clean of remote design/font imports  
- [x] D-006 intact (6/6 emitted HTML)  
- [~] Existing suite still green — **HOLD** (2 F-TEMPLATES fails; 9/9 new vendor tests pass; tsc 0)  
- [x] No live-flash PASS  

---

## Files

- Evidence: `vendor/guardtalk/docs/qa/Q-WEBINSTALL-PAJAMAS-VENDOR_EVIDENCE.md`  
- Tests: `vendor/guardtalk/web-installer/test/pajamas-vendor.test.ts`  
- Reports: `.agent-comm/inbox/TO_ARCHITECT.md` and `.agent-comm/inbox/TO_ARCHITECT_Q-WEBINSTALL-PAJAMAS-VENDOR.md`
