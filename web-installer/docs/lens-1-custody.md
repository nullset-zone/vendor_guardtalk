# Lens 1 — Key Custody / Material Egress (adversarial audit)

**Question:** can any private key byte, passphrase, or derived secret leave the browser tab?

**Date:** 2026-08-23 · **Mode:** READ-ONLY (no source file modified; this report is the sole write)
**Scope audited:** `routes/install/{early-steps,flash-runner,late-steps}.ts`, `routes/update/update-route.ts`,
`routes/recover/recover-route.ts`, `routes/verify-device/verify-route.ts`, `lib/keys/**`, `lib/avb/signer.ts`,
`lib/avb/pkmd.ts`, `lib/ui/**`, `lib/fastboot/**`, `lib/install-state/**`, `lib/cli-export/generator.ts`,
`wizard/**` (legacy ADB path), `test/*.ts`, shipped `dist/wizard/adb-rsa.js`.
**Binding refs:** PLAN.md §2 items 1–5, DECISION_LOG D-007 (custody), D-006 (CSP/no-network),
D-011 (sim-only execution), status.json `flashCapability` block, PHASE4-LENSES.md protocol.

---

## Gate -1 chain (transparency, Law 1/Law 10)

1. `mcp1_gate_enforcer(action=check, gateNumber=-1)` → **FAILED** (`missing: guardian_consulted, session_initialized`).
2. AGENTS.md fallback: `curl POST http://guardian.aegis.openstatestack.dev/v1/chat/completions` → **timeout after 10 s, 0 bytes** (Guardian proxy down).
3. `mcp1_ask_guardian` (governance-injected) → `[AEGIS GOVERNANCE COMPLIANT] … You may proceed.` with explicit warning
   *"Guardian Proxy not available - using local governance check"* (confidence 0.7, Law 5 referenced).
Audit proceeded on the local-fallback approval; recorded here per Law 10. This mirrors the outage posture already accepted in D-008.

---

## Findings summary

| ID | Sev | Where | One-line finding |
|----|-----|-------|------------------|
| F-HIGH-1 | HIGH | `routes/install/early-steps.ts:650` | Production flow-1 controller generates an `extractable:true` **private** CryptoKey (the "twin"); literal tripwire of audit item 2, heavily mitigated, untested. |
| F-MED-1 | MED | `wizard/adb-rsa.ts:74` (+`:40-51`,`:62-72`; wired by `wizard/adb-reboot.ts:28`) | Legacy wizard auto-persists a full RSA private JWK (incl. `d`,`p`,`q`) **plaintext, non-opt-in** in `localStorage` — violates D-007's letter; honestly disclosed; aggravated by missing CSP on `wizard/index.html`. |
| F-MED-2 | MED | `lib/keys/zeroise.ts:34-42` | `onPageHide` has **zero production callers** — the PLAN §2.4 / D-007 "zeroed on unload" clause is dead code. |
| F-MED-3 | MED | `lib/keys/import.ts:151-167`, `routes/install/early-steps.ts:686-692` | Imported private buffers (`n/e/d/p/q`) and their BigInt copies (`d` especially) are **never zeroised/scrubbed by any flow** and survive in results after signing; not console/DOM-reachable today, so MED with a defined escalation condition. |
| F-MED-4 | MED | `lib/keys/export-enc.ts:70-75`, `routes/install/early-steps.ts:649` | No passphrase policy floor (empty string accepted) on the encrypted-backup path — "passphrase ≥ policy" is unenforced. |
| F-MED-5 | MED | `routes/update/update-route.ts:262-267,529-534,547` | Update runner's flash gate trusts *asserted* machine state (`signedWithUserKey: true` hardcoded after reducer drive) instead of proving the actual `plan.vbmeta` bytes against the enrolled pkmd. |
| F-LOW-1 | LOW | `routes/install/early-steps.ts:649-674`, `test/route-install-early.test.ts` | `runGenerateFlow` — the custody-critical controller — has **no test coverage**, including no assertion that the re-imported handle is non-extractable. |
| F-LOW-2 | LOW | `routes/recover/recover-route.ts:315-319` | Stub wiring hands `flashPkmd` an empty `Uint8Array(0)` placeholder; inert today, worth a guard before real wiring. |

