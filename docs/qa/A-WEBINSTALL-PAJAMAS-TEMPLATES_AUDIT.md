# A-WEBINSTALL-PAJAMAS-TEMPLATES — Independent Audit

- **Task:** A-WEBINSTALL-PAJAMAS-TEMPLATES (`audit_scope: full`)
- **Auditor:** AEGIS Independent Auditor (read-only). No product, test, or doctrine edits.
- **Timestamp:** 2026-08-23T19:30:00+04:00 (2026-08-23T15:30:00Z)
- **Depends on:** F-WEBINSTALL-PAJAMAS-TEMPLATES APPROVED (Architect 2026-08-23T15:22:00Z)
- **Pair still open:** Q-WEBINSTALL-PAJAMAS-PIXEL DISPATCHED (no QA overlay in this session)
- **Targets:** `vendor/guardtalk/web-installer/` (routes, wizard chrome, vendored Pajamas, `dist/site`, flash/custody, claims)
- **Status:** **REVIEW only.** Auditor does not APPROVE.

## Gate -1 / Gate 5

- `gate_enforcer` MCP: **TOOL UNAVAILABLE** (`Not connected`).
- Guardian HTTP fallback `http://guardian.aegis.openstatestack.dev/v1/chat/completions`: **Permanent Redirect** (not a pass body).
- Proceeded on Architect packet (ADR-016) + human skip of `ultimate_critique`.
- **No Gate 5 score is reported.** `ultimate_critique` was not called.

## Verdict: CONFORMANT WITH FINDINGS

D-006, no runtime `design.guardtalk.io`, no inline hex/style/handlers in route shells, custody/honesty, and flash-order semantics hold. Signal-green on `/install` CTAs and verified chips is rationed as specified.

The **pixel-perfect claim is FAIL with measurements** (onboarding column **+200px**; no Chromium overlay). One **HIGH** Law 21 finding: vendored confirm-primary ink is nearly invisible on signal green (**1.10:1**). Prior `A-WEBINSTALL-PAJAMAS` MEDIUM findings stay closed; F5 contrast is **reopened** under the new light tokens.

**Not a live-flash GO.** `LIVE_FLASH_CLAIMED === false`. No machine/flash change observed.

| Severity | Count |
|----------|------:|
| BLOCK | 0 |
| CRITICAL | 0 |
| HIGH | 1 |
| MEDIUM | 0 |
| LOW | 3 |
| INFO | 3 |

---

## Independent verification (this session)

Cwd: `vendor/guardtalk/web-installer`. `PATH=/home/openstatestack/.local/node/bin:$PATH`. Node v22.12.0 / npm 10.9.2. No Chromium binary. No live USB.

```text
npx tsc --noEmit
TSC_EXIT:0

npx tsx --test --test-timeout=60000 test/*.test.ts
# tests 301
# pass 300
# fail 0
# skipped 1
# (pagehide hook: installs and uninstalls cleanly when window exists # SKIP)
TEST_EXIT:0

rg -n "design.guardtalk.io|@import url\(http|fonts.googleapis" dist/site
# empty
DIST_GREP_DONE

rg -n "LIVE_FLASH_CLAIMED" src/types.ts
119:export const LIVE_FLASH_CLAIMED = false;
```

D-006 exact string in all 6 emitted HTML files:

`default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'`

```text
D006_OK dist/site/index.html
D006_OK dist/site/install/index.html
D006_OK dist/site/install/recover/index.html
D006_OK dist/site/install/update/index.html
D006_OK dist/site/install/verify-device/index.html
D006_OK dist/site/threat-model/index.html
```

`rg -n "style=|onclick=|onerror=|onload=" dist/site --glob '*.html'` → empty.
Same empty on `routes/**/*.html`.

Published HTML (auditor fetch, **not** a runtime installer fetch): `https://design.guardtalk.io/pajamas/` HTTP 200, 936 bytes, sha256 `89c9066261d2a7dd49419b74620f7e0a66fcadd06db26d5b4ca1f588bbbd186c` — matches `design/pajamas/SOURCE.txt`.

