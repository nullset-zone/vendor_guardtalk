# Q-WEBINSTALL-DRYRUN-ONLY Evidence

**Task:** Q-WEBINSTALL-DRYRUN-ONLY  
**QA run:** 2026-08-20T16:37:00Z–2026-08-20T16:42:19Z (independent re-run; did **not** trust T report or Architect 38/38)  
**Artifact under test (read-only):** `vendor/guardtalk/web-installer/` (`src/` + `wizard/` + `test/`)  
**Depends on:** T-WEBINSTALL-DRYRUN-ONLY APPROVED  
**Not edited:** `web-installer/src/`, `web-installer/wizard/`, both `flash-from-remote.sh`, doctrine, governance laws/gates, secrets  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**Browser E2E:** **not run** — HOLD  
**CLI / dual-slot / fastbootd parity:** **not claimed** — HOLD  
**QA status:** **REVIEW only** (never APPROVED)

## Governance

- GIP-0 VERIFIED: workflow `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q cards, PROTOCOL/ROLES, memory-bank (`activeContext.md`, `progress.md` tail, `decisions.md` DEC-001..009, `systemPatterns.md`, `projectBrief.md`), AGENTS.md.
- Prompt-injection shield: SAFE (risk 0%; 22 pattern checks; 0 threats).
- Gate -1: first `gate_enforcer` check failed (`guardian_consulted` missing). `ask_guardian` returned fallback (`Guardian Proxy not available`; `governanceStatus=compliant`; “You may proceed”). Retry Gate -1 **PASSED**.
- Packet path lock: writes only under `vendor/guardtalk/docs/qa/`, `TO_ARCHITECT.md`, both `TASK_QUEUE.md`. Memory-bank write skipped (not in packet allowlist).
- Packet is authoritative: no `src/` or `wizard/` edits; no new test files in-repo.

## Environment

| Item | Independent observation |
|------|-------------------------|
| Host | Linux, cwd `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| Node | `/home/openstatestack/.local/node/bin/node` v22.12.0 (`npm` 10.9.2 also present) |
| Tools | `tsc` / `tsx` from `vendor/guardtalk/web-installer/node_modules/.bin` |
| Command | `cd vendor/guardtalk/web-installer && tsc --noEmit && tsc -p tsconfig.wizard.json --noEmit && tsx --test test/*.test.ts` |
| `test()` count on disk | allowlist 4 + channel 5 + hash 3 + orchestrator 8 + plan 4 + sha256-portable 2 + wizard-gating 12 = **38** |
| Live device | **none** — no `adb`/`fastboot`/WebUSB flash this session |
| Browser E2E | **none** — no Chromium/Playwright run |

---

## Check matrix

