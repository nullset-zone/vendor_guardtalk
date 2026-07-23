# GuardTalk Files + MIME Handlers Policy

**Task:** `T-SEC-P4-FILES` (Backend) → consumed by `F-SEC-P4-SYSTEM-UI` / `Q-SEC-P4-PRIVACY`  
**Date:** 2026-07-23

## Purpose

Extend the stock Files stack (DocumentsUI / ExternalStorageProvider / FileSystemProvider)
for GuardTalk products without inventing a parallel file manager:

1. **Trash + ZIP** for user storage (emulated / shared storage)
2. **Critical partition protection** — system / vendor / boot / recovery (and similar) cannot be deleted or trashed via the file manager
3. **Minimal MIME / handler set** — one Files launcher; no duplicate technical launcher icons

Out of scope: privacy_tmpfs / clipboard redesign (`T-SEC-P4-PRIVACY`); Messenger APK inventing.

## Product properties (live)

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.files_policy` | `1` | Master switch for Files policy |
| `ro.guardtalk.files_trash` | `1` | Force DocumentsUI trash UI on Baklava (SDK 36) when Documents trash APIs are present |
| `ro.guardtalk.files_protect_critical` | `1` | Block delete/trash of critical mounts (fail-closed when master on) |

**Live wiring:** `vendor/guardtalk/device/tokay/guardtalk-product-props.mk`  
**Docs mirror:** `vendor/guardtalk/device/tokay/guardtalk-tokay.mk` (not inherited)

## Trash / ZIP (user storage)

| Capability | Mechanism | Notes |
|------------|-----------|-------|
| Trash | `DocumentsContract.trashDocument` → `FileSystemProvider.trashDocument` → MediaStore trash path | UI gated by `FlagUtils.isTrashFlowEnabled()` |
| Restore | `RestoreJob` / trash root in DocumentsUI | Same flag gate |
| ZIP | Stock `CompressJob` (menu Compress / Zip) | `feature_archive_creation=true`; zip_ng renames label when Material3 on |

**Why a GuardTalk trash override?** Stock `FlagUtils.isTrashFlowEnabled()` requires `SDK_INT > BAKLAVA` (37+). Tokay `trunk_staging` is SDK **36**, but this tree already ships `enable_documents_trash_api` + MediaStore trash-by-path flags as **ENABLED**. GuardTalk forces trash UI on when `files_policy=1` and `files_trash=1`.

## Critical path protection

Enforced in framework (authoritative) and mirrored in ExternalStorageProvider trash eligibility:

| Layer | Class | Behavior |
|-------|-------|----------|
| Policy | `android.guardtalk.GuardTalkFilesPolicy` | Prefix list + prop gates |
| Provider | `FileSystemProvider.deleteDocument` / `trashDocument` | `SecurityException` if protected |
| Flags | `FileSystemProvider.includeFile` | Strips `FLAG_SUPPORTS_DELETE` / `FLAG_SUPPORTS_TRASH` |
| External storage | `ExternalStorageProvider.isTrashSupported` | Returns false if protected |
| DocumentsUI | `FlagUtils` + local prop bridge | Trash UI enablement only |

### Protected prefixes

```text
/system, /system_ext, /vendor, /product, /odm, /oem,
/boot, /recovery, /vendor_boot, /init_boot, /firmware, /persist,
/mnt/vendor, /mnt/product, /mnt/guardtalk_privacy
```

User shared storage (`/storage/emulated/…`, `/sdcard/…`) is **not** in this list — trash/ZIP/delete remain available there.

Fail-closed: unresolvable / traversal-suspect paths are treated as protected when the protect prop is on.

## MIME / handlers (minimal set)

**Single user-facing Files launcher:** `com.android.documentsui/.LauncherActivity` → `files.LauncherActivity`  
(categories: `LAUNCHER` + `APP_FILES` only).

| Intent | Handler | Keep? |
|--------|---------|-------|
| `MAIN` + `LAUNCHER` / `APP_FILES` | DocumentsUI `LauncherActivity` alias | **Yes** — the Files app |
| `OPEN_DOCUMENT` / `CREATE_DOCUMENT` / `GET_CONTENT` / `OPEN_DOCUMENT_TREE` | DocumentsUI `PickActivity` | **Yes** — SAF contract (`*/*`) |
| `VIEW` `vnd.android.document/root` \| `directory` | DocumentsUI `FilesActivity` | **Yes** — document roots only |
| `VIEW_DOWNLOADS` | DocumentsUI `ViewDownloadsActivity` alias | **Yes** — downloads entry |
| Compose `DocumentsUICompose` `MAIN`+`LAUNCHER` | Disabled / no `LAUNCHER` | **No** — technical shell; must not duplicate Files icon |
| StorageManager | `MANAGE_STORAGE` only (no `LAUNCHER`) | OK — not a second Files app |

Do **not** add broad `VIEW` + `*/*` handlers on DocumentsUI (that would create “Open with Files” spam). Frontend must not ship a second file-manager APK.

## Frontend contract (`F-SEC-P4-SYSTEM-UI`)

1. Keep a single Files icon (DocumentsUI). Do not re-enable `DocumentsUICompose` launcher.
2. Trash / Zip affordances come from stock DocumentsUI menus when policy props are on — no parallel Files UI stack.
3. Status / Security copy may reference:
   - “Files can be moved to Trash and restored.”
   - “System partitions cannot be deleted from Files.”
4. Suggested status keys:
   - `ro.guardtalk.files_policy`
   - `ro.guardtalk.files_trash`
   - `ro.guardtalk.files_protect_critical`

### Suggested UI copy

- Trash: “Deleted files go to Trash so you can restore them.”
- Protect: “System and firmware storage cannot be erased from Files.”

## Rollback (Law 11)

1. In `guardtalk-product-props.mk` (and docs mirror `guardtalk-tokay.mk`):
   - set `ro.guardtalk.files_policy=0` (or remove)
   - remove `ro.guardtalk.files_trash` / `ro.guardtalk.files_protect_critical`
2. Revert code hooks:
   - `frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java`
   - `FileSystemProvider` GuardTalk checks
   - `ExternalStorageProvider.isTrashSupported` GuardTalk check
   - `packages/apps/DocumentsUI` `FlagUtils` + `guardtalk/GuardTalkFilesLocalPolicy.java`
   - restore `DocumentsUICompose` launcher intent-filter if needed
   - this doc (optional)
3. Rebuild:

```bash
m DocumentsUI ExternalStorageProvider framework -j$(nproc)
m out/target/product/tokay/vendor/build.prop
```

No irreversible state: props are build-time; trash uses MediaStore trash (restorable); protection only blocks destructive ops.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
# If lunch fails on adevtool pin: temporarily comment
# vendor/google_devices/tokay/adevtool-version-check.mk, lunch, restore after.
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m DocumentsUI ExternalStorageProvider -j$(nproc)
```

