# GuardTalkOS OEM Device Hardware Specification

**Document:** OEM-DEV-SPEC-001
**Version:** 1.0 (Draft for OEM discussion)
**Date:** 2026-08-02
**Audience:** ODM/OEM hardware and platform engineering teams
**Classification:** Partner-confidential

---

## 1. Purpose

GuardTalkOS is a hardened, WiFi-only Android operating system (GrapheneOS-class fork) targeting
high-security enterprise and government deployments. We are seeking an OEM/ODM partner to
produce a purpose-built device meeting the requirements below.

This specification is derived from the publicly documented GrapheneOS future-device
requirements (https://grapheneos.org/faq#future-devices), the Android CDD, and the
Android Ready SE Alliance program, adapted for a **WiFi-only product with no cellular
modem**.

Devices that currently meet the full bar: Google Pixel 8/9/10 series only.
Motorola is building to this bar for 2027. This document defines how a new OEM device
can meet the same bar.

---

## 2. Product Definition

| Item | Specification |
|---|---|
| Product type | WiFi-only secure handheld or tablet |
| Cellular modem | **None required** (no baseband, no SIM, no eSIM) |
| Radios present | WiFi 6E/7 only. Bluetooth/NFC/GNSS optional (software-excised in current builds) |
| OS | GuardTalkOS (AOSP/GrapheneOS-based), signed with GuardTalk or customer keys |
| Boot state after sale | **Locked bootloader, customer/GuardTalk AVB root of trust** |

**WiFi-only is a cost and security advantage for the OEM:** removing the modem eliminates
baseband firmware cost, carrier certification, PTCRB/GCF, and the entire cellular attack
surface and its isolation requirements.

---

## 3. Hard Requirements (MUST)

### 3.1 Boot & Verified Boot

| # | Requirement | Notes |
|---|---|---|
| B1 | Bootloader unlock via standard fastboot (`fastboot flashing unlock`) | No per-device server approval, no account binding, no quota |
| B2 | **User-settable root of trust**: `avb_custom_key` partition, flashable/erasable only while unlocked | Must actually be honored at boot (not silently ignored) |
| B3 | Relock with custom key (`fastboot flashing lock`) boots a custom-signed OS in LOCKED state | AVB "yellow" state acceptable at boot screen |
| B4 | AVB 2.0 with rollback protection for OS **and** firmware partitions | Rollback indices in RPMB or SE |
| B5 | Yellow-state boot screen displays verified-boot key fingerprint as full SHA-256 (non-truncated) | Per AOSP device-state spec |
| B6 | A/B seamless updates for firmware and OS with automatic rollback on boot failure | |
| B7 | Bootloader reports `ro.boot.vbmeta.public_key_digest` via bootconfig | Enables runtime key verification |

### 3.2 Secure Element (SE) — StrongBox

| # | Requirement | Notes |
|---|---|---|
| S1 | Discrete SE or integrated SPU running **StrongBox KeyMint 3.0** | Android Ready SE certified applet |
| S2 | **Weaver HAL implemented in the SE** (not TEE) — LSKF throttling with slot wipe | Android 17 latest-generation SE rate limiting |
| S3 | Hardware key attestation for StrongBox, incl. **attest key** support for pinning | |
| S4 | **Insider attack resistance**: SE firmware updates rejected until Owner user authenticates | As Pixel Titan M2 |
| S5 | SE survives factory reset correctly (Weaver slots wiped, keys destroyed) | |
| S6 | Inline disk encryption acceleration (UFS ICE) with wrapped-key support | |

**Acceptable SE silicon (Android Ready SE Alliance, KeyMint 2.0/3.0 certified):**

| Vendor | Parts | Notes |
|---|---|---|
| NXP | SN300, SN220, SE060 | Most common in flagships |
| Thales | Connected eSE 4.2.3 / 5.3.4 | |
| **Goodix** | GSEA0, GSE20, GSN11, GSN22 | Chinese vendor, KeyMint 3.0 |
| **Tongxin Micro** | THN41, T10-Mobile | Chinese vendor, KeyMint 3.0 |
| Giesecke+Devrient | Sm@rtSIM CX Copernicus2.0M | eSIM-form (if eSIM variant ever needed) |
| STMicroelectronics | ST54L2x series | |
| Kigen | THD89-2048 | |
| Qualcomm | SPU (integrated in Snapdragon 8-series) | If Snapdragon SoC chosen |

### 3.3 SoC & CPU Security

| # | Requirement | Notes |
|---|---|---|
| C1 | **ARM MTE (Memory Tagging Extension)** enabled and exposed to the OS | Non-negotiable |
| C2 | PAC (pointer authentication) + BTI (branch target identification) | ARMv9 baseline |
| C3 | PXN/PAN (SMEP/SMAP equivalents) | |
| C4 | Hardware-accelerated virtualization usable by the OS (pKVM-class) | Protected KVM preferred |
| C5 | 64-bit-only device support code | |
| C6 | GKI kernel: Linux **6.6 or 6.12** LTS | 6.1 acceptable for existing designs |

**SoC options ranked:**

| Rank | SoC family | MTE | Notes |
|---|---|---|---|
| 1 | **MediaTek Dimensity 9300/9400/9500** | ✅ Armv9 Cortex-X4/X925 — MTE in silicon since D9300 | Fastest path; vivo X100 demonstrated MTE dev program |
| 2 | **Qualcomm Snapdragon 8 Elite Gen 5+** | ✅ Expected from this generation (Qualcomm security roadmap enabling GrapheneOS-Motorola 2027) | Includes SPU (integrated SE) |
| 3 | Samsung Exynos flagship | ✅ select models | Supply/licensing constraints |
| — | Older Snapdragon (8 Gen 3 and earlier) | ❌ custom cores lack MTE | Not acceptable |

### 3.4 Hardware Isolation

| # | Requirement |
|---|---|
| I1 | IOMMU isolation for GPU, WiFi, media encode/decode, image signal processor, storage |
| I2 | No shared-memory attack surface between WiFi firmware and AP without IOMMU mediation |
| I3 | Camera/microphone gated by hardware or firmware-level controls exposable to the OS |

### 3.5 USB

| # | Requirement |
|---|---|
| U1 | Hardware-level USB data disable in the USB controller (OS-controllable) |
| U2 | Full USB port disable (data + power role control) at hardware level |
| U3 | USB data must default to off at boot until OS policy applies |

### 3.6 Debug & Physical Attack Surface

| # | Requirement |
|---|---|
| D1 | JTAG / serial debug inaccessible while device is locked |
| D2 | Reset-attack mitigation: fastboot/boot modes zero residual OS memory before exposing attack surface (e.g. USB) |
| D3 | No test points or firmware paths that bypass AVB in production fusing |

### 3.7 WiFi

| # | Requirement |
|---|---|
| W1 | MAC address randomization (per-SSID, stable per network) |
| W2 | Probe request sequence number randomization; no leaked identifiers in probe/assoc frames |
| W3 | WiFi firmware updates shipped as part of monthly OTA train (see §4) |
| W4 | WiFi 6E (802.11ax 6 GHz) minimum; WiFi 7 preferred |

### 3.8 Biometrics (optional in v1)

Fingerprint and face hardware are **not required** (current GuardTalkOS builds excise them).
If included: under-display or side fingerprint with TEE/SE-bound enrollment; no vendor
biometric co-processor with un-auditable firmware.

---

## 4. Software & Update Commitments (MUST)

| # | Requirement | Notes |
|---|---|---|
| F1 | **7 years** of full security updates from launch (firmware, kernel, drivers, HALs) | Pixel 8+ standard; 5 years absolute minimum |
| F2 | Monthly Android Security Bulletin patches shipped **within 7 days** of ASB publication | Early ASB access via OEM program expected |
| F3 | Device support code migrated to new AOSP monthly/quarterly/yearly releases within months | |
| F4 | Complete kernel + vendor source drop (GPL) plus redistributable binary blobs for all hardware | Enables reproducible OS builds |
| F5 | Firmware updates delivered via the same A/B OTA mechanism as the OS | No PC-only flashing tools for field updates |
| F6 | Signed factory images + OTA packages published with deterministic build support where possible | |

---

## 5. What GuardTalk Provides

- GuardTalkOS source integration layer (device makefiles, excision profiles, VINTF manifests)
- OS hardening: hardened_malloc, MTE enforcement, USB protection, auto-reboot, duress/anti-bruteforce
- OTA update infrastructure and release signing (or customer-held keys)
- Security documentation and audit trail (see `vendor/guardtalk/docs/`)
- QA verification suites (static + on-device)

---

## 6. Acceptance Test Plan (OEM must pass before MP)

| # | Test | Pass criteria |
|---|---|---|
| T1 | Unlock → flash `avb_custom_key` → flash custom-signed OS → relock → boot | Boots LOCKED with custom root of trust; yellow screen shows full SHA-256 fingerprint |
| T2 | `avbroot avb verify-device` | All partitions verify against custom key |
| T3 | Rollback: flash older signed build | Boot rejected by rollback index |
| T4 | StrongBox: `FEATURE_STRONGBOX_KEYSTORE`, KeyMint 3.0 attestation chain | Valid attest key chain to SE root |
| T5 | Weaver: 20 wrong PIN attempts | Exponential backoff enforced in SE; no offline attack path |
| T6 | Insider resistance: SE firmware update without Owner auth | Rejected |
| T7 | MTE: `adb shell cat /proc/cpuinfo | grep mte` + MTE test app | MTE present and functional (SYNC/ASYNC) |
| T8 | USB: hardware data-off toggle | No data lines enumerated when disabled |
| T9 | JTAG/UART on locked device | Inaccessible |
| T10 | WiFi: probe/assoc frame capture | Randomized MAC + seq numbers, no static identifiers |
| T11 | OTA: monthly ASB build applied via A/B | Seamless update + auto-rollback on induced boot failure |

---

## 7. Reference Evidence (why these requirements)

- GrapheneOS future-device requirements: https://grapheneos.org/faq#future-devices
- Android Ready SE Alliance supported chipsets: https://developers.google.com/android/security/android-ready-se/supported-chipsets
- Weaver HAL (AOSP): https://source.android.com/docs/security/features/authentication/weaver
- AVB device state / user-settable root of trust: https://source.android.com/docs/security/features/verifiedboot/device-state
- Known-good `avb_custom_key` implementations (proof it is achievable by non-Google OEMs):
  Nothing Phone (1)/(2)/(3)/(3a)/(4a); Sony Xperia 1 II/1 V/1 VI/10 V
  (https://github.com/chenxiaolong/avbroot/issues/299)
- Known-broken implementations to avoid: Xiaomi (flash accepted, key ignored → brick),
  OnePlus 11+ (custom key registration bricks device)
- MTE in MediaTek Dimensity 9300 (Arm TCS23): https://newsroom.arm.com/news/tcs23-mediatek-vivo
- Qualcomm SPU StrongBox: Snapdragon 8-series product briefs; GrapheneOS-Motorola 2027 program

---

## 8. Commercial / Engagement Notes (for discussion)

| Item | Expectation |
|---|---|
| NRE | OEM quotes platform bring-up; GuardTalk provides OS integration engineering |
| MOQ | TBD — WiFi-only SKU reduces BOM (no modem, no RF front-end, no carrier cert) |
| Keys | Production signing keys held by customer or GuardTalk HSM; OEM never holds release keys |
| Branding | GuardTalkOS or customer brand; OEM silicon/board branding per agreement |
| Certifications | No cellular certs needed; CE/FCC for WiFi only; optional Common Criteria roadmap |

---

*Prepared by GuardTalkOS engineering. Technical contact: [TBD]*
