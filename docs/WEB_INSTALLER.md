# ADR: GuardTalkOS web installer — official GrapheneOS analysis

**Status:** Proposed (wave 1 analysis; no product code)  
**Task:** `T-WEBINSTALL-GOS-ANALYSIS`  
**Date:** 2026-08-20  
**Product path (later waves):** `vendor/guardtalk/web-installer/`  
**This file is the contract.** Reimplement later. Do not copy GrapheneOS HTML, CSS, JS, or marketing copy.

Architect locks honored: DEC-WEBINSTALL-001..005 (root `TASK_QUEUE.md`, bind 2026-08-20T15:12:00Z).

- **MVP device:** `tokay` (Pixel 9). `akita` follow-on. `rango` hidden / experimental — not production-bootable.
- **KEEP** both `scripts/flash-from-remote.sh` and `vendor/guardtalk/scripts/flash-from-remote.sh`. Web installer is additive.
- No rango `0xfc` / boot RCA work. `rango-latest` stays `130756`.
- Secrets: public `avb_pkmd.bin` and published hashes only. No env files or private key material.

### Gate -1 note (Law 9)

MCP `gate_enforcer` and `ask_guardian` both timed out (`-32001`) on 2026-08-20. Proceeded under Law 9 (graceful degradation) with this written Gate -1: research-only ADR; no installer product code; no secrets; no verbatim GrapheneOS copy; allowed paths only.

---

## Official sources fetched (Law 7)

Fetched and read on **2026-08-20**. Behavior claims below cite these; nothing is from memory.

| Ref | URL / path | What was read |
|-----|------------|---------------|
| W1 | https://grapheneos.org/install/web | Live web-installer guide (prereqs, unlock/flash/lock UX, AVB hashes) |
| W2 | https://github.com/GrapheneOS/grapheneos.org/blob/main/static/install/web.html | Same page source (`main` as of fetch) |
| W3 | https://github.com/GrapheneOS/grapheneos.org/blob/main/static/js/web-install.js | Installer controller (only JS module imported by W2 besides `redirect.js`) |
| W4 | https://github.com/GrapheneOS/grapheneos.org/tree/main/static/js/fastboot/ffe7e270 | Vendored fastboot bundle + `vendor/` workers |
| W5 | https://github.com/kdrag0n/fastboot.js/commit/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9 | Confirms `ffe7e270` is a commit on **kdrag0n/fastboot.js** |
| W6 | https://github.com/kdrag0n/fastboot.js/blob/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9/src/factory.ts | Legacy factory-zip flash order + `script.txt` dispatch |
| W7 | https://github.com/kdrag0n/fastboot.js/blob/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9/src/factory-optimized.ts | `script.txt` interpreter used for current GOS install zips |
| W8 | https://github.com/kdrag0n/fastboot.js/blob/master/LICENSE | MIT (Danny Lin, 2021) |
| W9 | https://github.com/kdrag0n/fastboot.js/blob/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9/package.json | Package `android-fastboot` 1.1.1; deps `@zip.js/zip.js`, `pako` |
| W10 | https://grapheneos.org/install/cli | CLI twin: unlock, signed zip, `flash-all`, lock, erase `avb_custom_key` |
| W11 | https://github.com/GrapheneOS/device_common/blob/16-qpr2/generate-factory-images-common.sh | Generates `flash-all.sh` / `.bat` and factory zip layout |
| W12 | https://github.com/GrapheneOS/script/blob/16-qpr2/generate-release.sh | Channel artifact names, device flags, `optimize-factory-image` |
| W13 | https://releases.grapheneos.org/tokay-stable | Channel pointer (fetched: `2026081300 1786591653 tokay stable`) |
| W14 | https://releases.grapheneos.org/allowed_signers | OpenSSH allowed signers (fetched 200) |
| W15 | https://grapheneos.org/releases | Channel model (Alpha → Beta → Stable); factory images vs OTA |
| W16 | https://github.com/GrapheneOS/grapheneos.org/blob/main/LICENSE | Site repo MIT (© 2014–2026 GrapheneOS) |
| W17 | https://raw.githubusercontent.com/nodeca/pako/master/LICENSE | pako MIT |
| W18 | https://raw.githubusercontent.com/gildas-lormeau/zip.js/master/LICENSE | zip.js BSD-3-Clause |

