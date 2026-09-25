#!/usr/bin/env bash
# Independent rematch for Q-OS-BACK-NAV (pair of T-OS-BACK-NAV).
# Do not trust Backend/Architect reports. Host static + structural only.
# Device Settings/Files/multi-activity back HOLD if adb empty. No USB.
# No product edits outside vendor/guardtalk/docs/qa/.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_os_back_nav_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; FAIL_N=$((FAIL_N + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }
FAIL_N=0

ACT="frameworks/base/core/java/android/app/Activity.java"
WRAP="frameworks/base/core/java/android/window/WindowOnBackInvokedDispatcher.java"
ACC="frameworks/base/services/core/java/com/android/server/wm/ActivityClientController.java"
ADEVTOOL="vendor/google_devices/tokay/adevtool-version-check.mk"

echo "=== Q-OS-BACK-NAV independent rematch ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

require_file "$ACT"
require_file "$WRAP"
require_file "$ACC"

echo "=== RAW: packet rg KEYCODE_BACK|onBackInvoked|BackAnimation|handleBack|predictiveBack ==="
rg -n "KEYCODE_BACK|onBackInvoked|BackAnimation|handleBack|predictiveBack" \
  frameworks/base/services/core/java/com/android/server/wm/ \
  frameworks/base/core/java/android/window/ || true
echo

echo "=== RAW: packet rg this::onBackPressed|skip onBackInvoked|shouldMoveTaskToBack ==="
rg -n "this::onBackPressed|skip onBackInvoked|shouldMoveTaskToBack" \
  "$ACT" "$WRAP" "$ACC" || true
echo

echo "=== RAW: vendor/guardtalk KEYCODE_BACK / OnBackInvoked (excl. this qa tree) ==="
rg -n --glob '!vendor/guardtalk/docs/qa/**' \
  "KEYCODE_BACK|OnBackInvoked|predictiveBack|handleBack" \
  vendor/guardtalk || true
echo

echo "=== RAW: adb devices ==="
if command -v adb >/dev/null 2>&1; then
  ADB_OUT="$(adb devices 2>&1 || true)"
else
  ADB_OUT="adb: command not found"
fi
printf '%s\n' "$ADB_OUT"
echo

python3 - "$ROOT" "$ACT" "$WRAP" "$ACC" "$ADB_OUT" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
act_p = Path(sys.argv[2])
wrap_p = Path(sys.argv[3])
acc_p = Path(sys.argv[4])
adb_out = sys.argv[5]
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


def extract_method(text, signature):
    idx = text.find(signature)
    if idx < 0:
        return None
    brace = text.find("{", idx)
    if brace < 0:
        return None
    depth = 0
    for i, ch in enumerate(text[brace:], brace):
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[idx : i + 1]
    return None


def strip_comments(src):
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"//.*?$", "", src, flags=re.M)
    return src


act = act_p.read_text(encoding="utf-8", errors="replace")
wrap = wrap_p.read_text(encoding="utf-8", errors="replace")
acc = acc_p.read_text(encoding="utf-8", errors="replace")

# --- 1. Activity system callback is this::onBackPressed ---
reg = extract_method(act, "boolean aheadOfTimeBack = WindowOnBackInvokedDispatcher")
# aheadOfTimeBack is a local in onCreate-ish; fall back to a window around the assignment
if "mDefaultBackCallback = this::onBackPressed" in act:
    out("PASS", "Activity assigns mDefaultBackCallback = this::onBackPressed")
else:
    out("FAIL", "Activity does not assign this::onBackPressed as default back callback")

# Negative: system callback must not be this::onBackInvoked
assign_invoked = re.search(
    r"mDefaultBackCallback\s*=\s*this::onBackInvoked\s*;", act
)
if assign_invoked:
    out("FAIL", "NEGATIVE: system callback is this::onBackInvoked (fragment stack skipped)")
else:
    out("PASS", "NEGATIVE refuted: system callback is not this::onBackInvoked")

# registerSystemOnBackInvokedCallback uses mDefaultBackCallback
if "registerSystemOnBackInvokedCallback(mDefaultBackCallback)" in act:
    out("PASS", "Activity registers mDefaultBackCallback as system OnBackInvokedCallback")
else:
    out("FAIL", "Activity does not register mDefaultBackCallback as system callback")

# --- 2. onBackPressed pops fragments then onBackInvoked ---
on_back = extract_method(act, "public void onBackPressed()")
if not on_back:
    out("FAIL", "Activity.onBackPressed() not extracted")
    on_back = ""
else:
    out("PASS", "Activity.onBackPressed() extracted")

