# Lens 4 — Byte Exactness Audit (AVB + fastboot protocol)

> READ-ONLY adversarial audit · 2026-08-23 · Auditor: Lens-4 subagent (ox-alpha)
> Scope: `lib/avb/**`, `lib/fastboot/**`, `routes/install/flash-runner.ts`
> Reference truth: `external/avb/avbtool.py` (AOSP avbtool v1.3) — every cited line re-read this session,
> none trusted from comments. Secondary: `docs/research/READER-B-AVB-FASTBOOT.md`.
> Question: *would the bytes produced and commands issued be exactly right on real silicon?*
>
> Method: full code read of every in-scope module; line-by-line re-derivation against
> avbtool.py; empirical execution of `test/avb.test.ts` (17/17 pass, **0 skipped** — python3 +
> openssl present, parity genuinely ran `python3 external/avb/avbtool.py make_vbmeta_image /
> extract_public_key` and the byte-for-byte resign comparison held), `test/fastboot.test.ts`
> (21/21), `test/route-install-late.test.ts` + `test/adb-reboot.test.ts` (35/35); plus two
> purpose-written probes (splitChunks boundary math; sparse-chunk × max-download-size interaction
> against SimulatedDevice). Gate −1 consulted and passed before start (session record).

---

## Verdict

**The AVB byte path is production-exact**: digest input, EMSA-PKCS1-v1_5 EM, raw-RSA op, auth-block
repack, release-string field, pkmd encoding and descriptor codecs are byte-for-byte equivalent to
avbtool, proven both by re-derivation and by live parity execution (D-014's fix independently
confirmed correct — see §D below). **No blocker found in the signing path.**

**The fastboot transport layer has three HIGH-severity gaps that will surface on real hardware**:
`max-download-size` is parsed, clamped and plumbed but **never fetched from the device**, and the
sparse-image expander produces payloads that defeat the chunker entirely — together these mean the
first large OS image either fails mid-flash or (sparse case, reproduced empirically) writes a
**silently corrupted partition**. INFO-packet handling is also asymmetric and will spuriously abort
on protocol-conformant bootloaders that emit INFO around download/flash.

Flash ORDER (PLAN §1.6) is correctly enforced: avb_custom_key FIRST → firmware → OS → vbmeta LAST;
no reorder path exists.

---

## Findings

