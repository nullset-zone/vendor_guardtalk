# GuardTalkOS WebInstaller — PLAN.md

> Phase-1 synthesis · 2026-08-22 · sources: build prompt (#5), Executive Summary v1.0 (#3),
> repo survey ([Reader C](../../.agent-comm/inbox/) digest), first-hand `external/avb/avbtool.py`
> analysis. Binding refs: KEY MODEL §KEY, FLOW §FLOW, DECISION_LOG D-001…D-013,
> QUESTIONS_FOR_HUMAN Q-01…Q-14.

## 0. Physical layout (D-013)

Extend `vendor/guardtalk/web-installer/` into a statically-exported multi-route site:

```
vendor/guardtalk/web-installer/
├── routes/install/            → /install            (steps 0–9)
├── routes/update/             → /install/update     (steps subset, no generate)
├── routes/verify-device/      → /install/verify-device
├── routes/recover/            → /install/recover
├── lib/
│   ├── avb/                   parser.ts · signer.ts · pkmd.ts · descriptors.ts
│   ├── fastboot/              usb.ts · client.ts · sparse.ts · simulated-device.ts
│   ├── keys/                  generate.ts · import.ts · export-enc.ts · fingerprint.ts · zeroise.ts
│   ├── verify/                sums.ts · detached-sig.ts · side-by-side.ts
│   ├── claims/                Hardening / ProtectionLimit / LineageNote components + claim lint
│   └── install-state/         machine.ts (no auto-advance) · steps.ts
├── status.json                installer: alpha · key-custody: alpha (+ RELEASE_STATE/PRE_LAUNCH flags)
└── DECISION_LOG.md · QUESTIONS_FOR_HUMAN.md · PROGRESS.md · ARCHITECTURE.md · SECURITY.md
```

Build: plain `tsc -p tsconfig.routes.json` + static emit; CSP via meta tag per route
(`default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'`).
Flags: `RELEASE_STATE=alpha`, `INSTALLER_STATE=alpha`, `PRE_LAUNCH=true`, `ONION=true`.

## 1. Step state machine (`/install`, binding FLOW)

Steps are explicit user-advanced only. Back always available. Any mismatch ⇒ flow STOPS at that
step (tripwire red + reason in words); no bypass path exists in code.

| # | Step | Advance condition (code-enforced) | Stop conditions |
|---|------|-----------------------------------|-----------------|
| 0 | Before you start | CTA "I understand — begin" clicked | — |
| 1 | Get release over Tor | 3 files picked (package, SHA256SUMS, SHA256SUMS.sig) via file inputs | — |
| 2 | Verify release | `SHA256SUMS` parses; every package hash matches; `SHA256SUMS.sig` verifies against GuardTalk release-key fingerprint placeholder | any byte mismatch / bad signature ⇒ STOP here |
| 3 | Your key | One of 3 flows chosen (equal cards, none pre-selected). Flow 1: fingerprint shown, last-8 typed back correctly, encrypted PEM download confirmed saved. Flow 2: PEM imported (+passphrase if encrypted), fingerprint derived. Flow 3: descriptor set + avbtool command exported; signed vbmeta re-imported AND verified against its public key | fingerprint retype wrong ×∞ (retry allowed, never skipped) |
| 4 | Sign the release | vbmeta re-signed locally (flow 1/2) or imported+verified (flow 3); signing algo + key fingerprint + new vbmeta digest displayed mono | chain descriptor present but partition layout unknown ⇒ STOP + `// confirm partition layout` (Q-07) |
| 5 | Connect device | WebUSB pairing OK; `getvar product` ∈ {tokay, rango} and == release target; lock state read; OEM-unlock guided incl. second data-wipe warning acknowledged | product mismatch ⇒ STOP before ANY write |
| 6 | Flash | ordered: `flash avb_custom_key avb_pkmd.bin` → factory bootloader/radio/boot/vendor_boot/dtbo → GuardTalkOS system/system_ext/product/vendor → user-signed vbmeta(s); per-partition mono progress | any fastboot FAIL ⇒ STOP, verbatim output shown |
| 7 | Lock | `flashing lock` + on-device confirmation acknowledged; custom-OS boot state + key fingerprint explained | — |
| 8 | First boot & verify | user TYPES boot-screen fingerprint; compared to enrolled public-key fingerprint | mismatch ⇒ STOP "do not use this device — it is not running what you signed" + recovery link |
| 9 | Keep the key | closing screen; sentence: "GuardTalk cannot update this phone. Only you can." | — |

Route variants (D-001…D-003): `update` = [1,2,3(flows 2/3 only, generate hidden w/ reason),4,5(no unlock),6,8,9];
`verify-device` = [5(read enrolled key where bootloader exposes it),8(guided compare)];
`recover` = honest unlock-wipes path, stated plainly.

## 2. Key-custody contract (binding, testable)

1. Key material exists ONLY as: non-extractable `CryptoKey` handles (generate/import flows), or
   transient memory buffers zeroed after use. Opt-in encrypted persistence (IndexedDB, passphrase-
   encrypted, off by default) is the sole exception.
2. Sink scan: no key/passphrase/derived secret may reach fetch/XHR/WebSocket, URL, cookie,
   localStorage/sessionStorage, console/log lines, DOM attributes/text except through the
   designated display path (fingerprint only — public half), error messages, or crash/report paths
   (which do not exist — no telemetry).
3. Display rule: UI shows fingerprints/hashes (SHA-256 of pkmd encoding), never private material;
   all mono, selectable, copy-on-click.
4. Zeroise: best-effort buffer fill(0) on step completion + pagehide; WebCrypto handles GC'd.
5. GuardTalk-anchor impossibility: flashing requires the USER-signed vbmeta produced from the
   user key in-step 4; no code path accepts a GuardTalk-signed vbmeta as boot anchor; release key
   verifies provenance only (step 2).

## 3. Module interfaces (Phase-2 contracts)

```ts
// lib/avb/parser.ts
parseVbmeta(img: Uint8Array): VbmetaImage          // header(256B,'AVB0') + auth + aux blocks
interface VbmetaImage { header; descriptors: Descriptor[]; publicKey?: Uint8Array; /* … */ }

// lib/avb/signer.ts — parity-tested vs external/avb/avbtool.py
resignVbmeta(img: Uint8Array, key: CryptoKey|KeyMaterial): Promise<Uint8Array>
// SHA256_RSA4096 (alg id 2): sign(authBlock||auxBlockSizeBE64?) per avbtool sign() — exact
// recipe fixed by Reader-B digest §B; PKCS1-v1.5 pad 0x00 0x01 FF*458 00 || DER{3031300d…0420}

// lib/avb/pkmd.ts — avb_pkmd.bin encode/decode/fingerprint
encodePkmd(pub: {n: bigint; e: 65537}): Uint8Array // !II(numBits,n0inv=2^32−n⁻¹ mod 2^32) ‖ n ‖ rr=n² mod N  → 1032B
pkmdFingerprint(pkmd: Uint8Array): string          // "SHA256_1032B" hex, mono display

// lib/fastboot/client.ts
class FastbootClient { getvar(v): Promise<string>; flash(part, data): AsyncIterable<Progress>;
  erase(part); flashingUnlock(); flashingLock(); reboot(target?); raw(cmd) }
// transport: WebUSB (Chromium-only) or SimulatedDevice; sparse chunking via lib/fastboot/sparse.ts

// lib/keys — generate(RSA-4096, RSASSA-PKCS1-v1_5, SHA-256, extractable:false)
// importPem(pem, pass?) · exportEncryptedPem(key, passphrase) [PBKDF2-SHA256 ≥600k iter fallback, Q-09]
// derivePkmdFromHandle(handle) via exported SPKI→modulus extraction

// lib/verify — parseSha256Sums(text) · verifyDetached(sig, sums, releasePubJwkPlaceholder)
// SideBySide<T> model {expected, actual, match} rendered everywhere comparisons happen

// lib/install-state/machine.ts — pure reducer; transition(stepA→stepB) legal ONLY via named
// user actions; serialize() for deep-linking; NO timers advance state
```

## 4. Test matrix (CI gates; all simulated — D-011)

| Suite | Gate |
|---|---|
| unit: parser/signer/pkmd/descriptors/sums/sig/state machine | tsc + tsx --test green |
| reference-avbtool parity | python3 runs external/avb/avbtool.py on fixture vbmeta (channels/tokay/vbmeta.img) ; our parser output ≡ avbtool parse; our resign ≡ avbtool -o byte-for-byte on same key/input |
| pkmd parity | our encodePkmd ≡ avbtool extract_public_key output (channels/*/avb_pkmd.bin fixtures) |
| tamper matrix | flip 1 byte each: package / SHA256SUMS / .sig / vbmeta / product string / boot-screen fingerprint ⇒ stop at correct step with correct reason (6 cases) |
| key-leak scan | grep every sink (fetch/url/storage/log/DOM attr/error) over built bundles + runtime proxy harness; zero hits |
| no-connect | headless load of /install route with request log; ZERO requests after load (incl. fonts/scripts off-origin) |
| claim lint | forbidden phrases (automatic update / OTA / push / secure-safe-protected without mechanism / Install now / Easy / Automatic / one-click) fail build |
| generate-hidden lint | /install/update bundle contains no reachable generate-flow entry |
| a11y | WCAG 2.1 AA checks; step rail keyboard-operable; mono values selectable; chips not colour-only |
| E2E simulated device | first install / update / verify-device / recover — scripted SimulatedDevice, full happy path + stop paths |
| CLI export equivalence | generated command sequence mirrors browser steps 1:1 (same order, same args, same files) |

## 5. Copy & styling contract (per STYLING block)

Obsidian ground; mono step rail + console; signal green ONLY for VERIFIED states + primary next
step; caution for alpha/pending; tripwire only for failures — never decorative, never CTA. Every
chip carries its word (never colour-only). Headlines are sentences with full stops; protective
verbs only. Key diagram = three-node static SVG with text equivalent (your private key stays here /
your public key goes into the phone / GuardTalk's release key proves the build, not the boot).
Posture pill: `◢ offline · your key · alpha`. Tor Browser honesty statement + CLI export as
first-class equal path. `<LineageNote>` credits upstream practice (Q-12 draft wording).
Every limit linked to `/threat-model`: firmware/baseband beneath AVB, compromised signing machine,
coercion, Gateway network defence. No auto-advance anywhere; success is calm (no confetti).

**Status:** copy phase BLOCKED pending Q-01..Q-03 identity sources; structure/copy drafts proceed
with placeholders marked `// confirm` and are re-linted when sources arrive.

## 6. Open questions

Tracked exclusively in QUESTIONS_FOR_HUMAN.md (Q-01…Q-14). Nothing invented around.
