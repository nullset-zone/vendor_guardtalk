#!/usr/bin/env bash
# Independent rematch for Q-OS-CAMMIC-SETTINGS (pair of F-OS-CAMMIC-SETTINGS).
# Do not trust Frontend/Architect reports. Host static + truth-table only.
# Device Settings/QS vs dumpsys HOLD if adb empty. No USB. No product edits.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_os_cammic_settings_static.sh
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

HELPER="packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSensorPrivacyHelper.java"
CAM_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/CameraToggleTile.java"
MIC_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/MicrophoneToggleTile.java"
CTRL="packages/apps/Settings/src/com/android/settings/privacy/SensorToggleController.java"
FRAG="packages/apps/Settings/src/com/android/settings/privacy/PrivacyControlsFragment.java"
XML="packages/apps/Settings/res/xml/privacy_controls_settings.xml"
PREF="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSensorPrivacyPreferenceController.java"
CAM_CTRL="packages/apps/Settings/src/com/android/settings/privacy/CameraToggleController.java"
MIC_CTRL="packages/apps/Settings/src/com/android/settings/privacy/MicToggleController.java"
POLICY="frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java"
MANIFEST="packages/apps/Settings/AndroidManifest.xml"
SETTINGS_JAVA="frameworks/base/core/java/android/provider/Settings.java"
QS_PARENT="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/SensorPrivacyToggleTile.java"
ADEVTOOL="vendor/google_devices/tokay/adevtool-version-check.mk"

echo "=== Q-OS-CAMMIC-SETTINGS independent rematch ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo

echo "=== RAW: packet rg setSensorBlocked|isSensorBlocked|setChecked|privacy_*_toggle ==="
rg -n "setSensorBlocked|isSensorBlocked|setChecked|privacy_camera_toggle|privacy_mic_toggle" \
  packages/apps/Settings/src/com/android/settings/privacy/ \
  packages/apps/Settings/res/xml/privacy_controls_settings.xml || true
echo

echo "=== RAW: packet rg mustDenySensors(|isKeyguardLocked Helper + QS tiles ==="
rg -n "mustDenySensors\\(|isKeyguardLocked" \
  "$HELPER" "$CAM_TILE" "$MIC_TILE" || true
echo

echo "=== RAW: adb devices ==="
ADB_OUT="$(adb devices 2>&1 || true)"
printf '%s\n' "$ADB_OUT"
echo

python3 - "$ROOT" <<'PY'
import re
import subprocess
import sys
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

HELPER = root / "packages/apps/Settings/src/com/android/settings/guardtalk/GuardTalkSensorPrivacyHelper.java"
CAM_TILE = root / "frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/CameraToggleTile.java"
MIC_TILE = root / "frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/MicrophoneToggleTile.java"
CTRL = root / "packages/apps/Settings/src/com/android/settings/privacy/SensorToggleController.java"
FRAG = root / "packages/apps/Settings/src/com/android/settings/privacy/PrivacyControlsFragment.java"
XML = root / "packages/apps/Settings/res/xml/privacy_controls_settings.xml"
PREF = root / "packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkSensorPrivacyPreferenceController.java"
CAM_CTRL = root / "packages/apps/Settings/src/com/android/settings/privacy/CameraToggleController.java"
MIC_CTRL = root / "packages/apps/Settings/src/com/android/settings/privacy/MicToggleController.java"
POLICY = root / "frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java"
MANIFEST = root / "packages/apps/Settings/AndroidManifest.xml"
SETTINGS_JAVA = root / "frameworks/base/core/java/android/provider/Settings.java"
QS_PARENT = root / "frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/SensorPrivacyToggleTile.java"
HOOKS = root / "frameworks/base/services/core/java/com/android/server/sensorprivacy/GuardTalkSensorPrivacyHooks.java"
SERVICE = root / "frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java"

for p in (HELPER, CAM_TILE, MIC_TILE, CTRL, FRAG, XML, PREF, CAM_CTRL, MIC_CTRL, POLICY):
    if p.is_file():
        out("PASS", f"present: {p.relative_to(root)}")
    else:
        out("FAIL", f"missing: {p.relative_to(root)}")

