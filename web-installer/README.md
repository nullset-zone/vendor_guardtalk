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

The packer is **vendored** at `web-installer/scripts/pack-webinstall-channel.sh`
(T-WEBINSTALL-PACKER-VENDOR), so this folder packs its own channels with no
product repo beside it. The parent `vendor/guardtalk/scripts/pack-webinstall-channel.sh`
is a thin `exec` wrapper around that file — there is exactly one implementation.
It reads an existing `releases/desktop-flash/` tokay, akita, or komodo stamp and emits:

- GOS-like pointer `{releaseId} {unixEpoch} {product} dev`
- `SHA256SUMS` of published artifacts
- public `avb_pkmd.bin` only
- a flashcore-consumable file list (no factory zip this wave)

**Advertised allowlist:** `tokay` (Pixel 9), `akita` (Pixel 8a), and
`komodo` (Pixel 9 Pro XL). `shiba` / `husky` / `caiman` / `rango` are not
offered. **Channel label:** `dev/unlocked`
(`DEC-WEBINSTALL-007`). This is **not** GrapheneOS-equivalent locked
verified boot.

**DEC-010:** The current advertised komodo desktop-flash stamp
`komodo-20260915-063833` is `userdebug` / test-keys. It is **not** a
signed user `FLASH_READY` image. `LIVE_FLASH_CLAIMED` remains `false`.

**DEC-011 / DEC-018:** Debug sidecar flash is a **separate** channel
(`komodo-debug-latest` → `komodo-debug-20260918-180338`). `DEBUG_FLASH_READY`
is **true** for that sidecar stamp (Q-DEBUG-PACK APPROVED). `USB_GO` stays
**false**. Signed-user `FLASH_READY` stays **false**. DEC-017 leftover SHA
HOLD residual remains. Do not treat `komodo-20260915-063833` as that gate.
Do not retarget `komodo-latest`. No new SKU. No USB GO. See
`vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md`.

See `vendor/guardtalk/docs/WEB_INSTALLER_CHANNEL.md`.

## Consuming this directory (git submodule / standalone clone)

This directory is self-contained: it can be checked out on its own, with **no
Android `repo` checkout around it**. Nothing in it roots itself in a parent
layout any more — every host dependency is resolved through an ordered
candidate list (`scripts/lib/resolve.sh`) and a missing dependency is an
**actionable error (exit 2)**, never a bare `No such file or directory`.

**Licence:** MIT — the full text is in [`LICENSE`](LICENSE) and matches the
`"license": "MIT"` field in `package.json`. Copyright holder: *GuardTalkOS
contributors*. Third-party components and their licences: [`NOTICE`](NOTICE).

### Build artifacts — never committed

| Path | What it is | In git? |
|------|------------|---------|
| `channels/` | packed per-device channel trees (`manifest.json`, `SHA256SUMS`, `files.txt`, staged image links) produced by the packer | **never** (`.gitignore`) |
| `dist/` | `tsc` output and the emitted static site (`dist/site`) produced by `npm run routes:build` / `wizard:build` | **never** (`.gitignore`) |
| `node_modules/` | npm devDependencies (`typescript`, `tsx`, `@types/node`) | **never** (`.gitignore`) |

A fresh checkout therefore has no channels, no build output and no
`node_modules`. A checked-out copy of any of them is **not** evidence that a
build ran or that a channel was verified — regenerate and re-verify instead.
`channels/` is generated state that git cannot protect: after any drill or
pack, check it with `bash scripts/check-channel-integrity.sh` and re-pin the
anchors with `node scripts/gen-expected-anchors.mjs --check`.

### Example superproject wiring

The installer lives in the GuardTalk product repo (`vendor/guardtalk`), so a
superproject adds the product repo and uses the path inside it. `git submodule
add` writes this `.gitmodules` entry for you:

```ini
[submodule "vendor/guardtalk"]
	path = vendor/guardtalk
	url = git@github.com:nullset-zone/vendor_guardtalk.git
	branch = 16-qpr2
```

```bash
git submodule add git@github.com:nullset-zone/vendor_guardtalk.git vendor/guardtalk
git submodule update --init --recursive
cd vendor/guardtalk/web-installer
```

If a superproject consumes only this directory instead of the product repo, the
same commands apply with a shallower `path` (`vendor/guardtalk/web-installer`).
The channel packers are **vendored** here (`scripts/pack-webinstall-channel.sh`,
`scripts/pack-wizard-hosted-channels.sh`), so `bash scripts/pack-channels.sh`
works with no product repo beside it; only the readiness **reporter**
(`scripts/gt-ready-devices.sh`) still lives in the product repo, and
`gen-readiness-manifest.sh --from-tsv` needs no reporter at all.

### Environment contract

