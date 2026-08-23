# A-WEBINSTALL-PAJAMAS — Design-Conformance Audit (GuardTalk Pajamas)

- **Task:** A-WEBINSTALL-PAJAMAS (`.agent-comm/TASK_QUEUE.md` line 112)
- **Auditor:** AEGIS Auditor (read-only). Gate -1 consulted (Guardian proxy fallback: compliant).
- **Timestamp:** 2026-08-21T07:05:00Z
- **Targets:** `wizard/index.html` (177 lines), `wizard/styles.css` (295 lines), classes/ids referenced from `wizard/main.ts` (265 lines)
- **VERDICT: CONFORMANT WITH FINDINGS**

## Scope & method

- Full read of the three target files; cross-checked dynamic class names (`log-line log-*`, `callout danger`) against `main.ts`.
- Pajamas reference: fetched `https://design.guardtalk.io/pajamas/#/components` (reachable). It confirms the **Button** API is category × variant × size with variants `default | confirm | danger | dashed | link`. All other Pajamas conventions (token names `$blue-500`/`$gray-950`, 8px spacing grid, 4/8px radii, alert icon/role conventions, Inter font) are **assumed standard GitLab-Pajamas conventions** and are marked as such below.

## Conformance matrix

| Dimension | Result | Rationale |
|---|---|---|
| 1. Design tokens | **PARTIAL** | Clean bespoke custom-property system (`--bg/--ink/--muted/--line/--copper/--ok/--warn/--danger/--focus`, styles.css:1-16) with semantics analogous to Pajamas ($gray-950≈`--ink`, $red-500≈`--danger`), but no Pajamas token names/values, spacing off the 8px grid (0.55rem/0.85rem), radii 0.4/0.6rem vs 4/8px, system font stack vs Pajamas Inter (assumed). |
| 2. Components | **PARTIAL** | Buttons implement only confirm-like (base) + default (`.secondary`) variants; **no danger variant** for destructive Unlock/Flash/Lock (index.html:132-134). Banners use border-left color coding (dev=warn, parity=brand, hold=danger) — reasonable but lack Pajamas alert icon/role conventions (assumed). `.cmd` class is dead CSS (styles.css:237-246, referenced nowhere). |
| 3. States & interaction | **PARTIAL** | `:focus-visible` rings present and not removed (styles.css:208-214), disabled state present (203-206), skip link works (29-41). Missing: `:hover`/`:active` states entirely; no busy/loading state during async actions; reconnect dialog Esc key deadlocks the await. |
| 4. Accessibility (Law 21, WCAG 2.1 AA) | **PARTIAL** | Strong: `lang="en"`, landmarks (header/nav[aria-label]/main/footer/dialog), heading order h1→h2→h3, `for=` label, wrapped checkbox, `role="status"` + `aria-live="polite"` (index.html:150-151). Contrast passes AA for all text pairs (see calculations). Failures: `--line` border on `--bg-elev` 1.3:1 (<3:1, WCAG 1.4.11) for secondary-button boundary; quota `callout.danger` shown dynamically with no live region; errors announced only politely. |
| 5. Branding / licensing | **PASS** | GuardTalkOS branding in title/eyebrow/footer (index.html:6,12,170). No GrapheneOS verbatim HTML/CSS/copy (see statement below). No third-party font/CSS/JS assets; system font stack only; NOTICE documents originality. |

## Findings

