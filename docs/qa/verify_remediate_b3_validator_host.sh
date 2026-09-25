#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B3-VALIDATOR (items 15, 16).
# Pair of F-REMEDIATE-B3-VALIDATOR. Do not trust Frontend / Architect reports.
# Host static + lunch. Device enable/nav HOLD if adb empty.
# dumpsys enabled=0 is COMPONENT_ENABLED_STATE_DEFAULT — do not invent
# on-device enabled=true. SensorPrivacyService.java must stay untouched.
# No product edits. No USB GO. No wipe. No commit. Never APPROVED.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b3_validator_host.sh
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

VAL="vendor/guardtalk/apps/GuardTalkValidator"
MAN="$VAL/AndroidManifest.xml"
CHROME="$VAL/src/com/guardtalk/validator/ValidatorChrome.kt"
MENU="$VAL/src/com/guardtalk/validator/EscapeMenu.kt"
STATUS="$VAL/src/com/guardtalk/validator/DeviceStatusReporter.kt"
HELPER="$VAL/src/com/guardtalk/validator/SensorToggleHelper.kt"
VIEWS="$VAL/src/com/guardtalk/validator/SensorToggleViews.kt"
VAL_ACT="$VAL/src/com/guardtalk/validator/ValidatorActivity.kt"
PROC_ACT="$VAL/src/com/guardtalk/validator/ProcessListActivity.kt"
LAY_CHROME="$VAL/res/layout/validator_chrome.xml"
LAY_VAL="$VAL/res/layout/activity_validator.xml"
LAY_PROC="$VAL/res/layout/activity_process_list.xml"
LAY_MENU="$VAL/res/layout/escape_menu.xml"
LAY_SENS="$VAL/res/layout/sensor_privacy_toggles.xml"
STRINGS="$VAL/res/values/strings.xml"
BP="$VAL/Android.bp"
LATE="vendor/guardtalk/radio-excised/product-config-late.mk"
DROP="vendor/guardtalk/feature-excised/userbuild-excised.mk"
SPS="frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java"
PM="frameworks/base/core/java/android/content/pm/PackageManager.java"
SEC="frameworks/base/core/java/android/guardtalk/GuardTalkSecurityStatus.java"
DASH="packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml"
GTINFO="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkGtInfoPreferenceController.java"

echo "=== Q-REMEDIATE-B3-VALIDATOR independent rematch (items 15, 16) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "F/Architect reports: not trusted"
echo "USB_GO=not started"
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
require_file "$MAN"
require_file "$CHROME"
require_file "$MENU"
require_file "$STATUS"
require_file "$HELPER"
require_file "$VIEWS"
require_file "$VAL_ACT"
require_file "$PROC_ACT"
require_file "$LAY_CHROME"
require_file "$LAY_VAL"
require_file "$LAY_PROC"
require_file "$LAY_MENU"
require_file "$LAY_SENS"
require_file "$STRINGS"
require_file "$BP"
require_file "$LATE"
require_file "$DROP"
require_file "$SPS"
require_file "$PM"
require_file "$SEC"
require_file "$DASH"
require_file "$GTINFO"

echo
echo "--- packet rg (enable / exit / escape / duress) ---"
rg -n 'android:enabled=|finishAndRemoveTask|ACTION_SETTINGS|Duress|isSensorPrivacyEnabled|accessOn' \
  "$MAN" "$CHROME" "$MENU" "$STATUS" "$HELPER" "$VIEWS" "$STRINGS" || true
echo
rg -n 'GuardTalkValidator' "$LATE" "$DROP" "$BP" || true
echo

echo "--- python structural rematch ---"
set +e
python3 - "$ROOT" <<'PY'
import re
import sys
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

def strip_xml_comments(src):
    return re.sub(r"<!--.*?-->", "", src, flags=re.S)

def strip_kt_comments(src):
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"//.*?$", "", src, flags=re.M)
    return src

def mk_live(src):
    lines = []
    for line in src.splitlines():
        s = line.split("#", 1)[0].rstrip()
        if s.strip():
            lines.append(s)
    return "\n".join(lines)

def tag_block(src, tag, extra=""):
    pat = rf"<{tag}{extra}[^>]*(?:/>|>.*?</{tag}>)"
    return re.findall(pat, src, flags=re.S)