**Counts: BLOCKER 0 · HIGH 1 · MED 5 · LOW 3**

---

## 1. Sink inventory (network / storage / console / DOM / errors)

Method: ripgrep sweeps over `routes/**`, `lib/**`, `wizard/**`, `src/**`, `test/**` for
`fetch(`, `XMLHttpRequest`, `WebSocket`, `sendBeacon`, `document.cookie`, `localStorage/sessionStorage`,
`console.*`, `setAttribute/style/dataset`, `new URL(`, `URLSearchParams`, `location.*=` , `createObjectURL`,
`postMessage`, `serviceWorker`, `caches.open`; then **manual read of every hit** listed below.

### Network sinks — every `fetch` in scope

| Site | Carries key material? | Verdict |
|------|----------------------|---------|
| `wizard/hosted-channel.ts:36` (`fetch(url)`, url built `:11,:22-27` from allowlisted product → `../channels/<product>/{manifest.json,SHA256SUMS,files.txt}`) | No — public release artifacts only; product gated by `src/allowlist.ts:9-11` | Clean |
| `wizard/http-store.ts:15` (`fetch(\`${baseUrl}${name}\`)`, name validated `:11`) | No — release image bytes inbound only | Clean |

No `fetch`/XHR/WebSocket/`sendBeacon` exists anywhere under `routes/**` or `lib/**` (grep: only test-side
negative assertions at `test/route-install-early.test.ts:374`, `test/route-update.test.ts:507`,
`test/route-install-late.test.ts:668`, and the scan table in `test/keys.test.ts:175-183`). The `/install`
route family makes zero network requests; `connect-src 'none'` CSP is baked at
`routes/install/page.html:8-9` and emitted by `lib/claims/csp.ts:3-8`.

### URL / cookie / storage sinks

- `document.cookie`: zero hits repo-wide. Clean.
- `URLSearchParams`: only `routes/install/late-steps.ts:36-42` parsing `?sim=1` (boolean sim flag; reads, never writes key data to any URL). Clean.
- `serialize()` deep-link (`lib/install-state/machine.ts:230-252`): payload = `route, currentStep, completedSteps[, keyFlow]` — doc-comment and code both exclude material/fingerprints; enforced by `test/route-update.test.ts:516-518`. Clean.
- **`localStorage`: exactly one producer** — `wizard/adb-rsa.ts:74` writing the private ADB JWK (see F-MED-1). No route/lib code touches `localStorage`/`sessionStorage` (grep confirms; sweep tests forbid it in markup: `test/route-update.test.ts:513`).
- IndexedDB / `openDatabase` / Cache API / ServiceWorker / `postMessage`: zero hits.

### Console sinks

- Browser code (`routes/**`, `lib/**`, `wizard/**`): **zero** `console.*` calls (grep). The only `console.error` lives in the host-side Node CLI harness `src/cli.ts:13,38` (usage/errors; never key data; not a browser surface).
- The wizard's visible log (`wizard/main.ts:30-37` `logLine`) receives only status sentences; the ADB token-signing path (`wizard/adb-session.ts:63-96`) sends signature/public-blob packets over USB and throws fixed-string errors (`:93-95`). No private JWK reaches any log. **Audit item 6 clause 2: verified clean.**

### DOM attribute / style assignment

