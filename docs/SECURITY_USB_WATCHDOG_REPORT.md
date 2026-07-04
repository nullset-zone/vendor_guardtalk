# SECURITY USB WATCHDOG REPORT — A-USB-WATCHDOG-RESEARCH

**Status:** READ-ONLY research. No files were edited, no code implemented, no commits made.
**Gate -1:** Acknowledged — Guardian First, read-only audit. No doctrine/governance files accessed.
**Source tree:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/` (AOSP + GrapheneOS, tokay / Pixel 9)
**Auditor:** AEGIS Auditor
**Date:** 2026-07-02

---

## 0. Executive Summary

**Recommendation: GO with caveats.** A USB-data-cable watchdog is technically feasible and integrates cleanly with GrapheneOS's *existing* USB-C port security, auto-reboot, and duress-PIN wipe infrastructure. The defensible design is **recoverable crypto-erase** (reuse `RecoverySystemService.deleteSecrets()` + `ExtendedWipeWithoutReboot`), NOT a permanent hardware brick. The wipe MUST be gated to (a) locked/duress-armed state and (b) verified-boot green, to avoid a trivial self-DoS from any charge cable. MVP: **duress-armed + locked + data-role transition ⇒ crypto-erase**; no auto-wipe on data-cable-without-duress.

The single most important finding: GrapheneOS already ships the *entire* primitive surface this feature needs — `UsbPortSecurityHooks` listens for `ACTION_USB_PORT_CHANGED` with `UsbPortStatus` (including `getDataRole()`), `DuressWipe` already calls `RecoverySystemService.deleteSecrets()` which already drives `vold` to destroy FBE/metadata keys. The watchdog is largely an **integration + policy** task, not greenfield engineering.

---

## 1. USB Data-Cable Detection Mechanisms

### 1.1 Framework-level (RECOMMENDED detection path)

GrapheneOS's `UsbPortSecurityHooks` already receives every USB port state change via the system broadcast:

```104:131:frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java
    void registerPortChangeReceiver() {
        var receiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                Slog.d(TAG, "PortChangeReceiver: " + intent + ", extras " + intent.getExtras().deepCopy());
                UsbPortStatus portStatus = intent.getParcelableExtra(UsbManager.EXTRA_PORT_STATUS,
                        UsbPortStatus.class);
                if (portStatus.isConnected()) {
                    ++usbConnectEventCount;
                    Slog.d(TAG, "usbConnectEventCount: " + usbConnectEventCount);
                }
                ...
            }
        };
        var filter = new IntentFilter(UsbManager.ACTION_USB_PORT_CHANGED);
        context.registerReceiver(receiver, filter, null, handler);
    }
```

`UsbManager.ACTION_USB_PORT_CHANGED` and `EXTRA_PORT_STATUS` are public system broadcast/constants:

```142:143:frameworks/base/core/java/android/hardware/usb/UsbManager.java
    public static final String ACTION_USB_PORT_CHANGED =
            "android.hardware.usb.action.USB_PORT_CHANGED";
```
```389:395:frameworks/base/core/java/android/hardware/usb/UsbManager.java
    public static final String EXTRA_PORT_STATUS = "portStatus";
```

### 1.2 Distinguishing DATA cable from CHARGE-ONLY

`UsbPortStatus` carries `dataRole` constants `DATA_ROLE_DEVICE` / `DATA_ROLE_HOST` / `DATA_ROLE_NONE`. These are imported and used throughout `UsbPortManager`:

```22:24:frameworks/base/services/usb/java/com/android/server/usb/UsbPortManager.java
import static android.hardware.usb.UsbPortStatus.DATA_ROLE_DEVICE;
import static android.hardware.usb.UsbPortStatus.DATA_ROLE_HOST;
```

A **charge-only** cable (no D+/D- pins, or USB-C charging-only with CC pull but no data role negotiation) does **not** transition `data_role` away from `DATA_ROLE_NONE`. A **data** cable causes the port to negotiate a data role (`host` when the phone is the DFP/host, `device` when the phone is the UFP/peripheral). Therefore:

> **Detection predicate: `portStatus.isConnected() && portStatus.getDataRole() != DATA_ROLE_NONE`** (or, more strictly, `== DATA_ROLE_DEVICE` to mean "an external host is asserting the data path against this phone", which is the forensic threat model).

Role-combination helpers confirm the semantics (`COMBO_SINK_DEVICE` etc.):

```121:128:frameworks/base/services/usb/java/com/android/server/usb/UsbPortManager.java
    private static final int COMBO_SOURCE_HOST =
            UsbPort.combineRolesAsBit(POWER_ROLE_SOURCE, DATA_ROLE_HOST);
    private static final int COMBO_SOURCE_DEVICE = UsbPort.combineRolesAsBit(
            POWER_ROLE_SOURCE, DATA_ROLE_DEVICE);
