# Komodo (Pixel 9 Pro XL) Port — desktop-flash stamp + CLI

> **Task:** `T-PORT-KOMODO-FLASH` (DEC-PORT-KOMODO-003)  
> **Depends on:** `T-PORT-KOMODO-LAYER` APPROVED  
> **FLASH:** Architect-APPROVED 2026-09-15T07:14:00Z. Stamp `komodo-latest` → `komodo-20260915-063833`.  
> **Not USB:** do **not** run `flash-from-remote.sh` against a phone until the operator says flash.  
> **Web installer:** `/install/` **does** advertise `komodo` (DEC-PORT-KOMODO-004: tokay + akita + komodo; `F-PORT-KOMODO-WEBINSTALL` APPROVED 2026-09-15T08:48:00Z).

## Lunch / build

```bash
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
source build/envsetup.sh && lunch komodo-trunk_staging-userdebug && m -j"$(nproc)"
```

Confirm:

| Var | Expected |
|-----|----------|
| `TARGET_PRODUCT` | `komodo` |
| `TARGET_BOARD_PLATFORM` | `zumapro` |
| `GUARDTALK_RADIO_EXCISED` | `true` |
| `PRODUCT_MODEL` | `GuardTalk Pixel 9 Pro XL` |

## Stamp (akita pattern)

Create `releases/desktop-flash/komodo-<UTCSTAMP>/` and symlink
`releases/desktop-flash/komodo-latest` → that directory.

Do **not** use `vendor/guardtalk/scripts/stage-rango-release.sh`.
Do **not** create `keys/komodo/`. Copy the **public** AVB blob only
(`keys/tokay/avb_pkmd.bin`, same as akita). **No `.pem` / `.pk8` is copied into
the stamp** — verified: `find releases/desktop-flash -name '*.pem' -o -name
'*.pk8'` = **0**, and the shipped `avb_pkmd.bin` is byte-identical
(`md5 67f509c1…`) to `keys/tokay/avb_pkmd.bin`.

> **Key-scope correction (`T-REMEDIATE-B6-STAMP-HONESTY`, DEC-REMEDIATE-019).**
> The earlier bare "No `.pem` / `.pk8`" read as a claim about the whole
> worktree. It is not a worktree-wide statement: `keys/tokay/` **does** contain
> an unencrypted PKCS#8 `avb.pem` plus a full `.pk8` set. Read-only provenance
> evidence: the eight package keys are **byte-identical** to the public AOSP
> test keys at `build/make/target/product/security/*.pk8` (cert subjects
> `O=Android, CN=Android`, 2008→2035), and `keys/tokay/avb_pkmd.bin`
> (`7728e30f…`) is the public AOSP test AVB key blob
> (`external/avb/test/data/testkey_rsa4096.pem`) — i.e. **public upstream AOSP
> test material**, not operator release keys. The standalone `keys/tokay/avb.pem`
> private key is a **different** key (derived public blob `962b174e…` matches no
> shipped bundle and no in-tree test key), so its origin is **UNRESOLVED** and
> should be settled by the operator. No private key content is reproduced here.

`init.insmod.komodo.cfg` comes from the real
`device/google/caimito-kernels/6.1/grapheneos/` tree (GNU `find` does not
traverse the `trunk-14096387` symlink).

`super.img` is omitted from the stamp (akita stamp also omitted `super.img`;
the flash script lists it as optional and uses `super_empty.img`).

`vbmeta_system.img` and `vbmeta_vendor.img` are copies of `vbmeta.img`.

Tokay `releases/desktop-flash/latest` and `akita-latest` must stay untouched
(expected inodes `193110379` / `193110357`).

## Desktop-flash CLI (`DEVICE=komodo`)

Both copies must stay identical (DEC-004):

- `scripts/flash-from-remote.sh`
- `vendor/guardtalk/scripts/flash-from-remote.sh`

Mapping:

| Function | `DEVICE=komodo` |
|----------|-----------------|
| `normalize_device` | exact `komodo` + substring |
| `device_pretty` | `Pixel 9 Pro XL (komodo)` |
| `apply_remote_paths` | `…/releases/desktop-flash/komodo-latest` |
| `apply_grapheneos_firmware_cleanup` | `tokay\|akita\|komodo` — uart + **erase fips** + dpm |
| extras / `install_insmod_cfg_via_adb` | `init.insmod.komodo.cfg` |

```bash
export REMOTE_HOST=oss-c1@192.168.2.220
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/komodo-latest
export REMOTE_KEY_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/komodo-latest
export LOCAL_WORK_DIR=./gt-flash-komodo
bash /path/to/scripts/flash-from-remote.sh
```

Or `DEVICE=komodo` (auto-maps product `komodo` → `komodo-latest`).

Desktop CLI is separate from `/install/`. The web installer **does** advertise
`komodo` (DEC-PORT-KOMODO-004: tokay + akita + komodo).

## Stamp record

| Item | Value |
|------|--------|
| `LUNCH_EXIT` | **0** |
| `BUILD_EXIT` | **0** (`#### build completed successfully` 2026-09-15T05:21:29Z) |
| Build log | `/tmp/t-port-komodo-flash-m-20260915T050731Z.log` |
| Stamp dir | `releases/desktop-flash/komodo-20260915-063833/` |
| Symlink | `releases/desktop-flash/komodo-latest` → `komodo-20260915-063833` |
| `SHA256SUMS` | 20 files, `sha256sum -c` OK |
| `super.img` | omitted (akita pattern; `super_empty.img` present) |
| Tokay `latest` inode | **193110379** (unchanged) |
| `akita-latest` inode | **193110357** (unchanged) |

Confirmed at lunch: `TARGET_PRODUCT=komodo`, `TARGET_BOARD_PLATFORM=zumapro`,
`GUARDTALK_RADIO_EXCISED=true`, `PRODUCT_MODEL=GuardTalk Pixel 9 Pro XL`.
