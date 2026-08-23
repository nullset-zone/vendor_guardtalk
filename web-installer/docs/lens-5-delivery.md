# Lens 5 — Delivery (build, CSP, static export, a11y) — adversarial audit

GuardTalkOS WebInstaller · READ-ONLY audit · 2026-08-23 · no file edited except this report.
Gate −1 (Guardian First): consulted and PASSED before any audit action.

**Scope.** All `page.html` files (`routes/install/page.html`, legacy `wizard/index.html`), all
emitted markup from `routes/**` renderers (`early-steps.ts`, `late-steps.ts`, `flash-runner.ts`,
`update-route.ts`, `verify-route.ts`, `recover-route.ts`), markup emitters in `lib/ui/**` +
`lib/claims/**`, every `tsconfig*.json`, `package.json` scripts, `status.json`, and both
stylesheets (`routes/install/styles-route.css`, `wizard/styles.css`).

**Binding refs.** PLAN.md §0 physical layout + D-013, DECISION_LOG D-006 (exact CSP),
PLAN §5 a11y/copy contract, PHASE4-LENSES.md Lens 5 checklist.

**Method.** Byte-exact string comparison of every CSP occurrence against D-006; regex sweeps
for inline handlers/styles/scripts across source AND compiled `dist/**`; full manual read of
every markup emitter; static-server path resolution traced per HTML entry; `status.json`
field-by-field against PLAN §0; keyboard/a11y contract traced emitter-by-emitter; `tsc`
actually executed for every config; wizard import graph re-derived from source. No browser
run was possible on this host — DOM-level claims rest on code + test evidence and are marked.

---

## 1. CSP exactness vs D-006

D-006 canonical string:
`default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'`

Every CSP occurrence in the product surface was byte-compared:

| Location | Result |
|---|---|
| `lib/claims/csp.ts:3-4` (`INSTALLER_CSP`) | **EXACT MATCH** |
| `lib/claims/csp.ts:7` (`cspMetaTag()` template) | **EXACT MATCH** (interpolates the constant) |
| `routes/install/page.html:8-9` (meta tag) | **EXACT MATCH** (byte-verified via script) |
| `routes/update/update-route.ts:393` (via `cspMetaTag()`) | **EXACT MATCH** |
| `routes/verify-device/verify-route.ts:333` (via `cspMetaTag()`) | **EXACT MATCH** |
| `routes/recover/recover-route.ts:191` (via `cspMetaTag()`) | **EXACT MATCH** |
| `routes/install/late-steps.ts:415-417` (`lateStepsCspMeta()`) | **EXACT MATCH** (duplicates the meta template but interpolates the same `INSTALLER_CSP` constant imported at `:16`) |

Grep over the whole package (`node_modules` excluded) finds no other CSP producer; remaining
hits are governance docs and tests that pin the same exact string
(`test/route-install-late.test.ts:653`, `test/claims.test.ts:76,80`,
`test/route-update.test.ts:114`). The single-source-of-truth constant plus test pins make
drift mechanically unlikely.

**VERIFIED CLEAN — zero drift, HIGH trigger did not fire.**

## 2. Zero inline handlers / styles / scripts

Swept `onclick=` `onchange=` `onsubmit=` `oninput=` `onerror=` `onload=` `style="` `<style`
`<script` over `routes/`, `lib/`, and `wizard/` sources, plus a wider `\son[a-z]+\s*=\s*"` /
`\sstyle\s*=\s*"` net over the whole package including `dist/wizard/**` bundles that ship to
the browser:

- The only `<script` occurrences are the two legitimate module loaders with `src=`
  attributes: `routes/install/page.html:15` (`./early-steps.js`) and
  `wizard/index.html:176` (`../dist/wizard/main.js`). No inline script bodies exist anywhere.
- Zero inline handlers or `style=` attributes in any emitted-string renderer. Behaviour is
  wired exclusively through delegated listeners and `data-*` hooks:
  `verify-route.ts:355-378` ("Delegated listeners only — zero inline handlers"),
  `recover-route.ts:297-331` (same contract), `rail.ts:272-293`, `dialog.ts`
  (`createElement`+`addEventListener` only), `console.ts:110-130`.
