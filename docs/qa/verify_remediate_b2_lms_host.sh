#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B2-LMS (pair of T-REMEDIATE-B2-LMS
# item 8 residual). Do not trust Backend/Architect dumps.
# Host static + lunch komodo-trunk_staging-user (not userdebug).
# Runtime LMS-absent / m / adb → HOLD (do not invent PASS; do not lift PASS HOLD).
# Do not overwrite verify_remediate_b2_excise_host.sh (that card HOLDs LMS start
# historically). No product edits. No USB GO. No wipe. No m. No commit.
# Do not start Q-REMEDIATE-B2-ONDEVICE. Do not re-enable radios.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_lms_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

SYS="frameworks/base/services/java/com/android/server/SystemServer.java"
HANDHELD="vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml"
LOC="vendor/guardtalk/feature-excised/loc-excised.mk"
APPS="vendor/guardtalk/feature-excised/apps-excised.mk"
RADIO="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
EXCISE_SUITE="vendor/guardtalk/docs/qa/verify_remediate_b2_excise_host.sh"

FORBID_PKGS=(
  FusedLocation
  gnssd
)
KEEP_PKGS=(
  HTMLViewer
  UniversalMediaPlayer
)

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

require_fixed() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && rg -qF -- "$pat" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
}

ART_DIR="vendor/guardtalk/docs/qa/_artifacts"
mkdir -p "$ART_DIR"
DUMP_PKGS="${ART_DIR}/Q-REMEDIATE-B2-LMS_PRODUCT_PACKAGES.txt"
DUMP_SSA="${ART_DIR}/Q-REMEDIATE-B2-LMS_PRODUCT_SYSTEM_SERVER_APPS.txt"
DUMP_PROPS="${ART_DIR}/Q-REMEDIATE-B2-LMS_PRODUCT_PROPERTY_OVERRIDES.txt"

token_in_file() {
  local file="$1" token="$2"
  tr ' \t' '\n' < "$file" | grep -Fxq -- "$token"
}

echo "=== Q-REMEDIATE-B2-LMS independent rematch (item 8 residual) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "USB_GO=not started"
echo "EXCISE_SUITE_OVERWRITE=forbidden (historical LMS-start HOLD card)"
echo "PASS_HOLD=remains"
echo

echo "--- required files ---"
require_file "$SYS"
require_file "$HANDHELD"
require_file "$LOC"
require_file "$APPS"
require_file "$RADIO"
require_file "$EXCISE_SUITE"

echo
echo "--- packet rg (SystemServer LMS / BT FEATURE gates) ---"
rg -n 'LocationManagerService.Lifecycle|FEATURE_LOCATION|FEATURE_BLUETOOTH|StartBluetoothService|StartLocationManagerService' \
  "$SYS" || true
echo
echo "--- packet rg (handheld live vs comment location features) ---"
rg -n 'android.hardware.location' "$HANDHELD" || true
echo
echo "--- packet rg (loc-excised FusedLocation / gnssd) ---"
rg -n 'FusedLocation|gnssd' "$LOC" || true
echo
echo "--- packet rg (KEEP HTMLViewer / UMP) ---"
rg -n 'HTMLViewer|UniversalMediaPlayer' "$APPS" || true
echo
echo "--- packet rg (persist.radio.disabled) ---"
rg -n 'persist.radio.disabled' "$RADIO" || true

echo
echo "--- static product wiring (loc-excised still drops; KEEP; RIL) ---"
require_fixed "FusedLocation \\" "$LOC" "loc-excised drop list contains FusedLocation"
require_fixed "gnssd \\" "$LOC" "loc-excised drop list contains gnssd"
require_fixed "filter-out FusedLocation" "$LOC" \
  "loc-excised filter-out FusedLocation from PRODUCT_SYSTEM_SERVER_APPS"
require_fixed "HTMLViewer \\" "$APPS" "apps-excised KEEP list contains HTMLViewer"
require_fixed "UniversalMediaPlayer" "$APPS" "apps-excised KEEP / add UniversalMediaPlayer"
require_fixed "persist.radio.disabled=1" "$RADIO" \
  "radio-excised still sets persist.radio.disabled=1"
if rg -q 'persist\.radio\.disabled=0' "$RADIO"; then
  fail "radio-excised sets persist.radio.disabled=0 (radio re-enable)"
else
  pass "radio-excised does not set persist.radio.disabled=0"
fi

echo
echo "--- python structural rematch (FEATURE_LOCATION else-gate) ---"
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
        fail += 1
    else:
        hold_n += 1