Git (`vendor/guardtalk` project) name-only + `git status --short` on `web-installer/src`, `lib/avb`, `lib/fastboot`, `lib/keys`, `lib/install-state`, `lib/verify`, `routes/install/flash-runner.ts`: **empty**.

---

## Pixel-perfect claim

**FAIL with measurements.** Token chrome matches. Column width does not. Screenshot overlay was not run here and was not run by F.

| Surface | Published / vendored source | Installer | Delta | Result |
|---|---|---|---|---|
| Page background | `--gl-background-color-default` = `--gl-color-neutral-50` `#F6F7F5` | `tokens.css` + reset/wizard `body` | 0 | MATCH |
| Body text | `--gl-text-color-default` `#2A2F37` | body / headlines | 0 | MATCH |
| Card radius | `--gl-border-radius-base` **6px** | `.installer-main` / `.gl-card` | 0 | MATCH |
| Card / form gap | `--gl-spacing-8` **24px** | `.installer-main` padding; `.gl-form-layout` gap | 0 | MATCH |
| Type / leading | **16px / 1.65** | `--gl-font-size-base` / `--gl-line-height-base` | 0 | MATCH |
| Stepper marker | `width/height: calc(var(--gl-spacing-8) + var(--gl-spacing-2))` = **26×26**, radius full | same class | 0 | MATCH |
| Confirm fill | `--gl-color-brand-500` **`#C3FF61`** | `--gl-action-confirm-bg` | 0 | MATCH (fill only) |
| Confirm **ink** | compiled `.gl-button--confirm-primary` → `--gl-action-primary-text` `#F6F7F5` | same vendored rule | 0 vs source; **1.10:1** vs WCAG | see H1 |
| Danger CTA fill | `--gl-action-danger-bg` `#C2362D` | recover unlock/relock `GL_BTN_DANGER` | 0 | MATCH |
| Dashed choice | 1px dashed `--gl-border-color-strong`, transparent fill | `.flow-pick` (`styles-route.css:443-455`) | 0 | MATCH |
| Onboarding column | F residual / `.gl-modal` **520px** in vendored CSS | `.installer` / `.route` `min(720px, 100% − 2×spacing-8)` (`styles-route.css:10`) | **+200px** | **FAIL** |
| Chromium overlay | required for pixel-perfect close-out | `command -v chromium` / `google-chrome` → **NO_CHROMIUM** | n/a | **UNVERIFIED** |

Notes on the 520px reference (honesty):

- Vendored compiled CSS contains **one** `520px` (`.gl-modal{width:min(92vw,520px)}`) and **one** `720px` (`.gl-bottom-sheet`). The string `onboarding` does **not** appear in `compiled/index-BFboFyqJ.css`.
- Published `/pajamas/` HTML is a 936-byte React shell. This auditor did not render `#/templates/` (no Chromium).
- F’s “3-step card ~520px” is therefore **accepted as F residual**, not independently screenshot-proven. The **720px** column **is** independently read from `routes/install/styles-route.css:10` and emitted `dist/site/install/styles-route.css`.

Architect already bound this residual when approving F. Q-PIXEL remains the overlay owner.

---

## D-006 + no runtime design-site

**PASS.**

- CSP constant `lib/claims/csp.ts` and all six route/root shells use `connect-src 'none'` exact.
- `scripts/build-site.sh` concatenates vendor tokens/reset/templates/components + wizard + route CSS as `'self'` and fail-closes on `design.guardtalk.io` / `@import url(http` / `fonts.googleapis`.
- `dist/site` grep this session: empty.
- Route TypeScript does not fetch `design.guardtalk.io`. SOURCE.txt / CATALOG.txt may name the URL as **docs**, not a runtime import.
- Not a React SPA rewrite. Route shells stay static HTML + module scripts.