- `escapeHtml` (`lib/ui/escape.ts`) never emits handler or style attributes, and its header
  comment states the invariant; attribute values are always double-quoted so `&apos;`-style
  breakouts cannot occur.
- A regression test sweeps ALL emitted `/install` markup for exactly these patterns
  (`test/route-install-early.test.ts:298,357-364`); route tests additionally assert each page
  shell carries the D-006 meta and no inline script/style
  (`test/route-install-early.test.ts:366+`; `test/route-update.test.ts:114`;
  `test/route-verify-recover.test.ts:398`).

**VERIFIED CLEAN.**

## 3. Static export coherence

HTML entries present today: `routes/install/page.html` → served as `/install/…` and
`wizard/index.html`. Traced asset resolution from each entry:

**[F1] HIGH — `/install` loads `./early-steps.js`, which is never emitted by any build in
the repo.** `routes/install/page.html:15` references `early-steps.js`, but no tsconfig emits
JS next to the routes: `tsconfig.lib.json` is `noEmit: true` (`tsconfig.lib.json:20`), the
root `tsconfig.json` emits to `dist/` with `rootDir: "."` (which would produce
`dist/routes/install/*.js`, not `routes/install/*.js`), and `package.json` has no
`build:routes`/static-export script at all (`package.json:11-18` — only
wizard/test/typecheck scripts). `ls routes/install/` confirms only `.ts` files ship there
today. Under any plain static server, `/install/` currently 404s its sole script and renders
an empty `<div id="root">` behind a noscript apology — the site does not load fully offline
as shipped. *Fix:* add a build step that compiles `routes/**/*.ts` to sibling `.js`
(`tsc -p tsconfig.routes.emit.json` with `outDir` mirroring `routes/`), and wire it into
`package.json` scripts.

**[F2] MED — update/verify-device/recover have NO html entry; renderers are unreachable
from a static server until the Phase-5 wiring lands.**
PLAN §0/D-013 map `routes/update/` → `/install/update`, `routes/verify-device/` →
`/install/verify-device`, `routes/recover/` → `/install/recover`, but those directories hold
only `.ts` renderers — no `page.html`, no emitted JS. This matches the dispatch state:
PHASE4-LENSES.md sends confirmed findings to "the Phase-5 fix queue"
(`docs/PHASE4-LENSES.md:102-103`), and Reader-C's Option-A survey explicitly plans a build
step emitting `/install/index.html`, `/install/update`, `/install/recover`,
`/install/verify-device` (`docs/research/READER-C-SITE-SURVEY.md:25`). Documented gap, not
silent breakage — but until then cross-route links (`/install/recover`,
`/install/verify-device`, `/install`, e.g. `late-steps.ts:376`, `recover-route.ts:210`)
resolve to nothing. *Fix:* during Phase-5 wiring emit an `index.html` per route directory
from the shared shell (CSP meta included).

Path-correctness of what does exist:

- `page.html:10` references `./styles-route.css` — present in the same directory ✓.
- `wizard/index.html:7` references `./styles.css` — present in `wizard/` ✓.
- `wizard/index.html:176` references `../dist/wizard/main.js` — present in-repo ✓ (and
  `npm run wizard:build` regenerates it).
- No bundler is required anywhere: all modules are ESM with explicit `.js` specifiers, so
  once F1's emit step exists the graph resolves under `python3 -m http.server`.

**[F3] MED — update route references a stylesheet that exists nowhere:
`<link rel="stylesheet" href="/install.css">` (`routes/update/update-route.ts:396`).**
No `install.css` exists at any depth (repo-wide glob: zero hits); the root-absolute form also
breaks under any sub-path mount. When this page gets its Phase-5 html shell it will silently
render unstyled. *Fix:* point the shell at the existing `routes/install/styles-route.css`
(or emit a dedicated stylesheet beside the page).

**[F4] LOW — key-diagram classes have no CSS anywhere.** `lib/ui/key-diagram.ts` emits
`.key-diagram`, `.kd-node`, `.kd-link`, `.kd-link-dashed`, `.kd-marker`
(`key-diagram.ts:37-58`); grep over both stylesheets finds none of them, so nodes/links
inherit default fill/stroke (invisible-on-dark risk for default black strokes). *Fix:* add
the five selectors to `styles-route.css` during Phase-5 styling.