| ID | Check | Expected | Actual | Verdict |
|----|-------|----------|--------|---------|
| C1 | Independent `tsc --noEmit` | exit 0 | `TSC_SRC_EXIT=0` | **PASS** |
| C2 | Independent `tsc -p tsconfig.wizard.json --noEmit` | exit 0 | `TSC_WIZARD_EXIT=0` | **PASS** |
| C3 | Independent `tsx --test test/*.test.ts` | N/N, fail 0 | `# tests 38` `# pass 38` `# fail 0` `TEST_EXIT=0` | **PASS** |
| C4 | Live `executePlan` / `lock` throw `LiveExecuteHoldError` (orchestrator) | throw; no flash/lock command | ok 18 + ok 19 + one-off: live transport → `LiveExecuteHoldError`; `isPlanComplete()===false`; no `flash` / `flashing lock` in log | **PASS** |
| C5 | Live `executePlan` / `lock` throw `LiveExecuteHoldError` (wizard) | throw; `canFlash`/`canLock` false | ok 36 + ok 37 + one-off: mode `live` → `LiveExecuteHoldError`; `canFlash===false`; `canLock===false` | **PASS** |
| C6 | Dry-run still walks firmware → avb → OS then lock | bootloader, radio, avb_custom_key, boot, vbmeta + lock | ok 17 + ok 30 + one-off: phases `["firmware","avb_custom_key","os"]`; flashes match; `reconnects >= 2`; `flashing lock` present | **PASS** |
| C7 | `canFlash` / `canLock` require `dryRun` | false when `dryRun:false` | one-off: all other flags ready + `dryRun:false` → both false; `dryRun:true` → both true | **PASS** |
| C8 | DEC-009 banner in `wizard/index.html` | `data-dec="009"` | line 31 `banner-hold` `data-dec="009"`: “DEC-009 HOLD” + “Live Flash/Lock are HOLD” + “Dry-run is the only shipped execute path” | **PASS** |
| C9 | `adaptAndroidFastboot` has `dryRun: false` | live marker | `src/transport.ts:30` `dryRun: false`; one-off `isDryRunTransport(adapted)===false`; executePlan HOLD; `flashBlob` never called | **PASS** |
| C10 | Missing `dryRun` marker treated as live (fail closed) | `isDryRunTransport` false; execute/lock HOLD | `dryRun === true` only. Missing property / `undefined` / `false` / string `"true"` all live. Orchestrator execute + lock HOLD | **PASS** |
| C11 | `LIVE_FLASH_CLAIMED === false` | constant false | `src/types.ts:118` `export const LIVE_FLASH_CLAIMED = false`; only assignment in tree (excl. node_modules/dist); ok 13/17/18; one-off same | **PASS** |
| C12 | No fastbootd / userdata wipe / `--disable-verity` added | none in src/wizard product | `rg` of `src/` + `wizard/` for `fastbootd`, `--disable-verity`, `--disable-verification`, `erase:userdata`, `erase:metadata` → **empty**. HTML line 115 warns that **unlock/lock** wipe user data (Pixel bootloader), not a flashcore userdata erase | **PASS** (note) |
| C13 | Flash scripts still `cmp` IDENTICAL | silent cmp | `FLASH_SCRIPTS_IDENTICAL`; both 1135 lines; SHA-256 `d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c` | **PASS** |
| C14 | Rango still rejected | allowlist + picker + connect | ok 2/4/9/14/27/34; one-off: `assertAllowedProduct("rango")` → `WrongProductError`; `selectDevice("rango")` → `WizardGateError`; picker ids `["tokay"]` | **PASS** |
| C15 | No secrets (`*.pem` `*.pk8` `.env`) | none in tree (excl. node_modules) | named-secret files empty; `NO_PRIVATE_KEY_OR_AWS_PATTERNS` | **PASS** |
| C16 | Dual-layer HOLD (wizard mode + transport marker) | either layer blocks live | live mode + `DryRunTransport` → wizard HOLD. `dry-run` mode + `adaptAndroidFastboot` → `canFlash===true` but orchestrator still `LiveExecuteHoldError` (`flashBlob` not called) | **PASS** |
| C17 | No `src/` or `wizard/` edits by QA | read-only | QA wrote only this evidence + queues + `TO_ARCHITECT.md`. One-off probe lived at `/tmp/q-webinstall-dryrun-only-probes.mts` (not in repo) | **PASS** |
| C18 | No live-flash PASS | honesty | none run; `LIVE_FLASH_CLAIMED===false` | **HOLD** (honesty) |
| C19 | Browser E2E | optional | not run | **HOLD** |
| C20 | CLI / dual-slot / fastbootd parity | must not claim | DEC-008 + DEC-009 banners; this card is dry-run-only HOLD, not a parity implementation | **HOLD** (not claimed) |

**Overall (host/mocked):** **PASS** with **HOLD** (no live-flash; no browser E2E; no CLI/dual-slot/fastbootd parity claim).

Architect/T “38/38” is **confirmed by this independent re-run**, not accepted on trust.

---

## Suite map (independent count = 38)

| # | File | Test name |
|---|------|-----------|
| 1 | allowlist.test.ts | tokay is the only allowed product |
| 2 | allowlist.test.ts | rango is rejected |
| 3 | allowlist.test.ts | akita and empty product are rejected |
| 4 | allowlist.test.ts | rango manifest fails closed at channel load |
| 5 | channel.test.ts | loads matching manifest + SHA256SUMS + files.txt |
| 6 | channel.test.ts | refuses a factoryZip string (no invented install zip) |
| 7 | channel.test.ts | SHA256SUMS vs manifest hash disagreement fails closed |
| 8 | channel.test.ts | secret-shaped artifact names are rejected |
| 9 | channel.test.ts | rango product in pointer-shaped channel is rejected |
| 10 | hash.test.ts | matching digest passes |
| 11 | hash.test.ts | hash mismatch fails closed |
| 12 | hash.test.ts | executePlan fails closed when store bytes do not match SHA256SUMS |
| 13 | orchestrator.test.ts | suite does not claim a live-flash PASS |
| 14 | orchestrator.test.ts | wrong product (rango) is rejected on connect |
| 15 | orchestrator.test.ts | unlock cancelled is rejected |
| 16 | orchestrator.test.ts | lock before the plan completes is rejected |
| 17 | orchestrator.test.ts | mocked flash runs firmware then avb key then OS, then lock |
| 18 | orchestrator.test.ts | live executePlan is HOLD |
| 19 | orchestrator.test.ts | live lock is HOLD |
| 20 | orchestrator.test.ts | already-unlocked device does not send flashing unlock |
| 21 | plan.test.ts | flash order is firmware → avb_custom_key → os |
| 22 | plan.test.ts | artifact flash sequence is bootloader, radio, avb key, then OS |
| 23 | plan.test.ts | avb_pkmd.bin maps to partition avb_custom_key before any OS image |
| 24 | plan.test.ts | firmware reconnect happens before AVB flash |
| 25 | sha256-portable.test.ts | portable SHA-256 matches FIPS empty and abc vectors |
| 26 | sha256-portable.test.ts | portable SHA-256 matches node:crypto on fixture bytes |
| 27 | wizard-gating.test.ts | picker offers tokay only |
| 28 | wizard-gating.test.ts | flash is gated until unlock |
| 29 | wizard-gating.test.ts | lock is gated until flashcore plan completes |
| 30 | wizard-gating.test.ts | dry-run walks flashcore then allows lock |
| 31 | wizard-gating.test.ts | flashcore lock-before-complete remains the backstop |
| 32 | wizard-gating.test.ts | quota uses actual artifact bytes, not 1700 MiB |
| 33 | wizard-gating.test.ts | tiny quota is called out as a private-window problem |
| 34 | wizard-gating.test.ts | rango cannot be selected |
| 35 | wizard-gating.test.ts | wizard HTML is GuardTalkOS-branded and carries DEC labels |
| 36 | wizard-gating.test.ts | wizard executePlan refuses live mode |
| 37 | wizard-gating.test.ts | wizard lock refuses live mode |
| 38 | wizard-gating.test.ts | assertCanFlash names unlock as the missing gate |

