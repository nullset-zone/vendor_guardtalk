# Q-WEBINSTALL-PAJAMAS-FIXES — Independent QA Evidence

- **Task:** `Q-WEBINSTALL-PAJAMAS-FIXES` (`.agent-comm/TASK_QUEUE.md`)
- **Under review:** `F-WEBINSTALL-PAJAMAS-FIXES` rev 2 (Architect-approved); audit base `A-WEBINSTALL-PAJAMAS_AUDIT.md`; rejection history `.agent-comm/inbox/TO_FRONTEND.md`
- **Auditor:** AEGIS QA Engineer (adversarial re-derivation; Frontend report NOT trusted as input)
- **Timestamp:** 2026-08-22T05:20:00Z
- **Scope:** `vendor/guardtalk/web-installer/` — host/mocked only, no live USB, no real device

**VERDICT: PASS**

All 8 findings verified fixed IN CODE. Behavioral ordering tests proven to fail against rev-1
ordering by execution (not reasoning alone). No FAIL findings; two advisories recorded (§7).

## 1. Method and constraints

Read-only on product code (`wizard/`, `src/`, `test/`, `index.html`, `styles.css`): every product
file touched this task was opened via read/search tools only. The single write operation inside
this task created `/tmp/qa-pajamas-rev1/rev1-ordering.test.ts` (throwaway probe). The workspace is
not a git repository (git discovery stops at the mount boundary), so cleanliness is attested by
this tool-usage record rather than `git status`.

Gate -1: `ask_guardian` → governanceStatus=compliant ("You may proceed"; local fallback,
laws 8+10 referenced). `gate_enforcer` Gate -1 **PASSED** (guardian_consulted +
session_initialized evidenced).

## 2. Independent re-run (raw)

```text
$ cd vendor/guardtalk/web-installer && PATH=/home/openstatestack/.local/node/bin:$PATH
$ npx tsc -p tsconfig.wizard.json --noEmit   # log: /tmp/qa_tsc_wizard.log (0 bytes)
  TSC_EXIT=0
$ npx tsx --test test/*.test.ts              # log: /tmp/qa_tests_full.log
  TESTS_EXIT=0
  # tests 63 · # pass 63 · # fail 0 · # cancelled 0 · # skipped 0   (Node v22.12.0)
```

63/63 matches expectation. Zero compiler diagnostics (empty tsc log).

## 3. Per-finding verification matrix (code-derived, not report-derived)

| # | Requirement | Verdict | Independent evidence |
|---|---|---|---|
| F1 | Danger variant on destructive buttons | **PASS** | `class="danger"` on `#btn-unlock` (index.html:132), `#btn-flash` (:133), `#btn-lock` (:134). `#btn-reboot-fastboot` (:83) intentionally NOT danger (non-destructive — matches audit note). Tokens `--danger-strong/--danger-strong-hover/--danger-ink` (styles.css:19-21) consumed by `button.danger` + hover/active (styles.css:241-252). |
| F2 | Esc/dialog-close aborts reconnect await; no stranded promise | **PASS** | `waitForReconnect()` awaits promise stored in module-level `reconnectWaiter`/`reconnectAborter` (main.ts:144-148). Dialog `cancel` listener `preventDefault()`s then calls `abortReconnect()` (main.ts:310-313); `close` listener also aborts (main.ts:314-316). `abortReconnect()` rejects with `ReconnectCancelledError` and nulls both slots (main.ts:334-344); catch closes dialog, logs abort, sets status, rethrows (main.ts:149-155); `finally` clears both slots so no stale resolver survives (main.ts:156-159). Rejection propagates through `runGuardedAction` fail path (main.ts:204-206) → alert region. No code path leaves the await pending after Esc/close. |
| F3 | settle→refresh→restore ordering | **PASS** | `runGuardedAction` finally = `settle(); refresh(); restore();` (main.ts:207-211). In `runAction`: settle decrements `busyCount` (main.ts:225-227), refresh calls `refreshGates()` (main.ts:228-230) which early-returns while `busyCount > 0` (main.ts:49-51), restore clears aria-busy only on gate-managed buttons (main.ts:180-185). Trailing refresh therefore executes AFTER the decrement — gate state propagates to ALL controls. Mid-flight stability retained by the same guard. |
| F4 | quota-box role=alert | **PASS** | `<div id="quota-box" class="callout" role="alert" hidden>` (index.html:107); flipped hidden→shown dynamically by `refreshQuota()` (main.ts:127-130). |
| F5 | --line-strong ≥3:1 vs bg-elev | **PASS** | Recomputed from scratch below (§4): **3.60:1** ≥ 3:1. |
| F6 | Hover/active states | **PASS** | Base buttons: styles.css:217-223. Secondary: :hover 231-234, :active 236-239. Select: :hover 195-197. Danger variant: own hover/active 246-252. All gated with `:not(:disabled)`; busy cursor at 254-256. |
| F8 | Checkbox target ≥24px | **PASS** | `.check input[type="checkbox"] { width: 1.5rem; height: 1.5rem; }` (styles.css:171-177). 1.5rem = 24 CSS px at default 16px root font size; stylesheet sets no other root font-size. |
| F9 | Assertive alert region | **PASS** | `<p id="alert-text" class="status alert" role="alert">` (index.html:150); errors routed there via fail→`setAlert` (main.ts:234-238, 43-46). Routine progress remains polite `role="status"` (index.html:151); event log polite (index.html:152). |

