# Lens 3 — State Machine Integrity Audit (READ-ONLY)

**Target:** GuardTalkOS web installer · `vendor/guardtalk/web-installer/`
**Date:** 2026-08-23 · **Lens:** 3 (State Machine Integrity)
**Question:** *Can flow advance without the named human action, or continue after a stop?*
**Scope audited:** `lib/install-state/**` (`machine.ts`, `steps.ts`, `stops.ts`, `gates.ts`, `index.ts`), all four route modules (`routes/install/{early-steps,late-steps,flash-runner}.ts`, `routes/update/update-route.ts`, `routes/verify-device/verify-route.ts`, `routes/recover/recover-route.ts`), shared wiring surfaces (`lib/ui/rail.ts`), plus `test/install-state.test.ts`, `test/route-*.test.ts` for behavioral confirmation.
**Binding:** PLAN.md §1 step table + route variants; DECISION_LOG D-001, D-002, D-003, D-011.
**Method:** full-file read of every in-scope module; repo-wide regex sweeps for `reduce(`/dispatch sites, direct state mutation (`currentStep =`, `stops =`, `completedSteps.add`, `oemUnlockAcked =`), timers (`setTimeout|setInterval|queueMicrotask|requestAnimationFrame|setImmediate`), promise-chain `await` sites in route wiring, and full import-graph enumeration for the D-003 trace. Every claimed escape sequence below was traced line-by-line through the reducer.

---

## Verdict

**No BLOCKER.** Within a live session, no sequence advances a step without its named action, and no sequence resumes advancement after a condition stop (hard-freeze holds; escape attempts in §4). One **HIGH** exists at the serialization boundary: `deserialize()` fabricates states that violate the route subsets and forge gate preconditions. Seven MED findings cover contract breaches, ungated failure exits, and enforcement living outside the machine. Timers, the D-003 generate-hidden invariant, the flash-gate internal re-check, back semantics, and re-acknowledgement enforcement verified clean.

---

## Findings

### HIGH

**H-1 · `deserialize()` fabricates out-of-subset states and forges gate preconditions**
`lib/install-state/machine.ts:269-272` — validates `currentStep` only as an integer, never against `stepsForRoute(route)`; `machine.ts:273-276` — accepts arbitrary numeric `completedSteps` with no subset or consistency check.
Crafted deep-link `{"route":"verify-device","currentStep":6,"completedSteps":[2,4,5]}` parses cleanly: step 6 (Flash) becomes reachable on the route whose subset is `[5,8]` (D-002), and because `flashBlockers` keys on `completedSteps.has(2)/has(4)` (`gates.ts:50-55`), the forged completions satisfy the machine-half of `canFlash` — a laundered verify-device state can pass the real gate (`gates.ts:24-31`) even though `flashBlockersOnVerifyDevice()` (`verify-route.ts:184-195`) correctly reports permanent blockage for honestly-derived states. The same forgery defeats the step-2/step-4 preconditions on any route.
*Reachability caveat:* no shipped wiring consumes `deserialize` outside tests today (`test/install-state.test.ts:248-261`, `test/route-update.test.ts:516`); the hole is in the exported public API awaiting a consumer.
**Fix:** reject in `deserialize()` any `currentStep ∉ stepsForRoute(route)` and any `completedSteps ⊄ stepsForRoute(route)` (and drop completions ≥ `currentStep`).

### MEDIUM

**M-1 · Guard-violation stops do not freeze advancement, contradicting the module's own contract**
`machine.ts:3` promises "Guard violations freeze advancement and record a StopRecord"; `HARD_STOP_REASON_IDS` (`machine.ts:73-75`) contains only the seven condition IDs, so freezes appended via `freeze()` — `OUT_OF_ORDER` (`:128`), `ROUTE_STEP_FORBIDDEN` (`:125`), `KEY_FLOW_FORBIDDEN` (`:171,:197`), `BACK_PAST_IRREVERSIBLE` (`:208`), `OEM_UNLOCK_ACK_REQUIRED` (`:137`) — record a stop but the very next correctly-named action advances (`advance():120` checks only the hard set). Behavior may be intentionally two-tier, but the code contradicts its documented contract, and `update-route.ts:88-98` builds on this: an unlock request on `/install/update` records `ROUTE_STEP_FORBIDDEN` and flow simply continues afterward.
**Fix:** align the header comment with the implemented two-tier semantics (or add the guard IDs to the freeze set if stopping was truly intended).