| Variable | Read by | Default | Meaning |
|----------|---------|---------|---------|
| `GUARDTALK_RELEASES_ROOT` | `scripts/gen-flash-matrix.mjs`, `scripts/gen-expected-anchors.mjs`, `scripts/readiness-gate.mjs`, `scripts/verify-flashall.sh`, `scripts/pack-channels.sh` (reported + passed through), `scripts/pack-wizard-hosted-channels.sh`, `scripts/pack-webinstall-channel.sh` | modules: `<repo root>/releases/desktop-flash` (repo root = three levels above the installer); the packers fall back to the tree root four levels above `scripts/` (last resort only) | The desktop-flash **release store** the channels are packed from and re-checked against. Point it at an external store when the installer is a submodule. |
| `GUARDTALK_INSTALLER_ROOT` | `scripts/readiness-gate.mjs` | the gate's own install location (`import.meta.url`) | The installer tree the gate **probes** (`channels/`, `docs/flash-matrix.json`, `status.json`). Set it explicitly for a `/tmp` drill; an explicit value that conflicts with `--matrix=` is an ERROR (exit 2), never a silent mismatch. |
| `GT_NODE_BIN` | `scripts/verify-flashall.sh` | first runnable Node.js >= 20 from an ordered candidate list (PATH, `$NODE`, user toolchains, Cursor server runtimes, system locations) | Explicit Node.js interpreter. **Authoritative**: a `GT_NODE_BIN` that does not run, or is older than 20, fails closed (exit 2) — it never falls through to another binary. |

Script-local variables (not part of the deployment contract):

| Variable | Read by | Meaning |
|----------|---------|---------|
| `NODE` | `scripts/build-site.sh` | Interpreter used for the local `tsc` (else the first `node` on PATH). |
| `GUARDTALK_RELEASES_DIR` | `scripts/readiness-gate.mjs` (`--releases-dir=` wins) | Drill/test override of the gate's release store; ordinary runs set `GUARDTALK_RELEASES_ROOT` instead. |
| `GT_MANIFEST_OUT`, `GT_MANIFEST_TIMESTAMP`, `GT_REPORTER_SHA` | `scripts/gen-readiness-manifest.sh` | Keep the generated manifest out of the committed file, freeze the timestamp, or supply a recorded reporter fingerprint (tests use these). |
| `CHANNEL` | `scripts/pack-webinstall-channel.sh` | `dev` (default) / `production`. `production` fails closed without a public signature. |
| `GUARDTALK_REQUIRE_SIGNED_ROOT` | `scripts/readiness-gate.mjs` | A mode that DEMANDS a signed channel root. Only `0`/`false`/`no` disable it; an **unrecognised value means REQUIRED** (fail closed). Equivalent to `--require-signed-root`. |

### First-run sequence (fresh clone, no parent checkout)

