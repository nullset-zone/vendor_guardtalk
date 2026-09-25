#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B3-SENSORS (item 17).
# Pair of T-REMEDIATE-B3-SENSORS + F-REMEDIATE-B3-SENSORS.
# Do not trust Backend / Frontend / Architect reports.
# Host static + lunch. Device QS tile visibility HOLD if adb empty.
# Do NOT fold OS-UX on-device proof (Q-REMEDIATE-B3-OSUX-DEVICE, BLOCKED).
# No product edits. No USB GO. No wipe. No commit. Never APPROVED.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b3_sensors_host.sh
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

FB_OV="vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay/res/values/config.xml"
QS_OV="vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml"
APPS_EX="vendor/guardtalk/feature-excised/apps-excised.mk"
FEAT_OV="vendor/guardtalk/feature-excised/feature-overlays.mk"
TEL_MK="vendor/guardtalk/radio-excised/telephony-features.mk"
SERVICE="frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java"
HOOKS="frameworks/base/services/core/java/com/android/server/sensorprivacy/GuardTalkSensorPrivacyHooks.java"
POLICY="frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java"
HELPER="vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SensorToggleHelper.kt"
VIEWS="vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SensorToggleViews.kt"
MENU="vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/EscapeMenu.kt"
SETTINGS_CTRL="packages/apps/Settings/src/com/android/settings/privacy/SensorToggleController.java"
SETTINGS_HELP="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSensorPrivacyHelper.java"
AOSP_CFG="frameworks/base/core/res/res/values/config.xml"
CAM_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/CameraToggleTile.java"
MIC_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/MicrophoneToggleTile.java"
QS_PARENT="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/SensorPrivacyToggleTile.java"
POLICY_MOD="frameworks/base/packages/SystemUI/src/com/android/systemui/statusbar/policy/PolicyModule.kt"
PRIVAPP="vendor/guardtalk/apps/GuardTalkValidator/privapp-permissions-com.guardtalk.validator.xml"
VAL_BP="vendor/guardtalk/apps/GuardTalkValidator/Android.bp"
VAL_MAN="vendor/guardtalk/apps/GuardTalkValidator/AndroidManifest.xml"

echo "=== Q-REMEDIATE-B3-SENSORS independent rematch (item 17) ==="
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
require_file "$FB_OV"
require_file "$QS_OV"
require_file "$APPS_EX"
require_file "$FEAT_OV"
require_file "$TEL_MK"
require_file "$SERVICE"
require_file "$HOOKS"
require_file "$POLICY"
require_file "$HELPER"
require_file "$VIEWS"
require_file "$MENU"
require_file "$SETTINGS_CTRL"
require_file "$SETTINGS_HELP"
require_file "$AOSP_CFG"
require_file "$CAM_TILE"
require_file "$MIC_TILE"
require_file "$QS_PARENT"
require_file "$POLICY_MOD"
require_file "$PRIVAPP"
require_file "$VAL_BP"
require_file "$VAL_MAN"

echo
echo "--- packet rg (overlay bools / QS specs / Pixel overlay) ---"
rg -n "config_supportsMicToggle|config_supportsCamToggle|PixelConfigOverlayCommon" \
  "$FB_OV" "$APPS_EX" || true
echo
rg -n "mictoggle|cameratoggle|lockdown" "$QS_OV" || true
echo
echo "--- packet rg (allowToggleChange / mustDenySensors / polarity) ---"
rg -n "allowToggleChange|ownsLockToggleAuthority|mustDenySensors|isSensorPrivacyEnabled|setSensorPrivacy|accessOn" \
  "$SERVICE" "$HOOKS" "$HELPER" "$SETTINGS_CTRL" || true
echo

echo "--- python structural rematch ---"
set +e
python3 - "$ROOT" <<'PY'
import re
import subprocess
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

def strip_comments_code(src):
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"//.*?$", "", src, flags=re.M)
    return src

