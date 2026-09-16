# Q-WEBINSTALL-PAJAMAS-PIXEL Evidence

**Task:** Q-WEBINSTALL-PAJAMAS-PIXEL  
**QA run:** 2026-08-23T15:23:00Z–2026-08-23T15:31:00Z (independent; did **not** trust F token table or +200px residual)  
**Artifact under test:** emitted `dist/site` + route chrome vs published Pajamas templates  
**Depends on:** F-WEBINSTALL-PAJAMAS-TEMPLATES APPROVED  
**QA wrote:** `vendor/guardtalk/web-installer/test/pajamas-pixel.test.ts` (7 tests), this file  
**Not edited:** `routes/`, `lib/`, `scripts/`, `wizard/`, doctrine, governance laws/gates, secrets  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**QA status:** **REVIEW only** (never APPROVED)  
**Chromium overlay:** **not produced** — no `chromium` / `google-chrome` / Playwright in this environment. Measured delta table is the substitute required by the packet.

## Governance

- GIP-0 VERIFIED: workflow `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q cards, PROTOCOL/ROLES, memory-bank (`activeContext.md`, `progress.md` tail, `decisions.md` DEC-010/011/012, `systemPatterns.md`, `projectBrief.md`), AGENTS.md. `governance-condensate.md` absent.
- Prompt-injection shield: **TOOL UNAVAILABLE** (`Not connected`). Manual scan: no role-override / delimiter / encoding injection. Dispatch is Architect-authoritative (ADR-016).
- Gate -1: `gate_enforcer` **TOOL UNAVAILABLE** (`Not connected`). Packet + human skip of `ultimate_critique` in force. Proceeded with manual Gate -1 acknowledgment. Did **not** call `ultimate_critique`. Did **not** fabricate a Gate 5 score.
- Packet path lock: writes only under `vendor/guardtalk/docs/qa/`, `vendor/guardtalk/web-installer/test/`, `.agent-comm/inbox/`, both `TASK_QUEUE.md`. Memory-bank write skipped (not in packet allowlist).

## Environment

| Item | Independent observation |
|------|-------------------------|
| Host | Linux, cwd `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer` |
| Node | `/home/openstatestack/.local/node/bin/node` v22.12.0 (`npm` 10.9.2) |
| Browser | **none** (`which chromium google-chrome playwright firefox` empty) |
| Live :8080 | `python3` pid 416371 already bound to `0.0.0.0:8080` serving `dist/site`. **Not killed.** After `npm run routes:build`, `Last-Modified` on `/install/` became `Sun, 23 Aug 2026 15:26:35 GMT` — same tree. |
| Live device | **none** |
| Published JS | `https://design.guardtalk.io/pajamas/assets/index-D1E98FVb.js` HTTP 200; sha256 `15626c7b642022aae4818bf87c8809e89de4d645c46c23807551a21924b42409` **matches SOURCE.txt** |

---

## Verdict

**FAIL (pixel-perfect) / PASS (security + suite) / HOLD (overlay + live-flash + stale reset header)**

Independent measurement **does not confirm** F's residual as written (`+200px` vs published `~520px`). Published onboarding template source (live JS, hash-matched) is `maxWidth: 560`, not ~520. Installer column is `min(720px, calc(100% - 2 * var(--gl-spacing-8)))` = `min(720px, 100% − 48px)`. Desktop delta vs published onboarding = **+160px**.

Token-level surfaces F listed as 0 (page bg, ink, radius 6px, spacing-8 24px, type 16/1.65, confirm `#C3FF61`, danger alert padding) **do** rematch vendored `--gl-*`. Pixel-perfect vs the published **onboarding template** still **FAIL**s on column width, stepper geometry, and title size/alignment.

**HOLD (not a product restyle fail):**

- No Chromium — no screenshot/overlay paths.
- No live-flash PASS (honesty).
- `design/pajamas/reset.css` header still says it is **NOT concatenated**; `scripts/build-site.sh` **does** concatenate it; emitted `dist/site/install/styles-route.css` contains the reset block (including the stale header comment). Disposition: **stale vendor comment**. Fail-closed still requires `reset.css`. Architect / T residual, not a missing concat.