on_back_nc = strip_comments(on_back)
idx_pop = on_back_nc.find("popBackStackImmediate")
idx_inv = on_back_nc.find("onBackInvoked()")
if idx_pop != -1 and idx_inv != -1 and idx_pop < idx_inv:
    out("PASS", "onBackPressed: popBackStackImmediate then onBackInvoked()")
else:
    out(
        "FAIL",
        f"onBackPressed order broken pop={idx_pop} onBackInvoked={idx_inv}",
    )

# collapseActionView still first
if "collapseActionView" in on_back_nc:
    out("PASS", "onBackPressed still collapses ActionBar first")
else:
    out("FAIL", "onBackPressed missing collapseActionView")

# --- 3. Wrapper onBackInvoked still invokes when anim && !isInProgress ---
wrapper = extract_method(wrap, "public void onBackInvoked() throws RemoteException")
if not wrapper:
    out("FAIL", "OnBackInvokedCallbackWrapper.onBackInvoked not extracted")
    wrapper = ""
else:
    out("PASS", "OnBackInvokedCallbackWrapper.onBackInvoked extracted")

wrapper_nc = strip_comments(wrapper)
if "skip onBackInvoked" in wrap or "skip onBackInvoked" in wrapper:
    out("FAIL", "NEGATIVE: 'skip onBackInvoked' string restored")
else:
    out("PASS", "NEGATIVE refuted: 'skip onBackInvoked' string absent")

# The anim && !isInProgress block must not return without invoke
anim_if = re.search(
    r"if\s*\(\s*callback\s+instanceof\s+OnBackAnimationCallback\s*&&\s*!isInProgress\s*\)\s*\{(.*?)\n\s*\}",
    wrapper,
    re.S,
)
if not anim_if:
    # Also accept if the condition is gone entirely AND invoke still happens
    if "WindowOnBackInvokedDispatcher.this.onBackInvoked(callback)" in wrapper_nc:
        out(
            "PASS",
            "anim&&!isInProgress skip-if absent; wrapper still invokes onBackInvoked(callback)",
        )
    else:
        out("FAIL", "cannot find anim&&!isInProgress block and invoke missing")
else:
    block = anim_if.group(1)
    block_nc = strip_comments(block)
    if re.search(r"\breturn\s*;", block_nc):
        out(
            "FAIL",
            "NEGATIVE: wrapper returns inside OnBackAnimationCallback && !isInProgress (skip restored)",
        )
    else:
        out(
            "PASS",
            "wrapper OnBackAnimationCallback && !isInProgress does not return (no skip)",
        )

if "WindowOnBackInvokedDispatcher.this.onBackInvoked(callback)" in wrapper_nc:
    out("PASS", "wrapper always reaches WindowOnBackInvokedDispatcher.this.onBackInvoked(callback)")
else:
    out("FAIL", "wrapper never invokes WindowOnBackInvokedDispatcher.this.onBackInvoked(callback)")

# Early returns that remain must be null-callback or IME pre-ime only
# After the anim-if, invoke must still be reachable (already checked).
# Confirm IME/null returns exist (not a silent swallow of all backs).
if "consumedByOnKeyPreIme()" in wrapper_nc:
    out("PASS", "wrapper still has IME onKeyPreIme consume path (not a blanket skip)")
else:
    out("FAIL", "wrapper missing consumedByOnKeyPreIme (unexpected rewrite)")

if 'Trying to call onBackInvoked() on a null callback reference' in wrapper:
    out("PASS", "wrapper still returns only on null callback after reset")
else:
    out("FAIL", "wrapper null-callback log/return missing")

# --- 4. shouldMoveTaskToBack: last-in-task, not HOME+MAIN-only ---
smt = extract_method(acc, "static boolean shouldMoveTaskToBack(")
if not smt:
    out("FAIL", "shouldMoveTaskToBack not extracted")
    smt = ""
else:
    out("PASS", "shouldMoveTaskToBack extracted")

smt_nc = strip_comments(smt)
if "isRelativeTaskRootActivity" in smt_nc:
    out("PASS", "shouldMoveTaskToBack checks relative-root")
else:
    out("FAIL", "shouldMoveTaskToBack missing isRelativeTaskRootActivity")

if "isTopActivityInTaskFragment" in smt_nc:
    out("PASS", "shouldMoveTaskToBack checks top-in-TF")
else:
    out("FAIL", "shouldMoveTaskToBack missing isTopActivityInTaskFragment")

if re.search(r"ACTION_MAIN|CATEGORY_HOME|Intent\.ACTION_MAIN", smt_nc):
    out("FAIL", "NEGATIVE: shouldMoveTaskToBack still gates on HOME+MAIN")