def read(rel):
    p = root / rel
    if not p.is_file():
        out("FAIL", f"unreadable {rel}")
        return ""
    return p.read_text(encoding="utf-8", errors="replace")


def assignment_tokens(src, var):
    tokens = []
    lines = src.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        code = raw.split("#", 1)[0].rstrip()
        m = re.match(rf"^{re.escape(var)}\s*(\+|:)??=\s*(.*)$", code)
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


def blank_java_noise(src):
    """Replace comments and string/char literals with spaces; keep length."""
    out_chars = []
    i = 0
    n = len(src)
    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if ch == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                out_chars.append(" " if src[i] != "\n" else "\n")
                i += 1
            continue
        if ch == "/" and nxt == "*":
            out_chars.extend("  ")
            i += 2
            while i < n and not (src[i] == "*" and i + 1 < n and src[i + 1] == "/"):
                out_chars.append("\n" if src[i] == "\n" else " ")
                i += 1
            if i < n:
                out_chars.extend("  ")
                i += 2
            continue
        if ch in "\"'":
            quote = ch
            out_chars.append(" ")
            i += 1
            while i < n:
                if src[i] == "\\":
                    out_chars.append(" ")
                    i += 1
                    if i < n:
                        out_chars.append("\n" if src[i] == "\n" else " ")
                        i += 1
                    continue
                if src[i] == quote:
                    out_chars.append(" ")
                    i += 1
                    break
                out_chars.append("\n" if src[i] == "\n" else " ")
                i += 1
            continue
        out_chars.append(ch)
        i += 1
    return "".join(out_chars)


def innermost_open(src, pos):
    stack = []
    i = 0
    while i < pos:
        c = src[i]
        if c == "{":
            stack.append(i)
        elif c == "}" and stack:
            stack.pop()
        i += 1
    return stack[-1] if stack else None


def matching_close(src, open_pos):
    depth = 0
    i = open_pos
    n = len(src)
    while i < n:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return None


def line_of(src, pos):
    return src.count("\n", 0, pos) + 1


def assert_feature_else_start(code, feature_const, start_needle, label):
    hits = []
    start = 0
    while True:
        pos = code.find(start_needle, start)
        if pos < 0:
            break
        hits.append(pos)
        start = pos + len(start_needle)
    if not hits:
        out("FAIL", f"{label}: start needle absent ({start_needle})")
        return
    gated = []
    ungated = []
    for pos in hits:
        open_pos = innermost_open(code, pos)
        if open_pos is None:
            ungated.append(pos)
            continue
        close_pos = matching_close(code, open_pos)
        if close_pos is None or not (open_pos < pos < close_pos):
            ungated.append(pos)
            continue
        prefix = code[:open_pos].rstrip()
        if not re.search(r"\belse\s*$", prefix):
            ungated.append(pos)
            continue
        # Sibling if-chain immediately before this else { ... }.
        chain = code[max(0, open_pos - 1200) : open_pos]
        if "hasSystemFeature" in chain and feature_const in chain:
            gated.append((pos, open_pos, close_pos))
        else:
            ungated.append(pos)
    if ungated:
        lines = ", ".join(str(line_of(code, p)) for p in ungated)
        out(
            "FAIL",
            f"{label}: unconditional / non-else start of {start_needle} "
            f"(lines {lines})",
        )
        return
    extra = []
    for pos, open_pos, close_pos in gated:
        if not (open_pos < pos < close_pos):
            extra.append(pos)
    if extra:
        out("FAIL", f"{label}: startService not inside FEATURE else")
        return
    lines = ", ".join(str(line_of(code, p)) for p, _, _ in gated)
    else_line = line_of(code, gated[0][1])
    out(
        "PASS",
        f"{label}: {start_needle} only inside hasSystemFeature({feature_const}) "
        f"else (start line(s) {lines}; else opens line {else_line})",
    )


sysj = read("frameworks/base/services/java/com/android/server/SystemServer.java")
handheld = read("vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml")
loc = read("vendor/guardtalk/feature-excised/loc-excised.mk")
apps = read("vendor/guardtalk/feature-excised/apps-excised.mk")
radio = read("vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk")

code = blank_java_noise(sysj)

# BT reference pattern (same FEATURE-gate shape).
assert_feature_else_start(
    code,
    "FEATURE_BLUETOOTH",
    "startServiceFromJar(BLUETOOTH_SERVICE_CLASS",
    "BT FEATURE_BLUETOOTH",
)