```

### 1.3 Lower-level sysfs (alternative / init-service path)

Tokay (Pixel 9, Tensor G4 + mainline-aligned kernel) is "modern" — it uses the `typec` class, not the legacy `android_usb` gadget framework. The modern kernel exposes:

- `/sys/class/typec/port0/data_role` (`host` / `device` / `none`)
- `/sys/class/typec/port0/power_role` (`source` / `sink`)
- `/sys/class/typec/port0/preferred_role`
- uevents tagged `TYPEC_PORT` / `USB_ROLE` / `extcon` on data-role transitions

A non-root init service with appropriate SELinux `typec_device` access can read these and/or listen for uevents via a Netlink/UeventObserver. `UsbPortManager` already wires HAL `UsbPortHal` (`HAL_DATA_ROLE_HOST`/`HAL_DATA_ROLE_DEVICE`, line 32-33 of `UsbPortManager.java`) which itself reads from the kernel typec layer — so the framework path and the sysfs path ultimately reflect the same kernel state. The kernel ABI symbols for the typec subsystem are present in the prebuilt kernel ABI/symbol lists (e.g. `kernel/prebuilts/6.12/arm64/abi_symbollist` matches `typec_*` symbols — not reproduced here for brevity).

### 1.4 Can it be observed from userspace without root?

Yes, two ways:
1. **Framework:** A system component subscribing to `ACTION_USB_PORT_CHANGED` (as `UsbPortSecurityHooks` already does) needs no special permission — it runs in `system_server`.
2. **Native init service:** Needs an SELinux domain granted read on `typec_device_t` (tokay SELinux policy already grants this to the USB HAL / `system_server`). A new `vendor/guardtalk/usb-watchdog` init service would need a bespoke SELinux `.te` allowance — flagged for the follow-on T-task.

### 1.5 Older `android_usb` path — NOT applicable

`/sys/class/android_usb/android0/state` is the legacy gadgetfs path. Modern Pixel devices (including tokay) use `configfs-gadget` + `dwc3` + `typec`, surfaced via the USB HAL `IUsb`. `UsbDeviceManager` still exists for function/ accessory management, but port-level state is owned by `UsbPortManager` + `UsbPortHal`. The watchdog should use `UsbPortManager`/`UsbPortStatus`, not `android_usb`.

---

## 2. GrapheneOS Existing USB Controls (BUILD ON THESE)

### 2.1 `UsbPortSecurityHooks` — the USB-C peripheral gate

This is the canonical GrapheneOS USB-C security component. Key facts (all `frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java`):

- **Class location:** `com.android.server.policy.keyguard.UsbPortSecurityHooks` (line 31).
- **Support gate:** `config_usbPortSecuritySupported` bool resource (line 61).
- **Modes** (from `android.ext.settings.UsbPortSecurity`):

```6:19:frameworks/base/core/java/android/ext/settings/UsbPortSecurity.java
public class UsbPortSecurity {
    public static final int MODE_ALL_PORTS_DISABLED = 0;
    public static final int MODE_CHARGING_ONLY = 1;
    // doesn't apply to connections that were made before locking
    public static final int MODE_CHARGING_ONLY_WHEN_LOCKED = 2;
    // doesn't apply to connections that were made before locking or first unlock
    public static final int MODE_CHARGING_ONLY_WHEN_LOCKED_AFU = 3;
    public static final int MODE_ALL_PORTS_ENABLED = 4;