Framework policy compiles with `framework` / full `m`; DocumentsUI + ExternalStorageProvider cover the product-facing modules touched here.

### Runtime checks (device)

```bash
getprop ro.guardtalk.files_policy            # expect 1
getprop ro.guardtalk.files_trash             # expect 1
getprop ro.guardtalk.files_protect_critical  # expect 1
# Launcher: only one Files entry (DocumentsUI); DocumentsUICompose not listed
cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.LAUNCHER \
  | grep -i document
```

### Static checks

```bash
rg -n "GuardTalkFilesPolicy|files_policy|files_trash|files_protect_critical" \
  frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java \
  frameworks/base/core/java/com/android/internal/content/storage/FileSystemProvider.java \
  frameworks/base/packages/ExternalStorageProvider/src/com/android/externalstorage/ExternalStorageProvider.java \
  packages/apps/DocumentsUI/src/com/android/documentsui/util/FlagUtils.kt \
  packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/GuardTalkFilesLocalPolicy.java \
  packages/apps/DocumentsUI/compose/AndroidManifest.xml \
  vendor/guardtalk/device/tokay/guardtalk-product-props.mk
```

## Files touched

| Path | Change |
|------|--------|
| `frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java` | **NEW** policy API |
| `frameworks/base/core/java/com/android/internal/content/storage/FileSystemProvider.java` | Delete/trash block + flag strip |
| `frameworks/base/packages/ExternalStorageProvider/.../ExternalStorageProvider.java` | Trash eligibility guard |
| `packages/apps/DocumentsUI/.../FlagUtils.kt` | Baklava trash enable via GuardTalk prop |
| `packages/apps/DocumentsUI/.../guardtalk/GuardTalkFilesLocalPolicy.java` | **NEW** prop bridge |
| `packages/apps/DocumentsUI/compose/AndroidManifest.xml` | Disable duplicate technical launcher |
| `vendor/guardtalk/device/tokay/guardtalk-product-props.mk` | Live props |
| `vendor/guardtalk/device/tokay/guardtalk-tokay.mk` | Docs mirror props |
| `vendor/guardtalk/docs/FILES_HANDLERS_POLICY.md` | **NEW** this doc |