# LMS: startService of Lifecycle MUST be inside FEATURE_LOCATION else.
lms_needles = [
    "startService(LocationManagerService.Lifecycle.class)",
    "startService(LocationManagerService.class)",
]
lms_hits = [n for n in lms_needles if n in code]
if "startService(LocationManagerService.class)" in code:
    out(
        "FAIL",
        "LocationManagerService.class startService present (Lifecycle-only expected)",
    )
if "startService(LocationManagerService.Lifecycle.class)" not in code:
    out("FAIL", "LocationManagerService.Lifecycle startService absent")
else:
    assert_feature_else_start(
        code,
        "FEATURE_LOCATION",
        "startService(LocationManagerService.Lifecycle.class)",
        "LMS FEATURE_LOCATION",
    )

# Raw-source adversarial: FEATURE_LOCATION and startService share a short window
# that contains else (catches comment-only FEATURE next to unconditional start).
raw_lms = [
    i
    for i, line in enumerate(sysj.splitlines(), 1)
    if "LocationManagerService.Lifecycle" in line and "startService" in line
]
if len(raw_lms) != 1:
    out(
        "FAIL",
        f"expected exactly one Lifecycle startService, found {raw_lms}",
    )
else:
    ln = raw_lms[0]
    window = "\n".join(sysj.splitlines()[max(0, ln - 12) : ln])
    if (
        "FEATURE_LOCATION" in window
        and "hasSystemFeature" in window
        and re.search(r"\belse\b", window)
    ):
        out(
            "PASS",
            f"12-line window above startService L{ln} contains "
            "hasSystemFeature(FEATURE_LOCATION) and else",
        )
    else:
        out(
            "FAIL",
            f"12-line window above startService L{ln} missing FEATURE_LOCATION else",
        )

# Handheld: strip XML comments, then live <feature name="android.hardware.location*".
xml_no_comments = re.sub(r"<!--.*?-->", "", handheld, flags=re.S)
live = re.findall(
    r'<feature\s+[^>]*name="android\.hardware\.location(?:\.[^"]*)?"',
    xml_no_comments,
)
if live:
    out("FAIL", f"handheld live android.hardware.location* feature tags: {live}")
else:
    out(
        "PASS",
        "handheld_core_hardware.prebuilt.xml has no live "
        "<feature name=\"android.hardware.location*\" tags",
    )
if re.search(r"android\.hardware\.location", handheld):
    out(
        "PASS",
        "handheld still mentions android.hardware.location in comments (comment-only OK)",
    )

loc_drop = assignment_tokens(loc, "GUARDTALK_LOC_PACKAGES")
for name in ("FusedLocation", "gnssd"):
    if name in loc_drop:
        out("PASS", f"{name} is in GUARDTALK_LOC_PACKAGES drop list")
    else:
        out("FAIL", f"{name} missing from GUARDTALK_LOC_PACKAGES")

if "filter-out FusedLocation" in loc and "PRODUCT_SYSTEM_SERVER_APPS" in loc:
    out("PASS", "loc-excised still writes back PRODUCT_SYSTEM_SERVER_APPS without FusedLocation")
else:
    out("FAIL", "PRODUCT_SYSTEM_SERVER_APPS FusedLocation filter missing")

keep = assignment_tokens(apps, "GUARDTALK_APPS_KEEP")
for name in ("HTMLViewer", "UniversalMediaPlayer"):
    if name in keep:
        out("PASS", f"{name} is in GUARDTALK_APPS_KEEP")
    else:
        out("FAIL", f"{name} missing from GUARDTALK_APPS_KEEP")
drop_apps = assignment_tokens(apps, "GUARDTALK_APPS_PACKAGES")
if "HTMLViewer" in drop_apps:
    out("FAIL", "HTMLViewer is in apps drop list (KEEP must remain)")
else:
    out("PASS", "HTMLViewer is not in GUARDTALK_APPS_PACKAGES drop list")

if re.search(r"persist\.radio\.disabled\s*=\s*1", radio):
    out("PASS", "guardtalk-radio-excised.mk still sets persist.radio.disabled=1")
else:
    out("FAIL", "persist.radio.disabled=1 missing from radio-excised")
if re.search(r"persist\.radio\.disabled\s*=\s*0", radio):
    out("FAIL", "persist.radio.disabled=0 in radio-excised (radio re-enable)")
else:
    out("PASS", "persist.radio.disabled=0 absent from radio-excised")

print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
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