    public static final IntSysProperty MODE_SETTING = new IntSysProperty(
            "persist.security.usb_mode",
            Build.IS_DEBUGGABLE ? MODE_ALL_PORTS_ENABLED : MODE_CHARGING_ONLY_WHEN_LOCKED);
}
```

- **Keyguard-coupled:** `onKeyguardShowingStateChangedInner` (line 226) flips the port to `CHARGING_ONLY` when the keyguard shows and back to `PORTS_ENABLED` when dismissed (lines 240-280).
- **Mechanism:** Sets `security.deny_new_usb2` sysprop (line 322) and `sys.port_security_mode` (line 316), which init/USB HAL consume to disable the USB2 data path.
- **Initial mode at boot:** `setInitialMode` (line 66) — relevant for the "locked-at-boot" policy matrix.
- **HAL callback:** `onHalEnableUsbDataSignal` (line 138) implements `IUsb.enableUsbDataSignal()` — even the HAL must defer to the security hook when `MODE_CHARGING_ONLY_*` is active (lines 175-195).

**This is the integration point for the watchdog.** The watchdog should NOT re-implement port listening — it should add a callback alongside `UsbPortSecurityHooks` (or extend it) that, on a `DATA_ROLE_*` transition while locked + duress-armed, invokes the wipe.

### 2.2 `AutoReboot` — inactivity reboot

```9:39:frameworks/base/services/core/java/com/android/server/policy/keyguard/AutoReboot.java
class AutoReboot {
    private static final String TAG = AutoReboot.class.getSimpleName();

    // writes to this system property are special-cased in init
    private static final String SYS_PROP = "sys.auto_reboot_ctl";

    static void onKeyguardShowingStateChanged(Context ctx, boolean showing, int userId) {
        ...
        if (!showing) {
            SystemProperties.set(SYS_PROP, "on_device_unlocked");
            return;
        }

        final int timeoutMillis = ExtSettings.AUTO_REBOOT_TIMEOUT.get(ctx);
        final int timeoutSeconds = timeoutMillis / 1000;
        if (timeoutSeconds > 0) {
            SystemProperties.set(SYS_PROP, Integer.toString(timeoutSeconds));
        }
        ...
    }
}
```

- Lives in `com.android.server.policy.keyguard` (same package as `UsbPortSecurityHooks`).
- Triggered by the **same** `onKeyguardShowingStateChanged` keyguard callback machinery (GrapheneOS routes keyguard state to both `AutoReboot` and `UsbPortSecurityHooks`).
- Timeout via `ExtSettings.AUTO_REBOOT_TIMEOUT`, special-cased in `init`.
- After N hours locked, the device reboots → on FBE devices, a reboot drops the CE keys from RAM and requires the user credential to re-derive them. Auto-reboot is therefore a *passive* anti-forensic primitive the watchdog should *complement*, not duplicate.

### 2.3 Duress-PIN wipe — `DuressWipe`, `DuressPasswordHelper`, `DuressCredentials`

GrapheneOS's duress wipe is fully in-tree. The triggering flow:

```37:61:frameworks/base/services/core/java/com/android/server/locksettings/DuressPasswordHelper.java
    protected void onVerifyCredentialResult(@Nullable VerifyCredentialResponse res, @Nullable LockscreenCredential credential) {
        if (res != null && res.isMatched()) {
            return;   // (matched the real credential — not duress)
        }
        ...
        backgroundThread.getThreadHandler().post(() -> {
            final boolean isDuressCredential;
            try {
                isDuressCredential = isDuressCredential(credentialCopy);
            } finally {
                // invalid credential might be similar to the actual credential
                credentialCopy.zeroize();
            }
            if (isDuressCredential) {
                DuressWipe.run(lockSettingsService.getContext());
            }
        });
    }
```

The wipe itself (`frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java`):

```13:38:frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java
public class DuressWipe {
    static final String TAG = DuressWipe.class.getSimpleName();

    public static boolean sleep5sBeforePoweroff;

