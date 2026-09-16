# A-WEBINSTALL-PAJAMAS-PIXELFIX — Independent Audit (extreme)

- **Task:** A-WEBINSTALL-PAJAMAS-PIXELFIX (`audit_scope: full`)
- **Auditor:** AEGIS Independent Auditor (read-only). No product / test / flash / custody / doctrine edits.
- **Timestamp:** 2026-08-23T20:59:00+04:00 (2026-08-23T16:59:00Z)
- **Depends on:** F-WEBINSTALL-PAJAMAS-PIXELFIX (R1 + R2) — APPROVED by Architect.
- **Target:** `vendor/guardtalk/web-installer/` (routes, `lib/ui/rail.ts`, vendored Pajamas, `dist/site`, flash/custody, claims).
- **Status:** **REVIEW only.** Auditor does not APPROVE.

## Gate -1 / Gate 5

- `gate_enforcer` MCP: **Not connected** (tool unavailable). Guardian HTTP proxy not reachable.
- Under **Law 9** (Graceful Degradation) I manually **ACKNOWLEDGE Gate -1**: scope = read-only audit; zero edits to product / test / flash / custody. Only artifacts written are this audit doc and the inbox completion note.
- `ultimate_critique` **skipped** per standing directive (D-008). **No Gate 5 score is reported / fabricated.**

---

## Final audit verdict: **PASS (with measurements)** — overlay HOLD

The F-WEBINSTALL-PAJAMAS-PIXELFIX wave (R1 title→36px, R2 stepper→28px, residuals bound) is **independently verified accurate on every claim**. All vendored-reproducible pixel targets MATCH. The two remaining deltas (560 onboarding column, centred title) are **legitimate SPA-only residuals** — the vendored design system contains no onboarding column-width and no centred onboarding page-title at all, so there is no vendored target to fail against. Rendered pixel overlay stays **HOLD/UNVERIFIED** (no host renderer; a browser was correctly NOT installed).

D-006, custody, and honesty invariants hold. **Not a live-flash GO** — `LIVE_FLASH_CLAIMED === false`; no machine/flash change observed.

| Severity | Count (new this audit) |
|----------|------:|
| BLOCK | 0 |
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 0 |
| LOW | 0 |
| INFO | 2 |

No new BLOCK/CRITICAL/HIGH/MEDIUM/LOW findings. Two INFO observations (below) are carried context, not defects introduced by this wave.

---

## Independent verification (this session)

Cwd: `vendor/guardtalk/web-installer`. `PATH=/home/openstatestack/.local/node/bin:$PATH`. Node v22.12.0. No Chromium/Firefox/Playwright on PATH. No live USB. (Note: this worktree exposes no `.git`, so change-scope was corroborated by file mtimes + direct file reads rather than `git diff`.)

```text
npx tsc --noEmit
TSC_EXIT: 0

npx tsx --test test/*.test.ts
# tests 313 | pass 312 | fail 0 | skipped 1 | todo 0
TEST_EXIT: 0        (includes test/pajamas-vendor.test.ts hash-pin — vendored assets byte-identical)

npm run routes:build
site written to .../dist/site       BUILD_EXIT: 0

curl (python http.server :8080 on dist/site):
200  install/
200  install/styles-route.css
200  install/update/
200  install/verify-device/
200  install/recover/
200  threat-model/
```

---

## 1. Pixel-perfect / template fidelity — **PASS**