Run from the installer directory (`cd vendor/guardtalk/web-installer`, or the
root of a clone of the product repo's `web-installer/`). Exit code is shown for
each step; every one must be `0`.

```bash
# 0. Node.js >= 20. Either put node on PATH, or pin it explicitly:
export GT_NODE_BIN=/absolute/path/to/node        # optional

# 1. install (devDependencies only; node_modules/ is never committed)
npm ci                                           # -> 0

# 2. point the release store at the desktop-flash release store
export GUARDTALK_RELEASES_ROOT=/path/to/releases/desktop-flash

# 3. pack the advertised channels from that store (one per device)
for p in tokay akita komodo rango; do
  bash scripts/pack-webinstall-channel.sh \
    --stamp "$GUARDTALK_RELEASES_ROOT/$p-latest" \
    --out "channels/$p" --copy-images
done                                             # -> 0 each

# 4. build the emitted site (dist/ is never committed)
npm run routes:build                             # -> 0

# 5. readiness gate: 0 = PASS, 1 = FAIL, 2 = ERROR (never a silent PASS)
node scripts/readiness-gate.mjs                  # -> 0

# 6. tests (tsc --noEmit + host tests)
npm test                                         # -> 0
```

Step 3 uses the **vendored** per-channel packer, so it works in a standalone /
submodule checkout. The hosted packer is vendored too: `npm run channels:pack`
(=`bash scripts/pack-channels.sh`) packs all four products into this tree's
`channels/` and reads `GUARDTALK_RELEASES_ROOT/<product>-latest`, exactly like
step 3 — it is a one-command equivalent, not a different rule set.

The executed transcript and exit codes for this sequence (fresh clone, no
parent tree) are recorded in
`.agent-comm/evidence/T-WEBINSTALL-SUBMODULE-CONTRACT/`.

**Honesty:** a green sequence above means "packed, built, gated and tested on
this host". It does **not** mean any image boots, and it is **not** a live
flash: `BOOT_VERIFIED=false` and `LIVE_FLASH_CLAIMED=false` stand.

## Signed channel roots (production authenticity)

**The shipped dev channel is NOT signed.** Its authenticity mechanism is a
review-gated checked-in constant (`docs/expected-anchors.json`, D-035/D-036),
which `scripts/trust-anchor.mjs` states plainly as *"checked-in, review-gated;
not a signed root"*. Nothing in this tree holds a real signing key, and none may
be added.

A **signed channel root** is the mechanism that makes a channel
production-authenticated. Inside a channel directory:

| File | What it is |
|------|------------|
| `channel-root.txt` | canonical statement binding the channel root (see below) |
| `channel-root.txt.sig` | a detached signature over that statement |

```text
guardtalk-channel-root/1
product tokay
channel production
manifest.json <sha256>
SHA256SUMS <sha256>
```

`SHA256SUMS` transitively binds every artifact (including `avb_pkmd.bin`) and
`manifest.json` binds the machine-readable contract, so one signature covers the
whole channel root. The statement binds `product` too, so a signed root cannot
be replayed onto another product.

**The scheme is the packer's, not a new one.** `scripts/pack-webinstall-channel.sh`
already refuses `CHANNEL=production` unless a `.sig` and an `allowed_signers`
file are present, and verifies with `ssh-keygen -Y verify -I guardtalk-channel
-n "factory images"`. `scripts/channel-signature.mjs` performs the same check
and adds the statement binding: the statement is **re-derived from the bytes on
disk**, so a signature over a statement that describes *different* bytes
authenticates nothing.

**Trust comes from outside the channel.** The accepted trust list is
`docs/expected-allowed-signers` (git-tracked, review-gated) or an explicit
`--allowed-signers=`. Every entry naming `guardtalk-channel` must be scoped:

```text
guardtalk-channel namespaces="factory images" ssh-ed25519 AAAA… release@guardtalk
```

A trust list that ships *inside* the channel directory is self-signed — an
attacker who can write the channel writes both halves — so it is reported as
`channel-local` and never unlocks the signed mode.

**Verify a channel you have:**

```bash
# dev channel: unchanged, 14 clauses, still "unsigned / not GrapheneOS-equivalent"
node scripts/readiness-gate.mjs

# a mode that DEMANDS a signed root — fails closed (exit 1) if none verifies
node scripts/readiness-gate.mjs --require-signed-root
node scripts/readiness-gate.mjs --require-signed-root --allowed-signers=/path/to/allowed_signers
node scripts/readiness-gate.mjs --json          # read .authenticity and .anchorMode
```

What the gate reports is structured, not a log line:

```json
{ "anchorMode": { "id": "signed-root", "signed": true, "label": "signed-root (production)" },
  "authenticity": { "mechanism": "signed-root", "required": true, "status": "verified",
                    "trustSource": "out-of-band", "signer": "guardtalk-channel",
                    "namespace": "factory images", "channels": [ … ] } }
```

`authenticity.status` is one of `verified` / `absent` / `invalid` / `untrusted`
/ `unavailable`, and `anchorMode` only reaches `signed-root` when a verifier
actually verified something. The clause is **conditional**: the dev channel
keeps its exact 14-clause contract, while a channel that ships a broken
signature FAILS rather than being ignored.

**What a verified root does NOT prove:** that the trust list's claim about the
key's owner is true, that any image boots (`BOOT_VERIFIED=false`), or that a
live flash happened (`LIVE_FLASH_CLAIMED=false`).

The end-to-end proof (unsigned ⇒ FAIL, correctly signed ⇒ PASS with a
throwaway signer generated per run under the OS temp dir) is
`test/channel-signature.test.ts`; it never writes a key inside the repository.

## Flashcore (this wave)

The orchestrator loads `manifest.json` + `SHA256SUMS` + `files.txt`, builds a
deterministic plan (`firmware` → `avb_custom_key` → `os`), verifies SHA-256
before each artifact (fail closed), and drives a `FastbootTransport`:

1. `connect` + `getvar product` must match the advertised channel product (`tokay`, `akita`, or `komodo`)
2. `unlock` (`flashing unlock` if not already unlocked)
3. flash firmware artifacts, then a reconnect hook
4. erase + flash `avb_custom_key` from public `avb_pkmd.bin`
5. flash OS images, then a reconnect hook
6. `lock` (`flashing lock`) only after the plan completes

**DEC-009:** Live Flash/Lock are HOLD. Shipped execute is dry-run only.
This is not `flash-from-remote.sh`.

There is no factory `-install-` zip / `script.txt` this wave. The public wizard is `wizard/index.html` (`F-WEBINSTALL-WIZARD`). It consumes
flashcore (connect / unlock / plan / flash / lock). Live WebUSB is provided by
MIT `android-fastboot` (kdrag0n/fastboot.js), declared in `package.json`
`dependencies` and pinned to commit `ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9`
(`npm install` / `npm ci` resolves it). `adaptAndroidFastboot` wraps a
`FastbootDevice`; `connectAndroidFastboot()` loads the pinned package and
connects (`T-WEBINSTALL-WEBUSB-TRANSPORT-BUNDLE`, D-043).

The wizard still does not call `connectAndroidFastboot()`: it adapts a
runtime-supplied `window.FastbootDevice`, and the static wizard build has no
bundler step, so a bare `android-fastboot` import would not resolve in the
browser yet. Dry-run and plan preview work without a phone, live
`executePlan`/`lock` remain HOLD (DEC-009), and `LIVE_FLASH_CLAIMED` stays
`false`.

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

Then open `http://127.0.0.1:4173/wizard/`. Pick Pixel 9, Pixel 8a, or Pixel 9 Pro XL — the page
loads `../channels/{tokay|akita|komodo}/` from this server (no file picker).
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