Full `setAttribute|style|dataset` inventory: aria/class/role attributes (`lib/ui/dialog.ts:42`,
`lib/ui/console.ts:39-49`, `lib/ui/chips.ts:30-34`), busy state (`wizard/main.ts:177`),
progress percentages (`lib/ui/progress.ts:68-72`). The only value-bearing attributes are
`data-full/data-truncated` (`lib/ui/sidebyside.ts:28-29`) and `data-fingerprint` elements
(`routes/install/early-steps.ts:543,856`; `routes/install/late-steps.ts:342`) — **hash/fingerprint values,
i.e. the designated display path**, always through `escapeHtml` (`lib/ui/escape.ts:12-19`).
Clean per PLAN §2.3.

### Error-message hygiene

Every thrown error in scope inspected: `AvbSignError/AvbVerifyError` (`lib/avb/signer.ts:43-44,71-75,118-122,160-181`),
`AvbPkmdError` (`lib/avb/pkmd.ts:23,40-88`), `PemParseError` (`lib/keys/import.ts:41-260` — labels, OIDs, lengths only),
`KeyExportError` (`lib/keys/export-enc.ts:112,147-176`), `AdbError` (`wizard/*` — packet names, var names),
`FastbootError` (verbatim bootloader FAIL text — device-controlled, not key-bearing).
No error interpolates key/passphrase bytes. Regression-pinned by `test/keys.test.ts:97-106,126-142`.
Clean.

### Designated display path integrity

Only `fingerprintFromJwk` (`lib/keys/fingerprint.ts:10-15`) and `pkmdFingerprint`
(`lib/avb/pkmd.ts:94-102`) produce displayed key-derived values — SHA-256 hex over **public** encodings.
`expectedFingerprintFromPublicJwk` additionally refuses JWKs carrying `d/p/q`
(`routes/verify-device/verify-route.ts:148-153`). Clean.

**Category verdict: no key/passphrase/derived-secret egress sink exists on the four-route surface;
the single storage egress is the legacy wizard ADB key (F-MED-1).**

---

## 2. Non-extractable handles

| Path | extractable | Evidence |
|------|-------------|----------|
| `lib/keys/generate.ts:23` (user key generation) | **false** (private) | `generateKey(KEY_ALGORITHM, false, …)`; pinned by `test/keys.test.ts:30-41` (`privateKey.extractable === false`) |
| `lib/keys/import.ts` | n/a — builds BigInt `PrivateMaterial`, creates **no** private CryptoKey; its `importKey` calls are PBKDF2 passphrase keys, `false` (`:223-229`) and AES-KW wrap keys, `false` (`:230-241`) | Clean |
| `lib/avb/signer.ts:247-253` | imports **public** verify keys, `ext:false` | Clean |
| `routes/install/early-steps.ts:655-661` (flow-1 re-import of signing handle) | **false** `["sign"]` | Clean — but see F-HIGH-1 for the transient twin that feeds it |
| `lib/verify/detached-sig.ts:47-53` | public release key, `true` (public-half extraction is harmless) | Acceptable |
| `wizard/adb-rsa.ts:62-71` | **true** (private, exported at `:72`) | Covered under F-MED-1 (legacy, disclosed, forced by raw-RSA ADB signing semantics — WebCrypto cannot perform the required raw `sig^d mod n` op, so `d` must be exported) |

### F-HIGH-1 — `extractable:true` private CryptoKey in a production flow (item-2 tripwire)

```650:650:vendor/guardtalk/web-installer/routes/install/early-steps.ts
  const twinPair = await crypto.subtle.generateKey(KEY_ALGORITHM, true, ["sign", "verify"]);
```

Evidence chain: twin generated `:650` → PKCS#8 exported `:651` → sealed into passphrase envelope `:654`
→ DER zeroised in `finally` `:671-673` → handle re-imported non-extractable `:655-661`. The pattern is
documented in-code (`:638-648`) and is the only way to satisfy both "encrypted backup of the SAME key"
(PLAN §1 step 3) and "handles are non-extractable" (`lib/keys/generate.ts:3-5`), i.e. it falls under
PLAN §2.1's sanctioned "transient memory buffers zeroed after use" clause. Mitigations are real but the
literal audit-item-2 tripwire fires on a **production-reachable** private key, and no test pins the
invariant that the *returned* handle is non-extractable (F-LOW-1).

