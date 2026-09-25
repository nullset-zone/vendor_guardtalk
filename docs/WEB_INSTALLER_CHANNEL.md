# GuardTalkOS web-install channel (dev/unlocked)

**Task:** `T-WEBINSTALL-DEVICES-INVENTORY` (channel packer bind; original factory-channel wave was `T-WEBINSTALL-FACTORY-CHANNEL`)  
**Contract:** `vendor/guardtalk/docs/WEB_INSTALLER.md` (DEC-WEBINSTALL-001..007, DEC-WEBINSTALL-015)  
**Status:** Channel metadata wave. Not a flash engine. Not a wizard.

This document describes the **factory-image + release-manifest channel** that a
future web installer can fetch. It is packed from an existing tokay, akita,
komodo, or rango `releases/desktop-flash/` stamp. There is **no second image
pipeline**.

## Label (DEC-WEBINSTALL-007)

This channel is **dev/unlocked**.

| Claim | Allowed? |
|-------|----------|
| Tokay / akita / komodo / rango desktop-flash artifacts, hashed, public AVB key published | yes |
| Bootloader expected unlocked (same as current CLI) | yes |
| Rango **production-boot-green** / SUPPORTED-green | **no** (experimental / boot HOLD; DEC-RANGO-REMEDIATE-002 / `0xfc`) |
| GrapheneOS-equivalent **locked** verified boot | **no** |
| Production / `stable` channel | **no** (no in-tree public signer this wave) |

`verifiedBootClaim` in the manifest is `none`. Do not advertise this as a
locked GrapheneOS install. Do not claim rango boot-green.

## Advertised allowlist (DEC-WEBINSTALL-015)

**tokay (Pixel 9), akita (Pixel 8a), komodo (Pixel 9 Pro XL), and rango (Pixel 10 Pro Fold, experimental / boot HOLD).**

The packer fails closed if the stamp product is not `tokay`, `akita`, `komodo`,
or `rango`. Unstamped Pixel 8 (`shiba`), Pixel 8 Pro (`husky`), `caiman`,
`tegu`, and `comet` are rejected. Rango is **image-ready and packable**; it is
**not** production-boot-green. Copy must chip experimental / boot HOLD.

`rango-latest` stays `rango-20260802-130756` (inode 193110354). Do not retarget.
DEC-009 live execute/lock remains HOLD.

Komodo channel source stamp: `releases/desktop-flash/komodo-latest`.  
Rango channel source stamp: `releases/desktop-flash/rango-latest` (130756).

## What the packer emits

Script: `vendor/guardtalk/scripts/pack-webinstall-channel.sh`

Default source: `releases/desktop-flash/latest` (must resolve to
`tokay-YYYYMMDD-HHMMSS`). Komodo packs from `releases/desktop-flash/komodo-latest`.
Rango packs from `releases/desktop-flash/rango-latest` (experimental / boot HOLD).

| File | Role |
|------|------|
| `tokay-dev` / `akita-dev` / `komodo-dev` / `rango-dev` | GOS-like pointer: `{releaseId} {unixEpoch} {product} dev` |
| `manifest.json` | Flashcore-oriented metadata (schema below) |
| `SHA256SUMS` | SHA-256 of every published artifact |
| `files.txt` | Name + phase + size (no zip) |
| `avb_pkmd.bin` | **Public** AVB key material only |

Default `--out` is **metadata + public key**. Images stay in the stamp.
`--copy-images` may symlink them into a staging directory for a release host.
Do **not** git-add multi-gigabyte copies.

### Channel pointer

Same shape as `https://releases.grapheneos.org/{product}-{channel}`:

```text
{releaseId} {unixEpoch} {product} dev
```

Example (illustrative): `20260725-102506 1753439106 tokay dev`

Komodo example: `{releaseId} {unixEpoch} komodo dev` packed from
`releases/desktop-flash/komodo-latest`.

