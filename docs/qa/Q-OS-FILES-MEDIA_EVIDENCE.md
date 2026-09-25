# QA Evidence — Q-OS-FILES-MEDIA

**Task:** `Q-OS-FILES-MEDIA` (independent rematch of `T-OS-FILES-MEDIA`)  
**DEC:** DEC-OS-UX-001  
**Date:** 2026-09-16T08:25:08Z  
**Agent:** QA_ENGINEER  
**Depends:** `T-OS-FILES-MEDIA` Architect-APPROVED (static) — **not trusted**  
**Verdict:** **PASS (static)** + **HOLD (adb / lunch / runtime)**  
**LIVE_DEVICE_CLAIMED:** false  
**USB/flash:** not run  

Do not treat Architect APPROVE or the Backend completion report as evidence.
This rematch re-ran packet commands and a host suite against in-tree sources.

## Suite

```bash
bash vendor/guardtalk/docs/qa/verify_os_files_media_static.sh
# PASS_COUNT=32 FAIL_COUNT=0 HOLD_COUNT=4 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# OVERALL: PASS (static) + HOLD (adb/lunch)
```

## Acceptance matrix

| Criterion | Result | Evidence |
|-----------|--------|----------|
| In-tree VIEW `image/jpeg` | **PASS** | HTMLViewer `HTMLViewerActivity` filter `image/jpeg` (`content` + `file`) |
| In-tree VIEW `image/png` | **PASS** | same filter `image/png` |
| In-tree VIEW `image/webp` | **PASS** | same filter `image/webp` |
| In-tree VIEW `video/mp4` | **PASS** | UniversalMediaPlayer `VideoPlayerActivity` `video/mp4` (`content` + `file`) |
| In-tree VIEW `video/webm` | **PASS** | same filter `video/webm` |
| Gallery2 still dropped | **PASS** | `GUARDTALK_APPS_PACKAGES` contains `Gallery2`; not in `GUARDTALK_APPS_KEEP` |
| HTMLViewer KEEP / not in drop list | **PASS** | not in drop list; in `GUARDTALK_APPS_KEEP`; still in `media_system.mk` |
| UniversalMediaPlayer in `PRODUCT_PACKAGES` | **PASS** | `PRODUCT_PACKAGES += UniversalMediaPlayer` + KEEP |
| DocumentsUI VIEW root + directory only | **PASS** | MIME `vnd.android.document/root` + `vnd.android.document/directory` |
| DocumentsUI VIEW `*/*` | **PASS (absent)** | no VIEW `*/*` |
| SAF `*/*` on GET_CONTENT/OPEN/CREATE | **PASS (not a FAIL)** | 4 SAF filters still `*/*` |
| `CRITICAL_PATH_PREFIXES` include `/system` `/vendor` `/boot` (etc.) | **PASS** | full T-SEC-P4 set still present |
| `query-activities` image/jpeg + video/mp4 | **HOLD** | `adb devices` empty |
| Device-fixed / black-screen | **HOLD** | no adb; not claimed |
| lunch / `m` | **HOLD** | `adevtool-version-check.mk` pin still present; lunch not run |

## Negative matrix

| Attack / failure mode | Expected | Actual | Status |
|-----------------------|----------|--------|--------|
| Silent fail because no handler | in-tree VIEW exists | HTMLViewer + UMP filters present | **PASS** (static). Runtime silent-fail **HOLD** |
| Empty chooser | resolvable handlers | cannot query PMS | **HOLD** (adb empty) |
| Gallery2 un-excised | stay in drop list | still dropped; not KEEP | **PASS** |
| DocumentsUI VIEW `*/*` spam launcher | forbidden | VIEW = root + directory only | **PASS** |
| HTMLViewer still in drop list | KEEP | not in drop; in KEEP | **PASS** |
| `GuardTalkFilesPolicy` critical-protect weakened | `/system` `/vendor` `/boot` remain | full prefix set intact | **PASS** |
| Black-screen claim without adb | HOLD | HOLD; not claimed PASS | **HOLD** |
| Extra Files / player LAUNCHER | none on HTMLViewer/UMP | no `LAUNCHER` category; PumpActivity `exported=false` | **PASS** |
| Compose second Files icon | disabled | Compose `MainActivity` `enabled=false`, no LAUNCHER | **PASS** |

## Packet command output (raw)

### `rg -n "android.intent.action.VIEW" packages/apps/DocumentsUI/AndroidManifest.xml`

```
156:                <action android:name="android.intent.action.VIEW" />
161:                <action android:name="android.intent.action.VIEW" />
172:                <action android:name="android.intent.action.VIEW_DOWNLOADS" />
```

VIEW MIME at those filters: `vnd.android.document/root` (L158) and `vnd.android.document/directory` (L163).
`VIEW_DOWNLOADS` is a distinct action (prefix match only).