| # | Sev | Location | Issue | One-sentence fix |
|---|-----|----------|-------|------------------|
| H1 | HIGH | `lib/fastboot/client.ts:100-116`, `lib/fastboot/protocol.ts:121-131`, `routes/install/flash-runner.ts:67-68,117-119` | `maxDownloadSize` is optional everywhere and **no code path ever calls `getvar:max-download-size`** (grep: zero call sites); `runFlashPlan` forwards only what a caller supplies, and no caller supplies it — so real flashes default to ONE unchunked `download:` of the whole image, which any real bootloader rejects once the image exceeds its budget (tokay channel ships system.img = 928 MB). | Have the runner fetch `getvar:max-download-size`, parse it with `parseMaxDownloadSize`, and pass the value into every `flashOne` (failing closed when the var is absent). |
| H2 | HIGH | `lib/fastboot/sparse.ts:95-172`, `lib/fastboot/client.ts:105` | Sparse expansion runs BEFORE size chunking, so one expanded RAW/FILL chunk larger than `max-download-size` is re-split by `splitChunks` into multiple `download:`+`flash:` pairs of the SAME partition — on real bootloaders each `flash:` restarts the partition write at sector 0, so later chunks overwrite earlier ones (empirically reproduced: 8192-byte RAW chunk @ mds 4096 ⇒ device stored 8192 B but wrote bytes 0–4095 twice). | Expand sparse images directly into `≤maxDownloadSize` transfer units consumed by a streaming writer (or reject sparse images with a visible STOP until supported end-to-end). |
| H3 | HIGH | `lib/fastboot/client.ts:150-163` | `expectKind` reads exactly ONE packet and never drains INFO, unlike `readTerminal` (:169-178): a protocol-conformant bootloader emitting `INFO…` before `DATA…` (after `download:`) or before `OKAY` (after `flash:`) causes a spurious `ProtocolError: expected DATA, got INFO…` and aborts the install. | Loop in `expectKind`: log-and-drain `INFO` packets until `DATA`/terminal arrives, keeping FAIL → `FastbootError` translation. |
| M1 | MED | `lib/fastboot/client.ts:131-137` | When the device answers `download:` with a smaller `DATA` than requested, the mismatch throws generic `ProtocolError`, discarding the verbatim-text guarantee the module promises for device-sourced failures. | Wrap the mismatch into `FastbootError`-style messaging carrying the announced size and the bootloader's prior INFO text, or treat it as a FAIL-class abort with verbatim transcript preserved. |
| M2 | MED | `lib/fastboot/simulated-device.ts:166-185` | Simulator semantics ("consecutive same-partition flash:s append") institutionalize the behaviour real bootloaders do NOT have (each `flash:` rewrites from the partition start), so tests enshrine an invariant that masks H2 on hardware. | Make SimulatedDevice mirror real silicon: each `flash:` starts the partition write at offset 0 (append mode behind an explicit opt-in flag for streaming tests). |
| M3 | MED | `lib/fastboot/sparse.ts:140-151,165-172` | Expansion drops `DONT_CARE` (leave-blocks-untouched) and `CRC32` (verify) semantics entirely, so the physical byte stream written differs from what a real bootloader writes from the identical sparse file. | Preserve chunk kinds in the transfer plan and either emulate skip/verify semantics or refuse images containing them. |
| M4 | MED | `lib/avb/signer.ts:52-54,65-76,164-166` | Signer accepts any embedded-key import for verify but hard-rejects anything except alg 2 / sig 512 for sign, and never cross-checks `signature_num_bytes*8` against the embedded key's `num_bits` (avbtool enforces this at :462-466) — RSA-2048/8192 keys fail only via downstream length errors. | Derive expected sizes from `ALGORITHMS`-style metadata and reject key/algorithm mismatches up front with an explicit `KEY_ALGORITHM_MISMATCH`. |
| M5 | MED | `lib/fastboot/client.ts:90-93` | `reboot("bootloader")` demands terminal OKAY, but many bootloaders reply INFO+FAIL or simply drop USB when servicing `reboot-bootloader`; the strict `expect` turns a successful reboot into a reported failure. | Accept OKAY-or-(FAIL/disconnect-after-send) for `reboot-*` specifically, mirroring the ADB-path disconnect tolerance. |
| M6 | MED | `wizard/adb-session.ts:34-47,98-113` | The expected-disconnect classifier treats `AbortError` as "device rebooted successfully", so a human cancelling the permission prompt (or the 90 s timer aborting the read) is indistinguishable from success. | Remove `AbortError` from `isExpectedRebootDisconnect` (timeout already surfaces its own message via `withTimeout`) or require explicit cancellation-context evidence. |
| M7 | MED | `wizard/adb-session.ts:98-128` | `waitForRebootAck` returns success after a lone OKAY without waiting for the socket drop / CLSE that indicates adbd actually serviced the reboot; the 90 s outer bound bounds the whole flow but the ACK itself proves little. | After OKAY, await the expected disconnect (bounded sub-window) or CLSE before declaring the reboot sent. |
| M8 | MED | `routes/install/flash-runner.ts:22-26`; `channels/tokay/files.txt:14` | No `super_empty.img` / dynamic-partition (virtual A/B) handling exists anywhere in the flash path, yet the tokay release bundle ships it — a real tokay flash needs the super re-layout step before system/vendor writes, and the current sparse expander would strip its DONT_CARE semantics even if it were flashed (see M3). | Add an explicit super-layout stage (flash `super_empty.img` via a DONT_CARE-preserving path, or emit `fastboot wipeall`-equivalent guidance) gated into FIRMWARE_ORDER before OS images. |
| L1 | LOW | `lib/avb/signer.ts:124-131` | Release override mutates the working copy before validating length; a >47-byte string throws after work is done (behaviour correct — `out` is discarded — but validation-first is cleaner). | Move the length check above the copy. |
| L2 | LOW | `lib/fastboot/usb.ts:195-200` | Payload `transferOut` is a single unbounded write relying on OS/URB splitting; combined with H1 this can attempt multi-hundred-MB single transfers whose failure modes vary by platform. | Transfer payloads in fixed slices (e.g. 1 MiB) with status checks per slice. |
| L3 | LOW | `lib/fastboot/protocol.ts:14,48-49,66` | Responses decoded as lossy ASCII (`U+FFFD` substitution) can mojibake the "verbatim" bootloader reason in logs/errors. | Decode with `fatal:false` latin1 semantics or hex-escape non-ASCII while keeping raw payload bytes available. |
| L4 | LOW | `lib/avb/parser.ts:109-127` vs `external/avb/avbtool.py:2207` | Footer discovery scans the last 4 KiB for `AVBf` while avbtool reads ONLY the final 64 bytes and tolerates absence — a malformed trailing image could parse here but be rejected by avbtool (benign for well-formed factory images). | Match avbtool: attempt footer strictly at `length−64`, fall back to bare-blob parsing. |
| L5 | LOW | `lib/avb/descriptors.ts:391-399` | Unknown-tag descriptor re-encode re-pads the body copy rather than preserving original pad bytes, so `descriptorsEqual` could theoretically differ on hostile unknown descriptors (never exercised on shipped releases). | Store the padded wire form for unknown tags and compare/emit verbatim. |
| L6 | LOW | `lib/fastboot/sparse.ts:187-194` | `expandFill` drops a trailing `<4`-byte tail; unreachable today (FILL output is block-aligned and blocks ≥512) but latent if the alignment guard ever loosens. | Guard `length % 4 === 0` explicitly inside `expandFill`. |
| L7 | LOW | `test/avb.test.ts:63-86,461-502` | Parity correctness currently depends on ambient python3+openssl: the suite degrades gracefully to skips (honest labels), but nothing in CI forces the parity lane to have executed at least once on a pinned environment. | Add a CI job that asserts `# skipped 0` for `test/avb.test.ts` (or records an explicit parity-run artifact) so a silent tooling loss cannot rot the parity guarantee. |
| L8 | LOW | `lib/fastboot/client.ts:140-146` + `routes/install/flash-runner.ts:104-109` | Progress events carry per-chunk `bytesTotal` but globally-offset `bytesSent`, so any consumer computing percentage gets inconsistent math (monotonicity itself holds and is tested). | Emit cumulative `bytesTotal` alongside the cumulative `bytesSent`. |

