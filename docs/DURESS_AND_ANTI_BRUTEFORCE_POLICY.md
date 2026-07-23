# GuardTalk Duress + Anti-Bruteforce Policy

**Task:** `T-SEC-P2-WIPE` (Backend) → consumed by `F-SEC-P2-SECURITY-SCREENS` (Frontend)  
**Date:** 2026-07-22

## Purpose

- **Duress Password:** second credential that looks like a normal unlock but triggers
  immediate crypto-erase via the shared `SecureWipeEngine`.
- **Anti-bruteforce:** progressive delays (existing GateKeeper/Weaver + software
  rate-limiter) plus **automatic wipe at 10** unique HW-reaching failed unlocks.

Wipe semantics and UI API: [`SECURE_WIPE_SERVICE.md`](./SECURE_WIPE_SERVICE.md).

## Duress (hash / derived key only)

| Item | Detail |
|------|--------|
| Storage | `DuressCredentials` / `DuressCredential` in LockSettings |
| Material stored | Salt (`PasswordData`) + **stretched LSKF hash** via `SyntheticPasswordManager.stretchLskf` |
| Never stored | Raw PIN/password plaintext |
| Verify path | Failed primary unlock → background `isDuressCredential` → `SecureWipeEngine(DURESS)` |
| Setup UI | GrapheneOS `DuressPasswordMainActivity` / `DuressPasswordSetupActivity` |
| Pref key | `guardtalk_security_duress` |
| Gate mutation | `GuardTalkConfigMutations.SECURITY_DURESS_CONFIG` |

Frontend should deep-link to Duress setup; do not show Duress status on the lockscreen
(Phase 5 security status is post-unlock only).

## Anti-bruteforce counter (HW-backed)

### Requirements

- Counter is **hardware-backed** (TEE / RPMB / KeyMint / Weaver).
- **Never** a normal userdata plaintext file as the authority of record.
- Prefer survival across reboot; resist reset via ADB / Recovery / Safe Mode where enforceable.
- Wipe at **10** failed unlocks (configurable via prop).

### Implementation

| Priority | Mechanism | Notes |
|----------|-----------|--------|
| Primary | Reserved **Weaver** slot (last slot) | RPMB/SE; `SyntheticPasswordManager.guardTalk*AntiBruteforceCounter` |
| Fallback | GateKeeper / Weaver **LSKF timeout estimation** | When Weaver unavailable; maps HW timeout to failure index using the progressive schedule |

Authoritative wipe decision:

```text
HW-reaching failed unlock (passed software rate-limiter → GateKeeper/Weaver)
        │
        ▼
HwBackedFailedAttemptCounter.recordFailureAndGetCount(hwTimeout)
        │  Weaver++  OR  estimate from HW timeout
        ▼
count >= ro.guardtalk.anti_bruteforce_wipe_threshold (default 10)
        │
        ▼
SecureWipeEngine(ANTI_BRUTEFORCE)
```

Successful unlock → `guardTalkResetAntiBruteforceCounter()` (Weaver → 0).

### What is NOT authoritative

| Store | Role |
|-------|------|
| SPM `failure_counter` file | Software rate-limiter only; **not** wipe authority |
| DPM `mFailedPasswordAttempts` | Admin policy / UI; userdata XML; **not** wipe authority |

Duplicate wrong guesses and too-short credentials (software rate-limiter early reject)
do **not** increment the HW wipe counter.

### Progressive delays

Existing GrapheneOS / AOSP stack remains:

- Hardware: GateKeeper or Weaver throttle
- Software: `SoftwareRateLimiter` (complements HW; may enforce longer delays)

GuardTalk adds wipe@10 on top; it does not remove delays.

## Settings / Frontend contract

| Pref | Key | Controller |
|------|-----|------------|
| Duress | `guardtalk_security_duress` | `GuardTalkDuressPreferenceController` |
| Anti-bruteforce | `guardtalk_security_anti_bruteforce` | `GuardTalkAntiBruteforcePreferenceController` (informational) |
| Secure wipe | `guardtalk_security_secure_wipe` | `GuardTalkSecureWipePreferenceController` |
| Security status | `guardtalk_security_status` | `GuardTalkSecurityStatusPreferenceController` (post-unlock shell; **no Duress**) |

Helper: `GuardTalkSecureWipeHelper.isSecureWipeEnabled(context)`.

**No** Wipe or Duress Quick Settings tiles (Phase 3 QS catalog is Mic / Camera /
Battery Saver / Auto-reboot only). Security status shell is post-unlock only and
never lists Duress.

## Props

| Property | Default (tokay) |
|----------|-----------------|
| `ro.guardtalk.secure_wipe_enabled` | `1` |
| `ro.guardtalk.anti_bruteforce_wipe_threshold` | `10` |

## Rollback

1. Disable props / overlay bool.
2. Revert Weaver slot reservation + LSS hooks.
3. Rebuild `services` / `Settings`.

## Verification

```bash
lunch tokay-trunk_staging-userdebug
m services Settings -j$(nproc)
```
