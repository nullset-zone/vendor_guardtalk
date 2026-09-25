#!/usr/bin/env bash
# Static verification for Q-OS-FILES-MEDIA
# Independent rematch of T-OS-FILES-MEDIA (DEC-OS-UX-001).
# Do not trust Backend/Architect claims. Do not claim device-fixed without adb.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_os_files_media_static.sh
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
HTML_MF="packages/apps/HTMLViewer/AndroidManifest.xml"
HTML_JAVA="packages/apps/HTMLViewer/src/com/android/htmlviewer/HTMLViewerActivity.java"
UMP_MF="packages/apps/UniversalMediaPlayer/AndroidManifest.xml"
UMP_VID="packages/apps/UniversalMediaPlayer/java/com/android/pump/activity/VideoPlayerActivity.java"
EXCISED="vendor/guardtalk/feature-excised/apps-excised.mk"
POLICY="frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java"
POLICY_DOC="vendor/guardtalk/docs/FILES_HANDLERS_POLICY.md"
MEDIA_MK="build/make/target/product/media_system.mk"
ADEVTOOL="vendor/google_devices/tokay/adevtool-version-check.mk"

echo "=== Q-OS-FILES-MEDIA independent rematch ==="
echo "ROOT=$ROOT"
echo

echo "=== RAW: rg -n android.intent.action.VIEW $DOCUI ==="
rg -n "android.intent.action.VIEW" "$DOCUI" || true
echo

echo "=== RAW: rg -n Gallery2|HTMLViewer|UniversalMediaPlayer $EXCISED ==="
rg -n "Gallery2|HTMLViewer|UniversalMediaPlayer" "$EXCISED" || true
echo

echo "=== RAW: rg -n image/jpeg|video/mp4|image/webp|video/webm|image/png HTMLViewer+UMP ==="
rg -n "image/jpeg|video/mp4|image/webp|video/webm|image/png" \
  "$HTML_MF" "$UMP_MF" || true
echo

echo "=== RAW: rg -n CRITICAL_PATH_PREFIXES|/system|/vendor|/boot $POLICY ==="
rg -n "CRITICAL_PATH_PREFIXES|/system|/vendor|/boot" "$POLICY" || true
echo

echo "=== RAW: rg -n LAUNCHER HTMLViewer+UMP+DocumentsUI ==="
rg -n "LAUNCHER" "$HTML_MF" "$UMP_MF" "$DOCUI" || true
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
    text = Path(path).read_text(encoding="utf-8")
    return ET.fromstring(text)

def action_name(action):
    return aget(action, "name") or ""

def mime_of(data):
    return aget(data, "mimeType")

def scheme_of(data):
    return aget(data, "scheme")

def category_name(cat):
    return aget(cat, "name") or ""

def filters(activity):
    return list(activity.findall("intent-filter"))

def activities(manifest):
    app = manifest.find("application")
    if app is None:
        return []
    return list(app.findall("activity")) + list(app.findall("activity-alias"))

def view_mimes(filt):
    actions = [action_name(a) for a in filt.findall("action")]
    if "android.intent.action.VIEW" not in actions:
        return None
    return [m for m in (mime_of(d) for d in filt.findall("data")) if m]

def view_schemes(filt):
    actions = [action_name(a) for a in filt.findall("action")]
    if "android.intent.action.VIEW" not in actions:
        return None
    return [s for s in (scheme_of(d) for d in filt.findall("data")) if s]

# --- DocumentsUI VIEW vs SAF ---
docui = parse_manifest(root / "packages/apps/DocumentsUI/AndroidManifest.xml")
view_mimes_all = []
view_star = False
saf_star_ok = 0
saf_actions = {
    "android.intent.action.GET_CONTENT",
    "android.intent.action.OPEN_DOCUMENT",
    "android.intent.action.CREATE_DOCUMENT",
}
for act in activities(docui):
    for filt in filters(act):
        actions = {action_name(a) for a in filt.findall("action")}
        mimes = [m for m in (mime_of(d) for d in filt.findall("data")) if m]
        if "android.intent.action.VIEW" in actions:
            view_mimes_all.extend(mimes)
            if "*/*" in mimes:
                view_star = True
        if actions & saf_actions and "*/*" in mimes:
            saf_star_ok += 1

allowed_view = {"vnd.android.document/root", "vnd.android.document/directory"}
if view_star:
    out("FAIL", "DocumentsUI VIEW includes */* (spam launcher)")
else:
    out("PASS", "DocumentsUI VIEW has no */*")
