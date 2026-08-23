# READER-B DIGEST — AVB2.0 vbmeta + fastboot-over-WebUSB (implementation spec)

> Provenance: `external/avb/avbtool.py` = AOSP avbtool v1.3 (lines 41–43); `external/avb/libavb/*.h`;
> `system/core/fastboot/*`. Sections A/C/D below from the original reader digest (line-cited);
> section B re-derived first-hand this session after the original delivery was truncated
> (avbtool.py lines 466–505, 3231–3283). All offsets big-endian ("network order").

## A. vbmeta binary layout

Image = fixed **256-byte header** + variable **auth block** + variable **aux block**
(`avb_vbmeta_image.h:64-74`); auth/aux sizes are multiples of 64 (`:100-101`).

### Header — 256 bytes (`avb_vbmeta_image.h:42`, avbtool.py:2093–2105)

| Off | Size | Field | Notes |
|----|------|-------|-------|
| 0 | 4 | magic | `"AVB0"` |
| 4 | 4 | required_libavb_version_major | 1 today |
| 8 | 4 | required_libavb_version_minor | |
| 12 | 8 | authentication_data_block_size | mult of 64 |
| 20 | 8 | auxiliary_data_block_size | mult of 64 |
| 28 | 4 | algorithm_type | 0 NONE · 1 SHA256_RSA2048 · 2 SHA256_RSA4096 · 3 SHA256_RSA8192 · 4/5 SHA512_* |
| 32 | 8 | hash_offset | into AUTH block |
| 40 | 8 | hash_size | |
| 48 | 8 | signature_offset | into AUTH block |
| 56 | 8 | signature_size | |
| 64 | 8 | public_key_offset | into AUX block |
| 72 | 8 | public_key_size | |
| 80 | 8 | public_key_metadata_offset | into AUX block |
| 88 | 8 | public_key_metadata_size | 0 if absent |
| 96 | 8 | descriptors_offset | into AUX block |
| 104 | 8 | descriptors_size | |
| 112 | 8 | rollback_index | uint64 |
| 120 | 4 | flags | bit0 HASHTREE_DISABLED, bit1 VERIFICATION_DISABLED (avbtool.py:49–50) |
| 124 | 4 | rollback_index_location | must be 0 for chained images (`avb_vbmeta_image.h:179-184`) |
| 128 | 48 | release_string | NUL-terminated; default `"avbtool 1.3.0"` |
| 176 | 80 | reserved | zeros |

Footer (`"AVBf"`, last 64 B of a partition image, `avb_footer.h:39-74`): magic(4) ver_major(4)
ver_minor(4) original_image_size(8) vbmeta_offset(8) vbmeta_size(8) reserved(28). Seek
partitionSize−4096 and scan for `"AVBf"` (`MAX_FOOTER_SIZE=4096`, avbtool.py:2207).
**Bare `make_vbmeta_image` output has NO footer** — blob starts at offset 0.

## B. Signing recipe (SHA256_RSA4096, alg id 2) — exact, parity-testable

Constants (avbtool.py:134–147): hash 32 B; signature 512 B; pkmd-encoded pubkey 1032 B;
PKCS#1 v1.5 padding = `00 01 ‖ FF×458 ‖ 00 ‖ DER(3031300d060960864801650304020105000420)`.

Build order inside `_generate_vbmeta_blob` (avbtool.py:3022–3283):

1. **Descriptors** encoded in insertion order (chain → props → cmdline → included-image
   descriptors; same-partition dedupe keeps LAST seen, sorted by type+name — :3174–3196).
   Each descriptor: tag(u32 BE) + num_bytes_following(u32? — per-descriptor struct, padded to
   8-byte multiple with zeros; see encode() at :1216–1228 et al.).
2. **Aux block layout** (:3223–3232): `[descriptors][public key 1032B][pkmd blob]`,
   zero-padded to 64-byte multiple. `descriptors_offset=0`,
   `public_key_offset=len(descriptors)`, `pkmd_offset=pubkey_off+1032`.
3. **Auth block layout** (:3234–3244): `[hash 32B][signature 512B]`, zero-padded to 64.
   `hash_offset=0`, `signature_offset=32`.