### `rg -n "Gallery2|HTMLViewer|UniversalMediaPlayer" vendor/guardtalk/feature-excised/apps-excised.mk`

Live (non-comment) hits:

```
147:    Gallery2 \
344:    HTMLViewer \
345:    UniversalMediaPlayer
776:PRODUCT_PACKAGES += UniversalMediaPlayer
```

L147 is inside `GUARDTALK_APPS_PACKAGES +=` (drop). L344–345 are inside `GUARDTALK_APPS_KEEP :=`.

### `rg -n "image/jpeg|video/mp4|image/webp|video/webm|image/png"` HTMLViewer + UMP

```
packages/apps/UniversalMediaPlayer/AndroidManifest.xml:102:                <data android:mimeType="video/mp4"/>
packages/apps/UniversalMediaPlayer/AndroidManifest.xml:103:                <data android:mimeType="video/webm"/>
packages/apps/HTMLViewer/AndroidManifest.xml:47:                <data android:mimeType="image/jpeg"/>
packages/apps/HTMLViewer/AndroidManifest.xml:48:                <data android:mimeType="image/png"/>
packages/apps/HTMLViewer/AndroidManifest.xml:49:                <data android:mimeType="image/webp"/>
```

UMP also declares `video/*` at L104 (broader residual, not FAIL).

### `rg -n "CRITICAL_PATH_PREFIXES|/system|/vendor|/boot" GuardTalkFilesPolicy.java`

```
63:    private static final String[] CRITICAL_PATH_PREFIXES = {
64:            "/system",
65:            "/system_ext",
66:            "/vendor",
70:            "/boot",
72:            "/vendor_boot",
76:            "/mnt/vendor",
```

Required set still present: `/system` `/system_ext` `/vendor` `/product` `/odm` `/oem` `/boot` `/recovery` `/vendor_boot` `/init_boot` `/firmware` `/persist` `/mnt/vendor` `/mnt/product` `/mnt/guardtalk_privacy`.

### `rg -n "LAUNCHER"` HTMLViewer + UMP + DocumentsUI

```
packages/apps/UniversalMediaPlayer/AndroidManifest.xml:35:        <!-- ... No LAUNCHER ...
packages/apps/DocumentsUI/AndroidManifest.xml:134:                <category android:name="android.intent.category.LAUNCHER" />
packages/apps/HTMLViewer/AndroidManifest.xml:40:            <!-- ... (no LAUNCHER).
```

HTMLViewer / UMP have comment-only `LAUNCHER` strings. DocumentsUI Files alias keeps the real category.

### `adb devices`

```
List of devices attached

```

Empty. `query-activities` **not executed**. Device-fixed **not claimed**.

## Backend claims — prove or refute

| Claim | QA result |
|-------|-----------|
| HTMLViewer image VIEW (jpeg/png/webp) | **PROVED** (static) |
| UniversalMediaPlayer video VIEW (mp4/webm) | **PROVED** (static); also `video/*` |
| Gallery2 stays excised | **PROVED** |
| GuardTalkFilesPolicy does not gate VIEW | **PROVED** (javadoc + no VIEW logic; protect methods still delete/trash) |
| DocumentsUI VIEW still root + directory | **PROVED** |
| HTMLViewer not in drop list (KEEP) | **PROVED** |
| `PRODUCT_PACKAGES += UniversalMediaPlayer` | **PROVED** |
| Device media open works | **NOT PROVED** — **HOLD** (adb empty) |
| No black screen | **NOT PROVED** — **HOLD** |

## Residuals (not FAIL)

- UniversalMediaPlayer still declares `INTERNET` + legacy storage (pre-existing).
- UMP `video/*` is broader than mp4/webm.
- Un-excising HTMLViewer also restores `text/html` / `text/plain` VIEW.
- HTMLViewer uses WebView (`JS` off, network blocked). Image render quality is device-only.
- UMP `VideoPlayerActivity` has no error listener on `setMediaItem`; runtime black-screen possible — **HOLD**.
- lunch HOLD: `vendor/google_devices/tokay/adevtool-version-check.mk` still errors “tokay vendor module is outdated”.
- `F-OS-FILES-OPEN` owns tap-to-open chrome. This card found `DocumentsUI` `MediaPreviewActivity` (`exported=false`, no VIEW filter) — Files UX, not a handler FAIL.
- `query-activities` / empty chooser / silent Files tap: **HOLD** until adb.

## Security notes (Gate 3)

- No secrets in manifests / policy / excised.mk.
- HTMLViewer: `setJavaScriptEnabled(false)` + `setBlockNetworkLoads(true)` still present.
- Critical-protect not weakened.
- No product source edited by QA.

## Counts

- **32 PASS / 0 FAIL / 4 HOLD**
- HOLD items: lunch pin; `query-activities` jpeg; `query-activities` mp4; runtime black-screen/chooser/silent-fail
- `pytest platform/tests`: N/A (AOSP manifest/product card)
- EXIT=0