**M-2 · Stop-record mutation implemented outside `machine.ts` (duplicate authorities)**
Audit item 1 hit: `update-route.ts:95` `{ ...state, stops: [...state.stops, record] }` and `recover-route.ts:230-236` `appendStop()` (+ wrappers `freezeOutOfOrder`/`freezeAckRequired`, `:219-226`) replicate the reducer's internal stop-append. They currently emit machine-vocabulary records, but they are parallel implementations that can drift from `appendStop` (`machine.ts:225-228`) and bypass any future validation added there.
**Fix:** expose a single `appendStopRecord(state, reasonId, step?)` action/helper from `machine.ts` and make both routes call it.

**M-3 · Fastboot failure mid-flash leaves the machine un-stopped (no `FASTBOOT_FAIL` mapping on any live path)**
In `runUpdateFlow`, the entire destructive phase (`update-route.ts:539-547`) runs as raw device calls between machine transitions; a throwing `flash`/`erase` propagates out of the runner leaving state parked at step 5 with **no** `{type:"stop", condition:"fastboot-fail"}` recorded — PLAN.md §1 step 6 ("any fastboot FAIL ⇒ STOP") is unrealized in available code. Same shape on `/install`: `runFlashPlan` throws `FastbootError`/`FlashGateError` (`flash-runner.ts:120-121,132-134`) and no wiring translates either into a machine stop (the install page wiring layer does not exist yet in-repo). The reducer supports the stop; nothing feeds it.
**Fix:** wrap the flash phase in each runner/wiring so `FastbootError` dispatches `{type:"stop", step, condition:"fastboot-fail"}` before surfacing the error.

**M-4 · `runUpdateFlow` auto-fires `oem-unlock-acked` — programmatic substitution for a human acknowledgement**
`update-route.ts:526` dispatches `{type:"oem-unlock-acked"}` unconditionally inside the scripted flow, while the update page's own step-5 consent control is a different checkbox (`data-ack="state-unchanged"`, `update-route.ts:251-254`) that the runner never consults. The machine's step-5 ack gate (`machine.ts:136-138`) is thus satisfiable with no human action whenever this runner is the dispatch source. Test-harness-only today (no production caller), but it is the exact "advance without the named human action" shape the lens hunts.
**Fix:** take the ack as an input precondition of `runUpdateFlow` (or dispatch it only from the checkbox handler), never inline.

**M-5 · Machine enforces order, not truth — steps 3/8 content checks live entirely outside the reducer**
`boot-fingerprint-typed` carries `fingerprint` (`machine.ts:44`) but `advance()` never compares it; `InstallState` does not even hold the enrolled fingerprint. The real comparisons are caller-side pure functions: `step3Decide`/`retypeMatches` (`early-steps.ts:575-606`) and `fingerprintsMatch` (`late-steps.ts:319-322`) / `compareHex` in `runUpdateFlow` (`update-route.ts:550-557`). Same for `device-matched`'s `product` payload. Wiring that skips the comparator advances the machine on false facts — at step 8 that means reaching "Keep the key" without the binding mismatch check (PLAN.md §1 step 8).
**Fix (one sentence):** thread the enrolled fingerprint (and target product) into `InstallState` and validate the action payloads inside `advance()` so the reducer, not the caller, owns the stop decision.

**M-6 · Recover typed-ack phrase has no comparator — the gate is a caller-supplied boolean**
`RECOVERY_ACK_PHRASE` is exported (`recover-route.ts:29`) and `renderRecoverPage({ackAcknowledged:true})` renders the enabled unlock button (`:85-99`, `:187-214`), but nothing in the repo implements the exact-match comparison; `wireRecoverPage` forwards raw input (`:299-304`) and `ACK_INPUT_MIN_LENGTH = phrase.length - 4` (`:56`) deliberately loosens the HTML hint. Enforcement rests entirely on future wiring discipline; D-001's "typed acknowledgement" is currently decorative at the code level.
**Fix:** export `recoveryAckMatches(typed: string): boolean` (exact match, trimmed) alongside the phrase and have the page derive `ackAcknowledged` only from it.

**M-7 · Verify-device machine accepts a data-wipe acknowledgement and will cross 5→8 on a route that never unlocks**
`ackOemUnlock` rejects only `route === "recover"` (`machine.ts:178-180`), so on `verify-device` at step 5 the machine happily records `oemUnlockAcked`, and the step-5 advance gate (`machine.ts:136-138`) then *requires* that wipe ack to move 5→8 — on the read-only route of D-002 whose own docs say it "never fabricates machine events" (`verify-route.ts:17-19`; the shipped page renders both capabilities statically and wires no machine advances, `verify-route.ts:330-378`). Latent trap: any future wiring that follows the generic step model must fake a wipe ack to progress.
**Fix:** gate `oem-unlock-acked`/the step-5 advance requirement to routes where unlock is actually offered (`install`, `update`).