Delta vs Q-WEBINSTALL-WIZARD (34): +4 DEC-009 tests (ok 18, 19, 36, 37). No prior tests deleted.

---

## Adversarial one-off probes (mocked; not committed)

26 probes via `tsx /tmp/q-webinstall-dryrun-only-probes.mts` importing `src/*.ts`, `wizard/*.ts`, `test/helpers.ts`. No file written under `src/`, `wizard/`, or `test/`.

```text
PASS LIVE_FLASH_CLAIMED === false
PASS orch.claimsLiveFlash() === false
PASS isDryRunTransport missing marker is live (undefined)
PASS isDryRunTransport dryRun:false is live
PASS isDryRunTransport truthy-string is live (fail closed)
PASS isDryRunTransport dryRun:true is dry-run
PASS MockFastboot default is dry-run
PASS MockFastboot({live:true}) is live
PASS adaptAndroidFastboot.dryRun === false
PASS live executePlan throws LiveExecuteHoldError (orchestrator)
PASS live lock throws LiveExecuteHoldError (orchestrator)
PASS missing dryRun property treated as live (orchestrator execute)
PASS missing dryRun property treated as live (orchestrator lock)
PASS adaptAndroidFastboot executePlan HOLD
PASS dry-run walks firmware → avb → OS then lock
PASS canFlash requires dryRun
PASS canLock requires dryRun
PASS wizard live executePlan throws LiveExecuteHoldError
PASS wizard live lock throws LiveExecuteHoldError
PASS wizard dry-run walks then lock
PASS wizard mode live even if transport.dryRun true still HOLD
PASS rango rejected allowlist + picker + wizard
PASS DEC-009 banner data-dec=009 in wizard/index.html
PASS DryRunTransport.dryRun is true const
PASS no live flash claimed after dry-run walk
PASS wizard dry-run mode + adaptAndroidFastboot still HOLD at orchestrator
ONE_OFF_PROBES_PASS 26
PROBE_EXIT=0
```

---

## Raw TAP (independent suite)

```text
TAP version 13
ok 1 - tokay is the only allowed product
ok 2 - rango is rejected
ok 3 - akita and empty product are rejected
ok 4 - rango manifest fails closed at channel load
ok 5 - loads matching manifest + SHA256SUMS + files.txt
ok 6 - refuses a factoryZip string (no invented install zip)
ok 7 - SHA256SUMS vs manifest hash disagreement fails closed
ok 8 - secret-shaped artifact names are rejected
ok 9 - rango product in pointer-shaped channel is rejected
ok 10 - matching digest passes
ok 11 - hash mismatch fails closed
ok 12 - executePlan fails closed when store bytes do not match SHA256SUMS
ok 13 - suite does not claim a live-flash PASS
ok 14 - wrong product (rango) is rejected on connect
ok 15 - unlock cancelled is rejected
ok 16 - lock before the plan completes is rejected
ok 17 - mocked flash runs firmware then avb key then OS, then lock
ok 18 - live executePlan is HOLD
ok 19 - live lock is HOLD
ok 20 - already-unlocked device does not send flashing unlock
ok 21 - flash order is firmware → avb_custom_key → os
ok 22 - artifact flash sequence is bootloader, radio, avb key, then OS
ok 23 - avb_pkmd.bin maps to partition avb_custom_key before any OS image
ok 24 - firmware reconnect happens before AVB flash
ok 25 - portable SHA-256 matches FIPS empty and abc vectors
ok 26 - portable SHA-256 matches node:crypto on fixture bytes
ok 27 - picker offers tokay only
ok 28 - flash is gated until unlock
ok 29 - lock is gated until flashcore plan completes
ok 30 - dry-run walks flashcore then allows lock
ok 31 - flashcore lock-before-complete remains the backstop
ok 32 - quota uses actual artifact bytes, not 1700 MiB
ok 33 - tiny quota is called out as a private-window problem
ok 34 - rango cannot be selected
ok 35 - wizard HTML is GuardTalkOS-branded and carries DEC labels
ok 36 - wizard executePlan refuses live mode
ok 37 - wizard lock refuses live mode
ok 38 - assertCanFlash names unlock as the missing gate
1..38
# tests 38
# suites 0
# pass 38
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 426.721508
TEST_EXIT=0
TSC_SRC_EXIT=0
TSC_WIZARD_EXIT=0
```

