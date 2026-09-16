# Q-WEBINSTALL-PAJAMAS-CONTRAST Evidence

**Task:** Q-WEBINSTALL-PAJAMAS-CONTRAST  
**QA run:** 2026-08-23T16:05:00Z–2026-08-23T16:25:00Z (independent; did **not** trust Frontend contrast math)  
**Artifact under test:** installer chrome + emitted `dist/site/install/styles-route.css` + vendored `--gl-*` tokens  
**Depends on:** F-WEBINSTALL-PAJAMAS-CONTRAST APPROVED (hash-pin exception ACCEPTED)  
**QA wrote:** `vendor/guardtalk/web-installer/test/pajamas-contrast.test.ts` (5 tests), this file  
**Not edited:** `routes/`, `lib/`, `scripts/`, `wizard/`, `design/pajamas/reset.css`, doctrine, governance laws/gates, secrets  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**QA status:** **REVIEW only** (never APPROVED)  
**Gate 5:** Human skip of `ultimate_critique` is in force. **No Gate 5 score** (not fabricated).

## Governance

- GIP-0 VERIFIED: Loaded `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q/F cards, PROTOCOL/ROLES, memory-bank (`activeContext.md`, `progress.md` tail, `decisions.md` DEC-010..014), AGENTS.md. `governance-condensate.md` absent.
- Prompt-injection shield: **TOOL UNAVAILABLE** (`Not connected`). Manual scan: no role-override / delimiter / encoding injection. Dispatch is Architect-authoritative (ADR-016).
- Gate -1: `gate_enforcer` **TOOL UNAVAILABLE** (`Not connected`). Guardian HTTP fallback returned `Permanent Redirect`. Manual Gate -1: Architect-dispatched packet, scope-locked, no flash/custody.
- Hallucination guard: **TOOL UNAVAILABLE** (`Not connected`). Every numeric claim below was re-run in this session against files / command output.
- Packet path lock: writes only under `vendor/guardtalk/docs/qa/`, `vendor/guardtalk/web-installer/test/`, `.agent-comm/inbox/`, both `TASK_QUEUE.md`. Memory-bank write skipped (not in packet allowlist).
- Did **not** call `ultimate_critique`. Did **not** fabricate a Gate 5 score.

## Environment

| Item | Independent observation |
|------|-------------------------|
| Host | Linux, cwd `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer` |
| Node | `/home/openstatestack/.local/node/bin/node` on `PATH` |
| Command PATH | `export PATH=/home/openstatestack/.local/node/bin:$PATH` |
| Live device | **none** |
| Browser overlay | **not required** this card (contrast + cascade, not pixel overlay) |

---

## Verdict

**PASS / HOLD (honesty: no live-flash)**

Independent WCAG 2.1 relative-luminance math rematches F’s rounded claims. Confirm CTA `#0A0B0C` on `#C3FF61` is **16.69:1** (≥4.5:1). Hover `#A6E83C` is **13.35:1**. Active `#7BAE26` is **7.43:1**. Secondary/dashed border token `--gl-color-neutral-500` `#6B727C` is **4.52:1** vs `#F6F7F5` and **4.86:1** vs `#FFFFFF` (≥3:1). Lighter `--gl-color-neutral-400` `#A7AEB8` still **fails** 3:1 (2.08 / 2.24) — rejection of that token is justified.

Emitted `dist/site/install/styles-route.css` has the **later** installer override `.gl-button--confirm-primary { color: var(--gl-button-confirm-text); }` at index **160512**, after published `color:var(--gl-action-primary-text)` at index **23272**. No invented hex in `routes/install/styles-route.css` or `wizard/styles.css`. Column still `min(720px, calc(100% - 2 * var(--gl-spacing-8)))` (DEC-014).