man = read("vendor/guardtalk/apps/GuardTalkValidator/AndroidManifest.xml")
chrome = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/ValidatorChrome.kt")
menu = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/EscapeMenu.kt")
status = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/DeviceStatusReporter.kt")
helper = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SensorToggleHelper.kt")
views = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SensorToggleViews.kt")
val_act = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/ValidatorActivity.kt")
proc_act = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/ProcessListActivity.kt")
lay_chrome = read("vendor/guardtalk/apps/GuardTalkValidator/res/layout/validator_chrome.xml")
lay_val = read("vendor/guardtalk/apps/GuardTalkValidator/res/layout/activity_validator.xml")
lay_proc = read("vendor/guardtalk/apps/GuardTalkValidator/res/layout/activity_process_list.xml")
lay_menu = read("vendor/guardtalk/apps/GuardTalkValidator/res/layout/escape_menu.xml")
lay_sens = read("vendor/guardtalk/apps/GuardTalkValidator/res/layout/sensor_privacy_toggles.xml")
strings = read("vendor/guardtalk/apps/GuardTalkValidator/res/values/strings.xml")
bp = read("vendor/guardtalk/apps/GuardTalkValidator/Android.bp")
late = read("vendor/guardtalk/radio-excised/product-config-late.mk")
drop = read("vendor/guardtalk/feature-excised/userbuild-excised.mk")
sps = read(
    "frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java"
)
pm = read("frameworks/base/core/java/android/content/pm/PackageManager.java")
sec = read("frameworks/base/core/java/android/guardtalk/GuardTalkSecurityStatus.java")
dash = read("packages/apps/Settings/res/xml/guardtalk_security_dashboard.xml")
gtinfo = read(
    "packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkGtInfoPreferenceController.java"
)

# --- item 15: explicit enabled=true (live XML, not comments) ---
man_noc = strip_xml_comments(man)
apps = tag_block(man_noc, "application")
if len(apps) != 1:
    out("FAIL", f"application tag count={len(apps)} (expected 1)")
    app = ""
else:
    app = apps[0]
    if re.search(r'\bandroid:enabled="true"', app.split(">", 1)[0]):
        out("PASS", "application live android:enabled=true (not comment-only)")
    else:
        out("FAIL", "application missing live android:enabled=true")
    if re.search(r'\bandroid:enabled="false"', app.split(">", 1)[0]):
        out("FAIL", "NEGATIVE HIT: application android:enabled=false")
    else:
        out("PASS", "application is not android:enabled=false")

def activity_enabled(name):
    blocks = tag_block(man_noc, "activity")
    hit = None
    for b in blocks:
        if f'android:name="{name}"' in b or f"android:name='{name}'" in b:
            hit = b
            break
    if hit is None:
        out("FAIL", f"activity {name} missing from manifest")
        return
    head = hit.split(">", 1)[0]
    if re.search(r'\bandroid:enabled="true"', head):
        out("PASS", f"{name} live android:enabled=true (not comment-only)")
    else:
        out("FAIL", f"{name} missing live android:enabled=true")
    if re.search(r'\bandroid:enabled="false"', head):
        out("FAIL", f"NEGATIVE HIT: {name} android:enabled=false")
    else:
        out("PASS", f"{name} is not android:enabled=false")

activity_enabled(".ValidatorActivity")
activity_enabled(".ProcessListActivity")

# enableOnBackInvokedCallback is not android:enabled — do not confuse
if 'android:enableOnBackInvokedCallback="true"' in man_noc:
    out("PASS", "enableOnBackInvokedCallback present (distinct from android:enabled)")
else:
    out("FAIL", "enableOnBackInvokedCallback missing")

# --- dumpsys enabled=0 contract (AOSP constant, not device claim) ---
if re.search(
    r"COMPONENT_ENABLED_STATE_DEFAULT\s*=\s*0\s*;",
    pm,
):
    out("PASS", "PackageManager.COMPONENT_ENABLED_STATE_DEFAULT=0 (dumpsys enabled=0 is DEFAULT, not DISABLED)")
else:
    out("FAIL", "cannot prove COMPONENT_ENABLED_STATE_DEFAULT=0 in PackageManager.java")
if re.search(r"COMPONENT_ENABLED_STATE_ENABLED\s*=\s*1\s*;", pm) and re.search(
    r"COMPONENT_ENABLED_STATE_DISABLED\s*=\s*2\s*;", pm
):
    out("PASS", "ENABLED=1 DISABLED=2; enabled=0 is not pm-disabled")
