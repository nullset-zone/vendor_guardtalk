# Q-WEBINSTALL-ADB-FIXES — Independent Verification Evidence

| Field | Value |
|-------|--------|
| Task | `Q-WEBINSTALL-ADB-FIXES` |
| Role | AEGIS QA Engineer (adversarial, independent of Backend report) |
| Timestamp (UTC) | 2026-08-21T12:32:00Z |
| Scope dir (read-only) | `vendor/guardtalk/web-installer/` |
| Evidence base | `docs/qa/A-WEBINSTALL-EXTREME_AUDIT.md`, `.agent-comm/inbox/TO_ARCHITECT_BACKEND.md` |
| Environment | Node v22.12.0 (`/home/openstatestack/.local/node/bin`); host/mocked only |
| Live USB / live device | **NONE** — every test and probe uses mocked in-memory IO |
| Probe scripts | `/tmp/qa-probes/*.ts` (throwaway, never committed) |

**VERDICT: PASS**

---

## 1. Gate -1

`ask_guardian` → `governanceStatus=compliant` ("You may proceed"; Guardian Proxy
fallback, laws 8+10 cited). `gate_enforcer` Gate -1 **PASSED**
(guardian_consulted, session_initialized). Read-only on all product code; the
only repo writes are this evidence file and the completion report.

## 2. Independent suite re-run (raw)

```text
$ npx tsc --noEmit                        → TSC_EXIT=0
$ npx tsc -p tsconfig.wizard.json --noEmit → WIZARD_TSC_EXIT=0
$ npx tsx --test test/*.test.ts           → TESTS_EXIT=0
  1..61
  # tests 61 · # pass 61 · # fail 0 · # cancelled 0 · # skipped 0
  # duration_ms 2419.519767
```

Matches the Backend report (61/61) exactly. Baseline 49 preserved + 12 new.

## 3. Per-claim results

| # | Claim (fix under test) | Method | Result |
|---|------------------------|--------|--------|
| C1 | F4: leftover buffer capped at 1 MiB, fails closed | code read + probes §4-A/B/C | **PASS** |
| C2 | F5: non-empty payload with forged `check==0` rejected; zero-length `check==0` still accepted | code read + probe §4-F5 | **PASS** |
| C3 | F7: OKAY `arg1 != localId` rejected with "local id" error | code read + probe §4-F7 | **PASS** |
| C4 | F2: post-OPEN DOMException outside allowlist surfaces as AdbError (never silent success); allowlist is NARROW | code read + probe §4-F2 | **PASS** |
| C5 | F2: `NetworkError` still counts as expected disconnect (success path) | probe §4-F2 [3][5] | **PASS** |
| C6 | F1: timeout aborts in-flight read AND closes io; no leaked handle | code read + probe §4-F1 | **PASS** |
| C7 | Key-at-rest disclosed in README + NOTICE, matching reality | doc/code diff §5 | **PASS** |
| C8 | DEC-009: `LIVE_FLASH_CLAIMED = false` untouched (`src/types.ts:119`, sole assignment in tree) | grep + tests ok | **PASS** |
| C9 | DEC-009: ADB path sends only `reboot:bootloader`; no flash/unlock/lock/fastboot commands in `adb-*.ts` | grep §6 | **PASS** |
| C10 | DEC-009: `executePlan`/`lock` dry-run gating untouched (double-gated session+orchestrator) | code read §6 | **PASS** |
| C11 | No live-flash PASS claimed anywhere | repo-wide grep §6 | **PASS** |
| C12 | Independent suite counts match Backend report | §2 | **PASS** |

No FAIL. No HOLD.

## 4. Hostile-packet negative matrix (own probes, `/tmp/qa-probes/`)

### F4 — leftover cap (`f4_leftover_cap.ts`)

```text
MAX_LEFTOVER_BYTES = 1048576 (expected 1048576)
[A] single 1048577-byte chunk -> AdbError 'exceeds the ...-byte cap'; reads=1
[B] valid header + 1048576-byte flood mid-payload -> AdbError cap after 2 reads
[C] exactly 1048576 bytes buffered -> no cap trip; OKAY parsed (boundary semantics '>')
[C+] subsequent garbage header fails on magic, not cap
F4 PROBE: PASS
```

Variant B is the realistic attack: a valid CNXN header declaring `len=4096`
plus a flood chunk while the payload demand is open — accumulation crosses the
cap mid-`readExact` and throws `AdbError`. Variant C pins the boundary
semantics (`>` not `>=`): exactly 1 MiB parses fine, no false positive.

### F5 — checksum rule (`f5_checksum.ts`)

```text
[1] non-empty payload + forged check=0 -> AdbError 'checksum mismatch' (rejected)
[2] zero-length payload + check=0 -> accepted (OKAY, 0-byte data)
[3] non-empty payload (7 bytes incl. NUL) + correct checksum -> accepted (control)
F5 PROBE: PASS
```

### F7 — OKAY remote-id validation (`f7_okay_arg1.ts`)

```text
[1] OKAY arg1=8 (host localId=1) -> AdbError 'local id' (rejected)
[2] OKAY arg1=1 (correct echo) -> success (control)
[3] OKAY arg1=0 (swapped args) -> AdbError 'local id' (rejected)
F7 PROBE: PASS
```