`reset.css` sha256 **matches** the Architect-accepted pin `baa208696f550d219495495c6e89e7d48386569916e8dea4d2e4fbe9087b071b` (767 bytes). Reconstructing the pre-L3 header (`NOT concatenated into dist — would restyle route HTML`) restores the Q-VENDOR hash `071b14e2acbf1e35fb74b8e019a93a82f15a695c4c6026bd783b50e229bbcc5e` at 770 bytes. CSS rules are unchanged and match the published compiled reset block. Comment-only confirmed.

D-006 exact 6/6. `dist/site` grep clean. `tsc` 0. Suite **312 pass / 0 fail / 1 skip** (313 tests; +5 contrast pins vs F’s 307/1). `LIVE_FLASH_CLAIMED === false`. No live USB flash. No live-flash PASS.

---

## Check matrix

| ID | Check | Expected | Actual | Verdict |
|----|-------|----------|--------|---------|
| C1 | H1 default `#0A0B0C` on `#C3FF61` ≥4.5:1 | ≥4.5; F claims 16.69:1 | **16.693843 → 16.69:1** | **PASS** |
| C2 | H1 hover `#0A0B0C` on `#A6E83C` ≥4.5:1 | ≥4.5; F claims 13.35:1 | **13.347256 → 13.35:1** | **PASS** |
| C3 | H1 active `#0A0B0C` on `#7BAE26` ≥4.5:1 | ≥4.5; F claims 7.43:1 | **7.433375 → 7.43:1** | **PASS** |
| C4 | Published fail still <4.5 (formula sanity) | ~1.10:1 | **1.098014 → 1.10:1** | **PASS** |
| C5 | Later override after published confirm ink | override index > published | 160512 > 23272 | **PASS** |
| C6 | L2 `#6B727C` vs `#F6F7F5` / `#FFFFFF` ≥3:1 | ≥3; F claims 4.52 / 4.86 | **4.520191 / 4.857589** | **PASS** |
| C7 | `--gl-color-neutral-400` still fails 3:1 | <3; F claims 2.08 / 2.24 | **2.081161 / 2.236503** | **PASS** (rejection holds) |
| C8 | No invented hex in route + wizard chrome | zero `#RRGGBB` | `rg` empty on both files | **PASS** |
| C9 | Column still `min(720px, …)` (DEC-014) | held | `min(720px, calc(100% - 2 * var(--gl-spacing-8)))` | **PASS** |
| C10 | reset.css sha256 + 767 bytes | pin match | `baa20869…` / 767 | **PASS** |
| C11 | Pin is comment-only vs published rules | rules unchanged | old-header recon → `071b14e2…` / 770; rules == compiled reset | **PASS** |
| C12 | D-006 exact in every emitted HTML | 6/6 | all 6 `D006_OK` | **PASS** |
| C13 | `dist/site` remote design/font | zero | empty `rg` | **PASS** |
| C14 | `npx tsc --noEmit` | exit 0 | `TSC_EXIT=0` | **PASS** |
| C15 | `test/*.test.ts` green | fail 0 | `# tests 313` `# pass 312` `# fail 0` `# skipped 1` | **PASS** |
| C16 | `LIVE_FLASH_CLAIMED === false` | false | `export const LIVE_FLASH_CLAIMED = false;` | **PASS** |
| C17 | No live-flash PASS | honesty | none run | **HOLD** (honesty) |

**Overall:** **PASS**. **HOLD** live-flash honesty only. Not a live-flash GO.

---

## Raw contrast math (WCAG 2.1)

Independent Python (not Frontend). sRGB linearize: `c ≤ 0.04045 → c/12.92` else `((c+0.055)/1.055)^2.4`.  
`L = 0.2126 R + 0.7152 G + 0.0722 B`. Ratio = `(L_lighter + 0.05) / (L_darker + 0.05)`.

Token resolution from `design/pajamas/tokens.css` (vendored, not invented):

