# Lens 2 — Honesty of Claims & Labelling (adversarial audit)

GuardTalkOS WebInstaller · READ-ONLY audit · 2026-08-23 · no file edited except this report.

**Scope.** Every user-visible string emitted by `routes/install/**`, `routes/update/**`,
`routes/verify-device/**`, `routes/recover/**`, `wizard/**` (including compiled
`dist/wizard/**` and `dist/src/**` bundles that ship to the browser), `lib/ui/**`,
`lib/claims/**`, plus string-producing modules whose output reaches a screen or console
(`lib/cli-export/generator.ts`, `lib/fastboot/*` error/log framing, `src/errors.js`).

**Binding refs.** PLAN.md §5 copy contract · DECISION_LOG D-004, D-008, D-009, D-011 ·
QUESTIONS_FOR_HUMAN Q-01…Q-14 · status.json.

**Method.** Independent regex sweeps (pattern inventory in §1) over source **and** compiled
bundles; full manual read of every markup emitter; constant tracing for numbers/algorithm
names. Deliberately **not** a re-run of `lib/claims/lint-claims.ts` — the linter's own blind
spots are reported as finding F2.

---

## 1. Forbidden-phrase sweep — independent of the linter

Swept case-insensitively over `routes/`, `lib/`, `wizard/`, `src/`, `channels/`, `*.html`,
`*.css`, `dist/**` (node_modules excluded):

> automatic update · over-the-air · OTA · we'll push · remote update · auto-update ·
> secure · safe/ly · protected · protection · install now · one-click · easy/easily ·
> just works · hassle-free · effortless · automatic(ally) · hurry · countdown · act now ·
> limited time · congratulations · success!

**Result: zero hits in any shipped surface.** All hits are non-copy: the linter's own pattern
tables (`lib/claims/lint-claims.ts`), its test fixtures (`test/claims.test.ts` — fixtures are
never imported by routes or bundles; `dist/` greps clean), governance documents
(PLAN / DECISION_LOG / QUESTIONS / PHASE4-LENSES), and CSS keywords
(`margin-inline: auto`, `overflow-x: auto`), which are style rules, not words.

Manual read of every emitter (the "out-think the linter" pass) found one dishonesty the
pattern sweep cannot express:

**[F1] MED — update route asserts an unverified device state as fact.**
`routes/update/update-route.ts:249-250` renders, before any pairing or `getvar` readback:

> "The bootloader has stayed open since the first install. An update flashes through it as it stands — the lock state is read, never changed, and no data is wiped."

"The bootloader has stayed open since the first install" is asserted unconditionally; a user
who relocked after first install gets a false sentence (the later read contradicts it, and the
flow then fails at flash with FASTBOOT_FAIL — a workaround, not honesty at claim time).
(The adjacent checkbox sentence "changes no lock state and wipes no data" is accurate about
installer behaviour and is not part of the offence.)
*Fix:* render the sentence only when the just-read lock state is `unlocked`, otherwise state
the truth and stop, or soften to "should still be open since the first install".

**[F2] LOW — linter blind spots (for future copy, no live offender today).**
`lib/claims/lint-claims.ts`:

- `MECHANISM_ALLOWLIST` includes `/signed/i` (`lint-claims.ts:36`), which substring-matches
  "**un**signed": a line like "Unsigned images stay protected" passes the security-word rule
  while negating its own mechanism. Fix: use a negative lookbehind (`(?<!un)\bsigned\b`) or
  drop the fragment rule.
- `SECURITY_ADJ_PATTERNS` (`:28`) omit `/\bsecurity\b/i` even though PLAN §4 names the
  secure/safe/protected family; "Security built in." would pass today. Fix: add the token.
- PLAN §4 forbids bare "Automatic", but the linter only catches "automatic update" (`:19`).
  Fix: add `/\bautomatic(ally)?\b/i` as its own rule family.
- Mechanism matching is line-local (per-line loop `:68-95`) while route copy legitimately
  spans multiple template-literal lines (e.g. `Hardening(...)` calls in `early-steps.ts`);
  an adjective and its mechanism on different lines evade the rule. Fix: lint joined text
  blocks, not lines.

## 2. D-011 honesty — live-flash claim & simulation labelling

**VERIFIED CLEAN.**

- `LIVE_FLASH_CLAIMED` stays `false` end-to-end: `src/types.ts:119`
  `export const LIVE_FLASH_CLAIMED = false;` → compiled `dist/src/types.js:11` identical →
  consumed only by `wizard/session.ts:149-151` and surfaced as the truthful log line
  "GuardTalkOS installer ready. LIVE_FLASH_CLAIMED is false." (`wizard/main.ts:380`);
  `status.json:20` `"liveFlashClaimed": false`. **No string in any surface asserts a flash
  occurred.**