**Fix (one sentence):** Keep the twin but shrink and prove the window — export→seal→re-import with the twin dropped immediately after export, and add a test asserting `result.privateKey.extractable === false` and `armoredBackup` decrypts to the same fingerprint.

*Architect note:* under the maximally literal reading of item 2 this is BLOCKER-class; graded HIGH because the key is transient, unpersisted, zeroised, and the surviving handle is non-extractable — cross-verify against `early-steps.ts:650-673` before upgrading.

---

## 3. Zeroise reachability

Live (production-invoked):
- `routes/install/early-steps.ts:672` — `zeroise(der)` in `finally` of `runGenerateFlow`. Reachable.
- `lib/keys/export-enc.ts:64-66,86-90` — passphrase encoding, salt, IV zeroised around the crypto awaits. Reachable.
- `lib/keys/import.ts:71-72,83-85,255-257,258-260` — DER and unwrapped PKCS#8 filled(0) on all exit paths. Reachable.

Dead / missing:
- **F-MED-2:** `onPageHide` (`lib/keys/zeroise.ts:34-42`) is exported and tested (`test/keys.test.ts:165-171`) but has **zero production callers** — grep over `routes|lib|wizard` finds none. PLAN §2.4 mandates "best-effort buffer fill(0) on step completion **+ pagehide**"; D-007 repeats it. Dead code ⇒ MED per audit rule.
- **F-MED-3:** Flow-level scrubbing never happens for flow-2 imports: `buildImported` (`import.ts:151-167`) returns owned `n/e/d/p/q` buffers; `signerMaterialFrom` (`early-steps.ts:686-692`) copies them into BigInts (`d` = private exponent, immutable and permanently unscrubbable in JS); `runImportFlow` (`:695-706`) returns all of it and **nothing in production ever calls `scrub()`/`zeroise()` on these** (`scrub` callers: tests only). Retention-after-signing is real; however the results live only inside closure scope of the not-yet-wired route shell (no global/module-state pinning exists today — `page.html:15` loads the module but no wiring file exists), so the "reachable from console/DOM ⇒ HIGH" condition is **not currently met**. Escalation condition recorded: any future wiring that stores `ImportedFlowResult`/`signerMaterial` on module or `window` state promotes this to HIGH.

**Fixes:** wire `onPageHide(() => { zeroise(activeMaterial.n/e/d…); })` at flow completion in the route shell; have `runImportFlow` consume-and-scrub `material` after `signerMaterialFrom`, and document that BigInt `d` retention is a known platform limit.

---

## 4. Opt-in persistence default OFF

- IndexedDB: **zero usage** anywhere in the project (grep: only the negative-assertion regexes in tests and docs). Default OFF trivially satisfied.
- The encrypted backup (`GTKEY-1` armor, `lib/keys/export-enc.ts:8-29`) is produced **only** inside `runGenerateFlow` after the user picks flow 1 and is additionally gated behind the explicit "I saved the encrypted key file" confirmation (`routes/install/early-steps.ts:531-539,584-606`); download happens via a user-clicked anchor (`:535`). Never auto-triggered. ✔
- KDF floor enforced: PBKDF2-SHA256 ≥600k iterations on write (`:75`) and re-checked on read (`:168-170`); pinned by `test/keys.test.ts:144-149`. ✔
- **F-MED-4:** no passphrase strength/length policy exists — `exportEncryptedPem(material, "")` succeeds; `runGenerateFlow(passphrase: string)` performs no check (`early-steps.ts:649`). "passphrase ≥ policy" (audit item 4) is unenforced.
  **Fix:** reject passphrases below a stated minimum (or a measured entropy check) in `exportEncryptedPem` before key derivation, mirroring the existing iteration-floor pattern.

