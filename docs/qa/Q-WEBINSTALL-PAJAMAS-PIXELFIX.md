# QA Report — Q-WEBINSTALL-PAJAMAS-PIXELFIX (P0)

**Role:** AEGIS QA Engineer (independent verification)
**Paired task:** `F-WEBINSTALL-PAJAMAS-PIXELFIX` (APPROVED, R1+R2)
**Status:** **REVIEW** (never APPROVED; no git commit; `ultimate_critique` skipped — no fabricated Gate 5)
**Date:** 2026-08-23
**Repo:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`
**Web installer:** `vendor/guardtalk/web-installer/`

---

## Gate -1 — Manual ACK (Law 9, Graceful Degradation)

MCP gate tools report **Not connected** on this host; no Guardian proxy reachable.
Per Law 9 I manually **ACKNOWLEDGE Gate -1** and lock scope:

- **Scope lock:** QA verification **only** — independent measurement of the emitted
  `dist/site` CSS/HTML via token math. **No product restyle.** Test-selector edits
  only if ever needed (none were needed this pass).
- **Forbidden paths — NOT touched:** `doctrine/`, `governance/laws/`,
  `governance/gates/`, `lib/avb/`, `lib/fastboot/`, `lib/keys/`,
  `lib/install-state/`, `routes/install/flash-runner.ts`, secrets/`.env`,
  `apps/AEGIS CONTROL CENTER/`. Product CSS/markup **read-only**.
- **Outputs:** this report + a completion note appended to
  `.agent-comm/inbox/TO_ARCHITECT_Q-WEBINSTALL-PAJAMAS-PIXELFIX.md`.
- **Honesty (Law 7):** measured, not trusted. One item did **not** fully close and
  is reported as a **measured discrepancy**, not relabelled.

---

## Method

Independent token math against the **emitted** artefacts (not the Frontend's report):

- Token scale read from `design/pajamas/tokens.css` (vendored).
- Geometry read from the concatenated, emitted `dist/site/install/styles-route.css`
  (built fresh via `npm run routes:build`) and `dist/site/**/index.html`.
- CSS cascade/specificity resolved by hand for each route's title element.
- All 5 routes load the **same** emitted stylesheet, so token values are uniform;
  per-route rows below record which components appear + the resolved title rule.

Stylesheet link proof (emitted):

| Route | `<link>` href | Resolves to |
|-------|---------------|-------------|
| `/install/` | `./styles-route.css` | `dist/site/install/styles-route.css` |
| `/install/update/` | `../styles-route.css` | same file |
| `/install/verify-device/` | `../styles-route.css` | same file |
| `/install/recover/` | `../styles-route.css` | same file |
| `/threat-model/` | `../install/styles-route.css` | same file |

### Vendored token scale (source of all math)

`--gl-spacing`: 2=2px · 3=4px · 4=8px · 5=12px · 6=16px · 7=20px · 8=24px · 9=32px · 11=48px
`--gl-border-radius`: small=4px · base=6px · large=8px · full=999px
`--gl-font-size`: sm=13px · base=16px · lg=18px · **h2=26px** · **h1=36px**
`--gl-line-height-base`: 1.65

---

## Verification commands (run + outputs)

```
$ export PATH=/home/openstatestack/.local/node/bin:$PATH

$ npx tsc --noEmit
TSC_EXIT=0                                    # 0 errors

