# GuardTalkOS WebInstaller — Beginner's Guide ("For Dummies")

> **New to GuardTalkOS?** Start with the full OS guide at [Build, Verify & Run GuardTalkOS for Dummies](../docs/BUILD_AND_RUN_FOR_DUMMIES.md) or the product overview at [vendor/guardtalk/README.md](../README.md).
>
> **Honest Readiness Disclosure:** This installer is **ready for dev/unlocked WebUSB UAT across all 14 packed targets**, and **NOT ready for production verified-boot fleets**.
> - `liveFlashClaimed=false` (`LIVE_FLASH_CLAIMED=false`)
> - `bootVerified=false` (`BOOT_VERIFIED=false`)
> - Channel posture: `dev/unlocked` (`verifiedBootClaim: "none"` — unsigned dev channel; **not** GrapheneOS-equivalent locked verified boot).

---

## Table of Contents

1. [What Is the GuardTalkOS WebInstaller?](#1-what-is-the-guardtalkos-webinstaller)
2. [Supported Pixel Devices (All 14 Packed Targets)](#2-supported-pixel-devices-all-14-packed-targets)
3. [Prerequisites (For Dummies)](#3-prerequisites-for-dummies)
4. [Step-by-Step Local Setup, Build & Test](#4-step-by-step-local-setup-build--test)
5. [Step-by-Step Browser Wizard Walkthrough](#5-step-by-step-browser-wizard-walkthrough)
6. [Troubleshooting FAQ](#6-troubleshooting-faq)
7. [Claim Honesty: Dev/UAT vs. Production Fleet](#7-claim-honesty-devuat-vs-production-fleet)
8. [Developer & Ops Reference](#8-developer--ops-reference)

---

## 1. What Is the GuardTalkOS WebInstaller?

The **GuardTalkOS WebInstaller** (`vendor/guardtalk/web-installer/`) lets you flash GuardTalkOS onto a supported Google Pixel directly from a Chromium-based web browser over USB (**WebUSB**), without installing `fastboot` on your computer.

How it works under the hood:
- **Browser UI (`wizard/`):** A 5-step guided wizard (`/wizard/`) that checks browser/USB readiness, connects to your Pixel in Fastboot Mode using the pinned MIT `android-fastboot` ES module (`/dist/vendor/fastboot.min.mjs`, from `kdrag0n/fastboot.js` commit `ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9`), and shows live progress and logs.
- **Flash Orchestrator (`src/` — `flashcore`):** Reads each device's hosted release channel (`channels/<codename>/manifest.json`, `SHA256SUMS`, `files.txt`), verifies the **SHA-256** checksum of every image before flashing (fail-closed), and executes a deterministic flash plan in strict order:
  1. `firmware` (bootloader / radio)
  2. `avb_custom_key` (erases and flashes public-only `avb_pkmd.bin`)
  3. `os` (logical partitions via `super_empty` + `fastbootd` or `super.img`, plus boot/vbmeta images)
- **Zero User Key Custody:** You never generate, upload, or import private signing keys in the browser. Release signing keys are held by GuardTalkOS maintainers; the browser only verifies published checksums and public `avb_pkmd.bin`.
- **Dry-Run Mode Included:** You can preview the exact flash plan and walk every wizard step **without plugging in a phone** by clicking **Use dry-run transport**.

> Prefer flashing from the command line or need stock rollback? See [Build, Verify & Run GuardTalkOS for Dummies](../docs/BUILD_AND_RUN_FOR_DUMMIES.md) for `scripts/flash-from-remote.sh` and `gt-rollback-to-stock.sh`.

---

## 2. Supported Pixel Devices (All 14 Packed Targets)

All **14** GuardTalkOS targets are packed into `channels/<codename>/` and wired into `src/allowlist.ts` (`STAGED_PRODUCTS`), `wizard/devices.ts` (`ALL_WIZARD_DEVICES`), `status.json`, and `scripts/pack-wizard-hosted-channels.sh`:

| Codename | Device Name | `status.json` Classification | Wizard Status | Default Boot-Chain | Super Mode |
|----------|-------------|------------------------------|---------------|--------------------|------------|
| `tokay` | Pixel 9 | `targets` | `supported` | `gt` | `super_empty` |
| `komodo` | Pixel 9 Pro XL | `targets` | `supported` | `gt` | `super_empty` |
| `caiman` | Pixel 9 Pro | `targets` | `supported` | `gt` | `super_empty` |
| `frankel` | Pixel 10 | `targets` | `supported` | `hybrid` (`gt`, `hybrid`) | `super` |
| `stallion` | Pixel 9a | `targets` | `supported` | `gt` | `super_empty` |
| `blazer` | Pixel 10 Pro | `targets` | `supported` | `hybrid` (`gt`, `hybrid`) | `super` |
| `rango` | Pixel 10 Pro Fold | `targets` | `experimental` (**boot HOLD**) | `hybrid` (`gt`, `hybrid`) | `super` |
| `akita` | Pixel 8a | `experimentalTargets` | `experimental` | `gt` | `super_empty` |
| `comet` | Pixel 9 Pro Fold | `targets` | `supported` | `gt` | `super_empty` |
| `husky` | Pixel 8 Pro | `targets` | `supported` | `gt` | `super_empty` |
| `mustang` | Pixel 10 Pro XL | `targets` | `supported` | `gt` | `super_empty` |
| `shiba` | Pixel 8 | `targets` | `supported` | `gt` | `super_empty` |
| `tegu` | Pixel 9a | `targets` | `supported` | `gt` | `super_empty` |
| `tangorpro` | Pixel Tablet | `targets` | `supported` | `gt` | `super_empty` |

**Notes:**
- All 14 channels are currently labeled **`dev/unlocked`** with **`LIVE_FLASH_CLAIMED=false`** and **`BOOT_VERIFIED=false`**.
- **Laguna Pixel 10 family (`frankel`, `blazer`, `rango`):** Default to `hybrid` (CP1A rescue-boot hybrid) and flash `super.img` directly. `rango` is marked **`experimental / boot HOLD`**. See [Troubleshooting FAQ](#6-troubleshooting-faq) and [../docs/BUILD_AND_RUN_FOR_DUMMIES.md](../docs/BUILD_AND_RUN_FOR_DUMMIES.md) for Laguna caveats.

---

## 3. Prerequisites (For Dummies)

Before you start, make sure you have all of the following:

### 3.1 Supported Web Browser (Chromium-Family Only)
- **Use:** Google Chrome, Chromium, Microsoft Edge, or Brave in a **normal (non-Incognito) window**.
- **Why Firefox, Safari, and Tor Browser do NOT work for live flashing:** They do not implement the **WebUSB** (`navigator.usb`) API. The wizard will still let you run **Dry-run** and **Plan preview**, but **Reboot to Fastboot** and live **Connect** are disabled.
- **Why Private / Incognito windows are unsupported:** Browsers severely restrict origin storage (OPFS) in private windows, which is too small to stage multi-GB Android partition images.

### 3.2 HTTPS / `window.isSecureContext` Requirement
Browsers only expose WebUSB inside a **secure context** (`window.isSecureContext === true`). In `wizard/main.ts`, the installer checks `window.isSecureContext === false` **before** checking `"usb" in navigator`:
- **Local machine (`localhost` or `127.0.0.1`):** `http://localhost:4173/wizard/` and `http://127.0.0.1:4173/wizard/` are treated as secure contexts by Chromium — WebUSB works locally without TLS certificates.
- **Remote server or LAN IP (`http://192.168.x.x:4173/wizard/`):** Plain HTTP on any non-localhost address has `window.isSecureContext === false`. The wizard will display:
  > *"WebUSB requires a secure context (https:// or localhost). Open this installer over https:// to enable Reboot to Fastboot and live WebUSB connect. Dry-run and plan preview still work."*
- **Fix for remote hosting:** Serve the installer behind **HTTPS** (TLS).

### 3.3 Hardware & Cable
- A **good USB data cable** (many cheap charging cables lack data wires).
- Plug directly into a USB port on the computer running the browser (avoid unpowered USB hubs).
- Back up everything on the Pixel — **unlocking the bootloader wipes all user data**.

### 3.4 Pixel Phone Preparation
On your Pixel (in stock Android):
1. Open **Settings → About phone** and tap **Build number** 7 times until Developer options are enabled.
2. Open **Settings → System → Developer options**.
3. Enable **OEM unlocking** (requires an internet connection on first toggle and a carrier-unlocked Pixel).
4. Enable **USB debugging** (needed only if you want to use the wizard's **Reboot to Fastboot** button).

### 3.5 Computer OS Setup (USB Access)
- **Linux:**
  1. Install Android `udev` rules (e.g., `android-udev-rules` package on Debian/Ubuntu/Arch/Fedora) and reload rules (`sudo udevadm control --reload-rules && sudo udevadm trigger`), then unplug/replug your Pixel.
  2. Stop `fwupd` if it claims the Fastboot USB interface:
     ```bash
     sudo systemctl stop fwupd.service
     ```
  3. Stop any running local `adb` server so Chromium can claim the USB interface:
     ```bash
     adb kill-server
     ```
- **macOS:** No extra kernel driver is needed. Run `adb kill-server` if `adb` is running, and avoid unpowered USB hubs.
- **Windows:** Install the **Google USB Driver** (*Android Bootloader Interface*) via Windows Update → Optional Updates or Device Manager before clicking **Connect**.

### 3.6 Local Host Tooling (Only If Running/Building Locally)
- **Node.js ≥ 20** (enforced by `"engines": { "node": ">=20" }` in `package.json`).
- **Python 3** (used by `npm run wizard:serve` and `npm run routes:serve`).

---

## 4. Step-by-Step Local Setup, Build & Test

Every command below is verified against `vendor/guardtalk/web-installer/package.json`. Run them from `vendor/guardtalk/web-installer/`:

```bash
cd vendor/guardtalk/web-installer
```

### Step 1 — Install Dependencies
`node_modules/`, `dist/`, and `channels/` are generated artifacts (gitignored and never committed). Install devDependencies and the pinned `android-fastboot` package:

```bash
npm ci
```

### Step 2 — Pack Release Channels (All 14 Targets)
Pack the 14 `<codename>-latest` desktop-flash stamps from `GUARDTALK_RELEASES_ROOT` (defaults to `<repo-root>/releases/desktop-flash` when inside the GuardTalk checkout) into `channels/<codename>/`:

```bash
# Optional: point at an external desktop-flash release store
# export GUARDTALK_RELEASES_ROOT=/path/to/releases/desktop-flash

npm run channels:pack
```

*(Need to pack just a single device? Run `bash scripts/pack-webinstall-channel.sh --stamp "$GUARDTALK_RELEASES_ROOT/tokay-latest" --out channels/tokay --copy-images`.)*

### Step 3 — Build the Static Site & Wizard
Run **both** build scripts so both the browser wizard (`dist/wizard/main.js`) and the vendored WebUSB Fastboot library (`dist/vendor/fastboot.min.mjs`, copied by `routes:build`) are emitted:

```bash
npm run routes:build
npm run wizard:build
```

### Step 4 — Verify Claims, Readiness Gate & Tests
Run the full host verification stack:

```bash
# 1. Claim-honesty linter (ensures zero forbidden overclaims)
npm run claims:lint

# 2. 14-clause readiness gate (0 = PASS, 1 = FAIL, 2 = ERROR)
node scripts/readiness-gate.mjs

# 3. Typecheck routes + flashcore + host test suite (mocked WebUSB/Fastboot)
npm run routes:typecheck
npm test
```

You can also inspect a flash plan from the terminal without touching USB:

```bash
npm run plan -- --channel channels/tokay
```

### Step 5 — Serve the Installer Locally
Start the local web server for the wizard:

```bash
npm run wizard:serve
```

Then open **`http://localhost:4173/wizard/`** (or **`http://127.0.0.1:4173/wizard/`**) in Chrome, Chromium, Edge, or Brave.

> **Note on `npm run routes:serve`:** `npm run routes:serve` serves `dist/site/` on port `8080` (`http://localhost:8080/`) to preview the static landing/redirect routes (`/`, `/install/`, `/install/update`, `/install/verify-device`, `/install/recover`, `/threat-model/`). For the full interactive wizard + `channels/` + `dist/vendor/fastboot.min.mjs`, use `npm run wizard:serve` on port `4173`.

### Complete `package.json` Script Reference

| Command | Underlying Script | What It Does |
|---------|-------------------|--------------|
| `npm ci` | *(npm built-in)* | Clean install of pinned dependencies (`typescript`, `tsx`, `@types/node`, `android-fastboot`). |
| `npm run channels:pack` | `bash scripts/pack-channels.sh` | Clears and repacks all 14 `channels/<codename>/` trees from `GUARDTALK_RELEASES_ROOT`. |
| `npm run routes:build` | `bash scripts/build-site.sh` | Builds `dist/site/` (including `/wizard/` redirects) and copies `dist/vendor/fastboot.min.mjs`. |
| `npm run wizard:build` | `tsc -p tsconfig.wizard.json` | Compiles `wizard/*.ts` to `dist/wizard/`. |
| `npm run typecheck` | `tsc --noEmit` | Typechecks `src/` and `test/`. |
| `npm run routes:typecheck` | `tsc -p tsconfig.routes.json --noEmit` | Typechecks `routes/` and `lib/`. |
| `npm test` | `tsc --noEmit && tsx --test test/*.test.ts` | Typechecks and runs all host unit/integration tests (mocked WebUSB/Fastboot). |
| `npm run claims:lint` | `node scripts/lint-claims-gate.mjs` | Lints emitted site and route copy for forbidden readiness/verified-boot overclaims. |
| `npm run plan` | `tsx src/cli.ts` | Prints a flashcore plan for a channel directory (no USB). |
| `npm run wizard:serve` | `python3 -m http.server 4173 --bind 0.0.0.0` | Serves the installer root so `/wizard/`, `/channels/`, and `/dist/` resolve on port `4173`. |
| `npm run routes:serve` | `python3 -m http.server 8080 --directory dist/site` | Serves the emitted static site in `dist/site/` on port `8080`. |

---

## 5. Step-by-Step Browser Wizard Walkthrough

### Opening the Wizard (and Legacy Redirects)
- Open **`/wizard/`** (e.g., `http://localhost:4173/wizard/` locally, or `https://<your-host>/wizard/` remotely).
- You can pre-select a device via query parameter, e.g., `/wizard/?device=tokay`.
- **Legacy routes retired:** Navigating to `/` (in `dist/site/`), `/install/update`, `/install/recover`, or `/install/verify-device` automatically redirects cleanly to `/wizard/`.

### Step 1 — Enable OEM Unlocking & Enter Fastboot Mode
1. Check the browser status line at the top of Step 1:
   - Confirm it reports a Chromium-family browser and WebUSB availability.
   - Make sure you are **not** in an Incognito/Private window.
2. Follow the OS-specific USB guidance tab (**Linux (udev & fwupd)**, **macOS**, or **Windows**).
3. Plug your Pixel into the computer running the browser and boot it into **Fastboot Mode** using any of these three methods:
   - Click **Reboot to Fastboot** in the wizard (sends `reboot:bootloader` over WebUSB ADB; accept the "Allow USB debugging" prompt on the Pixel).
   - Power off the Pixel, then hold **Volume Down + Power** until the Fastboot Mode screen appears.
   - Run the host fallback script: `vendor/guardtalk/scripts/reboot-to-fastboot.sh`.

### Step 2 — Select Device & Connect via WebUSB
1. Choose your Pixel model from the **Target Pixel device** dropdown (14 packed targets).
2. Check the **Boot-chain mode** selector:
   - Non-Laguna devices use `gt` (GuardTalk native boot chain).
   - Laguna Pixel 10 devices (`frankel`, `blazer`, `rango`) default to `hybrid` (CP1A rescue-boot hybrid) and allow switching between `hybrid` and `gt`.
3. Choose your transport:
   - **Want to practice safely without a phone?** Click **Use dry-run transport**, then click **Connect**.
   - **Ready to connect a real Pixel in Fastboot Mode?** Click **Connect** and select your Pixel in the browser's WebUSB picker.
4. The wizard reads and displays live telemetry from the bootloader:
   - **Detected product** (`getvar product` — must match the selected channel; mismatches fail closed)
   - **Current slot** (`current-slot`)
   - **Bootloader unlocked** (`unlocked`: `yes` or `no`)

### Step 3 — Unlock Bootloader
*(If your Pixel's bootloader is already unlocked, you can proceed straight to Step 4.)*
1. Check **"I understand unlocking the bootloader erases all user data on the Pixel."**
2. Click **Unlock bootloader** (runs `flashing unlock`).
3. On the Pixel screen, use the **Volume** buttons to highlight **Unlock the bootloader** and press **Power** to confirm. Wait for the wipe to finish and the Pixel to return to Fastboot Mode.

### Step 4 — Download, Verify & Flash Release
1. When you select a device, the wizard automatically loads `../channels/<codename>/`, verifies `manifest.json`, `SHA256SUMS`, and public `avb_pkmd.bin`, checks browser storage quota (OPFS / streaming), and displays the exact **flashcore** step list (`firmware` → `avb_custom_key` → `os`).
2. Review the plan preview (click **Refresh plan preview** if needed).
3. Click **Flash release** and watch the progress bar and **Activity** log.
4. **Reconnect prompts are normal:** When the flasher reboots into the bootloader or enters `fastbootd`, the browser's USB session resets and a **Reconnect the Pixel** dialog appears. Wait until the Pixel is back on the Fastboot screen, then click **Reconnect**.
5. If a transient USB transfer error occurs, the wizard displays a **Recoverable USB error** box with a **Reconnect & retry** button.

### Step 5 — Post-Flash & Safety-Gated Bootloader Lock
1. Once the flash plan completes, review the verification summary in Step 5 (which records the product, source stamp, `avb_pkmd.bin` SHA-256 prefix, and `LIVE_FLASH_CLAIMED=false`).
2. **About Locking the Bootloader (`flashing lock`):**
   - Because all current channels are **`dev/unlocked`** (development/test-keys, `verifiedBootClaim: "none"`), the **Lock bootloader** button is **safety-blocked by default** — locking requires checking **both** the data-wipe confirmation **and** the explicit **Operator override** checkbox.
   - **Important:** Locking a `dev/unlocked` channel does **not** create a GrapheneOS-equivalent production verified-boot install. For lab/UAT testing, leave the bootloader unlocked unless you explicitly intend to test locking with an operator override.

---

## 6. Troubleshooting FAQ

### Q: I see *"WebUSB requires a secure context (https:// or localhost)"*
- **Cause:** You opened the page over plain `http://` using a LAN IP or hostname (for example `http://192.168.1.50:4173/wizard/`), so `window.isSecureContext` is `false`.
- **Fix:**
  - If running on the same computer, open **`http://localhost:4173/wizard/`** or **`http://127.0.0.1:4173/wizard/`**.
  - If hosting on another machine, put an **HTTPS** reverse proxy (TLS) in front of it and open **`https://<your-host>/wizard/`**.

### Q: WebUSB says *Permission denied*, *Access denied*, or *Unable to claim interface*
- **Linux `udev` rules:** Install `android-udev-rules`, reload udev (`sudo udevadm control --reload-rules && sudo udevadm trigger`), and replug the USB cable.
- **`adb` daemon conflict:** Another process (`adb`) owns the USB interface. Run `adb kill-server` and retry.
- **`fwupd` conflict (Linux):** Run `sudo systemctl stop fwupd.service` and retry.
- **Another browser tab:** Close any other tabs using WebUSB (such as another installer tab).

### Q: My Pixel does not appear in the WebUSB device picker
- Confirm the Pixel screen actually says **Fastboot Mode** (red/green triangle screen), not normal Android or Recovery.
- Swap to a known-good **USB data cable** and plug directly into the computer (no unpowered USB hub).
- On **Windows**, install the **Google USB Driver** (*Android Bootloader Interface*) via Windows Update Optional Updates or Device Manager.
- On **Linux**, re-check `udev` rules and verify `lsusb` sees a Google device (`18d1:...`).

### Q: *OEM unlocking* is greyed out or the bootloader refuses to unlock
- Connect the Pixel to Wi-Fi in stock Android for a few minutes and check **Settings → System → Developer options → OEM unlocking** again.
- Carrier-locked Pixels (for example certain carrier-financed models) permanently disable OEM unlocking and cannot be unlocked or flashed.
- Make sure you confirmed the on-device prompt using the **Volume** and **Power** buttons during Step 3.

### Q: The flash pauses at *Reconnect the Pixel* or stalls entering `fastbootd`
- The **Reconnect the Pixel** dialog is **expected** whenever the bootloader reboots or transitions into `fastbootd` — it is not an error by itself. Wait for the Pixel to finish rebooting into Fastboot Mode, then click **Reconnect**.
- If the Pixel drops off USB completely, unplug and replug the cable, ensure it is in Fastboot Mode, and click **Reconnect & retry**.

### Q: What are the special caveats for Pixel 10 Laguna devices (`frankel`, `blazer`, `rango`)?
- Laguna devices (`frankel` Pixel 10, `blazer` Pixel 10 Pro, `rango` Pixel 10 Pro Fold) use `super.img` and default to the **`hybrid`** (CP1A rescue-boot) boot-chain mode rather than `gt`.
- **`rango` (Pixel 10 Pro Fold)** is currently flagged **`experimental / boot HOLD`**.
- For full Laguna hybrid flashing rules, `GT_BOOT_CHAIN=hybrid`, `REMOTE_RESCUE_DIR`, operator `acks/<dev>.ack` files, and stock rollback (`gt-rollback-to-stock.sh`), see [Build, Verify & Run GuardTalkOS for Dummies](../docs/BUILD_AND_RUN_FOR_DUMMIES.md).

---

## 7. Claim Honesty: Dev/UAT vs. Production Fleet

GuardTalkOS enforces strict claim honesty (verified automatically by `npm run claims:lint` and `node scripts/readiness-gate.mjs`):

| Dimension | Current State | Meaning |
|-----------|---------------|---------|
| **`liveFlashClaimed`** | **`false`** (`LIVE_FLASH_CLAIMED=false`) | All automated verification uses mocked WebUSB/Fastboot transports. A passing `npm test` or `readiness-gate` run is **not** a live hardware flash. |
| **`bootVerified`** | **`false`** (`BOOT_VERIFIED=false`) | Green host checks do **not** claim hardware boot verification. |
| **Channel Label** | **`dev/unlocked`** (`verifiedBootClaim: "none"`) | Channels are unsigned dev channels backed by review-gated anchor pins (`docs/expected-anchors.json`). |
| **Dev/Unlocked WebUSB UAT** | **GO (14/14 packed targets)** | All 14 channels are packed, verified by `readiness-gate`, `claims:lint`, and `npm test`, and ready for human-operated dev/unlocked WebUSB UAT. |
| **Production Verified-Boot Fleet** | **NO-GO (Blocked)** | Blocked on: (1) production release signing keys replacing AOSP `testkey` (`userdebug`/`test-keys` vs. vault-held release keys), (2) signed channel roots (`channel-root.txt` + `channel-root.txt.sig` verified via `--require-signed-root`), and (3) human-executed hardware live-flash and boot verification. |

---

## 8. Developer & Ops Reference

### Directory Layout

| Path | What It Is | Committed in Git? |
|------|------------|-------------------|
| `wizard/` | GuardTalkOS-branded 5-step WebUSB installer UI (`index.html`, `main.ts`, `devices.ts`, …) | Yes |
| `src/` | `flashcore` orchestrator (`allowlist.ts`, `types.ts`, `transport.ts`, `cli.ts`, …) | Yes |
| `routes/` & `lib/` | Static site routes, CSP headers, and claim-honesty linter (`lib/claims/`) | Yes |
| `scripts/` | Vendored channel packers, `build-site.sh`, `readiness-gate.mjs`, `lint-claims-gate.mjs`, `verify-flashall.sh` | Yes |
| `schema/` | JSON Schema (`channel-manifest.schema.json`) and example manifest (`manifest.example.json`) | Yes |
| `test/` | Host unit/integration tests with mocked Fastboot/WebUSB transport | Yes |
| `status.json` | Build-time posture manifest (`liveFlashClaimed: false`, `targets`, `experimentalTargets`) | Yes |
| `channels/` | Generated per-device channel trees (`manifest.json`, `SHA256SUMS`, `files.txt`, staged images) | **Never** (`.gitignore`) |
| `dist/` | Compiled TypeScript (`dist/wizard/`, `dist/site/`) and vendored `dist/vendor/fastboot.min.mjs` | **Never** (`.gitignore`) |
| `node_modules/` | Installed npm packages (`typescript`, `tsx`, `@types/node`, `android-fastboot`) | **Never** (`.gitignore`) |

### Consuming This Directory Standalone / As a Git Submodule
This directory is self-contained and can be checked out without an Android `repo` tree around it. Channel packers are vendored at `scripts/pack-webinstall-channel.sh` and `scripts/pack-wizard-hosted-channels.sh`, and host dependencies are resolved via `scripts/lib/resolve.sh` (missing dependencies fail closed with exit `2`).

```bash
git submodule add git@github.com:nullset-zone/vendor_guardtalk.git vendor/guardtalk
git submodule update --init --recursive
cd vendor/guardtalk/web-installer
```

After packing or drilling channels, verify integrity and anchors:

```bash
bash scripts/check-channel-integrity.sh
node scripts/gen-expected-anchors.mjs --check
```

### Environment contract

| Variable | Read by | Default | Meaning |
|----------|---------|---------|---------|
| `GUARDTALK_RELEASES_ROOT` | `scripts/gen-flash-matrix.mjs`, `scripts/gen-expected-anchors.mjs`, `scripts/readiness-gate.mjs`, `scripts/verify-flashall.sh`, `scripts/pack-channels.sh`, `scripts/pack-wizard-hosted-channels.sh`, `scripts/pack-webinstall-channel.sh` | `<repo root>/releases/desktop-flash` | Desktop-flash release store that channels are packed from and checked against. |
| `GUARDTALK_INSTALLER_ROOT` | `scripts/readiness-gate.mjs` | Gate's own install location (`import.meta.url`) | Installer tree probed by the gate (`channels/`, `docs/flash-matrix.json`, `status.json`). Conflicting `--matrix=` fails closed (exit `2`). |
| `GT_NODE_BIN` | `scripts/verify-flashall.sh` | First runnable Node.js ≥ 20 from ordered candidate list | Explicit Node.js binary. Fails closed (exit `2`) if unrunnable or `< 20`. |

Script-local variables:
- `NODE`: Interpreter used by `scripts/build-site.sh` for local `tsc`.
- `GUARDTALK_RELEASES_DIR`: Drill/test override for `scripts/readiness-gate.mjs` (`--releases-dir=` wins).
- `GT_MANIFEST_OUT`, `GT_MANIFEST_TIMESTAMP`, `GT_REPORTER_SHA`: Test overrides for `scripts/gen-readiness-manifest.sh`.
- `CHANNEL`: `dev` (default) or `production` for `scripts/pack-webinstall-channel.sh` (`production` fails closed without a valid signature).
- `GUARDTALK_REQUIRE_SIGNED_ROOT`: Demands a signed channel root in `scripts/readiness-gate.mjs` (equivalent to `--require-signed-root`; only `0`/`false`/`no` disable it — any unrecognized value fails closed).

### Signed Channel Roots (Production Authenticity)
The shipped `dev` channel is **not** signed; it uses review-gated pins in `docs/expected-anchors.json`. Production channels require a detached `ssh-keygen -Y` signature (`channel-root.txt` + `channel-root.txt.sig`) verified against an out-of-band `allowed_signers` file (`docs/expected-allowed-signers` or `--allowed-signers=`):

```bash
# Dev channel (14 clauses, unsigned dev posture)
node scripts/readiness-gate.mjs

# Strict signed-root mode — fails closed (exit 1) if no valid signature verifies
node scripts/readiness-gate.mjs --require-signed-root
node scripts/readiness-gate.mjs --require-signed-root --allowed-signers=/path/to/allowed_signers
node scripts/readiness-gate.mjs --json
```

### Browser ADB Key Storage (Private Key at Rest)
The first time you click **Reboot to Fastboot** (WebUSB ADB), `wizard/adb-rsa.ts` generates a 2048-bit RSA host key (`RSASSA-PKCS1-v1_5`, SHA-1) with WebCrypto and stores the private JWK unencrypted in `localStorage` under `guardtalk.webadb.rsa-jwk` (the browser equivalent of `~/.android/adbkey`) so your Pixel remembers the authorization.
- **Risk scope:** Readable by scripts in the same origin or anyone with access to your local browser profile; bounded to ADB-debugging trust on your device.
- **How to revoke:** Run `localStorage.removeItem("guardtalk.webadb.rsa-jwk")` in DevTools (or clear site data for the wizard origin), then revoke USB debugging authorizations under **Settings → Developer options** on the Pixel.

### Related Documentation & Licensing
- [Build, Verify & Run GuardTalkOS for Dummies](../docs/BUILD_AND_RUN_FOR_DUMMIES.md) — full OS build, QA verification, emulator, and CLI flashing walkthrough
- [GuardTalkOS Product Overview](../README.md) — repository index and component map
- [Web Installer Channel Specification](../docs/WEB_INSTALLER_CHANNEL.md) — channel schema and packaging contract
- **License:** MIT ([`LICENSE`](LICENSE)); third-party notices in [`NOTICE`](NOTICE).