---

## 5. GuardTalk-anchor impossibility (PLAN §2.5) — the audit spine

Provenance chain for the vbmeta actually flashed at step 6:

1. **Step-2 release artifacts never become the anchor.** `verifyRelease` (`routes/install/early-steps.ts:361-425`) consumes package/sums/sig and returns only a view-model + metadata; no vbmeta bytes cross from step 2 into steps 4–6 state. Release key verifies provenance only. ✔
2. **Step-4 output is USER-keyed, two ways:** `kind:"sign"` → `resignVbmeta(mode.img, mode.key)` where `mode.key` is the user's CryptoKey/KeyMaterial (`:804-828`); `kind:"import"` → accepted **only** after `verifyVbmetaAgainstKey(img, mode.expectedPkmd)` (`:830-837`), where `expectedPkmd` is derived from the *user's own public half* (`pkmdFromJwk(imported.publicJwk)` `:698` / `pkmdFromJwk(jwk)` `:718`).
3. **Byte-level identity check:** `verifyVbmetaAgainstKey` compares the embedded public key to the user's pkmd with `constantTimeEqual` **before** signature verification (`lib/avb/signer.ts:341-350`) — importing the untouched release vbmeta fails closed with "embedded public key does not match given key." No branch accepts a GuardTalk/release-signed image as anchor. ✔
4. **Flash order + enrolment:** user's pkmd is flashed FIRST to `avb_custom_key` (`routes/install/flash-runner.ts:140-144`), user-signed vbmeta(s) LAST (`:153-156`, contract doc `:38-44`); firmware/OS strictly ordered between (`:145-152`).
5. **Gates, defence in depth:** `canFlash` demands `signedWithUserKey` AND machine steps 2+4 completed (`lib/install-state/gates.ts:41-55`), and `runFlashPlan` re-evaluates the gate internally **before issuing any command** (`flash-runner.ts:130-134`); mismatch stops before ANY write (`test/route-install-late.test.ts:212-215,554+`).
6. **CLI export parity:** the offline script refuses to substitute any other key and aborts without self-exported material (`lib/cli-export/generator.ts:262-271`); anchors are signed with `$USER_KEY_PEM` and flashed last (`:283-289,361-367`).
7. **F-MED-5 (residual):** on `/install/update`, `runUpdateFlow` drives the reducer through `vbmeta-signed` (`update-route.ts:515`) **without executing the step-4 controller**, then hardcodes the gate input `{ signedWithUserKey: true }` (`:529-534`) and flashes caller-supplied `plan.vbmeta` bytes (`:547`) — the anchor-impossibility guarantee rests on caller discipline, not on proving those bytes against the enrolled pkmd. Simulated-only today (D-011) and the wired UI path does prove bytes, hence MED not HIGH.
   **Fix:** inside `runUpdateFlow`, derive `signedWithUserKey` from an actual `verifyVbmetaAgainstKey(plan.vbmeta.bytes, enrolledPkmd)` before opening the gate.

status.json binding (`status.json:18-22`): `implemented:true, liveFlashClaimed:false` matches code — execute/lock refuse anything but dry-run transport (`wizard/session.ts:200-204`), the wizard banner states the HOLD (`wizard/index.html:32-36`), and `LIVE_FLASH_CLAIMED` is surfaced honestly (`wizard/session.ts:149-151`, `wizard/main.ts:380`). ✔

---

## 6. Wizard legacy (ADB path)