| Check | Evidence | Result |
|---|---|---|
| Stepper marker **28px** | emitted `dist/site/install/styles-route.css`: `.gl-progress-steps__marker{…width:28px;height:28px;border-radius:var(--gl-border-radius-full);border:2px solid var(--gl-border-color-strong);…}`. Identical to vendored `design/pajamas/components.css:785` and `compiled/index-BFboFyqJ.css`. | **MATCH (28×28)** |
| Zero `gl-stepper` in emitted rail JS | `rg gl-stepper dist/site/lib/ui/rail.js install-app.js` → **0**. `rg gl-progress-steps dist/site/lib/ui/rail.js` → **6**. Source `lib/ui/rail.ts` emits `gl-progress-steps--horizontal · __step · __marker · __connector · __text · __label`. `rg gl-stepper lib routes scripts` → **0**. | **CLEAN** |
| Title **36px** on all 5 routes | Emitted CSS rule `.installer-main h2.step-headline,.route h1,.installer-head h1,.gl-onboarding__header h1{font-size:var(--gl-font-size-h1)}` with `--gl-font-size-h1:36px`. Title element per route maps to it: **install** `<h2 class="step-headline">` inside `.installer-main`; **update** `<h1>` inside `<header class="installer-head gl-onboarding__header">`; **verify-device** `<h1>` inside `.route.gl-onboarding`; **recover** `<h1>` inside `.route.gl-settings`; **threat-model** `<h1 class="gl-section__heading">` inside `.route`. | **MATCH (36px ×5)** |
| **720** column retained | emitted CSS `width:min(720px, calc(100% - 2 * var(--gl-spacing-8)))` (+ `@media ≤800px` clamp to `min(100% − 2×spacing-6, 720px)`). Route CSS does **not** redefine marker `width/height` (`rg gl-progress-steps__marker\{ routes/install/styles-route.css` → 0). | **RETAINED** |

Sub-hierarchy preserved: subsection `h2/h3` stay `--gl-font-size-h2` (26px); no vendored geometry redefined.

---

## 2. Residual legitimacy (critical) — **LEGITIMATE (NOT relabelled FAILs)**

Grep of the full vendored design system (`design/pajamas/tokens.css`, `templates.css`, `components.css`, `compiled/index-BFboFyqJ.css`):

- **Only `560` occurrence** = `.gl-command-palette{position:fixed;…width:min(92vw,560px);…}` — a **command-palette modal**, not an onboarding/settings/content column. There is **no** onboarding page column-width anywhere in vendored CSS. (For completeness, the other modal widths present are `.gl-modal{width:min(92vw,520px)}` and command-palette 560 — both modals, neither an onboarding column.)
- **Only centred title** = `.gl-mobileheader__title{margin:0;text-align:center;font-size:var(--gl-font-size-base);…ellipsis}` — a **16px mobile-header** title, not a 36px onboarding page-title. No vendored onboarding page-title is centred.
- The onboarding **560 column** and **centre-title** exist **only** in the un-vendored React SPA runtime (`design/pajamas/SOURCE.txt` names the compiled asset + `…assets/*.js` runtime SPA; that `.js` is **not vendored** into the repo). Chasing it would require depending on the runtime design site — which **D-006 forbids**. Not chasing it is therefore correct, not an evasion.

**Verdict:** both are genuine **SPA-only residuals**. There is no vendored target for either, so neither can be scored a FAIL against the vendored template. This is an honest disposition, not a relabelled failure.

**DEC-014 (720 retained) rationale — holds.** The `/install` route renders a **10-step** rail (`lib/install-state/steps.ts`: `install.steps = [0,1,2,3,4,5,6,7,8,9]`). The horizontal rail carries `min-width: 36rem` (**576px**). A 560px page column is **narrower than the 576px rail floor** → forced horizontal scroll and heavier per-step compression. Retaining **720** is the measurement-justified choice for a 10-step horizontal rail. Rationale is sound.

---

## 3. D-006 / no runtime design-site dependency — **PASS**

- **CSP exact** in all **6** emitted HTML shells (5 routes + landing), byte-for-byte:
  `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'`
  ```text
  D006_OK dist/site/index.html
  D006_OK dist/site/install/index.html
  D006_OK dist/site/install/recover/index.html
  D006_OK dist/site/install/update/index.html
  D006_OK dist/site/install/verify-device/index.html
  D006_OK dist/site/threat-model/index.html
  ```
