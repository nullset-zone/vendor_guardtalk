# GuardTalk Permission Defaults Policy

**Task:** `T-SEC-P4-PERMS` (Backend) → consumed by Frontend / `Q-SEC-P4-PRIVACY`  
**Date:** 2026-07-23

## Purpose

Product default permission policy for GuardTalkOS:

1. **Grant** required runtime permissions to GuardTalk **Messenger** at first boot / user create when the package is installed.
2. **Deny-by-default** automatic `etc/default-permissions` exception grants for other **third-party** (non-system) apps.
3. Leave special-access / AppOps paths user-gated (Settings / PermissionController); do not auto-elevate third-party apps.

Out of scope (later Phase-4 tasks): `privacy_tmpfs`, clipboard clear, Files handlers.

## Messenger package identity

| Field | Value |
|-------|--------|
| **Package name (constant)** | `com.guardtalk.messenger` |
| **Source of truth** | `android.guardtalk.GuardTalkPermissionDefaultsPolicy.MESSENGER_PACKAGE_NAME` |
| **In-tree APK / PRODUCT_PACKAGES app module** | **ABSENT (GAP)** |
| **Evidence searched** | `vendor/guardtalk/apps/` (Config, Validator, Face, Voice only); no `*Messenger*.apk` product prebuilt; branding icons only under `vendor/guardtalk/branding/.../guardtalk_messenger` |
| **CarMessenger APK** | `packages/apps/Car/MessengerPrebuilt/` — **not** GuardTalk Messenger; ignored |

**Do not invent a fake APK.** Plumbing is keyed by `com.guardtalk.messenger`. When the product Messenger APK is added (system/priv-app or product package), grants activate automatically if the APK requests the listed permissions.

## Product property

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.permission_defaults` | `1` | Enable Messenger grants + third-party exception deny filter |

Defined in `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`.

Unset / `0` ⇒ stock AOSP/GrapheneOS default-permission behavior (policy off).

## Messenger grants (product privilege)

Granted **by default**, **user-revocable** (`fixed=false`) when policy is on and the package is installed:

| Permission | Rationale |
|------------|-----------|
| `POST_NOTIFICATIONS` | Message alerts |
| `RECORD_AUDIO` | Voice calls / voice notes |
| `CAMERA` | Video calls / media capture |
| `READ_CONTACTS` / `WRITE_CONTACTS` / `GET_ACCOUNTS` | Contact sync (ContactsProvider stays installed; UI may be hidden) |
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO` | Attachments |
| `READ_MEDIA_VISUAL_USER_SELECTED` | Partial photo/video access (Android 14+) |
| `ACCESS_MEDIA_LOCATION` | Media metadata when reading attachments |

**Explicitly not granted by this policy** (radio/BT excised product posture):

- Phone / SMS / call-log groups
- Fine/coarse/background location
- Bluetooth / nearby-device group
- Legacy bare `READ/WRITE_EXTERNAL_STORAGE` (scoped media used instead)

Only permissions the Messenger APK **requests** are applied (`DefaultPermissionGrantPolicy` filters to requested dangerous runtime perms).

### Enforcement layers

```text
User create / grantDefaultPermissions(userId)
        │
        ├── AOSP sys/priv + default handlers (unchanged)
        ├── etc/default-permissions XML exceptions
        │     └── GuardTalk filter: skip non-system third-party (except Messenger)
        └── grantGuardTalkMessengerDefaultPermissions()
              └── grantPermissionsToPackage(ignoreSystemPackage=true)
                    when com.guardtalk.messenger is installed
```

| Layer | Location | Role |
|-------|----------|------|
| Framework policy | `android.guardtalk.GuardTalkPermissionDefaultsPolicy` | Package constant, prop, permission set, exception allow rules |
| Service hook | `DefaultPermissionGrantPolicy` | Messenger grants + third-party exception filter |
| Product XML | `vendor/guardtalk/permissions/default-permissions-com.guardtalk.messenger.xml` | Installs to `product/etc/default-permissions/` (system-app / cert path when APK is system) |
| Product wiring | `guardtalk-tokay.mk` + `vendor/guardtalk/permissions/Android.bp` | Prop + `PRODUCT_PACKAGES` |

PermissionController was **not** modified; runtime grant authority for this task is Package Manager `DefaultPermissionGrantPolicy`. PermissionController continues to surface user-facing grant/revoke UI.

## Non-Messenger / third-party rules (deny-default / restricted)

When `ro.guardtalk.permission_defaults=1`:

