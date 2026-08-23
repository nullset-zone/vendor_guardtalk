# Q-WEBINSTALL-WIZARD Evidence

**Task:** Q-WEBINSTALL-WIZARD  
**QA run:** 2026-08-20T16:18:00Z–2026-08-20T16:20:48Z (independent re-run; did **not** trust F report or Architect 34/34)  
**Artifact under test (read-only):** `vendor/guardtalk/web-installer/` (`wizard/` + `src/` + `test/`)  
**Depends on:** F-WEBINSTALL-WIZARD APPROVED  
**Not edited:** `web-installer/src/`, `web-installer/wizard/`, both `flash-from-remote.sh`, doctrine, governance laws/gates, secrets  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**Browser E2E:** **not run** — HOLD  
**QA status:** **REVIEW only** (never APPROVED)

## Governance

- GIP-0 VERIFIED: workflow `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q cards, PROTOCOL/ROLES, memory-bank (`activeContext.md`, `progress.md` tail, `decisions.md` DEC-001..008, `systemPatterns.md`, `projectBrief.md`), AGENTS.md.
- Prompt-injection shield: SAFE (risk 0%; 22 pattern checks; 0 threats).
- Gate -1: first `gate_enforcer` check failed (`guardian_consulted` missing). `ask_guardian` returned fallback (`Guardian Proxy not available`; `governanceStatus=compliant`; “You may proceed”). Retry Gate -1 **PASSED**.
- Later Gate 0/1/3 checks were blocked by MCP session reset (`blockedBy: -1`). Law 9: did not stop; evidence is this file.
- Packet path lock: writes only under `vendor/guardtalk/docs/qa/`, `TO_ARCHITECT.md`, both `TASK_QUEUE.md`. Memory-bank write skipped (not in packet allowlist).
- Packet is authoritative: no `src/` or `wizard/` edits; no new test files.

## Environment

| Item | Independent observation |
|------|-------------------------|
| Host | Linux, cwd `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| Node | `/home/openstatestack/.local/node/bin/node` v22.12.0 (`npm` 10.9.2 also present) |
| Tools | `tsc` / `tsx` from `vendor/guardtalk/web-installer/node_modules/.bin` |
| Command | `cd vendor/guardtalk/web-installer && tsc --noEmit && tsc -p tsconfig.wizard.json --noEmit && tsx --test test/*.test.ts` |
| `test()` count on disk | allowlist 4 + channel 5 + hash 3 + orchestrator 6 + plan 4 + sha256-portable 2 + wizard-gating 10 = **34** |
| Live device | **none** — no `adb`/`fastboot`/WebUSB flash this session |
| Browser E2E | **none** — no Chromium/Playwright run |

---

## Check matrix