---

## Inline hex / style / handlers (route shells)

**PASS** for `/install/` and siblings.

- `routes/**/*.html`: no `style=`, `onclick=`, `onerror=`, `onload=`. No inline `<style>` / `<script>` bodies. Stylesheets are `href` only; scripts are `src` only.
- `routes/**/*.{html,ts,css}` and `lib/ui/**` and `wizard/styles.css`: **no `#RRGGBB` hex**. Hex lives only in vendored `design/pajamas/tokens.css` / `components.css` (build-time).
- Viewport `initial-scale=1` is not an inline style.

Wizard `index.html` still uses `class="danger"` / `class="secondary"` (no hex, no inline handlers). Out of `/install/` shell AC; listed for prior-finding disposition.

---

## Signal-green rationing (DEC-011)

**PASS on `/install` routes, with INFO residuals.**

Allowed uses observed:

- Confirm CTAs via `GL_BTN_CONFIRM` → `gl-button--confirm-primary` (Next / continue / pair / flash-start).
- Verified chips via `makeChip(..., "verified")` → `chip-verified` + `gl-badge--success` (words mandatory; empty word throws).
- Dashed equals (`.flow-pick`) are **transparent**, not confirm fill. Specificity `0-1-0` beats concatenated wizard `button { background: var(--gl-action-confirm-bg) }` (`0-0-1`).
- Recover wipe/lock uses `GL_BTN_DANGER`, not confirm green.
- Tripwire / caution chips use danger / warning tokens.

INFO residuals (not rationing fails):

- Vendored Pajamas paints **completed stepper markers** and **progress fills** with `--gl-action-confirm-bg` (`components.css:362`, `styles-route.css:538-542`). That is catalog chrome, not a new installer invention.
- Wizard unmarked buttons (`#btn-reboot-fastboot`, `#btn-connect`, `#reconnect-btn`) inherit the generic `button` confirm fill. Wizard is not a `/install/` shell. High-emphasis actions; still a leak surface if that page is served.
- Skip-link and checkbox `accent-color` use confirm tokens (`wizard/styles.css:23,162`).

---

## Custody / honesty / DEC-012

**PASS. No machine/flash change.**

| Check | Evidence | Result |
|---|---|---|
| `LIVE_FLASH_CLAIMED` | `src/types.ts:119` `export const LIVE_FLASH_CLAIMED = false;` | **false** |
| Flash order | `src/types.ts:7` `["firmware", "avb_custom_key", "os"]` | unchanged (DEC-006) |
| `proveVbmetaUserSigned` | `lib/verify/user-anchor.ts:16-33`; called from `routes/install/flash-runner.ts:189` and `routes/update/update-route.ts:558` before write | unchanged spine |
| Install-state / AVB / keys / fastboot / flash-runner git | empty name-only + short status | no diff |
| Q-01…Q-14 `// confirm` | still shipped (`early-steps.ts:57-64`, update Q-08 note, claims `// confirm with counsel`) | unchanged |
| Suite honesty | 300 pass / 1 skip; wizard tests still refuse live `executePlan` / `lock` | no live-flash PASS |
| Live USB | not attached; not attempted | **HOLD** (honesty) |

---

## `reset.css` header vs `build-site.sh` concat

**Disposition: DOCUMENTATION DRIFT — LOW. Not a D-006 defect.**

| Artifact | Says |
|---|---|
| `design/pajamas/reset.css:2` | “NOT concatenated into dist — would restyle route HTML.” |
| `scripts/build-site.sh:38-70` | Concatenates `$VENDOR_RESET` after tokens, before templates/components. Comment L41-42: reset is included so route HTML matches published chrome. Fail-closed still requires the file. |

Live contract is the script. The header is stale (T-era comment; F later concatenated). Architect already recorded this residual on Q-VENDOR / F APPROVED. Auditor does not edit. Recommend a one-line header correction on a later F card.

---

