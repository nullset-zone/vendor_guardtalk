# Phase 4 — Five Adversarial Lenses (packet)

> Owner: Architect · Dispatched when Phase 3 acceptance passes.
> Each lens is an INDEPENDENT read-only audit subagent. No lens may fix code.
> Every finding MUST carry `file:line` evidence and a severity:
> `BLOCKER` (ships-broken or dishonest) / `HIGH` (contract violation) /
> `MED` (gap with workaround) / `LOW` (polish). Proposed fix = one sentence.
> Reports: `docs/lens-1-custody.md` … `docs/lens-5-delivery.md`.
> Architect cross-verifies every BLOCKER against the cited lines before Phase 5 dispatch.
> Binding refs: PLAN.md §1–§5, DECISION_LOG D-001…D-013, QUESTIONS_FOR_HUMAN Q-01…Q-14.
> Standing directives: D-008 (`ultimate_critique` skipped), D-011 (sim-only CI, live flash
> capability present but never claimed).

---

## Lens 1 — Custody (key material egress)

Question: *can any private key byte, passphrase, or derived secret leave the tab?*

- Trace ALL sinks across `routes/**` and `lib/**`: `fetch`/`XHR`/`WebSocket`, URL
  construction/query strings, `document.cookie`, `localStorage`/`sessionStorage`,
  `console.*`, DOM attributes/text content, thrown error messages.
- Designated display path ONLY: fingerprints/hashes (public half), mono, selectable.
- Zeroise: buffers filled(0) at step completion + `pagehide`; verify calls actually
  reachable (not dead code).
- Opt-in encrypted persistence (IndexedDB) must be OFF by default; verify default.
- Non-extractable handles: `extractable: false` on generate/import paths.
- GuardTalk-anchor impossibility (PLAN §2.5): no code path accepts a release-signed
  vbmeta as boot anchor; step 6 flashes only the USER-signed image from step 4.

## Lens 2 — Honesty (claims & labelling)

Question: *does every word on every surface stay true?*

- Claim lint sweep of ALL emitted strings (routes + wizard): forbidden phrases —
  automatic update, OTA, push, secure/safe/protected without mechanism, Install now,
  Easy, Automatic, one-click.
- `LIVE_FLASH_CLAIMED` remains `false`; no string claims a flash that did not occur;
  SIMULATION banner present wherever SimulatedDevice drives output (D-011).
- Alpha posture visible on every route (posture pill / state flags).
- Every stated limit links `/threat-model` per PLAN §5 (links may be placeholders if
  route not built — flag as MED, not fabrication).
- No success theatrics: calm closing, no confetti/auto-advance copy.
- `// confirm` placeholders still marked where Q-01..Q-14 unresolved — none silently
  resolved into asserted fact.

## Lens 3 — State machine (flow integrity)

Question: *can flow advance without the named human action, or continue after a stop?*

- All transitions pass through reducer actions; grep for direct step mutation outside
  `machine.ts`.
- No timers/intervals/promises advance steps (PLAN §3: "NO timers advance state").
- Back semantics: allowed targets per `steps.ts backTarget`; destructive acks NOT undone
  by back (re-acknowledgement required).
- Tamper matrix re-run independently (6 flip cases ⇒ correct step + verbatim reason):
  package / SHA256SUMS / .sig / vbmeta / product string / boot-screen fingerprint.
- Hard-freeze: once STOP fires, no action except restart/recover advances state.
- Route subsets: update = [1,2,3(flows 2/3 only),4,5(no unlock),6,8,9]; verify-device =
  [5(read),8]; recover = honest wipe path. Any step outside subset reachable = HIGH.
- `generate` reachability on `/install/update`: import graph + emitted bundle scan (D-003).

## Lens 4 — Byte exactness (AVB + fastboot protocol)

Question: *would the bytes produced/commands issued be exactly right on real silicon?*

- Signer recipe vs Reader-B digest §B and `external/avb/avbtool.py`: digest input,
  PKCS#1 v1.5 padding bytes, DER prefix, block assembly order, length fields.
- Parity tests genuinely run avbtool (not skipped/skipped-by-env); fixtures from
  `channels/*/vbmeta.img` + `avb_pkmd.bin`.
- pkmd encode: `!II(numBits, n0inv)` layout, 1032B, rr = n² mod N.
- Fastboot: command framing, response prefixes (OKAY/FAIL/DATA/INFO), sparse chunking
  vs `max-download-size`, flash ORDER per PLAN §1.6, FAIL ⇒ immediate abort before any
  further partition.
- Reboot-to-bootloader disconnect tolerance (ADB path): expected-disconnect classifier
  cannot swallow real errors.
- Progress accounting: cumulative monotonic per partition; payload lines in transcript.

## Lens 5 — Delivery (build, CSP, a11y, static export)

Question: *does the site build clean, load offline, and meet WCAG AA?*

- `tsc -p tsconfig.lib.json --noEmit` zero errors; full test suite green from clean run.
- CSP: every `page.html` meta AND every emitted-string meta equals D-006 exactly; zero
  inline handlers/styles/scripts anywhere in emitted markup.
- Static export story: routes resolvable as files (`/install/index.html` style or
  documented serving recipe); relative asset paths work under a plain static server;
  no bundler required.
- `status.json` exists with installer/key-custody alpha + PRE_LAUNCH flags per PLAN §0.
- A11y: skip link, keyboard-operable step rail, focus visibility, chips not colour-only
  (each chip carries its word), mono values selectable/copyable, labels on inputs,
  lang attribute, noscript fallback.
- Wizard legacy route unaffected by new route additions (no shared-state regressions).

---

## Cross-verification protocol

1. Lenses run in PARALLEL; disjoint report files; no code edits.
2. Architect re-reads every cited `file:line` for BLOCKER findings; rejects any finding
   whose evidence does not reproduce.
3. Deduplicated, confirmed findings become the Phase-5 fix queue (one engineer task per
   owning scope; QA pair each).
4. LOW/MED items triage: fix now if trivial and in-scope; else record in
   QUESTIONS_FOR_HUMAN.md / PROGRESS.md known-issues.