Driven through the real `adbRebootBootloader` with scripted banner reads, so
the OPEN localId on the wire is the genuine one.

### F2 — post-OPEN disconnect classification (`f2_domexception.ts`)

```text
[1] post-OPEN SecurityError -> AdbError 'ADB USB failure after OPEN (SecurityError)'
[2] post-OPEN InvalidStateError -> AdbError containing name
[3] post-OPEN NetworkError -> success (expected reboot disconnect)
[4] post-OPEN AdbError 'stream ended' -> success
[5] post-OPEN NoDeviceError -> success (allowlist)
[6] post-OPEN RangeError -> propagated unchanged
F2 PROBE: PASS
```

Allowlist confirmed narrow: exactly {NetworkError, NoDeviceError,
NotFoundError, AbortError} plus AdbError stream-ended/cancelled. SecurityError
and InvalidStateError surface as `AdbError("ADB USB failure after OPEN (<name>)")`
with the original name preserved — silent success is impossible. Foreign
(non-DOM, non-AdbError) errors propagate unchanged rather than being swallowed.

### F1 — timeout path (`f1_timeout.ts`)

```text
[1] timeout@30ms -> AdbError 'Timed out'; aborted=true; closed=true (ordered after abort)
[2] success path (banner then stream end) -> reboot reported; closed=true
[3] late-rejecting transfer -> timeout error in 33ms, no deadlock
F1 PROBE: PASS
```

Probe [1] asserts ordering: the abort signal fires while the read is in flight,
and `io.close()` runs strictly afterwards (macrotask yield in
`BufferedAdbPipe.close()` / `usbChunkIo.close()`), so WebUSB release cannot
reject against an outstanding transfer — the F1 leak is closed. Probe [3]
simulates a transfer that rejects late after abort: close is bounded, the
timeout error still wins, no deadlock.

## 5. Disclosure audit (C7)

- `README.md` L89-119: section **"Browser ADB key storage (private key at
  rest)"** — full private JWK incl. `d`, `p`, `q`, `dp`, `dq`, `qi`;
  unencrypted `localStorage` under **`guardtalk.webadb.rsa-jwk`**;
  `~/.android/adbkey` equivalence; XSS/local-profile threat model; clear
  instructions (`localStorage.removeItem(...)` + device-side revoke).
- `NOTICE` L32-38: **"Key-at-rest disclosure"** paragraph, same facts, points
  to README.
- Reality check: `wizard/adb-rsa.ts:13` `ADB_KEY_STORE_ID =
  "guardtalk.webadb.rsa-jwk"`; `localStorageKeyStore()` (L40-51) writes the
  exported private JWK via `storage.setItem`. Docs match implementation
  exactly. No overclaim found (future-work sentence about non-extractable
  CryptoKey is clearly labeled as future).

## 6. DEC-009 conformance (C8-C11)

- `src/types.ts:119`: `export const LIVE_FLASH_CLAIMED = false;` — sole
  assignment in the tree; consumed by `session.ts:150`,
  `orchestrator.ts:54`, asserted in `orchestrator.test.ts:19,71,89`.
- Gating intact: `wizard/session.ts` `executePlan()`/`lock()` call
  `assertDryRunOnly` (L179, L185) *and* `orchestrator.ts` enforces its own
  `assertDryRunOnly` (L76, L87, L98-102) → `LiveExecuteHoldError`.
- Only service string in `adb-session.ts:27` is `reboot:bootloader`. Grep of
  `adb-*.ts` for flash/unlock/lock/fastboot finds only user-facing prose
  ("hold volume-down for Fastboot", "Does not flash") — zero protocol commands.
- `index.html:32-35` retains the `data-dec="009"` HOLD banner.
- Repo-wide grep for affirmative live-flash claims: **none**. All hits are
  disclaimers ("A passing run is **not** a live-flash PASS",
  "**not attempted** — no live-flash PASS claimed").

## 7. Backend-report cross-check

Every factual claim in `TO_ARCHITECT_BACKEND.md` that is checkable from the
tree was re-derived independently: file/line anchors (pipe cap L19/L101-105,
checksum rule L49-53, allowlist L34-47, arg1 check L122-127, cancel/close
L37-43 + L66-80, usb signal plumbing L138-147/L149-165, README L89-119,
NOTICE L32-42) — all accurate. Suite counts match. No discrepancy found.

Advisories (non-blocking, no action required for this verdict):

1. `ultimate_critique` MCP tool is currently broken at the infrastructure
   layer (`python: not found` inside the MCP backend), so the Backend's
   91/100 could not be reproduced this session; `self_critique` works
   (QA run: 100/100 strict). Tooling availability issue, not a product defect.
2. The F4 cap check runs after `concatBytes`, so the transient buffer can
   reach `cap + chunk` before the throw. With the real WebUSB transport
   (`CHUNK = 4096`) the worst case is 1 MiB + 4 KiB — bounded and safe.

## 8. STOP

Deliverables: this file + `.agent-comm/inbox/TO_ARCHITECT_Q-WEBINSTALL-ADB-FIXES.md`.
Probe scripts live only under `/tmp/qa-probes/`. No product file edited.
No git commit/push. No live USB. QA stops at REVIEW.