unexpected = set(view_mimes_all) - allowed_view
if unexpected:
    out("FAIL", f"DocumentsUI VIEW unexpected MIME {sorted(unexpected)}")
else:
    out("PASS", f"DocumentsUI VIEW MIME only {sorted(set(view_mimes_all))}")
if {"vnd.android.document/root", "vnd.android.document/directory"} <= set(view_mimes_all):
    out("PASS", "DocumentsUI VIEW still root + directory")
else:
    out("FAIL", f"DocumentsUI VIEW missing root/directory; got {view_mimes_all}")
if saf_star_ok >= 1:
    out("PASS", f"SAF GET_CONTENT/OPEN/CREATE */* present ({saf_star_ok} filters) — not a FAIL")
else:
    out("FAIL", "SAF */* on GET_CONTENT/OPEN/CREATE missing (unexpected)")

launcher_docui = False
for act in activities(docui):
    for filt in filters(act):
        cats = [category_name(c) for c in filt.findall("category")]
        if "android.intent.category.LAUNCHER" in cats:
            launcher_docui = True
if launcher_docui:
    out("PASS", "DocumentsUI keeps LAUNCHER (single Files icon)")
else:
    out("FAIL", "DocumentsUI lost LAUNCHER")

compose_path = root / "packages/apps/DocumentsUI/compose/AndroidManifest.xml"
compose = parse_manifest(compose_path)
compose_launcher = False
for act in activities(compose):
    for filt in filters(act):
        cats = [category_name(c) for c in filt.findall("category")]
        if "android.intent.category.LAUNCHER" in cats:
            compose_launcher = True
    if aget(act, "name") == ".MainActivity":
        enabled = aget(act, "enabled")
        if enabled == "false":
            out("PASS", "DocumentsUI Compose MainActivity enabled=false")
        else:
            out("FAIL", f"DocumentsUI Compose MainActivity enabled={enabled}")
if compose_launcher:
    out("FAIL", "DocumentsUI Compose still has LAUNCHER")
else:
    out("PASS", "DocumentsUI Compose has no LAUNCHER")

# --- HTMLViewer image VIEW ---
html = parse_manifest(root / "packages/apps/HTMLViewer/AndroidManifest.xml")
html_view = []
html_image_schemes = []
html_launcher = False
for act in activities(html):
    for filt in filters(act):
        cats = [category_name(c) for c in filt.findall("category")]
        if "android.intent.category.LAUNCHER" in cats:
            html_launcher = True
        mimes = view_mimes(filt)
        if mimes is None:
            continue
        html_view.extend(mimes)
        if any(m.startswith("image/") for m in mimes):
            html_image_schemes.extend(view_schemes(filt) or [])
need_img = {"image/jpeg", "image/png", "image/webp"}
if need_img <= set(html_view):
    out("PASS", "HTMLViewer VIEW filters image/jpeg + image/png + image/webp")
else:
    out("FAIL", f"HTMLViewer missing image VIEW {sorted(need_img - set(html_view))}; got {html_view}")
if "*/*" in html_view:
    out("FAIL", "HTMLViewer VIEW includes */*")
else:
    out("PASS", "HTMLViewer VIEW has no */*")
if {"content", "file"} <= set(html_image_schemes):
    out("PASS", "HTMLViewer image VIEW schemes content + file")
else:
    out("FAIL", f"HTMLViewer image VIEW schemes {html_image_schemes}")
if html_launcher:
    out("FAIL", "HTMLViewer declares LAUNCHER")
else:
    out("PASS", "HTMLViewer has no LAUNCHER category")

html_java = (root / "packages/apps/HTMLViewer/src/com/android/htmlviewer/HTMLViewerActivity.java").read_text(encoding="utf-8")
if "setJavaScriptEnabled(false)" in html_java:
    out("PASS", "HTMLViewer setJavaScriptEnabled(false)")
else:
    out("FAIL", "HTMLViewer JS not disabled")
if "setBlockNetworkLoads(true)" in html_java:
    out("PASS", "HTMLViewer setBlockNetworkLoads(true)")
else:
    out("FAIL", "HTMLViewer network loads not blocked")

# --- UniversalMediaPlayer video VIEW ---
ump = parse_manifest(root / "packages/apps/UniversalMediaPlayer/AndroidManifest.xml")
ump_launcher = False
ump_video_mimes = []
ump_video_schemes = []
pump_exported = None
ump_internet = False
for perm in ump.findall("uses-permission"):
    if aget(perm, "name") == "android.permission.INTERNET":
        ump_internet = True