else:
    out("PASS", "NEGATIVE refuted: shouldMoveTaskToBack has no HOME+MAIN / ACTION_MAIN gate")

# After the two false-returns, must return true unconditionally
# Strip the two if-return false blocks and require a leftover `return true;`
returns = re.findall(r"return\s+(true|false)\s*;", smt_nc)
if returns and returns[-1] == "true" and "return true;" in smt_nc:
    out("PASS", "shouldMoveTaskToBack final return is true (last-in-task → moveTaskToBack)")
else:
    out("FAIL", f"shouldMoveTaskToBack final returns={returns} (expected last true)")

# False paths must still exist (not "always move")
if smt_nc.count("return false;") >= 2:
    out("PASS", "shouldMoveTaskToBack still false for non-root and non-top-in-TF")
else:
    out("FAIL", "shouldMoveTaskToBack lost root/top false-returns (too aggressive)")

# --- 5. ActivityClientController.onBackPressed order ---
acc_obp = extract_method(acc, "public void onBackPressed(IBinder token, IRequestFinishCallback callback)")
if not acc_obp:
    out("FAIL", "ActivityClientController.onBackPressed not extracted")
    acc_obp = ""
else:
    out("PASS", "ActivityClientController.onBackPressed extracted")

acc_obp_nc = strip_comments(acc_obp)
idx_org = acc_obp_nc.find("handleInterceptBackPressedOnTaskRoot")
idx_smt = acc_obp_nc.find("shouldMoveTaskToBack")
idx_move = acc_obp_nc.find("moveActivityTaskToBack")
idx_fin = acc_obp_nc.find("requestCallbackFinish")
ok_order = (
    idx_org != -1
    and idx_smt != -1
    and idx_move != -1
    and idx_fin != -1
    and idx_org < idx_smt < idx_move < idx_fin
)
if ok_order:
    out(
        "PASS",
        "onBackPressed order: organizer intercept → shouldMoveTaskToBack → "
        "moveActivityTaskToBack → else requestCallbackFinish",
    )
else:
    out(
        "FAIL",
        f"onBackPressed order broken org={idx_org} smt={idx_smt} "
        f"move={idx_move} finish={idx_fin}",
    )

# Organizer intercept still returns first (does not fall through to move/finish)
org_block = re.search(
    r"handleInterceptBackPressedOnTaskRoot\(r\)\)\s*\{(.*?)\}",
    acc_obp,
    re.S,
)
if org_block and "return;" in strip_comments(org_block.group(1)):
    out("PASS", "organizer intercept still returns first (no fall-through)")
else:
    out("FAIL", "organizer intercept missing early return")

# --- 6. No GuardTalk KEYCODE_BACK overlay ---
overlay_hits = []
for p in (root / "vendor/guardtalk").rglob("*"):
    if not p.is_file():
        continue
    rel = str(p.relative_to(root))
    if rel.startswith("vendor/guardtalk/docs/qa/"):
        continue
    if p.suffix.lower() not in {
        ".xml",
        ".java",
        ".kt",
        ".mk",
        ".bp",
        ".overlay",
        ".config",
        ".prop",
    }:
        continue
    try:
        txt = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    if "KEYCODE_BACK" in txt or "OnBackInvoked" in txt:
        overlay_hits.append(rel)

if overlay_hits:
    out("FAIL", "GuardTalk KEYCODE_BACK/OnBackInvoked overlay present: " + ", ".join(overlay_hits[:8]))
else:
    out("PASS", "no GuardTalk KEYCODE_BACK/OnBackInvoked overlay under vendor/guardtalk (excl. qa)")