def bools_from_overlay(src):
    noc = strip_xml_comments(src)
    found = {}
    for name, val in re.findall(
        r'<bool\s+name="([^"]+)"\s*>(true|false)</bool>', noc
    ):
        found[name] = val
    return found, noc

def qs_tokens(src, name):
    noc = strip_xml_comments(src)
    m = re.search(
        rf'<string\s+name="{re.escape(name)}"[^>]*>(.*?)</string>',
        noc,
        re.S,
    )
    if not m:
        return None
    body = re.sub(r"\s+", "", m.group(1))
    return [t for t in body.split(",") if t]

fb = read("vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay/res/values/config.xml")
qs = read("vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml")
apps = read("vendor/guardtalk/feature-excised/apps-excised.mk")
feat = read("vendor/guardtalk/feature-excised/feature-overlays.mk")
tel = read("vendor/guardtalk/radio-excised/telephony-features.mk")
service = read(
    "frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java"
)
hooks = read(
    "frameworks/base/services/core/java/com/android/server/sensorprivacy/GuardTalkSensorPrivacyHooks.java"
)
policy = read("frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java")
helper = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SensorToggleHelper.kt")
views = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/SensorToggleViews.kt")
menu = read("vendor/guardtalk/apps/GuardTalkValidator/src/com/guardtalk/validator/EscapeMenu.kt")
ctrl = read("packages/apps/Settings/src/com/android/settings/privacy/SensorToggleController.java")
shelp = read(
    "packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSensorPrivacyHelper.java"
)
aosp = read("frameworks/base/core/res/res/values/config.xml")
cam = read("frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/CameraToggleTile.java")
mic = read("frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/MicrophoneToggleTile.java")
parent = read(
    "frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/SensorPrivacyToggleTile.java"
)
pmod = read("frameworks/base/packages/SystemUI/src/com/android/systemui/statusbar/policy/PolicyModule.kt")
priv = read("vendor/guardtalk/apps/GuardTalkValidator/privapp-permissions-com.guardtalk.validator.xml")
vbp = read("vendor/guardtalk/apps/GuardTalkValidator/Android.bp")
vman = read("vendor/guardtalk/apps/GuardTalkValidator/AndroidManifest.xml")

# --- overlay bools: live XML, not comments ---
fb_bools, fb_noc = bools_from_overlay(fb)
if fb_bools.get("config_supportsMicToggle") == "true":
    out("PASS", "GuardTalkFrameworksBaseOverlay config_supportsMicToggle=true (live bool, not comment)")
else:
    out("FAIL", f"config_supportsMicToggle live value={fb_bools.get('config_supportsMicToggle')!r} (comments-only is FAIL)")
if fb_bools.get("config_supportsCamToggle") == "true":
    out("PASS", "GuardTalkFrameworksBaseOverlay config_supportsCamToggle=true (live bool, not comment)")
else:
    out("FAIL", f"config_supportsCamToggle live value={fb_bools.get('config_supportsCamToggle')!r} (comments-only is FAIL)")

# Comments may mention true; that is not enough.
if "config_supportsMicToggle" in fb and "true" in fb:
    if fb_bools.get("config_supportsMicToggle") != "true":
        out("FAIL", "NEGATIVE HIT: MicToggle true only in comments")
    else:
        out("PASS", "MicToggle true is a live <bool>, not comment-only")
if "config_supportsCamToggle" in fb and "true" in fb:
    if fb_bools.get("config_supportsCamToggle") != "true":
        out("FAIL", "NEGATIVE HIT: CamToggle true only in comments")
    else:
        out("PASS", "CamToggle true is a live <bool>, not comment-only")

# Hardware toggles stay false / unset in GuardTalk overlay
for hw in ("config_supportsHardwareMicToggle", "config_supportsHardwareCamToggle"):
    if fb_bools.get(hw) == "true":
        out("FAIL", f"overlay restores {hw}=true (hardware toggle must stay false)")
    else:
        out("PASS", f"overlay does not set {hw}=true")

