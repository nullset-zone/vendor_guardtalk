#!/usr/bin/env bash
# Independent rematch for Q-OS-CAMMIC-TOGGLE (pair of T-OS-CAMMIC-TOGGLE).
# Do not trust Backend/Architect reports. Host static + truth-table only.
# Device dumpsys/appops HOLD if adb empty. No USB. No product edits.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_os_cammic_toggle_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

POLICY="frameworks/base/core/java/android/guardtalk/GuardTalkSensorPrivacyPolicy.java"
HOOKS="frameworks/base/services/core/java/com/android/server/sensorprivacy/GuardTalkSensorPrivacyHooks.java"
SERVICE="frameworks/base/services/core/java/com/android/server/sensorprivacy/SensorPrivacyService.java"
QS_DIR="frameworks/base/packages/SystemUI/src/com/android/systemui/qs"
QS_OV="vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml"
PROPS="vendor/guardtalk/device/tokay/guardtalk-product-props.mk"
LPU="frameworks/base/core/java/com/android/internal/widget/LockPatternUtils.java"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

require_rg() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && rg -q -- "$pat" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
}

forbid_rg() {
  local pat="$1" path="$2" label="$3"
  if rg -q -- "$pat" "$path" 2>/dev/null; then
    fail "$label (forbidden pattern present: $pat)"
  else
    pass "$label"
  fi
}

echo "=== Q-OS-CAMMIC-TOGGLE independent rematch ==="
echo "ROOT=$ROOT"
echo

# --- Files ---
require_file "$POLICY"
require_file "$HOOKS"
require_file "$SERVICE"
require_file "$QS_OV"
require_file "$PROPS"

# --- Packet rg (raw symbols) ---
echo "--- packet rg (sensorprivacy + policy) ---"
rg -n "allowToggleChange|ownsLockToggleAuthority|allowUserToggle|mustDenySensors|canChangeToggleSensorPrivacy" \
  frameworks/base/services/core/java/com/android/server/sensorprivacy/ \
  "$POLICY" || true
echo

require_rg "ownsLockToggleAuthority" "$HOOKS" "hooks define ownsLockToggleAuthority"
require_rg "ownsLockToggleAuthority" "$SERVICE" "service consults ownsLockToggleAuthority"
require_rg "allowUserToggle" "$POLICY" "policy defines allowUserToggle"
require_rg "allowToggleChange" "$HOOKS" "hooks define allowToggleChange"
require_rg "allowToggleChange" "$SERVICE" "service calls allowToggleChange"
require_rg "canChangeToggleSensorPrivacy" "$SERVICE" "AOSP canChangeToggleSensorPrivacy present"
require_rg "mustDenySensors" "$POLICY" "policy defines mustDenySensors"
require_rg "mustDenySensors" "$HOOKS" "hooks call mustDenySensors"

# --- ownsLockToggleAuthority skips AOSP isDeviceLocked blanket ---
echo "--- canChangeToggleSensorPrivacy structure ---"
python3 - "$SERVICE" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
m = re.search(
    r"private boolean canChangeToggleSensorPrivacy\([^)]*\) \{.*?\n        \}",
    text,
    re.S,
)
if not m:
    print("STRUCT_FAIL: canChangeToggleSensorPrivacy not extracted")
    sys.exit(2)
body = m.group(0)
idx_emerg = body.find("isInEmergencyCall")
idx_lock = body.find("isDeviceLocked")
idx_owns = body.find("ownsLockToggleAuthority")
idx_mic = body.find("DISALLOW_MICROPHONE_TOGGLE")
idx_cam = body.find("DISALLOW_CAMERA_TOGGLE")
ok = True
def chk(name, cond):
    global ok
    if cond:
        print(f"STRUCT_PASS: {name}")
    else:
        print(f"STRUCT_FAIL: {name}")
        ok = False
chk("emergency mic check present", idx_emerg != -1)
chk("isDeviceLocked blanket present", idx_lock != -1)
chk("ownsLockToggleAuthority skip present", idx_owns != -1)
chk("DISALLOW_MICROPHONE_TOGGLE present", idx_mic != -1)
chk("DISALLOW_CAMERA_TOGGLE present", idx_cam != -1)
chk("emergency BEFORE lock blanket", idx_emerg != -1 and idx_lock != -1 and idx_emerg < idx_lock)
chk("lock skip uses ownsLockToggleAuthority AFTER isDeviceLocked", idx_lock != -1 and idx_owns != -1 and idx_lock < idx_owns)
chk("DISALLOW_* AFTER lock skip (not bypassed)", idx_owns != -1 and idx_mic != -1 and idx_cam != -1 and idx_owns < idx_mic < idx_cam)
# Skip must not return false when GuardTalk owns authority.
skip_block = body[idx_lock:idx_mic if idx_mic != -1 else len(body)]
chk("skip does not drop when ownsLockToggleAuthority true",
    "mGuardTalkHooks == null || !mGuardTalkHooks.ownsLockToggleAuthority()" in skip_block)