### LOW

**L-1 · `back()` is not gated by `isHardStopped` — navigation across a hard stop is possible**
`machine.ts:202-215` checks route/irreversibility/target-membership but not the freeze, so after a condition stop (e.g. step 8) `back` still moves `currentStep` to 7; all advancement remains frozen (`:120`), so this is reposition-only, but "once stop fires, no action except reset advances" is not literally true for `back`.
**Fix:** return the state unchanged in `back()` when `isHardStopped(state)`.

**L-2 · Freeze is not durable across serialization**
`serialize()` omits `stops` and `oemUnlockAcked` (`machine.ts:241-252`) and `deserialize()` reconstructs with `stops: []`, `oemUnlockAcked: false` (`:289-296`). A deep-link round-trip launders a hard stop (session resumes unfrozen at the same step, prior completions intact). Related to but distinct from H-1 (which needs no stop to exist). Mitigated: re-passing any check still requires the caller-side comparators and the flash gate.
**Fix:** include a stop summary in the serialized payload and restore the frozen state (or refuse to serialize a hard-stopped session).

**L-3 · Hygiene: unbounded stop growth, zero-byte pkmd placeholder, trust-me gate inputs**
Repeated violations append without bound (`appendStop`, `machine.ts:225-228`; visible in `update-route.ts:104-106` scanning all stops). `wireRecoverPage` hands `new Uint8Array(0)` to `onFlashPkmdRequested` (`recover-route.ts:315-320`) — an enrolment flash of empty bytes if wired as-is. `runUpdateFlow` passes hardcoded `{hashesMatch:true,signatureValid:true}`/`{signedWithUserKey:true}` into `canFlash` (`update-route.ts:529-534`), making the gate's caller-input half trust-based (its machine-completion half remains honest).
**Fix:** dedupe consecutive identical stops; supply real pkmd bytes through the handler contract; derive gate inputs from computed verification results.

---

## Audit item detail

### 1. All transitions via reducer actions — direct mutation hunt
Swept `routes/**`, `lib/**` for `currentStep =`, `stops =`, `completedSteps.add`, `oemUnlockAcked =`, object-literal `InstallState` construction. Result: `currentStep`/`completedSteps`/`keyFlow`/`oemUnlockAcked` are mutated **nowhere** outside `machine.ts`. Exactly two out-of-machine stop-record construction sites exist: `update-route.ts:88-98` and `recover-route.ts:230-236` (**M-2**). `rail.ts` only reads state and dispatches `{type:"back"}` (`rail.ts:223-241`); `lib/cli-export/generator.ts:411` uses an unrelated local variable. Runners drive everything through `reduce`/`reduceUpdate` (`update-route.ts:490-564`). *Not clean — see M-2.*

### 2. NO timers advance state — **verified clean**
Regex sweep `setTimeout|setInterval|queueMicrotask|requestAnimationFrame|setImmediate` over the installer tree: zero hits in `routes/**` and `lib/install-state/**`. The only timers are microtask-style yields inside device transports (`lib/fastboot/simulated-device.ts:120`, `lib/fastboot/usb.ts:203`) and the out-of-scope legacy `wizard/adb-*` modules (which import nothing from `lib/install-state`). All `await` sites in route wiring are user-event-triggered crypto/device operations; no `.then(() => reduce(...))` chain exists. `lib/claims/lint-claims.ts:49-50` additionally bans annotated timer-advance patterns. Caveat carried as **M-4**: the scripted runner substitutes one acknowledgement programmatically — a promise-chained action without a human event.

### 3. Back semantics — **verified clean**
Every `backTarget` in `steps.ts:44-125` points at the immediate predecessor and `back()` (`machine.ts:202-215`) validates the target against the route subset, so update can never back onto step 7 or 0 (`[1,2,3,4,5,6,8,9]`) and verify-device can never back off `[5,8]`. Step 5 is `irreversibleAfterAck: true` (`steps.ts:91`): backing *from* 5 freezes `BACK_PAST_IRREVERSIBLE` (`machine.ts:207-209`) and the rail hides the control (`rail.ts:101-109`). Critically, the ack itself cannot survive: leaving step 5 in any forward direction resets `oemUnlockAcked` to `false` (`machine.ts:153`), and `deserialize` restores it `false` (`:294`) — so 5→6→back→5 forces re-acknowledgement of the data-wipe warning before `device-matched` can ever succeed again. No path preserves a stale destructive ack.