## Prior `A-WEBINSTALL-PAJAMAS` findings

Base: `vendor/guardtalk/docs/qa/A-WEBINSTALL-PAJAMAS_AUDIT.md` (2026-08-21). Code-fix wave: `Q-WEBINSTALL-PAJAMAS-FIXES_EVIDENCE.md` (2026-08-22, PASS). Re-spot-checked after F-TEMPLATES token swap.

| # | Orig. sev | Topic | Disposition after F-TEMPLATES | Notes |
|---|---|---|---|---|
| F1 | MEDIUM | No danger variant on Unlock/Flash/Lock | **CLOSED** | `wizard/index.html:132-134` `class="danger"`; reboot stays non-danger |
| F2 | MEDIUM | Esc leaves reconnect promise pending | **CLOSED** | `wizard/main.ts:137-161` abort path + finally clears waiter |
| F3 | MEDIUM | No busy / double-activation guard | **CLOSED** | `aria-busy`, `runGuardedAction` settle→refresh→restore (`main.ts:196-211`) |
| F4 | MEDIUM | `#quota-box` not announced | **CLOSED** | `role="alert"` (`index.html:107`) |
| F5 | LOW | Secondary border 1.3:1 (dark `--line`) | **REOPENED (LOW)** | `--line-strong` now `var(--gl-border-color-strong)` = `#D8DDE3`. Independent WCAG: **1.37:1** on `#FFFFFF`, **1.27:1** on `#F6F7F5` (1.4.11 needs 3:1). Token-inherited light theme. See L2 |
| F6 | LOW | No hover/active | **CLOSED** | `wizard/styles.css` hover/active on button / secondary / danger / select |
| F7 | LOW | Dead `.cmd` | **RESIDUAL (LOW)** | `.cmd` still defined (`wizard/styles.css:278`); still unused in `wizard/index.html` |
| F8 | LOW | Checkbox &lt;24px | **CLOSED** | `1.5rem` (`wizard/styles.css:157-159`) |
| F9 | LOW | Errors only polite | **CLOSED** | `#alert-text` `role="alert"` (`index.html:150`) |
| F10 | INFO | Tokens not Pajamas names | **CLOSED** | `--gl-*` only in wizard/route chrome |
| F11 | INFO | System font vs Inter | **CLOSED (intentional)** | `--gl-font-family` names Space Grotesk/Inter with **system-ui fallbacks**; no `@font-face` / Google Fonts (D-006) |
| F12 | INFO | Off-grid spacing / radii | **CLOSED** | 8px spacing scale; radius 6px from vendor `--gl-border-radius-base` |
| F13 | INFO | No `prefers-reduced-motion` | **CLOSED** | `styles-route.css:609-614` + vendored `components.css:8` |
| F14 | INFO | Banner variant semantics | **CLOSED on routes** | `/threat-model/` and route alerts use `gl-alert--*`. Wizard banners remain local classes |

---

## Findings (this audit)

### HIGH

#### H1 — Confirm-primary ink is 1.10:1 on signal green (Law 21)

Vendored (and published compiled) rule:

`design/pajamas/components.css:15` / compiled `index-BFboFyqJ.css`:

`.gl-button--confirm-primary{background:var(--gl-button-confirm-bg);color:var(--gl-action-primary-text)}`

Light tokens:

- `--gl-button-confirm-bg` → `#C3FF61`
- `--gl-action-primary-text` → `#F6F7F5`
- Unused better token: `--gl-button-confirm-text` → `#0A0B0C` (**16.69:1** on the same fill)

Independent relative-luminance: **1.10:1** (WCAG 1.4.3 / 1.4.6 fail). Every `/install` Next/Continue uses `GL_BTN_CONFIRM` (`lib/ui/pajamas.ts:13-14`). Specificity of `.gl-button--confirm-primary` (0-1-0) beats wizard `button { color: var(--gl-action-confirm-text) }` (0-0-1), so the dark ink on the generic `button` rule does **not** save route CTAs.