if not ok:
    sys.exit(1)
PY
if [[ $? -eq 0 ]]; then
  pass "canChangeToggleSensorPrivacy: emergency+DISALLOW still block; lock blanket skipped iff ownsLockToggleAuthority"
else
  fail "canChangeToggleSensorPrivacy structural rematch"
fi

# Confirm skip is NOT a blanket removal of isDeviceLocked (stock path still drops)
if rg -q "Can't change mic/cam toggle while device is locked" "$SERVICE"; then
  pass "stock isDeviceLocked drop log still present (non-GuardTalk path)"
else
  fail "stock isDeviceLocked drop log missing"
fi

# --- allowUserToggle always true for privacy-ON ---
python3 - "$POLICY" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
m = re.search(
    r"public static boolean allowUserToggle\(\s*boolean enablePrivacy,.*?\{.*?\n    \}",
    text,
    re.S,
)
if not m:
    print("STRUCT_FAIL: allowUserToggle not extracted")
    sys.exit(2)
body = m.group(0)
ok = True
if "if (enablePrivacy)" in body and "return true;" in body.split("if (enablePrivacy)", 1)[1].split("}", 1)[0]:
    print("STRUCT_PASS: allowUserToggle(enablePrivacy=true) returns true immediately")
else:
    print("STRUCT_FAIL: allowUserToggle privacy-ON is not always true")
    ok = False
if "return !mustDenySensors" in body.replace(" ", "").replace("\n", " ") or "return !mustDenySensors(" in body:
    print("STRUCT_PASS: allowUserToggle(privacy-OFF) is !mustDenySensors")
else:
    # tolerate whitespace
    compact = re.sub(r"\s+", "", body)
    if "return!mustDenySensors(" in compact:
        print("STRUCT_PASS: allowUserToggle(privacy-OFF) is !mustDenySensors")
    else:
        print("STRUCT_FAIL: privacy-OFF not gated by mustDenySensors")
        ok = False
sys.exit(0 if ok else 1)
PY
if [[ $? -eq 0 ]]; then
  pass "allowUserToggle: privacy-ON always; privacy-OFF = !mustDeny"
else
  fail "allowUserToggle structural rematch"
fi

# --- 4-arg mustDenySensors does not OR stale deviceLocked ---
python3 - "$POLICY" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
# 4-arg overload only
m = re.search(
    r"public static boolean mustDenySensors\(\s*boolean keyguardShowing,\s*boolean deviceLocked,\s*boolean userUnlocked,\s*int strongAuthFlags\) \{.*?\n    \}",
    text,
    re.S,
)
if not m:
    print("STRUCT_FAIL: 4-arg mustDenySensors not extracted")
    sys.exit(2)
body = m.group(0)
# Strip comments so we don't count the "not OR-ed" comment as a use.
nocomment = re.sub(r"/\*.*?\*/", "", body, flags=re.S)
nocomment = re.sub(r"//.*?$", "", nocomment, flags=re.M)
# Parameter declaration mentions deviceLocked; body must not use it.
# After the signature, the identifier deviceLocked must not appear.
sig_end = nocomment.find("{")
inner = nocomment[sig_end:]
uses = re.findall(r"\bdeviceLocked\b", inner)
if uses:
    print(f"STRUCT_FAIL: 4-arg body still references deviceLocked ({len(uses)} times)")
    sys.exit(1)
if "return keyguardShowing;" not in body:
    print("STRUCT_FAIL: 4-arg does not return keyguardShowing after CE unlocked")
    sys.exit(1)
if "!userUnlocked" not in body and "if (!userUnlocked)" not in nocomment:
    print("STRUCT_FAIL: 4-arg missing !userUnlocked pre-unlock deny")
    sys.exit(1)
if "isLockdownActive" not in body:
    print("STRUCT_FAIL: 4-arg missing lockdown deny")
    sys.exit(1)
print("STRUCT_PASS: 4-arg mustDenySensors unused deviceLocked; deny = lockdown | !userUnlocked | keyguardShowing")
PY
if [[ $? -eq 0 ]]; then
  pass "4-arg mustDenySensors does not OR stale deviceLocked"
else
  fail "4-arg mustDenySensors still uses deviceLocked"
fi