## 4. status.json vs PLAN §0 contract

Checked field-by-field against PLAN §0 (`status.json … installer: alpha · key-custody: alpha
(+ RELEASE_STATE/PRE_LAUNCH flags)`):

| Contract field | Required | Actual | Verdict |
|---|---|---|---|
| `installer` | `"alpha"` | `"alpha"` (`status.json:3`) | ✅ |
| `keyCustody` | alpha | `"alpha"` (`status.json:4`) | ✅ |
| `releaseState` | alpha flag | `"alpha"` (`status.json:5`) | ✅ |
| `preLaunch` | true flag | `true` (`status.json:6`) | ✅ |
| onion block | recommended/address | `{"recommended": true, "address": null}` with Q-05 comment (`status.json:7-11`) | ✅ |
| `routes` map | four routes per D-013 | install/update/verifyDevice/recover exactly as D-013 (`status.json:12-17`) | ✅ |
| `flashCapability` | implemented=true claimed=false | `{"implemented": true, "liveFlashClaimed": false}` + D-011 comment (`status.json:18-22`) | ✅ |

Extra fields (`targets`, `experimentalTargets`, `noOta`) are consistent with D-004/D-012 and
add nothing contradictory. The posture renderer accepts this payload family
(`postureFromStatusJson`, `posture.ts:45-65`) and hard-fails on any contradiction of the
offline/single-user invariants.

**VERIFIED CLEAN.**

## 5. Accessibility on emitted markup (WCAG 2.1 AA contract)

- **Skip link + target**: `page.html:13` `<a class="skip-link" href="#installer-main">` →
  target id present on the chrome's `<main class="installer-main">`
  (`early-steps.ts:131`). Style reveals on focus (`wizard/styles.css:47-49`). Note: the
  skip link is defined in the static shell while the target is client-rendered; before
  hydration the anchor points at a not-yet-existing element (harmless no-op, LOW noise).
- **Step rail semantics**: items are real `<button type="button" class="rail-step-button">`
  elements, never divs (`rail.ts:139`); roving tabindex with the current step focusable and
  forward steps `-1` (`rail.ts:187`, maintained in `focusAt`, `rail.ts:211-221`);
  `aria-current="step"` on current/stopped, `"false"` otherwise (`rail.ts:141`);
  ArrowUp/Down/Left/Right + Home/End + Enter/Space handled by the pure resolver
  (`rail.ts:62-91`) and attached by `wireRail` (`rail.ts:272-293`). Activation is gated to
  back-reachable targets (`rail.ts:258-263`) matching machine `backTarget`s
  (`steps.ts:50-90`). Rail container labelled (`early-steps.ts:130`,
  `rail.ts:188`).
- **Chips carry their word**: `makeChip` throws on empty word (`chips.ts:27-29`) and always
  emits visible text alongside `data-kind` (`chips.ts:30-34`); verdict chips repeat the word
  in side-by-side rows (`sidebyside.ts:39-42`). Colour-only status does not occur.
- **Mono values selectable**: values render as plain `<code class="mono">` /
  `<span class="sbs-value mono">` text nodes — no `user-select` suppression exists in either
  stylesheet (grep: zero hits), and the console implements click-to-copy per line with a
  gesture guard (`console.ts:64-71,110-123`).
- **Labels on inputs**: file inputs use `label[for]` (`early-steps.ts:260-266`), retype input
  uses `label[for="retype-input"]` (`early-steps.ts:545-546`), boot-fingerprint inputs use
  `label[for]` (`late-steps.ts:346`, `verify-route.ts:308`), recover ack uses
  `label[for]` (`recover-route.ts:64-66`), checkboxes wrap their labels
  (`late-steps.ts:137`, `early-steps.ts:536`), update route wraps file inputs in labels with
  `aria-label` reinforcement (`update-route.ts:144-146,316-317`).
- **role=alert on warning/quota surfaces**: hard-stop banners (`late-steps.ts:206,247,302`),
  mismatch result (`late-steps.ts:372`), verify-device hard stop
  (`verify-route.ts:199`), wizard quota box `role="alert"` (`wizard/index.html:107`) — all
  present.