    static void run(Context context) {
        Slog.d(TAG, "start");

        EuiccWipeThread euiccWipeThread = EuiccWipeThread.start(context);

        Slog.d(TAG, "calling deleteSecrets");
        // deleteSecrets() calls AndroidKeyStoreMaintenance.deleteAllKeys(), which deletes all
        // KeyMint keys, including the storage encryption keys
        RecoverySystemService.deleteSecrets();
        Slog.d(TAG, "deleteSecrets returned");

        euiccWipeThread.await(3000);
        Slog.d(TAG, "finished waiting for euiccWipeThread");

        if (sleep5sBeforePoweroff) {
            SystemClock.sleep(5000);
        }

        PowerManagerService.lowLevelShutdown(null);
    }
}
```

**This `DuressWipe.run()` is exactly the entry point the USB watchdog should call** when its policy matrix resolves to "wipe". It already:
1. Deletes all KeyMint/Keystore keys (incl. FBE wrapping keys) via `RecoverySystemService.deleteSecrets()` (line 27, comment lines 25-26).
2. Wipes eSIMs (`EuiccWipe`, RESET_FLAG_IS_FOR_DURESS_WIPE) (lines 22, 58).
3. Shuts down the device (line 37).

Duress credentials storage (`frameworks/base/services/core/java/com/android/server/locksettings/DuressCredentials.java`):
- Persisted under `LockSettingsStorage` key `"duress_credentials"` at `USER_SYSTEM` (lines 41-42).
- Set/cleared via `LockSettingsService.setDuressCredentials()` (`LockSettingsService.java:4269`) and shell command `set-duress-credentials` (`LockSettingsShellCommand.java:82`).

**"Duress armed" predicate for the watchdog:** `DuressCredentials.maybeGet(lockSettingsStorage) != null` (line 49 of `DuressCredentials.java`). I.e. duress is "armed" iff duress PIN/password have been provisioned. There is no separate "armed" flag — provisioning IS arming.

---

## 3. Protective Action: Recoverable Crypto-Erase

### 3.1 FBE master-key wrapping (background)

AOSP File-Based Encryption wraps per-user CE/DE keys with the Synthetic Password, which is itself wrapped by a KeyMint-bound key (`spm.stretchLskf` — see `DuressCredential.create` at `DuressCredential.java:23-29`). The class hierarchy:

- `system/vold/FsCrypt.cpp` — installs/destroys user CE/DE keys.
- `system/vold/KeyStorage.cpp` — `destroyKey()` (line 652) sec-discards the on-disk key material.
- `system/vold/MetadataCrypt.cpp` — full-disk metadata key (`destroyKey` at lines 471, 491-494).

### 3.2 Crypto-erase mechanism = destroy the wrapping keys

The `RecoverySystemService.deleteSecrets()` call (the one `DuressWipe` invokes) does three things (`frameworks/base/services/core/java/com/android/server/recoverysystem/RecoverySystemService.java:554-577`):

```554:577:frameworks/base/services/core/java/com/android/server/recoverysystem/RecoverySystemService.java
    public static void deleteSecrets() {
        Slogf.w(TAG, "deleteSecrets");
        try {
            AndroidKeyStoreMaintenance.deleteAllKeys();
        } catch (Throwable e) {
            Slog.e(TAG, "Failed to delete all keys from keystore.", e);
        }

        try {
            ISecretkeeper secretKeeper = getSecretKeeper();
            if (secretKeeper != null) {
                Slogf.i(TAG, "ISecretkeeper.deleteAll();");
                secretKeeper.deleteAll();
            }
        } catch (Throwable e) {
            Slog.e(TAG, "Failed to delete all secrets from secretkeeper.", e);
        }

        try {
            ExtendedWipeWithoutReboot.run();
        } catch (Throwable e) {
            Slog.e(TAG, "ExtendedWipeWithoutReboot failed", e);
        }
    }
```

1. **`AndroidKeyStoreMaintenance.deleteAllKeys()`** — destroys every KeyMint key, including the FBE wrapping keys. Without these, the on-disk CE keys cannot be unwrapped → userdata CE directories are irrecoverable ciphertext.
2. **`ISecretkeeper.deleteAll()`** — wipes Trusty/secretkeeper-backed secrets (Pixel 9 has a Trusty TEE; relevant for Secretkeeper-backed DiskEncryption keys on newer devices).
3. **`ExtendedWipeWithoutReboot.run()`** (`frameworks/base/services/core/java/com/android/server/recoverysystem/ExtendedWipeWithoutReboot.java`) — additionally calls `vold` to sec-discard the on-disk key material directly:

```23:60:frameworks/base/services/core/java/com/android/server/recoverysystem/ExtendedWipeWithoutReboot.java
    static void run() {
        eraseSecureElement();

        IVold vold = ...;

        try {
            var um = LocalServices.getService(UserManagerInternal.class);
            for (int userId : um.getUserIds()) {
                destroyUserStorageKeys(vold, userId);
            }
        } catch (Throwable e) { ... }

        Slog.d(TAG, "calling vold.destroySystemStorageKey()");
        try {
            vold.destroySystemStorageKey();
        } catch (Throwable e) { ... }

        Slog.d(TAG, "calling vold.destroyMetadataKey(/data)");
        try {
            vold.destroyMetadataKey("/data");
        } catch (Throwable e) { ... }
    }
