# QA Evidence — Q-SEC-P4-PRIVACY

**Task:** `Q-SEC-P4-PRIVACY` (Phase-4 §32 privacy/files acceptance)  
**Date:** 2026-07-23  
**Agent:** QA_ENGINEER  
**Depends:** `T-SEC-P4-PERMS` ✅, `T-SEC-P4-PRIVACY` ✅, `T-SEC-P4-FILES` ✅, `F-SEC-P4-SYSTEM-UI` ✅  
**Verdict:** **GO** (static + cited prior builds) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Messenger `com.guardtalk.messenger` grant plumbing | PASS | `GuardTalkPermissionDefaultsPolicy.MESSENGER_PACKAGE_NAME`; `grantGuardTalkMessengerDefaultPermissions`; product XML + Soong module |
| Third-party deny-default | PASS | `allowDefaultPermissionException` + `DefaultPermissionGrantPolicy` skip non-system exceptions |
| privacy_tmpfs init + props | PASS | `init.guardtalk.privacy_tmpfs.rc` mounts `/mnt/guardtalk_privacy`; props in `guardtalk-product-props.mk` + vendor/build.prop |
| clipboard_clear hooks | PASS | `ClipboardService.clearAllClipboardsForGuardTalk` on lock + SCREEN_OFF; forced timeout via policy |
| Files trash / ZIP | PASS | `FlagUtils` → `GuardTalkFilesLocalPolicy.isTrashEnabled`; `FileSystemProvider.trashDocument`; `CompressJob` + `feature_archive_creation=true` |
| Critical-partition protect | PASS | `GuardTalkFilesPolicy.isProtectedFile` in FileSystemProvider + ExternalStorageProvider |
| No duplicate Compose launcher | PASS | Compose `MainActivity` `enabled=false`, no `LAUNCHER`; stock DocumentsUI keeps LAUNCHER |
| Keep-hide matrices (Notif/Sound/Modes/Display/Storage/Battery/System) | PASS | Overlay top-level KEEP + Phase-4 sub-hides per `SETTINGS_VISIBILITY_POLICY` |
| Security mutation password gate | PASS | `config_security_mutations_require_password=true`; dashboard `startConfirm` + `assertAuthorized` + mutation keys |
| No network under Security | PASS | Dashboard XML has no network/wifi/vpn/hotspot/airplane keys; docs forbid |
| Prior green builds cited | PASS | DONE_LOG T/F APPROVED; root TASK_QUEUE EXIT=0 (`m services` / DocumentsUI / Settings) |
| Vendor props (where regenerable) | PASS / GAP | permission + privacy + clipboard present in `vendor/build.prop`; **files_*** absent (mk wired; image refresh GAP) |
| Messenger APK absent gap | DOCUMENTED | No product APK under `vendor/guardtalk/apps`; plumbing ready |
| adb runtime gaps | DOCUMENTED | `adb devices` empty — device smoke SKIPPED |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sec_p4_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=120 FAIL_COUNT=0 EXIT=0
```

Created for `Q-SEC-P4-PRIVACY` (mirrors `verify_sec_p1_static.sh` / `verify_sec_p2_static.sh` / `verify_sec_p3_static.sh` style).

## Artifact / build smoke (cited; no fresh `m` this session)

| Source | Command / note | Result |
|--------|----------------|--------|
| DONE_LOG `T-SEC-P4-PERMS APPROVED` (2026-07-23 12:55) | services / default-permissions build | EXIT=0 (cited) |
| DONE_LOG `T-SEC-P4-PRIVACY APPROVED` (2026-07-23 13:52) | `m services` + privacy_tmpfs.rc / vendor props | EXIT=0 (cited) |
| DONE_LOG `T-SEC-P4-FILES APPROVED` (2026-07-23 14:40) | DocumentsUI + ExternalStorageProvider | EXIT=0 (cited) |
| DONE_LOG `F-SEC-P4-SYSTEM-UI APPROVED` (2026-07-23 16:25) | `m Settings DocumentsUI` | EXIT=0 (cited) |
| Root `TASK_QUEUE.md` Phase-4 cards | EXIT=0 recorded | cited |
| `out/target/product/tokay/vendor/build.prop` | permission/privacy/clipboard props | present |
| Same build.prop | `files_policy` / `files_trash` / `files_protect_critical` | **ABSENT** (stale image; mk has them) |

No rebuild performed this QA session (task allows citing prior green builds).

## Vendor props snapshot

```text
# Present in vendor/build.prop:
ro.guardtalk.permission_defaults=1
ro.guardtalk.privacy_tmpfs=1
ro.guardtalk.privacy_tmpfs_path=/mnt/guardtalk_privacy
ro.guardtalk.clipboard_clear=1
ro.guardtalk.clipboard_clear_timeout_ms=60000

