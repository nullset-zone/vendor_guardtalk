# GuardTalk Secure Wipe Service

**Task:** `T-SEC-P2-WIPE` (Backend) → consumed by `F-SEC-P2-SECURITY-SCREENS` (Frontend)  
**Date:** 2026-07-22

## Purpose

Single shared **crypto-erase** engine for:

1. **Secure wipe UI** (password + confirm)
2. **Duress Password** (hash/derived key match)
3. **Anti-bruteforce** wipe at **10** HW-backed failed unlocks

Reuse GrapheneOS `DuressWipe` → `RecoverySystemService.deleteSecrets()` (FBE / KeyMint
key destruction). Recoverable by reflash — **not** flash-overwrite-as-wipe, **not** a
hardware brick. **No Wipe / Duress QS tiles.**

Companion policy: [`DURESS_AND_ANTI_BRUTEFORCE_POLICY.md`](./DURESS_AND_ANTI_BRUTEFORCE_POLICY.md).

## Product properties (server)

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.secure_wipe_enabled` | `1` | Enable shared wipe engine + Settings rows |
| `ro.guardtalk.anti_bruteforce_wipe_threshold` | `10` | Wipe after N HW-backed failed unlocks |

Defined in `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`.

## Overlayable Settings bool

| Bool | Overlay | Effect |
|------|---------|--------|
| `config_guardtalk_secure_wipe_enabled` | `true` | Security → Secure wipe + Duress rows available |

UI uses **bool OR prop**. Server enforcement uses **props only**.

## Wipe engine (single stack)

```text
USER_REQUESTED / DURESS / ANTI_BRUTEFORCE
        │
        ▼
SecureWipeEngine.run(context, Reason)
        │
        ├── EuiccWipe (best-effort, parallel)
        ├── RecoverySystemService.deleteSecrets()
        │     ├── AndroidKeyStoreMaintenance.deleteAllKeys()  (KeyMint / FBE wrapping keys)
        │     ├── ISecretkeeper.deleteAll()
        │     └── ExtendedWipeWithoutReboot (vold CE/DE / metadata keys)
        └── PowerManagerService.lowLevelShutdown()
```

| Layer | Class | Role |
|-------|-------|------|
| Engine | `com.android.server.locksettings.SecureWipeEngine` | Sole wipe implementation |
| Compat | `DuressWipe` | Delegates to `SecureWipeEngine(DURESS)` |
| Policy | `android.guardtalk.GuardTalkSecureWipePolicy` | Props / threshold |
| Binder | `ILockSettings.requestSecureWipe` | UI path after owner LSKF verify |
| SettingsLib keys | `GuardTalkSecureWipeKeys` | Pref keys + prop names for Frontend |

### Call sites (must stay on this engine)

| Trigger | Entry |
|---------|--------|
| Secure wipe UI | `LockPatternUtils.requestSecureWipe` → `SecureWipeEngine(USER_REQUESTED)` |
| Duress credential | `DuressPasswordHelper` → `DuressWipe` → `SecureWipeEngine(DURESS)` |
| USB duress path | `UsbPortSecurityHooks` → `DuressWipe` → same engine |
| Anti-bruteforce@10 | `LockSettingsService` → `SecureWipeEngine(ANTI_BRUTEFORCE)` |

Do **not** fork a second wipe stack for Duress vs UI vs anti-bruteforce.

## Secure wipe UI API (Frontend)

| Item | Value |
|------|--------|
| Pref key | `guardtalk_security_secure_wipe` (`GuardTalkSecureWipeKeys.PREF_SECURE_WIPE`) |
| Controller | `GuardTalkSecureWipePreferenceController` |
| Activity | `GuardTalkSecureWipeActivity` (password → irreversible warning → erase confirm → `requestSecureWipe`) |
| Gate mutation | `GuardTalkConfigMutations.SECURITY_SECURE_WIPE` |
| Summary string | `guardtalk_security_secure_wipe_summary` |

Frontend (`F-SEC-P2-SECURITY-SCREENS`) polished confirm UX (password + irreversible warning +
final erase). Callers **must** keep calling `LockPatternUtils.requestSecureWipe(ownerCredential)`
so the shared engine runs.

## FBE / KeyMint semantics

- Wipe destroys **keys**, not by overwriting flash userdata as the wipe mechanism.
- After wipe, device powers off; data is unrecoverable without prior keys.
- Device identity can be restored by **reflash** / factory provisioning (recoverable-by-reflash).
- Not a hardware brick; not a permanent fuse burn.

## Forbidden

- Wipe / Duress / USB / Lockdown Quick Settings tiles (this task)
- Treating flash overwrite as the wipe primitive
- Userdata plaintext file as the anti-bruteforce counter authority

## Rollback

1. Set `ro.guardtalk.secure_wipe_enabled=0` (or remove props) and overlay bool `false`.
2. Revert `SecureWipeEngine` / LSS / Settings stubs / Weaver reservation.
3. Rebuild: `m services Settings -j$(nproc)`.
4. `DuressWipe` can remain as a thin delegate or be restored to its prior body.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services Settings -j$(nproc)
```

adevtool pin bypass+restore OK if needed for Settings rebuild.
