# QA Evidence — Q-SYS-HIDE-GESTURE-BACKUP

**Task:** `Q-SYS-HIDE-GESTURE-BACKUP` (Gestures/Backup UI+search absence)  
**Date:** 2026-07-24  
**Agent:** QA_ENGINEER  
**Depends:** `F-SYS-HIDE-GESTURE-BACKUP` ✅ APPROVED  
**Verdict:** **GO** (static) — runtime adb **NOT RUN** (no device)

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Overlay `config_show_gesture_settings=false` | PASS | `vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml` |
| Overlay `config_show_backup_settings=false` | PASS | same overlay config.xml |
| Settings defaults true (baseline) | PASS | `packages/apps/Settings/res/values/config.xml` both `true` |
| Gestures controller gate | PASS | `GesturesSettingPreferenceController.isGestureSettingsAvailable` → `UNSUPPORTED_ON_DEVICE` |
| Gesture `@SearchIndexable` pages gated | PASS | 13 pages call `isGestureSettingsAvailable` in `isPageSearchEnabled` |
| Backup Privacy force-hide | PASS | `PrivacySettingsUtils.getInvisibleKey` hides `backup_data` / `auto_restore` / `configure_account` / `backup_inactive` |
| Backup controllers gated | PASS | `BackupInactive` / `DataManagement` / `BackupSettingsPreferenceController` |
| Backup search gated | PASS | `PrivacySettings`, `BackupSettingsFragment`, `UserBackupSettingsActivity` |
| No APK/service deletes (F-SYS-HIDE scope) | PASS | Sources retained; `IBackupManager` still referenced; overlay/policy “hide ≠ delete”; no F-SYS-HIDE tie-in in feature-excised |
| Accepted residual: Sound Prevent Ringing | DOCUMENTED | `sound_settings.xml` key `gesture_prevent_ringing_sound`; dedicated search page gated; Architect accepted on F APPROVED |
| F APPROVED + `m Settings` EXIT=0 | PASS | `TASK_QUEUE.md` Architect APPROVED 2026-07-24; `TO_ARCHITECT_F-SYS-HIDE.md` EXIT=0; Settings.apk present with symbols |
| Policy / overlay docs | PASS | `SETTINGS_VISIBILITY_POLICY.md` + overlay README matrices |

## Static script

```bash
bash vendor/guardtalk/docs/qa/verify_sys_hide_gesture_backup_static.sh
# ALL STATIC CHECKS PASSED
# PASS_COUNT=103 FAIL_COUNT=0 EXIT=0
```

**Counts:** **103 / 103** PASS (0 FAIL).  
Created for `Q-SYS-HIDE-GESTURE-BACKUP` (mirrors `verify_sec_p*_static.sh` style).

## Build / artifact smoke (cited; no fresh `m` this session)

| Source | Command / note | Result |
|--------|----------------|--------|
| `TASK_QUEUE.md` F-SYS-HIDE-GESTURE-BACKUP APPROVED | Architect APPROVED 2026-07-24; Gate 5 94%; residual Sound Prevent Ringing accepted | cited |
| `.agent-comm/inbox/TO_ARCHITECT_F-SYS-HIDE.md` | `m Settings -j$(nproc)` **EXIT=0** (~08:41 / artifact 05:18 UTC) | cited |
| `out/target/product/tokay/system_ext/priv-app/Settings/Settings.apk` | symbols: `config_show_gesture_settings`, `config_show_backup_settings`, `isGestureSettingsAvailable` | PRESENT |

No rebuild performed this QA session (task allows citing F APPROVED green build + static script).

## Known residual (Architect-accepted)

| Residual | Status | Notes |
|----------|--------|-------|
| Sound → Prevent Ringing preference row (`gesture_prevent_ringing_sound`) | **ACCEPTED** | Not System → Gestures; dedicated `PreventRingingGestureSettings` search page is gated via `isGestureSettingsAvailable` |
| Pre-existing `feature-excised` Backup APK cluster | OUT OF SCOPE | Not introduced by F-SYS-HIDE; F task is UI-hide only |

## Adb

```text
adb devices
List of devices attached
(empty)
```

Runtime smoke **SKIPPED**:

- System → Gestures row absent on device
- Privacy → Backup rows absent on device
- Settings search returns no Gestures/Backup hits
- Sound Prevent Ringing residual visible (expected)

## Adversarial notes

| Case | Expected | Actual | Status |
|------|----------|--------|--------|
| Overlay bools true | would show Gestures/Backup | overlay false; Settings default true | PASS |
| Gesture search pages without gate | forbidden | all 13 listed pages gated | PASS |
| Backup search raw index when hidden | empty / non-indexable | `UserBackupSettingsActivity` early-return + NIK | PASS |
| APK delete as hide strategy | forbidden for this task | sources + IBackupManager retained | PASS |
| Invent PASS without script | forbidden | script EXIT=0 recorded | PASS |

## Coverage gaps

- No device/emulator: cannot adb-verify Settings UI hierarchy or live search results.
- Overlay runtime merge not exercised on device (static overlay XML only).
- Pre-existing Backup APK excision in `apps-excised.mk` not re-audited (out of F-SYS-HIDE delta).

## Gate 5 (Self-Critique)

See `.agent-comm/inbox/TO_ARCHITECT.md` / `TO_ARCHITECT_Q-SYS-HIDE.md` — **Q-SYS-HIDE-GESTURE-BACKUP Gate 5: 93%**.

### PQE Assessment: Code Entropy LOW — overlay-reversible UI hide; controllers/search fail closed when bool false; residual documented and accepted.