This matches published Pajamas CSS (pixel-perfect to a broken source). It still fails Law 21 on the installer. Q-PIXEL should screenshot; a later F card should map confirm-primary color to `--gl-button-confirm-text` (or equivalent) without touching flash/custody.

Danger-primary uses the same `--gl-action-primary-text` on `#C2362D` → **5.06:1** (AA pass). H1 is confirm-only.

### LOW

#### L1 — Onboarding column +200px; no overlay

`styles-route.css:10` `width: min(720px, calc(100% - 2 * var(--gl-spacing-8)))` vs F/catalog 3-step ~520px / `.gl-modal` 520px. No Chromium in this environment. Pixel-perfect claim **FAIL**. Architect-accepted F residual; Q-PIXEL still owns screenshots.

#### L2 — Secondary / dashed border contrast reopened under light `--gl-*`

`--gl-border-color-strong` `#D8DDE3` on `#FFFFFF` = **1.37:1**; on `#F6F7F5` = **1.27:1**. Affects `.flow-pick` and `.gl-button--default-secondary`. Prior F5 fix (`#6b7887` on dark elev = 3.60:1) is gone with the theme swap. Token-inherited; still a 1.4.11 miss.

#### L3 — `reset.css` header contradicts concat

See disposition above. Docs drift only.

### INFO

#### I1 — Q-PIXEL not finished

Overlay / measured-delta evidence file does not exist. This audit used CSS/token math only.

#### I2 — Wizard generic `button` confirm fill

`wizard/styles.css:192-201` paints every unmarked `<button>` signal green. Overridden on `/install` by `.gl-button*` / `.flow-pick`. Residual if `wizard/index.html` is still served.

#### I3 — Progress / completed-stepper inherit confirm fill from Pajamas

Catalog behavior. Not a new leak invented by F. Noted so rationing reviews do not treat it as a surprise.

---

## Law / DEC statements

- **DEC-WEBINSTALL-010:** PASS — vendor at build time; runtime CSP `connect-src 'none'`; no React SPA.
- **DEC-WEBINSTALL-011:** PARTIAL — `--gl-*` only in route/wizard chrome; signal green rationed on routes; H1/L2 are token/component defects, not new hex.
- **DEC-WEBINSTALL-012:** PASS — flash order, `proveVbmetaUserSigned`, custody, `LIVE_FLASH_CLAIMED`, install-state, Q-01…Q-14 `// confirm` unchanged.
- **DEC-WEBINSTALL-005:** PASS (no GOS verbatim copy in this restyle; system fonts only).
- **Law 4 / D-006:** PASS.
- **Law 16:** PASS for host/mocked suite (300/1). Overlay unverified.
- **Law 21:** FAIL on confirm CTA contrast (H1); text-on-background pairs independently pass (body **12.52:1**, subtle **4.52:1**).
- **Law 7:** Pixel-perfect overlay marked UNVERIFIED; 520px published card width not screenshot-proven.

---

## Recommended Architect follow-ups (do not create from Auditor)

1. Keep Q-WEBINSTALL-PAJAMAS-PIXEL DISPATCHED until Chromium overlay + H1 visual confirm.
2. Optional F card: confirm-primary color → `--gl-button-confirm-text`; fix `reset.css` header to match concat; do not touch flash/custody.
3. Do not treat this REVIEW as live-flash GO.

---

## AC checklist

- [x] Written audit; pixel-perfect claim **FAIL with measurements** (+200px; no overlay)
- [x] D-006 exact; no runtime design-site; no inline hex/style/handlers in route shells
- [x] Signal-green rationing confirmed on `/install` (CTA + verified chips)
- [x] Prior findings disposition table
- [x] Custody/honesty: `LIVE_FLASH_CLAIMED` false; no machine/flash change
- [x] `reset.css` vs concat disposition recorded
- [x] Status REVIEW only; no Gate 5 score; no git push