- **Storage disclosure vs behavior:** `adb-rsa.ts` behavior — generate RSA-2048 (`:62-71`), export full private JWK (`:72`), persist under `"guardtalk.webadb.rsa-jwk"` (`:13,:74`) via default `localStorageKeyStore()` (`:40-51`), which `adb-reboot.ts:28` wires as the default store reachable from the wizard's "Reboot to Fastboot" button (`wizard/main.ts:264-273` → `session.ts:153-155` → `adb-session.ts:53`). Disclosure — `NOTICE:32-38` and `README.md:89-119` — describes exactly this, including `d,p,q,dp,dq,qi`, the XSS/profile-read threat, the revocation command, and the roadmap. **Disclosure matches behavior: PASS**, with the D-007-letter violation tracked as F-MED-1.
- **Token signing log-leak:** `authenticate()`/`signAdbToken` emit signature packets and the *public* Android-format key blob over USB (`adb-session.ts:76-92`, `adb-rsa.ts:101-114`); no private field is formatted into any string, log line, or error (`adb-session.ts:93-95` is fixed text). **PASS.**
- Shipped bundle parity: `dist/wizard/adb-rsa.js:38-47` matches source (same extractable generation + `store.set`), so the disclosure covers the deployed artifact too.
- Aggravator folded into F-MED-1: `wizard/index.html:3-8` ships **no CSP meta**, unlike the four new routes.

---

## 7. Test-side

- Fixtures are runtime-generated extractable twins (`test/keys.test.ts:253-274`, `test/route-install-early.test.ts:240-250`, `test/avb.test.ts:288,525`, `test/route-update.test.ts:292`) — permitted per audit item 7; no hardcoded real-looking PEMs, none committed.
- **No test logs key material**: `console.*` appears nowhere under `test/` (grep); tests instead *assert secrecy* — error-string hygiene (`test/keys.test.ts:97-106,126-142`), sink scans over `lib/keys` sources (`:175-195`), custody sweeps over emitted HTML with known-secret variants in 4 encodings (`test/route-install-early.test.ts:899-922`), markup sink sweeps (`test/route-install-late.test.ts:656-683`, `test/route-update.test.ts:498-521`), serialize minimality (`:516-518`), and private-marker sweeps on Builder-D pages (`test/route-verify-recover.test.ts:59-72`). **Verified clean; no LOW notes triggered.**

---

## Verified-clean register (method stated per category)

| Category | Verdict | Method |
|---|---|---|
| Network sinks on the 4-route surface | Clean | Grep + manual read of every hit (§1 table); CSP meta present at `routes/install/page.html:8-9` |
| Cookie / sessionStorage / IndexedDB / postMessage / SW | Clean | Zero-hit grep repo-wide |
| Console sinks in browser code | Clean | Zero `console.*` in routes/lib/wizard; host CLI exempt |
| Fastboot transcript cannot carry secrets | Clean | Payloads logged length-only (`lib/fastboot/client.ts:186-189`); clipboard copy gesture-guarded (`lib/ui/console.ts:103-130`) |
| DOM attributes/styles | Clean | Full setAttribute inventory; only fingerprint/hash values, escaped |
| Error messages | Clean | Every throw-site read; negative tests pinned |
| `generate.ts`/`import.ts` handle extractability | Clean | Code read + `test/keys.test.ts:30-41` |
| Display path = fingerprints only | Clean | Trace of `fingerprintFromJwk`/`pkmdFingerprint` call sites |
| Anchor impossibility on `/install` spine | Clean | 6-step chain trace (§5 items 1-6); tamper path fails closed |
| Opt-in persistence default | Clean (except passphrase floor, F-MED-4) | IndexedDB absent; backup double-gated behind explicit user actions |
| Wizard disclosure accuracy | Pass | Behavior-vs-NOTICE/README line-by-line match |
| status.json flashCapability consistency | Pass | Compared against `session.ts`/`main.ts`/banner |

---

## Severity counts

**BLOCKER: 0 · HIGH: 1 · MED: 5 · LOW: 3**

*Audited under Gate -1 local-fallback approval (remote Guardian down); all findings carry reproducible `file:line` evidence per PHASE4-LENSES.md cross-verification protocol.*
