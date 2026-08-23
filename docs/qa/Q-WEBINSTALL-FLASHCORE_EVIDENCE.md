# Q-WEBINSTALL-FLASHCORE Evidence

**Task:** Q-WEBINSTALL-FLASHCORE  
**QA run:** 2026-08-20T15:57:03Z–2026-08-20T15:58:30Z (independent re-run; did **not** trust T completion report)  
**Artifact under test (read-only):** `vendor/guardtalk/web-installer/` (`src/` + `test/`)  
**Depends on:** T-WEBINSTALL-FLASHCORE APPROVED  
**Not edited:** `web-installer/src/`, `test/`, both `flash-from-remote.sh`, `pack-webinstall-channel.sh`, doctrine, governance laws/gates, secrets  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**QA status:** **REVIEW only** (never APPROVED)

## Governance

- GIP-0 VERIFIED: workflow `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q cards, PROTOCOL/ROLES, memory-bank (`activeContext.md`, `progress.md` tail, `decisions.md` DEC-001..008, `systemPatterns.md`, `projectBrief.md`), AGENTS.md.
- Prompt-injection shield: SAFE (risk 0%; 22 pattern checks; 0 threats).
- Gate -1: first `gate_enforcer` check failed (`guardian_consulted` missing). `ask_guardian` returned fallback (`Guardian Proxy not available`; `governanceStatus=compliant`; “You may proceed”). Retry Gate -1 **PASSED**.
- Law 9: Guardian proxy unavailable; proceeded with local fallback + written evidence (do not stop).
- Packet path lock: writes only under `vendor/guardtalk/docs/qa/`, `TO_ARCHITECT.md`, both `TASK_QUEUE.md`. Memory-bank write skipped (not in packet allowlist).
- Packet is authoritative over extra root-queue wording (`quota`, `fwupd`) — those are wizard-scope, not this card.

## Environment

| Item | Independent observation |
|------|-------------------------|
| Host | Linux, cwd `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| Node | `/home/openstatestack/.local/node/bin/node` v22.12.0 (`npm` 10.9.2 also present) |
| Tools | `tsc` / `tsx` from `vendor/guardtalk/web-installer/node_modules/.bin` |
| Command | `cd vendor/guardtalk/web-installer && tsc --noEmit && tsx --test test/*.test.ts` |
| `test()` count on disk | allowlist 4 + channel 5 + hash 3 + orchestrator 6 + plan 4 = **22** |
| Live device | **none** — no `adb`/`fastboot` flash this session |

---

## Check matrix

| ID | Check | Expected | Actual | Verdict |
|----|-------|----------|--------|---------|
| C1 | Independent `tsc --noEmit` | exit 0 | `TSC_EXIT=0` at 2026-08-20T15:57:19Z | **PASS** |
| C2 | Independent `tsx --test test/*.test.ts` | 22/22, fail 0 | `# tests 22` `# pass 22` `# fail 0` `TEST_EXIT=0` (15:57:21Z) | **PASS** |
| C3 | Wrong product / rango (suite) | reject on allowlist + connect + channel load | ok 2 rango allowlist; ok 3 akita/empty; ok 4 rango manifest; ok 9 rango pointer; ok 14 rango `connect()` → `WrongProductError` | **PASS** |
| C4 | Unlock cancelled (suite) | `UnlockCancelledError` | ok 15 `unlock cancelled is rejected` | **PASS** |
| C5 | Hash mismatch (suite) | fail closed | ok 11 `assertSha256Match` throws `HashMismatchError`; ok 12 `executePlan` tampered `boot.img` throws, `isPlanComplete()===false`; ok 7 SUMS vs manifest disagree | **PASS** |
| C6 | Lock-before-flash-complete (suite) | `LockBeforeCompleteError` | ok 16 lock before `executePlan` rejected; `isPlanComplete()===false` | **PASS** |
| C7 | factoryZip non-null (suite + probe) | `ChannelError` | ok 6 + one-off: `factoryZip must be null this wave; consume files.txt + SHA256SUMS` | **PASS** |
| C8 | Omitted `avb_pkmd.bin` (loadable; **not** a named suite test) | fail closed at load and/or plan | One-off: omit from texts → `ChannelError: avb.sha256 does not match SHA256SUMS`; wrong `publicKeyFile` → `avb.publicKeyFile must be avb_pkmd.bin`; mutate files → `PlanError: avb phase must be exactly avb_pkmd.bin` | **PASS** (probed) / **WARN** (not in committed 22) |
| C9 | Reconnect hook invoked; firmware before AVB | hook runs after firmware, before `avb_custom_key` | Suite ok 22 plan order; ok 17 `reconnects >= 2`. One-off: `hookCalls=2` `firstHookFlashes=["bootloader","radio"]` then `avb_custom_key` | **PASS** |
| C10 | `LIVE_FLASH_CLAIMED === false` | constant false; `claimsLiveFlash()` false | `src/types.ts:110` `export const LIVE_FLASH_CLAIMED = false`; ok 13 + ok 17; one-off same | **PASS** |
| C11 | No secrets in flashcore tree | no `*.pem`/`*.pk8`/`.env`/PEM text | named-secret files empty; `NO_PRIVATE_KEY_OR_AWS_PATTERNS`; only `SECRET_NAME_RE` + reject test for `key.pem` | **PASS** |
| C12 | Both `flash-from-remote.sh` identical | `cmp` silent | `FLASH_SCRIPTS_IDENTICAL`; both 1135 lines; SHA-256 `d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c` | **PASS** |
| C13 | No live-flash PASS | no device flash | none run; `android-fastboot` not a runtime dep (`package.json` devDeps only tsx/tsc/@types/node) | **PASS** (honesty) |
| C14 | DEC-006 order firmware → avb → OS | plan + mocked flash order | ok 19–21; ok 17 flashes `bootloader, radio, avb_custom_key, boot, vbmeta` | **PASS** |
| C15 | No `any` in `src/` | none | `rg` `\bany\b` in `src/` = 0 | **PASS** |
| C16 | Root-queue extras: quota / fwupd | packet does **not** require (wizard) | no `quota`/`fwupd` in `web-installer` src/test | **HOLD** (out of this card) |
| C17 | Reconnect *failure* (hook throws) | packet asked invocation, not fail | no dedicated suite test that `onReconnect` reject fails closed | **HOLD** (gap vs older queue wording) |

