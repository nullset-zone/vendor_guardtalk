# QA Evidence — Q-REMEDIATE-B3-VIEWER (item 18)

**Task:** `Q-REMEDIATE-B3-VIEWER` (independent rematch of `T-REMEDIATE-B3-VIEWER` + `F-REMEDIATE-B3-VIEWER`)  
**Date:** 2026-09-16T14:03:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** T-REMEDIATE-B3-VIEWER APPROVED static + F-REMEDIATE-B3-VIEWER APPROVED static (Architect). **Not trusted.**  
**DEC:** DEC-REMEDIATE-002  
**Verdict:** **PASS (host lunch + static)** — device `query-activities` **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED). **PASS HOLD remains.** OS-UX on-device proof **not folded** (`Q-REMEDIATE-B3-OSUX-DEVICE` BLOCKED).

Independent rematch. Backend and Frontend completion reports were **not trusted**. Product source was not edited. Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Guardian MCP / HTTP / aegis-verifier / gate_enforcer **not called**.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | HTMLViewer AndroidManifest VIEW jpeg/png/webp (content+file; no LAUNCHER; no `image/*` / `*/*`) | **PASS** | `packages/apps/HTMLViewer/AndroidManifest.xml` filters; JS off; network blocked |
| 2 | `lunch komodo-trunk_staging-user` (session-only GIT_CONFIG for `vendor/adevtool`; no `set -u` around `source build/envsetup.sh`) | **PASS** | `TARGET_PRODUCT=komodo` `TARGET_BUILD_VARIANT=user`. HTMLViewer **PRESENT**, Gallery2 **ABSENT**, ImageViewer **ABSENT**. DocumentsUI PRESENT. UMP PRESENT (supporting). HTMLViewer token count=1 |
| 3 | DocumentsUI `viewDocument`: HTMLViewer VIEW first, then generic VIEW, then in-app MediaPreview, then visible NoApplication dialog. Never silent | **PASS** | extracted `viewDocument` order; `showOpenFailed` → `showNoApplicationFoundDialog` |
| 4 | MediaPreviewActivity `exported=false`; SampleImageProvider `exported=false` | **PASS** | DocumentsUI manifest no VIEW filter; Validator provider `grantUriPermissions=true` |
| 5 | Validator main-path sample PNG via HtmlViewerLaunch + AlertDialog on fail. EscapeMenu must NOT contain the sample-image item | **PASS** | `ValidatorActivity` `btn_open_sample_image`; `openSampleOrExplain`; EscapeMenu.kt + `escape_menu.xml` have no sample-image tokens |
| 6 | No second gallery. Do not un-excise Gallery2 | **PASS** | Gallery2 still in drop list / not KEEP; no `vendor/guardtalk/apps/ImageViewer`; lunch ImageViewer ABSENT |
| 7 | `adb devices` empty → query-activities HOLD. Not device-fixed. Do not fold OS-UX device proof | **HOLD** (process **PASS**) | empty adb list. `Q-REMEDIATE-B3-OSUX-DEVICE` remains BLOCKED; not started |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b3_viewer_host.sh
# RESULT: PASS (host)  bash_PASS=31 bash_HOLD=4 bash_FAIL=0 PY_RC=0
# Combined: 93 PASS / 0 FAIL / 4 HOLD  (PY_COUNTS pass=62 fail=0 hold=0)
# EXIT=0
```

`pytest platform/tests`: N/A (AOSP manifests + DocumentsUI Java + Validator Kotlin).

First suite run FAILed (1) on `GuardTalkHtmlViewerLaunch` javadoc `{@code image/*}` / `{@code */*}` negatives treated as live MIME. Suite strips comments. **Not a product FAIL.**

## Independent rematch (do not trust T/F)

### Lunch packages

- HTMLViewer PRESENT (media_system.mk + KEEP). Token count=1.
- Gallery2 ABSENT (still in `GUARDTALK_APPS_PACKAGES` drop; not KEEP).
- ImageViewer ABSENT (no priv-app; no `PRODUCT_PACKAGES += ImageViewer`).
- DocumentsUI PRESENT (Files path).
- UniversalMediaPlayer PRESENT (supporting video VIEW; item 18 still-image AC is HTMLViewer).
- GmsCompat still in drop list (B2 not regressed).

### Files path

`AbstractActionHandler.viewDocument` order:

1. `GuardTalkHtmlViewerLaunch.start` (explicit `com.android.htmlviewer.HTMLViewerActivity` ACTION_VIEW for jpeg/png/webp only)
2. generic `intent.resolveActivity` VIEW
3. in-app `GuardTalkMediaPreview.start`
4. `showOpenFailed` → `showNoApplicationFoundDialog`

MediaPreviewActivity `exported=false`, no intent-filters.

### Validator path

Main-path `btn_open_sample_image` → `HtmlViewerLaunch.openSampleOrExplain` (PNG URI from grant-only `SampleImageProvider`). AlertDialog title/message/OK if HTMLViewer missing. EscapeMenu unchanged (Settings / cam-mic / status). Sample PNG magic `89 50 4E 47`, 69 bytes.

### Device

`adb devices` empty list. `query-activities image/jpeg` **HOLD**. `m` not run. Not device-fixed. Do not claim live / lift PASS HOLD. On-device Files/Validator proof remains `Q-REMEDIATE-B3-OSUX-DEVICE` (BLOCKED).

## Residuals (not FAIL)

- HTMLViewer still registers `text/html` VIEW (T-OS-FILES-MEDIA residual).
- `NoApplicationFragment` Play-store search copy is pre-existing; dialog is still visible (no store on this product).
- Unit tests added by Frontend were not executed (`m` HOLD).
- Device jpeg/png/webp open HOLD until a komodo **user** image exists.
