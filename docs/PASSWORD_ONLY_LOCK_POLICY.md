# GuardTalk Password-Only Device Lock Policy

**Task:** `T-SEC-P2-LOCK` (Backend) → consumed by `F-SEC-P2-SECURITY-SCREENS` (Frontend)  
**Date:** 2026-07-22

## Purpose

Enforce **password-only** device lock on GuardTalk products:

- PIN / pattern / biometric / Smart Lock enrollment and selection are blocked
- Lock-after-reboot (strong auth after boot) is enforced
- Inactivity / lock-after-timeout is clamped to a policy maximum
- Fail-closed: server rejects forbidden credential types even if UI is bypassed

Out of scope (later Phase-2 tasks): sensor privacy, Lockdown, USB, auto-reboot,
wipe, duress.

## Product properties (server fail-closed)

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.password_only_lock` | `1` | Only `CREDENTIAL_TYPE_PASSWORD` (or clear/`NONE`) may be set via LSS |
| `ro.guardtalk.lock_after_reboot` | `1` | Re-assert `STRONG_AUTH_REQUIRED_AFTER_BOOT` at LSS `systemReady` |
| `ro.guardtalk.max_lock_after_timeout_ms` | `300000` (5 min) | Max `Settings.Secure.LOCK_SCREEN_LOCK_AFTER_TIMEOUT` |

Defined in `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`.

## Overlayable Settings bools

Override in `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml`.

| Bool | Overlay | Effect |
|------|---------|--------|
| `config_guardtalk_password_only_lock` | `true` | Hide PIN/pattern/NONE/SWIPE in ChooseLockGeneric |
| `config_guardtalk_block_smart_lock` | `true` | Hide Trust Agents preference |
| `config_guardtalk_block_biometric_enroll` | `true` | Strip biometric enrollment extras in ChooseLockGeneric |
| `config_hide_none_security_option` | `true` | Hide “None” |
| `config_hide_swipe_security_option` | `true` | Hide “Swipe” |

## Enforcement layers

```text
Settings UI (ChooseLockGenericController / TrustAgents / Biometric extras)
        │  hide / skip forbidden options
        ▼
LockSettingsService.setLockCredential / setString / setLockCredentialWithToken
        │  GuardTalkLockSettingsHooks — SecurityException if forbidden
        ▼
LSKF / trust-agent storage
```

| Layer | Class | Role |
|-------|-------|------|
| Framework policy | `android.guardtalk.GuardTalkLockPolicy` | Prop readers + credential allow-list |
| LSS hooks | `com.android.server.locksettings.GuardTalkLockSettingsHooks` | Fail-closed mutations + boot clamp |
| SettingsLib keys | `com.android.settingslib.guardtalk.GuardTalkLockPolicyKeys` | Stable bool/prop name contract |
| Settings helper | `com.android.settings.guardtalk.GuardTalkLockPolicyHelper` | Bool **or** prop (UI) |
| Device lock row | `GuardTalkDeviceLockPreferenceController` | Security dashboard → ChooseLockGeneric |

## Frontend contract (`F-SEC-P2-SECURITY-SCREENS`)

1. **Device lock row** (`guardtalk_security_device_lock`) is live — launches
   `ChooseLockGeneric`. Only **Password** is selectable when policy is on.
2. Do **not** add PIN / pattern / fingerprint / face / Smart Lock tiles under
   Security when `config_guardtalk_password_only_lock=true`.
3. **Lock after screen timeout** (`lock_after_timeout`) must respect
   `ro.guardtalk.max_lock_after_timeout_ms` (Settings already clamps writes).
4. **Lock-after-reboot** is automatic (strong auth after boot). UI may show a
   non-toggleable status/summary; do not offer a user switch to disable it.
5. Gate Security mutations that change lock settings with
   `GuardTalkConfigMutations.SECURITY_DEVICE_LOCK` (GT Config password gate).
6. Full polish of Security screens remains Frontend-owned; Backend provides
   policy hooks + password-only ChooseLock path only.

### Suggested UI copy

- Summary: “Password only. PIN, pattern, biometrics, and Smart Lock are disabled.”
  (`R.string.guardtalk_security_device_lock_summary_password_only`)
- Lock-after-reboot status: “Required after every reboot”
- Inactivity: list values ≤ 5 minutes (or prop max)

## Lock-after-reboot

Platform `LockSettingsStrongAuth` already starts users with
`STRONG_AUTH_REQUIRED_AFTER_BOOT`. GuardTalk re-asserts this flag in
`LockSettingsService.systemReady()` when `ro.guardtalk.lock_after_reboot=1`
(or when password-only is on and the reboot prop is unset).

With biometrics and trust agents blocked, post-reboot unlock requires the
device password.

## Inactivity timeout

Keyguard (`KeyguardViewMediator.getLockTimeout`) reads
`Settings.Secure.LOCK_SCREEN_LOCK_AFTER_TIMEOUT`. GuardTalk:

1. Clamps the Secure setting at LSS `systemReady`
2. Clamps Settings preference writes in `LockAfterTimeoutPreferenceController`

Default max: **300000 ms (5 minutes)**.

## Fail-closed rules

1. Missing / unset props on non-GuardTalk builds ⇒ policy **off** (stock behavior).
2. On GuardTalk (`password_only_lock=1`): PIN/pattern setLockCredential ⇒
   `SecurityException`.
3. Biometric second-factor (Secondary domain) ⇒ `SecurityException`.
4. Non-empty trust-agent enablement via `setString` ⇒ `SecurityException`.
5. Escrow-token credential reset respects the same allow-list.
6. UI hide alone is insufficient — LSS is the authority.

## Rollback (Law 11)

1. Set props to `0` / remove overrides in `guardtalk-tokay.mk`:
   - `ro.guardtalk.password_only_lock=0`
   - `ro.guardtalk.lock_after_reboot=0`
   - remove or raise `ro.guardtalk.max_lock_after_timeout_ms`
2. Set overlay bools `config_guardtalk_password_only_lock`,
   `config_guardtalk_block_smart_lock`,
   `config_guardtalk_block_biometric_enroll` to `false`; restore
   `config_hide_none/swipe_security_option` if desired.
3. Revert LSS hooks (`GuardTalkLockSettingsHooks` call sites) and Settings
   controllers if a full code rollback is needed.
4. Rebuild: `m services Settings -j$(nproc)`.
5. No userdata migration; existing PIN/pattern credentials (if any from older
   builds) remain until the user changes them — new enrollments are blocked.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services Settings -j$(nproc)
```

Static checks (post-build):

```bash
# Symbols present
rg -n "GuardTalkLockPolicy|GuardTalkLockSettingsHooks|GuardTalkDeviceLockPreferenceController" \
  frameworks/base packages/apps/Settings vendor/guardtalk
```