**Overall (host/mocked):** **PASS** with **WARN** (omitted-`avb_pkmd.bin` is fail-closed in code but not a committed `test()` name) and **HOLD** (no live-flash; quota/fwupd/reconnect-fail are not this card).

---

## Negative matrix (packet-authoritative)

| Packet item | Covered by | Result |
|-------------|------------|--------|
| wrong product / rango | suite ok 2, 3, 4, 9, 14 | **PASS** |
| unlock cancelled | suite ok 15 | **PASS** |
| hash mismatch | suite ok 7, 11, 12 | **PASS** |
| lock-before-flash-complete | suite ok 16 | **PASS** |
| omitted `avb_pkmd.bin` | QA one-off (not in 22 names) | **PASS** (probed) |
| factoryZip non-null | suite ok 6 + one-off | **PASS** |
| reconnect hook invoked (firmware before AVB) | suite ok 17, 22 + one-off | **PASS** |
| `LIVE_FLASH_CLAIMED === false` | suite ok 13, 17 + one-off | **PASS** |
| no secrets | scan + suite ok 8 | **PASS** |
| flash scripts identical | `cmp` + SHA-256 | **PASS** |

---

## Suite map (independent count = 22)

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

---

## Coverage gaps (not packet FAILs)

- Committed suite has **no** `test()` titled omitted `avb_pkmd.bin`. Production fail-closed is real (`assembleChannel` AVB digest check; `buildFlashPlan` requires exactly `avb_pkmd.bin`). QA probed both paths; did **not** add a test file (packet forbids `src/` edits; `test/` not in allowlist).
- `LockCancelledError` exists; no suite case for lock FAIL after plan complete.
- `snapshot-update:cancel` path untested.
- `adaptAndroidFastboot` `slot === "other"` exists in `transport.ts` (DEC-008: v1 must not claim dual-slot). Mocked happy path does not pass `slot`.
- Quota / fwupd belong to `F/Q-WEBINSTALL-WIZARD`, not flashcore.
- No in-tree packed `manifest.json` under `vendor/guardtalk/` for a live `loadChannelFromDir` (0 files). factoryZip check used mocked texts only.

## Bugs found

- None that fail the packet matrix on this independent mocked re-run.

## Security (Gate 3 / Law 4)

- [x] No hardcoded credentials in `web-installer/src` or `test`
- [x] Secret-shaped names rejected (`.pem`/`.pk8`)
- [x] Hash mismatch fail-closed
- [x] Product allowlist fail-closed (rango/akita/empty)
- [x] QA did not open or copy secrets
- [x] No new dependencies added by QA

### PQE Assessment: Code Entropy **LOW**

Deterministic plan builder, typed fail-closed errors, SHA-256 before flash, tokay-only allowlist. Residual entropy: omitted-AVB not named in the suite; live WebUSB adapter untested (by design this wave).

---

## Raw command output

### C1 + C2 — independent `tsc` + `tsx --test`