| Token chain | Hex |
|-------------|-----|
| `--gl-button-confirm-text` → `--gl-action-confirm-text` → `--gl-color-neutral-1000` | `#0A0B0C` |
| `--gl-button-confirm-bg` → `--gl-action-confirm-bg` → `--gl-color-brand-500` | `#C3FF61` |
| `--gl-button-confirm-bg-hover` → `--gl-action-confirm-bg-hover` → `--gl-color-brand-600` | `#A6E83C` |
| `--gl-action-confirm-bg-active` → `--gl-color-brand-700` | `#7BAE26` |
| `--gl-action-primary-text` → `--gl-color-neutral-50` | `#F6F7F5` |
| `--gl-color-neutral-500` | `#6B727C` |
| `--gl-color-neutral-400` | `#A7AEB8` |
| `--gl-color-neutral-50` / `--gl-color-neutral-0` | `#F6F7F5` / `#FFFFFF` |

```text
pair                         fg/bg                         Lfg        Lbg      ratio
published FAIL               #F6F7F5 on #C3FF61       0.927069   0.839852   1.098014  (1.10:1)
  RGB #F6F7F5=(246,247,245)  #C3FF61=(195,255,97)
H1 confirm default           #0A0B0C on #C3FF61       0.003304   0.839852  16.693843  (16.69:1)
  RGB #0A0B0C=(10,11,12)  #C3FF61=(195,255,97)
H1 hover                     #0A0B0C on #A6E83C       0.003304   0.661465  13.347256  (13.35:1)
  RGB #0A0B0C=(10,11,12)  #A6E83C=(166,232,60)
H1 active                    #0A0B0C on #7BAE26       0.003304   0.346230   7.433375  (7.43:1)
  RGB #0A0B0C=(10,11,12)  #7BAE26=(123,174,38)
L2 n500 vs n50               #6B727C on #F6F7F5       0.166157   0.927069   4.520191  (4.52:1)
  RGB #6B727C=(107,114,124)  #F6F7F5=(246,247,245)
L2 n500 vs white             #6B727C on #FFFFFF       0.166157   1.000000   4.857589  (4.86:1)
  RGB #6B727C=(107,114,124)  #FFFFFF=(255,255,255)
rejected n400 vs n50         #A7AEB8 on #F6F7F5       0.419483   0.927069   2.081161  (2.08:1)
  RGB #A7AEB8=(167,174,184)  #F6F7F5=(246,247,245)
rejected n400 vs white       #A7AEB8 on #FFFFFF       0.419483   1.000000   2.236503  (2.24:1)
  RGB #A7AEB8=(167,174,184)  #FFFFFF=(255,255,255)
published border n300 vs n50 #D8DDE3 on #F6F7F5       0.718579   0.927069   1.271268  (1.27:1)
published border n300 vs white #D8DDE3 on #FFFFFF     0.718579   1.000000   1.366158  (1.37:1)
```

**INFO (not a fail):** published `components.css` has `.gl-button--confirm-primary:hover` but no `:active`. Active `#7BAE26` is applied on `<button>` via later `wizard/styles.css` `button:active:not(:disabled) { background: var(--gl-action-confirm-bg-active); }` (specificity 0,2,1 beats `.gl-button--confirm-primary` 0,2,0). Hover stays `#A6E83C` because `.gl-button--confirm-primary:hover` is 0,3,0.

---

## Cascade (emitted CSS)

`scripts/build-site.sh` concat order: tokens → reset → templates → components → `wizard/styles.css` → `routes/install/styles-route.css`.

After `npm run routes:build`:

```text
published_idx 23272
override_idx 160512
override_after_published True
has_720 True
has_n500_border True
has_n500_remap True
```

Published (components): `.gl-button--confirm-primary{background:var(--gl-button-confirm-bg);color:var(--gl-action-primary-text)}`  
Later installer chrome: `.gl-button--confirm-primary { color: var(--gl-button-confirm-text); }`

---

## reset.css pin (comment-only)

```text
$ sha256sum design/pajamas/reset.css
baa208696f550d219495495c6e89e7d48386569916e8dea4d2e4fbe9087b071b  design/pajamas/reset.css
767 design/pajamas/reset.css
```

Pin in `test/pajamas-vendor.test.ts` `SOURCE_HASHES.reset.css` = **767 / baa20869…** — matches the file.