- **Zero** `design.guardtalk.io`, remote `@import`, `fonts.googleapis`, `.woff/.woff2/.ttf`, or `url(http…)` in `dist/site`.
- **Zero runtime network calls** in emitted JS: `rg "fetch\(|XMLHttpRequest|WebSocket|sendBeacon|import\(['\"]http" dist/site -g '*.js'` → empty.
- Only outbound host refs are two user-facing **navigation anchors** in `dist/site/install/late-steps.js` (`<a href="https://guardtalk.io/system/gateway">`, `…/docs`), explicitly labelled *"these pages load over the network when you open them — this installer itself stays fully offline."* These are click-navigation (not `design.guardtalk.io`, not `@import`, not webfonts, not runtime fetches) and pre-date this wave. Recorded as **INFO-1**, not a D-006 defect.

---

## 4. No new inline hex / style / handlers — **PASS**

- `dist/site` route HTML/JS: `rg "style="` → 0; `rg "\son[a-z]+=[\"'\`]"` (handlers) → 0; `rg "#[0-9a-fA-F]{3,6}"` → 0; inline `<style>` / `<script>` bodies → 0 (scripts are `src=` module only; stylesheets `href=` only).
- The `.gl-progress-steps__step.is-complete .gl-progress-steps__marker{…color:#fff}` hex is **pre-existing vendored** (`components.css:786`), not introduced by the frontend. Confirmed no NEW hex/style/handler in `lib/ui/rail.ts` or `routes/install/styles-route.css` (route CSS uses only `var(--gl-*)`).

---

## 5. Custody / honesty invariants — **PASS (unchanged)**

| Check | Evidence | Result |
|---|---|---|
| Flash order | `src/types.ts:7` `FLASH_ORDER = ["firmware","avb_custom_key","os"]` | unchanged |
| `LIVE_FLASH_CLAIMED` | `src/types.ts:119` `export const LIVE_FLASH_CLAIMED = false;` | **false** |
| `proveVbmetaUserSigned` | `lib/verify/user-anchor.ts:16-33` — proves vbmeta signed by **enrolled user pkmd**, never the GuardTalk release key | unchanged spine |
| Install-state machine | `lib/install-state/machine.ts` (mtime 13:24, pre-wave) untouched | unchanged |
| `data-action` wiring | present across routes (install-app 7, early-steps 11, late-steps 3, recover 5, verify 3, update 2) | intact |
| `?sim=1` | `routes/{verify-device,recover}/…app.ts` read `?sim=1`; visible SIMULATION chip only | intact |
| Q-01…Q-14 `// confirm` placeholders | still shipped (`early-steps.ts`, update Q-05/Q-07/Q-08 markers, claims "…with counsel") | unchanged |
| Suite honesty | 312 pass / 1 skip / 0 fail; wizard still refuses live `executePlan` / `lock` | no live-flash PASS |
| Live USB / overlay | not attached / no renderer; not attempted | **HOLD** (honest) |

**Change scope corroboration (no git):** mtimes show only `lib/ui/rail.ts` (16:47:04) and `routes/install/styles-route.css` (16:47:17) were modified in this wave; every custody file (`lib/verify/user-anchor.ts` 13:27, `lib/install-state/machine.ts` 13:24, `src/types.ts` Aug-20) predates it. Consistent with a class/markup-only CSS+rail change (Law 6 minimal footprint).

---

## 6. Prior findings disposition (A-WEBINSTALL-PAJAMAS-TEMPLATES)

