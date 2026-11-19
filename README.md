# GuardTalkOS Vendor Layer

Product overlay for the **GuardTalkOS** GrapheneOS fork (`vendor/guardtalk/`).

> **New here? Start with the beginner guides:**
> - 📘 **[Build, Verify & Run for Dummies (`docs/BUILD_AND_RUN_FOR_DUMMIES.md`)](docs/BUILD_AND_RUN_FOR_DUMMIES.md)** — plain-English step-by-step walkthrough for prerequisites, building from source, running host/QA checks, testing in the emulator, CLI flashing, and stock rollback.
> - 🌐 **[GuardTalkOS WebInstaller Guide (`web-installer/README.md`)](web-installer/README.md)** — browser-based (WebUSB) flashing walkthrough for all 14 supported Pixel targets.

> **Readiness & Honesty Disclosure:** `LIVE_FLASH_CLAIMED=false` · `BOOT_VERIFIED=false`. Current staged bundles under `releases/desktop-flash/` use **AOSP `testkey`** signing keys and are intended for **dev/lab UAT with an unlocked bootloader**, not production locked-bootloader fleets (production requires offline operator release keys via `scripts/generate-signing-keys.sh` + `scripts/sign-build.sh`).

---

## Quickstart (Workspace Root)

```bash
# 1. Host contract & unit verification (no build output required; stdlib unittest — no pytest at root)
bash vendor/guardtalk/checkin/host/verify_host.sh
python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v
vendor/guardtalk/scripts/verify-bt-vintf-excision.sh

# 2. Build a Pixel target (example: tokay = Pixel 9; 14 Pixel codenames supported)
source build/envsetup.sh
lunch tokay-cur-user
m installclean && m -j"$(nproc)"

# 3. Verify build outputs
PRODUCT_OUT=out/target/product/tokay vendor/guardtalk/scripts/verify-radio-excision.sh
OUT_DIR=out/target/product/tokay vendor/guardtalk/scripts/verify-voice-filter.sh
OUT_DIR=out/target/product/tokay vendor/guardtalk/scripts/verify-face-filter.sh

# 4. Check staged release readiness (read-only)
bash scripts/gt-ready-devices.sh
```

---

## Core Subsystems

### Radio & Feature Excision (`GUARDTALK_RADIO_EXCISED`, `GUARDTALK_FEATURE_EXCISED_WAVE2`)
- **Targets:** 14 Pixel codenames (`shiba`, `husky`, `akita`, `tokay`, `caiman`, `komodo`, `comet`, `tegu`, `stallion`, `frankel`, `blazer`, `mustang`, `rango`, `tangorpro`) plus `emu64a` / `emu64x` emulator targets. See [`docs/EXCISION_MATRIX.md`](docs/EXCISION_MATRIX.md) and [`docs/device-alignment-matrix.json`](docs/device-alignment-matrix.json).
- **Late filter:** `radio-excised/product-config-late.mk` hooked from `build/make/core/product_config.mk` (after inherit merge), bridging into `feature-excised/guardtalk-feature-excised.mk` (modem/radio, Bluetooth, NFC, UWB, location/GNSS, fingerprint HAL, and stock UI app excision).
- **Honest AOSP/HAL residuals:** Baseband firmware (`radio.img`) still ships on cellular Pixels (absent on Wi-Fi-only `tangorpro`). Four AOSP/HAL-constrained artifacts remain due to platform/VINTF dependencies: `com.android.telephonycore.apex`, `com.android.nfcservices.apex`, `location.provider.xml`, and `vendor/etc/vintf/manifest/bluetooth_audio.xml` (on `audio-impl` targets). See [`docs/EXCISION_LEDGER.md`](docs/EXCISION_LEDGER.md).
- **Regenerating blobs:** Do **not** rely on raw `adevtool generate-all -d <codename>` output — re-apply GuardTalk hooks per [`device/REGEN_HOOKS.md`](device/REGEN_HOOKS.md) (and [`device/tokay/REGEN_HOOKS.md`](device/tokay/REGEN_HOOKS.md)).
- **After filter edits:** Clear cached Soong product variables before rebuilding:
  ```bash
  rm -f out/soong/soong.<device>.variables out/soong/soong.<device>.extra.variables
  ```