---

## Detailed notes on HIGH findings

### H1 — `max-download-size` is dead plumbing
`parseMaxDownloadSize` (`protocol.ts:122-131`) is unit-tested but has **zero production call sites**
(grep over all `.ts`: only tests). `FastbootClient.flash` chunks only when
`options.maxDownloadSize !== undefined` (`client.ts:100-116`); `RunFlashPlanDeps.maxDownloadSize`
(`flash-runner.ts:68`) is documented as "sourced from getvar max-download-size by the caller" but no
route or wizard code ever calls `client.getvar("max-download-size")`. Consequence on real silicon:
first image bigger than the bootloader's RAM buffer (every tokay OS image qualifies) dies with a
bootloader-specific failure at `DATA` time — loud, but fatal to the install and avoidable with
plumbing that already exists end-to-end. Note `clampToUint32` (`client.ts:216-218`) floors at 1,
so a hypothetical `mds=0` device would be "chunked" into 1-byte downloads rather than stopped;
prefer failing closed on absurd values.

### H2 — Sparse × chunker ordering corrupts partitions silently
`sparseChunks` expands FILL to `blocks × blockSize` and RAW verbatim (`sparse.ts:112-139`);
`imageDownloadChunks` concatenates nothing but hands each expanded chunk to
`FastbootClient.flash`, which re-splits by `maxDownloadSize`. Probe (SimulatedDevice, mds 4096,
single 8192-B RAW chunk):