---

## Check matrix

| ID | Check | Expected | Actual | Verdict |
|----|-------|----------|--------|---------|
| C1 | Measured deltas or overlay per route | table or screenshots | measured table below; **no overlay** | **PASS** (table) / **HOLD** (overlay) |
| C2 | F residual +200px vs ~520px | confirm or FAIL | published onboarding **560px**; installer **720px**; delta **+160px** | **FAIL** (F numbers) |
| C3 | Installer column formula | `min(720px, 100% − 48px)` | `min(720px, calc(100% - 2 * var(--gl-spacing-8)))`; `--gl-spacing-8` = 24px | **PASS** (formula) |
| C4 | Token / type / radius / confirm / danger | 0 vs `--gl-*` | 0 for listed tokens | **PASS** |
| C5 | Pixel-perfect vs published onboarding template | match | column +160; stepper 26 vs 28; title 26px left vs 36px center | **FAIL** |
| C6 | `reset.css` header vs concat | record disposition | header “NOT concatenated”; build + emit **do** concat | **HOLD** (stale comment) |
| C7 | Walk `/install/` siblings + `?sim=1` | 200 + sim label remains | all HTTP/1.0 200; `SIM_LABEL === "SIMULATION"`; banner `data-sim="true"` | **PASS** |
| C8 | D-006 exact in every emitted HTML | 6/6 | all 6 `D006_OK` | **PASS** |
| C9 | claim-lint clean | `claim lint: clean` | CLI exit 0 over 11 route files | **PASS** |
| C10 | grep `dist/site` remote design/font | zero | empty `rg` | **PASS** |
| C11 | `npx tsc --noEmit` | exit 0 | `TSC_EXIT=0` | **PASS** |
| C12 | `test/*.test.ts` green | fail 0 | `# tests 308` `# pass 307` `# fail 0` `# skipped 1` | **PASS** |
| C13 | No live-flash PASS | honesty | none run; `LIVE_FLASH_CLAIMED === false` | **HOLD** (honesty) |

**Overall:** **FAIL** on pixel-perfect / F residual numbers. **PASS** on CSP, claim-lint, dist grep, tsc, suite. **HOLD** overlay + live-flash + reset header.

---

## F residual — confirm or FAIL

F wrote: published 3-step card **~520px**; installer `min(720px, 100% − 48px)`; residual **+200px**.

Independent sources:

1. **Installer (emitted CSS L1595):**  
   `width: min(720px, calc(100% - 2 * var(--gl-spacing-8)));`  
   `--gl-spacing-8: 24px` ⇒ `100% − 48px`. Formula **confirmed**.
2. **Published onboarding template** (live `index-D1E98FVb.js` export `hDe`, sha256 matches SOURCE.txt):

```text
<div style={{ maxWidth: 560, margin: '0 auto' }}>
```

3. **520px in the published system** is **not** the onboarding column. Closest hits: `.gl-modal{width:min(92vw,520px)}` (component) and other catalog templates (`style:{maxWidth:520,margin:"0 auto"}` — sign-in / similar). Onboarding is **560**.

| Claim | F | Independent | Disposition |
|-------|---|-------------|-------------|
| Installer column | 720 / `100% − 48px` | same | **CONFIRM** |
| Published onboarding column | ~520px | **560px** | **FAIL** F number |
| Delta | +200px | **+160px** | **FAIL** F number |

Screenshot/overlay paths: **none** (no Chromium).

---

## Measured delta table (vs published templates)

Published values from hash-matched live JS + vendored `tokens.css` / `components.css`. Route values from `routes/install/styles-route.css` + rendered chrome (tsx, not curl shells).

### Shared tokens / components (all walked routes inherit `styles-route.css`)

