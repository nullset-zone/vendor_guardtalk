# A-WEBINSTALL-EXTREME — Extreme Audit (WebUSB ADB reboot path)

| Field | Value |
|-------|--------|
| Task | `A-WEBINSTALL-EXTREME` |
| Role | AEGIS Auditor (read-only; not the Architect) |
| Timestamp (UTC) | 2026-08-21T06:59:00Z |
| Scope dir (read-only) | `vendor/guardtalk/web-installer/` |
| Depends on | Q-WEBINSTALL-DRYRUN-ONLY APPROVED (2026-08-20T17:25:00Z) |
| Verdict | **CONDITIONAL GO** (host/mocked analysis only; **never** a live-flash verdict) |
| Live-flash GO? | **NO** — no device attached; no live USB operation performed or claimed |

---

## 1. Gate -1

`ask_guardian` → `governanceStatus=compliant` ("You may proceed"; Guardian Proxy
fallback). `gate_enforcer` Gate -1 **PASSED** (guardian_consulted,
session_initialized). Read-only mode: no file under scope edited; the only write
is this report.

## 2. Findings

| ID | Sev | Summary (file:line evidence) | Fix |
|----|-----|------------------------------|-----|
| F1 | **HIGH** | Timeout does not abort USB: `adb-reboot.ts:30-37` races `adbRebootBootloader` against a timer, but on timeout the pending `transferIn` is never cancelled and the device is never `close()`d — the underlying `openAdbUsb` device handle leaks and the tab keeps a claimed ADB interface. `finally` closes the *pipe*, whose `close()` only `releaseInterface`+`close()` the device — which WebUSB rejects while a transfer is in flight, so the leak persists. | Add `abort`/`cancel` to `AdbChunkIO`; on timeout call it before `pipe.close()`, or wrap `transferIn` in `Promise.race` with a rejection that triggers `device.close()`. |
| F2 | **HIGH** | `waitForRebootAck` swallows all `DOMException`s: `adb-session.ts:91-93` returns success for *any* DOMException (incl. `InvalidStateError`, `SecurityError`, `DataError`), so real USB failures after `OPEN` are reported as "reboot sent". The `AdbError` regex (`:88`) also matches the literal word "transfer" in unrelated messages. | Match on `err.name` (`NetworkError`, `NoDeviceError`, `AbortError`) only; rethrow everything else. |
| F3 | **MEDIUM** | Private key stored unencrypted in localStorage: `adb-rsa.ts:40-51,72-74` persists the full RSA JWK (incl. `d, p, q, dp, dq, qi`) under `guardtalk.webadb.rsa-jwk`. XSS or a local-machine read exfiltrates the ADB host key. Not disclosed in README/NOTICE/index.html. Risk is bounded (ADB-debugging trust only; same model as `~/.android/adbkey`), but it must be documented. | Document in README + wizard note; prefer non-extractable `CryptoKey` + IndexedDB, or offer a session-only key option. |
| F4 | **MEDIUM** | `readExact` unbounded memory amplification: `adb-pipe.ts:59-66` keeps concatenating attacker/device-controlled chunks into `this.leftover` with no cap while waiting to reach `length`. `length` is header-bounded (≤4096) so a single packet is safe, but a hostile device streaming data with `readPacket` never called can grow the buffer without limit. | Cap `this.leftover.length` (e.g. 1 MiB) and throw `AdbError` beyond it. |
| F5 | **MEDIUM** | `readPacket` accepts `data_length` > 0 with zero checksum: `adb-pipe.ts:44` treats `check === 0` as "skip verification" for any payload. AOSP sends checksum 0 only for zero-length CNXN/AUTH payloads. A 4096-byte corrupted/hostile payload passes integrity. | Only skip when `fields.length === 0 && fields.check === 0`. |
| F6 | **MEDIUM** | Test asserts signature flow but never verifies the signature: `test/adb-reboot.test.ts:81-91` accepts any 256-byte AUTH_SIGNATURE blob; RSA/PKCS#1 math is untested (no known-answer test). A broken `signAdbToken` would still pass the suite. | Add a KAT: fixed key/token → expected signature bytes; or verify with `crypto.subtle.verify` RSASSA-PKCS1-v1_5/SHA-1. |
| F7 | **MEDIUM** | `fakePhone` OKAY arg1 uses literal `1` instead of `open.arg1`: `test/adb-reboot.test.ts:97`. The host never validates `OKAY.arg1 === LOCAL_ID`, and the test masks that gap — remote-id checking is untested and unenforced. | Assert `open.arg1 === 0`, have the phone echo `open.arg0`, and add host-side validation in `adb-session.ts`. |
| F8 | **LOW** | `A_VERSION = 0x01000000` (`adb-packet.ts:13`): AOSP's current `A_VERSION` is `0x01000001` (protocol v1.1, adds `A_WRNXN`/`A_AUTH_RSAPUBLICKEY` semantics used by adbd ≥ 2021). Sending v1.0 is interoperable (adbd downgrades), and `adb-session.ts:34` correctly puts `MAX_PAYLOAD` in arg1, but the code neither checks nor records the version the *device* returns. | Acceptable for `reboot:bootloader`; consider parsing `banner.arg0` and warning on unknown versions. |
| F9 | **LOW** | `adb-usb.ts:139` returns a live view of the WebUSB transfer buffer (`new Uint8Array(result.data.buffer, …)`). Safe today because `readExact` copies via `concatBytes`/`slice`, but any future zero-copy reuse would corrupt packets. | `slice()` the chunk in `readChunk` for defense-in-depth. |
| F10 | **LOW** | Device disconnection mid-session surfaces as raw `AdbError("ADB USB stream ended")` (`adb-pipe.ts:63`) or untranslated DOMExceptions from `transferOut`/`transferIn` (`adb-usb.ts:128-140`); only the picker error path (`adb-usb.ts:156-164`) gets friendly text. UX-level, not security. | Map `NoDeviceError`/`NetworkError` in `usbChunkIo` to user-facing AdbError text. |
| F11 | **LOW** | NOTICE claims "does not bundle a third party ADB library" (`NOTICE:28-30`) — **verified true** for the ADB path, but NOTICE does not mention the private-key-at-rest behavior it ships (see F3). | Add one line to NOTICE/README about the localStorage key. |
| F12 | **INFO** | `adb-rsa.ts:101-114` `androidPublicKey` is a correct Android-style public-key blob: len=2048 bits, `n0inv = -n⁻¹ mod 2³²` via Newton iteration (`:130-137`, verified: 5 iterations ⇒ 32-bit inverse), `rr = 2⁴⁰⁹⁶ mod n` little-endian, e=65537 LE, trailing `\0`. Matches `adbd`'s expected format. | None. |
| F13 | **INFO** | `modPow` (`adb-bytes.ts:63-75`) is textbook square-and-multiply — constant-time is not expected for a browser ADB host key; no blinding. Acceptable for this threat model. | None. |
| F14 | **INFO** | `checksum` (`adb-packet.ts:24-30`) sums bytes mod 2³² — matches ADB spec (`sum & 0xffffffff` then `>>> 0`). Encode/decode magic `command ^ 0xffffffff` both sides verified (`:45`, `:62-65`). | None. |

