# GuardTalkOS web-install channel (dev/unlocked)

**Task:** `T-WEBINSTALL-FACTORY-CHANNEL`  
**Contract:** `vendor/guardtalk/docs/WEB_INSTALLER.md` (DEC-WEBINSTALL-001..007)  
**Status:** Channel metadata wave. Not a flash engine. Not a wizard.

This document describes the **factory-image + release-manifest channel** that a
future web installer can fetch. It is packed from an existing tokay
`releases/desktop-flash/` stamp. There is **no second image pipeline**.

## Label (DEC-WEBINSTALL-007)

This channel is **dev/unlocked**.

| Claim | Allowed? |
|-------|----------|
| Tokay desktop-flash artifacts, hashed, public AVB key published | yes |
| Bootloader expected unlocked (same as current CLI) | yes |
| GrapheneOS-equivalent **locked** verified boot | **no** |
| Production / `stable` channel | **no** (no in-tree public signer this wave) |

`verifiedBootClaim` in the manifest is `none`. Do not advertise this as a
locked GrapheneOS install.

## Advertised allowlist

**tokay (Pixel 9) and akita (Pixel 8a).**

The packer fails closed if the stamp product is not `tokay` or `akita`.
Pixel 8 (`shiba`), Pixel 8 Pro (`husky`), and `rango` are rejected.
Experimental or other desktop-flash products are rejected the same way.

## What the packer emits

Script: `vendor/guardtalk/scripts/pack-webinstall-channel.sh`

Default source: `releases/desktop-flash/latest` (must resolve to
`tokay-YYYYMMDD-HHMMSS`).

| File | Role |
|------|------|
| `tokay-dev` | GOS-like pointer: `{releaseId} {unixEpoch} tokay dev` |
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
{releaseId} {unixEpoch} tokay dev
```

Example (illustrative): `20260725-102506 1753439106 tokay dev`

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
```

If `releases/desktop-flash/latest` is missing, treat live packing as **HOLD**.
The script and schema remain the deliverable.

## Non-goals

- WebUSB flash engine (`T-WEBINSTALL-FLASHCORE`)
- Wizard UI (`F-WEBINSTALL-WIZARD`)
- Editing `flash-from-remote.sh` or `stage-rango-release.sh`
- Rebuilding Android images
- Committing factory zips or new image blobs