```
sparse expands to chunks: [ 8192 ]
   > download:00001000 / < DATA00001000 / > [4096 byte payload] / < OKAY / > flash:system / < OKAY
   > download:00001000 / < DATA00001000 / > [4096 byte payload] / < OKAY / > flash:system / < OKAY
flash OK; stored bytes: 8192        ← simulator appended; REAL bootloader rewrites from sector 0
```

On hardware the second `flash:` restarts the write, leaving the partition's first half holding
bytes 0–4095 twice and bytes 4096–8191 never written — **no error is raised**. Verified boot would
catch the damage at next boot (hash-descriptor mismatch ⇒ device refuses to boot), which is why
this is HIGH, not BLOCKER — but it converts a recoverable pre-flight failure into a bricked-looking
post-flash state. Fix belongs at the plan level (stream chunks sized to the download budget), with
M2 fixing the simulator so the invariant is testable.

### H3 — INFO asymmetry around DATA/flash
`readTerminal` (`client.ts:169-178`) drains INFO for getvar/erase/unlock/lock/reboot/raw, but
`expectKind` (`client.ts:150-163`) — used for the `download:`→DATA handshake and the `flash:`→ANY
handshake — reads one packet and throws on anything unexpected except FAIL. The fastboot protocol
permits INFO before any response; Pixel-family bootloaders emit INFO traffic around erase/flash of
dynamic partitions. One INFO line ⇒ install aborts with `ProtocolError` despite the device being
healthy. (Related, M1: the DATA-size mismatch path also discards the verbatim-transcript promise.)

---

## §D — Independent re-derivation of D-014 (`emsaPkcs1Sha256`)

Claim under test: the KeyMaterial branch must feed the FULL EMSA-PKCS1-v1_5 block — not the bare
32-byte digest — to the textbook RSA op, matching avbtool.

Reference (re-read, not trusted):
- Padding constant `SHA256_RSA4096`: `00 01 ‖ FF×458 ‖ 00 ‖ 30 31 30 0d 06 09 60 86 48 01 65 03 04 02 01 05 00 04 20`
  at `external/avb/avbtool.py:140-147`.
- `sign()` hashes `data_to_sign`, forms `padding_and_hash = algorithm.padding + digest`
  (:468-474), and applies the private op to the RAW 512-byte block via
  `openssl rsautl -sign -raw` (:495-500). Because that raw block is exactly the EMSA-PKCS1-v1_5
  encoded message (RFC 8017 §9.2) for SHA-256, a standard RSASSA-PKCS1-v1_5 signature over the same
  message is the identical byte string for e=65537 (RFC 8017 §8.2.3(2)).

Arithmetic check of FF count: k = 512, T = 19 (DER) + 32 (digest) = 51 ⇒ FF = 512 − 3 − 51 =
**458** — matches `em.fill(0xff, 2, 2 + ffCount)` with `ffCount = k − derLen − digest.length − 3`
(`signer.ts:197-211`), and matches the literal `[0xff]*458` at avbtool.py:142. DER prefix bytes in
`SHA256_DIGEST_INFO_DER` (`signer.ts:47-50`) are byte-identical to avbtool.py:144-146.