else:
    out("FAIL", "PackageManager enabled-state constants rewritten")

# --- PRODUCT_PACKAGES wiring (live mk, not comments) ---
late_live = mk_live(late)
if re.search(r"PRODUCT_PACKAGES\s*\+=\s*GuardTalkValidator\b", late_live):
    out("PASS", "product-config-late.mk live PRODUCT_PACKAGES += GuardTalkValidator")
else:
    out("FAIL", "GuardTalkValidator not a live PRODUCT_PACKAGES += in product-config-late.mk")
if "name: \"GuardTalkValidator\"" in bp:
    out("PASS", "Android.bp module name GuardTalkValidator")
else:
    out("FAIL", "Android.bp missing GuardTalkValidator module")

drop_live = mk_live(drop)
drop_m = re.search(r"GUARDTALK_USERBUILD_DROP\s*:=\s*(.+)", drop_live)
drop_toks = drop_m.group(1).split() if drop_m else []
if "GuardTalkValidator" in drop_toks:
    out("FAIL", "NEGATIVE HIT: GuardTalkValidator in GUARDTALK_USERBUILD_DROP")
else:
    out("PASS", "userbuild-excised DROP does not include GuardTalkValidator")

# --- no overlay / pm disable of com.guardtalk.validator ---
scan_roots = [
    root / "vendor/guardtalk/apps",
    root / "vendor/guardtalk/overlays",
    root / "vendor/guardtalk/device",
    root / "vendor/guardtalk/radio-excised",
    root / "vendor/guardtalk/feature-excised",
    root / "vendor/guardtalk/permissions",
]
skip_names = {".git", "out", "docs"}
pm_hits = []
overlay_hits = []
disable_re = re.compile(
    r"pm\s+disable(?:-user)?\s+(?:--user\s+\S+\s+)?com\.guardtalk\.validator"
    r"|setApplicationEnabledSetting\([^;]*com\.guardtalk\.validator",
    re.I,
)
overlay_re = re.compile(
    r'targetPackage\s*=\s*"com\.guardtalk\.validator"',
    re.I,
)
for base in scan_roots:
    if not base.exists():
        continue
    for p in base.rglob("*"):
        if not p.is_file():
            continue
        if any(part in skip_names for part in p.parts):
            continue
        if p.suffix.lower() not in {
            ".xml", ".xml.bk", ".mk", ".bp", ".rc", ".sh", ".kt", ".java",
            ".prop", ".te",
        }:
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        rel = str(p.relative_to(root))
        noc = strip_xml_comments(text) if p.suffix == ".xml" else text
        if p.suffix in {".mk", ".rc", ".sh", ".prop"}:
            noc = "\n".join(ln.split("#", 1)[0] for ln in noc.splitlines())
        if disable_re.search(strip_kt_comments(noc) if p.suffix in {".kt", ".java"} else noc):
            pm_hits.append(rel)
        if overlay_re.search(noc):
            overlay_hits.append(rel)

if pm_hits:
    out("FAIL", f"in-tree pm disable / setApplicationEnabledSetting of com.guardtalk.validator: {pm_hits}")
else:
    out("PASS", "no in-tree pm disable / setApplicationEnabledSetting of com.guardtalk.validator")

if overlay_hits:
    # Overlay targeting the package is not automatically a disable; flag for enabled=false.
    bad_ov = []
    for rel in overlay_hits:
        txt = strip_xml_comments(read(rel))
        if re.search(r'android:enabled="false"', txt):
            bad_ov.append(rel)
    if bad_ov:
        out("FAIL", f"overlay targets com.guardtalk.validator with enabled=false: {bad_ov}")
    else:
        out("PASS", f"overlay targetPackage hits have no enabled=false ({overlay_hits})")
else:
    out("PASS", "no overlay targetPackage=com.guardtalk.validator (no disable overlay)")

# Settings row is not the old stub/disabled trap (supporting, not a package overlay)
dash_noc = strip_xml_comments(dash)
gt_pref = re.search(
    r'<Preference[^>]*android:key="guardtalk_gt_info".*?>',
    dash_noc,
    re.S,
)
if gt_pref and 'android:enabled="true"' in gt_pref.group(0) and "GuardTalkGtInfoPreferenceController" in gt_pref.group(0):
    out("PASS", "Settings guardtalk_gt_info enabled=true via GuardTalkGtInfoPreferenceController (not Stub)")