def read(p: Path) -> str:
    return p.read_text(encoding="utf-8") if p.is_file() else ""

def strip_comments(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"//.*?$", "", src, flags=re.M)
    return src

def extract_method(src: str, sig: str):
    """Return innermost body of the first method whose signature matches sig."""
    m = re.search(sig, src)
    if not m:
        return None
    start = src.find("{", m.end() - 1)
    if start < 0:
        return None
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start + 1 : i]
    return None

def method_calls(src: str, name: str):
    """Return list of (args_text, arg_list) for name(...) call sites (not defs)."""
    noc = strip_comments(src)
    calls = []
    i = 0
    while True:
        j = noc.find(name + "(", i)
        if j < 0:
            break
        if j > 0 and (noc[j - 1].isalnum() or noc[j - 1] in "_"):
            i = j + 1
            continue
        # skip method definitions: preceding token 'boolean' / 'void' nearby
        pre = noc[max(0, j - 80):j]
        if re.search(r"\b(boolean|void|int|public|private|protected|static)\s+$", pre):
            i = j + len(name) + 1
            continue
        k = j + len(name)
        args_start = k + 1
        depth = 1
        p = args_start
        while p < len(noc) and depth:
            if noc[p] == "(":
                depth += 1
            elif noc[p] == ")":
                depth -= 1
            p += 1
        args = noc[args_start : p - 1]
        parts, cur, d = [], [], 0
        for ch in args:
            if ch == "(":
                d += 1
                cur.append(ch)
            elif ch == ")":
                d -= 1
                cur.append(ch)
            elif ch == "," and d == 0:
                tok = "".join(cur).strip()
                if tok:
                    parts.append(tok)
                cur = []
            else:
                cur.append(ch)
        tok = "".join(cur).strip()
        if tok:
            parts.append(tok)
        calls.append((re.sub(r"\s+", " ", args).strip(), parts))
        i = p
    return calls

# --- 4-arg mustDeny in Helper + both QS tiles; no 3-arg leftover ---
THREE = (HELPER, CAM_TILE, MIC_TILE)
for p in THREE:
    src = read(p)
    rel = p.relative_to(root)
    if "isKeyguardLocked()" not in src:
        out("FAIL", f"{rel}: missing isKeyguardLocked()")
    else:
        out("PASS", f"{rel}: isKeyguardLocked() present")
    if not re.search(r"keyguardShowing\s*=\s*.*isKeyguardLocked\(\)", src):
        out("FAIL", f"{rel}: keyguardShowing not bound to isKeyguardLocked()")
    else:
        out("PASS", f"{rel}: keyguardShowing = isKeyguardLocked()")
    calls = method_calls(src, "mustDenySensors")
    if not calls:
        out("FAIL", f"{rel}: no mustDenySensors call")
        continue
    leftover3 = False
    for args, parts in calls:
        if len(parts) != 4:
            leftover3 = True
            out("FAIL", f"{rel}: mustDenySensors argcount={len(parts)} (want 4) args={args}")
            continue
        first = parts[0]
        if first != "keyguardShowing":
            leftover3 = True
            out("FAIL", f"{rel}: 4-arg first param is {first!r}, not keyguardShowing")
            continue
        if parts[1] != "deviceLocked":
            out("FAIL", f"{rel}: 2nd arg is {parts[1]!r}, not deviceLocked")
            continue
        out("PASS", f"{rel}: 4-arg mustDenySensors(keyguardShowing, deviceLocked, …)")
    if leftover3:
        out("FAIL", f"{rel}: 3-arg leftover for enable-blocked")
    else:
        out("PASS", f"{rel}: no 3-arg mustDenySensors leftover")

# Negative: 3-arg still exists on policy (legacy) but must NOT be used by Helper/tiles
pol = read(POLICY)
if re.search(
    r"return mustDenySensors\(\s*deviceLocked,\s*deviceLocked,\s*userUnlocked,\s*strongAuthFlags\s*\)",
    pol,
):
    out("PASS", "policy 3-arg legacy still maps deviceLocked→keyguardShowing (unused by Helper/QS)")