for act in activities(ump):
    name = aget(act, "name") or ""
    if name.endswith(".PumpActivity") or name == ".activity.PumpActivity":
        pump_exported = aget(act, "exported")
    for filt in filters(act):
        cats = [category_name(c) for c in filt.findall("category")]
        if "android.intent.category.LAUNCHER" in cats:
            ump_launcher = True
        if not name.endswith("VideoPlayerActivity"):
            continue
        mimes = view_mimes(filt)
        if mimes is None:
            continue
        ump_video_mimes.extend(mimes)
        ump_video_schemes.extend(view_schemes(filt) or [])
need_vid = {"video/mp4", "video/webm"}
if need_vid <= set(ump_video_mimes):
    out("PASS", "UniversalMediaPlayer VideoPlayerActivity VIEW video/mp4 + video/webm")
else:
    out("FAIL", f"UMP video VIEW missing {sorted(need_vid - set(ump_video_mimes))}; got {ump_video_mimes}")
if {"content", "file"} <= set(ump_video_schemes):
    out("PASS", "UMP video VIEW schemes content + file")
else:
    out("FAIL", f"UMP video VIEW schemes {ump_video_schemes}")
if "video/*" in ump_video_mimes:
    out("PASS", "UMP also declares video/* (broader residual, not FAIL)")
else:
    out("HOLD", "UMP video/* absent (mp4/webm still required)")
if ump_launcher:
    out("FAIL", "UniversalMediaPlayer declares LAUNCHER")
else:
    out("PASS", "UniversalMediaPlayer has no LAUNCHER category")
if pump_exported == "false":
    out("PASS", "PumpActivity exported=false")
else:
    out("FAIL", f"PumpActivity exported={pump_exported}")
if ump_internet:
    out("PASS", "UMP INTERNET permission present (pre-existing residual, not FAIL)")
else:
    out("HOLD", "UMP INTERNET permission absent (unexpected vs T residual)")

vid_java = root / "packages/apps/UniversalMediaPlayer/java/com/android/pump/activity/VideoPlayerActivity.java"
if vid_java.is_file() and "class VideoPlayerActivity" in vid_java.read_text(encoding="utf-8"):
    out("PASS", "VideoPlayerActivity.java present (in-tree player class)")
else:
    out("FAIL", "VideoPlayerActivity.java missing")

# --- excised.mk lists ---
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
prod_plus = makefile_assign_tokens(mk, "PRODUCT_PACKAGES")

if "Gallery2" in drop:
    out("PASS", "Gallery2 still in GUARDTALK_APPS_PACKAGES drop list")
else:
    out("FAIL", "Gallery2 un-excised (missing from drop list)")
if "Gallery2" in keep:
    out("FAIL", "Gallery2 unexpectedly in GUARDTALK_APPS_KEEP")
else:
    out("PASS", "Gallery2 not in GUARDTALK_APPS_KEEP")
if "HTMLViewer" in drop:
    out("FAIL", "HTMLViewer still in GUARDTALK_APPS_PACKAGES drop list")
else:
    out("PASS", "HTMLViewer not in GUARDTALK_APPS_PACKAGES drop list")
if "HTMLViewer" in keep:
    out("PASS", "HTMLViewer in GUARDTALK_APPS_KEEP")
else:
    out("FAIL", "HTMLViewer missing from GUARDTALK_APPS_KEEP")
if "UniversalMediaPlayer" in drop:
    out("FAIL", "UniversalMediaPlayer in drop list")
else:
    out("PASS", "UniversalMediaPlayer not in drop list")
if "UniversalMediaPlayer" in keep:
    out("PASS", "UniversalMediaPlayer in GUARDTALK_APPS_KEEP")
else:
    out("FAIL", "UniversalMediaPlayer missing from GUARDTALK_APPS_KEEP")
if "UniversalMediaPlayer" in prod_plus:
    out("PASS", "PRODUCT_PACKAGES += UniversalMediaPlayer")
else:
    out("FAIL", "UniversalMediaPlayer not added to PRODUCT_PACKAGES")

media_mk = (root / "build/make/target/product/media_system.mk").read_text(encoding="utf-8")
if re.search(r"^\s*HTMLViewer\s*\\?\s*$", media_mk, re.M):
    out("PASS", "HTMLViewer still listed in media_system.mk PRODUCT_PACKAGES")
else:
    out("FAIL", "HTMLViewer missing from media_system.mk")