Durations omitted above for readability; first independent TAP included `duration_ms` per subtest.

---

## C13 — flash scripts

```text
$ cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh
FLASH_SCRIPTS_IDENTICAL
  1135 scripts/flash-from-remote.sh
  1135 vendor/guardtalk/scripts/flash-from-remote.sh
d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c  scripts/flash-from-remote.sh
d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c  vendor/guardtalk/scripts/flash-from-remote.sh
```

## package.json

```text
dependencies None
devDependencies {'@types/node': '22.10.5', 'tsx': '4.19.3', 'typescript': '5.7.3'}
has_android_fastboot False
NO_ANDROID_FASTBOOT_IN_LOCK
```

## rango-latest (read-only stamp check)

```text
releases/desktop-flash/rango-latest -> rango-20260802-130756
```

Not re-flashed. Not treated as a boot fix.

---

## Coverage gaps / notes (not FAIL)

1. **No live-flash PASS.** Dual-layer HOLD was exercised with mocks and a stub `adaptAndroidFastboot` device. No WebUSB / `adb` / `fastboot` against hardware.
2. **Browser E2E HOLD.** DEC-009 banner is in `wizard/index.html`; it was not clicked in Chromium.
3. **Not CLI / dual-slot / fastbootd parity.** DEC-008 + DEC-009 remain documented non-goals. This card only proves live execute/lock refuse.
4. **Unlock/lock wipe copy** in `wizard/index.html:115` is Pixel bootloader unlock/lock behavior, not a flashcore `erase userdata` / `erase metadata` step.
5. **Wizard `canFlash` is mode-based.** `flags.dryRun` is `mode === "dry-run"`. Attaching `adaptAndroidFastboot` while still in dry-run mode leaves `canFlash===true`; orchestrator `isDryRunTransport` is the second layer and still HOLDs. That is fail-closed, not a bypass.
6. **`rango-latest` stays `130756`.** QA did not flash.

---

## Law / gate checklist (QA)

| Law / Gate | Result |
|------------|--------|
| Law 0 Architect-dispatched only | PASS (`TO_QA.md` + both cards) |
| Law 2 Scope (evidence + queues only) | PASS |
| Law 3 Error-path tests exist | PASS (live HOLD, missing marker, rango, hash) |
| Law 4 Security scan | PASS (no secrets; live execute fail-closed) |
| Law 7 Did not trust T / Architect 38/38 | PASS (independent re-run) |
| Law 9 MCP critique python missing | PASS (did not stop; manual Gate 5) |
| Law 11 Reversible (no src/wizard edit) | PASS |
| Law 12 Doctrine untouched | PASS |
| Law 16 Tests re-run | PASS 38/38, TSC_EXIT 0 |
| Law 17 No PII/secrets | PASS |
| Gate -1 Guardian First | PASS (after consult) |
| Gate 5 Self-critique | see completion report |

**Verdict for Architect:** **REVIEW** — host/mocked **PASS**. Do **not** treat as live-flash PASS. Do **not** treat as browser E2E PASS. Do **not** treat as CLI / dual-slot / fastbootd parity.

### PQE Assessment: Code Entropy LOW

DEC-009 is two small typed guards (`assertDryRunOnly` on orchestrator + wizard) plus `isDryRunTransport` (`dryRun === true` only). Live adapter is marked `dryRun: false`. Fail-closed on missing marker. Dual-layer holds even if one layer is lied to.

### Ultimate Critique Score: 94% (Gate 5, manual)

`ultimate_critique` MCP: TOOL UNAVAILABLE (`python: not found`; score 0% discarded).  
`self_critique` MCP: 91/100 with a Law-5 false positive on the word “secrets” in the QA summary (no secrets present).  
Manual 0–10: acceptance 10, scope 10, suite pass 10, no regressions 10, adversarial 10, edge 9, independence 10, footprint 10, bug docs 9, gaps 6. Total **94**.