```text
$ export PATH="$HOME/.local/node/bin:$PWD/vendor/guardtalk/web-installer/node_modules/.bin:$PATH"
$ cd vendor/guardtalk/web-installer
$ tsc --noEmit
TSC_EXIT=0
$ tsx --test test/*.test.ts
TAP version 13
# Subtest: tokay is the only allowed product
ok 1 - tokay is the only allowed product
# Subtest: rango is rejected
ok 2 - rango is rejected
# Subtest: akita and empty product are rejected
ok 3 - akita and empty product are rejected
# Subtest: rango manifest fails closed at channel load
ok 4 - rango manifest fails closed at channel load
# Subtest: loads matching manifest + SHA256SUMS + files.txt
ok 5 - loads matching manifest + SHA256SUMS + files.txt
# Subtest: refuses a factoryZip string (no invented install zip)
ok 6 - refuses a factoryZip string (no invented install zip)
# Subtest: SHA256SUMS vs manifest hash disagreement fails closed
ok 7 - SHA256SUMS vs manifest hash disagreement fails closed
# Subtest: secret-shaped artifact names are rejected
ok 8 - secret-shaped artifact names are rejected
# Subtest: rango product in pointer-shaped channel is rejected
ok 9 - rango product in pointer-shaped channel is rejected
# Subtest: matching digest passes
ok 10 - matching digest passes
# Subtest: hash mismatch fails closed
ok 11 - hash mismatch fails closed
# Subtest: executePlan fails closed when store bytes do not match SHA256SUMS
ok 12 - executePlan fails closed when store bytes do not match SHA256SUMS
# Subtest: suite does not claim a live-flash PASS
ok 13 - suite does not claim a live-flash PASS
# Subtest: wrong product (rango) is rejected on connect
ok 14 - wrong product (rango) is rejected on connect
# Subtest: unlock cancelled is rejected
ok 15 - unlock cancelled is rejected
# Subtest: lock before the plan completes is rejected
ok 16 - lock before the plan completes is rejected
# Subtest: mocked flash runs firmware then avb key then OS, then lock
ok 17 - mocked flash runs firmware then avb key then OS, then lock
# Subtest: already-unlocked device does not send flashing unlock
ok 18 - already-unlocked device does not send flashing unlock
# Subtest: flash order is firmware → avb_custom_key → os
ok 19 - flash order is firmware → avb_custom_key → os
# Subtest: artifact flash sequence is bootloader, radio, avb key, then OS
ok 20 - artifact flash sequence is bootloader, radio, avb key, then OS
# Subtest: avb_pkmd.bin maps to partition avb_custom_key before any OS image
ok 21 - avb_pkmd.bin maps to partition avb_custom_key before any OS image
# Subtest: firmware reconnect happens before AVB flash
ok 22 - firmware reconnect happens before AVB flash
1..22
# tests 22
# suites 0
# pass 22
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 409.636839
TEST_EXIT=0
```

Durations omitted above for readability; full TAP included `duration_ms` per subtest. Wall clock: tsc 15:57:19Z, tests 15:57:21Z.

### C8 + C9 — independent one-off probes (mocked; not committed)

```text
PASS omit-avb-channel-load: ChannelError: avb.sha256 does not match SHA256SUMS
PASS omit-avb-publicKeyFile: ChannelError: avb.publicKeyFile must be avb_pkmd.bin
PASS omit-avb-plan: PlanError: avb phase must be exactly avb_pkmd.bin
PASS factoryZip-non-null: ChannelError: factoryZip must be null this wave; consume files.txt + SHA256SUMS
PASS reconnect-hook-firmware-before-avb: hookCalls=2 reconnects=2 firstHookFlashes=["bootloader","radio"] flashes=["bootloader","radio","avb_custom_key","boot","vbmeta"] LIVE_FLASH_CLAIMED=false
PASS live-flash-claimed-false: LIVE_FLASH_CLAIMED=false
PROBE_SUMMARY pass=6 fail=0 total=6
```

One-off used `tsx --input-type=module` importing `src/*.ts` + `test/helpers.ts`. No file written under `src/` or `test/`.

### C12 — flash scripts

```text
$ cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh
FLASH_SCRIPTS_IDENTICAL
  1135 scripts/flash-from-remote.sh
  1135 vendor/guardtalk/scripts/flash-from-remote.sh
d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c  scripts/flash-from-remote.sh
d48a0c9dd2c48065e4c8f3707751f4056fd9675ed9cccd6c60c3f467c442d63c  vendor/guardtalk/scripts/flash-from-remote.sh
```

---

## Law / gate checklist (QA)

| Law / Gate | Result |
|------------|--------|
| Law 0 Architect-dispatched only | PASS (`TO_QA.md` + both cards) |
| Law 2 Scope (evidence + queues only) | PASS |
| Law 3 Error-path tests exist | PASS (unlock/lock/hash/product) |
| Law 4 Security scan | PASS (no secrets) |
| Law 7 Did not trust T report | PASS (independent re-run) |
| Law 11 Reversible (no src edit) | PASS |
| Law 12 Doctrine untouched | PASS |
| Law 16 Tests re-run | PASS 22/22 |
| Law 17 No PII/secrets in fixtures | PASS (`public-avb-pkmd` fixture text) |
| Gate -1 Guardian First | PASS (after consult) |
| Gate 5 Self-critique | see completion report |

**Verdict for Architect:** **REVIEW** — host/mocked **PASS**. Do not treat as live-flash PASS.