# --- GuardTalkFilesPolicy critical prefixes ---
pol = (root / "frameworks/base/core/java/android/guardtalk/GuardTalkFilesPolicy.java").read_text(encoding="utf-8")
m = re.search(r"CRITICAL_PATH_PREFIXES\s*=\s*\{(.*?)\};", pol, re.S)
if not m:
    out("FAIL", "CRITICAL_PATH_PREFIXES array not found")
    prefixes = []
else:
    prefixes = re.findall(r'"(/[^"]+)"', m.group(1))
required = [
    "/system", "/system_ext", "/vendor", "/product", "/odm", "/oem",
    "/boot", "/recovery", "/vendor_boot", "/init_boot", "/firmware",
    "/persist", "/mnt/vendor", "/mnt/product", "/mnt/guardtalk_privacy",
]
missing = [p for p in required if p not in prefixes]
if missing:
    out("FAIL", f"CRITICAL_PATH_PREFIXES weakened; missing {missing}")
else:
    out("PASS", "CRITICAL_PATH_PREFIXES still include /system /vendor /boot (full T-SEC-P4 set)")
if "does <strong>not</strong> restrict ACTION_VIEW" in pol or "does not restrict ACTION_VIEW" in pol:
    out("PASS", "GuardTalkFilesPolicy documents VIEW is not gated")
else:
    out("HOLD", "GuardTalkFilesPolicy VIEW-not-gated javadoc wording changed")
if "isProtectedPath" in pol and "isProtectedFile" in pol:
    out("PASS", "isProtectedPath + isProtectedFile still present")
else:
    out("FAIL", "critical-protect methods missing")

doc = (root / "vendor/guardtalk/docs/FILES_HANDLERS_POLICY.md").read_text(encoding="utf-8")
if "T-OS-FILES-MEDIA" in doc and "HTMLViewer" in doc and "UniversalMediaPlayer" in doc:
    out("PASS", "FILES_HANDLERS_POLICY.md records T-OS-FILES-MEDIA handlers")
else:
    out("FAIL", "FILES_HANDLERS_POLICY.md missing T-OS-FILES-MEDIA handler table")

adev = root / "vendor/google_devices/tokay/adevtool-version-check.mk"
if adev.is_file() and "tokay vendor module is outdated" in adev.read_text(encoding="utf-8"):
    out("HOLD", "lunch tokay-trunk_staging-userdebug (adevtool pin still present; not run)")
else:
    out("HOLD", "lunch not run this QA session")

print(f"__COUNTS__ PASS={pass_n} FAIL={fail_n} HOLD={hold_n}")
Path("/tmp/q-os-files-media-counts").write_text(f"{pass_n} {fail_n} {hold_n}\n")
sys.exit(0)
PY
read -r PASS_N FAIL_N HOLD_N < /tmp/q-os-files-media-counts
if [[ "${FAIL_N}" -gt 0 ]]; then
  FAIL=1
fi

echo
echo "=== adb query-activities (device) ==="
DEVICE_LINES="$(printf '%s\n' "$ADB_OUT" | awk 'NR>1 && $1 != "" && $1 != "*" && $1 != "List" {print $1}')"
if [[ -z "${DEVICE_LINES}" ]]; then
  hold "adb devices empty — query-activities image/jpeg HOLD (not device-fixed)"
  hold "adb devices empty — query-activities video/mp4 HOLD (not device-fixed)"
  hold "black-screen / empty chooser / silent-fail runtime — HOLD without adb"
else
  echo "RAW: adb shell cmd package query-activities -a android.intent.action.VIEW -t image/jpeg"
  JPEG_Q="$(adb shell cmd package query-activities -a android.intent.action.VIEW -t image/jpeg 2>&1 || true)"
  printf '%s\n' "$JPEG_Q"
  echo "RAW: adb shell cmd package query-activities -a android.intent.action.VIEW -t video/mp4"
  MP4_Q="$(adb shell cmd package query-activities -a android.intent.action.VIEW -t video/mp4 2>&1 || true)"
  printf '%s\n' "$MP4_Q"
  if printf '%s\n' "$JPEG_Q" | rg -q "htmlviewer|HTMLViewer|com.android.htmlviewer"; then
    pass "device query-activities image/jpeg includes HTMLViewer"
  else
    fail "device query-activities image/jpeg missing HTMLViewer"
  fi
  if printf '%s\n' "$MP4_Q" | rg -q "pump|UniversalMediaPlayer|VideoPlayerActivity|com.android.pump"; then
    pass "device query-activities video/mp4 includes UniversalMediaPlayer"
  else
    fail "device query-activities video/mp4 missing UniversalMediaPlayer"
  fi
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