else:
    out("HOLD", "policy 3-arg legacy overload missing or rewritten — confirm callers")

# Helper isSensorEnableBlocked delegates to areSensorsForceDenied (4-arg)
h = read(HELPER)
enb = extract_method(h, r"public static boolean isSensorEnableBlocked\(")
if enb and "returnareSensorsForceDenied(context);" in re.sub(r"\s+", "", enb):
    out("PASS", "Helper isSensorEnableBlocked → areSensorsForceDenied (4-arg path)")
else:
    out("FAIL", "Helper isSensorEnableBlocked does not delegate to areSensorsForceDenied")

# --- SensorToggleController polarity ---
c = read(CTRL)
is_checked = extract_method(c, r"public boolean isChecked\(")
if is_checked and "return!mSensorPrivacyManagerHelper.isSensorBlocked(getSensor());" in re.sub(
    r"\s+", "", is_checked
):
    out("PASS", "SensorToggleController.isChecked = !isSensorBlocked (access ON = privacy OFF)")
else:
    out("FAIL", "SensorToggleController.isChecked polarity not !isSensorBlocked")

set_checked = extract_method(c, r"public boolean setChecked\(boolean isChecked\)")
if not set_checked:
    out("FAIL", "SensorToggleController.setChecked not extracted")
else:
    compact = re.sub(r"\s+", "", set_checked)
    if "if(isChecked&&!mIgnoreDeviceConfig&&isSensorEnableBlocked())" in compact:
        out("PASS", "setChecked(true) rejected when isSensorEnableBlocked (4-arg)")
    else:
        out("FAIL", "setChecked(true) does not reject when enable-blocked")
    if "setSensorBlocked(getSensor(),!isChecked)" in compact:
        out("PASS", "setChecked(false) → setSensorBlocked(true) (access OFF still blocks)")
    else:
        out("FAIL", "setChecked does not invert to setSensorBlocked(!isChecked)")
    if compact.index("if(isChecked&&") < compact.index("setSensorBlocked"):
        out("PASS", "enable-blocked reject is before persist; OFF (isChecked=false) still persists")
    else:
        out("FAIL", "reject/persist order unexpected")

# Disable + locked summary only when 4-arg mustDeny AND access OFF
apply_ui = extract_method(c, r"private void applyGuardTalkAccessUi\(Preference preference\)")
if apply_ui:
    spaced = re.sub(r"\s+", " ", apply_ui)
    if "isSensorEnableBlocked() && !accessOn" in spaced or (
        "isSensorEnableBlocked()" in apply_ui and "!accessOn" in apply_ui
    ):
        out("PASS", "disable + locked summary only when mustDeny AND access OFF")
    else:
        out("FAIL", "applyGuardTalkAccessUi does not gate disable on mustDeny && !accessOn")
    if "getSensorEnableBlockedSummaryRes" in apply_ui:
        out("PASS", "locked/lockdown summary shown when enable-blocked")
    else:
        out("FAIL", "no visible locked summary when enable-blocked")
else:
    out("FAIL", "applyGuardTalkAccessUi not extracted")

# Availability DISABLED_DEPENDENT_SETTING when enable-blocked and !isChecked
avail = extract_method(c, r"public int getAvailabilityStatus\(")
if avail and "isSensorEnableBlocked() && !isChecked()" in re.sub(r"\s+", " ", avail):
    out("PASS", "availability DISABLED_DEPENDENT_SETTING when 4-arg mustDeny and access OFF")
else:
    out("FAIL", "availability does not disable only when mustDeny && access OFF")

# isSensorEnableBlocked uses Helper (4-arg)
if "GuardTalkSensorPrivacyHelper.isSensorEnableBlocked(mContext)" in c:
    out("PASS", "SensorToggleController enable-blocked uses Helper 4-arg")
else:
    out("FAIL", "SensorToggleController does not call Helper.isSensorEnableBlocked")

# Lifecycle ON_START / ON_STOP
if "@OnLifecycleEvent(Lifecycle.Event.ON_START)" in c and "addSensorBlockedListener" in c:
    out("PASS", "SensorToggleController ON_START adds sensor listener")
