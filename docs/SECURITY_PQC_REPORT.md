# A-PQC-FS-RESEARCH — PQC Posture for GuardTalkOS Storage/Boot Trust Chain

**Task ID:** A-PQC-FS-RESEARCH (#4)
**Role:** AEGIS Auditor (READ-ONLY research)
**Date:** 2026-07-02
**Gate -1:** ACKNOWLEDGED. No files edited outside this report. No commits. No doctrine/governance access.
**Source tree:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/` (AOSP + GrapheneOS, tokay/Pixel 9)

---

## 0. Executive Summary

GuardTalkOS's storage/boot trust chain is **NOT** ready for a PQC transition today, and — critically — the most-asked question ("should we swap the FBE cipher for a PQC cipher?") is **a category error**: there is no NIST-standardized PQC block cipher, and AES-256-XTS/CTS is already post-quantum-safe (Grover's algorithm halves its 256-bit security to 128-bit effective, which remains strong).

The actionable PQC surface is in **asymmetric** crypto — attestation, AVB signing, and OTA signing — and in every case the upstream tooling (KeyMint HAL, `avbtool`, `ota_from_target_files`, the Pixel bootloader blob) ships **no PQC algorithm support**. BoringSSL in this tree *does* ship ML-KEM and ML-DSA primitives, but they are wired into the **TLS layer only** (hybrid PQ key exchange groups `X25519MLKEM768`, `MLKEM1024`); they are **NOT** exposed in KeyMint, AVB, OTA, or X.509 attestation certificate signing.

**Go/No-Go:** **NO-GO** for PQC implementation in GuardTalkOS today. **GO** for monitoring upstream adoption (BoringSSL, `external/avb`, `hardware/interfaces/keymint`). The FBE cipher must not / cannot meaningfully become "PQC."

---

## 1. Threat Model: Where Quantum Matters in the Storage/Boot Path

The brief flags this as critical, and it is correct: the storage/boot trust chain mixes **symmetric** (PQ-safe) and **asymmetric** (PQ-vulnerable) primitives. Conflating them leads to the wrong recommendation.

### 1.1 Block cipher (FBE data-at-rest) — PQ-SAFE, no action

Android File-Based Encryption (FBE) encrypts file **contents** with AES-256-XTS and file **names** with AES-256-CTS (or the Adiantum AEAD on devices without AES acceleration). Both are symmetric ciphers.

Evidence (`system/vold/CryptoType.h:68-76`):

```68:68:system/vold/CryptoType.h
constexpr CryptoType aes_256_xts = CryptoType()
                                           .set_config_name("aes-256-xts")
                                           .set_kernel_name("aes-xts-plain64")
                                           .set_keysize(64);
constexpr CryptoType adiantum = CryptoType()
                                        .set_config_name("adiantum")
                                        .set_kernel_name("xchacha12,aes-adiantum-plain64")
                                        .set_keysize(32);
```

Evidence (`system/vold/MetadataCrypt.cpp:70,76-77`):

```70:77:system/vold/MetadataCrypt.cpp
constexpr CryptoType supported_crypto_types[] = {aes_256_xts, adiantum};
...
constexpr CryptoType legacy_aes_256_xts =
        CryptoType().set_config_name("aes-256-xts").set_kernel_name("AES-256-XTS").set_keysize(64);
```

Evidence (filename mode default, `system/vold/FsCrypt.cpp:357-365`):

```357:365:system/vold/FsCrypt.cpp
    auto contents_mode = android::base::GetProperty("ro.crypto.volume.contents_mode", "");
    auto filenames_mode =
            android::base::GetProperty("ro.crypto.volume.filenames_mode",
                                                     first_api_level > __ANDROID_API_Q__ ? "" : "aes-256-heh");
    auto options_string = android::base::GetProperty("ro.crypto.volume.options",
                                                     contents_mode + ":" + filenames_mode);
```

**Quantum threat assessment:**
- Grover's algorithm provides a quadratic speedup, reducing the effective security of AES-256 from 256 bits to **~128 bits** against a quantum adversary.
- 128-bit effective security is still considered strong (equivalent to brute-forcing AES-128 classically, which remains infeasible).
- There is **no NIST-standardized PQC block cipher** (ML-KEM is a KEM, ML-DSA is a signature scheme — neither is a drop-in AES-XTS replacement).
- **Conclusion: AES-256-XTS/CTS is ALREADY PQ-safe. No PQC swap is needed or possible.**

### 1.2 FBE key wrapping — SYMMETRIC, PQ-SAFE

The FBE master key is wrapped by `KeyStorage.cpp`. There are two paths:
1. **Keystore path** (when `auth.usesKeystore()` is true): generates an AES-256-GCM key in KeyMint/Keystore and uses it to encrypt (wrap) the FBE master key.
2. **No-keystore path**: derives a wrapping key via SHA-512(preKey) and uses AES-256-GCM directly via OpenSSL.

Evidence (`system/vold/KeyStorage.cpp:51-53, 117-134`):

```51:53:system/vold/KeyStorage.cpp
static constexpr size_t AES_KEY_BYTES = 32;
static constexpr size_t GCM_NONCE_BYTES = 12;
static constexpr size_t GCM_MAC_BYTES = 16;
```

```117:134:system/vold/KeyStorage.cpp
static bool generateKeyStorageKey(Keystore& keystore, const std::string& appId, std::string* key) {
    auto paramBuilder = km::AuthorizationSetBuilder()
                                .AesEncryptionKey(AES_KEY_BYTES * 8)
                                .GcmModeMinMacLen(GCM_MAC_BYTES * 8)
                                .Authorization(km::TAG_APPLICATION_ID, appId)
                                .Authorization(km::TAG_NO_AUTH_REQUIRED);
    LOG(DEBUG) << "Generating \"key storage\" key";
    auto paramsWithRollback = paramBuilder;
    paramsWithRollback.Authorization(km::TAG_ROLLBACK_RESISTANCE);

    if (!keystore.generateKey(paramsWithRollback, key)) {
        LOG(WARNING) << "Failed to generate rollback-resistant key.  This is expected if keystore "
                        "doesn't support rollback resistance.  Falling back to "
                        "non-rollback-resistant key.";
        if (!keystore.generateKey(paramBuilder, key)) return false;
    }
    return true;
}
```

Evidence (no-keystore path uses AES-256-GCM, `system/vold/KeyStorage.cpp:434-482`):

```434:482:system/vold/KeyStorage.cpp
static bool encryptWithoutKeystore(const std::string& preKey, const KeyBuffer& plaintext,
                                   std::string* ciphertext) {
    std::string key;
    hashWithPrefix(kHashPrefix_keygen, preKey, &key);
    key.resize(AES_KEY_BYTES);
    ...
    if (1 != EVP_EncryptInit_ex(ctx.get(), EVP_aes_256_gcm(), NULL, ...
```

**Quantum threat assessment:**
- The key wrapping is **symmetric** (AES-256-GCM), not RSA/EC key agreement. There is **no asymmetric key wrap** in this path.
- The "secret" mixed into the `appId` (`KeyStorage.cpp:411-428`) is the user credential, derived through the gatekeeper path, not an RSA/EC key.
- **Conclusion: PQ-safe. No Shor vulnerability here.** The brief's hypothesis ("If symmetric, PQ-safe. If RSA/EC, vulnerable to Shor") resolves to: **symmetric, PQ-safe.**

### 1.3 Attestation — ASYMMETRIC, SHOR-VULNERABLE (harvest-now-decrypt-later)

KeyMint attestation produces X.509 certificates signed by an attestation key. The attestation key is generated via `Tag::ALGORITHM` which — per `Algorithm.aidl` — supports only `RSA` or `EC` (see §2 below). The `AttestationKey.aidl` parcelable (`hardware/interfaces/security/keymint/aidl/.../AttestationKey.aidl:29-45`) carries only an opaque `keyBlob` and `issuerSubjectName`; the signature algorithm is dictated by the key's `Algorithm` tag.

**Quantum threat assessment:**
- RSA-2048/EC P-256 attestation certificates are vulnerable to **Shor's algorithm**.
- This is a **harvest-now-decrypt-later (HNDL)** scenario: an adversary who records an attestation certificate chain today could, with a future quantum computer, forge attestation signatures.
- **Practical risk today: LOW** (no cryptographically relevant quantum computer exists), but the HNDL window is open for any long-lived attestation key.
- **Conclusion: PQ-relevant (eventually), but blocked on KeyMint PQC support (see §2).**

### 1.4 AVB signing — ASYMMETRIC, SHOR-VULNERABLE (real-time forgery)

Android Verified Boot (AVB) signs the `vbmeta` partition and chained images. The `avbtool` signature algorithm set is RSA-only (see §3). An attacker with a quantum computer could forge AVB signatures.

**Quantum threat assessment:**
- Unlike attestation, AVB verification is **real-time** (boot-time), not a decrypt-later scenario. The attack window requires the attacker to possess a quantum computer *at the time of boot forgery*.
- **Practical risk today: VERY LOW** — but the long-term concern is real for devices with multi-decade deployment lifetimes.
- **Conclusion: PQ-relevant (eventually), but blocked on `avbtool` + bootloader PQC support (see §3, §6).**

### 1.5 OTA signing — ASYMMETRIC, SHOR-VULNERABLE (real-time forgery)

OTA payloads are signed via `payload_signer.py` which calls `openssl pkeyutl` with RSA/EC keys (see §3). Same threat profile as AVB.

### 1.6 TLS (network) — ASYMMETRIC, SHOR-VULNERABLE, PQC PARTIALLY AVAILABLE

BoringSSL in this tree ships hybrid PQ TLS key exchange (see §4). This is the **only** place where PQC is actually wired into a usable code path in the GuardTalkOS tree, and it is **not** part of the storage/boot trust chain.

---

## 2. KeyMint/StrongBox PQC Availability — NONE

### 2.1 Algorithm enum — RSA, EC, AES, TRIPLE_DES, HMAC only

Evidence (`hardware/interfaces/security/keymint/aidl/android/hardware/security/keymint/Algorithm.aidl:25-37`):

```25:37:hardware/interfaces/security/keymint/aidl/android/hardware/security/keymint/Algorithm.aidl
enum Algorithm {
    /** Asymmetric algorithms. */
    RSA = 1,
    /** 2 removed, do not reuse. */
    EC = 3,

    /** Block cipher algorithms */
    AES = 32,
    TRIPLE_DES = 33,

    /** MAC algorithms */
    HMAC = 128,
}
```

**No ML-KEM, no ML-DSA, no Kyber, no Dilithium, no PQC enum value.** The `2 removed` slot is reserved/unused and is not a hidden PQC algorithm.

### 2.2 EcCurve enum — classical curves only

Evidence (`hardware/interfaces/security/keymint/aidl/android/hardware/security/keymint/EcCurve.aidl:25-31`):

```25:31:hardware/interfaces/security/keymint/aidl/android/hardware/security/keymint/EcCurve.aidl
enum EcCurve {
    P_224 = 0,
    P_256 = 1,
    P_384 = 2,
    P_521 = 3,
    CURVE_25519 = 4,
}
```

Classical NIST curves + Curve25519. No PQC curve or lattice parameter set.

### 2.3 KeyParameterValue union — no PQC surface

Evidence (`hardware/interfaces/security/keymint/aidl/android/hardware/security/keymint/KeyParameterValue.aidl:32-54`): the union references only `Algorithm`, `BlockMode`, `PaddingMode`, `Digest`, `EcCurve`, `KeyOrigin`, `KeyPurpose`, `HardwareAuthenticatorType`, `SecurityLevel` — all of which are classical. There is no PQC variant.

### 2.4 Tag.aidl — no PQC tags

A full read of `hardware/interfaces/security/keymint/aidl/android/hardware/security/keymint/Tag.aidl` confirms tags reference RSA (`RSA_PUBLIC_EXPONENT`, `RSA_OAEP_MGF_DIGEST`), EC (`EC_CURVE`), AES (`BLOCK_MODE`, `MIN_MAC_LENGTH`), HMAC — no PQC tags.

### 2.5 StrongBox (Pixel 9 / tokay)

No production StrongBox ships PQC today. The Pixel 9's StrongBox (Google Tensor G4 secure element) is a proprietary hardware-backed KeyMint implementation conforming to the same `Algorithm` AIDL surface above. Since the AIDL surface exposes no PQC algorithm, **StrongBox cannot be invoked with a PQC algorithm** even if the silicon could theoretically support one — there is no enum value to request it.

Verified: no `hardware/interfaces/keymint/` directory exists separately (only `hardware/interfaces/security/keymint/`); the older Keymaster HAL is deprecated and not PQC either.

### 2.6 Software KeyMint — could add PQC, loses HW protection

A software KeyMint implementation *could* theoretically be extended to add ML-DSA/ML-KEM (BoringSSL provides the primitives, §4). However:
- It would lose StrongBox/TEE hardware protection (the entire point of KeyMint).
- It would require patching the `Algorithm` AIDL enum — breaking VintfStability guarantees.
- It would require corresponding X.509 attestation certificate support in BoringSSL, which is **NOT** present (§4.3).
- **Conclusion: not a viable path for GuardTalkOS today.**

---

## 3. AVB/OTA PQC Signing Availability — NONE

### 3.1 AVB (`external/avb/avbtool.py`) — RSA-only

Evidence (`external/avb/avbtool.py:112-204`):

```112:204:external/avb/avbtool.py
ALGORITHMS = {
    'NONE': Algorithm(
        algorithm_type=0,        # AVB_ALGORITHM_TYPE_NONE
        ...
    'SHA256_RSA2048': Algorithm(
        algorithm_type=1,        # AVB_ALGORITHM_TYPE_SHA256_RSA2048
        ...
    'SHA256_RSA4096': Algorithm(
        algorithm_type=2,        # AVB_ALGORITHM_TYPE_SHA256_RSA4096
        ...
    'SHA256_RSA8192': Algorithm(
        algorithm_type=3,        # AVB_ALGORITHM_TYPE_SHA256_RSA8192
        ...
    'SHA512_RSA2048': Algorithm(
        algorithm_type=4,        # AVB_ALGORITHM_TYPE_SHA512_RSA2048
        ...
    'SHA512_RSA4096': Algorithm(
        algorithm_type=5,        # AVB_ALGORITHM_TYPE_SHA512_RSA4096
        ...
    'SHA512_RSA8192': Algorithm(
        algorithm_type=6,        # AVB_ALGORITHM_TYPE_SHA512_RSA8192
        ...
}
```

**Seven entries total: NONE + six RSA variants.** No EC, no Ed25519, no ML-DSA, no PQC. A grep for `mldsa|ml_dsa|mlkem|ml_kem|kyber|dilithium|pq_sign|post.quantum` across the entire `external/avb/` tree returns **zero matches**.

The `ALGORITHMS` dict must be kept in sync with `libavb/avb_crypto.h` (referenced at `avbtool.py:108`), which is the C-side verifier consumed by the bootloader. Even if `avbtool.py` were patched to add an ML-DSA entry, the **Pixel bootloader blob is a proprietary closed-source binary** that links against `libavb` and cannot be modified by GuardTalkOS.

### 3.2 OTA (`build/tools/releasetools/payload_signer.py`) — RSA/EC via OpenSSL

Evidence (`build/tools/releasetools/payload_signer.py:98-123`):

```98:123:build/tools/releasetools/payload_signer.py
    if payload_signer is None:
      # Prepare the payload signing key.
      private_key = package_key + private_key_suffix
      cmd = ["openssl", "pkcs8", "-in", private_key, "-inform", "DER"]
      ...
      self.signer = "openssl"
      self.signer_args = ["pkeyutl", "-sign", "-inkey", signing_key,
                          "-pkeyopt", "digest:sha256"]
      self.maximum_signature_size = self._GetMaximumSignatureSizeInBytes(
          signing_key)
    else:
      self.signer = payload_signer
      self.signer_args = payload_signer_args
      if payload_signer_maximum_signature_size:
        self.maximum_signature_size = int(
            payload_signer_maximum_signature_size)
      else:
        # The legacy config uses RSA2048 keys.
        logger.warning("The maximum signature size for payload signer is not"
                       " set, default to 256 bytes.")
        self.maximum_signature_size = 256
```

The default signer invokes `openssl pkeyutl -sign`, which operates on whatever key OpenSSL supports. OpenSSL *can* be built with ML-DSA providers, but:
- The AOSP-built `openssl` binary in this tree is BoringSSL-based, and BoringSSL's `pkeyutl` does **not** expose ML-DSA as a signing algorithm through the `EVP_PKEY` interface in the way `payload_signer.py` expects.
- The `--payload_signer` external hook *could* be pointed at a custom ML-DSA signer, but the **device-side OTA verifier** (update_engine) would need to verify an ML-DSA signature — which it cannot do today.
- The signing key would need to be re-generated as an ML-DSA key, and the device's embedded verification key would need updating — which requires bootloader cooperation.

### 3.3 Hybrid PQ signatures (RSA-4096 + ML-DSA) for AVB/OTA

**No path exists in the current AOSP.** A hybrid scheme would require:
1. Patching `external/avb/avbtool.py` `ALGORITHMS` to add hybrid entries.
2. Patching `external/avb/libavb/avb_crypto.h` and the verifier C code.
3. **Patching the Pixel bootloader blob** — which is closed-source and out of GuardTalkOS control.
4. Same for OTA: patching `payload_signer.py`, `update_engine`, and the bootloader's OTA verification key.

**Conclusion: hybrid PQ AVB/OTA signing is blocked on the proprietary Pixel bootloader. Not actionable for GuardTalkOS.**

---

## 4. Where PQC Is Meaningful vs. Where AES-256 Already Suffices

### 4.1 BoringSSL PQC inventory (in-tree, TLS-only)

BoringSSL in this tree (`external/boringssl/`) ships FIPS 203/204 primitives:
- `include/openssl/mlkem.h` — ML-KEM-768 (FIPS 203, §1: "Module-Lattice-Based Key-Encapsulation Mechanism from https://csrc.nist.gov/pubs/fips/204/final"). Note: FIPS 204 is ML-DSA; the header comment appears mislabeled but the implementation is ML-KEM-768 per the struct names.
- `include/openssl/mldsa.h` — ML-DSA-65 (FIPS 204, §1: "Module-Lattice-Based Digital Signature Standard").
- `crypto/mlkem/`, `crypto/mldsa/`, `crypto/kyber/`, `crypto/xwing/` — implementations.
- Rust bindings: `rust/bssl-crypto/src/mlkem.rs`, `rust/bssl-crypto/src/mldsa.rs`.

**However, these are wired into the TLS layer only:**

Evidence (`external/boringssl/src/ssl/ssl_key_share.cc:284-467`):

```284:467:external/boringssl/src/ssl/ssl_key_share.cc
// draft-ietf-tls-ecdhe-mlkem-00
class X25519MLKEM768KeyShare : public SSLKeyShare {
  uint16_t GroupID() const override { return SSL_GROUP_X25519_MLKEM768; }
  ...
};
// draft-ietf-tls-mlkem-04
class MLKEM1024KeyShare : public SSLKeyShare {
  uint16_t GroupID() const override { return SSL_GROUP_MLKEM1024; }
  ...
};
```

Evidence (`external/boringssl/src/ssl/extensions.cc:101-105`):

```101:105:external/boringssl/src/ssl/extensions.cc
static bool is_post_quantum_group(uint16_t id) {
    switch (id) {
    case SSL_GROUP_X25519_KYBER768_DRAFT00:
    case SSL_GROUP_X25519_MLKEM768:
    case SSL_GROUP_MLKEM1024:
```

### 4.2 ML-DSA is NOT wired into X.509 attestation

A grep for `mldsa|MLDSA|ml_dsa|ML_DSA|MLDSA65|MLDSA87|MLDSA44` across `external/boringssl/src/crypto/x509/` returns **zero matches**. The BoringSSL OID table (`external/boringssl/src/crypto/obj/objects.txt:1335-1340`) defines NIDs only for TLS KEMs, with the explicit comment "no corresponding OIDs":

```1335:1340:external/boringssl/src/crypto/obj/objects.txt
# NIDs for post quantum hybrid KEMs in TLS (no corresponding OIDs).
...
 : X25519MLKEM768
# NIDs for post quantum (pure) KEMs in TLS (no corresponding OIDs).
 : MLKEM1024
```

**No ML-DSA OID is registered for X.509 certificate signatures.** Therefore even if KeyMint wanted to emit an ML-DSA-signed attestation certificate, BoringSSL cannot encode/verify it today.

### 4.3 Summary table

| Component | Algorithm | Quantum threat? | PQC needed? | Actionable today? |
|---|---|---|---|---|
| FBE block cipher (contents) | AES-256-XTS | Grover ⇒ 128-bit effective | **NO** (already PQ-safe; no PQC block cipher standard exists) | None — do not touch |
| FBE block cipher (filenames) | AES-256-CTS (or Adiantum) | Grover ⇒ 128-bit effective | **NO** | None |
| FBE key wrapping (Keystore path) | AES-256-GCM (symmetric, KeyMint-wrapped) | None (symmetric) | **NO** | None |
| FBE key wrapping (no-Keystore path) | AES-256-GCM (SHA-512-derived key) | None (symmetric) | **NO** | None |
| KeyMint key blobs | Opaque hardware-wrapped (symmetric inside TEE/StrongBox) | None | **NO** | None |
| Attestation certs | RSA-2048 / EC P-256 (X.509) | Shor (HNDL) | Yes (eventually) | **NO** — blocked on KeyMint PQC AIDL + BoringSSL X.509 ML-DSA OID |
| AVB signing | RSA-2048/4096/8192 (SHA256/512) | Shor (real-time forgery) | Yes (eventually) | **NO** — blocked on `avbtool` PQC + Pixel bootloader blob |
| OTA signing | RSA-2048/4096 (openssl pkeyutl) | Shor (real-time forgery) | Yes (eventually) | **NO** — blocked on `update_engine` verifier + bootloader |
| TLS (network) | RSA/EC + X25519 (classical) | Shor | Yes | **Partially** — BoringSSL ships hybrid PQ groups (`X25519MLKEM768`, `MLKEM1024`); AOSP tracks this |

---

## 5. Actionable Recommendation

### 5.1 Is there ANY PQC change that is GO for GuardTalkOS today?

**NO.** Specifically:
- **FBE cipher:** Must NOT and CANNOT be "swapped for PQC." AES-256-XTS/CTS is already PQ-safe, and there is no NIST PQC block cipher standard. This is the most important correction to the framing.
- **Key wrapping:** Already symmetric AES-256-GCM. PQ-safe. No action.
- **Attestation:** Blocked on KeyMint `Algorithm` AIDL gaining an ML-DSA enum value AND BoringSSL X.509 gaining ML-DSA signature OID support. Neither exists today.
- **AVB signing:** Blocked on `avbtool` `ALGORITHMS` dict gaining a PQC entry AND the closed-source Pixel bootloader blob being updated to verify PQC signatures. GuardTalkOS cannot modify the bootloader.
- **OTA signing:** Blocked on `update_engine` PQC verification + bootloader cooperation.
- **TLS (out of storage/boot scope, noted for completeness):** BoringSSL already ships hybrid PQ groups; AOSP/GrapheneOS track this upstream. No GuardTalkOS action required.

### 5.2 What to monitor

| Upstream component | Path | What to watch for |
|---|---|---|
| BoringSSL | `external/boringssl/` | ML-DSA X.509 certificate signature OID registration in `crypto/obj/objects.txt`; `EVP_PKEY` ML-DSA provider for `pkeyutl` |
| KeyMint HAL | `hardware/interfaces/security/keymint/aidl/.../Algorithm.aidl` | Addition of `ML_KEM` / `ML_DSA` enum values; corresponding `Tag` entries |
| AVB | `external/avb/avbtool.py`, `external/avb/libavb/avb_crypto.h` | New entries in `ALGORITHMS` dict beyond RSA-8192 |
| Pixel bootloader | (closed-source) | Google bootloader update shipping PQC AVB verification — out of GuardTalkOS control |
| AOSP PQC tracking | upstream Android source-of-truth | AOSP Security / Platform PQC roadmap announcements |

### 5.3 Key custody implication

If PQC is added later for AVB/OTA:
- The AVB signing key would need to be **re-generated as a (hybrid) PQ key**.
- The bootloader must support verifying the new key type — which requires a **Pixel bootloader update from Google**, out of GuardTalkOS control.
- A key migration / dual-signing window would be needed during transition.
- This is a multi-year upstream-coordinated effort, not a GuardTalkOS-local change.

---

## 6. Go/No-Go Recommendation

### 6.1 Implementation: **NO-GO**

A PQC implementation spike for the GuardTalkOS storage/boot trust chain is **NO-GO today**. Rationale:
1. The FBE block cipher (the component most commonly — and wrongly — flagged for PQC migration) is **symmetric AES-256, already PQ-safe**. There is no PQC block cipher to swap to.
2. The FBE key-wrapping path is **symmetric AES-256-GCM** (verified in `system/vold/KeyStorage.cpp`). PQ-safe. No Shor vulnerability.
3. The actual PQ-vulnerable surfaces (attestation, AVB, OTA) are **blocked on upstream tooling that does not yet exist** — KeyMint PQC AIDL, `avbtool` PQC algorithms, BoringSSL X.509 ML-DSA OIDs, and — critically — the **closed-source Pixel bootloader blob** that GuardTalkOS cannot modify.
4. BoringSSL ships ML-KEM/ML-DSA primitives, but they are wired into the **TLS layer only**, not the storage/boot path.

### 6.2 Monitoring: **GO**

GuardTalkOS should:
- Track upstream BoringSSL, KeyMint AIDL, and `external/avb` for PQC additions.
- Re-evaluate this decision when (a) KeyMint `Algorithm.aidl` gains PQC enum values, (b) `avbtool` `ALGORITHMS` gains PQC entries, AND (c) a Pixel bootloader update ships PQC AVB verification.
- Until then, the current posture (AES-256-XTS/CTS for FBE, RSA-4096 for AVB/OTA) is the only viable posture, and it is **quantum-safe for the data-at-rest layer**.

### 6.3 Explicit correction of the brief's framing

The brief correctly identifies the critical framing: **"Symmetric AES-256 is ALREADY quantum-resistant... PQC addresses ASYMMETRIC crypto... rather than 'swap the FS cipher.'"** This report confirms that framing against in-tree evidence and reinforces it: the FBE cipher swap is not merely unnecessary, it is **undefined** (no PQC block cipher standard exists). The actionable PQC items are entirely in the asymmetric path and are blocked upstream.

---

## 7. Evidence Index

| Claim | File:Line |
|---|---|
| FBE uses AES-256-XTS | `system/vold/CryptoType.h:68-71`, `system/vold/MetadataCrypt.cpp:70,76-77` |
| FBE filenames use AES-256-CTS (default for API > Q) | `system/vold/FsCrypt.cpp:357-365` |
| Adiantum is the only non-AES FBE option | `system/vold/CryptoType.h:73-76`, `system/vold/MetadataCrypt.cpp:70` |
| FBE key wrapping is symmetric AES-256-GCM (Keystore path) | `system/vold/KeyStorage.cpp:51-53,117-134,370-394` |
| FBE key wrapping is symmetric AES-256-GCM (no-Keystore path) | `system/vold/KeyStorage.cpp:434-482` |
| KeyMint `Algorithm` enum: RSA, EC, AES, TRIPLE_DES, HMAC only | `hardware/interfaces/security/keymint/aidl/.../Algorithm.aidl:25-37` |
| KeyMint `EcCurve` enum: P-224/256/384/521, Curve25519 only | `hardware/interfaces/security/keymint/aidl/.../EcCurve.aidl:25-31` |
| KeyMint `KeyParameterValue` union: no PQC variant | `hardware/interfaces/security/keymint/aidl/.../KeyParameterValue.aidl:32-54` |
| KeyMint `Tag.aidl`: RSA/EC/AES/HMAC tags only, no PQC | `hardware/interfaces/security/keymint/aidl/.../Tag.aidl` (full file) |
| AVB `ALGORITHMS` dict: NONE + 6 RSA variants only | `external/avb/avbtool.py:112-204` |
| AVB has zero PQC code (grep) | `external/avb/` — no matches for mldsa/mlkem/kyber/dilithium |
| OTA signer uses `openssl pkeyutl` with RSA/EC keys | `build/tools/releasetools/payload_signer.py:98-123` |
| BoringSSL ships ML-KEM-768 | `external/boringssl/include/openssl/mlkem.h:1-60` |
| BoringSSL ships ML-DSA-65 | `external/boringssl/include/openssl/mldsa.h:1-60` |
| BoringSSL wires ML-KEM into TLS only | `external/boringssl/src/ssl/ssl_key_share.cc:284-467`, `external/boringssl/src/ssl/extensions.cc:101-105` |
| BoringSSL X.509 has NO ML-DSA support (grep) | `external/boringssl/src/crypto/x509/` — zero matches |
| BoringSSL OID table: ML-KEM TLS-only, no ML-DSA OID | `external/boringssl/src/crypto/obj/objects.txt:1335-1340` |

---

*Report generated by AEGIS Auditor (read-only research). Gate -1 acknowledged. No files outside `vendor/guardtalk/docs/SECURITY_PQC_REPORT.md` were modified. No commits. No doctrine/governance access.*