# Do not restore Pixel fingerprint true
if fb_bools.get("config_fingerprintSupportsGestures") == "true":
    out("FAIL", "overlay restores Pixel config_fingerprintSupportsGestures=true")
else:
    out("PASS", "overlay does not restore Pixel fingerprint-gestures=true")

# AOSP defaults remain false (overlay is the restore, not AOSP rewrite)
aosp_bools, _ = bools_from_overlay(aosp)
if aosp_bools.get("config_supportsMicToggle") == "false" and aosp_bools.get("config_supportsCamToggle") == "false":
    out("PASS", "AOSP framework-res still defaults both SW toggles false (overlay must supply true)")
else:
    out("FAIL", f"AOSP defaults unexpected: mic={aosp_bools.get('config_supportsMicToggle')} cam={aosp_bools.get('config_supportsCamToggle')}")

# --- QS lead ---
for name in ("quick_settings_tiles_new_default", "quick_settings_tiles_default"):
    toks = qs_tokens(qs, name)
    if toks is None:
        out("FAIL", f"{name} missing from GuardTalkSystemUIOverlay")
        continue
    if toks[:2] == ["mictoggle", "cameratoggle"]:
        out("PASS", f"{name} leads with mictoggle,cameratoggle ({len(toks)} tokens)")
    else:
        out("FAIL", f"{name} does not lead with mictoggle,cameratoggle (head={toks[:4]!r})")
    if "lockdown" in toks:
        out("FAIL", f"{name} contains lockdown tile")
    else:
        out("PASS", f"{name} has no lockdown tile")

stock = qs_tokens(qs, "quick_settings_tiles_stock")
if stock is None:
    out("FAIL", "quick_settings_tiles_stock missing")
else:
    if "mictoggle" in stock and "cameratoggle" in stock:
        out("PASS", "stock catalog still lists mictoggle and cameratoggle")
    else:
        out("FAIL", f"stock catalog missing mictoggle/cameratoggle: {stock}")
    if "lockdown" in stock:
        out("FAIL", "stock catalog contains lockdown tile")
    else:
        out("PASS", "stock catalog has no lockdown tile")

# --- Pixel overlay drop / GuardTalk keep ---
# Drop list: PixelConfigOverlayCommon as its own token (backslash-newline safe)
drop_line = re.sub(r"\\\n", " ", apps)
# GUARDTALK_APPS_PACKAGES += block that contains PixelConfigOverlayCommon
if re.search(r"\bPixelConfigOverlayCommon\b", apps):
    out("PASS", "apps-excised.mk lists PixelConfigOverlayCommon in drop set")
else:
    out("FAIL", "PixelConfigOverlayCommon not in apps-excised drop set")
keep_m = re.search(r"^GUARDTALK_OVERLAY_KEEP\s*:=(.*?)(?=^\S|\Z)", apps, re.S | re.M)
keep_blob = keep_m.group(1) if keep_m else ""
if re.search(r"\bPixelConfigOverlayCommon\b", keep_blob):
    out("FAIL", "PixelConfigOverlayCommon is in GUARDTALK_OVERLAY_KEEP (would be restored)")
else:
    out("PASS", "PixelConfigOverlayCommon is not in GUARDTALK_OVERLAY_KEEP")
if re.search(r"\bGuardTalkFrameworksBaseOverlay\b", keep_blob) and re.search(
    r"\bGuardTalkSystemUIOverlay\b", keep_blob
):
    out("PASS", "KEEP list includes GuardTalkFrameworksBaseOverlay and GuardTalkSystemUIOverlay")
else:
    out("FAIL", "GuardTalk overlays missing from GUARDTALK_OVERLAY_KEEP")

if "PRODUCT_PACKAGES += GuardTalkSystemUIOverlay" in feat or "GuardTalkSystemUIOverlay" in feat:
    out("PASS", "feature-overlays.mk still wires GuardTalkSystemUIOverlay")
else:
    out("FAIL", "feature-overlays.mk missing GuardTalkSystemUIOverlay")
