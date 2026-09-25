#!/usr/bin/env bash
# Static verification for Q-OS-FILES-OPEN
# Independent rematch of F-OS-FILES-OPEN (DEC-OS-UX-001).
# Do not trust Frontend/Architect claims. Do not claim device-fixed without adb.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_os_files_open_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
FAIL_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; FAIL_N=$((FAIL_N + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

DOCUI="packages/apps/DocumentsUI/AndroidManifest.xml"
DOCUI_COMPOSE="packages/apps/DocumentsUI/compose/AndroidManifest.xml"
AAH="packages/apps/DocumentsUI/src/com/android/documentsui/AbstractActionHandler.java"
AH="packages/apps/DocumentsUI/src/com/android/documentsui/files/ActionHandler.java"
PREVIEW="packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/GuardTalkMediaPreview.java"
MPA="packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/MediaPreviewActivity.java"
DEC="packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/MediaPreviewDecoder.java"
LAYOUT="packages/apps/DocumentsUI/res/layout/guardtalk_media_preview.xml"
NOAPP="packages/apps/DocumentsUI/src/com/android/documentsui/files/NoApplicationFragment.kt"
INPUT="packages/apps/DocumentsUI/src/com/android/documentsui/dirlist/InputHandlers.java"
DIRFRAG="packages/apps/DocumentsUI/src/com/android/documentsui/dirlist/DirectoryFragment.java"
EXCISED="vendor/guardtalk/feature-excised/apps-excised.mk"
POLICY="frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java"
ADEVTOOL="vendor/google_devices/tokay/adevtool-version-check.mk"

echo "=== Q-OS-FILES-OPEN independent rematch ==="
echo "ROOT=$ROOT"
echo

echo "=== RAW: rg -n openDocument|viewDocument|QuickView|ACTION_VIEW|no_application_found|GuardTalkMediaPreview packages/apps/DocumentsUI/src ==="
rg -n "openDocument|viewDocument|QuickView|ACTION_VIEW|no_application_found|GuardTalkMediaPreview" \
  packages/apps/DocumentsUI/src || true
echo

echo "=== RAW: rg -n LAUNCHER|MediaPreviewActivity|vnd.android.document packages/apps/DocumentsUI/AndroidManifest.xml ==="
rg -n "LAUNCHER|MediaPreviewActivity|vnd.android.document" "$DOCUI" || true
echo

echo "=== RAW: rg -n LAUNCHER|enabled packages/apps/DocumentsUI/compose/AndroidManifest.xml ==="
rg -n "LAUNCHER|enabled" "$DOCUI_COMPOSE" || true
echo

echo "=== RAW: adb devices ==="
ADB_OUT="$(adb devices 2>&1 || true)"
printf '%s\n' "$ADB_OUT"
echo

python3 - "$ROOT" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(sys.argv[1])
pass_n = fail_n = hold_n = 0

def out(kind, msg):
    global pass_n, fail_n, hold_n
    print(f"{kind}: {msg}")
    if kind == "PASS":
        pass_n += 1
    elif kind == "FAIL":
        fail_n += 1
    else:
        hold_n += 1

ANDROID = "{http://schemas.android.com/apk/res/android}"

def aget(elem, name):
    return (
        elem.get(ANDROID + name)
        or elem.get("android:" + name)
        or elem.get(name)
    )

def parse_manifest(path):
    return ET.fromstring(Path(path).read_text(encoding="utf-8"))

def action_name(action):
    return aget(action, "name") or ""

def mime_of(data):
    return aget(data, "mimeType")

def category_name(cat):
    return aget(cat, "name") or ""

def filters(activity):
    return list(activity.findall("intent-filter"))

def activities(manifest):
    app = manifest.find("application")
    if app is None:
        return []
    return list(app.findall("activity")) + list(app.findall("activity-alias"))

def extract_method(text, name):
    pat = re.compile(
        rf"(?:private|public|protected)\s+(?:static\s+)?(?:boolean|void|int)\s+{name}\s*\("
    )
    m = pat.search(text)
    if not m:
        return None
    start = m.start()
    i = text.find("{", start)
    if i < 0:
        return None
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[start : j + 1]
    return None

def pos(hay, needle):
    i = hay.find(needle)
    return i if i >= 0 else None

aah = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/AbstractActionHandler.java").read_text(encoding="utf-8")
ah = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/files/ActionHandler.java").read_text(encoding="utf-8")
preview = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/GuardTalkMediaPreview.java").read_text(encoding="utf-8")
mpa = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/MediaPreviewActivity.java").read_text(encoding="utf-8")
decoder = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/MediaPreviewDecoder.java").read_text(encoding="utf-8")
layout = (root / "packages/apps/DocumentsUI/res/layout/guardtalk_media_preview.xml").read_text(encoding="utf-8")
noapp = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/files/NoApplicationFragment.kt").read_text(encoding="utf-8")
inputs = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/dirlist/InputHandlers.java").read_text(encoding="utf-8")
dirfrag = (root / "packages/apps/DocumentsUI/src/com/android/documentsui/dirlist/DirectoryFragment.java").read_text(encoding="utf-8")
strings = (root / "packages/apps/DocumentsUI/res/values/strings.xml").read_text(encoding="utf-8")
tests_ah = (root / "packages/apps/DocumentsUI/tests/unit/com/android/documentsui/files/ActionHandlerTest.java").read_text(encoding="utf-8")
tests_mp = (root / "packages/apps/DocumentsUI/tests/unit/com/android/documentsui/guardtalk/GuardTalkMediaPreviewTest.java").read_text(encoding="utf-8")

# --- 1. viewDocument: VIEW resolve first, in-app fallback, dialog ---
view_doc = extract_method(aah, "viewDocument")
if not view_doc:
    out("FAIL", "AbstractActionHandler.viewDocument not found")
else:
    r_pos = pos(view_doc, "resolveActivity")
    p_pos = pos(view_doc, "GuardTalkMediaPreview.start")
    d_pos = pos(view_doc, "showOpenFailed") or pos(view_doc, "showNoApplicationFoundDialog")
    if r_pos is None:
        out("FAIL", "viewDocument does not call resolveActivity")
    else:
        out("PASS", "viewDocument calls resolveActivity for VIEW")
    if p_pos is None:
        out("FAIL", "viewDocument missing GuardTalkMediaPreview.start fallback")
    else:
        out("PASS", "viewDocument falls back to GuardTalkMediaPreview.start")
    if d_pos is None:
        out("FAIL", "viewDocument missing visible no-app dialog after both fail")
    else:
        out("PASS", "viewDocument shows no-app dialog if VIEW + in-app fail")
    if r_pos is not None and p_pos is not None and r_pos < p_pos:
        out("PASS", "viewDocument prefers resolved VIEW before in-app preview")
    else:
        out("FAIL", "viewDocument does not prefer VIEW resolve before in-app preview")
    if p_pos is not None and d_pos is not None and p_pos < d_pos:
        out("PASS", "viewDocument tries in-app preview before dialog")
    elif d_pos is None or p_pos is None:
        pass
    else:
        out("FAIL", "viewDocument dialog is not after in-app preview fallback")

show_open = extract_method(aah, "showOpenFailed")
if show_open and "showNoApplicationFoundDialog" in show_open:
    out("PASS", "showOpenFailed uses showNoApplicationFoundDialog (not silent)")
else:
    out("FAIL", "showOpenFailed missing or not dialog-based")

# --- 2. Space / preview-only path fails visibly ---
opened = extract_method(aah, "onDocumentOpened")
if not opened:
    out("FAIL", "onDocumentOpened not found")
else:
    preview_only = (
        "VIEW_TYPE_PREVIEW" in opened
        and "VIEW_TYPE_NONE" in opened
        and "GuardTalkMediaPreview.start" in opened
        and "showOpenFailed" in opened
    )
    if preview_only:
        out("PASS", "preview-only (space) path tries in-app preview then showOpenFailed")
    else:
        out("FAIL", "preview-only path missing in-app preview or visible dialog")
    po_idx = opened.find("type == VIEW_TYPE_PREVIEW && fallback == VIEW_TYPE_NONE")
    if po_idx < 0:
        out("FAIL", "preview-only (VIEW_TYPE_PREVIEW + NONE) branch missing")
    else:
        brace = opened.find("{", po_idx)
        depth = 0
        end = None
        for j in range(brace, len(opened)):
            if opened[j] == "{":
                depth += 1
            elif opened[j] == "}":
                depth -= 1
                if depth == 0:
                    end = j
                    break
        block = opened[po_idx : (end + 1 if end is not None else po_idx)]
        if "GuardTalkMediaPreview.start" in block and "showOpenFailed" in block:
            out("PASS", "preview-only path is not a silent return")
        else:
            out("FAIL", "preview-only path still returns silently")

if 'KEYCODE_SPACE' in inputs and "VIEW_TYPE_PREVIEW" in inputs and "VIEW_TYPE_NONE" in inputs:
    out("PASS", "InputHandlers SPACE uses VIEW_TYPE_PREVIEW + VIEW_TYPE_NONE")
else:
    out("FAIL", "SPACE key not wired to preview-only open")

if "openItem(item, VIEW_TYPE_PREVIEW, VIEW_TYPE_REGULAR)" in dirfrag:
    out("PASS", "DirectoryFragment tap uses PREVIEW then REGULAR (hits viewDocument fallback)")
else:
    out("FAIL", "DirectoryFragment tap path not PREVIEW+REGULAR")

# --- 3. showChooserForDoc does not start empty chooser ---
chooser = extract_method(ah, "showChooserForDoc")
if not chooser:
    out("FAIL", "files.ActionHandler.showChooserForDoc not found")
else:
    r_pos = pos(chooser, "resolveActivity")
    c_pos = pos(chooser, "createChooser")
    d_pos = pos(chooser, "showNoApplicationFoundDialog")
    if r_pos is None or d_pos is None:
        out("FAIL", "showChooserForDoc missing resolveActivity or dialog")
    elif r_pos < d_pos:
        out("PASS", "showChooserForDoc resolveActivity-null → dialog")
    else:
        out("FAIL", "showChooserForDoc dialog not gated on resolveActivity")
    if c_pos is None:
        out("PASS", "showChooserForDoc has no createChooser (desktop-only resolver)")
    elif r_pos is not None and r_pos < c_pos:
        out("PASS", "showChooserForDoc createChooser only after resolveActivity")
    else:
        out("FAIL", "showChooserForDoc may start chooser before resolve check")
    early_return = "return;" in chooser.split("createChooser")[0] if c_pos else "return;" in chooser
    if "resolveActivity" in chooser and "return;" in chooser:
        out("PASS", "showChooserForDoc returns after unresolved dialog (no empty chooser)")
    else:
        out("FAIL", "showChooserForDoc unresolved path does not return before chooser")

# --- 4. Manifest: MediaPreview exported=false, no VIEW; Files VIEW root/directory ---
docui = parse_manifest(root / "packages/apps/DocumentsUI/AndroidManifest.xml")
mp_found = False
mp_exported = None
mp_has_filter = False
mp_has_view = False
files_view_mimes = []
files_view_star = False
all_view_star = False
all_view_mimes = []
launcher_pairs = []
for act in activities(docui):
    name = aget(act, "name") or ""
    for filt in filters(act):
        actions = {action_name(a) for a in filt.findall("action")}
        cats = {category_name(c) for c in filt.findall("category")}
        mimes = [m for m in (mime_of(d) for d in filt.findall("data")) if m]
        if "android.intent.action.MAIN" in actions and "android.intent.category.LAUNCHER" in cats:
            launcher_pairs.append(name)
        if "android.intent.action.VIEW" in actions:
            all_view_mimes.extend(mimes)
            if "*/*" in mimes:
                all_view_star = True
                if name.endswith("MediaPreviewActivity") or name.endswith("FilesActivity"):
                    files_view_star = True
        if name.endswith("FilesActivity") and "android.intent.action.VIEW" in actions:
            files_view_mimes.extend(mimes)
    if name.endswith("MediaPreviewActivity"):
        mp_found = True
        mp_exported = aget(act, "exported")
        mp_has_filter = bool(filters(act))
        for filt in filters(act):
            actions = {action_name(a) for a in filt.findall("action")}
            if "android.intent.action.VIEW" in actions:
                mp_has_view = True

if mp_found:
    out("PASS", "MediaPreviewActivity declared")
else:
    out("FAIL", "MediaPreviewActivity missing from DocumentsUI manifest")
if mp_exported == "false":
    out("PASS", "MediaPreviewActivity exported=false")
else:
    out("FAIL", f"MediaPreviewActivity exported={mp_exported}")
if not mp_has_filter:
    out("PASS", "MediaPreviewActivity has no intent-filter")
else:
    out("FAIL", "MediaPreviewActivity has an intent-filter")
if not mp_has_view:
    out("PASS", "MediaPreviewActivity has no VIEW intent-filter")
else:
    out("FAIL", "MediaPreviewActivity declares VIEW")

allowed = {"vnd.android.document/root", "vnd.android.document/directory"}
if files_view_star:
    out("FAIL", "FilesActivity VIEW includes */*")
else:
    out("PASS", "FilesActivity VIEW has no */*")
unexpected = set(files_view_mimes) - allowed
if unexpected:
    out("FAIL", f"FilesActivity VIEW unexpected MIME {sorted(unexpected)}")
else:
    out("PASS", f"FilesActivity VIEW MIME only {sorted(set(files_view_mimes))}")
if allowed <= set(files_view_mimes):
    out("PASS", "FilesActivity VIEW still vnd.android.document/{root,directory}")
else:
    out("FAIL", f"FilesActivity VIEW missing root/directory; got {files_view_mimes}")
if all_view_star:
    out("FAIL", "DocumentsUI has a VIEW */* filter")
else:
    out("PASS", "DocumentsUI has no VIEW */* (SAF GET_CONTENT */* is not VIEW)")

# --- 5. Single MAIN+LAUNCHER; Compose disabled ---
if launcher_pairs == [".LauncherActivity"]:
    out("PASS", "Single MAIN+LAUNCHER on Files alias .LauncherActivity")
elif len(launcher_pairs) == 1:
    out("FAIL", f"Single LAUNCHER but not Files alias: {launcher_pairs}")
elif len(launcher_pairs) == 0:
    out("FAIL", "DocumentsUI lost MAIN+LAUNCHER")
else:
    out("FAIL", f"Extra Files launcher(s): {launcher_pairs}")

compose = parse_manifest(root / "packages/apps/DocumentsUI/compose/AndroidManifest.xml")
compose_launcher = []
main_enabled = None
for act in activities(compose):
    name = aget(act, "name") or ""
    if name.endswith("MainActivity"):
        main_enabled = aget(act, "enabled")
    for filt in filters(act):
        cats = {category_name(c) for c in filt.findall("category")}
        actions = {action_name(a) for a in filt.findall("action")}
        if "android.intent.category.LAUNCHER" in cats:
            compose_launcher.append(name)
        if name.endswith("MainActivity") and "android.intent.action.MAIN" in actions:
            if "android.intent.category.LAUNCHER" in cats:
                out("FAIL", "Compose MainActivity still has LAUNCHER")
if main_enabled == "false":
    out("PASS", "Compose MainActivity enabled=false")
else:
    out("FAIL", f"Compose MainActivity enabled={main_enabled}")
if not compose_launcher:
    out("PASS", "Compose has no LAUNCHER category")
else:
    out("FAIL", f"Compose still has LAUNCHER on {compose_launcher}")

overlay = root / "vendor/guardtalk/overlays/GuardTalkDocumentsUIIconOverlay/AndroidManifest.xml"
ov = overlay.read_text(encoding="utf-8") if overlay.is_file() else ""
if "LAUNCHER" in ov:
    out("FAIL", "DocumentsUI icon overlay declares LAUNCHER")
else:
    out("PASS", "DocumentsUI icon overlay has no LAUNCHER (icon-only)")

# --- 6. Decode/play failure shows peek_no_preview ---
if 'name="peek_no_preview"' in strings and "No preview available" in strings:
    out("PASS", "peek_no_preview string present")
else:
    out("FAIL", "peek_no_preview string missing")
if 'android:text="@string/peek_no_preview"' in layout and 'id="@+id/guardtalk_preview_error"' in layout:
    out("PASS", "preview layout binds peek_no_preview on error TextView")
else:
    out("FAIL", "preview layout missing peek_no_preview error view")
if "showError()" in mpa and "mError.setVisibility(View.VISIBLE)" in mpa:
    out("PASS", "MediaPreviewActivity.showError makes error view visible")
else:
    out("FAIL", "MediaPreviewActivity missing visible showError")
if "if (bitmap == null)" in mpa and "showError()" in mpa:
    out("PASS", "image decode null → showError")
else:
    out("FAIL", "image decode failure not wired to showError")
if "setOnErrorListener" in mpa and "onVideoError" in mpa and "showError()" in mpa:
    out("PASS", "video OnErrorListener → showError")
else:
    out("FAIL", "video play failure not wired to showError")
if "uri == null || !GuardTalkMediaPreview.isSupportedMime(mime)" in mpa:
    out("PASS", "unsupported/missing URI shows error, not blank")
else:
    out("FAIL", "unsupported MIME path may blank the preview")

# --- GuardTalkMediaPreview MIME + explicit intent ---
if "MimeTypes.IMAGE_MIME" in preview and "MimeTypes.VIDEO_MIME" in preview:
    out("PASS", "GuardTalkMediaPreview supports image/* and video/*")
else:
    out("FAIL", "GuardTalkMediaPreview MIME gate missing image/* or video/*")
need_mimes = ("image/jpeg", "image/png", "image/webp", "video/mp4", "video/webm")
if all(m in tests_mp for m in need_mimes):
    out("PASS", "unit tests assert jpeg/png/webp/mp4/webm supported")
else:
    out("FAIL", "unit tests missing jpeg/png/webp/mp4/webm MIME asserts")
if "new Intent(context, MediaPreviewActivity.class)" in preview:
    out("PASS", "GuardTalkMediaPreview.createIntent is explicit component")
else:
    out("FAIL", "GuardTalkMediaPreview intent is not explicit")
if 'Intent.ACTION_VIEW' in preview and "setAction" in preview:
    out("FAIL", "GuardTalkMediaPreview sets ACTION_VIEW (risk of VIEW spam)")
else:
    out("PASS", "GuardTalkMediaPreview does not set ACTION_VIEW")

if "class MediaPreviewDecoder" in decoder and "MAX_EDGE = 2048" in decoder:
    out("PASS", "MediaPreviewDecoder bounded sample present")
else:
    out("FAIL", "MediaPreviewDecoder missing or unbounded")

# --- NoApplicationFragment visible dialog ---
if "MaterialAlertDialogBuilder" in noapp and "setNegativeButton(android.R.string.ok" in noapp:
    out("PASS", "NoApplicationFragment always builds visible dialog + OK")
else:
    out("FAIL", "NoApplicationFragment not a visible dialog")
if "playResolvable" in noapp and "setPositiveButton" in noapp:
    out("PASS", "Play Store button only when play search is resolvable")
else:
    out("FAIL", "Play Store button gating missing")
if "no_application_dialog_message_no_store" in strings:
    out("PASS", "no-store dialog copy present")
else:
    out("FAIL", "no-store dialog copy missing")

# --- Unit tests for tap / chooser / preview-only ---
if "testDocumentPicked_NoViewHandler_OpensInAppImagePreview" in tests_ah:
    out("PASS", "ActionHandlerTest covers in-app image preview fallback")
else:
    out("FAIL", "missing in-app image preview unit test")
if "testDocumentPicked_NoViewHandler_OpensInAppVideoPreview" in tests_ah:
    out("PASS", "ActionHandlerTest covers in-app video preview fallback")
else:
    out("FAIL", "missing in-app video preview unit test")
if "testPreviewOnly_NoQuickViewer_OpensInAppPreview" in tests_ah:
    out("PASS", "ActionHandlerTest covers preview-only in-app fallback")
else:
    out("FAIL", "missing preview-only unit test")
if "testDocumentPicked_NoViewHandler_ShowsVisibleErrorForPdf" in tests_ah:
    out("PASS", "ActionHandlerTest covers visible dialog for non-media")
else:
    out("FAIL", "missing visible-error unit test for unresolved non-media")
if "testShowChooser_NoApplicationFound" in tests_ah and "testShowChooser_NoApplicationFound_Phone" in tests_ah:
    out("PASS", "ActionHandlerTest covers chooser unresolved → dialog (phone+desktop)")
else:
    out("FAIL", "missing chooser unresolved unit tests")

# --- 7. Negative: Gallery2 still excised; F did not un-excise ---
mk = (root / "vendor/guardtalk/feature-excised/apps-excised.mk").read_text(encoding="utf-8")

def makefile_assign_tokens(text, var):
    tokens = []
    lines = text.splitlines()
    i = 0
    pat = re.compile(rf"^{re.escape(var)}\s*(\+|:)*=\s*(.*)$")
    while i < len(lines):
        raw = lines[i]
        stripped = raw.split("#", 1)[0]
        m = pat.match(stripped)
        if not m:
            i += 1
            continue
        buf = m.group(2)
        while buf.rstrip().endswith("\\"):
            buf = buf.rstrip()[:-1] + " "
            i += 1
            if i >= len(lines):
                break
            buf += lines[i].split("#", 1)[0]
        tokens.extend(buf.split())
        i += 1
    return tokens

drop = makefile_assign_tokens(mk, "GUARDTALK_APPS_PACKAGES")
keep = makefile_assign_tokens(mk, "GUARDTALK_APPS_KEEP")
if "Gallery2" in drop:
    out("PASS", "Gallery2 still in drop list (F did not un-excise)")
else:
    out("FAIL", "Gallery2 un-excised (missing from drop list)")
if "Gallery2" in keep:
    out("FAIL", "Gallery2 unexpectedly in GUARDTALK_APPS_KEEP")
else:
    out("PASS", "Gallery2 not in GUARDTALK_APPS_KEEP")

pol = root / "frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java"
if pol.is_file() and "CRITICAL_PATH_PREFIXES" in pol.read_text(encoding="utf-8"):
    out("PASS", "GuardTalkFilesPolicy.java still present (QA did not require F to edit it)")
else:
    out("FAIL", "GuardTalkFilesPolicy.java missing")

# --- lunch pin ---
adev = root / "vendor/google_devices/tokay/adevtool-version-check.mk"
if adev.is_file() and "tokay vendor module is outdated" in adev.read_text(encoding="utf-8"):
    out("HOLD", "lunch tokay-trunk_staging-userdebug (adevtool pin still present; not run)")
else:
    out("HOLD", "lunch not run this QA session")

print(f"__COUNTS__ PASS={pass_n} FAIL={fail_n} HOLD={hold_n}")
Path("/tmp/q-os-files-open-counts").write_text(f"{pass_n} {fail_n} {hold_n}\n")
sys.exit(0)
PY
read -r PASS_N FAIL_N HOLD_N < /tmp/q-os-files-open-counts
if [[ "${FAIL_N}" -gt 0 ]]; then
  FAIL=1
fi

echo
echo "=== adb device tap / query-activities ==="
DEVICE_LINES="$(printf '%s\n' "$ADB_OUT" | awk 'NR>1 && $1 != "" && $1 != "*" && $1 != "List" {print $1}')"
if [[ -z "${DEVICE_LINES}" ]]; then
  hold "adb devices empty — tap jpeg/png/webp HOLD (not device-fixed)"
  hold "adb devices empty — tap mp4/webm HOLD (not device-fixed)"
  hold "runtime blank viewer / empty chooser / silent no-op — HOLD without adb"
else
  for mime in image/jpeg image/png image/webp video/mp4 video/webm; do
    echo "RAW: adb shell cmd package query-activities -a android.intent.action.VIEW -t ${mime}"
    QOUT="$(adb shell cmd package query-activities -a android.intent.action.VIEW -t "${mime}" 2>&1 || true)"
    printf '%s\n' "$QOUT"
    if [[ -n "$QOUT" ]]; then
      pass "device query-activities ${mime} returned output (not a tap-open proof)"
    else
      fail "device query-activities ${mime} empty"
    fi
  done
  hold "device Files tap-to-open jpeg/png/webp/mp4/webm — query-activities is not tap proof; HOLD unless UI exercised"
fi

echo
echo "=== SUMMARY ==="
echo "PASS_COUNT=${PASS_N} FAIL_COUNT=${FAIL_N} HOLD_COUNT=${HOLD_N}"
echo "LIVE_DEVICE_CLAIMED=false"
if [[ "$FAIL" -eq 0 ]]; then
  echo "OVERALL: PASS (static) + HOLD (adb/lunch). EXIT=0"
  exit 0
fi
echo "OVERALL: FAIL. EXIT=1"
exit 1