else:
    out("FAIL", "SensorToggleController missing ON_START listener")
if "@OnLifecycleEvent(Lifecycle.Event.ON_STOP)" in c and "removeSensorBlockedListener" in c:
    out("PASS", "SensorToggleController ON_STOP removes sensor listener")
else:
    out("FAIL", "SensorToggleController missing ON_STOP listener")

# --- PrivacyControlsFragment observers + keys ---
f = read(FRAG)
xml = read(XML)
if 'CAMERA_KEY = "privacy_camera_toggle"' in f and 'MIC_KEY = "privacy_mic_toggle"' in f:
    out("PASS", "PrivacyControlsFragment keys privacy_camera_toggle / privacy_mic_toggle")
else:
    out("FAIL", "PrivacyControlsFragment keys mismatch")
if 'android:key="privacy_camera_toggle"' in xml and 'android:key="privacy_mic_toggle"' in xml:
    out("PASS", "XML keys privacy_camera_toggle / privacy_mic_toggle")
else:
    out("FAIL", "privacy_controls_settings.xml missing toggle keys")
if "settings:controller=\"com.android.settings.privacy.CameraToggleController\"" in xml and \
   "settings:controller=\"com.android.settings.privacy.MicToggleController\"" in xml:
    out("PASS", "XML controllers CameraToggleController / MicToggleController")
else:
    out("FAIL", "XML controller class mismatch")
if "getSettingsLifecycle().addObserver(use(CameraToggleController.class))" in re.sub(r"\s+", "", f) or (
    "addObserver(use(CameraToggleController.class))" in re.sub(r"\s+", "", f)
):
    out("PASS", "PrivacyControlsFragment observes CameraToggleController")
else:
    out("FAIL", "PrivacyControlsFragment does not addObserver CameraToggleController")
if "addObserver(use(MicToggleController.class))" in re.sub(r"\s+", "", f):
    out("PASS", "PrivacyControlsFragment observes MicToggleController")
else:
    out("FAIL", "PrivacyControlsFragment does not addObserver MicToggleController")
if "new CameraToggleController(context, CAMERA_KEY)" in f and "new MicToggleController(context, MIC_KEY)" in f:
    out("PASS", "createPreferenceControllers binds camera/mic keys")
else:
    out("FAIL", "createPreferenceControllers missing camera/mic controllers")

# Subclass sensors
camc = read(CAM_CTRL)
micc = read(MIC_CTRL)
if "return SENSOR_CAMERA" in camc:
    out("PASS", "CameraToggleController sensor = CAMERA")
else:
    out("FAIL", "CameraToggleController sensor not CAMERA")
if "return SENSOR_MICROPHONE" in micc:
    out("PASS", "MicToggleController sensor = MICROPHONE")
else:
    out("FAIL", "MicToggleController sensor not MICROPHONE")

# --- Deep-link ---
pref = read(PREF)
if "new Intent(Settings.ACTION_PRIVACY_CONTROLS)" in pref:
    out("PASS", "GuardTalkSensorPrivacyPreferenceController deep-links ACTION_PRIVACY_CONTROLS")
else:
    out("FAIL", "preference controller missing ACTION_PRIVACY_CONTROLS")
sj = read(SETTINGS_JAVA)
if 'ACTION_PRIVACY_CONTROLS =\n            "android.settings.PRIVACY_CONTROLS"' in sj or \
   'ACTION_PRIVACY_CONTROLS =' in sj and '"android.settings.PRIVACY_CONTROLS"' in sj:
    out("PASS", "Settings.ACTION_PRIVACY_CONTROLS = android.settings.PRIVACY_CONTROLS")
else:
    out("FAIL", "ACTION_PRIVACY_CONTROLS constant missing")
man = read(MANIFEST)
if 'android:name="android.settings.PRIVACY_CONTROLS"' in man and \
   "com.android.settings.privacy.PrivacyControlsFragment" in man:
    out("PASS", "PrivacyControlsActivity intent-filter → PrivacyControlsFragment")
else:
    out("FAIL", "manifest PRIVACY_CONTROLS → fragment missing")