Code check: the KeyMaterial branch builds `emsaPkcs1Sha256(digest, k)` and calls `rawRsaSign`
(`signer.ts:162, 217-229`) — textbook `m^d mod n` over the 512-byte EM, exactly `rsautl -raw`;
the CryptoKey branch feeds the raw MESSAGE `header‖aux` to WebCrypto RSASSA-PKCS1-v1_5
(`signer.ts:151-155`), which performs EMSA internally — the two branches therefore agree with each
other and with avbtool, and the pre-computed digest is never double-hashed. The pre-fix bug
(bare 32-byte digest ⇒ `EM length 32 != modulus length 512`) is structurally impossible now:
`rawRsaSign` enforces `em.length === k` (`signer.ts:220-222`).

Empirical proof: parity test "resign fixture-style minimal image matches avbtool byte-for-byte"
executed live this session (17/17 pass, 0 skipped) — our re-sign of avbtool's own output under the
same PEM key equals avbtool's bytes exactly. **D-014 verified correct.**

---

## Verified-clean inventory (with method)

| Area | Claim verified | Method |
|---|---|---|
| Digest input | `SHA-256(header[256] ‖ aux)` — `signer.ts:133-139, 304-313` ≡ avbtool.py:3261-3268, 589-594 | Code walk + live parity (tests 15–17) |
| Signature op | RSASSA-PKCS1-v1_5 ≡ `rsautl -sign -raw` over `padding‖digest` for e=65537 — `signer.ts:141-163` ≡ :468-505 | RFC 8017 derivation + live byte-parity test 17 |
| Auth repack | `[hash@hashOffset][sig@signatureOffset]` from ORIGINAL header fields, overflow-guarded — `signer.ts:168-181` ≡ :3239-3244, :3276-3281 | Code walk + tamper matrix test 13 |
| Release string | written at offset 128, NUL-padded, ≤47 B enforced — `signer.ts:124-131` ≡ header `'47sx'` @ :2104 | Code walk + test 12 |
| Verify mirror | digest compare → RSA verify vs EMBEDDED key; explicit-key variant fails closed — `signer.ts:287-350` ≡ :548-594, :2575-2583 | Code walk + tamper matrix + parity test 16 |
| pkmd encode | `!II(numBits, n0inv=2^32−inv(n mod 2^32)) ‖ BE(n) ‖ rr=(2^bits)² mod N`, exactly 1032 B, e=65537 enforced — `pkmd.ts:38-62` ≡ :411-435, :246-265 | Code walk + live parity test 15 (encodePkmd ≡ avbtool extract_public_key) + fixture roundtrip test 4 |
| pkmd fingerprint | SHA-256 over the raw 1032 bytes, lowercase hex — `pkmd.ts:94-102` | Test 4 vs `node:crypto` |
| Descriptor codecs | property/hashtree/hash/cmdline/chain layouts, reserved-60 fields, 8-byte zero padding, num_bytes_following arithmetic — `descriptors.ts` ≡ :1265-1334 / :1378-1508 / :1585-1676 / :1726-1789 / :1823-1903 | Line-by-line diff + fixture roundtrips (`wireLen === descriptorsSize`, tests 1, 8, 9) |
| Parser geometry | 256-B header field offsets match FORMAT_STRING (:2093-2105); auth/aux 64-alignment; footer at image tail tolerated-absent (:2791-2801) | Code walk + parse tests 1–3, 6 |
| Fastboot framing | ASCII commands, UTF-8 encode only at transport boundary; `download:%08x` lowercase zero-padded; DATA size echoed-and-compared; unknown prefixes rejected — `protocol.ts`, tests | Unit tests 61-81 + wire-identity test |
| FAIL propagation | verbatim bootloader reason carried on `FastbootError.reason`; flow stops immediately; later partitions untouched — `client.ts:23-32,192-203` | route-install-late tests (failNthFlash, refusal cases) |
| Flash ORDER | avb_custom_key FIRST → firmware (bootloader/radio/boot/vendor_boot/dtbo) → OS → user-signed vbmeta LAST; unknown names rank last WITHIN their phase, never across phases — `flash-runner.ts:22-26,81-92,130-158` | Code walk + ordered-transcript assertions (late-steps tests) |
| Chunk boundary math | `splitChunks` exact-multiple and remainder cases correct (probe: 2560@1024 ⇒ 1024/1024/512; 2048@1024 ⇒ 2 chunks; floor≥1 clamp) | Empirical probe |
| ADB reboot bounds | 90 s budget; timeout aborts in-flight read and closes handle; wrong-localId OKAY rejected; AUTH loop bounded at 8; checksum enforced | `adb-reboot.test.ts` / `adb-pipe.ts` walk |