$ npx tsx --test test/*.test.ts
# tests 313
# pass  312
# fail  0
# skipped 1     # "pagehide hook: installs and uninstalls cleanly when window exists" — SKIP (headless, no window; benign)
# todo  0
# duration_ms ~12.7s

$ npm run routes:build
site written to .../vendor/guardtalk/web-installer/dist/site

$ curl -s -o /dev/null -w "%{http_code}"  http://192.168.1.4:8080/<path>
200  install/
200  install/update/
200  install/verify-device/
200  install/recover/
200  threat-model/
200  install/styles-route.css
200  install/?sim=1

$ rg -n "design.guardtalk.io|@import url\(https?:|https?://fonts" dist/site
(no matches)  exit=1                          # ZERO remote refs

# Emitted-CSS proofs (dist/site/install/styles-route.css):
.gl-progress-steps__marker{...width:28px;height:28px;border-radius:var(--gl-border-radius-full);
  border:2px solid var(--gl-border-color-strong);...}          # marker 28x28
.gl-progress-steps--horizontal .gl-progress-steps__connector{top:14px;left:28px;right:var(--gl-spacing-3);height:2px}
--gl-font-size-h1: 36px;                                        # title token
width: min(720px, calc(100% - 2 * var(--gl-spacing-8)))        # column 720 / -48px

# CSP (exact D-006) present in all 6 emitted pages (index, install, update, verify, recover, threat-model):
default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'

# gl-stepper provenance:
rg -c gl-stepper routes/install/styles-route.css     -> 0   (route CSS clean)
rg -c gl-stepper dist/site/lib/ui/rail.js            -> 0   (rail markup clean)
rg -c gl-progress-steps dist/site/lib/ui/rail.js     -> 6   (rail uses new family)
rg -c gl-stepper dist/site/install/styles-route.css  -> 12  (ALL from vendored components.css library; unused)
```

**claim-lint:** no standalone npm/script `claim-lint` exists; the linter
(`lib/claims/lint-claims.ts`) is exercised by the test
*"claim-lint is clean over route sources"* which **passed** (part of the 312).
No dishonest/overclaiming copy detected.

---

## Independent per-route delta table (measured from emitted CSS/HTML)

Shared surfaces (identical on every route — one emitted stylesheet):

| Surface | Measured value (token → px) | Source |
|---|---|---|
| Content column | `min(720px, 100% − 2×spacing-8)` = **min(720px, 100%−48px)**; ≤800px → `min(100%−32px, 720px)` | `.installer/.route/body.route-update` |
| Card radius | `--gl-border-radius-base` = **6px** | `.installer-main/.route .phase/.threat-card` |
| Card padding | `--gl-spacing-8` = **24px** | card block |
| Card inner gap | `--gl-spacing-6` = **16px** | card block |
| Top-level stack gap | `--gl-spacing-8` = **24px** | `.installer/.route` |
| Type scale | title **36px** (h1) · subsection **26px** (h2) · body **16px** · small **13px** · lg **18px** | tokens + heading rules |
| Buttons | min-height **32px**, padding **6px 12px** (spacing-5), radius **6px**; confirm-primary ink override (DEC-013) | `.flow-pick`, inputs, `.gl-button--confirm-primary` |
| Alerts (`gl-alert`) | padding `--gl-spacing-6` = **16px**; danger bg `--gl-feedback-danger-bg` | vendored components.css |
| Focus ring | 2px solid `--gl-focus-ring`, offset 2px | `:focus-visible` |

Per-route specifics:

| Route | Step rail (28px marker)? | Danger zone | Alerts present | Title element → resolved size | Title align |
|---|---|---|---|---|---|
| `/install/` | **Yes** (10-step 0–9) | `.phase-loss/.phase-unlock` (danger border+bg) | sim-banner (warning), verify-result (danger) | **steps 0–4:** `h2.step-headline` → **36px** · **steps 5–9:** plain `<h1>` → **26px** (see Finding 1) | left |
| `/install/update/` | **Yes** (renders rail) | — | — | `<h1>` in `.installer-head.gl-onboarding__header` → **36px** | left |
| `/install/verify-device/` | No | — | hard-stop danger alert | `.route h1` → **36px** | left |
| `/install/recover/` | No | `.recover-danger-zone` (danger border+bg) | — | `.route h1` → **36px** | left |
| `/threat-model/` | No | — | warning list items | `.gl-section__heading` is `h1` under `.route` → **36px** | left |

### Stepper marker geometry (measured, emitted CSS)

```
.gl-progress-steps__marker            width:28px; height:28px; border:2px; radius:999px  (was .gl-stepper-marker 26px/1px)
.gl-progress-steps__step.is-active    box-shadow:0 0 0 3px var(--gl-feedback-info-bg); border/color brand
.gl-progress-steps__step.is-complete  bg/border --gl-action-confirm-bg; color #fff (pre-existing vendored)
.gl-progress-steps--horizontal .__connector  top:14px; left:28px; right:4px (spacing-3); height:2px
```
Old `.gl-stepper-marker` = `calc(spacing-8 + spacing-2)` = 24+2 = **26px**. New = **28px**. Δ = **+2px** ✓.

---

## FAIL-closure / residual verdicts (measured)

| Prior item | Verdict | Measured evidence |
|---|---|---|
| **Stepper marker 26 → 28px** | **PASS (CLOSED)** | Emitted `.gl-progress-steps__marker{width:28px;height:28px}`; rail JS uses `gl-progress-steps*` (6 hits) with **0** `gl-stepper`; route CSS **0** `gl-stepper`. The 12 `gl-stepper` hits in the emitted stylesheet are all the **vendored components.css** library class (unused by the rail). |
| **Title 36px on all 5 routes** | **PARTIAL / discrepancy** | 36px confirmed on the **landing view of all 5 routes** and install **steps 0–4** (`h2.step-headline`). **BUT install steps 5–9** ("Connect the device." / "Flash GuardTalkOS." / "Lock the bootloader." / "First boot & verify." / "Keep the key.") render a plain `<h1>` inside `.installer-main`, which matches **only** `.installer-main h1` (26px block); the 36px block omits `.installer-main h1`. → **those 5 titles compute to 26px.** See Finding 1. |
| **Column 720 retained (DEC-014 residual)** | **PASS (documented, legitimate)** | `width: min(720px, 100%−48px)`. Functional justification independently verified: rail `min-width: 36rem = 576px` > 560px, so a 560 column would clip/scroll the 10-step rail. Documented in `styles-route.css` comment as an Architect-bound residual. (Note: the DECISION_LOG entry `D-014` is the AVB-signer fix, not the rail — the "DEC-014" label in the change note is a **cross-reference mismatch**, but the substantive disposition holds; see Finding 2.) |
| **560 column = SPA-only** | **PASS (legitimate)** | Only vendored `560` is `.gl-command-palette{width:min(92vw,560px)}` — a **modal**, not a content column. Other modal widths: gl-modal 520, popover 320, drawer 400, hover-card 300. **No** vendored onboarding/settings/content column at 560. The 560 onboarding column lives only in un-vendored `index-D1E98FVb.js`. |
| **Centre title = SPA-only** | **PASS (legitimate)** | Vendored `text-align:center` titles: `.gl-mobileheader__title` (mobile header) and `.gl-navrail__label` (nav-rail label) only — neither an onboarding page title. `.gl-section__header` uses `align-items:flex-start`. templates.css ships **no** `.gl-onboarding__title`/`.gl-settings__title` at all. **No vendored onboarding title centres.** |
| **Title left-aligned** | **PASS (legitimate)** | Header uses `align-items: flex-start`; no `text-align:center` on any route title. The `align-items:center` hits in the route CSS are inline component rows (posture, pills, chips, actions, sim-switch), not titles. |

---

## Regression checks (all PASS)

| Check | Verdict | Evidence |
|---|---|---|
| `data-action` wiring intact | **PASS** | Source TS counts == emitted JS counts exactly: install-app **7**, early-steps **11**, late-steps **3**, update-route **1**, update-app **1**, verify-route **3**, recover-route **5**. |
| `?sim=1` labels SIMULATION | **PASS** | `SIM_LABEL="SIMULATION"`, `isSimMode("?sim=1")=true`; emitted `late-steps.js` has `SIMULATION` + `data-sim="true"` + `gl-alert--warning`; `?sim=1` route → 200. |
| Q-01…Q-14 `// confirm` placeholders | **PASS (unchanged)** | Placeholders live in `early-steps.ts`/`update-route.ts` (Q-04/05/06/07/08 etc.), untouched by the pixelfix (which edited only `rail.ts` + `styles-route.css`). |
| DEC-013 confirm-ink preserved | **PASS** | `.gl-button--confirm-primary { color: var(--gl-button-confirm-text); }` (16.69:1) intact at top of `styles-route.css`; token `--gl-button-confirm-text` present. |
| `LIVE_FLASH_CLAIMED = false` | **PASS** | `src/types.ts:119 export const LIVE_FLASH_CLAIMED = false;`; test *"LIVE_FLASH_CLAIMED stays false"* green. |
| D-006 CSP exact | **PASS** | Exact string in all 6 emitted pages; `INSTALLER_CSP` equals D-006. |
| Zero remote refs in `dist/site` | **PASS** | grep → 0 matches. |

---

## Overlay (rendered pixel diff)

**HOLD.** No browser is installable on host (no `chromium`/`chrome`/`firefox`/
`playwright` on PATH). Per instruction, **did not install a browser**. Verification
is by **computed-value / token math** on the emitted CSS/HTML above, which is
deterministic and sufficient for geometry claims. A true rendered overlay remains
an Architect-bound HOLD for a host with a browser.

---

## Findings (for the Architect)

### Finding 1 — Title item does not fully close: install steps 5–9 titles are 26px (measured)

The R1 title promotion block is:

```
.installer-main h2.step-headline,
.route h1,
.installer-head h1,
.gl-onboarding__header h1 { font-size: var(--gl-font-size-h1); }   /* 36px */
```

Install **early** steps (0–4) render `<h2 class="step-headline">` → matched → 36px. ✓
Install **late** steps (5–9) render a **plain `<h1>`** inside `.installer-main`
(`late-steps.ts`: "Connect the device." … "Keep the key."). That `<h1>` matches
**only** `.installer-main h1` from the 26px block (`font-size: var(--gl-font-size-h2)`),
and matches **none** of the 36px selectors (`.route` ancestor absent; header
selectors don't apply to `.installer-main`). Resolved size = **26px**.

Net: the blanket claim *"title 36px on all 5 routes"* is true for every route's
**landing view**, but **half of `/install/`'s steps show a 26px title** — and,
ironically, those are the semantic `<h1>`s. This is a **scoping gap in the
promotion selector**, not a regression (pre-R1 all titles were 26px). QA does not
restyle product code; a minimal product fix would be either adding
`.installer-main h1` to the 36px block or making late-steps use `h2.step-headline`
— **Architect/Frontend decision**.

### Finding 2 — DEC-013 / DEC-014 label cross-reference mismatch (non-blocking)

`styles-route.css` and the Frontend note cite **"DEC-013"** for confirm-ink and
**"DEC-014"** for the 10-step column. In `DECISION_LOG.md`, `D-013` is *"physical
home of /install (Option A)"* and `D-014` is *"AVB signer rawRsaSign EMSA fix"* —
neither is confirm-ink or the rail column. The **substance** of both dispositions
is sound and independently verified; only the ID cross-reference is inconsistent.
Recommend the Architect either add explicit DECISION_LOG entries for confirm-ink
and the 720/10-step-rail column, or correct the in-code labels.

---

## Verdict (per item + overall)

| Item | Verdict |
|---|---|
| Marker 28px (rail swap, zero gl-stepper) | **PASS** |
| Title 36px on all 5 routes | **PARTIAL** — PASS on landings/install 0–4; **26px on install 5–9** |
| Column 720 retained | **PASS** (documented, legitimate) |
| 560 / centre-title dispositions SPA-only | **PASS** — legitimately documented residuals, not relabelled FAILs |
| Regressions (data-action, sim, // confirm, DEC-013 ink, LIVE_FLASH_CLAIMED) | **PASS** |
| CSP D-006 + zero remote refs | **PASS** |
| tsc / test suite | **PASS** (0 tsc errors; 312 pass / 0 fail / 1 skip of 313) |
| Rendered overlay | **HOLD** (no browser; computed-value proof only) |

**Overall: REVIEW — PASS with one measured exception (title item PARTIAL) and one
HOLD (overlay).** The stepper-marker fix and column retention are clean; residual
dispositions are legitimate and independently confirmed. The single honest gap is
the install late-step (`<h1>`) title at 26px (Finding 1), surfaced for Architect
disposition. No commit. `ultimate_critique` skipped (no fabricated Gate 5).