```

These `vold` binder calls map onto the destroy functions found in `system/vold`:

```27:39:system/vold/FsCrypt.h
bool fscrypt_destroy_user_keys(userid_t user_id, bool evict);
bool fscrypt_set_ce_key_protection(userid_t user_id, const std::vector<uint8_t>& secret);
bool fscrypt_destroy_system_key();
void fscrypt_deferred_fixate_ce_keys();

std::vector<int> fscrypt_get_unlocked_users();

bool fscrypt_destroy_user_storage(const std::string& volume_uuid, userid_t user_id, int flags);

bool fscrypt_destroy_volume_keys(const std::string& volume_uuid);
```

```693:701:system/vold/VoldNativeService.cpp
    return translateBool(fscrypt_destroy_user_keys(userId, true));
}

binder::Status VoldNativeService::destroyUserStorageKeys2(int32_t userId, bool evict) {
    ...
    return translateBool(fscrypt_destroy_user_keys(userId, evict));
}
```

And the per-key sec-discard primitive (`system/vold/KeyStorage.cpp:652` `destroyKey()`). For metadata encryption, `MetadataCrypt.cpp:471-494` calls `destroyKey()` on the metadata key dir.

**Net effect:** userdata becomes ciphertext that cannot be unwrapped. The data is crypto-erased. This is the canonical AOSP "recoverable wipe" path — also invoked for `RECOVERY_WIPE_DATA_COMMAND` (`RecoverySystemService.java:542-543`).

### 3.3 Recoverability — NOT a hardware brick

After `deleteSecrets()` + `ExtendedWipeWithoutReboot` + shutdown:
- The on-disk FBE keys and metadata keys are sec-discarded → userdata unreadable.
- The bootloader, bootloader partition, and hardware are untouched.
- `fastboot flash` of a fresh image (or `fastboot flashing unlock` + flash) restores a bootable device.
- **No hardware damage.** This satisfies AEGIS Law 11 (Reversibility) — the change is reversible by re-flash, even though the user *data* is intentionally irrecoverable.

Confirmed by absence of any bootloader/eMMC fuse-blow code in the wipe path; the wipe touches *only* keystore, secretkeeper, and `vold`-managed key directories.

### 3.4 GrapheneOS duress wipe = crypto-erase (verified)

The comment at `DuressWipe.java:25-26` is explicit:

> `// deleteSecrets() calls AndroidKeyStoreMaintenance.deleteAllKeys(), which deletes all`
> `// KeyMint keys, including the storage encryption keys`

So GrapheneOS's duress wipe IS a recoverable crypto-erase, exactly as the brief requires. The watchdog reuses the same path.

### 3.5 Bootloader-lock gating

Verified-boot state is observable via `ro.boot.verifiedbootstate` (`frameworks/base/services/devicepolicy/java/com/android/server/devicepolicy/DevicePolicyManagerService.java:3968-3971`):

```3968:3971:frameworks/base/services/devicepolicy/java/com/android/server/devicepolicy/DevicePolicyManagerService.java
        final String verifiedBootState =
                mInjector.systemPropertiesGet("ro.boot.verifiedbootstate");
        final String verityMode = mInjector.systemPropertiesGet("ro.boot.veritymode");
        SecurityLog.writeEvent(SecurityLog.TAG_OS_STARTUP, verifiedBootState, verityMode);
```