| ID | Check | Expected | Actual | Verdict |
|----|-------|----------|--------|---------|
| C1 | Independent `tsc --noEmit` | exit 0 | `TSC_SRC_EXIT=0` | **PASS** |
| C2 | Independent `tsc -p tsconfig.wizard.json --noEmit` | exit 0 | `TSC_WIZARD_EXIT=0` | **PASS** |
| C3 | Independent `tsx --test test/*.test.ts` | 34/34, fail 0 | `# tests 34` `# pass 34` `# fail 0` `TEST_EXIT=0` | **PASS** |
| C4 | Branding is GuardTalkOS; reject GOS paste `The web installer is the easiest method` | HTML + tree | HTML title/eyebrow/footer GuardTalkOS; rg of tree finds paste **only** as a `doesNotMatch` in `test/wizard-gating.test.ts:119` | **PASS** |
| C5 | Tokay selectable; rango not offered; `selectDevice('rango')` fails | picker tokay-only | `WIZARD_DEVICES` length 1 id `tokay`; HTML has no `value="rango"`; one-off + ok 25/32: `selectDevice('rango')` → `WizardGateError` (`not offered`); `akita` also rejected | **PASS** |
| C6 | No flash before unlock | `canFlash` false; `executePlan` throws | ok 26 + ok 34 + one-off: `canFlash===false`; `WizardGateError` `/unlock/`; `assertCanFlash` names unlock | **PASS** |
| C7 | No lock before flashcore `planComplete` | `canLock` false; `lock()` throws | ok 27 + ok 29 + one-off: `WizardGateError` `/plan completes/`; flashcore `LockBeforeCompleteError` still the backstop | **PASS** |
| C8 | DEC-007 `dev/unlocked` + not GOS-equivalent locked verified boot | banners present | `wizard/index.html` `data-dec="007"`: “dev/unlocked” + “not GrapheneOS-equivalent locked verified boot”; lock status copy same | **PASS** |
| C9 | DEC-008 not a substitute for `flash-from-remote.sh` / dual-slot | banners present | `data-dec="008"`: “not a substitute for `flash-from-remote.sh`” + dual-slot mentioned; no CLI-parity claim | **PASS** |
| C10 | Quota warning uses actual artifact sizes (not 1700 MiB) | sum(`file.size`) + 256 MiB slack | `payloadBytes` / `assessQuota`; ok 30; one-off 100.0 MiB, summary has no `1700`; `EXTRACT_SLACK_BYTES = 256 MiB`. Note: sizes come from channel `files` (`files.txt`), not measured blob `byteLength` | **PASS** (note) |
| C11 | Incognito / private window called unsupported | copy + quota | HTML: “Private / Incognito windows are not a supported path”; ok 31 + one-off: `Incognito is not a supported path` | **PASS** |
| C12 | Reconnect copy + dialog after reboot-bootloader | markup + wiring | HTML section + `<dialog id="reconnect-dialog">`; `main.ts` `waitForReconnect()` `showModal()` passed to `executePlan` | **PASS** (host); **HOLD** (browser E2E) |
| C13 | Wizard under `vendor/guardtalk/web-installer/wizard/` not AEGIS CONTROL CENTER | path isolation | `wizard/` has 8 files; `find` of `apps/AEGIS CONTROL CENTER` (prune `node_modules`) found no wizard / web-install files | **PASS** |
| C14 | `android-fastboot` is **not** a runtime dependency | package.json deps none; devDeps only tsx/typescript/@types/node | `dependencies` = None; `devDependencies` = `@types/node` 22.10.5, `tsx` 4.19.3, `typescript` 5.7.3; no `android-fastboot` in `package.json` or `package-lock.json` | **PASS** |
| C15 | `LIVE_FLASH_CLAIMED === false` | constant false | `src/types.ts:110` `export const LIVE_FLASH_CLAIMED = false`; `session.claimsLiveFlash()` / `orch.claimsLiveFlash()` return it; ok 13/17/28; one-off same | **PASS** |
| C16 | Flash scripts `cmp` IDENTICAL | silent cmp | `FLASH_SCRIPTS_IDENTICAL`; both 1135 lines; SHA-256 `d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c` | **PASS** |
| C17 | Hash split (`hash.ts` / `sha256-portable.ts` / `channel-fs.ts`) still fail-closed | mismatch throws; plan incomplete | `hash.ts` delegates to `sha256PortableHex`; `orchestrator.flashVerified` still `assertSha256Match` before `transport.flash`; ok 10–12, 23–24; one-off tampered `boot.img` → `HashMismatchError`, `isPlanComplete()===false`. `channel-fs.ts` is host-only wrapper around `loadChannelFromTexts` | **PASS** |
| C18 | No secrets (`*.pem` `*.pk8` `.env`) | none in tree (excl. node_modules) | named-secret files empty; `NO_PRIVATE_KEY_OR_AWS_PATTERNS` | **PASS** |
| C19 | No `src/` or `wizard/` edits by QA | read-only | QA wrote only this evidence + queues + `TO_ARCHITECT.md`. One-off probe lived at `/tmp/q-webinstall-wizard-probes.mts` (not in repo) | **PASS** |
| C20 | No live-flash PASS | honesty | none run; `LIVE_FLASH_CLAIMED===false` | **HOLD** (honesty) |
| C21 | Browser E2E | optional | not run | **HOLD** |
| C22 | Full CLI / dual-slot parity | must not claim | DEC-008 banner + README: not a substitute; dual-slot follow-on | **HOLD** (not claimed) |

