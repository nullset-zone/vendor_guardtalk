#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B3-VIEWER (item 18).
# Pair of T-REMEDIATE-B3-VIEWER + F-REMEDIATE-B3-VIEWER.
# Do not trust Backend / Frontend / Architect reports.
# Host static + lunch. Device query-activities HOLD if adb empty.
# Do NOT fold OS-UX on-device proof (Q-REMEDIATE-B3-OSUX-DEVICE, BLOCKED).
# No product edits. No USB GO. No wipe. No commit. Never APPROVED.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b3_viewer_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
FAIL_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; FAIL_N=$((FAIL_N + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

HTML_MF="packages/apps/HTMLViewer/AndroidManifest.xml"
HTML_JAVA="packages/apps/HTMLViewer/src/com/android/htmlviewer/HTMLViewerActivity.java"
DOCUI_MF="packages/apps/DocumentsUI/AndroidManifest.xml"
AAH="packages/apps/DocumentsUI/src/com/android/documentsui/AbstractActionHandler.java"
HTML_LAUNCH="packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/GuardTalkHtmlViewerLaunch.java"
MPA="packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/MediaPreviewActivity.java"
MP_HELPER="packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/GuardTalkMediaPreview.java"
AH_TEST="packages/apps/DocumentsUI/tests/unit/com/android/documentsui/files/ActionHandlerTest.java"
HTML_LAUNCH_TEST="packages/apps/DocumentsUI/tests/unit/com/android/documentsui/guardtalk/GuardTalkHtmlViewerLaunchTest.java"
NOAPP="packages/apps/DocumentsUI/src/com/android/documentsui/files/NoApplicationFragment.kt"
EXCISED="vendor/guardtalk/feature-excised/apps-excised.mk"
VAL_MF="vendor/guardtalk/apps/GuardTalkValidator/AndroidManifest.xml"
VAL_ACT="vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/ValidatorActivity.kt"
VAL_HTML="vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/HtmlViewerLaunch.kt"
VAL_PROV="vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SampleImageProvider.kt"
VAL_MENU="vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/EscapeMenu.kt"
VAL_MENU_XML="vendor/guardtalk/apps/GuardTalkValidator/res/layout/escape_menu.xml"
VAL_LAY="vendor/guardtalk/apps/GuardTalkValidator/res/layout/activity_validator.xml"
VAL_STR="vendor/guardtalk/apps/GuardTalkValidator/res/values/strings.xml"
VAL_PNG="vendor/guardtalk/apps/GuardTalkValidator/res/raw/sample_image.png"

echo "=== Q-REMEDIATE-B3-VIEWER independent rematch (item 18) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-REMEDIATE-B3-OSUX-DEVICE=not started (BLOCKED; not folded here)"
echo "USB_GO=not started"
echo "T/F reports: not trusted"
echo

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

echo "--- required files ---"
require_file "$HTML_MF"
require_file "$HTML_JAVA"
require_file "$DOCUI_MF"
require_file "$AAH"
require_file "$HTML_LAUNCH"
require_file "$MPA"
require_file "$MP_HELPER"
require_file "$AH_TEST"
require_file "$HTML_LAUNCH_TEST"
require_file "$NOAPP"
require_file "$EXCISED"
require_file "$VAL_MF"
require_file "$VAL_ACT"
require_file "$VAL_HTML"
require_file "$VAL_PROV"
require_file "$VAL_MENU"
require_file "$VAL_MENU_XML"
require_file "$VAL_LAY"
require_file "$VAL_STR"
require_file "$VAL_PNG"

if [[ -d "vendor/guardtalk/apps/ImageViewer" ]]; then
  fail "second gallery: vendor/guardtalk/apps/ImageViewer exists"
else
  pass "vendor/guardtalk/apps/ImageViewer ABSENT (no priv-app gallery)"
fi

echo
echo "--- packet rg (HTMLViewer VIEW jpeg/png/webp) ---"
rg -n "image/jpeg|image/png|image/webp|LAUNCHER|ACTION_VIEW" "$HTML_MF" || true
echo
echo "--- packet rg (DocumentsUI MediaPreview / viewDocument / HTMLViewer) ---"
rg -n "MediaPreview|HTMLViewer|image/jpeg|ACTION_VIEW|viewDocument|showNoApplication|showOpenFailed" \
  "$DOCUI_MF" "$AAH" "$HTML_LAUNCH" "$MPA" || true
echo
echo "--- packet rg (Validator HtmlViewerLaunch / sample / EscapeMenu) ---"
rg -n "HtmlViewerLaunch|SampleImageProvider|sample_image|AlertDialog|EscapeMenu|ACTION_VIEW|image/jpeg" \
  "$VAL_MF" "$VAL_ACT" "$VAL_HTML" "$VAL_PROV" "$VAL_MENU" "$VAL_MENU_XML" "$VAL_LAY" "$VAL_STR" || true
echo
echo "--- packet rg (Gallery2 / HTMLViewer KEEP / ImageViewer) ---"
rg -n "Gallery2|HTMLViewer|ImageViewer|GUARDTALK_APPS_KEEP|GUARDTALK_APPS_PACKAGES" "$EXCISED" || true
echo

echo "--- python structural rematch ---"
set +e
python3 - "$ROOT" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(sys.argv[1])
fail = 0
pass_n = 0
hold_n = 0

def out(kind, msg):
    global fail, pass_n, hold_n
    print(f"{kind}: {msg}")
    if kind == "PASS":
        pass_n += 1
    elif kind == "FAIL":
        fail = 1
    else:
        hold_n += 1

def read(rel):
    p = root / rel
    if not p.is_file():
        out("FAIL", f"unreadable {rel}")
        return ""
    return p.read_text(encoding="utf-8", errors="replace")

ANDROID = "{http://schemas.android.com/apk/res/android}"

def aget(elem, name):
    return (
        elem.get(ANDROID + name)
        or elem.get("android:" + name)
        or elem.get(name)
    )

def parse_manifest(rel):
    text = read(rel)
    if not text:
        return None
    return ET.fromstring(text)

def activities(manifest):
    app = manifest.find("application")
    if app is None:
        return []
    return list(app.findall("activity")) + list(app.findall("activity-alias"))

def providers(manifest):
    app = manifest.find("application")
    if app is None:
        return []
    return list(app.findall("provider"))

def extract_method(text, name):
    pat = re.compile(
        rf"(?:private|public|protected)\s+(?:static\s+)?(?:boolean|void|int)\s+{re.escape(name)}\s*\("
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

# --- HTMLViewer VIEW jpeg/png/webp ---
html_mf = parse_manifest("packages/apps/HTMLViewer/AndroidManifest.xml")
if html_mf is None:
    out("FAIL", "HTMLViewer AndroidManifest unreadable")
else:
    found_jpeg = found_png = found_webp = False
    found_launcher = False
    found_image_star = False
    found_star_star = False
    schemes = set()
    view_mimes = set()
    for act in activities(html_mf):
        exported = aget(act, "exported")
        for filt in act.findall("intent-filter"):
            actions = {aget(a, "name") or "" for a in filt.findall("action")}
            cats = {aget(c, "name") or "" for c in filt.findall("category")}
            if "android.intent.category.LAUNCHER" in cats:
                found_launcher = True
            if "android.intent.action.VIEW" not in actions:
                continue
            for d in filt.findall("data"):
                mime = aget(d, "mimeType")
                scheme = aget(d, "scheme")
                if mime:
                    view_mimes.add(mime)
                if scheme:
                    schemes.add(scheme)
                if mime == "image/jpeg":
                    found_jpeg = True
                if mime == "image/png":
                    found_png = True
                if mime == "image/webp":
                    found_webp = True
                if mime == "image/*":
                    found_image_star = True
                if mime == "*/*":
                    found_star_star = True
        if aget(act, "name") in ("HTMLViewerActivity", ".HTMLViewerActivity"):
            if exported == "true":
                out("PASS", "HTMLViewerActivity exported=true (VIEW handler, not a gallery)")
            else:
                out("FAIL", f"HTMLViewerActivity exported={exported} (VIEW must be exported)")
    if found_jpeg and found_png and found_webp:
        out("PASS", "HTMLViewer VIEW filters include image/jpeg + image/png + image/webp")
    else:
        out(
            "FAIL",
            f"HTMLViewer missing still-image VIEW (jpeg={found_jpeg} png={found_png} webp={found_webp})",
        )
    if "content" in schemes and "file" in schemes:
        out("PASS", "HTMLViewer image VIEW schemes include content + file")
    else:
        out("FAIL", f"HTMLViewer image VIEW schemes={sorted(schemes)} (need content+file)")
    if found_launcher:
        out("FAIL", "HTMLViewer has LAUNCHER (second gallery)")
    else:
        out("PASS", "HTMLViewer has no LAUNCHER")
    if found_image_star:
        out("FAIL", "HTMLViewer VIEW includes image/*")
    else:
        out("PASS", "HTMLViewer VIEW does not include image/*")
    if found_star_star:
        out("FAIL", "HTMLViewer VIEW includes */*")
    else:
        out("PASS", "HTMLViewer VIEW does not include */*")

html_java = read("packages/apps/HTMLViewer/src/com/android/htmlviewer/HTMLViewerActivity.java")
if "setJavaScriptEnabled(false)" in html_java:
    out("PASS", "HTMLViewer JavaScript disabled")
else:
    out("FAIL", "HTMLViewer JavaScript not disabled")
if "setBlockNetworkLoads(true)" in html_java:
    out("PASS", "HTMLViewer network loads blocked")
else:
    out("FAIL", "HTMLViewer network loads not blocked")

# --- DocumentsUI MediaPreviewActivity exported=false, no VIEW ---
docui = parse_manifest("packages/apps/DocumentsUI/AndroidManifest.xml")
if docui is None:
    out("FAIL", "DocumentsUI AndroidManifest unreadable")
else:
    found_mp = False
    for act in activities(docui):
        name = aget(act, "name") or ""
        if name.endswith("MediaPreviewActivity"):
            found_mp = True
            exported = aget(act, "exported")
            if exported == "false":
                out("PASS", "MediaPreviewActivity exported=false")
            else:
                out("FAIL", f"MediaPreviewActivity exported={exported} (must be false)")
            filters = list(act.findall("intent-filter"))
            view_in_mp = False
            for filt in filters:
                actions = {aget(a, "name") or "" for a in filt.findall("action")}
                if "android.intent.action.VIEW" in actions:
                    view_in_mp = True
            if view_in_mp:
                out("FAIL", "MediaPreviewActivity has VIEW intent-filter (system gallery)")
            else:
                out("PASS", "MediaPreviewActivity has no VIEW intent-filter (in-app only)")
            if filters:
                out("FAIL", f"MediaPreviewActivity has {len(filters)} intent-filter(s)")
            else:
                out("PASS", "MediaPreviewActivity has no intent-filters")
    if not found_mp:
        out("FAIL", "MediaPreviewActivity missing from DocumentsUI manifest")

# --- viewDocument order: HTMLViewer VIEW → generic VIEW → MediaPreview → dialog ---
aah = read("packages/apps/DocumentsUI/src/com/android/documentsui/AbstractActionHandler.java")
view_doc = extract_method(aah, "viewDocument")
if not view_doc:
    out("FAIL", "AbstractActionHandler.viewDocument not found")
else:
    html_p = pos(view_doc, "GuardTalkHtmlViewerLaunch.start")
    resolve_p = pos(view_doc, "intent.resolveActivity")
    preview_p = pos(view_doc, "GuardTalkMediaPreview.start")
    dialog_p = pos(view_doc, "showOpenFailed")
    if html_p is None:
        out("FAIL", "viewDocument does not call GuardTalkHtmlViewerLaunch.start first")
    else:
        out("PASS", "viewDocument calls GuardTalkHtmlViewerLaunch.start")
    if resolve_p is None:
        out("FAIL", "viewDocument missing generic VIEW resolveActivity")
    else:
        out("PASS", "viewDocument generic VIEW resolveActivity present")
    if preview_p is None:
        out("FAIL", "viewDocument missing in-app GuardTalkMediaPreview.start")
    else:
        out("PASS", "viewDocument in-app MediaPreview fallback present")
    if dialog_p is None:
        out("FAIL", "viewDocument missing showOpenFailed (silent fail risk)")
    else:
        out("PASS", "viewDocument calls showOpenFailed (visible dialog)")
    if None not in (html_p, resolve_p, preview_p, dialog_p):
        if html_p < resolve_p < preview_p < dialog_p:
            out(
                "PASS",
                "viewDocument order: HTMLViewer VIEW → generic VIEW → MediaPreview → dialog",
            )
        else:
            out(
                "FAIL",
                f"viewDocument order wrong html={html_p} resolve={resolve_p} preview={preview_p} dialog={dialog_p}",
            )
    # never return after failed preview without dialog
    after_preview = view_doc[preview_p:] if preview_p is not None else ""
    if preview_p is not None and "showOpenFailed" in after_preview:
        out("PASS", "viewDocument shows dialog if MediaPreview does not start")
    elif preview_p is not None:
        out("FAIL", "viewDocument may return after MediaPreview miss without dialog")

show_failed = extract_method(aah, "showOpenFailed")
if show_failed and "showNoApplicationFoundDialog" in show_failed:
    out("PASS", "showOpenFailed uses showNoApplicationFoundDialog (visible, not toast-only)")
else:
    out("FAIL", "showOpenFailed missing showNoApplicationFoundDialog")

# silent-fail guard: viewDocument must not end with bare return true after preview miss
if view_doc and re.search(
    r"GuardTalkMediaPreview\.start\(.*?\).*?return true;\s*\}?\s*$",
    view_doc,
    re.S,
):
    out("FAIL", "viewDocument may silently succeed without dialog after preview")
else:
    out("PASS", "viewDocument does not silently succeed after MediaPreview miss")

# --- GuardTalkHtmlViewerLaunch contract ---
html_launch = read(
    "packages/apps/DocumentsUI/src/com/android/documentsui/guardtalk/GuardTalkHtmlViewerLaunch.java"
)
if 'MIME_JPEG = "image/jpeg"' in html_launch and 'MIME_PNG = "image/png"' in html_launch and 'MIME_WEBP = "image/webp"' in html_launch:
    out("PASS", "GuardTalkHtmlViewerLaunch still-image MIME jpeg/png/webp")
else:
    out("FAIL", "GuardTalkHtmlViewerLaunch still-image MIME set incomplete")
def strip_comments_code(src):
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"//.*?$", "", src, flags=re.M)
    return src

html_launch_code = strip_comments_code(html_launch)
if "image/*" in html_launch_code or '"*/*"' in html_launch_code:
    out("FAIL", "GuardTalkHtmlViewerLaunch live code uses image/* or */*")
else:
    out("PASS", "GuardTalkHtmlViewerLaunch live code does not use image/* or */* (javadoc negatives ignored)")
if 'HTMLVIEWER_PACKAGE = "com.android.htmlviewer"' in html_launch and "HTMLViewerActivity" in html_launch:
    out("PASS", "GuardTalkHtmlViewerLaunch explicit HTMLViewer component")
else:
    out("FAIL", "GuardTalkHtmlViewerLaunch missing explicit HTMLViewer component")
if "Intent.ACTION_VIEW" in html_launch and "setClassName" in html_launch:
    out("PASS", "GuardTalkHtmlViewerLaunch ACTION_VIEW + setClassName")
else:
    out("FAIL", "GuardTalkHtmlViewerLaunch missing ACTION_VIEW / setClassName")
if "FLAG_GRANT_READ_URI_PERMISSION" in html_launch:
    out("PASS", "GuardTalkHtmlViewerLaunch grants read URI permission")
else:
    out("FAIL", "GuardTalkHtmlViewerLaunch missing FLAG_GRANT_READ_URI_PERMISSION")

# --- Validator HtmlViewerLaunch + AlertDialog ---
val_html = read(
    "vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/HtmlViewerLaunch.kt"
)
if 'mime == "image/jpeg"' in val_html and 'mime == "image/png"' in val_html and 'mime == "image/webp"' in val_html:
    out("PASS", "Validator HtmlViewerLaunch still-image MIME jpeg/png/webp")
else:
    out("FAIL", "Validator HtmlViewerLaunch still-image MIME set incomplete")
if "image/*" in val_html or '"*/*"' in val_html:
    out("FAIL", "Validator HtmlViewerLaunch uses image/* or */*")
else:
    out("PASS", "Validator HtmlViewerLaunch does not use image/* or */*")
if 'HTMLVIEWER_PACKAGE = "com.android.htmlviewer"' in val_html and "HTMLViewerActivity" in val_html:
    out("PASS", "Validator HtmlViewerLaunch explicit HTMLViewer component")
else:
    out("FAIL", "Validator HtmlViewerLaunch missing explicit HTMLViewer component")
if "Intent.ACTION_VIEW" in val_html and "setClassName" in val_html:
    out("PASS", "Validator HtmlViewerLaunch ACTION_VIEW + setClassName")
else:
    out("FAIL", "Validator HtmlViewerLaunch missing ACTION_VIEW / setClassName")
if "openSampleOrExplain" in val_html and "AlertDialog.Builder" in val_html:
    out("PASS", "Validator HtmlViewerLaunch openSampleOrExplain uses AlertDialog on fail")
else:
    out("FAIL", "Validator HtmlViewerLaunch missing AlertDialog on sample-open fail")
if "SampleImageProvider.SAMPLE_URI" in val_html and "SampleImageProvider.MIME_PNG" in val_html:
    out("PASS", "Validator sample path uses SampleImageProvider PNG URI")
else:
    out("FAIL", "Validator sample path missing SampleImageProvider PNG URI")
if "setPositiveButton" in val_html:
    out("PASS", "Validator fail dialog has a positive button (visible, not silent)")
else:
    out("FAIL", "Validator fail dialog missing positive button")

val_act = read(
    "vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/ValidatorActivity.kt"
)
if "btn_open_sample_image" in val_act and "HtmlViewerLaunch.openSampleOrExplain" in val_act:
    out("PASS", "ValidatorActivity main-path sample PNG via HtmlViewerLaunch")
else:
    out("FAIL", "ValidatorActivity missing main-path HtmlViewerLaunch sample open")
if "EscapeMenu" in val_act and "openSampleOrExplain" in val_act:
    # activity may mention neither together; EscapeMenu is chrome, sample is main path
    pass
if re.search(r"EscapeMenu.*openSample|openSample.*EscapeMenu", val_act):
    out("FAIL", "ValidatorActivity wires sample open onto EscapeMenu")
else:
    out("PASS", "ValidatorActivity sample open is not on EscapeMenu")

val_lay = read("vendor/guardtalk/apps/GuardTalkValidator/res/layout/activity_validator.xml")
if 'android:id="@+id/btn_open_sample_image"' in val_lay:
    out("PASS", "activity_validator.xml has main-path btn_open_sample_image")
else:
    out("FAIL", "activity_validator.xml missing btn_open_sample_image")
if "sample_image_open_cd" in val_lay:
    out("PASS", "sample image button has contentDescription")
else:
    out("FAIL", "sample image button missing contentDescription")

val_str = read("vendor/guardtalk/apps/GuardTalkValidator/res/values/strings.xml")
if "sample_image_failed_title" in val_str and "sample_image_failed_message" in val_str:
    out("PASS", "Validator fail copy present (not silent)")
else:
    out("FAIL", "Validator fail strings missing")

# --- EscapeMenu must NOT contain sample-image ---
val_menu = read(
    "vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/EscapeMenu.kt"
)
menu_hits = []
for token in (
    "sample_image",
    "HtmlViewerLaunch",
    "SampleImageProvider",
    "btn_open_sample_image",
    "openSampleOrExplain",
):
    if token in val_menu:
        menu_hits.append(token)
if menu_hits:
    out("FAIL", f"EscapeMenu.kt contains sample-image tokens: {menu_hits}")
else:
    out("PASS", "EscapeMenu.kt has no sample-image item")

menu_xml = read("vendor/guardtalk/apps/GuardTalkValidator/res/layout/escape_menu.xml")
xml_hits = []
for token in ("sample_image", "btn_open_sample_image", "HtmlViewer"):
    if token in menu_xml:
        xml_hits.append(token)
if xml_hits:
    out("FAIL", f"escape_menu.xml contains sample-image tokens: {xml_hits}")
else:
    out("PASS", "escape_menu.xml has no sample-image item")

# EscapeMenu still has Settings / sensors / status (do not fight F-VALIDATOR)
if "menu_open_settings" in val_menu and "SensorToggleViews.bind" in val_menu and "menu_device_status" in val_menu:
    out("PASS", "EscapeMenu still Settings / cam-mic / status (F-VALIDATOR not fought)")
else:
    out("FAIL", "EscapeMenu missing Settings / cam-mic / status (regressed F-VALIDATOR)")

# --- SampleImageProvider exported=false ---
val_mf = parse_manifest("vendor/guardtalk/apps/GuardTalkValidator/AndroidManifest.xml")
if val_mf is None:
    out("FAIL", "Validator AndroidManifest unreadable")
else:
    found_prov = False
    for prov in providers(val_mf):
        name = aget(prov, "name") or ""
        if name.endswith("SampleImageProvider"):
            found_prov = True
            exported = aget(prov, "exported")
            grant = aget(prov, "grantUriPermissions")
            auth = aget(prov, "authorities")
            if exported == "false":
                out("PASS", "SampleImageProvider exported=false")
            else:
                out("FAIL", f"SampleImageProvider exported={exported} (must be false)")
            if grant == "true":
                out("PASS", "SampleImageProvider grantUriPermissions=true (grant-only)")
            else:
                out("FAIL", f"SampleImageProvider grantUriPermissions={grant}")
            if auth == "com.guardtalk.validator.sampleimage":
                out("PASS", "SampleImageProvider authority matches SAMPLE_URI")
            else:
                out("FAIL", f"SampleImageProvider authority={auth}")
    if not found_prov:
        out("FAIL", "SampleImageProvider missing from Validator manifest")
    queries = list(val_mf.findall("queries"))
    q_text = ET.tostring(val_mf, encoding="unicode")
    if "com.android.htmlviewer" in q_text:
        out("PASS", "Validator queries HTMLViewer package")
    else:
        out("FAIL", "Validator missing <queries> for HTMLViewer")
    for mime in ("image/jpeg", "image/png", "image/webp"):
        if mime in q_text:
            out("PASS", f"Validator queries VIEW {mime}")
        else:
            out("FAIL", f"Validator missing VIEW query for {mime}")
    if "image/*" in q_text.split("queries")[-1] if "queries" in q_text else "":
        out("FAIL", "Validator queries image/*")
    else:
        out("PASS", "Validator queries do not use image/*")

prov_kt = read(
    "vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SampleImageProvider.kt"
)
if "MODE_READ_ONLY" in prov_kt and "openRawResource" in prov_kt:
    out("PASS", "SampleImageProvider grant-only read of sample PNG")
else:
    out("FAIL", "SampleImageProvider missing read-only sample PNG open")
if re.search(r"fun insert[\s\S]*?=\s*null", prov_kt) and re.search(
    r"fun delete[\s\S]*?=\s*0", prov_kt
):
    out("PASS", "SampleImageProvider insert/delete are no-ops (not a gallery store)")
else:
    out("FAIL", "SampleImageProvider insert/delete not no-ops")

png = root / "vendor/guardtalk/apps/GuardTalkValidator/res/raw/sample_image.png"
if png.is_file():
    magic = png.read_bytes()[:8]
    if magic == b"\x89PNG\r\n\x1a\n":
        out("PASS", "sample_image.png is a PNG (magic 89 50 4E 47)")
    else:
        out("FAIL", f"sample_image.png magic={magic.hex()} (not PNG)")
    if png.stat().st_size > 0:
        out("PASS", f"sample_image.png size={png.stat().st_size} bytes")
    else:
        out("FAIL", "sample_image.png empty")
else:
    out("FAIL", "sample_image.png missing")

# --- Gallery2 still excised; no ImageViewer; KEEP HTMLViewer ---
excised = read("vendor/guardtalk/feature-excised/apps-excised.mk")

def mk_list(src, name):
    m = re.search(rf"^{re.escape(name)}\s*:=(.*?)(?=^[A-Z_][A-Z0-9_]*\s*[+:]?=|\Z)", src, re.M | re.S)
    if not m:
        return []
    body = m.group(1)
    body = re.sub(r"#.*", "", body)
    return [t.strip(" \t\\") for t in body.split() if t.strip(" \t\\")]

keep = mk_list(excised, "GUARDTALK_APPS_KEEP")
# drop list is built via several += ; collect all assignment bodies
drop_tokens = []
for m in re.finditer(
    r"^GUARDTALK_APPS_PACKAGES\s*\+?=\s*(.*?)(?=^[A-Z_][A-Z0-9_]*\s*[+:]?=|\Z)",
    excised,
    re.M | re.S,
):
    body = re.sub(r"#.*", "", m.group(1))
    drop_tokens.extend(t.strip(" \t\\") for t in body.split() if t.strip(" \t\\"))

if "HTMLViewer" in keep:
    out("PASS", "HTMLViewer in GUARDTALK_APPS_KEEP")
else:
    out("FAIL", "HTMLViewer missing from GUARDTALK_APPS_KEEP")
if "Gallery2" in drop_tokens:
    out("PASS", "Gallery2 still in GUARDTALK_APPS_PACKAGES drop list")
else:
    out("FAIL", "Gallery2 un-excised (missing from drop list)")
if "Gallery2" in keep:
    out("FAIL", "Gallery2 in KEEP (un-excised)")
else:
    out("PASS", "Gallery2 not in KEEP")
if "ImageViewer" in keep or "ImageViewer" in drop_tokens:
    out("FAIL", "ImageViewer token present in KEEP/drop (second gallery)")
else:
    out("PASS", "ImageViewer not in KEEP or drop (not shipped)")
if "PRODUCT_PACKAGES += ImageViewer" in excised or re.search(
    r"PRODUCT_PACKAGES\s*\+=\s*ImageViewer\b", excised
):
    out("FAIL", "apps-excised.mk adds ImageViewer to PRODUCT_PACKAGES")
else:
    out("PASS", "apps-excised.mk does not PRODUCT_PACKAGES += ImageViewer")
if re.search(r"PRODUCT_PACKAGES\s*\+=\s*Gallery2\b", excised):
    out("FAIL", "apps-excised.mk re-adds Gallery2")
else:
    out("PASS", "apps-excised.mk does not re-add Gallery2")

# GmsCompat drop stanza must remain (do not regress B2 from this card)
if re.search(r"^\s*GmsCompat\s*\\?\s*$", excised, re.M):
    out("PASS", "GmsCompat still in drop list (B2 not regressed)")
else:
    out("FAIL", "GmsCompat missing from drop list (B2 regression)")

# --- unit tests exist (not executed; m HOLD) ---
ah_test = read(
    "packages/apps/DocumentsUI/tests/unit/com/android/documentsui/files/ActionHandlerTest.java"
)
if "FILE_JPG" in ah_test and "FILE_PNG" in ah_test and "MediaPreviewActivity" in ah_test:
    out("PASS", "ActionHandlerTest covers jpeg/png in-app MediaPreview fallback")
else:
    out("FAIL", "ActionHandlerTest missing jpeg/png MediaPreview fallback")
html_test = read(
    "packages/apps/DocumentsUI/tests/unit/com/android/documentsui/guardtalk/GuardTalkHtmlViewerLaunchTest.java"
)
if "image/jpeg" in html_test and "image/png" in html_test and "image/webp" in html_test:
    out("PASS", "GuardTalkHtmlViewerLaunchTest covers jpeg/png/webp MIME")
else:
    out("FAIL", "GuardTalkHtmlViewerLaunchTest MIME coverage incomplete")
if "image/gif" in html_test and "assertFalse" in html_test:
    out("PASS", "GuardTalkHtmlViewerLaunchTest rejects gif / image/*")
else:
    out("FAIL", "GuardTalkHtmlViewerLaunchTest missing gif / image/* negatives")

# no second gallery under vendor/guardtalk/apps
apps_root = root / "vendor/guardtalk/apps"
if apps_root.is_dir():
    names = [p.name for p in apps_root.iterdir() if p.is_dir()]
    galleryish = [n for n in names if re.search(r"gallery|imageviewer|photoviewer", n, re.I)]
    if galleryish:
        out("FAIL", f"second gallery dir(s) under vendor/guardtalk/apps: {galleryish}")
    else:
        out("PASS", f"no gallery/ImageViewer dir under vendor/guardtalk/apps (have {names})")

print(f"PY_COUNTS pass={pass_n} fail={fail} hold={hold_n}")
sys.exit(1 if fail else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -eq 0 ]]; then
  pass "python structural rematch exit 0"
else
  fail "python structural rematch exit $PY_RC"
fi

echo
echo "--- lunch komodo-trunk_staging-user (independent; do not skip) ---"
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="${ROOT}/vendor/adevtool"
set +e
set +u
# envsetup uses unset vars. lunch MUST run in this shell (not $() or pipe).
# Do not set -u around source. Session-only GIT_CONFIG (do not git config --global).
# shellcheck disable=SC1091
source build/envsetup.sh
lunch komodo-trunk_staging-user
LUNCH_RC=$?
set -u
if [[ "$LUNCH_RC" -eq 0 ]]; then
  pass "lunch komodo-trunk_staging-user exit 0"
else
  fail "lunch komodo-trunk_staging-user exit $LUNCH_RC"
fi

gbv() {
  local var="$1"
  set +u
  get_build_var "$var"
  local rc=$?
  set -u
  return $rc
}

VARIANT="$(gbv TARGET_BUILD_VARIANT | tail -n 1 | tr -d '[:space:]')"
PRODUCT="$(gbv TARGET_PRODUCT | tail -n 1 | tr -d '[:space:]')"
PKGS="$(gbv PRODUCT_PACKAGES || true)"

echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"

if [[ "$PRODUCT" == "komodo" ]]; then
  pass "TARGET_PRODUCT=komodo"
else
  fail "TARGET_PRODUCT=${PRODUCT} (expected komodo)"
fi
if [[ "$VARIANT" == "user" ]]; then
  pass "TARGET_BUILD_VARIANT=user (not userdebug)"
else
  fail "TARGET_BUILD_VARIANT=${VARIANT} (expected user)"
fi

# Do not grep -q in a pipe: SIGPIPE + pipefail is a false ABSENT.
pkg_tokens() {
  printf '%s\n' "$PKGS" | tr '[:space:]' '\n' | grep -E -v '^(Build sandboxing|export BUILD_|=======|$)' || true
}

echo "--- filtered PRODUCT_PACKAGES (user lunch) ---"
html_pkg="$(pkg_tokens | grep -Fx 'HTMLViewer' || true)"
gal_pkg="$(pkg_tokens | grep -Fx 'Gallery2' || true)"
img_pkg="$(pkg_tokens | grep -Fx 'ImageViewer' || true)"
doc_pkg="$(pkg_tokens | grep -Fx 'DocumentsUI' || true)"
ump_pkg="$(pkg_tokens | grep -Fx 'UniversalMediaPlayer' || true)"

if [[ -n "$html_pkg" ]]; then
  pass "filtered PRODUCT_PACKAGES: HTMLViewer PRESENT"
else
  fail "HTMLViewer ABSENT from filtered PRODUCT_PACKAGES"
fi
if [[ -z "$gal_pkg" ]]; then
  pass "filtered PRODUCT_PACKAGES: Gallery2 ABSENT"
else
  fail "Gallery2 PRESENT in filtered PRODUCT_PACKAGES (un-excised)"
fi
if [[ -z "$img_pkg" ]]; then
  pass "filtered PRODUCT_PACKAGES: ImageViewer ABSENT"
else
  fail "ImageViewer PRESENT in filtered PRODUCT_PACKAGES (second gallery)"
fi
if [[ -n "$doc_pkg" ]]; then
  pass "filtered PRODUCT_PACKAGES: DocumentsUI PRESENT (Files path)"
else
  fail "DocumentsUI ABSENT from filtered PRODUCT_PACKAGES"
fi
if [[ -n "$ump_pkg" ]]; then
  pass "filtered PRODUCT_PACKAGES: UniversalMediaPlayer PRESENT (supporting video VIEW)"
else
  hold "UniversalMediaPlayer ABSENT from filtered PRODUCT_PACKAGES (item 18 still-image AC uses HTMLViewer)"
fi

html_count="$(pkg_tokens | grep -Fx 'HTMLViewer' | wc -l | tr -d '[:space:]')"
if [[ "$html_count" == "1" ]]; then
  pass "HTMLViewer token count=1 (no duplicate PRODUCT_PACKAGES +=)"
else
  hold "HTMLViewer token count=${html_count}"
fi

ART_DIR="vendor/guardtalk/docs/qa/_artifacts"
mkdir -p "$ART_DIR"
printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -E 'HTMLViewer|Gallery2|ImageViewer|DocumentsUI|UniversalMediaPlayer' \
  > "$ART_DIR/Q-REMEDIATE-B3-VIEWER_PRODUCT_PACKAGES.txt" || true

echo
echo "--- adb (query-activities HOLD if empty; not device-fixed) ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | awk 'NR>1 && $2=="device" {found=1} END{exit found?0:1}'; then
  hold "adb device present — query-activities image/jpeg NOT claimed PASS on this card"
  hold "do not lift PASS HOLD; Files/Validator on-device open remains Q-REMEDIATE-B3-OSUX-DEVICE"
else
  hold "adb devices empty — query-activities HOLD; not device-fixed"
  hold "Q-REMEDIATE-B3-OSUX-DEVICE stays BLOCKED (not folded; needs flashed user image)"
fi
hold "m HTMLViewer / DocumentsUI / GuardTalkValidator not run this QA stamp"
hold "PASS HOLD remains; live not claimed; never APPROVED"

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} bash_FAIL=${FAIL_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "QUERY_ACTIVITIES=HOLD"
echo "Q-REMEDIATE-B3-OSUX-DEVICE=BLOCKED (not folded)"
exit "$FAIL"