| Surface | Published Pajamas | `/install` chrome | Delta | Notes |
|---------|-------------------|-------------------|-------|-------|
| Page background | `--gl-background-color-default` → `#F6F7F5` | reset + body | 0 | |
| Body ink | `--gl-text-color-default` → `#2A2F37` | body / headlines | 0 | |
| Card radius | `--gl-border-radius-base` 6px | `.installer-main` / `.gl-card` | 0 | |
| Card / form gap | `--gl-spacing-8` 24px | `.installer-main` padding; `.gl-form-layout` gap | 0 | |
| Type size / leading | 16px / 1.65 | `--gl-font-size-base` / `--gl-line-height-base` | 0 | |
| Confirm CTA fill | `--gl-action-confirm-bg` / `#C3FF61` | `.gl-button--confirm-primary` | 0 | |
| Danger CTA fill | `--gl-action-danger-bg` / `#C2362D` | `.gl-button--danger-primary` | 0 | |
| Alert STOP padding | `--gl-spacing-6` 16px | `.gl-alert` | 0 | |
| Dashed choice | 1px dashed `--gl-border-color-strong` | `.flow-pick` | 0 | token; class kept `flow-pick` |
| Inline hex in route/wizard CSS | none | `rg` empty | 0 | |

### Onboarding template (primary)

Published onboarding is a **3-step** centered card (`Account / Workspace / Invite`), not a 10-step rail.

| Surface | Published onboarding (`hDe`) | Route | Delta | Route(s) |
|---------|------------------------------|-------|-------|----------|
| Column max width | **560px** | **720px** (`min(720px, 100% − 48px)`) | **+160px** | `/install/`, `/install/update/`, `/install/verify-device/`, `/threat-model/` (`.installer` / `.route` / `body.route-update`) |
| Page padding | `--gl-spacing-9` (32px) all sides | `32px 0 48px` (`--gl-spacing-9` / `11`) | +16px bottom; 0 horizontal on the column rule | same |
| Title size | `--gl-font-size-h1` **36px**, centered | `--gl-font-size-h2` **26px**, start | **−10px**; alignment | `/install/` chrome h2; update uses `<h1>` in header without h1 size override → 36px browser default unless reset; reset does not set h1 size |
| Stepper | custom **28×28** gradient dots | `.gl-stepper-marker` **26×26** (`24+2`) | **−2px**; fill differs (border vs brand gradient) | `/install/`, `/install/update/` |
| Back / Next | `Button category="secondary"` + `variant="confirm"` | `gl-button--default-secondary` + `gl-button--confirm-primary` | 0 class intent | `/install/` |
| Card | `<Card>` (`gl-card`) | `.installer-main.gl-card` | 0 | `/install/`, update, threat-model |

F's stepper “0 vs `.gl-stepper-marker`” is true against **component CSS**, not against the **published onboarding template** (which does not use `.gl-stepper`).

### Settings / danger-zone

| Surface | Published settings (`iDe`) | `/install/recover/` | Delta |
|---------|----------------------------|---------------------|-------|
| Danger card | `<Card style={{ borderColor: var(--gl-feedback-danger) }}>` | `.recover-danger-zone.gl-card` + `data-zone="danger"` | composed; route also sets **danger background** (`--gl-feedback-danger-bg`) |
| Danger title | h2 color `--gl-feedback-danger` | h2 inherit + `gl-alert--danger` title “Danger zone” | composed |
| Danger alert | `<Alert variant="danger">` | `glAlertHtml("danger", …)` | 0 |
| Danger button | `<Button variant="danger">` | `gl-button--danger-primary` | 0 |
| Settings rail | 200px sticky + 1fr | **not used** (single column 720) | layout residual |

### Alerts

| Surface | Published | Route | Delta | Route(s) |
|---------|-----------|-------|-------|----------|
| `.gl-alert--danger` | danger-bg + danger ink | same class | 0 | verify hard-stop; recover; install mismatch |
| `.gl-alert--warning` | warning tokens | same class | 0 | `/install/?sim=1` banner; `/threat-model/` list |