else:
    out("FAIL", "Settings guardtalk_gt_info row missing, disabled, or still Stub")
if "GuardTalkSecurityStubPreferenceController" in dash_noc:
    out("FAIL", "NEGATIVE HIT: dashboard still wires GuardTalkSecurityStubPreferenceController")
else:
    out("PASS", "dashboard XML does not wire GuardTalkSecurityStubPreferenceController")
if 'GT_INFO_PACKAGE = "com.guardtalk.validator"' in gtinfo:
    out("PASS", "GtInfo controller deep-links com.guardtalk.validator")
else:
    out("FAIL", "GtInfo controller package constant rewritten")

# --- item 16: every screen has exit chrome ---
if 'android:id="@+id/btn_exit"' in lay_chrome and 'android:id="@+id/btn_menu"' in lay_chrome:
    out("PASS", "validator_chrome.xml has btn_exit and btn_menu")
else:
    out("FAIL", "validator_chrome.xml missing Exit/Menu ids")
if 'layout="@layout/validator_chrome"' in strip_xml_comments(lay_val):
    out("PASS", "activity_validator.xml includes validator_chrome")
else:
    out("FAIL", "ValidatorActivity layout missing validator_chrome include")
if 'layout="@layout/validator_chrome"' in strip_xml_comments(lay_proc):
    out("PASS", "activity_process_list.xml includes validator_chrome")
else:
    out("FAIL", "ProcessListActivity layout missing validator_chrome include")

acts = list((root / "vendor/guardtalk/apps/GuardTalkValidator/src").rglob("*.kt"))
activity_files = []
for p in acts:
    txt = p.read_text(encoding="utf-8", errors="replace")
    if re.search(r"class\s+\w+Activity\s*:\s*Activity", txt):
        activity_files.append(p)
if len(activity_files) != 2:
    out("FAIL", f"activity count={len(activity_files)} (expected ValidatorActivity + ProcessListActivity)")
else:
    out("PASS", "exactly two Activity classes (ValidatorActivity, ProcessListActivity)")

if "ValidatorChrome.attach(this, /* leaveAppOnBack= */ true)" in val_act:
    out("PASS", "ValidatorActivity attaches chrome; back leaves the task")
else:
    out("FAIL", "ValidatorActivity chrome attach / leaveAppOnBack rewritten")
if "ValidatorChrome.attach(this, /* leaveAppOnBack= */ false)" in proc_act:
    out("PASS", "ProcessListActivity attaches chrome; back finishes to parent")
else:
    out("FAIL", "ProcessListActivity chrome attach rewritten")

chrome_noc = strip_kt_comments(chrome)
if "fun exitApp(activity: Activity)" in chrome and "activity.finishAndRemoveTask()" in chrome_noc:
    out("PASS", "ValidatorChrome.exitApp calls finishAndRemoveTask")
else:
    out("FAIL", "exitApp missing finishAndRemoveTask")
if "btn_exit" in chrome and "exitApp(activity)" in chrome:
    out("PASS", "btn_exit click wires exitApp (finishAndRemoveTask)")
else:
    out("FAIL", "btn_exit not wired to exitApp")
if "btn_menu" in chrome and "EscapeMenu.show(activity)" in chrome:
    out("PASS", "btn_menu click opens EscapeMenu")
else:
    out("FAIL", "btn_menu not wired to EscapeMenu")

# Escape gestures: MENU / ESC / long-press back / long-press or triple-tap title
if "KEYCODE_ESCAPE" in chrome and "KEYCODE_MENU" in chrome:
    out("PASS", "escape keys KEYCODE_ESCAPE and KEYCODE_MENU open the menu")
else:
    out("FAIL", "escape MENU/ESC keys missing")
if "KEYCODE_BACK" in chrome and "isLongPress" in chrome and "EscapeMenu.show" in chrome:
    out("PASS", "long-press BACK opens EscapeMenu")
else:
    out("FAIL", "long-press BACK escape missing")
if "escape_hotspot" in chrome and "ESCAPE_TAP_COUNT = 3" in chrome:
    out("PASS", "title hotspot: long-press + triple-tap escape")
else:
    out("FAIL", "escape hotspot / triple-tap missing")