`https://raw.githubusercontent.com/GrapheneOS/fastboot.js/main/README.md` returned **404**. Lineage is therefore **confirmed via the in-repo vendor path** `static/js/fastboot/ffe7e270/` matching commit `ffe7e270` on `kdrag0n/fastboot.js` (W4 + W5), not via a live `GrapheneOS/fastboot.js` default branch.

In-tree (read-only): `scripts/flash-from-remote.sh` (1135 lines), `vendor/guardtalk/scripts/flash-from-remote.sh` (1135 lines, **byte-identical** to the root copy on 2026-08-20), `vendor/guardtalk/docs/FLASH.md`, `vendor/guardtalk/docs/RANGO_FLASH.md` device table only.

---

## How the official web installer works

The live page (W1) and `web.html` (W2) are a **stepped human guide** with five WebUSB actions wired by `web-install.js` (W3): unlock bootloader, download release, flash release, lock bootloader, remove non-stock AVB key.

`web.html` loads two scripts: `redirect.js` (fragment redirects; not part of flash) and `web-install.js` as a module (W2). `web-install.js` has **one ES import**:

```text
import * as fastboot from "./fastboot/ffe7e270/fastboot.min.mjs";
```

Source: [GrapheneOS/grapheneos.org `static/js/web-install.js`](https://github.com/GrapheneOS/grapheneos.org/blob/main/static/js/web-install.js) (`main` as fetched).

It then configures zip.js inflate workers (W3):

```text
fastboot.configureZip({
  workerScripts: {
    inflate: ["/js/fastboot/ffe7e270/vendor/z-worker-pako.js", "pako_inflate.min.js"],
  },
});
```

Directory listing of that vendor tree (W4): `fastboot.min.mjs`, `fastboot.min.mjs.map`, `vendor/pako_inflate.min.js`, `vendor/z-worker-pako.js`.

### fastboot.js lineage — **confirmed**

| Claim | Evidence |
|-------|----------|
| Import/vendor path in GOS site | `static/js/fastboot/ffe7e270/` (W3, W4) |
| `ffe7e270` is kdrag0n/fastboot.js | Commit `ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9` exists on https://github.com/kdrag0n/fastboot.js (W5). Message: factory-optimized parser for outer-directory zip entries. Committer listed as Daniel Micay. |
| Library identity | `package.json` at that commit: `"name": "android-fastboot"`, `"repository": "https://github.com/kdrag0n/fastboot.js"`, `"license": "MIT"` (W9) |
| GrapheneOS/fastboot.js default branch | **Denied as a live source** (README 404). Do not treat a separate GOS fork URL as the vendor origin. |

### User-visible step list (paraphrase, not copy)

From W1/W2 and W10 (CLI twin):

1. Enable OEM unlocking in the stock OS (Developer options). Carrier SKUs may require network.
2. Boot the device into the bootloader UI (volume-down) and leave it in Fastboot Mode.
3. Connect USB (udev on Linux; optional Windows fastboot driver for older hosts).
4. **Unlock** the bootloader (device confirm; wipe).
5. **Download** the factory install zip for the connected `product`.
6. **Flash** the zip. The implementation flashes firmware, reconnects after reboots, then flashes the OS.
7. **Lock** the bootloader (device confirm; wipe again) so verified boot is fully enabled.
8. Optional: erase `avb_custom_key` when returning to stock (W1 “Remove non-stock key”; W10 `fastboot erase avb_custom_key`).

### What `web-install.js` actually does (W3)

| Action | Fastboot / host behavior |
|--------|--------------------------|
| Unlock | `getvar unlocked`; if not `yes`, `flashing unlock`. FAIL treated as user rejected unlock. |
| Download | `getvar product` must be in `supportedDevices`. `GET https://releases.grapheneos.org/{product}-stable`. First whitespace token = release id. Zip name `{product}-install-{releaseId}.zip`. Cached in IndexedDB `BlobStore`. |
| Flash | Reload zip from cache. If `snapshot-update-status` is not `none`, `snapshot-update:cancel`. Then `device.flashFactoryZip(blob, /*wipe=*/ true, reconnectCallback, progress)`. |
| Lock | `flashing lock`. FAIL treated as user rejected lock. |
| Remove key | `erase:avb_custom_key`. |
| Reconnect | After reboot, WebUSB session is gone. UI shows a reconnect control; `device.connect()` again. Required on Android unless desktop mode is off (W1). |
| Wake lock | Screen wake lock during download/flash; `beforeunload` guard while those bits are set. |
| Quota | If `navigator.storage.estimate().quota` is nonzero and `< 2000 * 1024 * 1024`, show the low-quota warning in the page. Comment in W3: factory images then ~1700 MiB. |
| No WebUSB | All action buttons report unavailable and point at prerequisites. |

`supportedDevices` in W3 (order as published):  
`stallion`, `rango`, `mustang`, `blazer`, `frankel`, `tegu`, `comet`, `komodo`, `caiman`, **`tokay`**, **`akita`**, `husky`, `shiba`, `felix`, `tangorpro`, `lynx`, `cheetah`, `panther`, `bluejay`, `raven`, `oriole`.

GuardTalkOS MVP may only **offer** `tokay`. `akita` is follow-on. `rango` stays hidden even though GOS lists it.

---

## Sequence

Official GOS web + CLI user sequence, with the in-zip flash plan that current `-install-` zips execute (W3 + W7 + W11 + W12). `reconnect` is a WebUSB re-`connect()` after the device drops (W3 `reconnectCallback`).

```mermaid
sequenceDiagram
    actor User
    participant Page as Browser installer
    participant Rel as releases.grapheneos.org
    participant Dev as Pixel (fastboot)

    User->>Dev: Enable OEM unlocking (stock OS)
    User->>Dev: Boot Fastboot Mode (vol-down)
    User->>Page: Unlock
    Page->>Dev: WebUSB connect
    Page->>Dev: getvar unlocked
    alt locked
        Page->>Dev: flashing unlock
        User->>Dev: Confirm (wipe)
        Page->>User: Reconnect after reboot
        Page->>Dev: WebUSB connect
    end

    User->>Page: Download release
    Page->>Dev: getvar product
    Page->>Rel: GET /{product}-stable
    Rel-->>Page: "{id} {epoch} {product} stable"
    Page->>Rel: GET /{product}-install-{id}.zip
    Rel-->>Page: zip blob (IndexedDB cache)

    User->>Page: Flash release
    Page->>Dev: snapshot-update:cancel (if needed)
    Note over Page,Dev: flashFactoryZip(wipe=true) → script.txt (optimized)
    Page->>Dev: bootloader --slot=other (twice) + reconnect
    Page->>Dev: flash radio + reconnect
    Page->>Dev: erase avb_custom_key
    Page->>Dev: flash avb_custom_key (avb_pkmd.bin)
    Page->>Dev: oem uart disable; erase fips (tokay); erase dpm_a/dpm_b
    Page->>Dev: -w update image-*.zip (firmware already done; OS + wipe)
    Page->>User: Reconnect after each reboot
    Page->>Dev: reboot-bootloader

    User->>Page: Lock
    Page->>Dev: flashing lock
    User->>Dev: Confirm (wipe)
```

**Order note (do not collapse):** CLI `flash-all.sh` (W11) writes **AVB key after radio and before** `fastboot -w --skip-reboot update image-*.zip`. Legacy `factory.ts` without `script.txt` (W6) flashes AVB **after** OS images. Current GOS releases run `fastboot optimize-factory-image` (W12), so the published `-install-` zip contains `*/script.txt` and W6 dispatches to W7. The script is generated from `flash-all.sh`, so **web flash of a current GOS zip follows CLI order: firmware → avb_custom_key → OS update → lock (lock is a separate button, not inside the zip).**

Unlock and lock are **outside** the zip (W3 buttons). The zip’s `wipe` flag (`true` in W3) controls whether `erase` commands in `script.txt` run, except `avb_custom_key` which W7 always erases when the script says `erase avb_custom_key`.

---

## Factory-zip / flash-script contract

### Channel and filenames

| Item | Contract | Source |
|------|----------|--------|
| Channel file | `https://releases.grapheneos.org/{product}-stable` (also `-alpha`, `-beta`) | W3, W13, W15 |
| Channel body | `{releaseId} {unixEpoch} {product} {channel}` — first token is the id | W3, W13 |
| Install zip | `{product}-install-{releaseId}.zip` | W3, W10, W12 |
| Signature | `{product}-install-{releaseId}.zip.sig` | W10 |
| Signers file | `https://releases.grapheneos.org/allowed_signers` | W10, W14 |
| Verify | `ssh-keygen -Y verify -f allowed_signers -I contact@grapheneos.org -n "factory images" -s ZIP.sig < ZIP` | W10 |
| SHA256SUMS | **Not published** at `/sha256sums`, `/SHA256SUMS`, or `{zip}.sha256` (all 404 on 2026-08-20) | HTTP HEAD this wave |
| Intermediate factory zip | `{device}-factory-{BUILD}.zip` is built then consumed by `optimize-factory-image`; **not** the public URL (HEAD of `tokay-factory-2026081300.zip` = 404) | W11, W12, HEAD |

Fetched 2026-08-20:

- `tokay-stable` / `tokay-alpha` / `tokay-beta`: `2026081300 1786591653 tokay {channel}`
- `tokay-install-2026081300.zip`: HTTP 200, `Content-Length: 2001076770` (~1.86 GiB)
- `tokay-install-2026081300.zip.sig`: HTTP 200, 310 bytes
- `allowed_signers` (W14): `contact@grapheneos.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUg/m5CoP83b0rfSCzYSVA4cw4ir49io5GPoxbgxdJE`

W15: factory images are for **initial install** and are OpenSSH-verifiable. OTA/full update packages are a different artifact and must not be used as the web-install payload.

### Zip interiors (two layers)

**1. Unoptimized factory zip** (`generate-factory-images-common.sh`, W11) — directory `$PRODUCT-$VERSION` later renamed `$PRODUCT-factory-$VERSION`:

- `image-$PRODUCT-$VERSION.zip` (OS images; what `fastboot update` consumes)
- `bootloader-$DEVICE-$BOOTLOADER.img`
- `radio-$DEVICE-$RADIO.img` (absent for `tangorpro` per W12)
- `avb_pkmd.bin` when `AVB_PKMD` is set (W12 always sets it to the device key dir’s public blob)
- GSC firmware files copied from `VENDOR/firmware/$GSCFIRMWARESRC/`
- `flash-all.sh` and `flash-all.bat`

**2. Published install zip** (W12):

```text
fastboot -S $MAX_DOWNLOAD_SIZE optimize-factory-image \
  $DEVICE-factory-$BUILD_NUMBER.zip $DEVICE-install-$BUILD_NUMBER
```

`MAX_DOWNLOAD_SIZE` is `0x10000000` for `rango|mustang|blazer|frankel`, else `0xf900000` (includes **tokay**). Output default name is `{device}-install-{build}.zip`. The second argument is the **outer directory name**. W5/W7 exist because zip entries live under that prefix (`…/script.txt`).

`script.txt` opcodes understood by W7 (GuardTalk flashcore must implement or generate the same set):

| Opcode | Effect |
|--------|--------|
| `check-requirements <file>` | Parse `android-info.txt` requires (`require var=val`; `board` → `product`; `partition-exists`) |
| `check-var <name> <value>` | Hard fail if `getvar` mismatches |
| `erase <partition>` | `erase:` — skipped unless wipe **or** partition is `avb_custom_key` |
| `flash <part> <file> [other-slot]` | Flash zip entry to current or other slot |
| `maybe-cancel-snapshot-update` | `snapshot-update:cancel` if status ≠ `none` |
| `reboot-bootloader` | Reboot + `waitForConnect(onReconnect)` |
| `run-cmd <rest of line>` | Raw fastboot command (e.g. `oem uart disable`) |
| `toggle-active-slot` | `set_active:` other slot |

CLI users extract the same `-install-` zip and run `bash flash-all.sh` / `./flash-all.bat` (W10). Web users never run the shell script; W7 replays the optimized script.

### `flash-all.sh` command order (tokay flags)

From W11 concatenated with W12 tokay flags (`DISABLE_UART`, `DISABLE_FIPS`, `DISABLE_DPM` all true; radio present):

1. Reject if `fastboot` missing or version `< 35.0.1`
2. Reject if `getvar product` ≠ `$DEVICE`
3. `flash --slot=other bootloader …` → `--set-active=other` → `reboot-bootloader` → sleep
4. Repeat bootloader flash on the new “other” slot → `--set-active=other`
5. `reboot-bootloader` → sleep
6. `flash radio …` → `reboot-bootloader` → sleep
7. `erase avb_custom_key` → `flash avb_custom_key avb_pkmd.bin`
8. `oem uart disable`
9. `erase fips` (Pixel 6–9 family including **tokay**; **not** rango family)
10. `erase dpm_a` / `erase dpm_b`
11. `fastboot -w --skip-reboot update image-$PRODUCT-$VERSION.zip`
12. `reboot-bootloader` → sleep

W10: do not interact with the device until the script finishes; then lock (lock wipes again).

### Device allowlist vs GuardTalkOS

| Codename | GOS web (W3) | GOS release script (W12) | GuardTalkOS web (this ADR) |
|----------|--------------|--------------------------|----------------------------|
| tokay | yes | UART+FIPS+DPM | **MVP — only advertised device** |
| akita | yes | UART+FIPS+DPM | Follow-on; do not block schema |
| rango | yes | UART+DPM, **no FIPS**; larger sparse split | **Hidden / experimental** |

### Published verified-boot key hashes (public)

From W1 (6th-gen+ Pixels show the full sha256 of the AVB public key on the yellow boot notice). GuardTalkOS must publish **its own** hashes later; do not imply GOS hashes apply to GT images.

| Marketing name | sha256 (from W1) |
|----------------|------------------|
| Pixel 9 (tokay) | `9e6a8f3e0d761a780179f93acd5721ba1ab7c8c537c7761073c0a754b0e932de` |
| Pixel 8a (akita, follow-on) | `096b8bd6d44527a24ac1564b308839f67e78202185cbff9cfdcb10e63250bc5e` |
| Pixel 10 Pro Fold (rango, **hidden**) | `55a2d44103e56d5ec65496399c417987ba77730e6488fc60ba058d09fc3caee3` |

These are GrapheneOS key hashes, not GuardTalkOS keys. GT flash path uses public `avb_pkmd.bin` from the desktop-flash bundle (`FLASH.md` / `RANGO_FLASH.md`). Never document private key material.

---

## Browser / OS / storage-quota matrix

From W1/W2 unless noted. Official GrapheneOS text does **not** name OPFS. The implementation (W3) uses **IndexedDB** (`BlobStore` / object store `files`) plus `navigator.storage.estimate()` (Storage Manager quota, which on Chromium includes origin storage that may be OPFS-backed). Treat “OPFS” as the platform quota bucket, not as an API GOS calls.

### Host OS (web method)

| Platform | Official? | Notes from W1 |
|----------|-----------|---------------|
| Windows 10, Windows 11 | yes | Generic fastboot driver on current Win10/11 for Pixel 4a (5G)+; optional “LeMobile Android Device” via Windows Update |
| macOS Sonoma 14, Sequoia 15, Tahoe 26 | yes | |
| Arch Linux | yes | `android-udev` |
| Debian 12, Debian 13 | yes | `android-sdk-platform-tools-common` |
| Ubuntu 22.04 LTS, 24.04 LTS, 25.04 | yes | Same udev package; **Ubuntu Chromium Snap = broken WebUSB** |
| Linux Mint 21 / 22 / LMDE 6 | yes | Follow Ubuntu 22.04 / 24.04 / Debian 12 respectively |
| ChromeOS | yes | Web only (CLI list omits ChromeOS/Android) |
| GrapheneOS | yes | Vanadium |
| Android 14–17 with Play Protect | yes | Disable browser desktop mode (reconnect-after-reboot) |
| Older EOL versions of the above | usable, unsupported | |
| OS in a VM | discouraged | USB passthrough + tiny disks |

Web method also requires ~**2 GiB free RAM** and **32 GiB free storage** (W1). CLI (W10) same RAM/disk; CLI cannot run on a phone.

### Browsers

| Browser | Official? | Constraint (W1 / W3) |
|---------|-----------|----------------------|
| Chromium (not Ubuntu Snap) | yes | |
| Vanadium | yes | |
| Google Chrome | yes | |
| Microsoft Edge | yes | |
| Brave | yes | Shields **off** (Shields caps storage) |
| Firefox / Safari | no | No WebUSB in W3 (`"usb" in navigator` gate) |
| Flatpak / Snap browsers | avoid | Known install failures (W1) |
| Incognito / private | **forbidden** | Not enough origin storage to extract the zip (W1); W3 maps `QuotaExceededError` to a quota/incognito message |

### Storage / quota (implementation facts)

| Check | Threshold / behavior | Source |
|-------|----------------------|--------|
| Page copy | 32 GiB free disk | W1 |
| JS warning | `estimate.quota < 2000 MiB` (and ≠ 0) | W3 |
| Cache | IndexedDB `BlobStore` v1, key `name`, value `blob` | W3 |
| Download | XHR `responseType=blob` (not `fetch`) for progress | W3 |
| Official OPFS API use | **None found** in W3 | W3 |

GuardTalkOS flashcore should keep a quota warning at ≥ the size of the tokay factory zip plus extract slack. Observed GOS tokay zip ≈ 1.86 GiB (HEAD); W3’s 2000 MiB warning is already below that zip — GT must **raise** the warning to match real payload size (Law 7: do not copy the stale 1700 MiB comment).

Linux fwupd may claim the fastboot device; W1 says `sudo systemctl stop fwupd.service` (temporary).

---

## License table

| Upstream file / tree | License | Copy into GT product? |
|----------------------|---------|------------------------|
| `grapheneos.org` repo `LICENSE` (W16) | MIT (© GrapheneOS 2014–2026) | Attribution only. **Do not copy** `web.html`, CSS, or page prose (DEC-WEBINSTALL-005). |
| `static/install/web.html` (W2) | Site MIT + AOSP-style includes | **Reimplement** the *step list*, not the markup or wording. |
| `static/js/web-install.js` (W3) | MIT (file header magnet Expat) | **Reimplement.** Orchestration is the GT contract; this file is the behavior spec. |
| `static/js/redirect.js` | MIT (file header) | Not required for GT. |
| `static/js/fastboot/ffe7e270/fastboot.min.mjs` (W4) | MIT via kdrag0n/fastboot.js (W8, W9) | **Allowed as a library** (npm `android-fastboot` or git pin `ffe7e270`) with copyright notice. Prefer dependency over vendoring a minified blob. |
| `kdrag0n/fastboot.js` `src/*.ts` (W6, W7) | MIT | Allowed with attribution. Pin the commit that understands `*/script.txt`. |
| `vendor/z-worker-pako.js` | zip.js (BSD-3-Clause, W18) | Allowed with BSD notice. Pulled by `android-fastboot` build (W9). |
| `vendor/pako_inflate.min.js` | pako MIT (W17) | Allowed with attribution. |
| `@zip.js/zip.js` | BSD-3-Clause (W18) | Allowed. |
| `device_common/generate-factory-images-common.sh` (W11) | Apache 2.0 (AOSP header) | **Do not copy** the generated STOP-banner `flash-all.sh`. Reuse the **command order** as a spec. |
| `script/generate-release.sh` (W12) | (GOS script repo; treat as Apache/AOSP-family; do not paste) | Spec only. |

**Recommendation (DEC-WEBINSTALL-005):** Reimplement the wizard and host orchestration in `vendor/guardtalk/web-installer/`. Depend on **MIT** `android-fastboot` (kdrag0n/fastboot.js, pin ≥ `ffe7e270`) and **BSD-3 / MIT** zip/pako transitives. Ship a `NOTICE` / `LICENSE-THIRD-PARTY`. Do not fork GrapheneOS site files. Do not paste GOS marketing sentences.

---

## Gap analysis vs `scripts/flash-from-remote.sh` (tokay MVP)

Root script header + steps (read-only, 1135 lines). Vendor copy: **1135 lines, `cmp` identical** on 2026-08-20. `RANGO_FLASH.md` still records stale drift (913 vs 857). KEEP both copies anyway (DEC-WEBINSTALL-004).

### What the CLI script already does (tokay)

Documented in the script header and steps 2–6:

1. Auto-detect `product` → bundle `releases/desktop-flash/latest` (tokay).
2. **Fail closed if bootloader locked** — prints unlock instructions; does **not** unlock.
3. Dual-slot bootloader (`--slot=other` dance) + radio + reboot.
4. `erase` + `flash avb_custom_key` from public `avb_pkmd.bin` **before OS** (matches W11, not legacy W6).
5. `oem uart disable`; `erase fips`; `erase dpm_a` / `dpm_b`.
6. `erase userdata` + `erase metadata`.
7. Enter **fastbootd before** GuardTalk boot images; flash `super.img` (or wipe-super + logicals); reboot to bootloader; flash GT boot/vbmeta with `--disable-verity --disable-verification`.
8. Does **not** lock the bootloader.
9. Transport: `scp` from a LAN build host, not HTTPS factory zips.

### Gaps the web installer must close (tokay)

| Gap | GOS web (official) | GT `flash-from-remote.sh` | Web-installer contract |
|-----|--------------------|---------------------------|------------------------|
| Unlock UX | Button + device confirm | Manual; script dies if locked | Required. Same wipe warning. |
| Image transport | HTTPS zip + IndexedDB | `scp` individual images | Later wave: signed/checksummed factory-zip **or** equivalent zip built from existing `releases/desktop-flash/*` (DEC-WEBINSTALL / T-WEBINSTALL-FACTORY-CHANNEL). No second image pipeline. |
| Integrity | OpenSSH `.sig` + `allowed_signers` (CLI); web trusts HTTPS + site | None (trusted LAN) | Factory-channel wave: hash + signature reject path. Public keys only. |
| Flash plan source | `script.txt` / `flash-all.sh` | Hard-coded image lists + fastbootd-first GT order | Flashcore must **trace to this ADR + tokay CLI order**, including reconnect. Do not invent a third order. |
| Reconnect | First-class WebUSB prompt (W3) | Host `fastboot` keeps USB | Required. Android desktop-mode pitfall (W1). |
| AVB key | Inside zip via `avb_pkmd.bin` | Same public blob from `REMOTE_KEY_DIR` | Public `avb_pkmd.bin` only. |
| Lock | Required for full verified boot (W1/W10) | Not performed | Product must expose lock as a **final** step (wizard must not lock before flash completes). GT may keep an expert “leave unlocked” path; default should match GOS (lock). |
| Verity flags | Official images intended to lock | `--disable-verity --disable-verification` on vbmeta | **Open follow-on:** locking a GT image that was flashed with verification disabled is not equivalent to GOS. Factory-channel + signing policy must resolve this before advertising “verified boot like GOS.” |
| Super / logical | `fastboot update` / `update-super` via script | Prefer `super.img`; fallback wipe-super + logicals | Tokay flashcore should accept a factory-style image zip **or** a GT super blob; document which artifact the channel ships. |
| Host OS matrix | Browsers above | Linux/macOS + platform-tools | Web path adds Windows/ChromeOS/Android hosts GOS already supports. |
| Quota / Incognito | Warned (W1/W3) | N/A | Required warning; no Incognito. Size from **actual** GT zip, not GOS’s 1700 MiB comment. |
| fwupd | Documented stop | Operator tribal knowledge | Surface in wizard for Linux. |
| Device allowlist | Many Pixels including rango | tokay / akita / rango | UI: **tokay only**. Reject other `product` values. |

### rango (hidden)

From `RANGO_FLASH.md` device table only (do not advertise as production-bootable):

| Codename | Pretty name | Bundle symlink |
|----------|-------------|----------------|
| tokay | Pixel 9 | `releases/desktop-flash/latest` |
| akita | Pixel 8a | `releases/desktop-flash/akita-latest` |
| rango | Pixel 10 Pro Fold | `releases/desktop-flash/rango-latest` |

CLI extras **not** in GOS web: rango stock rescue boot before first fastbootd; `init.insmod.rango.cfg` push; no `fips` erase; harvest/`0xfc` diagnostics. **Out of scope** this wave and for the MVP wizard. `rango-latest` stays `130756`. Do not add rango to the web allowlist until Architect re-binds boot-green.

---

## Follow-on waves (not this task)

| Wave | ID | Role of this ADR |
|------|-----|------------------|
| Factory channel | `T-WEBINSTALL-FACTORY-CHANNEL` | Manifest + signed zip from existing desktop-flash staging; tokay; public `avb_pkmd.bin` |
| Flashcore | `T-WEBINSTALL-FLASHCORE` | WebUSB orchestrator whose plan traces to the sequence + tokay CLI order |
| Wizard | `F-WEBINSTALL-WIZARD` | UI: `vendor/guardtalk/web-installer/wizard/` (GuardTalkOS-branded step list; tokay only) |

---

## Non-goals (this wave)

- No files under `vendor/guardtalk/web-installer/`
- No edits to either `flash-from-remote.sh`
- No rango boot RCA / `0xfc` work
- No private key material, env files, or private key paths in examples
- No verbatim GrapheneOS HTML/CSS/JS/marketing

---

## Decision

Proceed with a **reimplementation** of a WebUSB installer whose flash plan is the official GOS sequence (unlock → firmware + reconnect → AVB key → OS + reconnect → lock), specialized for **tokay** GuardTalkOS artifacts. Use MIT `android-fastboot` (kdrag0n/fastboot.js @ `ffe7e270` or newer compatible) plus attributed zip/pako. Treat this document as the Gate 0 contract for later waves.