- SIMULATION banner is structurally embedded at the top of **every** late-step renderer,
  before any step content: `routes/install/late-steps.ts:159` (step 5), `:226` (step 6),
  `:286` (step 7), `:335` (step 8), `:389` (step 9) all open with `simBannerHtml(...)` —
  regression-pinned by `test/route-install-late.test.ts:615-633`.
- The banner text itself does not overclaim (`late-steps.ts:58`):
  > "This session runs against a simulated device. No hardware is touched; results are reproducible and are not evidence of a real flash."
- Update/verify/recover equivalents present: header chip "SIMULATED DEVICE — NOTHING TOUCHES
  HARDWARE" (`update-route.ts:366-368,381`); chips "SIMULATED DEVICE"
  (`verify-route.ts:295-297,339`; `recover-route.ts:164-166,197`).
- Wizard legacy: static DEC-009 HOLD banner (`wizard/index.html:32-36`), runtime disclosure
  "Dry-run transport attached. Not a live flash." (`wizard/main.ts:250`), and gates that
  require `dryRun` for execute/lock (`wizard/gating.ts:39,44`; `session.ts:200-204`).

**[F3] LOW — wizard completion strings drop the dry-run qualifier.**
`wizard/main.ts:292-293` emit "Flashcore plan complete." / "Flash complete. Lock is now
available." after `executePlan`. In the only shippable mode (dry-run) neither restates that
nothing was written; a skimming reader can take "Flash complete" as a hardware result.
Mitigations exist (HOLD banner, attach-time warning), hence LOW.
*Fix:* "Dry-run plan complete — nothing was written."

## 3. Alpha posture on every route surface

**VERIFIED CLEAN on all four alpha-era routes** (pill text exactly `◢ offline · your key ·
alpha` per `lib/ui/posture.ts:18-20`, release word pinned to "alpha"):

- `/install`: pill in chrome header (`early-steps.ts:126-135`) plus caution chip
  "ALPHA — READ FIRST" (`:231`).
- `/install/update`: pill in header (`update-route.ts:370-384`).
- `/install/verify-device`: pill in header (`verify-route.ts:282-288,337`).
- `/install/recover`: pill in header (`recover-route.ts:151-157,195`).

**[F4] LOW — legacy wizard has no posture surface.** `wizard/index.html` discloses
dev/unlocked + HOLD (`:21-36`) but carries no alpha/posture pill; PLAN §5's posture contract
postdates it. Acceptable as legacy scope. *Fix:* add the pill or an explicit "legacy
installer" notice.

## 4. Threat-model links (every stated limit → `/threat-model`)

**[F5] MED — `/install` steps 5–9 state protective claims with no `/threat-model` link
anywhere in the file.** `late-steps.ts` imports (`:12-16`) pull no claims component, and the
string `/threat-model` appears nowhere in it (grep over `routes/` matches only
`update-route.ts:335,408` plus a comment in `early-steps.ts`). Strongest case, the step-7
boot-state explainer (`late-steps.ts:306-310`):

> "the phone itself now proves, every single boot, that it is running exactly what you signed and nothing else."

— an absolute proof claim whose standing caveat (firmware/baseband beneath AVB, compromised
signing machine, coercion) is stated only three steps earlier at step 0 and is unreachable
from here; the step-9 custody recap (`:392-405`) is a second unlinked site.
*Fix:* append a ProtectionLimit-style "(Read the threat model)" link to the boot-state
explainer and the step-9 recap.

**[F6] MED — PLAN §5's fourth named limit, "Gateway network defence," is never
stated-and-linked on any surface.** PLAN.md:128-129 requires each of {firmware/baseband
beneath AVB, compromised signing machine, coercion, Gateway network defence} linked to
`/threat-model`. The Gateway handoff (`late-steps.ts:357-365`) links
`guardtalk.io/system/gateway` and the docs, but no route tells the user the Gateway is a
network-defence boundary with its own limits, nor links the threat model beside it.
*Fix:* one ProtectionLimit sentence + `/threat-model` link inside the step-8 Gateway handoff
block.

