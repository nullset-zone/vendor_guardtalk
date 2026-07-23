# GuardTalk USB Protection Policy

**Task:** `T-SEC-P2-USB` (Backend) → consumed by `F-SEC-P2-SECURITY-SCREENS` (Frontend)  
**Date:** 2026-07-22

## Purpose

Enforce fail-closed USB data protection on GuardTalk products by **extending** GrapheneOS `UsbPortSecurityHooks` (and the existing USB duress watchdog path) — not inventing a parallel stack:

- USB **data path OFF** while the device is locked
- USB **data path OFF** before first unlock after boot (CE locked)
- ADB / MTP / PTP / APK-over-USB (sideload) **blocked** in that state
- **Charging-only** remains available
- After unlock (and CE unlocked): charging-only-when-locked mode restores the data path; unrestricted “On” and AFU modes are clamped away
- **No USB Quick Settings tile** (Phase 3 catalogs Mic/Camera/Battery Saver/Auto-reboot only)

Out of scope (later Phase-2 tasks): auto-reboot, wipe, duress engines (watchdog hook already present; not enabled by this task).

## Product properties (server fail-closed)

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.usb_protection_fail_closed` | `1` | Clamp modes + deny ADB/MTP/PTP while locked or `!isUserUnlocked` |
| `persist.security.usb_mode` | `2` | GrapheneOS `MODE_CHARGING_ONLY_WHEN_LOCKED` default |

Defined in `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`.

## Overlayable Settings bool

Override in `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml`.

| Bool | Overlay | Effect |
|------|---------|--------|
| `config_guardtalk_usb_protection_fail_closed` | `true` | Security row summaries / helper treat policy as on |

UI uses **bool OR prop** (fail-closed toward restriction). Server enforcement uses **props only**.

## Enforcement layers

```text
Boot / Keyguard lock / USER_UNLOCKED
        │
        ▼
UsbPortSecurityHooks (extended)
        │  getEffectiveMode() clamps AFU / On → WHEN_LOCKED
        │  setInitialMode → CHARGING_ONLY_IMMEDIATE (fail-closed)
        │  sys.port_security_mode + security.deny_new_usb2
        ▼
USB HAL data path disabled (charging-only)

UsbDeviceManager (defense-in-depth)
        │  sanitizeUsbFunctions / getChargingFunctions / applyAdbFunction
        ▼
ADB / MTP / PTP gadget functions stripped while denied
```

| Layer | Class | Role |
|-------|-------|------|
| Framework policy | `android.guardtalk.GuardTalkUsbProtectionPolicy` | Prop readers + mustDeny + mode clamp |
| Port security | `UsbPortSecurityHooks` | HAL data-path gate + USER_UNLOCKED re-eval |
| Gadget functions | `UsbDeviceManager` | Strip ADB/MTP/PTP while denied |
| SettingsLib keys | `GuardTalkUsbProtectionKeys` | Stable bool/prop/pref contract |
| Settings helper | `GuardTalkUsbProtectionHelper` | Bool **or** prop (UI) |
| Security row | `GuardTalkUsbProtectionPreferenceController` | Status + deep-link to Exploit protection (USB-C port) |
| Mode picker | `UsbPortSecurityPrefController` | Hides AFU / On under GuardTalk |

Existing USB duress watchdog (`maybeTriggerUsbDuressWipe`) is unchanged and remains opt-in via `vendor.guardtalk.usb_duress_wipe.enabled`.

## Post-unlock policy

1. After first unlock (CE unlocked) **and** keyguard not showing: port security may set `ports_enabled`; gadget functions follow user/ADB settings.
2. On subsequent lock: charging-only again (HAL + function strip).
3. Allowed persisted modes under fail-closed: Off, Charging-only, Charging-only when locked. AFU and On are clamped to Charging-only when locked.
4. Mutations that change USB protection policy should use GT Config gate key `security_usb_protection` (`GuardTalkConfigMutations.SECURITY_USB_PROTECTION`).

## Frontend contract (`F-SEC-P2-SECURITY-SCREENS`)

1. **USB protection row** (`guardtalk_security_usb_protection`) is live — shows policy/locked summaries; opens Exploit protection (USB-C port mode).
2. **Do not** register a USB Quick Settings tile.
3. Mode picker must not offer AFU or unrestricted On when fail-closed is on (Settings already filters).
4. Gate mutations with `GuardTalkConfigMutations.SECURITY_USB_PROTECTION`.
5. Full Security screen polish remains Frontend-owned.

### Suggested UI copy

- Policy: “USB data stays off while locked and before first unlock. Charging only.”
- Active deny: “USB data off (device locked or awaiting first unlock). Charging only.”

## Fail-closed rules

1. Missing / unset props on non-GuardTalk builds ⇒ policy **off** (stock GrapheneOS USB port security).
2. On GuardTalk (`usb_protection_fail_closed=1`):
   - `!UserManager.isUserUnlocked` ⇒ USB data denied
   - `KeyguardManager.isDeviceLocked` ⇒ USB data denied
3. If Keyguard/UserManager unavailable while policy on ⇒ treat as locked (deny).
4. UI hide alone is insufficient — HAL port security + gadget function strip are the authority.
5. Charging remains available whenever the data path is denied.

## Rollback (Law 11)

1. Set / remove in `guardtalk-tokay.mk`:
   - `ro.guardtalk.usb_protection_fail_closed=0` (or remove)
   - remove `persist.security.usb_mode=2` override if reverting default
2. Set overlay bool `config_guardtalk_usb_protection_fail_closed` to `false`.
3. Revert extensions in `UsbPortSecurityHooks` / `UsbDeviceManager` and Settings USB preference controller wiring to stubs.
4. Rebuild: `m services Settings -j$(nproc)`.

No irreversible state: sysprops and HAL mode are runtime-reversible; duress wipe engine is not armed by this task.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services Settings -j$(nproc)
```

### Runtime checks (device)

```bash
getprop ro.guardtalk.usb_protection_fail_closed   # expect 1
getprop persist.security.usb_mode                 # expect 2
getprop sys.port_security_mode                    # charging-only* while locked
getprop security.deny_new_usb2                    # 1 while data denied
```