Rango example: `{releaseId} {unixEpoch} rango dev` packed from
`releases/desktop-flash/rango-latest` (`rango-20260802-130756`). Rango remains
experimental / boot HOLD.

`releaseId` is the stamp time token so it traces to the desktop-flash directory.

### Flash order (DEC-WEBINSTALL-006)

The manifest `flashOrder` is always:

1. `firmware` — `bootloader.img`, `radio.img` if present
2. `avb_custom_key` — `avb_pkmd.bin`
3. `os` — remaining published `*.img`

The channel **does not emit a factory `-install-` zip this wave**. Wrapping the
stamp into a GOS-style zip would either invent `script.txt` (forbidden here)
or produce a ~2–3 GiB blob that must not be committed.

Flashcore (`vendor/guardtalk/web-installer/src/`) consumes `files.txt` +
`SHA256SUMS` + stamp blobs and flashes in this `flashOrder`. It does not
invent a factory `-install-` zip or `script.txt`. A later signed zip must
**preserve** this order. **DEC-009:** live Flash/Lock are HOLD (dry-run only).

### Secrets

The packer:

- copies `avb_pkmd.bin` only if it does not look like a private key
- fails closed if the stamp has no public `avb_pkmd.bin`
- fails closed if any stamp file contains a `BEGIN … PRIVATE` PEM header
- never writes `*.pem`, `*.pk8`, or `.env`

### Signatures

There is no in-tree **public** channel signer that can be used without private
keys. This wave therefore:

- `CHANNEL=dev` (default): **hash-only** (`SHA256SUMS`)
- `CHANNEL=production`: **fail closed** if a `.sig` + `allowed_signers` pair is
  missing (`--verify`); packing production is refused

Do not generate or commit private keys to “fill” the signature slot.

## Schema

- Schema: `vendor/guardtalk/web-installer/schema/channel-manifest.schema.json`
- Example: `vendor/guardtalk/web-installer/schema/manifest.example.json`

`product` / `advertisedDevices` enum is tokay, akita, komodo, rango (`maxItems`
4). `reservedProducts` must not list those advertised devices. Unstamped
products (shiba, husky, caiman, tegu, comet) stay out of the advertised enums.

## Commands (no phone)

```bash
vendor/guardtalk/scripts/pack-webinstall-channel.sh --help
vendor/guardtalk/scripts/pack-webinstall-channel.sh --self-test
vendor/guardtalk/scripts/pack-webinstall-channel.sh --dry-run
vendor/guardtalk/scripts/pack-webinstall-channel.sh \
  --stamp releases/desktop-flash/latest \
  --out /tmp/gt-webinstall-channel
vendor/guardtalk/scripts/pack-webinstall-channel.sh \
  --verify /tmp/gt-webinstall-channel \
  --verify-stamp releases/desktop-flash/latest
vendor/guardtalk/scripts/pack-webinstall-channel.sh \
  --stamp releases/desktop-flash/komodo-latest \
  --out /tmp/gt-webinstall-channel-komodo
vendor/guardtalk/scripts/pack-webinstall-channel.sh \
  --stamp releases/desktop-flash/rango-latest \
  --out /tmp/gt-webinstall-channel-rango
```

`--self-test` uses a **synthetic** rango fixture (tiny `boot.img`). It does
not USB-flash and does not claim boot-green. Hosted packer
`pack-wizard-hosted-channels.sh` also has a rango line; do not run it against
live multi-GiB stamps unless an operator asks.

If `releases/desktop-flash/latest` is missing, treat live packing as **HOLD**.
The script and schema remain the deliverable.

## Non-goals

- WebUSB flash engine (`T-WEBINSTALL-FLASHCORE`)
- Wizard UI (`F-WEBINSTALL-DEVICES-PICKER` owns picker copy)
- Editing `flash-from-remote.sh` or `stage-rango-release.sh`
- Rebuilding Android images
- Committing factory zips or new image blobs
- Promoting `rango-latest` off `130756`
- Claiming rango boot-green or live-flash GO