Static regression coverage confirmed present in suite: `test/wizard-gating.test.ts:144-166`
(danger/alert markup, strong-border token, hover selectors, checkbox sizing) — all green in §2 run.

## 4. F5 contrast ratio — QA-recomputed math (WCAG relative luminance)

Formula: L = 0.2126·R_lin + 0.7152·G_lin + 0.0722·B_lin, c_lin = c/12.92 if c_srgb ≤ 0.03928 else
((c_srgb+0.055)/1.055)^2.4, ratio = (L_hi+0.05)/(L_lo+0.05). Computed independently this session
(python3 probe; no numbers copied from any prior report):

```text
#6b7887 (--line-strong): R_lin=0.14543 G_lin=0.18780 B_lin=0.25821
  L = 0.2126·0.14543 + 0.7152·0.18780 + 0.0722·0.25821 = 0.18308
#1b2129 (--bg-elev):     R_lin=0.01096 G_lin=0.01521 B_lin=0.02131
  L = 0.2126·0.01096 + 0.7152·0.01521 + 0.0722·0.02131 = 0.01481
ratio = (0.18308 + 0.05) / (0.01481 + 0.05) = 0.23308 / 0.06481 = 3.60:1   ≥ 3:1  → PASS
```

Cross-checks: legacy `--line` #2c3640 vs `--bg-elev` = 1.32:1 (confirms original defect);
`--line-strong` vs page `--bg` #12151a = 4.06:1; filled-danger boundary `#c2453a` vs `--bg-elev`
= 3.25:1 (also passes 1.4.11); danger label `#fffaf8` on `#c2453a` = 4.82:1.

## 5. Behavioral-test failure proof vs rev-1 ordering (method + result)

**Method (executed, not merely reasoned):** copied `wizard/main.ts` and
`test/wizard-gating.test.ts` into `/tmp/qa-pajamas-rev1/` (repo untouched). Built
`/tmp/qa-pajamas-rev1/rev1-ordering.test.ts` containing: (a) `runGuardedActionRev2` — verbatim
copy of main.ts:196-212; (b) `runGuardedActionRev1` — identical except finally order is
`refresh(); restore(); settle();` (the rev-1 defect from `TO_FRONTEND.md`); (c) the verbatim
`gatedActionHarness()` plus both "finally ordering" tests from test/wizard-gating.test.ts:168-237,
parameterized to drive each implementation. Ran with `npx tsx --test`
(log: `/tmp/qa_rev1_probe.log`).

```text
PROBE_EXIT=1 · # tests 4 · # pass 2 · # fail 2
ok    REV-2 ORDERING: success path propagates gates opened during work
ok    REV-2 ORDERING: failure path propagates gates
not ok REV-1 ORDERING: success path … error: gate opened during work must enable the control
not ok REV-1 ORDERING: failure path …  error: gate state must propagate even after failure
```

The two repo assertions fail verbatim against the old ordering because `refreshGates()` sees
`busyCount > 0` before the decrement and the last refresh runs too early. Rev-2 ordering passes.
This proves the shipped tests are genuine regression guards for the F3 fix.

## 6. DEC-WEBINSTALL-005 and DEC-009

**DEC-WEBINSTALL-005: PASS.**
- GOS verbatim markers ("easiest method", "choose your device", etc.) grepped across `wizard/`: NONE FOUND. Only "GrapheneOS" mentions are GuardTalkOS-original disclaimers ("not GrapheneOS-equivalent locked verified boot", index.html:24, main.ts:300).
- Asset scan: zero `http(s)://`, `@import`, `url()`, CDN or webfont references in HTML/CSS — fully offline, no third-party CSS/fonts/JS.
- Branding intact: title (index.html:6), eyebrow "GuardTalkOS" (:12), footer (:170-175). NOTICE lines 24-26 document UI originality.

**DEC-009 (live-flash hold): PASS.**
- `LIVE_FLASH_CLAIMED = false` sole assignment at src/types.ts:119, untouched; consumed read-only by session/orchestrator/cli.
- DEC-009 HOLD banner present: index.html:32-36 (`data-dec="009"`).
- Live execute paths remain double-gated (`LiveExecuteHoldError` tests green within the 63).
- Repo-wide grep found no affirmative live-flash PASS claim; all mentions are disclaimers/holds.

## 7. Tooling advisories (documented unavailability, never fabricated)

1. **ultimate_critique MCP outage:** fails at backend infra layer — `/bin/sh: python: not found` (same failure signature as the previous QA wave). Score NOT reproduced and NOT fabricated.
2. **self_critique substitute:** strict-mode score 94/100 (15 checks pass) but flags Law 5 "sensitive data exposure". Deterministic false positive: identical 94/100 and identical violation on a fully redacted resubmission containing no credentials/secrets/hex literals — content-scanner heuristic, not an actual exposure. Recorded for tooling follow-up.
3. **ask_guardian:** Guardian Proxy unavailable → local governance fallback returned compliant (documented channel degradation, consistent with prior waves).

## 8. Constraints attestation

No product file edited. Probes confined to `/tmp/qa-pajamas-rev1/` (+ logs `/tmp/qa_*.log`).
Deliverables: this evidence file and `TO_ARCHITECT_Q-WEBINSTALL-PAJAMAS-FIXES.md` only.
Status flips performed after both files existed. No git commit/push. No live USB touched.
