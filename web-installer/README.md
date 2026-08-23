# GuardTalkOS web-installer

This directory is the product path for the GuardTalkOS WebUSB installer
(`DEC-WEBINSTALL-002`).

| Path | What it is |
|------|------------|
| `schema/channel-manifest.schema.json` | JSON Schema for a channel `manifest.json` |
| `schema/manifest.example.json` | Example packed from a real tokay desktop-flash stamp |
| `src/` | Flash orchestrator (`T-WEBINSTALL-FLASHCORE`) |
| `wizard/` | GuardTalkOS-branded installer UI (`F-WEBINSTALL-WIZARD`) |
| `test/` | Host tests with a mocked Fastboot/WebUSB transport |
| `NOTICE` | Third-party licenses |

The packer lives at `vendor/guardtalk/scripts/pack-webinstall-channel.sh`.
It reads an existing `releases/desktop-flash/` tokay stamp and emits:

- GOS-like pointer `{releaseId} {unixEpoch} tokay dev`
- `SHA256SUMS` of published artifacts
- public `avb_pkmd.bin` only
- a flashcore-consumable file list (no factory zip this wave)

**Advertised allowlist:** `tokay` (Pixel 9) and `akita` (Pixel 8a).
`shiba` / `husky` / `rango` are not offered. **Channel label:** `dev/unlocked`
(`DEC-WEBINSTALL-007`). This is **not** GrapheneOS-equivalent locked
verified boot.

See `vendor/guardtalk/docs/WEB_INSTALLER_CHANNEL.md`.

## Flashcore (this wave)

The orchestrator loads `manifest.json` + `SHA256SUMS` + `files.txt`, builds a
deterministic plan (`firmware` → `avb_custom_key` → `os`), verifies SHA-256
before each artifact (fail closed), and drives a `FastbootTransport`:

1. `connect` + `getvar product` must be `tokay`
2. `unlock` (`flashing unlock` if not already unlocked)
3. flash firmware artifacts, then a reconnect hook
4. erase + flash `avb_custom_key` from public `avb_pkmd.bin`
5. flash OS images, then a reconnect hook
6. `lock` (`flashing lock`) only after the plan completes

**DEC-009:** Live Flash/Lock are HOLD. Shipped execute is dry-run only.
This is not `flash-from-remote.sh`.

There is no factory `-install-` zip / `script.txt` this wave. The public wizard is `wizard/index.html` (`F-WEBINSTALL-WIZARD`). It consumes
flashcore (connect / unlock / plan / flash / lock). Live WebUSB should wrap MIT
`android-fastboot` (kdrag0n/fastboot.js pin ≥ `ffe7e270`) via
`adaptAndroidFastboot`. That library is **not** bundled this wave; dry-run and
plan preview work without a phone.

Host harness (prints a plan; does **not** open USB):

```bash
cd vendor/guardtalk/web-installer
npx tsx src/cli.ts --channel /path/to/channel-dir
```

Wizard (no phone required for plan preview):

```bash
cd vendor/guardtalk/web-installer
npm run channels:pack
npm run wizard:build
npm run wizard:serve
```

Then open `http://127.0.0.1:4173/wizard/`. Pick Pixel 9 or Pixel 8a — the page
loads `../channels/{tokay|akita}/` from this server (no file picker).
**Dry-run** walks flashcore without USB.

If the Pixel is still in stock Android, use **Reboot to Fastboot** on the page.
That button talks ADB over WebUSB and sends `reboot:bootloader` (the same
command as `adb reboot bootloader`). Enable OEM unlocking and USB debugging
first, plug USB into the computer running the browser, and stop a local
`adb` daemon (`adb kill-server`) so Chromium can claim the interface.

Fallback on the USB host:

```bash
vendor/guardtalk/scripts/reboot-to-fastboot.sh
```

`flash-from-remote.sh` already does the same auto-reboot when the phone is in
Android or recovery. This does **not** lift DEC-009 live Flash/Lock.
Channel label is **dev/unlocked**. This is not GrapheneOS-equivalent locked
verified boot, and it does not claim `flash-from-remote.sh` dual-slot parity.

## Browser ADB key storage (private key at rest)

The first time the wizard talks ADB over WebUSB, it generates a 2048-bit RSA
host key (`RSASSA-PKCS1-v1_5`, SHA-1) with WebCrypto and stores the **full
private JWK — including the private exponent `d` and CRT components
`p`, `q`, `dp`, `dq`, `qi` — unencrypted in `localStorage` under
`guardtalk.webadb.rsa-jwk`** (`wizard/adb-rsa.ts`). This is the browser
equivalent of `~/.android/adbkey`.

Why: ADB host keys must persist so the phone keeps trusting the browser after
the first "Allow USB debugging" prompt; `localStorage` is the only synchronous,
persistent store available without extra permissions.

Threat model / limits:

- Any script running in this origin (e.g. via XSS) can read the key.
- Anyone with local disk access to the browser profile can read it.
- Exposure is bounded to ADB-debugging trust for your device — the key is not a
  disk-encryption or account credential — but treat the browser profile as
  sensitive.

How to clear it (revokes the browser's ADB trust; the phone will re-prompt on
next use):

- DevTools console: `localStorage.removeItem("guardtalk.webadb.rsa-jwk")`
- Or clear site data for the wizard origin in the browser settings.
- Then remove the matching entry on the device if desired:
  Settings → Developer options → USB debugging authorizations → Revoke.

A future wave may move to a non-extractable `CryptoKey` in IndexedDB or offer a
session-only key. Until then, use the wizard from a trusted browser profile.

## Tests

Host-only. A passing run is **not** a live-flash PASS.

```bash
cd vendor/guardtalk/web-installer
npm install
npm test
```

Requires Node ≥ 20. Tests mock `FastbootDevice` / WebUSB.