| # | Prior sev | Topic | Disposition after PIXELFIX | Evidence |
|---|---|---|---|---|
| H1 | HIGH | Confirm-primary ink 1.10:1 on signal green (Law 21) | **SATISFIED (retained fix)** | `styles-route.css:7-12` route override `.gl-button--confirm-primary{color:var(--gl-button-confirm-text)}` (DEC-013). In emitted CSS the override sits at byte ~160519 — **after** the vendored rule at ~23273 (equal specificity 0-1-0, later cascade wins) → ink `--gl-button-confirm-text` = `#0A0B0C`, **16.69:1**. Untouched by this wave. |
| L1 | LOW | Onboarding column +200px (720 vs claimed 520) | **RESOLVED-BY-DISPOSITION** | Reframed correctly: vendored CSS has **no** onboarding column at all; the 560 SPA column is un-vendored. 720 is DEC-014-bound for the 10-step rail. Not a FAIL against vendored template. |
| L2 | LOW | Secondary/dashed border contrast under light `--gl-*` | **CARRIED (unchanged)** | `--gl-border-color-strong` `#D8DDE3` token-inherited; not touched by R1/R2. Still Architect-bound. |
| L3 | LOW | `reset.css` header contradicts concat | **CARRIED (docs drift)** | Unchanged by this wave. |
| I3 | INFO | Completed markers / progress fills inherit confirm fill | **CARRIED** | Vendored catalog chrome (`components.css`), not a new invention. Signal-green rationing intact — no fabricated green. |

**Signal-green rationing:** intact. Confirm green remains reserved for confirm CTAs + verified chips; completed-stepper/progress fills are vendored catalog behaviour, not new fabricated green.

---

## INFO observations (this audit)

- **INFO-1** — Two outbound navigation anchors to `guardtalk.io/system/gateway` and `/docs` in `late-steps.js`. Navigation-only, honestly labelled offline-note, not a runtime fetch, not a design-site/webfont/@import ref. Pre-existing (not from this wave). No D-006 impact.
- **INFO-2** — Rendered pixel overlay is **HOLD/UNVERIFIED** (no host renderer; browser correctly not installed). CSS/token math only. Q-PIXEL remains the overlay owner. Per Law 7 no rendered pixel-perfect PASS is claimed — only the vendored-CSS/token-measurable targets are asserted PASS.

---

## Law / DEC statements

- **D-006 / Law 4:** PASS — CSP exact ×6; zero runtime network; no design-site/webfont/@import in `dist/site`.
- **DEC-013 (confirm-ink):** SATISFIED — override effective (16.69:1), retained.
- **DEC-014 (720 column):** SOUND — 10-step rail (576px floor) > 560 column.
- **DEC-WEBINSTALL-012 (custody):** PASS — flash order, `proveVbmetaUserSigned`, custody, `LIVE_FLASH_CLAIMED=false`, install-state, Q-01…Q-14 `// confirm` unchanged.
- **Law 6:** PASS — 2-file class/markup swap; custody files untouched.
- **Law 16:** PASS for host/mocked suite (312/1-skip/0-fail); rendered overlay unverified (HOLD).
- **Law 7:** Rendered pixel-perfect overlay marked UNVERIFIED; no fabricated Gate 5.

---

## Recommended Architect follow-ups (Auditor does not create tasks)

1. Keep the rendered overlay (Q-PIXEL) as the owner of the final Chromium screenshot close-out; treat this REVIEW as evidence-complete for the vendored-CSS layer only.
2. L2 (secondary/dashed border contrast) and L3 (`reset.css` header drift) remain carried Architect-bound residuals — optionally a later F card, must not touch flash/custody.
3. Do **not** treat this REVIEW as a live-flash GO.

## AC checklist

- [x] Findings table with severity
- [x] Residual-legitimacy verdict (560-column + centre-title = legitimate SPA-only, not relabelled FAILs)
- [x] D-006 result (PASS; CSP exact ×6; zero remote refs; zero runtime fetch)
- [x] Prior-findings disposition table (H1/L1/L2/L3 + signal-green)
- [x] Final audit verdict PASS with measurements; overlay HOLD
- [x] Custody/honesty: `LIVE_FLASH_CLAIMED=false`; no machine/flash change
- [x] Status REVIEW only; no Gate 5 score; no git commit/push; `ultimate_critique` skipped