## Reference-line ledger (comments vs actual avbtool.py)

Every `:NNN` citation in `signer.ts`, `pkmd.ts`, `parser.ts`, `descriptors.ts`, `bytes.ts` was
re-read. All material references are accurate (digest :3261-3268; sign :468-505; padding
:134-147; auth layout :3234-3244/:3276-3281; assembly :3283; pkmd :411-435; header :2093-2105;
footer :1978-2039; MAX_FOOTER_SIZE :2207; descriptors as listed above; verify :548-594/:597-655;
key-blob compare :2575-2583). Two trivially-off comment ranges, no code impact:
- `signer.ts:46` cites ":143-146" for the DER prefix; the prefix bytes actually sit at :144-146
  (:143 is the FF-row continuation).
- `parser.ts:22` cites ":112-197" for ALGORITHMS; the dict opens earlier (~:96, NONE entry) with
  the cited span covering the SHA256_RSA*/SHA512_RSA* entries.

## Parity honesty (audit item 2)

`test/avb.test.ts` genuinely shells out: `before()` generates a fresh RSA-4096 PEM with openssl and
runs `python3 external/avb/avbtool.py make_vbmeta_image --algorithm SHA256_RSA4096 …` plus
`extract_public_key` (:74-81), and three parity tests consume the outputs byte-for-byte. Executed
this session: **17/17 passed, 0 skipped, 0 faked**. Caveats: (a) the suite skips gracefully — with
an honest label — when python3/openssl are missing, and no CI mechanism forces the parity lane to
have run (L7); (b) parity covers the CryptoKey branch AND (via `resignWithPemKey`, :511-533) the
imported-JWK branch, so both sign paths are anchored to avbtool.

## ADB reboot classifier (audit item 7)

`isExpectedRebootDisconnect` (`adb-session.ts:34-47`) whitelists pipe-level "stream ended/
cancelled" and four DOMException names. It cannot swallow: unexpected ADB packets (:117-121),
wrong-localId OKAY (:123-127), checksum/hostile-buffer failures (pipe layer), or arbitrary USB
errors — `InvalidStateError` after OPEN surfaces as `AdbError` (tested, adb-reboot.test.ts:331-357).
Two residual honesty gaps are filed as M6 (AbortError swallowed as success) and M7 (bare OKAY
treated as reboot-done). `waitForRebootAck` is bounded by the 90 s `REBOOT_WAIT_MS` wrapper with
guaranteed cancel/close unwind (`adb-reboot.ts:31-44`, tested :285-315).

---

## Severity counts

| Severity | Count | IDs |
|---|---|---|
| BLOCKER | 0 | — |
| HIGH | 3 | H1, H2, H3 |
| MED | 8 | M1–M8 |
| LOW | 8 | L1–L8 |
| **Total** | **19** | |

Bottom line: ship-blocking defects are concentrated in the transport/plumbing layer (H1–H3), not in
cryptography — the AVB bytes this installer produces are provably identical to avbtool's on real
keys, and the flash-order anchor (vbmeta LAST) is enforced. Fix H1+H2 together (fetch
max-download-size; stream sparse expansion into budget-sized units; align the simulator first), and
H3 falls to a five-line INFO-drain loop in `expectKind`.