if "GuardTalkFrameworksBaseOverlay" in tel:
    out("PASS", "telephony-features.mk still wires GuardTalkFrameworksBaseOverlay")
else:
    out("FAIL", "telephony-features.mk missing GuardTalkFrameworksBaseOverlay")

# --- SensorPrivacyService lock semantics UNTOUCHED ---
svc_noc = strip_comments_code(service)
if "mGuardTalkHooks.allowToggleChange(userId, enable)" in service:
    out("PASS", "setToggleSensorPrivacy still consults allowToggleChange(userId, enable)")
else:
    out("FAIL", "setToggleSensorPrivacy allowToggleChange call missing or rewritten")
if "allowToggleChange(userId, state != DISABLED)" in service:
    out("PASS", "setToggleSensorPrivacyState still consults allowToggleChange")
else:
    out("FAIL", "setToggleSensorPrivacyState allowToggleChange rewritten")
if "Can't change mic/cam toggle while device is locked" in service:
    out("PASS", "stock isDeviceLocked drop log still present (non-GuardTalk path)")
else:
    out("FAIL", "stock isDeviceLocked drop log missing (lock semantics rewritten)")
if "mGuardTalkHooks == null || !mGuardTalkHooks.ownsLockToggleAuthority()" in service:
    out("PASS", "lock blanket still skipped iff ownsLockToggleAuthority (T-OS-CAMMIC)")
else:
    out("FAIL", "ownsLockToggleAuthority skip rewritten")
if "Can't change mic toggle during an emergency call" in service:
    out("PASS", "emergency-call mic block still present")
else:
    out("FAIL", "emergency-call mic block missing")
if "DISALLOW_MICROPHONE_TOGGLE" in service and "DISALLOW_CAMERA_TOGGLE" in service:
    out("PASS", "DISALLOW_*_TOGGLE still present")
else:
    out("FAIL", "DISALLOW_*_TOGGLE missing")

# Order inside canChangeToggleSensorPrivacy only (file-wide first-hit is a false FAIL).
ccm = re.search(
    r"private boolean canChangeToggleSensorPrivacy\([^)]*\) \{.*?\n        \}",
    service,
    re.S,
)
if not ccm:
    out("FAIL", "canChangeToggleSensorPrivacy not extracted")
else:
    body = ccm.group(0)
    idx_emerg = body.find("isInEmergencyCall")
    idx_lock = body.find("isDeviceLocked")
    idx_owns = body.find("ownsLockToggleAuthority")
    idx_mic = body.find("DISALLOW_MICROPHONE_TOGGLE")
    idx_cam = body.find("DISALLOW_CAMERA_TOGGLE")
    if -1 not in (idx_emerg, idx_lock, idx_owns, idx_mic, idx_cam) and idx_emerg < idx_lock < idx_owns < idx_mic < idx_cam:
        out("PASS", "canChangeToggleSensorPrivacy order: emergency → lock skip → DISALLOW mic/cam")
    else:
        out("FAIL", "canChangeToggleSensorPrivacy lock-order rewritten")

# hooks.allowToggleChange still 4-arg allowUserToggle
if "GuardTalkSensorPrivacyPolicy.allowUserToggle(" in hooks and "enablePrivacy, keyguardShowing, deviceLocked, userUnlocked, flags" in hooks:
    out("PASS", "hooks.allowToggleChange still 4-arg allowUserToggle (T-OS-CAMMIC)")
else:
    out("FAIL", "hooks.allowToggleChange rewritten")

# 4-arg mustDeny unused deviceLocked
m4 = re.search(
    r"public static boolean mustDenySensors\(\s*boolean keyguardShowing,\s*boolean deviceLocked,\s*boolean userUnlocked,\s*int strongAuthFlags\) \{.*?\n    \}",
    policy,
    re.S,
)
if not m4:
    out("FAIL", "4-arg mustDenySensors not extracted from policy")