`green` ⇒ bootloader locked and OS verified. The watchdog should gate auto-wipe on `ro.boot.verifiedbootstate == green` to ensure the policy is enforced on a verified OS image (avoids a malicious unlock-then-cable spoof firing the wipe on a victim's verified device — though note: an unlocked bootloader can rewrite `ro.boot.verifiedbootstate` only by reflashing bootloader; this is a defense-in-depth check, not a hard guarantee).

---

## 4. Gating + Policy Design

### 4.1 Policy matrix

| Lock state | Duress armed | Cable kind | `data_role` | Action |
|---|---|---|---|---|
| Unlocked | any | charge-only | `NONE` | **NO action** |
| Unlocked | any | data | `DEVICE`/`HOST` | **NO action** (user is using the device) |
| Locked | no | charge-only | `NONE` | **NO action** (existing `UsbPortSecurityHooks` already forces charging-only) |
| Locked | no | data | `DEVICE`/`HOST` | **NO auto-wipe (MVP)** — log + enforce charging-only via existing hooks. Optional policy: operator-configurable "wipe on any data cable while locked". |
| Locked | yes | charge-only | `NONE` | **NO action** (charging-only cables are safe) |
| **Locked** | **yes** | **data** | **`DEVICE`** (external host) | **CRYPTO-ERASE** via `DuressWipe.run()` |
| Locked | yes | data | `HOST` (phone is host, e.g. USB OTG) | Policy choice: NO action (phone driving, not being probed) — recommended MVP. |

The forensic threat model is "an adversary connects the locked phone as a *peripheral* (DFP adversary = host) to extract data via USB." That corresponds to `data_role == DATA_ROLE_DEVICE`. The `HOST` case (phone is the host, OTG drive / accessory) is not the same threat and should NOT trigger wipe in the MVP.

### 4.2 "Locked" detection

`KeyguardManager.isKeyguardLocked()` / `isDeviceLocked()` (used by `UsbService.java:284` and `UsbDeviceManager.java:321`). GrapheneOS routes keyguard state changes to `UsbPortSecurityHooks.onKeyguardShowingStateChanged` and `AutoReboot.onKeyguardShowingStateChanged` via a shared keyguard callback; the watchdog should subscribe to the same source. The `prevKeyguardShowing` field in `UsbPortSecurityHooks` (line 220) is the existing source of truth for "currently locked."

### 4.3 "Duress armed" detection

`DuressCredentials.maybeGet(LockSettingsStorage)` (`DuressCredentials.java:49`). Non-null ⇒ armed. This is a system-server-only check (`LockSettingsStorage` is not directly accessible to non-system UIDs), which fits the watchdog's deployment context (it lives in `system_server` or a system init service).

### 4.4 Self-DoS risk analysis

| Risk | Mitigation |
|---|---|
| Charge cable misdetected as data → wipe | Require `getDataRole() == DATA_ROLE_DEVICE` (not just `isConnected()`). Charge-only cables never negotiate a data role. Additionally require **duress-armed** for auto-wipe — a non-duress user never loses data from a cable event. |
| User legitimately plugs into their own laptop while locked (e.g. to charge from a PC port) → wipe | This is *intended* duress behavior IF duress is armed; if duress is NOT armed, MVP does not wipe. Operator may set an explicit "wipe on any data cable while locked" opt-in policy. |
| Faulty USB-C dock asserts data role spuriously | Same as above — duress-armed gate prevents self-DoS. |
| Adversary forces duress disarm before cable | Disarming duress requires the *owner* credential (`setDuressCredentials` requires `ownerCredential`, `LockSettingsService.java:4269`). An adversary with the owner credential has already won. |
| Race: plug-in happens before keyguard fully engaged | `prevKeyguardShowing` is set from the keyguard callback; at boot `setInitialMode` already applies `CHARGING_ONLY_IMMEDIATE` for the default `MODE_CHARGING_ONLY_WHEN_LOCKED` (line 75-77 of `UsbPortSecurityHooks`). The watchdog should additionally consult `keyguardDismissedAtLeastOnce` (line 219) — at boot the device is "locked" but a user-present cable should NOT trigger duress wipe until first unlock has occurred (avoid boot-time false positives during legitimate first-use). |
| Polling `/sys/class/typec/` drains battery | Do NOT poll. Subscribe to `ACTION_USB_PORT_CHANGED` (framework) or uevent Netlink (native). `UsbPortSecurityHooks` is already event-driven; reuse that pattern. |

### 4.5 Legal / operational review (FLAGGED)

A wipe-on-USB-data feature is, by construction, an evidence-destruction mechanism. Depending on jurisdiction and the operator's threat model this may be:
- **Lawful** for the *owner* of the device protecting their own data (analogous to duress PIN, which GrapheneOS already ships).
- **Potentially unlawful** if configured to fire in scenarios that could destroy evidence subject to a preservation obligation, subpoena, or lawful seizure.

**Recommendation:** ship the feature gated to **duress-armed + locked + external-host (DATA_ROLE_DEVICE)** only. Document in operator runbook that enabling duress credentials is an affirmative owner decision, and that the USB-data-cable auto-trigger is an *opt-in extension* of the existing duress-PIN feature, not a default. Legal sign-off required before enabling in any deployment subject to evidence-preservation duties. This is flagged for the operator's legal review and is out of scope for code implementation.

---

## 5. Implementation Sketch (for follow-on T-task, NOT here)

### 5.1 Where the watchdog lives

Two viable options:

**Option A (RECOMMENDED): extend `UsbPortSecurityHooks`** in `frameworks/base/services/core/java/com/android/server/policy/keyguard/`. It already:
- Listens to `ACTION_USB_PORT_CHANGED` with `UsbPortStatus`.
- Tracks `prevKeyguardShowing` (lock state).
- Runs in `system_server` (can call `DuressWipe.run()` directly — same package family, system UID).
- Is gated by `config_usbPortSecuritySupported`.

Add a new `UsbDataWatchdog` class in the same package that:
- On each `UsbPortStatus` change, evaluates the policy matrix (§4.1).
- Reads duress-armed state via `LockSettingsService` local service / `DuressCredentials.maybeGet`.
- Reads verified-boot state via `SystemProperties.get("ro.boot.verifiedbootstate")`.
- On match, calls `DuressWipe.run(context)`.

**Option B: native init service** in `vendor/guardtalk/usb-watchdog/` reading `/sys/class/typec/port0/data_role` via uevent. Pros: works even if `system_server` is compromised/crashed. Cons: needs bespoke SELinux policy, can't directly call `DuressWipe` (would need a vold binder call or a SystemApi), and loses the rich `UsbPortStatus` semantics. Recommend Option A as primary, Option B as defense-in-depth for the follow-on task.

### 5.2 How it invokes the wipe

`DuressWipe.run(context)` is package-private in `com.android.server.locksettings`. From the same `system_server` process (Option A), expose a `SystemApi` or `LocalService`:

```java
// pseudocode — NOT to be implemented in this research task
LockSettingsInternal lsi = LocalServices.getService(LockSettingsInternal.class);
lsi.triggerDuressWipe("usb-data-cable-watchdog");
```

Or add a thin method on `DuressWipe` that's invoked via the `LockSettingsService.LocalService`. The existing `DuressWipe.run()` already does everything needed (keystore delete + vold key destroy + eSIM wipe + shutdown). No new wipe code required.

### 5.3 Reversibility (Law 11)

Confirmed: the wipe path (`RecoverySystemService.deleteSecrets` + `ExtendedWipeWithoutReboot`) destroys keys but does **not** blow fuses or brick the bootloader. `fastboot flash` of a fresh image restores a bootable device. Reversible-by-reflash. The user *data* is intentionally irrecoverable — that is the *purpose* of the wipe — but the *device* is recoverable.

### 5.4 SELinux / permissions (for T-task)

- Framework path (Option A): no new SELinux policy — `system_server` already has all needed access.
- Native path (Option B): new `vendor_guardtalk_usb_watchdog` domain with `typec_device_t:chr_file r_file_perms` and `typec_device_t:dir r_dir_perms`, plus `binder_call` to `vold` and `keystore` if it bypasses the framework (not recommended).

---

## 6. Go / No-Go Recommendation

### **GO with caveats.**

**Caveats:**
1. **MUST be gated** to locked + duress-armed + `DATA_ROLE_DEVICE` to avoid self-DoS from any charge cable. No auto-wipe on data-cable-without-duress in the MVP.
2. **MUST integrate** with GrapheneOS's existing `UsbPortSecurityHooks`, `AutoReboot`, and `DuressWipe` — do NOT reinvent port monitoring or wipe primitives.
3. **MUST use recoverable crypto-erase** (`RecoverySystemService.deleteSecrets()` + `ExtendedWipeWithoutReboot`), NOT a hardware brick. Confirmed recoverable-by-reflash.
4. **MUST use event-driven detection** (`ACTION_USB_PORT_CHANGED`), never polling `/sys/class/typec/`.
5. **MUST gate on verified-boot green** (`ro.boot.verifiedbootstate == green`) as defense-in-depth.
6. **Legal review required** before enabling in any deployment subject to evidence-preservation duties.
7. **Boot-time guard:** do not fire wipe until `keyguardDismissedAtLeastOnce == true` (avoid first-use false positives).

### MVP scope (for follow-on T-task)

1. **Only** `duress-armed && locked && data_role==DEVICE && verified-boot-green && first-unlock-done` ⇒ `DuressWipe.run()`.
2. **No** "wipe on any data cable while locked" auto-policy (too risky for MVP; leave as operator opt-in for later).
3. **No** native init service (Option A framework path only for MVP; Option B is a hardening follow-up).
4. Audit log entry (Law 10 — Audit Trail) on every policy evaluation, regardless of outcome, via `SecurityLog` or `Slog` with structured tags. Note: the wipe itself shuts down the device, so logs must be flushed synchronously before `deleteSecrets()` returns — confirm in implementation.
5. Tests: extend `frameworks/base/tests/UsbTests/` with a watchdog policy-matrix unit test.

### Risks (summary)

| Risk | Severity | Mitigation |
|---|---|---|
| Self-DoS from misdetection | HIGH | Duress-armed gate + `DATA_ROLE_DEVICE`-only + first-unlock-done guard |
| Evidence-destruction legal exposure | HIGH | Operator legal review; opt-in only; document as extension of existing duress-PIN feature |
| Battery drain from polling | LOW | Use event-driven `ACTION_USB_PORT_CHANGED` (no polling) |
| Wipe fired by malicious accessory forcing data role | MEDIUM | Verified-boot-green gate + duress-armed gate + lock gate (all three required) |
| Race at boot before keyguard settles | MEDIUM | `keyguardDismissedAtLeastOnce` guard |
| `DuressWipe.run()` is package-private | LOW | Expose via `LocalService` (implementation detail for T-task) |
| Audit log not persisted before shutdown | MEDIUM | Synchronous flush before `deleteSecrets()` (implementation detail) |

---

## 7. Evidence Index (file:line)

| Claim | Evidence |
|---|---|
| GrapheneOS listens to USB port changes | `frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java:104-131` |
| USB port broadcast constants | `frameworks/base/core/java/android/hardware/usb/UsbManager.java:142-143, 389-395` |
| `DATA_ROLE_DEVICE`/`HOST` semantics | `frameworks/base/services/usb/java/com/android/server/usb/UsbPortManager.java:22-24, 121-128` |
| USB-C security modes | `frameworks/base/core/java/android/ext/settings/UsbPortSecurity.java:6-19` |
| Keyguard-coupled USB gating | `frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java:226-285` |
| `deny_new_usb2` mechanism | `frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java:316, 322-331` |
| Auto-reboot exists | `frameworks/base/services/core/java/com/android/server/policy/keyguard/AutoReboot.java:9-39` |
| Duress-PIN wipe trigger | `frameworks/base/services/core/java/com/android/server/locksettings/DuressPasswordHelper.java:37-61` |
| Duress wipe = crypto-erase | `frameworks/base/services/core/java/com/android/server/locksettings/DuressWipe.java:13-38` (esp. comment lines 25-26) |
| `deleteSecrets()` mechanism | `frameworks/base/services/core/java/com/android/server/recoverysystem/RecoverySystemService.java:554-577` |
| Extended wipe (vold key destroy) | `frameworks/base/services/core/java/com/android/server/recoverysystem/ExtendedWipeWithoutReboot.java:23-60` |
| vold FBE key destroy | `system/vold/FsCrypt.h:27-39`, `system/vold/FsCrypt.cpp:700-789`, `system/vold/VoldNativeService.cpp:693-701` |
| vold key sec-discard primitive | `system/vold/KeyStorage.cpp:652` |
| Metadata key destroy | `system/vold/MetadataCrypt.cpp:471-494` |
| Duress credentials storage/arm state | `frameworks/base/services/core/java/com/android/server/locksettings/DuressCredentials.java:41-55` |
| Verified-boot state sysprop | `frameworks/base/services/devicepolicy/java/com/android/server/devicepolicy/DevicePolicyManagerService.java:3968-3971` |
| Keyguard lock detection in USB service | `frameworks/base/services/usb/java/com/android/server/usb/UsbService.java:167, 274-295` |
| Keyguard lock in UsbDeviceManager | `frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java:319-329` |
| Duress credential set via shell | `frameworks/base/services/core/java/com/android/server/locksettings/LockSettingsShellCommand.java:82-85, 221-229` |

---

*End of report. Read-only audit. No files modified except this report file. No commits. No doctrine/governance files accessed.*