| # | Severity | Location | Finding | Fix |
|---|---|---|---|---|
| F1 | MEDIUM | index.html:132-134 | Destructive actions (Unlock/Flash/Lock — wipe user data) rendered as brand-primary buttons; no Pajamas `danger` variant | Add `.danger` button variant (red-500-equivalent token, white/near-white ink) and apply to `btn-unlock`/`btn-flash`/`btn-lock` |
| F2 | MEDIUM | main.ts:120-131 | `waitForReconnect()` resolves only via `#reconnect-btn` click; Esc (dialog `cancel`) closes the dialog but leaves the promise pending — flash flow hangs silently, worse for keyboard users | Listen for dialog `cancel`/`close`; on cancel re-show or resolve with an abort path |
| F3 | MEDIUM | main.ts:133-143; index.html:130-135 | No busy/loading state during async actions; triggering button stays enabled → double-activation (e.g. double flash) possible | Disable triggering control + set `aria-busy="true"` in `runAction` while in flight; restore after |
| F4 | MEDIUM | index.html:107-110; main.ts:110-113 | `#quota-box` flips hidden→shown with `callout danger` with no live region — SR users never hear the low-quota/private-window warning | Add `role="alert"` (or `aria-live="assertive"`) to `#quota-box` |
| F5 | LOW | styles.css:197-201 | `.secondary` border `--line` (#2c3640) on panel `--bg-elev` = 1.3:1 — fails WCAG 1.4.11 (3:1) for the component-boundary affordance (text itself passes at 13.7:1) | Introduce `--line-strong` (≥3:1 vs `--bg-elev`, e.g. #46525e) for control borders |
| F6 | LOW | styles.css:186-206 | No `:hover`/`:active` states on any control (Pajamas hover conventions, assumed) — pointer feedback is cursor-only | Add hover darken/shift for base+secondary buttons and select |
| F7 | LOW | styles.css:237-246 | `.cmd` class defined but unused anywhere (dead CSS); inline `<code>` in checklist is unstyled | Either remove `.cmd` or apply it to the command snippets in the host-check list |
| F8 | LOW | index.html:86-89 | Native checkbox ≈13px target (<24px, WCAG 2.2 SC 2.5.8; not a 2.1 AA failure — spacing exception unlikely) | `#private-hint { width/height: 1.25rem; accent-color: var(--copper); }` |
| F9 | LOW | main.ts:139-140 | Errors written to `role="status"` (polite) region — failures may be missed/deferred by AT | Route errors to a `role="alert"` region; keep routine progress polite |
| F10 | INFO | styles.css:1-16 | Tokens don't reference Pajamas names/values (`$gray-950`, `$blue-500`, …) — mapping is by semantics only | Add comment block mapping `--ink→$gray-950(dark-inverted)`, `--danger→$red-500`, etc., or alias real Pajamas tokens |
| F11 | INFO | styles.css:15 | Font stack "Segoe UI"/system vs Pajamas Inter (assumed convention); no webfont loaded (good for offline/licensing) | Acceptable; document as intentional deviation in NOTICE/README |
| F12 | INFO | styles.css (passim) | Spacing 0.55/0.65/0.85/1.15rem off the 8px grid; radii 0.4/0.6rem vs Pajamas 4/8px | Snap to 0.5rem multiples / 0.25-0.5rem radii in a token pass |
| F13 | INFO | styles.css (passim) | No animations/transitions exist, so `prefers-reduced-motion` is N/A today | Add a reduced-motion guard if transitions are ever introduced |
| F14 | INFO | index.html:22-36 | Banner semantics: dev=warning, hold=danger are apt; parity banner uses brand copper where Pajamas would use info/neutral (assumed) | Optional: add icons + explicit variant classes |

Note on "Reboot to Fastboot" (index.html:83): base/confirm-style variant is **appropriate** — it is a non-destructive, recoverable device action, unlike Unlock/Flash/Lock (F1).

## Contrast calculations (WCAG relative luminance; L = 0.2126R+0.7152G+0.0722B, linearized sRGB)

1. **Body text `--ink` #e8edf2 on `--bg` #12151a** → R_lin 0.8069, G_lin 0.8469, B_lin 0.8879 → L=0.8413; bg L=0.0074 → (0.8913)/(0.0574) = **15.5:1** — PASS AAA.
2. **Muted text `--muted` #9aa6b2 on panel `--bg-elev` #1b2129** (lede/notes/banners) → L(#9aa6b2)=0.3736; L(#1b2129)=0.0148 → (0.4236)/(0.0648) = **6.5:1** — PASS AA (normal text).
3. **Primary button `--copper-ink` #1a1308 on `--copper` #d4a054** → L(#d4a054)=0.3978; L(#1a1308)=0.0070 → (0.4478)/(0.0570) = **7.9:1** — PASS AAA.
4. **Status colors on panels**: `--warn` #e6c36a on `--bg-elev` = 9.5:1; `--danger` #f0a0a0 on `--bg-elev` = 7.9:1; `--ok` #8fd0a4 on `--bg` = 10.2:1 — all PASS.
5. **Focus ring `--focus` #f2d19a vs `--bg`** = 12.5:1 (non-text ≥3:1 PASS; ring sits on page bg via 2px offset, not on the copper button).
6. **FAIL: `--line` #2c3640 on `--bg-elev` #1b2129** = (0.0854)/(0.0648) = **1.3:1** (<3:1) — see F5.

## DEC-WEBINSTALL-005 statement

**No GrapheneOS verbatim copy detected.** All markup, CSS, and copy in `wizard/index.html`/`styles.css` is GuardTalkOS-original (flashcore/tokay/akita/`dev/unlocked` vocabulary, DEC-007/008/009 banners, GuardTalkOS branding). Topical overlap with the GrapheneOS WebInstall page (Chromium-family requirement, private-window storage limits, `fwupd` conflict, volume-down+power fallback) is factual domain knowledge expressed in **different wording** with GuardTalkOS-specific context — not verbatim reuse. No GrapheneOS CSS, assets, fonts, or remote resources are loaded. `NOTICE` lines 24-26 record the same claim. **DEC-WEBINSTALL-005: PASS.**

## Law 21 (Accessibility & Inclusivity) statement

WCAG 2.1 AA: **largely met** (semantics, labels, live regions, keyboard-native controls, focus visibility, contrast). Blocking gaps for full AA conformance: F5 (1.4.11 non-text contrast) and the F2 keyboard deadlock (2.1.2 No Keyboard Trap risk — Esc is an expected dialog exit that strands the flow). F1-F4 are quality/safety gaps that should be fixed before live-flash enablement.

## Verdict rationale

No HIGH findings; five MEDIUM findings concentrated in variant semantics, async state, and two concrete WCAG AA edge failures. Foundation (tokens, semantics, contrast, licensing) is sound. **CONFORMANT WITH FINDINGS.**