# --- QS tiles: refuse access ON while 4-arg mustDeny; long-click Controls ---
def check_tile(p: Path, spec: str):
    src = read(p)
    rel = p.relative_to(root)
    if f'TILE_SPEC = "{spec}"' in src:
        out("PASS", f"{rel}: TILE_SPEC={spec}")
    else:
        out("FAIL", f"{rel}: TILE_SPEC not {spec}")
    click = extract_method(src, r"protected void handleClick\(")
    if not click:
        out("FAIL", f"{rel}: handleClick not extracted")
    else:
        compact = re.sub(r"\s+", "", click)
        if "if(blocked&&isGuardTalkSensorEnableBlocked())" in compact and "refreshState(true)" in compact:
            out("PASS", f"{rel}: handleClick refuses turning access ON while 4-arg mustDeny")
        else:
            out("FAIL", f"{rel}: handleClick does not refuse access ON when mustDeny")
        if "super.handleClick" in click:
            out("PASS", f"{rel}: non-mustDeny click still reaches parent toggle (OFF persist)")
        else:
            out("FAIL", f"{rel}: handleClick never calls super (OFF may be dead)")
    upd = extract_method(src, r"protected void handleUpdateState\(")
    if upd and "STATE_UNAVAILABLE" in upd and "isGuardTalkSensorEnableBlocked()" in upd:
        out("PASS", f"{rel}: tile UNAVAILABLE when blocked && 4-arg mustDeny")
    else:
        out("FAIL", f"{rel}: handleUpdateState missing locked UNAVAILABLE")
    lci = extract_method(src, r"public Intent getLongClickIntent\(")
    if lci and "Settings.ACTION_PRIVACY_CONTROLS" in lci:
        out("PASS", f"{rel}: long-click ACTION_PRIVACY_CONTROLS")
    else:
        out("FAIL", f"{rel}: long-click not Controls")
    # enable-blocked uses same 4-arg as Helper
    if "GuardTalkSensorPrivacyPolicy.mustDenySensors(" in src and "isKeyguardLocked()" in src:
        out("PASS", f"{rel}: enable-blocked uses policy 4-arg + isKeyguardLocked")
    else:
        out("FAIL", f"{rel}: enable-blocked not 4-arg isKeyguardLocked")

check_tile(CAM_TILE, "cameratoggle")
check_tile(MIC_TILE, "mictoggle")

# Parent polarity: value = !isBlocked (access ON = privacy OFF)
parent = read(QS_PARENT)
if "state.value = !isBlocked" in parent and "setSensorBlocked(QS_TILE, getSensorId(), !blocked)" in parent:
    out("PASS", "QS parent: value=!isBlocked; click setSensorBlocked(!blocked)")
else:
    out("FAIL", "QS parent polarity unexpected")

# QS desync: extract enable-blocked bodies and compare (ignore class wrapping)
def enable_blocked_body(src: str) -> str:
    m = extract_method(src, r"private boolean isGuardTalkSensorEnableBlocked\(")
    return re.sub(r"\s+", " ", m).strip() if m else ""

bcam = enable_blocked_body(read(CAM_TILE))
bmic = enable_blocked_body(read(MIC_TILE))
if bcam and bcam == bmic:
    out("PASS", "Camera/Mic QS enable-blocked bodies identical (no QS desync in 4-arg)")
else:
    out("FAIL", "QS Camera vs Mic enable-blocked bodies differ")

# --- Host truth-table: UI enable-blocked (4-arg) vs 3-arg leftover ---
print("--- host truth-table (UI enable-blocked) ---")
LOCKDOWN = 0x20

def must_deny_4(kg, device_locked, user_unlocked, flags, sensor_when_locked=True, lockdown_fail_closed=True):
    _ = device_locked  # unused once keyguard dismissed
    if lockdown_fail_closed and (flags & LOCKDOWN):
        return True
    if not sensor_when_locked:
        return False
    if not user_unlocked:
        return True
    return kg

def must_deny_3(device_locked, user_unlocked, flags, **kw):
    return must_deny_4(device_locked, device_locked, user_unlocked, flags, **kw)