**Overall (host/mocked):** **PASS** with **HOLD** (no live-flash; no browser E2E; no CLI dual-slot parity claim).

Architect/F “34/34” is **confirmed by this independent re-run**, not accepted on trust.

---

## Suite map (independent count = 34)

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
| 18 | orchestrator.test.ts | already-unlocked device does not send flashing unlock |
| 19 | plan.test.ts | flash order is firmware → avb_custom_key → os |
| 20 | plan.test.ts | artifact flash sequence is bootloader, radio, avb key, then OS |
| 21 | plan.test.ts | avb_pkmd.bin maps to partition avb_custom_key before any OS image |
| 22 | plan.test.ts | firmware reconnect happens before AVB flash |
| 23 | sha256-portable.test.ts | portable SHA-256 matches FIPS empty and abc vectors |
| 24 | sha256-portable.test.ts | portable SHA-256 matches node:crypto on fixture bytes |
| 25 | wizard-gating.test.ts | picker offers tokay only |
| 26 | wizard-gating.test.ts | flash is gated until unlock |
| 27 | wizard-gating.test.ts | lock is gated until flashcore plan completes |
| 28 | wizard-gating.test.ts | dry-run walks flashcore then allows lock |
| 29 | wizard-gating.test.ts | flashcore lock-before-complete remains the backstop |
| 30 | wizard-gating.test.ts | quota uses actual artifact bytes, not 1700 MiB |
| 31 | wizard-gating.test.ts | tiny quota is called out as a private-window problem |
| 32 | wizard-gating.test.ts | rango cannot be selected |
| 33 | wizard-gating.test.ts | wizard HTML is GuardTalkOS-branded and carries DEC labels |
| 34 | wizard-gating.test.ts | assertCanFlash names unlock as the missing gate |

---

## Adversarial one-off probes (mocked; not committed)

29 probes via `tsx /tmp/q-webinstall-wizard-probes.mts` importing `src/*.ts`, `wizard/*.ts`, `test/helpers.ts`. No file written under `src/`, `wizard/`, or `test/`.

```text
PASS LIVE_FLASH_CLAIMED === false | false
PASS claimsLiveFlash false
PASS picker tokay only
PASS picker has no rango
PASS selectDevice(rango) throws WizardGateError
PASS selectDevice(akita) throws
PASS selectDevice(tokay) ok
PASS canFlash before unlock is false
PASS executePlan before unlock throws WizardGateError
PASS canLock before planComplete is false
PASS lock before planComplete throws WizardGateError
PASS planComplete after dry-run
PASS canLock after planComplete
PASS still not live flash
PASS quota payload is 100 MiB not 1700
PASS quota summary has 100.0 MiB
PASS incognito copy in quota
PASS hash assertSha256Match still fail-closed after split
PASS executePlan tampered boot fail-closed HashMismatchError
PASS planComplete false after hash fail
PASS html GuardTalkOS
PASS html no GOS easiest paste
PASS html DEC-007
PASS html DEC-008
PASS html incognito unsupported
PASS html reconnect copy+dialog
PASS html no rango option
PASS html no 1700 MiB
PASS assertCanFlash/Lock messages
ONE_OFF_PROBES_PASS 29
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
ok 18 - already-unlocked device does not send flashing unlock
ok 19 - flash order is firmware → avb_custom_key → os
ok 20 - artifact flash sequence is bootloader, radio, avb key, then OS
ok 21 - avb_pkmd.bin maps to partition avb_custom_key before any OS image
ok 22 - firmware reconnect happens before AVB flash
ok 23 - portable SHA-256 matches FIPS empty and abc vectors
ok 24 - portable SHA-256 matches node:crypto on fixture bytes
ok 25 - picker offers tokay only
ok 26 - flash is gated until unlock
ok 27 - lock is gated until flashcore plan completes
ok 28 - dry-run walks flashcore then allows lock
ok 29 - flashcore lock-before-complete remains the backstop
ok 30 - quota uses actual artifact bytes, not 1700 MiB
ok 31 - tiny quota is called out as a private-window problem
ok 32 - rango cannot be selected
ok 33 - wizard HTML is GuardTalkOS-branded and carries DEC labels
ok 34 - assertCanFlash names unlock as the missing gate
1..34
# tests 34
# suites 0
# pass 34
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 410.419054
TEST_EXIT=0
TSC_SRC_EXIT=0
TSC_WIZARD_EXIT=0
```