4. Header fields set as above; `header_data_blob = h.encode()` (the 256 bytes).
5. **Digest** (:3261–3268): SHA-256 over `header_data_blob ‖ aux_data_blob`.
6. **Signature** (:3270–3274 → :437–505): raw RSA private-key operation over
   `padding_and_hash = PKCS1v1.5_padding(458×FF) ‖ sha256(header‖aux)`
   — i.e. sign the 512-byte prehashed block with `openssl rsautl -sign -raw`
   (equivalently RSA-PKCS1-v1.5 signature over the DigestInfo structure that padding embeds;
   WebCrypto RSASSA-PKCS1-v1_5 with SHA-256 produces the identical 512-byte output for e=65537).
   data_to_sign passed to sign() is `header ‖ aux`; sign() itself hashes it and prepends padding.
7. Final blob = `header ‖ auth ‖ aux`.

Verification mirror (`verify_image`): parse header, recompute SHA-256(header‖aux), compare to auth
hash, then RSA-verify signature against embedded public key. Our parser must reproduce all three.

## C. avb_pkmd.bin format (RSAPublicKey.encode, avbtool.py:411–435)

```
u32 BE num_bits            # 4096
u32 BE n0inv               # 2^32 − (n mod 2^32)^(-1) mod 2^32
byte[512] modulus n        # big-endian, full key length
byte[512] rr               # (2^(bit_length(n)))² mod n — Montgomery R²
```
Total 1032 bytes; exponent must be 65537 (:423–424). Matches `channels/*/avb_pkmd.bin` fixtures.
Fingerprint shown to user = SHA-256 over these 1032 bytes (hex, mono).

## D. Chain descriptors & safe-stop rule

`AvbChainPartitionDescriptor` (avbtool.py:1811+, encode :1887–1903) names a partition whose own
vbmeta is signed by another key. If a release's top-level vbmeta contains chain descriptors for
partitions we cannot re-sign client-side with known layout ⇒ **STOP the flow** with reason +
`// confirm partition layout` (Q-07). Never flash a partially signed set.

## E. Fastboot command/response matrix

Commands: `getvar:<var>` → `OKAY<value>` / `INFO…` / `FAIL<reason>`;
`download:<size08x>` → `DATA<size08x>` → send bytes → `OKAY`;
`flash:<partition>` / `erase:<partition>` / `flashing unlock` / `flashing lock` /
`reboot` / `reboot-bootloader` → `OKAY` or `FAIL<reason>`. USB packet size 512.
Large partitions: chunk via `download:` in ≤256 MiB slices; sparse images supported by
chunked download of sparse chunks. Every command+response echoed verbatim to the mono console.

## F. Reusable WebUSB patterns from this repo (post Q-WEBINSTALL-ADB-FIXES)

Claim interface + pair endpoints once; wrap transferIn with optional AbortSignal and forward it
through every read layer; cap leftover buffers (1 MiB pattern from adb-pipe); macrotask yield
before device.close() so aborted transfers unwind; classify DOMExceptions explicitly instead of
swallowing; validate remote IDs on responses. Mirror these in lib/fastboot/usb.ts.

## G. CI fixture plan (deterministic)

```bash
# smallest deterministic sample vbmeta (no image hashing):
openssl genrsa -out test/fixtures/testkey_rsa4096.pem 4096
python3 external/avb/avbtool.py make_vbmeta_image \
  --output test/fixtures/sample.avbvbmeta \
  --algorithm SHA256_RSA4096 --key test/fixtures/testkey_rsa4096.pem \
  --rollback_index 0 --flags 0 --padding_size 64
python3 external/avb/avbtool.py extract_public_key \
  --key test/fixtures/testkey_rsa4096.pem --output test/fixtures/expected.avb_pkmd.bin
# real-release fixtures already in-tree:
#   channels/tokay/vbmeta.img (+ vbmeta_system.img, vbmeta_vendor.img) for parse-parity
#   channels/tokay/avb_pkmd.bin (1032 B) for pkmd-parity
```

Parity assertions: our `parseVbmeta(sample) ≡ avbtool` fields; our `resignVbmeta(sample,key)` ≡
`avbtool … --key samekey` output byte-for-byte; our `encodePkmd ≡ expected.avb_pkmd.bin`.