### Face Persona Filter (`DEC-GT-004`)
- **Pipeline:** `libguardtalkface_jni.so` + Camera2 Beauty extension override (`camera/`)
- **Control:** `GuardTalkFace` priv-app + `persist.vendor.guardtalk.face.*`
- **Docs & Verify:** [`docs/FACE_FILTER.md`](docs/FACE_FILTER.md) · `vendor/guardtalk/scripts/verify-face-filter.sh`

### Mic Voice Filter (`DEC-GT-003`)
- **Effect:** `libguardtalkvoicesw.so` (AIDL preprocessing, C++ DSP in `audio/`)
- **Control:** `GuardTalkVoice` priv-app + `persist.vendor.guardtalk.voice.*`
- **Docs & Verify:** [`docs/VOICE_FILTER.md`](docs/VOICE_FILTER.md) · `vendor/guardtalk/scripts/verify-voice-filter.sh`

### Apps & Overlays
- **Included apps:** `GuardTalkVoice`, `GuardTalkFace`, `GuardTalkConfig`, `GuardTalkValidator` (`apps/`), plus 12 framework/Settings/SystemUI/Launcher/icon RROs (`overlays/`).
- **Check-in (`GuardTalkCheckin` / `checkin/`):** Source and host contract suite (`checkin/host/verify_host.sh`, 13 stdlib `unittest` cases) live in-tree; default `PRODUCT_PACKAGES` preinstall wiring is decommissioned.
- **Purged:** `GuardTalkMessenger` has been permanently purged and is **not** installed.

---

## Flashing, Emulation & Rollback

- **Beginner walkthrough (recommended):** [`docs/BUILD_AND_RUN_FOR_DUMMIES.md`](docs/BUILD_AND_RUN_FOR_DUMMIES.md)
- **Browser WebInstaller (WebUSB):** [`web-installer/README.md`](web-installer/README.md)
- **CLI flasher:** `scripts/flash-from-remote.sh` (AVB/`dm-verity` enabled by default; supports `GT_FLASH_QUARANTINE_CHECK_ONLY=1`, `GT_READY_CHECK_ONLY=1`, `GT_FLASH_PLAN_ONLY=1`, and Laguna `GT_BOOT_CHAIN=hybrid`). See also [`docs/FLASH.md`](docs/FLASH.md).
- **Emulator:** [`docs/EMULATOR.md`](docs/EMULATOR.md) & [`docs/KVM.md`](docs/KVM.md) (`scripts/check-kvm.sh`, `scripts/run-emulator.sh`).
- **Stock rollback:** `vendor/guardtalk/scripts/gt-rollback-to-stock.sh` (hash-verified against `scripts/gt-rollback-manifest.tsv`) and `scripts/gt-flash-stock.sh`.

---

## Directory Layout

```text
vendor/guardtalk/
├── apps/                  GuardTalkVoice, GuardTalkFace, GuardTalkConfig, GuardTalkValidator, GuardTalkCheckin
├── audio/                 Mic DSP + AIDL effect + effects config
├── camera/                Face persona pipeline + Camera2 extension
├── checkin/               12h check-in schema + host contract tests (verify_host.sh)
├── device/                Per-device BoardConfig/insmod/flag hooks (14 Pixels + emu64a) + REGEN_HOOKS.md
├── docs/                  Guides (BUILD_AND_RUN_FOR_DUMMIES.md, EMULATOR.md, KVM.md, FLASH.md, EXCISION_MATRIX.md) & qa/ (72 verify_*.sh scripts)
├── feature-excised/       Wave 2 excision modules (BT, NFC, UWB, GNSS, FP, apps, variant registry, blocklists)
├── overlays/              12 Framework, Settings, SystemUI, Launcher, SetupWizard & icon RROs
├── radio-excised/         Late product pass (packages, copy-files, product-config-late.mk)
├── scripts/               Host acceptance checks, emulator runner, signing helpers, stock rollback tool
└── web-installer/         Browser WebUSB installer (README.md, wizard/, src/, channels/)
```
