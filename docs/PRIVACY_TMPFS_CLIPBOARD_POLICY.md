# GuardTalk Privacy tmpfs + Clipboard Clear Policy

**Task:** `T-SEC-P4-PRIVACY` (Backend) → consumed by `F-SEC-P4-SYSTEM-UI` / `Q-SEC-P4-PRIVACY`  
**Date:** 2026-07-23

## Purpose

Enforce two complementary privacy controls on GuardTalk products:

1. **`privacy_tmpfs`** — sensitive ephemeral data (product logs/cache) lives on a RAM-backed tmpfs so it is **gone after reboot**
2. **`clipboard_clear`** — system `ClipboardService` clears clipboard content on **lock**, **timeout**, and **reboot** (RAM-native), fail-closed toward clearing

Out of scope (later Phase-4 tasks): Files ops / MIME handlers (`T-SEC-P4-FILES`); Messenger APK inventing.

## Product properties (server fail-closed)

| Property | Tokay value | Effect |
|----------|-------------|--------|
| `ro.guardtalk.privacy_tmpfs` | `1` | Init mounts privacy tmpfs on boot |
| `ro.guardtalk.privacy_tmpfs_path` | `/mnt/guardtalk_privacy` | Canonical mount path (contract for writers) |
| `ro.guardtalk.clipboard_clear` | `1` | Force clipboard clear on lock / screen-off / timeout |
| `ro.guardtalk.clipboard_clear_timeout_ms` | `60000` | Auto-clear timeout (60s); `<=0` falls back to 60s |

**Live wiring:** `vendor/guardtalk/device/tokay/guardtalk-product-props.mk`
(included from `guardtalk-radio-excised.mk` → `tokay.mk`).  
**Docs mirror:** `vendor/guardtalk/device/tokay/guardtalk-tokay.mk` (not inherited).

## privacy_tmpfs layout

```text
/mnt/guardtalk_privacy/          ← tmpfs (64m, nosuid,nodev,noexec)
├── logs/                        ← system:system 0770 — RAM logs
└── cache/                       ← system:system 0770 — ephemeral cache
```

| Item | Value |
|------|-------|
| Init script | `vendor/guardtalk/init/init.guardtalk.privacy_tmpfs.rc` |
| Soong module | `init.guardtalk.privacy_tmpfs.rc` (`prebuilt_etc` → `system/etc/init/`) |
| PRODUCT_PACKAGES | Live via `guardtalk-feature-excised.mk` (late product bridge) |
| Trigger | `on init` (unconditional when .rc is installed; package is the product gate) |
| Sepolicy | Reuses `/mnt` tmpfs labeling; init already has `tmpfs:dir` create/mounton |

**Contract for consumers:** Write sensitive ephemeral logs/cache under
`GuardTalkPrivacyPolicy.getPrivacyTmpfsPath()` (`logs/` / `cache/` subdirs). Do **not**
persist plaintext privacy material under `/data` for these paths. After reboot the
mount is empty — that is the acceptance criterion (“RAM logs gone after reboot”).

## clipboard_clear enforcement

```text
Copy / setPrimaryClip
        │
        ▼
ClipboardService.scheduleAutoClear
        │  GuardTalk on ⇒ force auto_clear + product timeout (60s)
        ▼
Timeout → MSG_CLEAR → primaryClip = null

Keyguard locked / SCREEN_OFF
        │
        ▼
clearAllClipboardsForGuardTalk → all users/devices cleared

Reboot
        │
        ▼
In-memory clips discarded (no disk persistence)
```

| Layer | Class | Role |
|-------|-------|------|
| Framework policy | `android.guardtalk.GuardTalkPrivacyPolicy` | Props, path, timeout, mustClearOnLock |
| Clipboard service | `ClipboardService` | Lock/screen-off clear + forced timeout |
| Init | `init.guardtalk.privacy_tmpfs.rc` | Mount privacy tmpfs |

## Fail-closed rules

1. Props unset on non-GuardTalk builds ⇒ policy **off** (stock GrapheneOS clipboard auto-clear / no privacy mount).
2. When `clipboard_clear=1`:
   - DeviceConfig `auto_clear_enabled=false` is **ignored** (still clears)
   - Timeout `<=0` ⇒ default 60s
   - Keyguard listener unavailable ⇒ one-shot clear + SCREEN_OFF companion
   - Unknown lock state (`mustClearClipboardOnLock(null)`) ⇒ clear
3. When `privacy_tmpfs=1` but mount fails, init logs the failure; writers should still target the documented path (empty/absent ⇒ no persistent leak of those paths under `/data` from this feature).
4. UI hide alone is insufficient — `ClipboardService` is the authority for clipboard retention.