else:
    nocomment = strip_comments_code(m4.group(0))
    inner = nocomment[nocomment.find("{") :]
    if re.findall(r"\bdeviceLocked\b", inner):
        out("FAIL", "4-arg mustDenySensors body still uses deviceLocked")
    else:
        out("PASS", "4-arg mustDenySensors does not OR stale deviceLocked")
    if "return keyguardShowing;" in m4.group(0) and "isLockdownActive" in m4.group(0):
        out("PASS", "4-arg deny = lockdown | !userUnlocked | keyguardShowing")
    else:
        out("FAIL", "4-arg deny formula rewritten")

# git: service/hooks must not be rewritten this wave
def git_diff(paths):
    cmd = [
        "git",
        "-c",
        f"safe.directory={root}",
        "diff",
        "--name-only",
        "HEAD",
        "--",
        *paths,
    ]
    try:
        r = subprocess.run(cmd, cwd=root, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as e:
        out("HOLD", f"git diff unavailable ({e}); structural rematch still applies")
        return None
    if r.returncode != 0:
        out("HOLD", f"git diff rc={r.returncode}: {r.stderr.strip()[:200]}")
        return None
    names = [ln.strip() for ln in r.stdout.splitlines() if ln.strip()]
    return names

touched = git_diff(
    [
        "frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java",
        "frameworks/base/services/core/java/com/android/server/sensorprivacy/GuardTalkSensorPrivacyHooks.java",
        "frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java",
    ]
)
if touched is None:
    pass
elif not touched:
    out("PASS", "git diff HEAD empty for SensorPrivacyService + hooks + policy (T-OS-CAMMIC lineage uncommitted-untouched)")
else:
    out("FAIL", f"T-OS-CAMMIC lock files have working-tree diffs (must not rewrite): {touched}")

# --- Validator helper polarity + 4-arg ---
h_noc = strip_comments_code(helper)
if "!spm.isSensorPrivacyEnabled(sensor)" in helper or "!spm.isSensorPrivacyEnabled(sensor)" in h_noc:
    out("PASS", "SensorToggleHelper isAccessOn = !isSensorPrivacyEnabled (Settings polarity)")
else:
    out("FAIL", "isAccessOn polarity inverted or missing")
# adversarial invert
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

# 4-arg call site, not 3-arg, not strongAuth=0
calls = re.findall(
    r"GuardTalkSensorPrivacyPolicy\.mustDenySensors\s*\((.*?)\)",
    helper,
    re.S,
)
if len(calls) != 1:
    out("FAIL", f"mustDenySensors call count={len(calls)} (expected 1)")
else:
    args = [a.strip() for a in re.split(r",\s*", re.sub(r"\s+", " ", calls[0])) if a.strip()]
    if len(args) == 4 and args == ["keyguardShowing", "deviceLocked", "userUnlocked", "strongAuth"]:
        out("PASS", "SensorToggleHelper 4-arg mustDenySensors(keyguardShowing, deviceLocked, userUnlocked, strongAuth)")
    else:
        out("FAIL", f"mustDenySensors args={args!r} (do not invert; must be 4-arg)")
    if "strongAuth=0" in helper.replace(" ", "") or re.search(r"mustDenySensors\([^)]*0\s*\)", helper):
        out("FAIL", "mustDenySensors still hardcodes strongAuth=0 (skips lockdown)")
    else:
        out("PASS", "mustDenySensors uses getStrongAuthForUser (not strongAuth=0)")

if "LockPatternUtils(context).getStrongAuthForUser(userId)" in helper:
    out("PASS", "helper reads strongAuth via LockPatternUtils")
else:
    out("FAIL", "helper missing LockPatternUtils.getStrongAuthForUser")

# Views must not invert checked state
if "toggle.isChecked = accessOn" in views:
    out("PASS", "SensorToggleViews isChecked = accessOn (not inverted)")
else:
    out("FAIL", "SensorToggleViews checked-state inverted or missing")
if "toggle.isChecked = !accessOn" in views or "isChecked = !SensorToggleHelper.isAccessOn" in views:
    out("FAIL", "NEGATIVE HIT: views invert accessOn")
else:
    out("PASS", "SensorToggleViews does not invert accessOn")
if "SensorToggleHelper.setAccessOn(context, sensor, isChecked)" in views:
    out("PASS", "views persist via setAccessOn(..., isChecked)")
else:
    out("FAIL", "views persist wiring missing")
if "blocked && !accessOn" in views:
    out("PASS", "views disable OFF→ON while mustDeny (access still off)")
else:
    out("FAIL", "views missing fail-closed disable when blocked && !accessOn")

if "SensorToggleViews.bind" in menu:
    out("PASS", "EscapeMenu binds SensorToggleViews (in-app toggles)")
else:
    out("FAIL", "EscapeMenu does not bind SensorToggleViews")

# Settings polarity (do not invert)
if "return !mSensorPrivacyManagerHelper.isSensorBlocked(getSensor());" in ctrl:
    out("PASS", "Settings SensorToggleController isChecked = !isSensorBlocked")
else:
    out("FAIL", "Settings isChecked polarity rewritten")
if "setSensorBlocked(getSensor(), !isChecked)" in ctrl:
    out("PASS", "Settings setChecked persists blocked = !isChecked")
else:
    out("FAIL", "Settings setChecked polarity inverted")
if "GuardTalkSensorPrivacyHelper.isSensorEnableBlocked" in ctrl:
    out("PASS", "Settings still fail-closes enable via GuardTalk helper")
else:
    out("FAIL", "Settings enable-blocked path missing")

# Settings helper 4-arg
if "GuardTalkSensorPrivacyPolicy.mustDenySensors(\n                keyguardShowing, deviceLocked, userUnlocked, strongAuth)" in shelp or \
   "mustDenySensors(\n                keyguardShowing, deviceLocked, userUnlocked, strongAuth)" in shelp:
    out("PASS", "Settings helper 4-arg mustDenySensors (same polarity contract)")
elif "mustDenySensors(" in shelp and "keyguardShowing, deviceLocked, userUnlocked, strongAuth" in shelp:
    out("PASS", "Settings helper 4-arg mustDenySensors (same polarity contract)")
else:
    out("FAIL", "Settings helper 4-arg mustDenySensors missing")

# QS tiles still registered + isAvailable gated on supportsSensorToggle
if 'TILE_SPEC = "cameratoggle"' in cam and "supportsSensorToggle(CAMERA)" in cam:
    out("PASS", "CameraToggleTile TILE_SPEC=cameratoggle; isAvailable uses supportsSensorToggle")
else:
    out("FAIL", "CameraToggleTile registration/availability rewritten")
if 'TILE_SPEC = "mictoggle"' in mic and "supportsSensorToggle(MICROPHONE)" in mic:
    out("PASS", "MicrophoneToggleTile TILE_SPEC=mictoggle; isAvailable uses supportsSensorToggle")
else:
    out("FAIL", "MicrophoneToggleTile registration/availability rewritten")
if 'CAMERA_TOGGLE_TILE_SPEC = "cameratoggle"' in pmod and 'MIC_TOGGLE_TILE_SPEC = "mictoggle"' in pmod:
    out("PASS", "PolicyModule still registers cameratoggle/mictoggle")
else:
    out("FAIL", "PolicyModule tile specs missing")
if "state.value = !isBlocked" in parent:
    out("PASS", "QS tile value = !isBlocked (access ON = privacy OFF)")
else:
    out("FAIL", "QS tile polarity inverted")

# supportsSensorToggle reads overlay bools
if "R.bool.config_supportsMicToggle" in service and "R.bool.config_supportsCamToggle" in service:
    out("PASS", "SensorPrivacyService.supportsSensorToggle still reads overlay SW bools")
else:
    out("FAIL", "supportsSensorToggle resource wiring missing")

# Validator permissions
if "android.permission.MANAGE_SENSOR_PRIVACY" in vman and "OBSERVE_SENSOR_PRIVACY" in vman:
    out("PASS", "Validator manifest requests MANAGE/OBSERVE_SENSOR_PRIVACY")
else:
    out("FAIL", "Validator manifest missing sensor privacy permissions")
if "android.permission.MANAGE_SENSOR_PRIVACY" in priv and "OBSERVE_SENSOR_PRIVACY" in priv:
    out("PASS", "Validator privapp whitelist grants MANAGE/OBSERVE_SENSOR_PRIVACY")
else:
    out("FAIL", "Validator privapp whitelist missing sensor privacy grants")
if "platform_apis: true" in vbp:
    out("PASS", "GuardTalkValidator Android.bp platform_apis: true")
else:
    out("FAIL", "GuardTalkValidator missing platform_apis")

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

# pipefail + grep -q SIGPIPE is a false ABSENT when the token is early.
# Strip CR / nsjail chatter; match exact tokens only.
gt_pkg_tokens() {
  printf '%s\n' "$PKGS" | tr -d '\r' | tr ' \t' '\n' | grep -E '^[A-Za-z0-9._-]+$' || true
}

echo "--- filtered PRODUCT_PACKAGES overlay presence ---"
TOKENS="$(gt_pkg_tokens)"
if printf '%s\n' "$TOKENS" | grep -Fx -- "GuardTalkFrameworksBaseOverlay" >/dev/null; then
  pass "filtered PRODUCT_PACKAGES: GuardTalkFrameworksBaseOverlay PRESENT"
else
  fail "GuardTalkFrameworksBaseOverlay ABSENT from filtered PRODUCT_PACKAGES"
fi
if printf '%s\n' "$TOKENS" | grep -Fx -- "GuardTalkSystemUIOverlay" >/dev/null; then
  pass "filtered PRODUCT_PACKAGES: GuardTalkSystemUIOverlay PRESENT"
else
  fail "GuardTalkSystemUIOverlay ABSENT from filtered PRODUCT_PACKAGES"
fi
if printf '%s\n' "$TOKENS" | grep -Fx -- "PixelConfigOverlayCommon" >/dev/null; then
  fail "NEGATIVE HIT: PixelConfigOverlayCommon PRESENT in filtered PRODUCT_PACKAGES"
else
  pass "filtered PRODUCT_PACKAGES: PixelConfigOverlayCommon ABSENT"
fi
if printf '%s\n' "$TOKENS" | grep -Fx -- "GuardTalkValidator" >/dev/null; then
  pass "filtered PRODUCT_PACKAGES: GuardTalkValidator PRESENT (in-app toggles ship)"
else
  fail "GuardTalkValidator ABSENT from filtered PRODUCT_PACKAGES"
fi

# Show the matching lines for the evidence log
printf '%s\n' "$PKGS" | tr ' ' '\n' | grep -E '^(GuardTalkFrameworksBaseOverlay|GuardTalkSystemUIOverlay|PixelConfigOverlayCommon|GuardTalkValidator)$' || true

echo
echo "--- adb (device tile visibility HOLD if empty; not device-fixed) ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | awk 'NR>1 && $2=="device" {found=1} END{exit found?0:1}'; then
  hold "adb device present — QS tile visibility / dumpsys sensor_privacy not claimed PASS on this card; Q-REMEDIATE-B3-OSUX-DEVICE owns on-device proof"
  hold "this card does not lift PASS HOLD; not device-fixed"
else
  hold "adb devices empty — device tile visibility HOLD; not device-fixed"
  hold "Q-REMEDIATE-B3-OSUX-DEVICE remains BLOCKED; OS-UX on-device proof not folded here"
fi
hold "m not run this QA stamp (QS APK not rebuilt here)"
hold "PASS HOLD remains; live not claimed"

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} bash_FAIL=${FAIL_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "DEVICE_TILE_VISIBILITY=HOLD"
echo "OSUX_DEVICE_PROOF=not folded (Q-REMEDIATE-B3-OSUX-DEVICE BLOCKED)"
exit "$FAIL"