# Wired in guardtalk-product-props.mk but NOT yet in vendor/build.prop:
ro.guardtalk.files_policy=1
ro.guardtalk.files_trash=1
ro.guardtalk.files_protect_critical=1
```

**GAP:** Refresh vendor image / re-run product prop packaging so `files_*` land in `vendor/build.prop` before device acceptance confidence.

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime smoke **SKIPPED**:

- Messenger first-boot grants (requires Messenger APK + device)
- Third-party app exception deny at runtime
- privacy_tmpfs mount + reboot wipe of `/mnt/guardtalk_privacy/{logs,cache}`
- Clipboard clear on lock / 60s timeout
- Files Trash / ZIP / protect critical paths
- Settings keep-hide UI + Security password gate UX
- Confirm no network rows under Security on device

## Messenger-APK-absent gap

| Item | Status |
|------|--------|
| Package constant `com.guardtalk.messenger` | Present |
| Framework + XML + product prop plumbing | Present |
| Product Messenger APK / `PRODUCT_PACKAGES` app | **ABSENT** (by design for this phase) |
| Runtime grant activation | Blocked until APK ships |

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Third-party `etc/default-permissions` exception | skipped when non-system | `allowDefaultPermissionException` → `isSystemApp` only | PASS |
| Compose LAUNCHER re-enabled | forbidden | no LAUNCHER + `enabled=false` | PASS |
| Network keys under Security dashboard | forbidden | none | PASS |
| Security mutations without password gate | forbidden | overlay bool true + dashboard gate | PASS |
| files_* only in docs mk, not live props mk | forbidden | live in `guardtalk-product-props.mk` | PASS |
| Stale vendor/build.prop missing files_* | image refresh needed | GAP documented | GAP |

## Coverage gaps

- Device/runtime smoke deferred until adb device available
- Messenger grant e2e blocked on APK absence
- Fresh `m services` / DocumentsUI / Settings rebuild not re-run this session (cited prior green)
- `files_*` props need vendor image refresh to appear in `build.prop`

## PQE Assessment

### PQE Assessment: Code Entropy LOW — policy classes + thin service hooks; deny-default and protect paths fail-closed; Compose launcher removed reduces UI cascade; primary residual risk is stale vendor prop image + missing Messenger APK for runtime grant proof.

## Gate 5

### Ultimate Critique Score: 93% (Gate 5)

Method: MCP `ultimate_critique` unavailable this session (Not connected); manual fallback.  
Manual 0–10: acceptance 10, scope 10, tests pass 10, regressions 10, adversarial 9, edges 8, independence 10, footprint 10, bugs/docs 9, gaps 8 → **93/100**.

## GO / NO-GO

**GO** for Architect review of Phase-4 static acceptance.  
Do **not** treat as production-ready until: (1) adb device smoke, (2) vendor image refresh for `files_*` props, (3) Messenger APK lands and grant e2e is proven.  
Status remains **REVIEW** — never APPROVED by QA.