Clean elsewhere: `/install` step 0 states the other three named limits, each with a working
`/threat-model` link (`early-steps.ts:213-226` via the `ProtectionLimit` default,
`components.ts:52-65`); `/install/update` carries two links (`update-route.ts:335` step-9
limit, `:408` footer). `verify-device`/`recover` state route-capability facts ("This route
never writes to the device", "Recovery cannot save it") rather than threat-model-class
claims — no link owed, none fabricated. The unbuilt `/threat-model` destination is the
flagged-acceptable case per the lens rubric.

## 5. Success theatrics / urgency patterns

**VERIFIED CLEAN.** The closing screen is calm prose (`keepKeyStepHtml`,
`late-steps.ts:387-412`): headline "Keep the key.", custody recap, the contractual closing
sentence "GuardTalk cannot update this phone. Only you can." (`:24`), and a plain
acknowledgement button — no confetti, no auto-advance wording, no countdown/hurry/
exclamation stacking (swept `!`, "hurry", "act now", "limited time", "congratulations",
"success!" across all surfaces including wizard and `dist/`; zero hits in copy). Every
advance in copy is an explicit user action ("Continue to verification", "Record this
fingerprint", "Compare").

## 6. `// confirm` placeholders vs unresolved Q-items

**VERIFIED CLEAN — no placeholder has silently become an asserted fact** (the HIGH trigger
did not fire). Enumerated against QUESTIONS_FOR_HUMAN:

- **Q-04**: "// confirm release-key fingerprint (Q-04)" still ships as a mono placeholder
  (`early-steps.ts:59,278`; `cli-export/generator.ts:59,129,194`); the verifier itself stays
  placeholder-gated (`detached-sig.ts:3-5`).
- **Q-05**: "// confirm onion address (Q-05)" at `early-steps.ts:57,277`;
  `update-route.ts:138`; `generator.ts:58,124`; `status.json:9-10` keeps `address: null`.
- **Q-06**: rango renders literally as "// confirm device name (Q-06)"
  (`early-steps.ts:61,74`).
- **Q-07**: "// confirm partition layout (Q-07)" rendered on the stop path
  (`early-steps.ts:63,867`) and pre-stated on update step 4 (`update-route.ts:235-237`).
- **Q-08**: `SIDELOAD_NOTE` verbatim on update step 5 (`update-route.ts:47-49,255`).
- **Q-12**: LineageNote renders a visible "// confirm with counsel" marker
  (`components.ts:72-83`).
- **Q-14**: akita correctly fenced as experimental on the new routes
  (`early-steps.ts:152-153,169`).

**[F7] LOW — a comment promises UI labelling the UI does not deliver.**
`lib/keys/export-enc.ts:4-6` says the PBKDF2-SHA256 ≥600k fallback "is labelled as such in
the UI", but no route emits the KDF name or iteration count (grep: PBKDF2 occurs only in lib
internals and the armored header, which does self-describe "KDF: PBKDF2-SHA256 /
Iterations: 600000"). The engineering side is honest — `ITERATIONS_MIN = 600_000`, clamped
at `:75` and enforced at parse time `:168-170`. Drift is comment-vs-UI only.
*Fix:* label the flow-1 backup panel with KDF + iterations, or strike the "labelled as
such" clause.

**[F8] LOW — legacy wizard offers akita unmarked while Q-14 is unresolved elsewhere.**
`wizard/devices.ts:9-12` advertises `{ id: "akita", label: "Pixel 8a (akita)" }` as an equal
picker option, whereas the new installer displays "akita (Pixel 8a) stays behind an explicit
experimental flag pending confirmation — it is not offered by this installer today"
(`early-steps.ts:152-153`) and `status.json:24` lists it under `experimentalTargets`.
Each surface is internally consistent; the cross-surface posture differs.
*Fix:* mark the wizard's akita option "experimental — pending confirmation".

## 7. Numbers, units, algorithm names — spot-checks against source constants

**VERIFIED CLEAN — six spot-checks, all match implementation constants:**

1. **Signing algorithm.** UI renders `STEP4_ALGORITHM = "SHA256_RSA4096"`
   (`early-steps.ts:738,852`) ≡ parser enum `AlgorithmType.SHA256_RSA4096 = 2`
   (`lib/avb/parser.ts:26`) ≡ signer enforcement (`lib/avb/signer.ts:68,117,296`) ≡ CLI
   flag `--algorithm SHA256_RSA4096` (`cli-export/generator.ts:55,287`) ≡ avbtool spelling.
2. **Key size.** Copy "RSA-4096" (`early-steps.ts:474`; `recover-route.ts:109`; CLI aborts
   unless "4096 bit" — `generator.ts:225,259`) ≡ `KEY_ALGORITHM.modulusLength: 4096`
   (`lib/keys/generate.ts:9`).
3. **KDF iteration floor.** Claimed ≥600k (PLAN §3, Q-09) ≡ `ITERATIONS_MIN = 600_000`,
   clamped on encrypt and rejected below-policy on decrypt (`export-enc.ts:25,75,168-170`);
   the armor header prints the actual count.
4. **pkmd byte count.** "1032 bytes" claims (`generator.ts:239`) ≡ `encodePkmd` layout
   `8 + 512×2 = 1032` (`lib/avb/pkmd.ts:55`) ≡ channel fixture `avb.size: 1032`
   (`channels/tokay/manifest.json:25,32`).
5. **Fingerprint definition.** UI label "Key fingerprint (SHA-256 over your public key
   material)" (`early-steps.ts:542`) ≡ `fingerprintFromJwk = sha256Hex(encodePkmd(jwk))`
   (`lib/keys/fingerprint.ts:10-15`) — the AVB encoding of the public half only;
   display-rule compliant, nothing private derivable.
6. **Byte units.** Progress label renders exact integers with an explicit "bytes" unit and
   no rounding (`lib/ui/progress.ts:17-20`); quota copy derives from real channel sizes with
   a stated 256 MiB slack (`wizard/quota.ts:3,73-88`) — no invented totals anywhere.

Flash-order copy ≡ code: `late-steps.ts:230` order note ≡ `FIRMWARE_ORDER`/`OS_ORDER`
(`flash-runner.ts:23-26`) with vbmeta last; update plan rows (`update-route.ts:286-292`) ≡
`runUpdateFlow` sequence (`:539-547`); the CLI mirror annotates every command with the
browser step it duplicates (`generator.ts:330-367`).

---

## Findings index

| ID | Severity | Location | Violating string (verbatim) | One-sentence fix |
|----|----------|----------|-----------------------------|------------------|
| F1 | **MED** | `routes/update/update-route.ts:249-250` | "The bootloader has stayed open since the first install." | Render the sentence only when the just-read lock state is unlocked (else state the truth and stop), or soften to "should still be open". |
| F5 | **MED** | `routes/install/late-steps.ts:306-310` (whole file lacks `/threat-model`) | "…the phone itself now proves, every single boot, that it is running exactly what you signed and nothing else." | Append a ProtectionLimit-style "(Read the threat model)" link to the boot-state explainer and the step-9 custody recap. |
| F6 | **MED** | `routes/install/late-steps.ts:357-365` vs `PLAN.md:128-129` | "<h2>Next: the Gateway.</h2>" (service links only; the network-defence limit is never stated or linked) | Add one ProtectionLimit sentence naming Gateway network defence with a `/threat-model` link inside the handoff block. |
| F2 | LOW | `lib/claims/lint-claims.ts:19,28,36,68-95` | `MECHANISM_ALLOWLIST` fragment `/signed/i` (matches "u**nsigned**"); `/\bsecurity\b/i` and bare-Automatic rules absent; line-local matching | Anchor `/signed/` behind a negative lookbehind, add the `security`/`automatic` tokens, and lint joined text blocks. |
| F3 | LOW | `wizard/main.ts:292-293` | "Flash complete. Lock is now available." | Reword to "Dry-run plan complete — nothing was written." |
| F4 | LOW | `wizard/index.html:21-36` | (absence of any alpha/posture pill on the legacy wizard) | Add the posture pill or an explicit legacy-installer notice. |
| F7 | LOW | `lib/keys/export-enc.ts:4-6` | "PBKDF2-SHA256 with >=600_000 iterations ships instead and is labelled as such in the UI." | Label the flow-1 backup panel with the KDF name and iteration count, or strike the "labelled as such" clause. |
| F8 | LOW | `wizard/devices.ts:9-12` | `{ id: "akita", label: "Pixel 8a (akita)" }` (offered as an equal, unmarked option) | Mark the wizard's akita option "experimental — pending confirmation (Q-14)". |

**Severity counts: BLOCKER 0 · HIGH 0 · MED 3 · LOW 5 — total 8.**

## Verdict

Every checked binding holds today: no OTA/push/superlative/mechanism-free security language
ships on any surface (source or bundle); `LIVE_FLASH_CLAIMED` is false everywhere and no
string claims a flash that did not occur; the SIMULATION banner is structurally embedded in
all late-step renders with honest banner text and chip equivalents on the other routes; the
alpha posture pill appears on all four new routes; the closing screen is calm; all Q-item
placeholders survive verbatim; and every spot-checked number, unit, and algorithm name
matches its implementation constant. The three MED findings are gaps of omission or
premature assertion — an unconditioned device-state sentence on `/install/update` (F1),
missing `/threat-model` links on `/install` steps 5–9 (F5), and the never-stated
Gateway-limit disclosure (F6) — all one-line copy fixes with no logic change. The linter
itself needs the four hardening tweaks of F2 so the next wave of copy cannot slip past it.
