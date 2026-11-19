# GuardTalkOS — Build, Verify & Run for Dummies

> **Honesty & Readiness Banner (Read This First)**
> - **`LIVE_FLASH_CLAIMED=false`** — Host-side scripts and documentation do **not** claim an automated live flash was executed on your phone.
> - **`BOOT_VERIFIED=false`** — Passing host verification proves image integrity and excision rules on disk; it does **not** guarantee every stamp boots on physical hardware without on-device testing.
> - **Dev / Lab UAT vs. Production Fleet:** Staged bundles currently use public **AOSP `testkey`** signing keys. They are suitable for **dev/lab UAT with an unlocked bootloader**, **not** for production locked-bootloader fleet deployment (which requires offline operator-generated release keys — see [Signing Keys](#34-signing-keys-testkey-vs-production)).

This guide walks you from zero to building, verifying, emulating, flashing, and rolling back **GuardTalkOS** in plain English. Every file path, script, `lunch` target, and flag below has been verified directly against this workspace.

If you just want to flash a pre-built image from Chrome/Chromium without using the command line, jump straight to the **[GuardTalkOS WebInstaller Guide](../web-installer/README.md)**.

---

## Table of Contents

1. [What Is GuardTalkOS? (Plain-English Overview)](#1-what-is-guardtalkos-plain-english-overview)
2. [Host Prerequisites (What You Need Before Starting)](#2-host-prerequisites-what-you-need-before-starting)
3. [Step-by-Step Source Build](#3-step-by-step-source-build)
4. [Step-by-Step Local Verification](#4-step-by-step-local-verification)
5. [Running & Flashing GuardTalkOS](#5-running--flashing-guardtalkos)
   - [Option A: Run in the Android Emulator (`emu64a` / `emu64x`)](#option-a-run-in-the-android-emulator-emu64a--emu64x)
   - [Option B: Flash a Physical Pixel via CLI (`scripts/flash-from-remote.sh`)](#option-b-flash-a-physical-pixel-via-cli-scriptsflash-from-remotesh)
   - [Option C: Flash via Browser (WebInstaller)](#option-c-flash-via-browser-webinstaller)
   - [Option D: Roll Back to Stock Android](#option-d-roll-back-to-stock-android)
6. [Troubleshooting FAQ](#6-troubleshooting-faq)

---

## 1. What Is GuardTalkOS? (Plain-English Overview)

**GuardTalkOS** is a privacy-hardened product overlay built on top of **GrapheneOS** (Android) that lives in `vendor/guardtalk/` inside this GrapheneOS `repo` checkout.

Instead of maintaining a separate OS from scratch, GuardTalkOS hooks into the Android Soong/Make build (`vendor/guardtalk/radio-excised/product-config-late.mk` and `vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk`) to **strip unwanted wireless/radio and sensor stacks** while **adding GuardTalk's own privacy features and UI overlays**.

### 1.1 What Is Excised (Removed or Blocklisted)

When `GUARDTALK_RADIO_EXCISED := true` and `GUARDTALK_FEATURE_EXCISED_WAVE2 := true` are active (all supported Pixel targets), GuardTalkOS excises:

| Surface | Build-Layer Module(s) | What It Does |
|---------|------------------------|--------------|
| **Cellular Modem / Radio & Telephony** | `vendor/guardtalk/radio-excised/`, `vendor_dlkm.modules.blocklist` | Drops RIL/telephony packages, SIM/mobile network UI, and blocklists modem transport kernel modules (`cpif.ko`, `cpif_page.ko`, `shm_ipc.ko`). |
| **Bluetooth** | `vendor/guardtalk/feature-excised/bt-excised.mk`, `vendor_dlkm` / `system_dlkm` blocklists | Removes Bluetooth userspace HALs/apps and blocklists BT kernel modules (such as `nitrous.ko`). |
| **NFC** | `vendor/guardtalk/feature-excised/nfc-excised.mk` | Strips NFC HALs, services, and `st21nfc.ko` module loading. |
| **UWB (Ultra-Wideband) & ContextHub** | `vendor/guardtalk/feature-excised/uwb-contexthub-excised.mk` | Strips UWB services/permissions and blocklists UWB/802.15.4 `.ko` modules (`aoc_uwb_*`, `qm35.ko`, `mcps802154*`). |
| **Location / GNSS** | `vendor/guardtalk/feature-excised/loc-excised.mk` | Strips GNSS/location HALs and blocklists `gnss_*` modules. |
| **Fingerprint Biometrics** | `vendor/guardtalk/feature-excised/fp-excised.mk` | Removes QFP / Goodix fingerprint HALs using the data-driven variant registry. |
| **Unneeded Stock UI Apps & Debug Tools** | `apps-excised.mk`, `userbuild-excised.mk` | Strips stock Dialer, Messaging, Browser, AppStore, Auditor, ExactCalculator, InfoApp, plus `su` / debug remounters on `user` builds. |

> **Honest Note on AOSP/Hardware Residuals:** Excision is **not** magic hardware removal. Per [`EXCISION_MATRIX.md`](EXCISION_MATRIX.md) and [`EXCISION_LEDGER.md`](EXCISION_LEDGER.md):
> - Baseband firmware (`radio.img`) is still flashed on cellular Pixels (except `tangorpro`, which has no cellular modem hardware).
> - Four AOSP/HAL-constrained artifacts remain in staged images due to Android platform/VINTF build dependencies: `com.android.telephonycore.apex`, `com.android.nfcservices.apex`, `location.provider.xml`, and (on audio-impl targets) `vendor/etc/vintf/manifest/bluetooth_audio.xml`.

### 1.2 What Features & Apps Are Included

| Component | Path | Purpose |
|-----------|------|---------|
| **Voice Filter** | `vendor/guardtalk/audio/` + `vendor/guardtalk/apps/GuardTalkVoice/` | Real-time microphone C++ DSP preprocessing (`libguardtalkvoicesw.so`) controlled via the `GuardTalkVoice` settings app (`persist.vendor.guardtalk.voice.*`). See [`VOICE_FILTER.md`](VOICE_FILTER.md). |
| **Face Persona Filter** | `vendor/guardtalk/camera/` + `vendor/guardtalk/apps/GuardTalkFace/` | Camera2 Beauty extension override (`libguardtalkface_jni.so`) controlled via `GuardTalkFace` (`persist.vendor.guardtalk.face.*`). See [`FACE_FILTER.md`](FACE_FILTER.md). |
| **GuardTalkConfig** | `vendor/guardtalk/apps/GuardTalkConfig/` | Device configuration and provisioning helper app. |
| **GuardTalkValidator** | `vendor/guardtalk/apps/GuardTalkValidator/` | On-device validation helper app. |
| **System & UI Overlays (12 RROs)** | `vendor/guardtalk/overlays/` | Framework, Settings, SettingsProvider, SystemUI, SetupWizard, Launcher, branding, and icon Runtime Resource Overlays (`GuardTalk*Overlay`). |
| **GuardTalk Check-in (Host Contract & Source)** | `vendor/guardtalk/apps/GuardTalkCheckin/` + `vendor/guardtalk/checkin/` | 12-hour seizure check-in source and host contract test suite (`verify_host.sh`). **Note:** Default preinstall wiring in `PRODUCT_PACKAGES` is currently decommissioned (verified by `verify_host.sh`). See [`SEIZURE_CHECKIN.md`](SEIZURE_CHECKIN.md). |

> **Note on Purged Apps:** `GuardTalkMessenger` has been **permanently purged** from `vendor/guardtalk/` and is **not** installed. Do not look for or reference it as a shipped app.

### 1.3 Supported Devices (14 Pixel Targets + Emulator)

All 14 physical Pixel codenames below exist under `vendor/guardtalk/device/<codename>/`, are tracked in [`device-alignment-matrix.json`](device-alignment-matrix.json), and have `<codename>-latest` bundles staged under `releases/desktop-flash/`:

| Codename | Marketing Model | SoC | Excision Variant (`EXCISION_MATRIX.md`) | `lunch` Target |
|----------|-----------------|-----|-----------------------------------------|----------------|
| `shiba` | Pixel 8 | `zuma` | `zuma_shusky` | `shiba-cur-user` |
| `husky` | Pixel 8 Pro | `zuma` | `zuma_shusky` | `husky-cur-user` |
| `akita` | Pixel 8a | `zuma` | `zuma_akita` | `akita-cur-user` |
| `tokay` | Pixel 9 | `zumapro` | `zumapro_caimito` | `tokay-cur-user` |
| `caiman` | Pixel 9 Pro | `zumapro` | `zumapro_caimito` | `caiman-cur-user` |
| `komodo` | Pixel 9 Pro XL | `zumapro` | `zumapro_caimito` | `komodo-cur-user` |
| `comet` | Pixel 9 Pro Fold | `zumapro` | `zumapro_comet` | `comet-cur-user` |
| `tegu` | Pixel 9a | `zumapro` | `zumapro_tegu` | `tegu-cur-user` |
| `stallion` | Pixel 10a | `zumapro` | `zumapro_stallion` | `stallion-cur-user` |
| `frankel` | Pixel 10 | `laguna` | `laguna_muzel` | `frankel-cur-user` |
| `blazer` | Pixel 10 Pro | `laguna` | `laguna_muzel` | `blazer-cur-user` |
| `mustang` | Pixel 10 Pro XL | `laguna` | `laguna_muzel` | `mustang-cur-user` |
| `rango` | Pixel 10 Pro Fold | `laguna` | `laguna_rango` | `rango-cur-user` |
| `tangorpro` | Pixel Tablet | `gs201` (Wi-Fi only) | *(no cellular radio hardware)* | `tangorpro-cur-user` |
| `emu64a` / `emu64x` | Android Emulator | Goldfish (ARM64 / x86_64) | *(userspace testing only)* | `guardtalk_emu64a-trunk_staging-userdebug` |

---

## 2. Host Prerequisites (What You Need Before Starting)

You need a **64-bit Linux** machine (Ubuntu 22.04/24.04 or Debian recommended) to build Android/GrapheneOS from source. Flashing via CLI or WebInstaller can be done from Linux or macOS.

### Hardware Requirements (for Building from Source)
- **CPU:** Multi-core x86_64 (8+ cores strongly recommended; virtualization `vmx`/`svm` needed for the emulator).
- **RAM:** **32 GB minimum** (64 GB recommended for parallel Soong/Ninja builds without OOM kills).
- **Disk:** **350–450+ GB** of free SSD/NVMe space (the GrapheneOS tree + `out/` build artifacts + staged `releases/desktop-flash/` images are large).

### Software Requirements
1. **Android `repo` & Build Tools:** Standard AOSP/GrapheneOS Linux build dependencies (`git`, `curl`, `unzip`, `zip`, `rsync`, `openssl`, `e2fsprogs` / `debugfs`, `jq`). Soong and Ninja are bundled inside the workspace (`build/envsetup.sh`).
2. **Android Platform Tools (`adb` and `fastboot`):**
   - Must be recent enough for Pixel 8/9/10 dynamic partitions (`fastbootd`).
   - Verify with `fastboot --version` and `adb --version`.
3. **Linux USB `udev` Rules (for physical Pixels):**
   - Install `android-sdk-platform-tools-common` (Debian/Ubuntu) or add a rule in `/etc/udev/rules.d/51-android.rules` for Google USB vendor ID `18d1`:
     ```bash
     echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/51-android.rules
     sudo udevadm control --reload-rules && sudo udevadm trigger
     ```
   - Make sure your user is in `plugdev` (`sudo usermod -aG plugdev "$USER"`, then log out and back in).
4. **Node.js (LTS, v20+):** Required by `vendor/adevtool/` (vendor blob generator) and `vendor/guardtalk/web-installer/`.
5. **Python 3 (standard library only):**
   - Used by host contract tests and helper scripts.
   - **Important:** There is **no `pytest` suite** at this workspace root. Always use `python3 -m unittest`.
6. **KVM (only if running the Android emulator):** See [`KVM.md`](KVM.md) and Option A below.

---

## 3. Step-by-Step Source Build

Run all build commands from the **workspace root** (`/path/to/GrapheneOS-worktree`).

### 3.1 Prepare Vendor Blobs with `adevtool` (First Time or After Upstream Updates)

GrapheneOS uses `adevtool` (`vendor/adevtool/README.md`) to extract proprietary vendor blobs from stock Google Pixel factory images into `vendor/google_devices/<codename>/`.

```bash
source build/envsetup.sh
m adevtool
adevtool generate-all -d <codename>
```

> **CRITICAL WARNING:** Running `adevtool generate-all -d <codename>` **overwrites** `vendor/google_devices/<codename>/<codename>.mk` and `BoardConfig.mk` with stock GrapheneOS files!
> After regenerating blobs, you **must** re-apply the GuardTalk include hooks (`BoardConfig-excised-late.mk`, `guardtalk-radio-excised.mk`, `guardtalk-insmod.mk`, etc.) following **[`vendor/guardtalk/device/REGEN_HOOKS.md`](../device/REGEN_HOOKS.md)** (and [`vendor/guardtalk/device/tokay/REGEN_HOOKS.md`](../device/tokay/REGEN_HOOKS.md) for the reference `tokay` layout).

### 3.2 Configure Environment and Choose Your Target (`lunch`)

Replace `<device>` with one of the 14 Pixel codenames (for example, `tokay` for Pixel 9):

```bash
source build/envsetup.sh
lunch tokay-cur-user
```

- `cur` = current GrapheneOS release configuration.
- `user` = hardened production-style build (`ro.build.type=user`, `ro.debuggable=0`, no `/system/xbin/su`).

### 3.3 Clean & Build (`m installclean && m`)

Always run `m installclean` before building a target (especially when switching devices or after editing any GuardTalk excision `.mk` files) so stale files from previous builds cannot sneak into `out/target/product/<device>/`:

```bash
# If you edited vendor/guardtalk/radio-excised/*.mk or feature-excised/*.mk,
# also clear Soong's cached product variables first:
rm -f out/soong/soong.tokay.variables out/soong/soong.tokay.extra.variables

# Clean stale installed output and build:
m installclean
m -j"$(nproc)"
```

Compiled partition images (`boot.img`, `system.img`, `system_ext.img`, `product.img`, `vendor.img`, `vendor_dlkm.img`, `vbmeta*.img`, `super.img`, etc.) land in `out/target/product/<device>/`.

### 3.4 Signing Keys (`testkey` vs. Production)

Understanding Android Verified Boot (AVB) keys prevents confusion:

- **Default Dev / Lab UAT (`testkey`):** Standard `m` builds and the current staged bundles under `releases/desktop-flash/` are signed with public **AOSP `testkey`** keys (`avb_pkmd.bin` matches AOSP `testkey_rsa4096.pem`). Anyone on the internet has the public AOSP testkey — so **never** treat a `testkey` build as a production security boundary.
- **Production Fleet Signing (Operator Release Keys):** Before deploying locked-bootloader production devices, generate your own private keys on an **offline, air-gapped machine** and sign `m dist` target-files:
  1. Generate keys offline: `vendor/guardtalk/scripts/generate-signing-keys.sh`
  2. Sign a release bundle: `vendor/guardtalk/scripts/sign-build.sh`
  3. Full architecture & key ceremony rules: [`vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md`](SECURITY_SIGNING_REPORT.md).

### 3.5 Release Staging (`releases/desktop-flash/`)

Flashable desktop bundles live under `releases/desktop-flash/`:

```text
releases/desktop-flash/
├── <codename>-<YYYYMMDD-HHMMSS>/   # Timestamped image bundle + SHA256SUMS + avb_pkmd.bin
├── <codename>-latest -> <codename>-<YYYYMMDD-HHMMSS>   # Active pointer symlink
├── <codename>-rescue-boot/         # Stock factory rescue boot chain (laguna devices)
├── <codename>-rescue-cp1a/         # CP1A rescue boot chain (frankel, blazer)
└── acks/
    └── <codename>.ack              # Operator acknowledgement binding exact stamp + SHA256SUMS
```

Every staged bundle carries a `SHA256SUMS` manifest verified before flashing, and an operator acknowledgement file in `releases/desktop-flash/acks/<codename>.ack` that cryptographically binds the device codename, exact stamp directory name, and `SHA256SUMS` SHA-256 digest.

---

## 4. Step-by-Step Local Verification

Run these checks **from the workspace root** before flashing anything.

### 4.1 Core Host Verification (Always Runnable, No Build Output Needed)

```bash
# 1. GuardTalk check-in host contract & wiring checks (expects PASS=21 FAIL=0 HOLD=2)
bash vendor/guardtalk/checkin/host/verify_host.sh

# 2. Python stdlib unit tests (expects Ran 13 tests ... OK; do NOT use pytest)
python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v

# 3. Bluetooth VINTF excision self-test (or pass --device <codename> / --forbid bt+radio)
vendor/guardtalk/scripts/verify-bt-vintf-excision.sh
```

### 4.2 Build-Output Acceptance Checks (After Running `m`)

Point `PRODUCT_OUT` / `OUT_DIR` at your built target (defaults to `out/target/product/tokay`):

```bash
# Modem / radio excision check
PRODUCT_OUT=out/target/product/tokay vendor/guardtalk/scripts/verify-radio-excision.sh

# Voice filter check
OUT_DIR=out/target/product/tokay vendor/guardtalk/scripts/verify-voice-filter.sh

# Face persona filter check
OUT_DIR=out/target/product/tokay vendor/guardtalk/scripts/verify-face-filter.sh

# Vendor HAL shared-library (DT_NEEDED) closure check (prevents boot loops from missing libs)
vendor/guardtalk/scripts/verify-vendor-hal-deps.sh
```

### 4.3 Static & Host QA Verify Scripts (72 Scripts)

GuardTalkOS ships 72 QA verify scripts under `vendor/guardtalk/docs/qa/verify_*.sh`. Always invoke them with `bash` (some are not marked executable):

```bash
# Example: verify the shared excision variant matrix across all devices
bash vendor/guardtalk/docs/qa/verify_port_excision_matrix_static.sh

# Example: verify adevtool guard uniformity
bash vendor/guardtalk/docs/qa/verify_adevtool_guard_uniform_static.sh

# Pattern for any static or host QA script:
bash vendor/guardtalk/docs/qa/verify_<name>_static.sh
bash vendor/guardtalk/docs/qa/verify_<name>_host.sh
```

### 4.4 Release Readiness Report (`scripts/gt-ready-devices.sh`)

Check which staged bundles in `releases/desktop-flash/` pass `SHA256SUMS`, excision checks, and operator `.ack` validation (read-only; takes ~30–60s because it hashes all staged images):

```bash
# Human-readable TSV table
bash scripts/gt-ready-devices.sh

# Machine-readable JSON with per-clause provenance
bash scripts/gt-ready-devices.sh --json

# Fail (exit 1) unless every device is READY or READY-ACK
bash scripts/gt-ready-devices.sh --strict
```

Status meanings:
- **`READY-ACK`** — All host gates pass AND a valid `releases/desktop-flash/acks/<dev>.ack` binds this exact stamp + `SHA256SUMS`. Flashable for UAT (`BOOT_VERIFIED=false`).
- **`HOLD`** — Host gates pass, but no valid operator `.ack` exists for this stamp.
- **`BUILD-OK`** — Bundle is intact on the host, but boot is unverified (e.g., Laguna family) or carries an unresolved risk block. Requires explicit stamp-pinned `GT_ALLOW_BUILD_OK=<stamp-id>` to flash.
- **`PENDING`** — One or more host gate clauses failed.

---

## 5. Running & Flashing GuardTalkOS

### Option A: Run in the Android Emulator (`emu64a` / `emu64x`)

Pixel hardware images **cannot** boot on the Android emulator (different kernel/HALs). Use the dedicated GuardTalk emulator target to test GuardTalk userspace (apps, overlays, voice/face libs, `ro.guardtalk.*` properties) without a physical phone. Full details live in [`EMULATOR.md`](EMULATOR.md) and [`KVM.md`](KVM.md).

```bash
# 1. Check KVM hardware acceleration (required on headless Linux)
vendor/guardtalk/scripts/check-kvm.sh

# If /dev/kvm permission is denied, add your user to the kvm group once and re-login:
#   sudo gpasswd -a "$USER" kvm

# 2. Build and boot headless (defaults to guardtalk_emu64a-trunk_staging-userdebug
#    when KVM is available, or guardtalk_emu64x-trunk_staging-userdebug on x86_64 without KVM)
HEADLESS=1 vendor/guardtalk/scripts/run-emulator.sh

# Useful flags:
#   WIPE=1 HEADLESS=1 vendor/guardtalk/scripts/run-emulator.sh   # wipe userdata
#   vendor/guardtalk/scripts/run-emulator.sh --build-only        # compile only
```

Once booted, inspect GuardTalk properties and packages via `adb`:

```bash
adb shell getprop | grep guardtalk
adb shell pm list packages | grep guardtalk
```

---

### Option B: Flash a Physical Pixel via CLI (`scripts/flash-from-remote.sh`)

> **Before You Plug In Your Phone:**
> 1. Back up all data — flashing **wipes userdata and metadata**.
> 2. Enable **Developer Options → OEM Unlocking** in Android Settings, reboot into the bootloader (**Power + Volume Down**), and unlock the bootloader (`fastboot flashing unlock`).
> 3. Confirm `fastboot devices` shows **only** the single target Pixel you intend to flash.

`scripts/flash-from-remote.sh` is the canonical multi-device CLI flasher. It pulls a staged bundle from `REMOTE_HOST:REMOTE_BUILD_DIR` (or locally), checks the quarantine registry, verifies readiness + `acks/<dev>.ack`, flashes bootloader (both slots) + radio + `avb_pkmd.bin`, enters `fastbootd` to flash logical partitions (`system`, `system_ext`, `product`, `vendor`, `vendor_dlkm`, `system_dlkm`), then flashes the boot chain and `vbmeta*`.

#### Step 1: Run Dry-Run / Pre-Flight Checks First (Zero Writes to Device)

```bash
# 1. Quarantine check only (refuses quarantined or below-floor stamps)
DEVICE=tokay GT_FLASH_QUARANTINE_CHECK_ONLY=1 bash scripts/flash-from-remote.sh

# 2. Readiness + operator ack check only
DEVICE=tokay GT_READY_CHECK_ONLY=1 bash scripts/flash-from-remote.sh

# 3. Print full resolved flash plan without touching any device
DEVICE=tokay GT_FLASH_PLAN_ONLY=1 bash scripts/flash-from-remote.sh
```

#### Step 2: Flash Standard Non-Laguna Pixel (e.g., `tokay`, `akita`, `caiman`, `komodo`, `stallion`)

```bash
export REMOTE_HOST="oss-c1@192.168.2.220"   # adjust to your build host
export DEVICE="tokay"
bash scripts/flash-from-remote.sh
```

#### Step 3: Flash Laguna Family (`frankel`, `blazer`, `mustang`, `rango`) with Hybrid Boot Chain

On Pixel 10 (`laguna`) devices, if the full GuardTalk boot chain is ABL-rejected or a stamp is classified `BUILD-OK`, use the operator opt-in hybrid boot chain (`GT_BOOT_CHAIN=hybrid`) together with the exact stamp ID (`GT_ALLOW_BUILD_OK`) and the matching CP1A rescue boot directory (`REMOTE_RESCUE_DIR`):

```bash
export REMOTE_HOST="oss-c1@192.168.2.220"
export DEVICE="frankel"
export GT_BOOT_CHAIN="hybrid"
export GT_ALLOW_BUILD_OK="$(basename "$(readlink -f releases/desktop-flash/frankel-latest)")"
export REMOTE_RESCUE_DIR="/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/frankel-rescue-cp1a"
bash scripts/flash-from-remote.sh
```

*(For `rango` or `mustang`, use `releases/desktop-flash/<dev>-rescue-boot` if `<dev>-rescue-cp1a` is not present.)*

#### Security & Device Notes for CLI Flashing
- **AVB & `dm-verity` Enabled by Default:** `scripts/flash-from-remote.sh` flashes all `vbmeta*` partitions with AVB and `dm-verity` **enabled by default**. It only passes `--disable-verity --disable-verification` if you explicitly set `GT_FLASH_DISABLE_VERITY=1` (lab debugging only — weakens verified boot).
- **Unlocked Bootloader & `testkey`:** Because current staged bundles use AOSP `testkey`, keep the bootloader **unlocked** during dev/lab UAT and treat the device as a UAT unit, not a hardened production phone.
- **Pixel Tablet (`tangorpro`):** Has no cellular radio hardware (step-2 `radio.img` is skipped) and uses a single `vbmeta.img` (no `vbmeta_system.img` / `vbmeta_vendor.img`), with mandatory two-phase stock-boot-chain `fastbootd` handling.
- **Post-Flash On-Device Check:** After your device boots and USB debugging is enabled, run:
  ```bash
  vendor/guardtalk/scripts/verify-on-device.sh
  ```

---

### Option C: Flash via Browser (WebInstaller)

Prefer a point-and-click GrapheneOS-style browser wizard over the CLI? Use the **GuardTalkOS WebInstaller** (Chromium/Chrome WebUSB over HTTPS, all 14 Pixel targets packed):

👉 **[`vendor/guardtalk/web-installer/README.md`](../web-installer/README.md)**

---

### Option D: Roll Back to Stock Android

If a GuardTalk build fails to boot or you want to return your Pixel to pure Google stock Android, two verified scripts exist:

#### 1. Hash-Verified Rollback Tool (`vendor/guardtalk/scripts/gt-rollback-to-stock.sh`)
Pinned against `vendor/guardtalk/scripts/gt-rollback-manifest.tsv` (fail-closed — refuses any missing or tampered artifact):

```bash
# Inspect rollback plan (read-only, touches nothing)
bash vendor/guardtalk/scripts/gt-rollback-to-stock.sh plan --device tokay

# Verify SHA-256 digests of stock factory zips on disk (read-only)
bash vendor/guardtalk/scripts/gt-rollback-to-stock.sh attest --device tokay

# Laguna-only Tier-1 rescue: re-flash stock rescue boot chain to regain fastbootd
bash vendor/guardtalk/scripts/gt-rollback-to-stock.sh unbrick --device blazer

# Execute factory restore (WIPES DEVICE — requires explicit confirmation flag)
bash vendor/guardtalk/scripts/gt-rollback-to-stock.sh execute \
  --device tokay \
  --i-understand-this-erases-the-device
```

*(Bootloader/radio firmware are NOT reflashed by default to avoid anti-rollback bricks; add `--flash-firmware --allow-firmware-flash` only when intentionally updating firmware.)*

#### 2. Stock CP1A Flash + Kernel Log Recovery (`scripts/gt-flash-stock.sh`)
Flashes pure stock CP1A (erasing `avb_custom_key` and wiping userdata/metadata) and recovers the previous failed GuardTalk boot's `pstore` kernel log via `dumpsys dropbox`:

```bash
DEVICE=blazer bash scripts/gt-flash-stock.sh
```

---

## 6. Troubleshooting FAQ

### Q: `fastboot devices` returns nothing (or `no permissions`) on Linux
- **Cause:** Missing udev rules, charge-only USB cable, or phone not in bootloader mode.
- **Fix:**
  1. Ensure the phone is in bootloader mode (hold **Power + Volume Down** while powering on).
  2. Use a known-good **USB-C data cable** plugged directly into a host USB port (avoid unpowered hubs).
  3. Install the `18d1` udev rule from [Section 2](#2-host-prerequisites-what-you-need-before-starting) and re-login so `plugdev` group membership takes effect.

### Q: My build succeeded, but an old app/library is still in the image or camera/settings crash
- **Cause:** Stale build artifacts left in `out/` from an earlier build or another device.
- **Fix:** Always run `m installclean` before `m`. If you edited any `radio-excised/*.mk` or `feature-excised/*.mk` file, also delete `out/soong/soong.<device>.variables` and `out/soong/soong.<device>.extra.variables`.

### Q: `flash-from-remote.sh` refuses with `BUILD-OK` or `HOLD`
- **Cause:** Fail-closed safety gate.
  - **`HOLD`:** The bundle passed host checks, but `releases/desktop-flash/acks/<dev>.ack` is missing or its `stamp`/`sha256sums_sha256` does not match the current `<dev>-latest` stamp.
  - **`BUILD-OK`:** The bundle is not boot-verified (e.g., Laguna family). You must pass the **exact** stamp directory name via `GT_ALLOW_BUILD_OK=<stamp-id>` (never `1` or empty — the script rejects boolean overrides).

### Q: Laguna (`frankel` / `blazer` / `mustang` / `rango`) hangs at the Google logo when entering `fastbootd`
- **Cause:** Attempting to enter `fastbootd` after flashing a GuardTalk boot chain, or missing/mismatched `REMOTE_RESCUE_DIR`.
- **Fix:** Use `scripts/flash-from-remote.sh` (which flashes the stock rescue boot chain *before* `fastbootd`), and for hybrid mode explicitly set `GT_BOOT_CHAIN=hybrid` and `REMOTE_RESCUE_DIR=releases/desktop-flash/<dev>-rescue-cp1a` (for `frankel`/`blazer`) or `<dev>-rescue-boot`.

### Q: Phone shows a yellow/orange warning screen on boot about an unlocked bootloader / custom OS
- **Cause:** Normal for an unlocked bootloader and/or custom `avb_pkmd.bin` (currently AOSP `testkey`).
- **Fix:** Expected during dev/lab UAT. Never lock the bootloader with AOSP `testkey` images for production use — see [Section 3.4](#34-signing-keys-testkey-vs-production).

### Q: Emulator fails with `/dev/kvm: Permission denied` or takes 30+ minutes
- **Cause:** Your Linux user is not in the `kvm` group, or you are inside a VM without nested virtualization.
- **Fix:** Run `vendor/guardtalk/scripts/check-kvm.sh`, add your user via `sudo gpasswd -a "$USER" kvm`, open a new shell/SSH session, and re-run `HEADLESS=1 vendor/guardtalk/scripts/run-emulator.sh`. See [`KVM.md`](KVM.md).

### Q: Where is `pytest`? Running `pytest` fails at the repo root!
- **Cause:** This root is a GrapheneOS Android checkout, not a Python/pytest project.
- **Fix:** Run `python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v` instead.

---

## Further Reading

- **[GuardTalkOS Vendor Layer Index](../README.md)**
- **[GuardTalkOS WebInstaller Guide](../web-installer/README.md)**
- **[Excision Variant Matrix](EXCISION_MATRIX.md)** & **[Excision Residual Ledger](EXCISION_LEDGER.md)**
- **[Emulator Guide](EMULATOR.md)** & **[KVM Setup](KVM.md)**
- **[Voice Filter](VOICE_FILTER.md)** & **[Face Persona Filter](FACE_FILTER.md)**
- **[Signing Keys & Security Report](SECURITY_SIGNING_REPORT.md)**
- **[Add-a-Device / `adevtool` Hook Recipe](../device/REGEN_HOOKS.md)**
