# GuardTalk Files UI Notes

**Task:** `F-SEC-P4-SYSTEM-UI` (Frontend) — consumes `T-SEC-P4-FILES` / `FILES_HANDLERS_POLICY.md`  
**Date:** 2026-07-23

## Purpose

UI polish only for the stock DocumentsUI Files app. No parallel file manager,
no Backend policy engine redesign.

## Contract (applied)

| Rule | UI posture |
|------|------------|
| Single Files launcher | DocumentsUI `LauncherActivity` only; Compose shell stays `enabled=false` / no `LAUNCHER` |
| Trash | Stock menus (“Move to Trash” / “Restore from Trash”) when `ro.guardtalk.files_trash=1` |
| ZIP | `feature_archive_creation=true` — Compress / Zip menus remain |
| Critical mounts | Delete failure copy explains system/firmware cannot be erased from Files |
| No duplicate technical launcher | Do not re-enable `DocumentsUICompose` MAIN+LAUNCHER |

## Copy (Settings Security status)

Surfaced post-unlock under Security → Status (no network rows):

- Clipboard: “Clipboard clears when the device locks and after a short timeout.”
- Privacy tmpfs: “Sensitive temporary data is kept in RAM and discarded on reboot.”
- Files: “Deleted files go to Trash so you can restore them. System and firmware storage cannot be erased from Files.”

## Rollback (Law 11)

1. Revert DocumentsUI string / config comment polish.
2. Revert Security status XML/string rows for clipboard/tmpfs/files.
3. Rebuild: `m Settings DocumentsUI -j$(nproc)`.