def enable_blocked_4(kg, device_locked, user_unlocked, flags, sensor_on=True, lockdown_on=True):
    if not sensor_on and not lockdown_on:
        return False
    return must_deny_4(kg, device_locked, user_unlocked, flags, sensor_on, lockdown_on)

cases = [
    # name, kg, locked, unlocked, flags, exp4, exp3
    ("unlocked", False, False, True, 0, False, False),
    ("stale_deviceLocked_keyguard_dismissed", False, True, True, 0, False, True),
    ("keyguard_showing", True, True, True, 0, True, True),
    ("pre_unlock", False, True, False, 0, True, True),
    ("lockdown_0x20", False, False, True, 0x20, True, True),
    ("keyguard_plus_lockdown", True, True, True, 0x20, True, True),
]
tt_fail = 0
for name, kg, locked, unlocked, flags, exp4, exp3 in cases:
    got4 = enable_blocked_4(kg, locked, unlocked, flags)
    got3 = must_deny_3(locked, unlocked, flags)
    ok4 = got4 is exp4
    ok3 = got3 is exp3
    status = "PASS" if ok4 else "FAIL"
    print(
        f"  {status}: {name} kg={kg} deviceLocked={locked} unlocked={unlocked} flags=0x{flags:x}"
        f" enableBlocked4={got4} expected4={exp4} leftover3={got3} expected3={exp3}"
    )
    if not ok4:
        tt_fail += 1
        out("FAIL", f"truth-table 4-arg {name}")
    else:
        out("PASS", f"truth-table 4-arg {name} enableBlocked={got4}")
    if not ok3:
        tt_fail += 1
        out("FAIL", f"truth-table 3-arg residual {name} (document leftover polarity)")
    else:
        out("PASS", f"truth-table 3-arg residual {name} would_block={got3}")

# Negative: disable-as-locked while interactively unlocked is 3-arg behavior
if enable_blocked_4(False, True, True, 0) is False and must_deny_3(True, True, 0) is True:
    out("PASS", "NEGATIVE refuted: 4-arg does NOT disable-as-locked while interactively unlocked; 3-arg would")
else:
    out("FAIL", "stale-deviceLocked polarity not as specified")

# Turning OFF still allowed when mustDeny (Settings setChecked false path)
# Model: reject only if isChecked(true) && enableBlocked
def set_checked(want_access_on, kg, locked, unlocked, flags):
    blocked_now = False  # unused; persist invert
    if want_access_on and enable_blocked_4(kg, locked, unlocked, flags):
        return ("reject", None)
    return ("persist", not want_access_on)  # setSensorBlocked(!isChecked)

off_locked = set_checked(False, True, True, True, 0)
on_locked = set_checked(True, True, True, True, 0)
off_unlocked = set_checked(False, False, False, True, 0)
on_unlocked = set_checked(True, False, False, True, 0)
on_stale = set_checked(True, False, True, True, 0)
if off_locked == ("persist", True):
    out("PASS", "setChecked(false) while keyguard still persists setSensorBlocked(true)")
else:
    out("FAIL", f"OFF while locked unexpected {off_locked}")
if on_locked == ("reject", None):
    out("PASS", "setChecked(true) while keyguard rejected")
else:
    out("FAIL", f"ON while locked unexpected {on_locked}")
if off_unlocked == ("persist", True) and on_unlocked == ("persist", False):
    out("PASS", "unlocked: OFF persists blocked=true; ON persists blocked=false")
else:
    out("FAIL", "unlocked persist polarity")
if on_stale == ("persist", False):
    out("PASS", "stale deviceLocked + keyguard dismissed: turning access ON not rejected")
else:
    out("FAIL", f"stale deviceLocked still rejects access ON: {on_stale}")

# QS click refuse model
def qs_click(blocked, kg, locked, unlocked, flags):
    if blocked and enable_blocked_4(kg, locked, unlocked, flags):
        return "refuse_on"
    return "toggle"

if qs_click(True, True, True, True, 0) == "refuse_on":
    out("PASS", "QS click: access OFF + mustDeny → refuse turning ON")
else:
    out("FAIL", "QS click did not refuse ON while mustDeny")
