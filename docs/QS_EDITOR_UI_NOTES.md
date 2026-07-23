# GuardTalk Quick Settings Editor — UI Notes

**Task:** `F-SEC-P3-QS-EDITOR`  
**Date:** 2026-07-23  
**Consumes:** `vendor/guardtalk/docs/QS_TILES_POLICY.md` (`T-SEC-P3-QS` ✅)

## Purpose

Document editor/catalog UX for the four Phase-3 QS tiles so QA can verify
add/remove without redesigning Backend tile engines.

## Editor catalog (source of truth)

| Surface | Resource | Phase-3 expectation |
|---------|----------|---------------------|
| QS edit / stock catalog | `quick_settings_tiles_stock` | Includes `battery`, `mictoggle`, `cameratoggle`, `autoreboot` |
| First-boot / reset panel | `quick_settings_tiles_default` | Mic / Camera / Battery Saver; **no** `autoreboot` |
| New UI default panel | `quick_settings_tiles_new_default` | Mic / Camera / Battery Saver; **no** `autoreboot` |

Overlay: `vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml`.

Stock list order groups Phase-3 specs for discoverability in edit mode:
`battery,mictoggle,cameratoggle,autoreboot` (adjacent block).

## Product labels (editor + tile)

| Spec | Product name | Overlay string |
|------|--------------|----------------|
| `mictoggle` | Mic | `quick_settings_mic_label` |
| `cameratoggle` | Camera | `quick_settings_camera_label` |
| `battery` | Battery Saver | `battery_detail_switch_title` |
| `autoreboot` | Auto-reboot | `quick_settings_auto_reboot_label` |

> `saver` is AOSP **Data Saver** — leave in stock catalog; do not treat as Battery Saver.

Overlay: `vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/strings.xml`.

## Add / remove contract (config / UX)

SystemUI edit mode (`EditModeViewModel` / `StockTilesRepository`) reads stock
specs and filters unavailable tiles via `TilesAvailabilityInteractor`.

| Action | Expected |
|--------|----------|
| Open QS → Edit | Catalog shows Mic, Camera, Battery Saver, Auto-reboot (when available) |
| Remove Mic / Camera / Battery Saver from panel | Tile moves to available catalog; can re-add |
| Add Auto-reboot from catalog | Appears on active panel; persists via `sysui_qs_tiles` |
| Reset QS to default | Active panel matches `quick_settings_tiles_default` / `new_default` — **no** Auto-reboot auto-placed |
| Auto-reboot availability | Requires `ro.guardtalk.auto_reboot_profiles=1` (tokay product prop) |

No parallel persistence store — stock Secure settings / tile pipeline only.

## Forbidden in editor / catalog

Do **not** register or surface as QS tiles:

- Lockdown
- USB data / USB protection
- Secure wipe
- Duress

These remain Settings / power-menu / service surfaces (Phase 2).

## Backend engines (out of scope)

Do not redesign: `AutoRebootTile`, `MicrophoneToggleTile`, `CameraToggleTile`,
`BatterySaverTile`. Frontend scope is overlay/config labels + catalog lists.

## Static verification

```bash
rg -n 'mictoggle|cameratoggle|,battery,|autoreboot' \
  vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml

# Auto-reboot must NOT be in default / new_default
rg -n 'quick_settings_tiles_(default|new_default)' -A1 \
  vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml \
  | rg -n 'autoreboot' && echo 'FAIL: autoreboot on default' || echo 'OK: catalog-only'

rg -n 'LockdownTile|UsbTile|SecureWipeTile|DuressTile' \
  frameworks/base/packages/SystemUI/src/com/android/systemui/qs || true
```

## Build

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m SystemUI -j$(nproc)
```

## Rollback (Law 11)

1. Revert overlay `config.xml` stock order / Phase-3 comments if needed.
2. Remove overlay `strings.xml` Phase-3 label overrides.
3. Remove this doc.
4. Rebuild `m SystemUI -j$(nproc)`.