### Per-route chrome walk (rendered HTML, not empty shells)

| Route | HTTP | Chrome present | Notes |
|-------|------|----------------|-------|
| `/install/` | 200 / 811 shell | `gl-onboarding`, `gl-card`, `gl-stepper`, confirm CTA | column 720 |
| `/install/update/` | 200 / 721 | onboarding + stepper + link buttons | `?sim=1` → “SIMULATED DEVICE — NOTHING TOUCHES HARDWARE” |
| `/install/verify-device/` | 200 / 728 | `gl-onboarding`; hard-stop `gl-alert--danger` | no 10-step rail |
| `/install/recover/` | 200 / 723 | danger-zone + danger alert + danger CTA | settings/danger composition |
| `/threat-model/` | 200 / 2237 static | `gl-onboarding` + warning alerts + link buttons | skip-link present |
| `/install/?sim=1` | 200 (same shell) | `SIM_LABEL` = `SIMULATION`; banner `data-sim="true"` | label **remains** |

---

## reset.css disposition

```text
design/pajamas/reset.css:2
  GuardTalk Pajamas document reset (NOT concatenated into dist — would restyle route HTML).

scripts/build-site.sh:64-70
  cat "$VENDOR_TOKENS" "$VENDOR_RESET" "$VENDOR_TEMPLATES" "$VENDOR_COMPONENTS" \
      wizard/styles.css routes/install/styles-route.css \
      > "$SITE/install/styles-route.css"

dist/site/install/styles-route.css:126
  same “NOT concatenated” comment, then `*{box-sizing:border-box}`
```

**Disposition:** comment is stale. Concat is intentional (F + D-006 system fonts only). Emitted site **does** include reset. Recommend T/F fix the header to say it **is** concatenated. Not a runtime fail.

---

## Raw command output

Working directory: `vendor/guardtalk/web-installer`  
`export PATH=/home/openstatestack/.local/node/bin:$PATH`  
Timestamp: **2026-08-23T15:26:00Z–15:31:00Z**

```text
===== TSC =====
TSC_EXIT=0

===== CLAIM LINT CLI =====
claim lint: clean
CLAIM_LINT_EXIT=0

===== ROUTES BUILD =====
site written to /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/web-installer/dist/site
BUILD_EXIT=0

===== DIST GREP =====
rg -n "design.guardtalk.io|@import url\(http|fonts.googleapis" dist/site
DIST_GREP_DONE
(no hits)

===== D-006 =====
D006_OK dist/site/index.html
D006_OK dist/site/install/index.html
D006_OK dist/site/install/recover/index.html
D006_OK dist/site/install/update/index.html
D006_OK dist/site/install/verify-device/index.html
D006_OK dist/site/threat-model/index.html

===== CURL WALK =====
/install/                  HTTP/1.0 200 OK  Content-Length: 811
/install/update/           HTTP/1.0 200 OK  Content-Length: 721
/install/verify-device/    HTTP/1.0 200 OK  Content-Length: 728
/install/recover/          HTTP/1.0 200 OK  Content-Length: 723
/threat-model/             HTTP/1.0 200 OK  Content-Length: 2237
/install/?sim=1            HTTP/1.0 200 OK  Content-Length: 811
/install/styles-route.css  HTTP/1.0 200 OK  Content-Length: 171642

===== LIVE JS =====
js_http=200 bytes=1753904
15626c7b642022aae4818bf87c8809e89de4d645c46c23807551a21924b42409  /tmp/q-pixel-pajamas.js
ONBOARDING maxWidth: 560

===== FULL SUITE =====
# tests 308
# pass 307
# fail 0
# skipped 1
# (pagehide hook: installs and uninstalls cleanly when window exists # SKIP)
TEST_EXIT=0

===== PIXEL TESTS =====
# tests 7
# pass 7
PIXEL_TEST_EXIT=0

===== LIVE_FLASH =====
src/types.ts:119 export const LIVE_FLASH_CLAIMED = false;
```

