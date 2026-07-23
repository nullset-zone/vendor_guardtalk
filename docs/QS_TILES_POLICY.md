# GuardTalk Quick Settings Tiles Policy

**Task:** `T-SEC-P3-QS` (Backend) → consumed by `F-SEC-P3-QS-EDITOR` (Frontend)  
**Date:** 2026-07-22  
**Depends:** `Q-SEC-P2-STACK` ✅ APPROVED; `AUTO_REBOOT_POLICY.md` QS section

## Purpose

Register exactly **four** GuardTalk Phase-3 Quick Settings catalog tiles and
document persistence / press contracts. Prefer extending AOSP/GrapheneOS
Mic / Camera / Battery Saver infrastructure; add Auto-reboot tile.

## Catalog tiles (exactly four new GuardTalk registrations)

| Product name | Tile spec | Implementation | Default panel |
|--------------|-----------|----------------|---------------|
| Mic | `mictoggle` | Existing `MicrophoneToggleTile` (sensor privacy) | Already in product defaults (GrapheneOS + prior overlays) |
| Camera | `cameratoggle` | Existing `CameraToggleTile` (sensor privacy) | Already in product defaults |
| Battery Saver | `battery` | Existing `BatterySaverTile` (`TILE_SPEC=battery`) | Already in product defaults |
| Auto-reboot | `autoreboot` | New `AutoRebootTile` | **Catalog only** — not forced onto default / new_default |

> Note: AOSP `saver` is **Data Saver**, not Battery Saver. GuardTalk Battery
> Saver is the `battery` spec.

## Forbidden QS tiles (must not be registered)

| Forbidden | Spec / class | Status |
|-----------|--------------|--------|
| Lockdown | — | Not registered as QS tile |
| USB data / USB protection | — | Not registered as QS tile |
| Secure wipe | — | Not registered as QS tile |
| Duress | — | Not registered as QS tile |

These remain Settings / power-menu / service surfaces only (Phase 2).

## Catalog vs default panel

| List resource | Role |
|---------------|------|
| `quick_settings_tiles_stock` | QS editor / catalog — includes the four tiles (+ other stock tiles) |
| `quick_settings_tiles_default` | First-boot / reset active panel |
| `quick_settings_tiles_new_default` | New UI default panel |

- Mic / Camera / Battery Saver remain on default panels because product overlays
  already document them as defaults (T-BT-UI-SWEEP / GrapheneOS baseline).
- Auto-reboot is added **only** to `quick_settings_tiles_stock` so users can
  add it via the editor; it is not auto-placed on the panel.

Overlay source of truth for tokay:
`vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml`.

## Persistence

| State | Storage |
|-------|---------|
| Active QS tile set (user panel) | Existing SystemUI Secure settings / tile pipeline (`sysui_qs_tiles` etc.) |
| Mic / Camera block state | Sensor privacy framework (unchanged) |
| Battery Saver on/off | Power save framework (unchanged) |
| Auto-reboot profile timeout | `Settings.Global` / `ExtSettings.AUTO_REBOOT_TIMEOUT` (`settings_reboot_after_timeout`) |
| Auto-reboot last non-Off profile (for Off↔On toggle) | SystemUI SharedPreferences key `guardtalk_qs_auto_reboot_last_timeout_ms` |

## Auto-reboot tile contract

| Action | Behavior |
|--------|----------|
| Short press | Toggle Off ↔ last non-Off profile (or default **8h**) via `ExtSettings.AUTO_REBOOT_TIMEOUT` |
| Long press | Open Settings → Exploit protection (Auto reboot picker) — same deep-link as Security → Auto-reboot |

Availability: `GuardTalkAutoRebootPolicy.isProfilesEnabled()` (`ro.guardtalk.auto_reboot_profiles=1`).

Secondary label shows Off / Nh / On. Profile clamping and exclusion windows remain
framework/init responsibilities (`AUTO_REBOOT_POLICY.md`).

## Frontend contract (`F-SEC-P3-QS-EDITOR`)

1. QS editor must allow add/remove of **only** these four Phase-3 tiles as the
   GuardTalk “new” set (Mic, Camera, Battery Saver, Auto-reboot).
2. Do not expose Lockdown / USB / Secure wipe / Duress as QS tiles.
3. Auto-reboot long-press should land on Exploit protection Auto reboot (backend
   already sets the intent).
4. Tile persistence uses stock SystemUI panel storage — no parallel store.

## Implementation map

| Piece | Path |
|-------|------|
| Auto-reboot tile | `frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/AutoRebootTile.java` |
| Dagger module | `.../qs/tiles/AutoRebootModule.kt` (included from `ReferenceSystemUIModule`) |
| Mic / Camera | `MicrophoneToggleTile` / `CameraToggleTile` + `PolicyModule` |
| Battery Saver | `BatterySaverTile` + `BatterySaverModule` |
| Stock/default lists | SystemUI `res/values/config.xml` + GuardTalkSystemUIOverlay |

## Rollback (Law 11)

1. Remove `autoreboot` from `quick_settings_tiles_stock` (base + overlay).
2. Remove `AutoRebootModule` from `ReferenceSystemUIModule` and delete
   `AutoRebootTile.java` / `AutoRebootModule.kt` / related strings & drawables.
3. Leave Mic / Camera / Battery Saver infrastructure in place (stock AOSP).
4. Rebuild: `m SystemUI -j$(nproc)`.

No irreversible state: Global timeout and SharedPreferences are runtime-reversible.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
# If lunch fails on adevtool pin: temporarily comment
# vendor/google_devices/tokay/adevtool-version-check.mk, lunch, restore after.
m SystemUI -j$(nproc)
```

### Static checks

```bash
# Four Phase-3 specs present in GuardTalk stock catalog
rg -n 'mictoggle|cameratoggle|,battery,|autoreboot' \
  vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml

# Forbidden tiles absent from SystemUI QS tile classes
rg -n 'LockdownTile|UsbTile|SecureWipeTile|DuressTile|TILE_SPEC = "lockdown"|TILE_SPEC = "usb"|TILE_SPEC = "wipe"|TILE_SPEC = "duress"' \
  frameworks/base/packages/SystemUI/src/com/android/systemui/qs || true

# Auto-reboot registration
rg -n 'AutoRebootTile|autoreboot' frameworks/base/packages/SystemUI/src
```

### Runtime (device)

```bash
# Catalog: open QS edit — expect Mic, Camera, Battery Saver, Auto-reboot available
# Short-press Auto-reboot: settings get global settings_reboot_after_timeout toggles 0 ↔ last/8h
# Long-press: opens Exploit protection Auto reboot picker
```