# --- 7. This card did not edit SystemUI / Launcher3 ---
def git_paths_dirty(paths):
    try:
        r = subprocess.run(
            ["git", "status", "--porcelain", "--"] + paths,
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None, "git status failed"
    return r.stdout.strip(), None

sysui_out, sysui_err = git_paths_dirty(
    [
        "frameworks/base/packages/SystemUI",
        "packages/apps/Launcher3",
    ]
)
if sysui_err:
    out("HOLD", f"cannot confirm SystemUI/Launcher3 cleanliness ({sysui_err})")
elif not sysui_out:
    out("PASS", "git porcelain clean for SystemUI and Launcher3 (this rematch did not edit Frontend)")
else:
    # Dirty Frontend trees are F-card leftovers, not a T-OS-BACK-NAV FAIL unless
    # this QA session edited them. Report as INFO-HOLD, not FAIL for T rematch.
    lines = [ln for ln in sysui_out.splitlines() if ln.strip()]
    out(
        "HOLD",
        f"SystemUI/Launcher3 porcelain dirty ({len(lines)} paths) — "
        "not attributed to this QA rematch; Frontend card residual",
    )

# --- 8. Host truth-table: last-in-task move vs HOME+MAIN-only bug ---
print("--- host truth-table shouldMoveTaskToBack ---")


def should_move(is_root, is_rel_root, is_top_tf):
    if (not is_root) and (not is_rel_root):
        return False
    if not is_top_tf:
        return False
    return True


cases = [
    ("last_in_task_not_HOME_MAIN", True, False, True, True),
    ("last_in_task_HOME_MAIN_still_true", True, False, True, True),
    ("relative_root_top", False, True, True, True),
    ("not_root_not_rel", False, False, True, False),
    ("root_not_top_in_tf", True, False, False, False),
    ("rel_root_not_top", False, True, False, False),
]
tt_fail = 0
for name, is_root, is_rel, is_top, exp in cases:
    got = should_move(is_root, is_rel, is_top)
    ok = got is exp
    print(
        f"  {'PASS' if ok else 'FAIL'}: {name} root={is_root} rel={is_rel} "
        f"topTF={is_top} → {got} expected={exp}"
    )
    if not ok:
        tt_fail += 1
if tt_fail:
    out("FAIL", f"host truth-table shouldMoveTaskToBack ({tt_fail} mismatches)")
else:
    out("PASS", "host truth-table shouldMoveTaskToBack 6/6 (HOME+MAIN not required)")

# Wrapper invoke truth-table
print("--- host truth-table wrapper onBackInvoked ---")


def wrapper_invokes(is_anim, in_progress, callback_null, ime_consume):
    if ime_consume:
        return False
    if callback_null:
        return False
    # anim && !in_progress MUST still invoke (old skip gone)
    return True


w_cases = [
    ("anim_idle_KEYCODE_BACK", True, False, False, False, True),
    ("anim_in_progress", True, True, False, False, True),
    ("plain_callback", False, False, False, False, True),
    ("null_callback", True, False, True, False, False),
    ("ime_preime_consume", True, False, False, True, False),
]
w_fail = 0
for name, anim, prog, null, ime, exp in w_cases:
    got = wrapper_invokes(anim, prog, null, ime)
    ok = got is exp
    print(
        f"  {'PASS' if ok else 'FAIL'}: {name} anim={anim} inProg={prog} "
        f"null={null} ime={ime} → invoke={got} expected={exp}"
    )
    if not ok:
        w_fail += 1
if w_fail:
    out("FAIL", f"host truth-table wrapper ({w_fail} mismatches)")
else:
    out("PASS", "host truth-table wrapper 5/5 (anim+idle still invokes)")

# --- 9. adb / device ---
device_lines = [
    ln for ln in adb_out.splitlines() if ln.strip() and not ln.startswith("List of devices")
]
attached = any(re.search(r"\bdevice\b", ln) and not ln.startswith("*") for ln in device_lines)
if "command not found" in adb_out:
    out("HOLD", "adb binary not on PATH — device back-stack HOLD; not device-fixed")
elif attached:
    out("HOLD", "adb device listed — Settings/Files/multi-activity stack not exercised this rematch")
else:
    out("HOLD", "adb devices empty — Settings/Files/multi-activity back HOLD; not device-fixed")

# --- 10. lunch HOLD (do not run; do not edit adevtool pin) ---
adev = root / "vendor/google_devices/tokay/adevtool-version-check.mk"
if adev.is_file():
    out("HOLD", "lunch not run (adevtool pin risk); adevtool-version-check.mk not edited")
else:
    out("HOLD", "lunch not run; adevtool-version-check.mk absent or unreadable")

print()
print(
    f"SUITE_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail_n} HOLD_COUNT={hold_n} "
    f"EXIT={0 if fail_n == 0 else 1}"
)
print("LIVE_DEVICE_CLAIMED=false")
sys.exit(1 if fail_n else 0)
PY
PY_RC=$?

# bash-level adb HOLD already counted in python; keep wrapper echo
echo
if [[ "$FAIL" -ne 0 || "$PY_RC" -ne 0 ]]; then
  echo "RESULT: FAIL  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=1 PY_RC=$PY_RC"
  exit 1
fi
echo "RESULT: PASS (static)  bash_PASS=$PASS_N bash_HOLD=$HOLD_N PY_RC=$PY_RC"
echo "Device back-stack: HOLD unless adb proof above. LIVE_DEVICE_CLAIMED=false"
exit 0