Durations omitted above for readability; full TAP included `duration_ms` per subtest.

---

## C16 — flash scripts

```text
$ cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh
FLASH_SCRIPTS_IDENTICAL
  1135 scripts/flash-from-remote.sh
  1135 vendor/guardtalk/scripts/flash-from-remote.sh
d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c  scripts/flash-from-remote.sh
d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c  vendor/guardtalk/scripts/flash-from-remote.sh
```

## C14 — package.json

```text
dependencies None
devDependencies {'@types/node': '22.10.5', 'tsx': '4.19.3', 'typescript': '5.7.3'}
has_android_fastboot False
NO_ANDROID_FASTBOOT_IN_LOCK
```

---

## Coverage gaps / notes (not FAIL)

1. **Browser E2E HOLD.** Reconnect `<dialog>` and Incognito checkbox are present and wired in `wizard/main.ts`; they were not exercised in a real Chromium window.
2. **No live WebUSB.** `adaptAndroidFastboot` exists; `android-fastboot` is not bundled. Dry-run only.
3. **Quota sizes** are `files.txt` declared sizes, not a live `blob.byteLength` sum. Still not a 1700 MiB constant.
4. **Flashcore `executePlan` does not itself require unlock.** Wizard `assertCanFlash` is the UI/session gate; device-side unlock remains the physical gate. Same layering as Q-WEBINSTALL-FLASHCORE.
5. **Do not claim** full `flash-from-remote.sh` dual-slot parity (DEC-008).

---

## Law / gate checklist (QA)

| Law / Gate | Result |
|------------|--------|
| Law 0 Architect-dispatched only | PASS (`TO_QA.md` + both cards) |
| Law 2 Scope (evidence + queues only) | PASS |
| Law 3 Error-path tests exist | PASS (unlock/lock/rango/hash) |
| Law 4 Security scan | PASS (no secrets; no android-fastboot runtime) |
| Law 7 Did not trust F / Architect 34/34 | PASS (independent re-run) |
| Law 9 MCP later-gate session reset | PASS (did not stop) |
| Law 11 Reversible (no src/wizard edit) | PASS |
| Law 12 Doctrine untouched | PASS |
| Law 16 Tests re-run | PASS 34/34, TSC_EXIT 0 |
| Law 17 No PII/secrets | PASS |
| Gate -1 Guardian First | PASS (after consult) |
| Gate 5 Self-critique | see completion report |

**Verdict for Architect:** **REVIEW** — host/mocked **PASS**. Do **not** treat as live-flash PASS. Do **not** treat as browser E2E PASS. Do **not** treat as CLI/dual-slot parity.

### PQE Assessment: Code Entropy LOW

Wizard gates are small, typed, and fail-closed (`WizardGateError`). Flashcore hash/product/lock backstops remain. Branding and DEC banners are explicit, not inferred.