# 3-arg still maps deviceLocked → keyguardShowing (Settings residual, documented)
if rg -n "return mustDenySensors\(deviceLocked, deviceLocked, userUnlocked, strongAuthFlags\);" "$POLICY" >/dev/null; then
  pass "3-arg legacy still duplicates deviceLocked (Settings residual, not T persist path)"
else
  fail "3-arg legacy overload missing or changed unexpectedly"
fi

# --- lockdown flag 0x20 ---
if rg -q "STRONG_AUTH_REQUIRED_AFTER_USER_LOCKDOWN = 0x20" "$LPU"; then
  pass "STRONG_AUTH_REQUIRED_AFTER_USER_LOCKDOWN = 0x20"
else
  fail "lockdown flag is not 0x20"
fi
require_rg "isLockdownActive" "$POLICY" "policy isLockdownActive uses USER_LOCKDOWN flag"

# --- hooks pass 4-arg (keyguard showing first) ---
require_rg "isKeyguardShowing\(\)" "$HOOKS" "hooks read isKeyguardLocked via isKeyguardShowing"
if python3 - "$HOOKS" <<'PY'
import sys
text = open(sys.argv[1]).read()
compact = " ".join(text.split())
ok = "GuardTalkSensorPrivacyPolicy.mustDenySensors(" in compact and \
     "keyguardShowing, deviceLocked, userUnlocked" in compact
sys.exit(0 if ok else 1)
PY
then
  pass "hooks call 4-arg mustDenySensors(keyguardShowing, deviceLocked, ...)"
else
  fail "hooks do not call 4-arg mustDeny with keyguardShowing first"
fi

# --- persist path: public set still reaches Unchecked after GuardTalk allow ---
require_rg "setToggleSensorPrivacyUnchecked" "$SERVICE" "persist Unchecked path present"
if python3 - "$SERVICE" <<'PY'
import sys
text = open(sys.argv[1]).read()
# Public setToggleSensorPrivacy: canChange → allowToggleChange → Unchecked
idx = text.find("public void setToggleSensorPrivacy(@UserIdInt int userId")
chunk = text[idx:idx+2500]
ok = (
    "canChangeToggleSensorPrivacy" in chunk
    and "allowToggleChange" in chunk
    and "setToggleSensorPrivacyUnchecked" in chunk
)
sys.exit(0 if ok else 1)
PY
then
  pass "setToggleSensorPrivacy: canChange then allowToggleChange then persist Unchecked"
else
  fail "setToggleSensorPrivacy persist order broken"
fi

# --- AppOps force-deny OR ---
require_rg "toggleEnabled || mustDenySensors" "$HOOKS" "effectiveRestriction = toggle OR mustDeny"
require_rg "effectiveSensorRestriction" "$SERVICE" "service AppOps uses effectiveSensorRestriction"

# --- product props fail-closed ---
require_rg "ro.guardtalk.sensor_privacy_when_locked=1" "$PROPS" "LIVE prop sensor_privacy_when_locked=1"
require_rg "ro.guardtalk.lockdown_fail_closed=1" "$PROPS" "LIVE prop lockdown_fail_closed=1"

# --- No Lockdown QS tile ---
echo "--- Lockdown QS ---"
rg -n "LockdownTile|TILE_SPEC = \"lockdown\"" "$QS_DIR" || true
if rg -q "LockdownTile|TILE_SPEC = \"lockdown\"" "$QS_DIR" 2>/dev/null; then
  fail "Lockdown QS tile class/spec present under SystemUI qs/"
else
  pass "no LockdownTile / TILE_SPEC=lockdown under SystemUI qs/"
fi

python3 - "$QS_OV" <<'PY'
import re, sys
text = open(sys.argv[1]).read()
# Extract tile list strings
names = re.findall(r'<string name="(quick_settings_tiles[^"]*)"[^>]*>(.*?)</string>', text, re.S)
ok = True
for name, body in names:
    tokens = [t.strip() for t in body.replace("\n", "").split(",") if t.strip()]
    if "lockdown" in tokens:
        print(f"STRUCT_FAIL: {name} contains lockdown tile")
        ok = False
    else:
        print(f"STRUCT_PASS: {name} has no lockdown tile ({len(tokens)} tokens)")
sys.exit(0 if ok else 1)
PY
if [[ $? -eq 0 ]]; then
  pass "GuardTalk SystemUI overlay QS lists have no lockdown tile"
else
  fail "lockdown tile present in overlay QS lists"
fi

# --- No HAL re-enable in T target files ---
if rg -n "ICameraDevice|ICameraProvider|enableCamera|camera HAL" "$POLICY" "$HOOKS" "$SERVICE" >/dev/null 2>&1; then
  fail "HAL re-enable symbols in T target files"