- **lang attribute**: `<html lang="en">` in both HTML shells (`page.html:2`,
  `wizard/index.html:2`); route renderers emit `<html lang="en">` too
  (`update-route.ts:390`).
- **noscript fallback**: present with honest copy (`page.html:16`).
- **Focus visibility**: global `:focus-visible` outline rules in both stylesheets
  (`styles-route.css:380-383`, `wizard/styles.css:263-269`).
- **Contrast (computed)**: token pairs on the elevated background measure — muted 6.54:1,
  body ink 13.75:1, ok 9.05:1, warn 9.55:1, danger 7.90:1, copper-button ink 7.85:1 — all
  clear AA (≥4.5:1 text, ≥3:1 UI borders per `--line-strong` note at
  `wizard/styles.css:9-10`).

Findings:

**[F5] MED — flow-card choice buttons announce no selected state.** Step-3 cards render
three equal buttons (`early-steps.ts:493-500`); after choosing one, no
`aria-pressed`/`aria-current`/disabled differentiation is applied to the chosen card, and the
route deliberately avoids `aria-checked` (`test/route-install-early.test.ts:644` pins its
absence for the D-005 no-default rule). A screen-reader user cannot tell which flow is
active. *Fix:* set `aria-pressed="true"` (toggle-button pattern) on the chosen card's button
at selection time.

**[F6] MED — step-level errors are not programmatically associated with their inputs.**
Wrong fingerprint retype (`early-steps.ts:591-597`), boot-fingerprint mismatch, and compare
invalid-input (`verify-route.ts:252-259`) surface as separate paragraphs/banners without
`aria-describedby`, `aria-invalid`, or focus movement; `role="alert"` announces them, but the
offending field is not identified to assistive tech mid-form. *Fix:* link error paragraphs
via `aria-describedby` + `aria-invalid="true"` and move focus to the message.

**[F7] LOW — SVG diagram exposes only one labelled node relationship.**
`renderKeyDiagram` gives the svg `role="img"` + `aria-labelledby` to a single title
(`key-diagram.ts:54-56`) — the three node texts are visual-only for AT (acceptable since
`<title>`/`<desc>` carry the meaning, but node-level structure is lost). *Fix:* keep as-is or
switch to a semantic list fallback beside the graphic.

**[F8] LOW — `<details>` OEM guide has no programmatic link from its acknowledgement.**
The wipe checkbox (`late-steps.ts:137`) and the guide (`:194-202`) reference each other only
in prose ("the checkbox above covers this", `:201`). Cosmetic AT nicety only. *Fix:* give the
guide an id and reference it with `aria-details` from the warning section.

## 6. Build reproducibility

Executed with TypeScript 5.7.3 (vendored, `node_modules/typescript/package.json`) under
Node v22.20.0 (throwaway runtime installed to `/tmp` because the host has no system Node;
no repo file touched):

```
npx-equivalent: tsc -p tsconfig.lib.json --noEmit   → exit 0   ✅ (directive satisfied)
tsc --noEmit                (root tsconfig.json)    → exit 2   ❌
tsc -p tsconfig.wizard.json --noEmit                → exit 0   ✅
tsc -p tsconfig.avb.json    --noEmit                → exit 0   ✅
tsx --test test/*.test.ts                            → 266 tests, 265 pass,
                                                       0 fail, 1 skipped     ✅
```

Full suite green: 0 failures across all files (route suites individually: early 26 ok,
late 18 ok, update 14 ok, verify-recover 21 ok, ui 24 ok, claims 10 ok). The one skip is
`pagehide hook…` in `test/keys.test.ts:165`, skipped by design outside a browser window
(`{ skip: typeof window === "undefined" }`) — environmental, not a defect.

**[F9] HIGH — the root `tsconfig.json` typecheck fails with 8 errors**, so `npm test`'s own
first clause (`"test": "tsc --noEmit && tsx --test …"`, `package.json:12`) fails before any
test runs, and `npm run typecheck` is red. Errors (verbatim):