Existing :8080 server left bound (pid 416371).

---

## New tests

`vendor/guardtalk/web-installer/test/pajamas-pixel.test.ts` — **7/7 pass**

1. Installer column formula `min(720px, 100% − 48px)`  
2. Token surfaces (bg, ink, radius, type, confirm, danger, stepper marker, danger-zone)  
3. `reset.css` header vs `build-site.sh` concat  
4. Emitted D-006 + zero remote refs  
5. claim-lint over route sources  
6. `?sim=1` / `SIM_LABEL === "SIMULATION"`  
7. `LIVE_FLASH_CLAIMED === false`  

Did **not** restyle product pages. Did **not** add a Chromium/Playwright dependency.

---

## Existing suite (final)

```text
# tests 308
# pass 307
# fail 0
# skipped 1
TEST_EXIT=0
```

Pre-F suite after Architect re-run was 301 (300/1). +7 pixel tests = 308. Skip is the same `keys.test.ts` pagehide hook (no `window` in Node). No test selectors needed updating (F already fixed `wizard-gating.test.ts`).

---

## Self-critique note (no Gate 5 score)

Human directive: skip `ultimate_critique`; do not fabricate a Gate 5 score. **No score is reported.**

Manual COT-006:

1. CLASSIFY: QA evidence + measurement tests  
2. CORE LAWS: Law 0 (Architect dispatch); Law 2 (allowed paths only); Law 4 (CSP / no remote); Law 7 (did not trust F 520/+200; live-fetched JS; rematched hash); Law 11 (tests removable); Law 12 (doctrine/governance untouched); Law 13 (no harmful fixtures)  
3. EXTENDED: Law 16 (308/307/1); Law 17 (no PII); Law 19 (this file); Law 21 (skip-link + word chips observed, not a full a11y audit)  
4. GATES: Gate -1 MCP unavailable; Gate 5 skipped by human; no fabricated score  
5. SCOPE: matches Q card  
6. CONFIDENCE: 8/10 on published 560 vs installer 720; 9/10 on CSP/suite; 3/10 on pixel-perfect (explicit FAIL)  
7. VERDICT: **FAIL** (pixel-perfect / F residual numbers) / **PASS** (security + suite)

`hallucination_guard` / `self_critique` MCP: **TOOL UNAVAILABLE** (`Not connected`). Numeric claims copied from command output in this session.

### PQE Assessment: Code Entropy **LOW** (tokens) / **MEDIUM** (template fidelity)

One `--gl-*` vocabulary is in force. Entropy rise: published onboarding is a 3-step 560px centered demo; installer is a 10-step 720px rail. F measured against component tokens, not the published template source. Stale `reset.css` header vs concat is a comment/entropy leak.

Adversarial: (1) 520px exists on **modal / other templates** — easy to mis-attribute to onboarding; (2) curl `?sim=1` cannot prove the chip (JS); proved via `isSimMode` + `simBannerHtml`; (3) no Chromium means layout px are CSS-declared, not painted.

---

## AC checklist

- [x] Evidence with overlays **or** measured deltas per route — **table yes; overlay HOLD**  
- [x] CSP D-006 exact; claim-lint clean  
- [x] No `design.guardtalk.io` in emitted site  
- [x] Full `test/*.test.ts` green (307 pass / 1 skip)  
- [x] No live-flash PASS  
- [x] F +200 / ~520 residual independently measured — **FAIL those numbers; +160 vs 560**  

---

## Files

- Evidence: `vendor/guardtalk/docs/qa/Q-WEBINSTALL-PAJAMAS-PIXEL_EVIDENCE.md`  
- Tests: `vendor/guardtalk/web-installer/test/pajamas-pixel.test.ts`  
- Reports: `.agent-comm/inbox/TO_ARCHITECT.md` and `.agent-comm/inbox/TO_ARCHITECT_Q-WEBINSTALL-PAJAMAS-PIXEL.md`  
- Screenshot/overlay paths: **none**
