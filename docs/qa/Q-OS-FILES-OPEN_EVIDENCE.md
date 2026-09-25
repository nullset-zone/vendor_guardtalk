# QA Evidence — Q-OS-FILES-OPEN

**Task:** `Q-OS-FILES-OPEN` (independent rematch of `F-OS-FILES-OPEN`)  
**DEC:** DEC-OS-UX-001  
**Date:** 2026-09-16T08:55:00Z  
**Agent:** QA_ENGINEER  
**Depends:** `F-OS-FILES-OPEN` Architect-APPROVED (static) — **not trusted**  
**Verdict:** **PASS (static)** + **HOLD (adb / lunch / runtime tap)**  
**LIVE_DEVICE_CLAIMED:** false  
**USB/flash:** not run  

Do not treat Architect APPROVE or the Frontend completion report as evidence.
This rematch re-ran packet commands and a host suite against in-tree sources.

## Suite

```bash
bash vendor/guardtalk/docs/qa/verify_os_files_open_static.sh
# PASS_COUNT=47 FAIL_COUNT=0 HOLD_COUNT=4 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# OVERALL: PASS (static) + HOLD (adb/lunch)
```

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Tap path: VIEW resolve then in-app preview then dialog | **PASS** | `viewDocument` order: `resolveActivity` → `GuardTalkMediaPreview.start` → `showOpenFailed` |
| Space / preview-only fails visibly | **PASS** | `VIEW_TYPE_PREVIEW` + `NONE`: in-app start then `showOpenFailed`; SPACE key wired |
| No empty chooser when unresolved | **PASS** | `showChooserForDoc` `resolveActivity == null` → dialog + `return` before `createChooser` |
| `MediaPreviewActivity` `exported=false`, no VIEW filter | **PASS** | manifest activity, no `<intent-filter>` |
| FilesActivity VIEW root+directory only (no VIEW `*/*`) | **PASS** | `vnd.android.document/{root,directory}` only |
| Single MAIN+LAUNCHER on Files alias | **PASS** | `.LauncherActivity` only |
| Compose `enabled=false` / no LAUNCHER | **PASS** | compose `MainActivity` |
| Decode/play failure visible (`peek_no_preview`) | **PASS** | layout + `showError` on null bitmap / video error |
| Extra Files launcher | **PASS (absent)** | one MAIN+LAUNCHER; overlay icon-only |
| VIEW `*/*` on Files/MediaPreview | **PASS (absent)** | none; SAF GET_CONTENT `*/*` is not VIEW |
| Gallery2 un-excise | **PASS (still dropped)** | still in `GUARDTALK_APPS_PACKAGES`; not KEEP |
| Device tap jpeg/png/webp/mp4/webm | **HOLD** | `adb devices` empty |
| `m DocumentsUI` / lunch | **HOLD** | adevtool pin (`tokay vendor module is outdated`) |
| Not device-fixed | **PASS (honesty)** | `LIVE_DEVICE_CLAIMED=false` |

## Packet commands (raw)

### `rg -n "LAUNCHER|MediaPreviewActivity|vnd.android.document" packages/apps/DocumentsUI/AndroidManifest.xml`

```
134:                <category android:name="android.intent.category.LAUNCHER" />
142:            android:name=".guardtalk.MediaPreviewActivity"
158:                <data android:mimeType="vnd.android.document/root" />
163:                <data android:mimeType="vnd.android.document/directory" />
```

LAUNCHER is on activity-alias `.LauncherActivity` (MAIN+LAUNCHER).  
MediaPreview is `exported="false"` with **no** intent-filter (L141–145).  
FilesActivity VIEW MIME is root + directory only.

### `rg -n "LAUNCHER|enabled" packages/apps/DocumentsUI/compose/AndroidManifest.xml`

```
51:             second Files launcher icon. Keep MAIN for adb/debug start; drop LAUNCHER. -->
55:            android:enabled="false">
```

Compose `MainActivity`: `enabled=false`, MAIN without LAUNCHER.

### `adb devices`

```
List of devices attached

```

Empty. `query-activities` **not executed**. Device tap **HOLD**. Device-fixed **not claimed**.

### `viewDocument` / preview-only / chooser (source order)

`AbstractActionHandler.viewDocument`:

1. `intent.resolveActivity(...) != null` → `startActivityAsUser` VIEW  
2. else `GuardTalkMediaPreview.start` (image/* or video/*)  
3. else `showOpenFailed` → `showNoApplicationFoundDialog`

`onDocumentOpened` preview-only (`type == PREVIEW && fallback == NONE`):

1. `GuardTalkMediaPreview.start`  
2. else `showOpenFailed` (not silent)

`files.ActionHandler.showChooserForDoc`:

1. `resolveActivity == null` → dialog + `return`  
2. else chooser / ResolverActivity (caught `ActivityNotFoundException` → dialog)

Tap (`DirectoryFragment.onItemActivated`, non-desktop): `openItem(PREVIEW, REGULAR)` → QuickView then `viewDocument`.  
SPACE (`InputHandlers`): `openItem(PREVIEW, NONE)`.

## Frontend claims — prove or refute

| Claim | QA result |
|-------|-----------|
| VIEW handler first, then in-app preview, then dialog | **PROVED** (static) |
| Space/preview-only no longer silent | **PROVED** (static) |
| Chooser unresolved → dialog, not empty chooser | **PROVED** (static) |
| MediaPreview `exported=false`, no VIEW filter | **PROVED** |
| Single MAIN+LAUNCHER; Compose disabled | **PROVED** |
| DocumentsUI VIEW still root+directory | **PROVED** |
| Decode/play failure shows `peek_no_preview` | **PROVED** (static wiring) |
| Did not un-excise Gallery2 | **PROVED** |
| Device tap jpeg/png/webp/mp4/webm works | **NOT PROVED** — adb empty HOLD |
| `m DocumentsUI` EXIT=0 | **NOT PROVED** — lunch HOLD |

## Adversarial / negative

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Extra Files LAUNCHER | exactly one `.LauncherActivity` | one | PASS |
| MediaPreview VIEW `*/*` | none | no intent-filter | PASS |
| FilesActivity VIEW `*/*` | none | root+directory only | PASS |
| Gallery2 KEEP / drop | still dropped | dropped, not KEEP | PASS |
| Silent preview-only | dialog or in-app | in-app then dialog | PASS |
| Empty chooser | dialog + return | resolve-null returns | PASS |
| Blank preview on decode fail | visible error | `peek_no_preview` VISIBLE | PASS |
| Device tap without adb | HOLD | HOLD | HOLD |

## Counts

- **47 PASS / 0 FAIL / 4 HOLD / EXIT=0**
- HOLD: lunch pin; adb jpeg/png/webp; adb mp4/webm; runtime blank/empty/silent
- Instrumented `ActionHandlerTest` / `GuardTalkMediaPreviewTest` present; **not executed** (no lunch)
- `pytest platform/tests`: N/A (AOSP DocumentsUI UX card)

## Honesty

**Not device-fixed.** No USB. No git commit. Status **REVIEW** only (never APPROVED).