```
lib/ui/dialog.ts(48,16): error TS2488: Type 'NodeListOf<HTMLElement>' must have a '[Symbol.iterator]()' method...
lib/ui/rail.ts(195,26):  error TS2488: (same)
lib/ui/rail.ts(198,24):  error TS2488: (same)
test/install-state.test.ts(3,1):      error TS6192: All imports in import declaration are unused.
test/route-verify-recover.test.ts(26,3): error TS6133: 'renderHardStopBanner' declared but never read.
test/route-verify-recover.test.ts(165,12): error TS2339: Property 'avb_custom_key' does not exist on type 'DeviceVars'.
test/route-verify-recover.test.ts(183,11): error TS6133: 'sim' declared but its value is never read.
test/verify.test.ts(130,3):           error TS2532: Object is possibly 'undefined'.
```

Root cause: the root config predates Phase-2/3 code. It lacks `DOM.Iterable` in `lib`
(`tsconfig.json:16` has `["ES2022","DOM"]` vs `tsconfig.lib.json:23`
`["ES2022","DOM","DOM.Iterable"]`) yet includes `src/`, `test/`, and `wizard/` together
(`tsconfig.json:17`), sweeping in lib code the newer scoped configs were created to exclude.
The three newer configs (lib/avb/wizard) are clean; the stale aggregate is not.
Note `tsconfig.lib.json` includes `routes/**/*.ts` but NOT `src/hash.ts` consumers'
root-config siblings — the divergence between "root = everything" and "scoped = actual
product graphs" is itself the finding. *Fix:* align root config with the lib config
(add `DOM.Iterable`, scope include to the current product graphs) or delete the aggregate
include in favour of project references.

Orphan configs: `tsconfig.early.json` confirmed deleted (glob: zero hits). No
`*.tmp.json` anywhere in web-installer (glob: zero hits). Present configs:
`tsconfig.json`, `tsconfig.lib.json`, `tsconfig.routes.json`, `tsconfig.wizard.json`,
`tsconfig.avb.json`.

**[F10] MED — `tsconfig.routes.json` is a dead stub: it extends the root config with
`noEmit` and an EMPTY include (`tsconfig.routes.json:1-7`).** Compiling it exits 2 with
TS18003 "No inputs were found". PLAN §0 names `tsc -p tsconfig.routes.json` as the build
command, so the named build command does not work as documented. *Fix:* populate its
include with the route/lib graphs (mirroring `tsconfig.lib.json`) or repoint PLAN §0 at
`tsconfig.lib.json`.

Also noted (no ticket): host has no Node/npm (`npx` missing) — CI must provide the runtime;
reproducibility elsewhere is good since versions are pinned in `package-lock.json` and
devDependencies carry exact versions (`typescript 5.7.3`, `tsx 4.19.3`).

## 7. Wizard legacy route integrity

- `wizard/index.html` still loads its own bundle `../dist/wizard/main.js` (`:176`) and its
  own stylesheet `./styles.css` (`:7`); dist artifacts are present
  (`dist/wizard/main.js` etc.) and regenerate via `npm run wizard:build`.
- Import-graph isolation verified: the ONLY `wizard/*` imports from outside `wizard/` and
  `test/` come from the root tsconfig's aggregate include — no `routes/**` or `lib/**`
  module imports anything from `wizard/` (grep over `*.ts`: hits confined to
  `test/wizard-gating.test.ts`, `test/adb-reboot.test.ts`, `test/hosted-channel.test.ts`).
  Conversely, new-route code imports only `lib/**` + `src/hash.ts`.
- Shared-state regression check: `tsconfig.wizard.json` still lists the exact flashcore file
  set + `wizard/**/*.ts` and typechecks clean (exit 0 above); wizard tests all pass within
  the 266-test run; the wizard's static a11y scaffolding is intact (skip link `#workspace`,
  quota/alert roles, `lang`, dialog) and untouched by route additions.
- The two trees share only `channels/` data (read by wizard at runtime via
  `../channels/{tokay|akita}/`, README.md:69) — no coupling introduced by the new routes.

**VERIFIED CLEAN — no relative-path or shared-state regressions detected.**

---

## Findings index