else
  pass "no camera HAL re-enable symbols in policy/hooks/service"
fi

# --- Host truth-table (independent reimplementation of policy booleans) ---
echo "--- host truth-table ---"
python3 - <<'PY'
"""Independent rematch of GuardTalkSensorPrivacyPolicy (policy ON)."""
LOCKDOWN = 0x20  # STRONG_AUTH_REQUIRED_AFTER_USER_LOCKDOWN

def is_lockdown_active(flags: int) -> bool:
    return (flags & LOCKDOWN) != 0

def must_deny(keyguard_showing, device_locked, user_unlocked, flags,
              sensor_when_locked=True, lockdown_fail_closed=True):
    # device_locked unused once keyguard dismissed (DEC-OS-UX-001)
    _ = device_locked
    if lockdown_fail_closed and is_lockdown_active(flags):
        return True
    if not sensor_when_locked:
        return False
    if not user_unlocked:
        return True
    return keyguard_showing

def allow_user_toggle(enable_privacy, keyguard_showing, device_locked,
                      user_unlocked, flags, **kw):
    if enable_privacy:
        return True
    return not must_deny(keyguard_showing, device_locked, user_unlocked, flags, **kw)

# 3-arg residual: deviceLocked duplicated as keyguardShowing
def must_deny_3arg(device_locked, user_unlocked, flags, **kw):
    return must_deny(device_locked, device_locked, user_unlocked, flags, **kw)

cases = [
    # name, kg, locked, unlocked, flags, exp_deny, exp_on, exp_off
    ("unlocked", False, False, True, 0, False, True, True),
    ("stale_deviceLocked_keyguard_dismissed", False, True, True, 0, False, True, True),
    ("keyguard_showing", True, True, True, 0, True, True, False),
    ("pre_unlock", False, True, False, 0, True, True, False),
    ("lockdown_0x20", False, False, True, 0x20, True, True, False),
    ("keyguard_plus_lockdown", True, True, True, 0x20, True, True, False),
]
fail = 0
for name, kg, locked, unlocked, flags, exp_deny, exp_on, exp_off in cases:
    deny = must_deny(kg, locked, unlocked, flags)
    on = allow_user_toggle(True, kg, locked, unlocked, flags)
    off = allow_user_toggle(False, kg, locked, unlocked, flags)
    ok = (deny, on, off) == (exp_deny, exp_on, exp_off)
    status = "PASS" if ok else "FAIL"
    print(f"  {status}: {name} kg={kg} deviceLocked={locked} unlocked={unlocked} flags=0x{flags:x}"
          f" mustDeny={deny} allowOn={on} allowOff={off} expected=({exp_deny},{exp_on},{exp_off})")
    if not ok:
        fail += 1

# Adversarial extras (count separately)
extras_ok = True
# policy OFF: locked does not deny
if must_deny(True, True, True, 0, sensor_when_locked=False, lockdown_fail_closed=False) is not False:
    print("  FAIL: policy-off still denies")
    extras_ok = False
    fail += 1
else:
    print("  PASS: policy-off locked does not deny (stock)")

# lockdown still denies even if sensor_when_locked false but lockdown_fail_closed true
if must_deny(False, False, True, 0x20, sensor_when_locked=False, lockdown_fail_closed=True) is not True:
    print("  FAIL: lockdown_fail_closed did not deny with sensor_when_locked off")
    extras_ok = False
    fail += 1
else:
    print("  PASS: lockdown_fail_closed denies even if sensor_when_locked off")

# 3-arg residual: stale deviceLocked WOULD deny (Settings helper, not service)
if must_deny_3arg(True, True, 0) is not True:
    print("  FAIL: 3-arg residual no longer ORs deviceLocked")
    extras_ok = False
    fail += 1
else:
    print("  PASS: 3-arg residual still ORs deviceLocked (Settings helper; not T persist)")

print(f"TRUTH_TABLE fail={fail}")
raise SystemExit(1 if fail else 0)
PY
if [[ $? -eq 0 ]]; then
  pass "host truth-table rematch (6 core + 3 adversarial extras)"
else
  fail "host truth-table rematch"
fi

# --- adb (HOLD if empty) ---
echo "--- adb ---"
if ! command -v adb >/dev/null 2>&1; then
  hold "adb binary not on PATH — cannot dumpsys/appops; not device-fixed"
else
  ADB_OUT="$(adb devices 2>&1 || true)"
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
    hold "adb devices empty — dumpsys/appops not run; not device-fixed"
  fi
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=1"
  exit 1
fi
echo "RESULT: PASS (static)  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=0"
echo "Device capture/persist: HOLD unless adb proof above."
exit 0