Reconstruct old header line from Q-PIXEL/Q-VENDOR evidence:

```text
 * GuardTalk Pajamas document reset (NOT concatenated into dist — would restyle route HTML).
```

→ 770 bytes, sha256 `071b14e2acbf1e35fb74b8e019a93a82f15a695c4c6026bd783b50e229bbcc5e` (exact Q-VENDOR record). Rules after `*/` are unchanged and match compiled `index-BFboFyqJ.css` reset block (`*{box-sizing:border-box}` … focus-visible). **Comment-only confirmed.**

---

## D-006 + remote grep

Exact CSP: `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'`

```text
D006_OK dist/site/index.html
D006_OK dist/site/install/index.html
D006_OK dist/site/install/update/index.html
D006_OK dist/site/install/verify-device/index.html
D006_OK dist/site/install/recover/index.html
D006_OK dist/site/threat-model/index.html

rg -n "design.guardtalk.io|@import url\(http|fonts.googleapis" dist/site
(no matches)
```

`LIVE_FLASH_CLAIMED`:

```text
src/types.ts:119:export const LIVE_FLASH_CLAIMED = false;
```

---

## Raw command output

Working directory: `vendor/guardtalk/web-installer`  
`export PATH=/home/openstatestack/.local/node/bin:$PATH`

```text
npx tsc --noEmit
TSC_EXIT:0

npm run routes:build
site written to /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer/dist/site
BUILD_EXIT:0

npx tsx --test --test-timeout=60000 test/*.test.ts
# tests 313
# pass 312
# fail 0
# cancelled 0
# skipped 1
# duration_ms 11765.363576
TEST_EXIT:0

sha256sum design/pajamas/reset.css
baa208696f550d219495495c6e89e7d48386569916e8dea4d2e4fbe9087b071b  design/pajamas/reset.css
```

New contrast pins (all ok): 145–149 in this run (`pajamas-contrast.test.ts`).

---

## Adversarial / independence notes

| Probe | Input | Expected | Actual | Status |
|-------|-------|----------|--------|--------|
| invented hex | `#` in route + wizard chrome | none | none | PASS |
| lighter border token | `#A7AEB8` vs surfaces | <3:1 | 2.08 / 2.24 | PASS (reject) |
| published confirm ink | `#F6F7F5` on `#C3FF61` | <4.5 | 1.10:1 | PASS (formula) |
| old reset header recon | swap one comment line | Q-VENDOR hash | 071b14e2… / 770 | PASS |
| cascade order | emitted CSS indexes | override later | 160512 > 23272 | PASS |

### Coverage gaps

- No Chromium computed-style check of the winning `color` (file-order proof only).
- No live USB flash (honesty HOLD).
- Active fill for confirm-primary is via wizard `button:active`, not a published class `:active` rule (INFO above).

### Bugs found

- None that reopen H1/L2/L3.

### Regression

- Pre-change (F note): 307 pass / 1 skip  
- Post-QA pins: 312 pass / 1 skip (313 tests)  
- Tests modified/deleted: **NONE** (new file only)

### PQE Assessment: Code Entropy LOW

Law 21 confirm ink and 1.4.11 borders now meet AA using existing `--gl-*`. Reset header matches concat. No new hex, no new deps, DEC-014 720 held.

### GOVERNANCE COMPLIANCE CHECK (COT-006 condensed)

1. CLASSIFY: evidence + test pins  
2. CORE LAWS 0–15: PASS (Architect packet; tests only; no doctrine edit; no flash)  
3. EXTENDED 16–23: PASS (suite green; no PII; contrast math shown)  
4. GATE PIPELINE: Gate -1 manual (MCP down); Gate 5 skipped per human instruction — **no score**  
5. CROSS-REFERENCE: H1/L2/L3 rematched; DEC-014 720 held; D-006 intact  
6. CONFIDENCE: 9/10  
7. VERDICT: **PASS** (Architect REVIEW; not APPROVED by QA)

Not a live-flash GO.