| ID | Severity | Location | Evidence (one line) | One-sentence fix |
|----|----------|----------|--------------------|------------------|
| F1 | **HIGH** | `routes/install/page.html:15` + `package.json:11-18` | Page loads `./early-steps.js` but no build emits route JS (`tsconfig.lib.json` is noEmit; no export script; `routes/install/` holds only `.ts`) | Add a build step compiling `routes/**/*.ts` to sibling `.js` and wire it into `package.json` scripts. |
| F9 | **HIGH** | `tsconfig.json:16-17` (+ `lib/ui/dialog.ts:48`, `lib/ui/rail.ts:195,198`, `test/verify.test.ts:130`, `test/install-state.test.ts:3`, `test/route-verify-recover.test.ts:26,165,183`) | Root `tsc --noEmit` exit 2 with 8 errors, so `npm test`'s first clause and `npm run typecheck` fail before tests run | Align the root config with `tsconfig.lib.json` (add `DOM.Iterable`, scope the include) or replace the aggregate with project references. |
| F2 | MED | `routes/update|verify-device|recover/` (no html) vs PLAN §0 layout | Three mapped routes have no html entry; Phase-5 wiring plan is on record (`READER-C-SITE-SURVEY.md:25`, `PHASE4-LENSES.md:102-103`) | During Phase-5, emit an index.html per route directory from the shared shell (CSP meta included). |
| F3 | MED | `routes/update/update-route.ts:396` | `<link rel="stylesheet" href="/install.css">` — no such file exists anywhere (repo-wide glob zero hits) | Point the update shell at `routes/install/styles-route.css` or emit a dedicated stylesheet. |
| F5 | MED | `routes/install/early-steps.ts:493-500` | Flow-choice buttons expose no `aria-pressed`/state after selection (test pins absence of `aria-checked` at `route-install-early.test.ts:644`) | Set `aria-pressed="true"` on the chosen flow's button at selection time. |
| F6 | MED | `routes/install/early-steps.ts:591-597`; `routes/verify-device/verify-route.ts:252-259` | Retype/compare errors announced globally but never tied to their inputs (`aria-describedby`/`aria-invalid` absent) | Associate error messages via `aria-describedby` + `aria-invalid="true"` and move focus to them. |
| F10 | MED | `tsconfig.routes.json:5` | Empty `"include": []` makes the PLAN §0 build command fail with TS18003 | Populate the include with the route/lib graphs or repoint PLAN §0 at `tsconfig.lib.json`. |
| F4 | LOW | `lib/ui/key-diagram.ts:37-58` vs both stylesheets | `.kd-node/.kd-link/.kd-marker/.key-diagram` classes styled nowhere (default stroke risks invisibility on dark ground) | Add the key-diagram selectors to `routes/install/styles-route.css`. |
| F7 | LOW | `lib/ui/key-diagram.ts:54-56` | Single `aria-labelledby` title for a 3-node SVG (node structure lost to AT) | Keep the title/desc pair or add a visually-hidden list equivalent. |
| F8 | LOW | `routes/install/late-steps.ts:137,194-202` | Wipe checkbox and `<details>` guide related only by prose ("the checkbox above covers this") | Give the guide an id and reference it via `aria-details` from the warning. |

**Severity counts: BLOCKER 0 · HIGH 2 · MED 5 · LOW 3 — total 10.**

## Verdict

The delivery layer's discipline is real where it exists: D-006's CSP is byte-exact at every
producer with a single source of truth and test pins; no inline handler/style/script exists
in any emitted string or shipped bundle; status.json matches the PLAN §0 contract field for
field; the rail/chips/labels/live-region a11y contract is implemented with computed contrast
comfortably clearing AA; and the legacy wizard remains isolated and green. But the site
does **not** yet "load fully offline" as shipped: `/install` points at a script no build
emits (F1), three mapped routes have no html at all pending Phase-5 wiring (F2), and the
update route names a nonexistent stylesheet (F3). Build reproducibility splits in two — the
scoped configs and the full 266-test suite pass cleanly, while the stale aggregate root
config fails typecheck (F9) and the PLAN-named `tsconfig.routes.json` is an empty stub
(F10). The five a11y/build MEDs and three LOWs are one-line-to-one-file fixes queued
naturally for Phase-5.