VARIANT="$(gbv TARGET_BUILD_VARIANT | grep -v 'Build sandboxing' | tail -n 1 | tr -d '[:space:]')"
PRODUCT="$(gbv TARGET_PRODUCT | grep -v 'Build sandboxing' | tail -n 1 | tr -d '[:space:]')"
set +e
gbv PRODUCT_PACKAGES | grep -v 'Build sandboxing' > "$DUMP_PKGS"
gbv PRODUCT_SYSTEM_SERVER_APPS | grep -v 'Build sandboxing' > "$DUMP_SSA"
gbv PRODUCT_PROPERTY_OVERRIDES | grep -v 'Build sandboxing' > "$DUMP_PROPS"
set -e
echo "DUMP_PKGS_BYTES=$(wc -c < "$DUMP_PKGS") DUMP_PKGS_WORDS=$(wc -w < "$DUMP_PKGS")"
echo "DUMP_SSA_WORDS=$(wc -w < "$DUMP_SSA") DUMP_PROPS_BYTES=$(wc -c < "$DUMP_PROPS")"

echo "TARGET_PRODUCT=${PRODUCT}"
echo "TARGET_BUILD_VARIANT=${VARIANT}"

if [[ "$PRODUCT" == "komodo" ]]; then
  pass "TARGET_PRODUCT=komodo"
else
  fail "TARGET_PRODUCT=${PRODUCT} (expected komodo)"
fi

if [[ "$VARIANT" == "user" ]]; then
  pass "TARGET_BUILD_VARIANT=user (not userdebug)"
elif [[ "$VARIANT" == "userdebug" ]]; then
  fail "NEGATIVE HIT: userdebug leftover as product lunch truth (variant=$VARIANT)"
else
  fail "TARGET_BUILD_VARIANT=${VARIANT} (expected user)"
fi

echo
echo "--- user PRODUCT_PACKAGES (FusedLocation/gnssd ABSENT; HTMLViewer/UMP PRESENT) ---"
for tok in "${FORBID_PKGS[@]}"; do
  if token_in_file "$DUMP_PKGS" "$tok"; then
    fail "user PRODUCT_PACKAGES still has ${tok}"
  else
    pass "user PRODUCT_PACKAGES: ${tok} ABSENT"
  fi
done
for tok in "${KEEP_PKGS[@]}"; do
  if token_in_file "$DUMP_PKGS" "$tok"; then
    pass "user PRODUCT_PACKAGES: ${tok} PRESENT (KEEP)"
  else
    fail "user PRODUCT_PACKAGES missing KEEP ${tok}"
  fi
done

echo
echo "--- user PRODUCT_SYSTEM_SERVER_APPS ---"
if token_in_file "$DUMP_SSA" "FusedLocation"; then
  fail "PRODUCT_SYSTEM_SERVER_APPS still has FusedLocation"
else
  pass "PRODUCT_SYSTEM_SERVER_APPS: FusedLocation ABSENT"
fi

echo
echo "--- user PRODUCT_PROPERTY_OVERRIDES (do not re-enable radios) ---"
if grep -Fq 'persist.radio.disabled=1' "$DUMP_PROPS"; then
  pass "PRODUCT_PROPERTY_OVERRIDES contains persist.radio.disabled=1"
else
  fail "PRODUCT_PROPERTY_OVERRIDES missing persist.radio.disabled=1"
fi
if grep -Fq 'persist.radio.disabled=0' "$DUMP_PROPS"; then
  fail "PRODUCT_PROPERTY_OVERRIDES sets persist.radio.disabled=0 (radio re-enable)"
else
  pass "PRODUCT_PROPERTY_OVERRIDES does not set persist.radio.disabled=0"
fi

echo
echo "--- runtime LMS-absent / m / adb HOLD (do not invent PASS) ---"
hold "runtime LMS-absent not proven (no system_server log / service list; m not run)"
hold "m not run this QA stamp (not a built user image; never device-fixed)"
hold "PASS HOLD remains — this card does not lift it"

echo
echo "--- adb / device HOLD ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN[[:space:]]'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; do not start Q-ONDEVICE; not device-fixed"
else
  hold "adb devices empty / no komodo 54111FDAS000GN — device HOLD, never device-fixed"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  RESULT=PASS
else
  RESULT=FAIL
fi
echo "RESULT: ${RESULT} (host)  bash_PASS=${PASS_N} bash_FAIL=${FAIL} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "LMS_RUNTIME_ABSENT=HOLD"
echo "M=HOLD"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
echo "Q-ONDEVICE=not started"
echo "EXCISE_SUITE_UNTOUCHED=true"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
