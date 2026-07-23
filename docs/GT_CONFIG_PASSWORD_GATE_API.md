# GuardTalk GT Config Password Gate API

**Task:** `T-SEC-P1-GTGATE` (Backend) → consumed by `F-SEC-P1-ABOUT-APPS` / GT Config UX  
**Date:** 2026-07-22

## Purpose

Security mutations performed via **GT Config** (and maintenance-gated Settings
entries) require verification of the **main device password**. Unauthorized
mutations are rejected (**fail-closed**). Wipe/duress execution is **out of
scope** (Phase 2 / `T-SEC-P2-WIPE`).

## Service

| Item | Value |
|------|--------|
| ServiceManager name | `guardtalk_config_gate` |
| AIDL | `android.os.IGuardTalkConfigGate` |
| SystemService | `com.android.server.guardtalk.GuardTalkConfigGateService` |
| LocalServices | `com.android.server.guardtalk.GuardTalkConfigGateInternal` |
| Client helper | `android.guardtalk.GuardTalkConfigGateManager` |
| Settings helper | `com.android.settings.guardtalk.GuardTalkConfigGateClient` |
| Mutation keys | `android.guardtalk.GuardTalkConfigMutations` |
| Enable prop | `ro.guardtalk.config_password_gate` (default `true`) |

## Frontend flow (`F-SEC-P1-ABOUT-APPS` / `F-SEC-P4-SYSTEM-UI` GT Config UX)

```text
1. User opens Security → GT Config (or a maintenance-gated / mutation entry)
2. Settings launches KeyguardManager.createConfirmDeviceCredentialIntent
   via GuardTalkConfigGateClient.startConfirm(fragment)
3. On Activity.RESULT_OK → GuardTalkConfigGateClient.handleActivityResult(...)
   → IGuardTalkConfigGate.onDeviceCredentialConfirmed(userId)
4. Short-lived in-memory session opens (default TTL = 5 minutes)
5. Before any Security mutation, call:
     GuardTalkConfigGateManager.assertMutationAuthorized(userId, mutationKey)
   or Settings:
     GuardTalkConfigGateClient.assertAuthorized(context, mutationKey)
6. Unauthorized ⇒ SecurityException / false (fail-closed)
```

### Security dashboard mutations (`F-SEC-P4-SYSTEM-UI`)

When overlay `config_security_mutations_require_password=true`,
`GuardTalkSecurityDashboardFragment` gates these rows behind the same
confirm→session flow (mutation keys below):

| Preference key | Mutation key |
|----------------|--------------|
| `guardtalk_security_device_lock` | `security_device_lock` |
| `guardtalk_security_sensor_privacy` | `security_sensor_privacy` |
| `guardtalk_security_usb_protection` | `security_usb_protection` |
| `guardtalk_security_lockdown` | `security_lockdown` |
| `guardtalk_security_auto_reboot` | `security_auto_reboot` |
| `guardtalk_security_duress` | `security_duress_config` |
| `guardtalk_security_secure_wipe` | `security_secure_wipe` |
| `guardtalk_gt_config` | `gt_config_write` (launch) |

Status rows remain read-only (no gate). Network controls must never appear.

### Request code

`GuardTalkConfigGateClient.REQUEST_CONFIRM_FOR_GT_CONFIG` = `7601`

### Mutation keys (P1 contract)

| Key | Constant | Notes |
|-----|----------|-------|
| `gt_config_write` | `GT_CONFIG_WRITE` | Generic GT Config writes |
| `maintenance_access` | `MAINTENANCE_ACCESS` | Apps/Network maintenance-gated entries |
| `security_device_lock` | `SECURITY_DEVICE_LOCK` | Phase-2 owner |
| `security_sensor_privacy` | `SECURITY_SENSOR_PRIVACY` | Phase-2 owner |
| `security_usb_protection` | `SECURITY_USB_PROTECTION` | Phase-2 owner |
| `security_lockdown` | `SECURITY_LOCKDOWN` | Phase-2 owner |
| `security_auto_reboot` | `SECURITY_AUTO_REBOOT` | Phase-2 owner |
| `security_duress_config` | `SECURITY_DURESS_CONFIG` | Config only; wipe = P2 |

Unknown keys **fail closed**.

## Binder API (summary)

```java
boolean isGateEnabled();
boolean hasSecureLockScreen(int userId);
boolean isAuthorized(int userId);
boolean isMutationAuthorized(int userId, String mutationKey);
boolean onDeviceCredentialConfirmed(int userId); // privileged
void closeSession(int userId);                    // privileged
void assertMutationAuthorized(int userId, String mutationKey); // throws
long getSessionRemainingMillis(int userId);
```

## System-server callers (Phase 2+)

```java
GuardTalkConfigGateInternal gate =
        LocalServices.getService(GuardTalkConfigGateInternal.class);
if (gate == null) {
    throw new SecurityException("GT Config gate missing (fail-closed)");
}
gate.assertMutationAuthorized(userId, GuardTalkConfigMutations.SECURITY_USB_PROTECTION);
```

## Fail-closed rules

1. Missing binder / LocalServices ⇒ unauthorized.
2. No secure lock screen ⇒ session cannot open.
3. Expired / never-opened session ⇒ mutation rejected.
4. Unknown mutation key ⇒ rejected.
5. Safe mode (`ro.sys.safemode` / `persist.sys.safemode`) ⇒ rejected.
6. Auth state is **in-memory only** (not `Settings.Global` / `Secure`) so
   `adb shell settings put` cannot grant access.
7. `SHELL_UID` / `ROOT_UID` cannot call `onDeviceCredentialConfirmed`.
8. Screen-off clears all sessions.

## P1 bypass resistance (P5 hardens further)

| Vector | P1 posture |
|--------|------------|
| ADB `settings put` | No persisted auth flag to flip |
| `adb shell` binder | Shell/root rejected for session open |
| Recovery | `system_server` gate not running |
| Safe Mode | Explicit deny |
| UI hide only | Enforcement is service-side, not preference visibility |

## Product wiring

```make
# vendor/guardtalk/device/tokay/guardtalk-tokay.mk
PRODUCT_PROPERTY_OVERRIDES += \
    ro.guardtalk.config_password_gate=1
```

## Rollback (Law 11)

1. Set `ro.guardtalk.config_password_gate=0` (bring-up escape hatch), **or**
2. Revert `GuardTalkConfigGateService` registration in `SystemServer` and related
   Settings hooks / sepolicy entries.
3. No persistent userdata migrations; sessions are RAM-only.

## Out of scope (do not implement here)

- Secure wipe / duress password execution (`T-SEC-P2-WIPE`)
- Full production hardening / TEE binding (`T-SEC-P5-HARDEN`)
- Contacts UI suppression (`T-SEC-P1-CONTACTS`)