if qs_click(False, True, True, True, 0) == "toggle":
    out("PASS", "QS click: access ON + mustDeny → still allow toggle OFF")
else:
    out("FAIL", "QS click blocked turning OFF while mustDeny")
if qs_click(True, False, True, True, 0) == "toggle":
    out("PASS", "QS click: stale deviceLocked unlocked → does not refuse ON")
else:
    out("FAIL", "QS click still refuses ON while interactively unlocked (stale isDeviceLocked)")

# --- Forbidden product files not required edited (QA does not touch) ---
# Confirm we are rematching F files, not re-running T persist path as this card.
if HOOKS.is_file() and SERVICE.is_file():
    out("PASS", "T persist files present (not re-run as this card; Q-OS-CAMMIC-TOGGLE already APPROVED)")
else:
    out("HOLD", "T persist files missing — unexpected")

# Overlay must not reintroduce 3-arg Settings helper
ov = list((root / "vendor/guardtalk/overlays").glob("**/GuardTalkSensorPrivacyHelper.java")) if (root / "vendor/guardtalk/overlays").is_dir() else []
if ov:
    out("FAIL", f"overlay Helper present (unexpected): {ov}")
else:
    out("PASS", "no overlay GuardTalkSensorPrivacyHelper (no 3-arg overlay leftover)")

# Secrets / forbidden paths not written by this script (static scan of this file is N/A)
# lunch HOLD via adevtool pin — do not edit adevtool-version-check.mk
pin = root / "vendor/google_devices/tokay/adevtool-version-check.mk"
if pin.is_file():
    ptxt = pin.read_text(encoding="utf-8")
    want = re.search(r"rev-parse HEAD\),([a-f0-9]+)", ptxt)
    expected = want.group(1) if want else None
    got = None
    try:
        got = subprocess.check_output(
            ["git", "-C", str(root / "vendor/adevtool"), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except Exception as exc:
        out("HOLD", f"vendor/adevtool HEAD unreadable: {exc}")
        got = ""
    if expected and got and got != expected:
        out(
            "HOLD",
            f"lunch tokay / m Settings HOLD — adevtool pin mismatch got={got} want={expected}; "
            "adevtool-version-check.mk not edited",
        )
    elif expected and got == expected:
        out("HOLD", "adevtool pin matches; lunch / m Settings not run this rematch (static UI-binding card)")
    elif expected is None:
        out("HOLD", "adevtool pin SHA not parsed; lunch not run")
else:
    out("HOLD", "adevtool-version-check.mk missing; lunch not run")

print()
print(f"SUITE_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail_n} HOLD_COUNT={hold_n}")
sys.exit(1 if fail_n else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -ne 0 ]]; then
  FAIL=1
fi

echo
echo "=== adb device proof ==="
if ! command -v adb >/dev/null 2>&1; then
  hold "adb binary not on PATH — Settings/QS vs dumpsys not proven; not device-fixed"
else
  echo "$ADB_OUT"
  if echo "$ADB_OUT" | awk 'NR>1 && $2=="device" {found=1} END{exit found?0:1}'; then
    echo "--- dumpsys sensor_privacy ---"
    adb shell dumpsys sensor_privacy || hold "dumpsys sensor_privacy failed"
    echo "--- appops CAMERA ---"
    adb shell cmd appops query-op CAMERA || hold "appops CAMERA failed"
    echo "--- appops RECORD_AUDIO ---"
    adb shell cmd appops query-op RECORD_AUDIO || hold "appops RECORD_AUDIO failed"
    pass "adb device present — dumpsys/appops captured (see output)"
  else
    hold "adb devices empty — Settings/QS vs dumpsys not run; not device-fixed"
  fi
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL_COUNT=$FAIL_N PY_RC=$PY_RC"
  exit 1
fi
echo "RESULT: PASS (static)  bash_PASS=$PASS_N bash_HOLD=$HOLD_N bash_FAIL=$FAIL_N PY_RC=$PY_RC"
echo "Device Settings/QS vs dumpsys: HOLD unless adb proof above."
echo "LIVE_DEVICE_CLAIMED=false"
exit 0
