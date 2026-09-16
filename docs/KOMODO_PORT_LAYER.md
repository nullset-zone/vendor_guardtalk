# Komodo (Pixel 9 Pro XL) Port — GuardTalk Device Layer

> **Task:** `T-PORT-KOMODO-LAYER`  
> **Date:** 2026-09-14  
> **Depends on:** `T-PORT-KOMODO-PREFLIGHT` ✅ APPROVED  
> **Decisions:** DEC-PORT-KOMODO-001, DEC-PORT-KOMODO-003  
> **Not FLASH:** no full `m`, no `komodo-latest`, no USB, no FLASH.md / web-installer advertise

## Results

| Item | Result |
|------|--------|
| Device layer | `vendor/guardtalk/device/komodo/` |
| REGEN_HOOKS | Applied to `vendor/google_devices/komodo/{komodo.mk,BoardConfig.mk}` |
| `device.mk` | adevtool does **not** emit `vendor/google_devices/komodo/device.mk`. `komodo.mk` inherits `vendor/adevtool/config/mk/google_devices/device/komodo/device.mk` (stock zumapro). Live tokay leaves that config unmodified. Flags load via `PRODUCT_DEVICE`; theme via `PRODUCT_DEVICE`. |
| `lunch komodo-trunk_staging-userdebug` | **OK** (`LUNCH_EXIT=0`; `TARGET_PRODUCT=komodo` in lunch banner — not the PREFLIGHT false-green) |
| Platform | `zumapro` |
| Fingerprint HAL | QFP (`qfp-daemon` / `libqfp-service` / `libqfpsuez`) — shared `fp-excised.mk`, not Goodix-only |
| Blocklist | `vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist` (caimito grapheneos + `blocklist nitrous`) |
| Full `m` image | Not run (FLASH task) |

## Kernel resolution method

`RELEASE_KERNEL_KOMODO_DIR` (`trunk_staging`) requires
`device/google/caimito-kernels/6.1/trunk-14096387`.

**Method:** symlink `trunk-14096387` → `grapheneos/` (akita LAYER filesystem alias).
No invented AOSP trunk blobs. `build/release` not edited.

**Insmod insurance:** GNU `find` does not traverse a symlink start path, so
`vendor/guardtalk/device/komodo/guardtalk-insmod.mk` copies
`init.insmod.komodo.cfg` from the real `grapheneos/` directory (akita/rango
precedent). FLASH still owns full `m`.

See `device/google/caimito-kernels/6.1/README.guardtalk-trunk-14096387.md`.

## Lunch verification (captured 2026-09-14 ~20:03 UTC)

Session env (not a git-config write):

```bash
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory \
  GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
source build/envsetup.sh && lunch komodo-trunk_staging-userdebug
```

```text
LUNCH_EXIT=0
TARGET_PRODUCT=komodo
TARGET_BOARD_PLATFORM=zumapro
GUARDTALK_RADIO_EXCISED=true
GUARDTALK_FEATURE_EXCISED_WAVE2=true
PRODUCT_MODEL=GuardTalk Pixel 9 Pro XL
GUARDTALK_PRODUCT_MODEL=GuardTalk Pixel 9 Pro XL
RELEASE_KERNEL_KOMODO_DIR=device/google/caimito-kernels/6.1/trunk-14096387
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE=vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist
```

Lunch banner also printed `TARGET_PRODUCT=komodo` / `BUILD_ID=BP4A.260205.002`.
Host printed `Build sandboxing disabled due to nsjail error.` (pre-existing; not a lunch FAIL).

## QFP (not Goodix)

Komodo is tokay-family zumapro. Shared `vendor/guardtalk/feature-excised/fp-excised.mk`
already filters QFP (`qfp-daemon`, `libqfp-service`, …) and Goodix. WAVE2 flag
engages that filter. Do **not** copy akita Goodix/zuma blocklist or HAL wiring.

## Tokay / akita non-regression

GuardTalk `vendor/guardtalk/device/{tokay,akita}/` and
`vendor/google_devices/{tokay,akita}/` intentionally untouched.

Stamp inodes unchanged vs PREFLIGHT:

- `releases/desktop-flash/akita-latest` → `akita-20260725-101434` (inode 193110357)
- `releases/desktop-flash/latest` → `tokay-20260725-102506` (inode 193110379)
- No `releases/desktop-flash/komodo-latest`

`FLASH.md` and `vendor/guardtalk/web-installer/` were not edited and still do
not name komodo.

## Layer files

| File | Role |
|------|------|
| `guardtalk-flags.mk` | Radio/wave2/voice; `GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 9 Pro XL`; face empty |
| `BoardConfig-excised-late.mk` | Modem OTA filter, radio cmdline, komodo blocklist override |
| `vendor_dlkm.modules.blocklist` | caimito grapheneos baseline + `blocklist nitrous` |
| `guardtalk-insmod.mk` | Explicit `init.insmod.komodo.cfg` install (symlink TARGET_KERNEL_DIR) |
| `guardtalk-theme.mk` | Thin wrapper → shared branding mk (`PRODUCT_DEVICE`) |
| `guardtalk-audio.mk` / `guardtalk-camera.mk` | Voice/face filters (face gated off); recipe parity |
| `product-common-excised.mk` | Tokay recipe parity (optional; not hooked in live adevtool device.mk) |
| `REGEN_HOOKS.md` | Re-apply after `adevtool generate-all -d komodo` |