**BLOCK: 0 · CRITICAL: 0 · HIGH: 2 · MEDIUM: 4 · LOW: 4 · INFO: 4**

## 3. Per-module review notes

### `wizard/adb-bytes.ts`
Correct helpers. `bigIntToBytesLe/Be` truncate silently on oversize input (callers
pass fixed sizes; `padPkcs1Type1` guards payload size). `base64UrlToBytes`
handles unpadded input. No randomness here (see auth below).

### `wizard/adb-packet.ts`
Constants verified byte-for-byte: `CNXN=0x4e584e43`, `AUTH=0x48545541`,
`OPEN=0x4e45504f`, `OKAY=0x59414b4f`, `CLSE=0x45534c43` — little-endian encodings
of ASCII "CNXN"/"AUTH"/"OPEN"/"OKAY"/"CLSE", matching
`system/core/adb/protocol.txt`. Header 24 B = 6×u32 LE (cmd,arg0,arg1,len,check,
magic). `decodeHeader` validates length ≥ 24 and the magic complement; it does
**not** validate that `command` is a known word (unknown commands are rejected
upstream in `adb-session.ts:53-55` — acceptable). `MAX_PAYLOAD=4096` is the
classic ADB chunk size. See F5 (checksum-0 skip), F8 (version).

### `wizard/adb-rsa.ts`
2048-bit RSASSA-PKCS1-v1_5/SHA-1 — exactly what adbd requires. `signAdbToken`
enforces 20-byte tokens (`:89-92`, matches adbd's `TOKEN_SIZE = SHA_DIGEST_LENGTH
= 20`), builds `DigestInfo{SHA-1} || token` with the correct DER prefix
(`3021300906052b0e03021a05000414`), applies EMSA-PKCS1-v1_5 type-1 with ≥8 bytes
of 0xFF (`:116-128`), signs via `modPow(m, d, n)`, outputs 256 B BE. **Randomness:
none consumed by the implementation itself** — keygen uses `crypto.subtle.
generateKey` (WebCrypto CSPRNG). No `Math.random` anywhere in the tree (rg
verified). Key storage: see F3. `parseJwk` fails closed on non-string `n`/`d`.
Corrupt stored key → caught in `loadOrCreateAdbKey` (`:56-60`) → regenerate. No
key material is ever logged: error strings contain only lengths/labels; rg found
zero `console.*` in `wizard/` (only `src/cli.ts` prints plan text).

### `wizard/adb-pipe.ts`
Header/payload reassembly via `readExact` is correct against USB short transfers
(4096 B chunks reassembled until `length` satisfied; excess retained in
`leftover`). `writePacket` splits header/payload into two transfers — legal
(ADB is a byte stream over bulk endpoints) though two `transferOut` calls per
packet is slightly wasteful. Bounds: `fields.length > maxPayload` rejected before
allocation (`:39-41`) — **no attacker-controlled oversized allocation**. See F4
(leftover growth), F5 (checksum-0).

### `wizard/adb-session.ts`
Flow: CNXN(host::) → loop ≤8 packets → AUTH TOKEN → AUTH SIGNATURE(sig) →
(next token) → AUTH RSAPUBLICKEY(pubkey) → … → CNXN → OPEN(local-id-1,
`reboot:bootloader\0`) → wait OKAY/CLSE. arg0/arg1 usage: CNXN arg0=version,
arg1=max-data (correct); OPEN arg0=local id, arg1=0 (correct — remote id assigned
by device); AUTH SIGNATURE/RSAPUBLICKEY arg0=type, arg1=0 (correct). The
8-iteration bound is a reasonable liveness cap; the final error tells the user to
accept the debugging dialog. `waitForRebootAck` treats OKAY **or** CLSE as
success — CLSE after OPEN is a valid adbd response when the service completes
immediately; reboot may already be in flight. See F2 (DOMException swallow).

### `wizard/adb-usb.ts`
Interface match is strict (class 255 / subclass 66 / protocol 1, bulk IN+OUT),
matching the standard ADB interface. `claimAdbInterface` iterates configurations,
selects, claims; claim failure → actionable `adb kill-server` message. Status
checks on both transfer directions fail closed (`status !== "ok"` → AdbError).
Picker cancellation (`NotFoundError`) is translated, not swallowed. See F1/F9/F10.

### `wizard/adb-reboot.ts`
`withTimeout` is a correct `Promise.race` + `clearTimeout` (no unhandled
rejection: the loser promise's rejection is delivered via the race). 90 s budget
covers the on-screen "Allow USB debugging" prompt. But see F1: the race does not
propagate cancellation into the in-flight transfer; `finally { pipe.close() }`
swallows interface-release errors by design (device may have rebooted) — which
also masks F1's leak. `openFromPicker` fails closed with a script fallback hint
when WebUSB is absent. Doc comment (`:19-22`) correctly scopes the feature:
"Does not flash."

### Wiring: `session.ts` / `main.ts` / `index.html`
`session.rebootToFastboot()` (`session.ts:153-155`) is a pure passthrough to
`rebootAndroidToBootloader` — it touches no transport, no plan, no gating state.
`executePlan()`/`lock()` (`session.ts:178-188`) retain `assertDryRunOnly` +
`assertCanFlash/assertCanLock`, untouched by this feature. `main.ts:167-176`
binds `btn-reboot-fastboot` → `wizard.rebootToFastboot()` with `runAction` error
logging; button disabled unless `webUsbAvailable()` (`main.ts:41`). `index.html`
documents the flow (USB debugging, `adb kill-server`, first-use dialog) and keeps
the DEC-009 HOLD banner (`data-dec="009"`, lines 32-36). The reboot button is
**not** gated behind channel load — intentional (works on stock Android before
any channel is chosen) and harmless: `reboot:bootloader` cannot flash or lock.

## 4. DEC-009 / DEC-007 non-regression — INTACT

- `LIVE_FLASH_CLAIMED = false` constant unchanged: `src/types.ts:119`; returned
  by `InstallWizard.claimsLiveFlash()` (`session.ts:149-151`) and
  `FlashOrchestrator.claimsLiveFlash()` (`orchestrator.ts:53-55`); asserted in
  tests ok 11, plus `test/orchestrator.test.ts:19,71,89`. Only assignment in tree.
- `executePlan()` double-gated: `session.assertDryRunOnly` (`session.ts:179,200-204`)
  **and** `orchestrator.assertDryRunOnly` (`orchestrator.ts:76,98-102`); `lock()`
  likewise (`session.ts:184-188`, `orchestrator.ts:86-96`). Live mode →
  `LiveExecuteHoldError` (tests ok 18, ok 19).
- The ADB path sends only `reboot:bootloader` (`adb-session.ts:27,39`). No flash,
  no `flashing unlock/lock`, no fastboot commands exist anywhere in `adb-*.ts`.
  `rebootAndroidToBootloader` cannot reach the orchestrator.
- DEC-007 wording preserved: dev/unlocked banners in `index.html:22-26`,
  `main.ts:202-203`; no locked-verified-boot claim added by this feature.

## 5. Supply chain / licensing (DEC-005)

- **No third-party ADB library**: `wizard/adb-*.ts` are the only ADB
  implementations in the tree; rg for `adb` across `src/`, `wizard/`, `test/`
  shows no imports beyond `./adb-*.js` and `../src/errors.js`. Lockfile packages:
  typescript, tsx, @types/node + esbuild/get-tsconfig/resolve-pkg-maps/fsevents/
  undici-types (dev graph only). No `android-fastboot`, no zip.js, no pako.
- **NOTICE truthful**: `NOTICE:28-30` claim verified as above; dev-dep pins match
  `package-lock.json` (typescript 5.7.3, tsx 4.19.3, @types/node 22.10.5). The
  "intended, not installed" android-fastboot note remains accurate.
- **No GrapheneOS verbatim copy**: rg of `wizard/` for `grapheneos` (case-insensitive)
  matches only the *disclaimer* phrases "Not/This channel is not
  GrapheneOS-equivalent locked verified boot" — required DEC-007 labeling, not
  GOS copy. No `web-install.js`, `fastboot.min`, "easiest method", or GOS lede
  text anywhere in the product tree. UI text is original GuardTalkOS prose.

## 6. Test verification (observed, not assumed)

Environment: Node **v22.12.0** at `/home/openstatestack/.local/node/bin` (not on
default PATH; auditor exported it). Tooling **was available** — results below are
real runs.

| Command (cwd `vendor/guardtalk/web-installer`) | Result |
|------------------------------------------------|--------|
| `npx tsc --noEmit` | exit 0 (`TSC_EXIT=0`) |
| `npx tsc -p tsconfig.wizard.json --noEmit` | exit 0 (`WIZARD_TSC_EXIT=0`) |
| `npx tsx --test test/adb-reboot.test.ts test/wizard-gating.test.ts` | **# tests 20 · # pass 20 · # fail 0** (TAP, exit 0) |
| `npx tsx --test test/*.test.ts` (full suite) | **# tests 49 · # pass 49 · # fail 0** (TAP, exit 0) |

Test honesty review:

- `adb-reboot.test.ts` asserts real protocol behavior through a byte-exact
  in-memory USB loop (`linkedIo` + `fakePhone`): CNXN banner, AUTH SIGNATURE then
  RSAPUBLICKEY ordering, `reboot:bootloader\0` service string, fail-closed
  without WebUSB (ok 7). Not vacuous — the fake phone decodes packets with the
  same `BufferedAdbPipe`, so framing is exercised both directions.
- Gaps (filed F6, F7): signature bytes never verified; `OKAY` remote-id not
  checked; no malformed-header / bad-checksum / oversized-`data_length` hostile
  packet tests; no timeout-path test (F1 untested).
- `wizard-gating.test.ts` asserts the DEC-009 backstops concretely: live-mode
  `executePlan`/`lock` reject with `LiveExecuteHoldError` (ok 18/19),
  lock-before-complete backstop (ok 12), `claimsLiveFlash() === false` (ok 11),
  HTML carries `data-dec="009"` / "Live Flash/Lock are HOLD" (ok 17). Not vacuous.

**No live-device test exists or ran. A green suite is not a live-flash PASS.**

## 7. Verdict

**CONDITIONAL GO** — host/mocked analysis only.

The WebUSB ADB reboot path is protocol-correct against AOSP `protocol.txt`
(magic words, checksum, header layout, arg0/arg1 semantics, 20-byte token
signing, Android pubkey blob), fails closed on missing WebUSB, and does not
touch the flash/lock paths. DEC-009 HOLD and `LIVE_FLASH_CLAIMED=false` are
intact; no GOS copy; no third-party ADB lib; NOTICE accurate on that point.

Conditions (fix before or with the next wave, none block dry-run-only shipping):
1. F1 — make the timeout actually abort the transfer / close the device.
2. F2 — narrow the `DOMException` swallow in `waitForRebootAck`.
3. F3 — disclose the localStorage private-key-at-rest in README/NOTICE (or move
   to non-extractable key storage).
4. F4/F5 — cap `leftover` growth; only skip checksum for zero-length payloads.

HOLD unchanged: live flash, live lock, browser E2E, any live-USB claim. This
audit performs and endorses **no** live-device operation.

## 8. STOP

Deliverable: this file only. No other file created, edited, or reverted. No git
commit. No live USB. Gate -1 passed at start; auditor stops at REVIEW.