### 4. Hard-freeze escape attempts — **none succeeded in-session**
`advance()` (`machine.ts:120-122`), `chooseKeyFlow` (`:166-168`), and `ackOemUnlock` (`:181-183`) all check `isHardStopped` before acting, and the check precedes step lookup — so a stop recorded at any step freezes all three action families on **every** step (confirmed by tests: post-`fastboot-fail` advance no-op `test/install-state.test.ts:191-196`; post-mismatch `keep-key-acknowledged` no-op `test/route-install-late.test.ts:511,548`). Constructed escapes:
- *Navigate-past-the-stop*: hard stop at 8 → `back` → 7 (works, **L-1**) → any advance no-ops. Dead end.
- *Reset*: by-design full restart; `completedSteps` cleared, so flash gates force redo of steps 2/4. Safe.
- *Serialize-laundry*: round-trip drops `stops` (**L-2**) and, worse, `deserialize` forges subset/completions (**H-1**). This is the only mechanism that revives a frozen/fabricated state, and it requires a serialized payload — no in-session route.
Conclusion: **no BLOCKER**; boundary findings H-1/L-2.

### 5. Route subsets — clean under reducer dynamics; H-1 via deserializer; D-003 graph clean
Pure-reducer reachability: `advance()` walks `routeSteps` (`machine.ts:139-147`) so install terminates at 9, update can never synthesize step 7, verify-device walks 5→8 only; `chooseKeyFlow` rejects flow 1 on update (`:169-172`, soft stop; test `test/install-state.test.ts:217`) and `checkKeyFlow` re-validates at advance time (`:130-135,:190-200`). No step outside a subset is reachable through `reduce`. **Exception:** `deserialize` (H-1). **D-003 trace:** full import enumeration of `routes/update/update-route.ts` (lines 13-36): imports are csp, `install-state/{gates,machine,steps,stops}`, fastboot client/simulator, keys/**fingerprint**, verify/*, ui/* — **no** `early-steps.js`, **no** `lib/keys/generate.js`, no dynamic `import()`; transitive closure via `recover→verify-route` adds nothing generate-bearing. The update page renders only flows 2/3 with an explicit no-card slot for flow 1 (`update-route.ts:172-224`, esp. comment `:205-212`). `early-steps.ts` (which does import `generate.js` at `:41`) is reachable only from `/install`'s graph and tests. **Verified clean** (static import-graph level; bundle-level proof remains the PLAN §4 `generate-hidden` CI lint).

### 6. Flash gates — **verified clean**
`runFlashPlan` re-checks `canFlash` internally before constructing the client or issuing any command (`flash-runner.ts:130-134`, throws `FlashGateError` pre-write; defence-in-depth test `test/route-install-late.test.ts:212-215,554+` asserts zero commands on unsatisfied gates). `flashBlockers` independently cross-checks machine completions 2/4 (`gates.ts:50-55`), so caller-supplied verification booleans alone cannot open the gate. `flashBlockersOnVerifyDevice()` (`verify-route.ts:184-195`) always returns non-empty (unverifiable release + `""` vs `"alpha"` product mismatch + unsigned vbmeta + missing completions + route-policy line). Residual nit folded into L-3 (trust-me inputs in `runUpdateFlow`).

### 7. Recover route — warnings/ordering verified; ack comparator missing (M-6)
Loss statement renders before anything actionable (`recover-route.ts:74-83`, placed ahead of the ack section in `renderRecoverPage:201-208`); the typed-ack section precedes the unlock phase, whose wipe warning (`WIPE_WARNING_TEXT`, `:31-32`) renders *inside* the unlock section before the button, which is `disabled` with "Complete the typed acknowledgement above first" until `ackAcknowledged` (`:85-99`). Re-enrol and relock each carry their verbatim wipe warnings ahead of their buttons (`:39-40,:118-127,:140-149`). Post-wipe session handling is documented on `recoverUnlock` (`:259-267`: USB link drops mid-unlock; caller reopens transport) and exercised across two clients in `test/route-verify-recover.test.ts:361-373`. Gap: the phrase comparison itself does not exist in code (M-6), and the machine is intentionally bypassed on this route (D-001 custom phases; any `advance` action lands a soft `OUT_OF_ORDER` via `machine.ts:117-119`).

---

## Severity counts

| Severity | Count | IDs |
|---|---|---|
| BLOCKER | 0 | — |
| HIGH | 1 | H-1 |
| MEDIUM | 7 | M-1…M-7 |
| LOW | 3 | L-1…L-3 |

**Answer to the lens question:** within a running session, flow cannot advance without the named human action, and cannot resume after a condition stop — the freeze holds against every constructed escape. The exceptions are all at the edges: a deserializer that invents states (H-1), a scripted runner that speaks for the human once (M-4), and enforcement of *what was typed/compared* delegated to callers the machine must trust (M-5, M-6).