| Rule | Behavior |
|------|----------|
| **R1 — Runtime deny-default** | Third-party apps do not receive dangerous runtime permissions until the user grants them (AOSP baseline; unchanged). |
| **R2 — Exception XML filter** | `etc/default-permissions` exceptions for **non-system** packages are **skipped**, except `com.guardtalk.messenger`. System-image exceptions (Seedvault, Updater, GmsCompat, carrier, etc.) remain. |
| **R3 — No product auto-grant list for others** | Only Messenger is on the GuardTalk product grant list. GuardTalkConfig / Validator use privapp / their own manifests — not this grant set. |
| **R4 — Special access** | `SYSTEM_ALERT_WINDOW`, `WRITE_SETTINGS`, `PACKAGE_USAGE_STATS`, `MANAGE_EXTERNAL_STORAGE`, etc. remain Settings / role gated — not auto-granted to third-party apps by this policy. |
| **R5 — Restricted permissions** | Messenger grants use `whitelistRestrictedPermissions=true` so restricted members of the set can be granted to Messenger only via this intentional path; third-party still need platform whitelist / user paths. |

## Frontend contract

1. Do **not** invent a different Messenger package name in UI copy — use `com.guardtalk.messenger`.
2. Permission / Apps screens may show Messenger grants as granted-by-default when the APK is present; user can revoke.
3. Do not surface a “grant all to third-party” product shortcut.
4. Special Access rows remain Maintenance / GT Config gated where Phase-1 UI already requires it.
5. When Messenger APK is still absent, UI should not claim grants are active on-device.

## Fail-closed / gap handling

1. Policy prop unset ⇒ no GuardTalk filter / no Messenger code grants.
2. Messenger package missing ⇒ log and skip grants (no crash; XML parse warns “No such package”).
3. Messenger present but does not request a listed permission ⇒ that permission is not granted.
4. Third-party exception XML with matching cert ⇒ still blocked by R2 when policy on (product deny).

## Rollback (Law 11)

1. Set `ro.guardtalk.permission_defaults=0` (or remove) in `vendor/guardtalk/device/tokay/guardtalk-tokay.mk`.
2. Remove `PRODUCT_PACKAGES += default-permissions-com.guardtalk.messenger` from the same makefile.
3. Revert hooks in `DefaultPermissionGrantPolicy` and delete:
   - `frameworks/base/core/java/android/guardtalk/GuardTalkPermissionDefaultsPolicy.java`
   - `vendor/guardtalk/permissions/` (XML + Android.bp)
   - this doc (optional)
4. Rebuild: `m services default-permissions-com.guardtalk.messenger -j$(nproc)`.

No irreversible state: grants are runtime flags; wipe / reflash restores prior policy.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
# If lunch fails on adevtool pin: temporarily comment
# vendor/google_devices/tokay/adevtool-version-check.mk, lunch, restore after.
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services default-permissions-com.guardtalk.messenger -j$(nproc)
```

Optional smoke (PermissionController untouched but listed in sprint P4 verify):

```bash
m services PermissionController default-permissions-com.guardtalk.messenger -j$(nproc)
```

Static checks:

```bash
grep -n 'com.guardtalk.messenger' \
  frameworks/base/core/java/android/guardtalk/GuardTalkPermissionDefaultsPolicy.java \
  vendor/guardtalk/permissions/default-permissions-com.guardtalk.messenger.xml
grep -n 'grantGuardTalkMessengerDefaultPermissions\|allowDefaultPermissionException' \
  frameworks/base/services/core/java/com/android/server/pm/permission/DefaultPermissionGrantPolicy.java
get_build_var PRODUCT_PACKAGES | tr ' ' '\n' | grep default-permissions-com.guardtalk.messenger
```

## Files touched

| Path | Change |
|------|--------|
| `frameworks/base/core/java/android/guardtalk/GuardTalkPermissionDefaultsPolicy.java` | **NEW** policy API |
| `frameworks/base/services/core/java/com/android/server/pm/permission/DefaultPermissionGrantPolicy.java` | Messenger grant + third-party exception filter |
| `vendor/guardtalk/permissions/default-permissions-com.guardtalk.messenger.xml` | **NEW** product XML |
| `vendor/guardtalk/permissions/Android.bp` | **NEW** `prebuilt_etc` |
| `vendor/guardtalk/device/tokay/guardtalk-tokay.mk` | Prop + PRODUCT_PACKAGES |
| `vendor/guardtalk/docs/PERMISSION_DEFAULTS_POLICY.md` | **NEW** this doc |