if "KEYCODE_HOME" in chrome_noc:
    out("FAIL", "NEGATIVE HIT: chrome consumes KEYCODE_HOME (non-launcher must not)")
else:
    out("PASS", "chrome does not consume KEYCODE_HOME (system Home leaves the task)")

# Both activities forward keys + deprecated onBackPressed
for name, src in (("ValidatorActivity", val_act), ("ProcessListActivity", proc_act)):
    if "ValidatorChrome.handleKey" in src and "onBackPressed" in src:
        out("PASS", f"{name} forwards keys and onBackPressed to chrome")
    else:
        out("FAIL", f"{name} missing chrome back/key wiring")

# Predictive back
if "OnBackInvokedCallback" in chrome and "registerOnBackInvokedCallback" in chrome:
    out("PASS", "ValidatorChrome registers OnBackInvokedCallback")
else:
    out("FAIL", "predictive back callback missing")

# --- escape menu: Settings / cam-mic helper / device status ---
menu_noc = strip_kt_comments(menu)
if "Settings.ACTION_SETTINGS" in menu and "ValidatorChrome.exitApp(activity)" in menu:
    out("PASS", "EscapeMenu Settings intent then exitApp")
else:
    out("FAIL", "EscapeMenu Settings / exit wiring missing")
if "SensorToggleViews.bind(activity, view)" in menu:
    out("PASS", "EscapeMenu binds SensorToggleViews (cam/mic via helper)")
else:
    out("FAIL", "EscapeMenu does not bind SensorToggleViews")
if "DeviceStatusReporter.format(activity)" in menu:
    out("PASS", "EscapeMenu device status uses DeviceStatusReporter")
else:
    out("FAIL", "EscapeMenu missing DeviceStatusReporter")
if 'layout="@layout/sensor_privacy_toggles"' in strip_xml_comments(lay_menu) and 'menu_open_settings' in lay_menu and 'menu_device_status' in lay_menu:
    out("PASS", "escape_menu.xml has Settings, sensor include, device status")
else:
    out("FAIL", "escape_menu.xml missing Settings / sensors / status")

# --- polarity: do not invert SensorToggleHelper ---
h_noc = strip_kt_comments(helper)
v_noc = strip_kt_comments(views)
if "!spm.isSensorPrivacyEnabled(sensor)" in helper:
    out("PASS", "isAccessOn = !isSensorPrivacyEnabled (Settings polarity)")
else:
    out("FAIL", "isAccessOn polarity inverted or missing")
if re.search(r"return\s+spm\.isSensorPrivacyEnabled\(sensor\)", h_noc):
    out("FAIL", "NEGATIVE HIT: isAccessOn returns privacy directly (inverted)")
else:
    out("PASS", "isAccessOn is not inverted to raw privacy")
if "setSensorPrivacy(SensorPrivacyManager.Sources.OTHER, sensor, !accessOn)" in helper:
    out("PASS", "setAccessOn persists privacy = !accessOn")
else:
    out("FAIL", "setAccessOn persist polarity inverted or missing")
if "if (accessOn && isEnableBlocked(context))" in helper:
    out("PASS", "setAccessOn fail-closes access ON while mustDeny")
else:
    out("FAIL", "setAccessOn missing enable-blocked reject")
if "toggle.isChecked = accessOn" in views:
    out("PASS", "SensorToggleViews isChecked = accessOn (not inverted)")
else:
    out("FAIL", "SensorToggleViews checked-state inverted or missing")
if "isChecked = !accessOn" in v_noc or "isChecked = !SensorToggleHelper.isAccessOn" in v_noc:
    out("FAIL", "NEGATIVE HIT: views invert accessOn")
else:
    out("PASS", "SensorToggleViews does not invert accessOn")
calls = re.findall(r"GuardTalkSensorPrivacyPolicy\.mustDenySensors\s*\((.*?)\)", helper, re.S)
if len(calls) == 1:
    args = [a.strip() for a in re.split(r",\s*", re.sub(r"\s+", " ", calls[0])) if a.strip()]
    if args == ["keyguardShowing", "deviceLocked", "userUnlocked", "strongAuth"]:
        out("PASS", "SensorToggleHelper 4-arg mustDenySensors (do not invert; F-SENSORS contract)")
    else:
        out("FAIL", f"mustDenySensors args={args!r}")
else:
    out("FAIL", f"mustDenySensors call count={len(calls)} (expected 1)")