## Frontend contract (`F-SEC-P4-SYSTEM-UI`)

1. Do **not** expose a user toggle that disables clipboard clear or privacy tmpfs without GT Config (future hardening may add gated status only).
2. Security / privacy status copy may reference:
   - “Clipboard clears on lock and after 60 seconds.”
   - “Sensitive logs stay in RAM and are wiped on reboot.”
3. Files UI / MIME handlers remain `T-SEC-P4-FILES` — do not wire here.
4. Suggested status keys (optional, Frontend-owned):
   - prop `ro.guardtalk.clipboard_clear`
   - prop `ro.guardtalk.privacy_tmpfs`
   - path `ro.guardtalk.privacy_tmpfs_path`

### Suggested UI copy

- Clipboard: “Clipboard clears when the device locks and after a short timeout.”
- Privacy storage: “Sensitive temporary data is kept in RAM and discarded on reboot.”

## Rollback (Law 11)

1. In `vendor/guardtalk/device/tokay/guardtalk-product-props.mk` (and the
   docs mirror `guardtalk-tokay.mk`):
   - set `ro.guardtalk.privacy_tmpfs=0` (or remove)
   - remove `ro.guardtalk.privacy_tmpfs_path`
   - set `ro.guardtalk.clipboard_clear=0` (or remove)
   - remove `ro.guardtalk.clipboard_clear_timeout_ms`
2. Remove `PRODUCT_PACKAGES += init.guardtalk.privacy_tmpfs.rc` from
   `guardtalk-feature-excised.mk` (and the docs mirror in `guardtalk-tokay.mk`).
3. Revert hooks in `ClipboardService` and delete:
   - `frameworks/base/core/java/android/guardtalk/GuardTalkPrivacyPolicy.java`
   - `vendor/guardtalk/init/` (rc + Android.bp)
   - `vendor/guardtalk/device/tokay/guardtalk-product-props.mk` (or strip privacy lines)
   - this doc (optional)
4. Rebuild:

```bash
m services init.guardtalk.privacy_tmpfs.rc -j$(nproc)
# refresh vendor props after PRODUCT_PROPERTY_OVERRIDES changes:
m out/target/product/tokay/vendor/build.prop
```

No irreversible state: tmpfs is RAM-only; clipboard is in-memory; props are build-time reversible.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
# If lunch fails on adevtool pin: temporarily comment
# vendor/google_devices/tokay/adevtool-version-check.mk, lunch, restore after.
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m services init.guardtalk.privacy_tmpfs.rc -j$(nproc)
```

### Runtime checks (device)

```bash
getprop ro.guardtalk.privacy_tmpfs              # expect 1
getprop ro.guardtalk.privacy_tmpfs_path         # expect /mnt/guardtalk_privacy
getprop ro.guardtalk.clipboard_clear            # expect 1
getprop ro.guardtalk.clipboard_clear_timeout_ms # expect 60000
mount | grep guardtalk_privacy                  # expect tmpfs on /mnt/guardtalk_privacy
ls -ld /mnt/guardtalk_privacy/logs /mnt/guardtalk_privacy/cache
# After reboot: mount present and empty (no prior RAM logs)
```

### Static checks

```bash
rg -n "GuardTalkPrivacyPolicy|privacy_tmpfs|clipboard_clear" \
  frameworks/base/core/java/android/guardtalk/GuardTalkPrivacyPolicy.java \
  frameworks/base/services/core/java/com/android/server/clipboard/ClipboardService.java \
  vendor/guardtalk/init/init.guardtalk.privacy_tmpfs.rc \
  vendor/guardtalk/device/tokay/guardtalk-tokay.mk
```

## Files touched

| Path | Change |
|------|--------|
| `frameworks/base/core/java/android/guardtalk/GuardTalkPrivacyPolicy.java` | **NEW** policy API |
| `frameworks/base/services/core/java/com/android/server/clipboard/ClipboardService.java` | Lock/screen-off clear + forced timeout |
| `vendor/guardtalk/init/init.guardtalk.privacy_tmpfs.rc` | **NEW** tmpfs mount |
| `vendor/guardtalk/init/Android.bp` | **NEW** `prebuilt_etc` |
| `vendor/guardtalk/device/tokay/guardtalk-product-props.mk` | **NEW** live PRODUCT_PROPERTY_OVERRIDES |
| `vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk` | Include product-props |
| `vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk` | PRODUCT_PACKAGES for init rc (+ PERMS XML) |
| `vendor/guardtalk/device/tokay/guardtalk-tokay.mk` | Docs mirror props + packages |
| `vendor/guardtalk/docs/PRIVACY_TMPFS_CLIPBOARD_POLICY.md` | **NEW** this doc |