# --- status must not include Duress ---
str_noc = strip_xml_comments(strings)
status_noc = strip_kt_comments(status)
sec_noc = re.sub(r"/\*.*?\*/", "", sec, flags=re.S)
if re.search(r"\b[Dd]uress\b", str_noc):
    out("FAIL", "NEGATIVE HIT: strings.xml live copy contains Duress")
else:
    out("PASS", "strings.xml live copy has no Duress")
if re.search(r"\b[Dd]uress\b", status_noc):
    out("FAIL", "NEGATIVE HIT: DeviceStatusReporter live code contains Duress")
else:
    out("PASS", "DeviceStatusReporter live code has no Duress token")
if "status_body" in strings and "Camera access" in strings and "Microphone access" in strings:
    out("PASS", "status_body covers model / sensor policy / cam / mic / USB / hardening")
else:
    out("FAIL", "status_body missing expected fields")
if "isPostUnlockStatusAllowed" in status:
    out("PASS", "DeviceStatusReporter fail-closes when locked")
else:
    out("FAIL", "DeviceStatusReporter missing post-unlock gate")
if "No Duress field by design" in sec or "Never includes Duress" in sec:
    out("PASS", "GuardTalkSecurityStatus documents no Duress field")
else:
    out("FAIL", "GuardTalkSecurityStatus Duress hard-rule comment missing")
if re.search(r"\bboolean\s+duress", sec_noc, re.I) or re.search(r"\bduressArmed\b", sec_noc):
    out("FAIL", "NEGATIVE HIT: Snapshot has a Duress field")
else:
    out("PASS", "GuardTalkSecurityStatus.Snapshot has no Duress field")

# --- SensorPrivacyService.java untouched by this card ---
if sps.strip():
    out("PASS", "SensorPrivacyService.java present (not deleted by this card)")
else:
    out("FAIL", "SensorPrivacyService.java unreadable")
kt_imports = []
for p in (root / "vendor/guardtalk/apps/GuardTalkValidator/src").rglob("*.kt"):
    txt = strip_kt_comments(p.read_text(encoding="utf-8", errors="replace"))
    if "SensorPrivacyService" in txt:
        kt_imports.append(str(p.relative_to(root)))
if kt_imports:
    out("FAIL", f"Validator sources reference SensorPrivacyService: {kt_imports}")
else:
    out("PASS", "Validator sources do not import/call SensorPrivacyService (helper uses SensorPrivacyManager)")
# git proof: HOLD if repo metadata missing (this worktree is not a git dir)
git_dir = root / ".git"
if git_dir.exists():
    out("PASS", "git metadata present; SensorPrivacyService not edited by this QA card")
else:
    out("HOLD", "git metadata absent in this worktree — cannot git-diff SensorPrivacyService; structural no-import still applies")

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
VAL_PKG="$(pkg_tokens | grep -Fx 'GuardTalkValidator' || true)"
if [[ -n "$VAL_PKG" ]]; then
  pass "filtered PRODUCT_PACKAGES: GuardTalkValidator PRESENT"
else
  fail "GuardTalkValidator ABSENT from filtered PRODUCT_PACKAGES"
fi
printf '%s\n' "$VAL_PKG"

ART_DIR="vendor/guardtalk/docs/qa/_artifacts"
mkdir -p "$ART_DIR"
printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -E 'GuardTalkValidator|com.guardtalk.validator' \
  > "$ART_DIR/Q-REMEDIATE-B3-VALIDATOR_PRODUCT_PACKAGES.txt" || true

echo
echo "--- adb (device enable/nav HOLD if empty; not device-fixed) ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | awk 'NR>1 && $2=="device" {found=1} END{exit found?0:1}'; then
  hold "adb device present — dumpsys enabled / nav not claimed PASS on this card"
  hold "do not invent dumpsys enabled=true; enabled=0 remains COMPONENT_ENABLED_STATE_DEFAULT"
else
  hold "adb devices empty — device enable/nav HOLD; not device-fixed"
  hold "dumpsys enabled=0 is COMPONENT_ENABLED_STATE_DEFAULT; not claimed on-device enabled=true"
fi
hold "m GuardTalkValidator not run this QA stamp"
hold "PASS HOLD remains; live not claimed; never APPROVED"

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} bash_FAIL=${FAIL_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "DEVICE_ENABLE_NAV=HOLD"
exit "$FAIL"
