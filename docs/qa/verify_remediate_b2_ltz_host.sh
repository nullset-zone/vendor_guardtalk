#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B2-LTZ (pair of T-REMEDIATE-B2-LTZ
# item 8 residual). Do not trust Backend/Architect dumps.
# Host static + lunch komodo-trunk_staging-user (not userdebug).
# Runtime LTZ/CountryDetector-absent / m / adb → HOLD (do not invent PASS;
# do not lift PASS HOLD).
# Do not overwrite verify_remediate_b2_lms_host.sh or
# verify_remediate_b2_excise_host.sh. No product edits. No USB GO. No wipe.
# No m. No commit. Do not start Q-REMEDIATE-B2-ONDEVICE. Do not re-enable
# radios. Do not invent a GNSS start.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_ltz_host.sh
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
GNSS_CFG="frameworks/base/core/res/res/values/config.xml"
HANDHELD="vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml"
APPS="vendor/guardtalk/feature-excised/apps-excised.mk"
RADIO="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
LMS_SUITE="vendor/guardtalk/docs/qa/verify_remediate_b2_lms_host.sh"
EXCISE_SUITE="vendor/guardtalk/docs/qa/verify_remediate_b2_excise_host.sh"

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

sha256_of() {
  sha256sum -- "$1" | awk '{print $1}'
}

ART_DIR="vendor/guardtalk/docs/qa/_artifacts"
mkdir -p "$ART_DIR"
DUMP_PKGS="${ART_DIR}/Q-REMEDIATE-B2-LTZ_PRODUCT_PACKAGES.txt"
DUMP_PROPS="${ART_DIR}/Q-REMEDIATE-B2-LTZ_PRODUCT_PROPERTY_OVERRIDES.txt"

token_in_file() {
  local file="$1" token="$2"
  tr ' \t' '\n' < "$file" | grep -Fxq -- "$token"
}

echo "=== Q-REMEDIATE-B2-LTZ independent rematch (item 8 residual) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "USB_GO=not started"
echo "LMS_SUITE_OVERWRITE=forbidden"
echo "EXCISE_SUITE_OVERWRITE=forbidden"
echo "PASS_HOLD=remains"
echo

echo "--- required files ---"
require_file "$SYS"
require_file "$GNSS_CFG"
require_file "$HANDHELD"
require_file "$APPS"
require_file "$RADIO"
require_file "$LMS_SUITE"
require_file "$EXCISE_SUITE"

LMS_SHA_BEFORE="$(sha256_of "$LMS_SUITE")"
EXCISE_SHA_BEFORE="$(sha256_of "$EXCISE_SUITE")"
echo "LMS_SUITE_SHA256=${LMS_SHA_BEFORE}"
echo "EXCISE_SUITE_SHA256=${EXCISE_SHA_BEFORE}"

echo
echo "--- packet rg (SystemServer CountryDetector / LTZ / LMS / GNSS / BT) ---"
rg -n 'LocationTimeZoneManagerService.Lifecycle|CountryDetectorService|FEATURE_LOCATION|LocationManagerService.Lifecycle|FEATURE_BLUETOOTH|config_enableGnssTimeUpdateService|GnssTimeUpdateService.Lifecycle' \
  "$SYS" || true
echo
echo "--- packet rg (AOSP GNSS default) ---"
rg -n 'config_enableGnssTimeUpdateService' "$GNSS_CFG" || true
echo
echo "--- packet rg (KEEP HTMLViewer / UMP) ---"
rg -n 'HTMLViewer|UniversalMediaPlayer' "$APPS" || true
echo
echo "--- packet rg (persist.radio.disabled) ---"
rg -n 'persist.radio.disabled' "$RADIO" || true

echo
echo "--- static product wiring (KEEP; RIL not re-enabled) ---"
require_fixed "HTMLViewer \\" "$APPS" "apps-excised KEEP list contains HTMLViewer"
require_fixed "UniversalMediaPlayer" "$APPS" "apps-excised KEEP / add UniversalMediaPlayer"
require_fixed "persist.radio.disabled=1" "$RADIO" \
  "radio-excised still sets persist.radio.disabled=1"
if rg -q 'persist\.radio\.disabled=0' "$RADIO"; then
  fail "radio-excised sets persist.radio.disabled=0 (radio re-enable)"
else
  pass "radio-excised does not set persist.radio.disabled=0"
fi
require_fixed '<bool name="config_enableGnssTimeUpdateService">false</bool>' \
  "$GNSS_CFG" "AOSP config_enableGnssTimeUpdateService default is false"
# Overlay/source only (exclude QA docs, installer images, binaries).
if rg -q 'config_enableGnssTimeUpdateService' vendor/guardtalk \
    --glob '*.xml' --glob '*.mk' --glob '*.java' \
    --glob '!docs/qa/**' --glob '!web-installer/**'; then
  fail "vendor/guardtalk overlays/source override config_enableGnssTimeUpdateService"
else
  pass "vendor/guardtalk xml/mk/java does not override config_enableGnssTimeUpdateService"
fi

echo
echo "--- python structural rematch (FEATURE_LOCATION else-gates) ---"
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


def ancestor_opens(src, pos):
    stack = []
    i = 0
    while i < pos:
        c = src[i]
        if c == "{":
            stack.append(i)
        elif c == "}" and stack:
            stack.pop()
        i += 1
    return list(stack)


def feature_else_ancestors(code, pos, feature_const):
    gated = []
    for open_pos in ancestor_opens(code, pos):
        close_pos = matching_close(code, open_pos)
        if close_pos is None or not (open_pos < pos < close_pos):
            continue
        prefix = code[:open_pos].rstrip()
        if not re.search(r"\belse\s*$", prefix):
            continue
        chain = code[max(0, open_pos - 1200) : open_pos]
        if "hasSystemFeature" in chain and feature_const in chain:
            gated.append((open_pos, close_pos))
    return gated


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
        ancestors = feature_else_ancestors(code, pos, feature_const)
        if not ancestors:
            ungated.append(pos)
            continue
        gated.append((pos, ancestors[-1][0], ancestors[-1][1]))
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
        out("FAIL", f"{label}: start/construct not inside FEATURE else")
        return
    lines = ", ".join(str(line_of(code, p)) for p, _, _ in gated)
    else_line = line_of(code, gated[0][1])
    out(
        "PASS",
        f"{label}: {start_needle} only inside hasSystemFeature({feature_const}) "
        f"else (start line(s) {lines}; else opens line {else_line})",
    )


def raw_unique_window(sysj, needle, must_have, label):
    raw = [
        i
        for i, line in enumerate(sysj.splitlines(), 1)
        if needle in line
    ]
    if len(raw) != 1:
        out("FAIL", f"{label}: expected exactly one site, found {raw}")
        return
    ln = raw[0]
    window = "\n".join(sysj.splitlines()[max(0, ln - 12) : ln])
    missing = [tok for tok in must_have if tok not in window]
    if missing or not re.search(r"\belse\b", window):
        out(
            "FAIL",
            f"{label}: 12-line window above L{ln} missing {missing or 'else'}",
        )
        return
    out(
        "PASS",
        f"{label}: 12-line window above L{ln} contains "
        + ", ".join(must_have)
        + " and else",
    )


sysj = read("frameworks/base/services/java/com/android/server/SystemServer.java")
gnss_cfg = read("frameworks/base/core/res/res/values/config.xml")
apps = read("vendor/guardtalk/feature-excised/apps-excised.mk")
radio = read("vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk")
handheld = read("vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml")

code = blank_java_noise(sysj)

# BT reference pattern (same FEATURE-gate shape).
assert_feature_else_start(
    code,
    "FEATURE_BLUETOOTH",
    "startServiceFromJar(BLUETOOTH_SERVICE_CLASS",
    "BT FEATURE_BLUETOOTH",
)

# LMS FEATURE_LOCATION gate must still exist (not rewritten into LTZ/CD block).
assert_feature_else_start(
    code,
    "FEATURE_LOCATION",
    "startService(LocationManagerService.Lifecycle.class)",
    "LMS FEATURE_LOCATION (must remain)",
)

lms_lines = sysj.splitlines()
# Dispatch: prove LMS FEATURE_LOCATION gate (L2383–2393) still present
# and not rewritten into this card's block.
if len(lms_lines) < 2393:
    out("FAIL", f"SystemServer.java too short ({len(lms_lines)} lines)")
else:
    lms_window = "\n".join(lms_lines[2382:2393])  # 1-indexed 2383–2393
    lms_ok = (
        "FEATURE_LOCATION" in lms_window
        and "hasSystemFeature" in lms_window
        and "LocationManagerService.Lifecycle" in lms_window
        and re.search(r"\belse\b", lms_window)
        and "startService" in lms_window
    )
    banned = []
    for tok in (
        "CountryDetectorService",
        "LocationTimeZoneManagerService",
        "GnssTimeUpdateService",
        "StartCountryDetectorService",
        "StartLocationTimeZoneManagerService",
    ):
        if tok in lms_window:
            banned.append(tok)
    if lms_ok and not banned:
        out(
            "PASS",
            "LMS FEATURE_LOCATION gate L2383–2393 still present "
            "(Lifecycle start + else); not rewritten with LTZ/CD/GNSS",
        )
    else:
        out(
            "FAIL",
            "LMS L2383–2393 rewritten or incomplete "
            f"(lms_ok={lms_ok} banned={banned})",
        )

# CountryDetector: construct + addService MUST be inside FEATURE_LOCATION else.
if "new CountryDetectorService" not in code:
    out("FAIL", "CountryDetectorService construct absent")
else:
    assert_feature_else_start(
        code,
        "FEATURE_LOCATION",
        "new CountryDetectorService",
        "CountryDetector FEATURE_LOCATION construct",
    )
if "ServiceManager.addService(Context.COUNTRY_DETECTOR" not in code:
    out("FAIL", "COUNTRY_DETECTOR addService absent")
else:
    assert_feature_else_start(
        code,
        "FEATURE_LOCATION",
        "ServiceManager.addService(Context.COUNTRY_DETECTOR",
        "CountryDetector FEATURE_LOCATION addService",
    )

raw_unique_window(
    sysj,
    "new CountryDetectorService",
    ("FEATURE_LOCATION", "hasSystemFeature"),
    "CountryDetector construct window",
)

# LTZ Lifecycle start MUST be inside FEATURE_LOCATION else.
if "startService(LocationTimeZoneManagerService.Lifecycle.class)" not in code:
    out("FAIL", "LocationTimeZoneManagerService.Lifecycle startService absent")
else:
    assert_feature_else_start(
        code,
        "FEATURE_LOCATION",
        "startService(LocationTimeZoneManagerService.Lifecycle.class)",
        "LTZ FEATURE_LOCATION",
    )

raw_unique_window(
    sysj,
    "startService(LocationTimeZoneManagerService.Lifecycle.class)",
    ("FEATURE_LOCATION", "hasSystemFeature"),
    "LTZ startService window",
)

# Exactly one start/construct site each (adversarial duplicate).
for needle, label in (
    ("startService(LocationManagerService.Lifecycle.class)", "LMS Lifecycle start"),
    ("new CountryDetectorService", "CountryDetector construct"),
    ("startService(LocationTimeZoneManagerService.Lifecycle.class)", "LTZ Lifecycle start"),
    ("startService(GnssTimeUpdateService.Lifecycle.class)", "GNSS Lifecycle start"),
):
    hits = [
        i
        for i, line in enumerate(sysj.splitlines(), 1)
        if needle in line
    ]
    if len(hits) == 1:
        out("PASS", f"exactly one {label} site (L{hits[0]})")
    else:
        out("FAIL", f"{label}: expected 1 site, found {hits}")

# GNSS must remain bool-gated (default false). Do not invent a FEATURE start.
gnss_needle = "startService(GnssTimeUpdateService.Lifecycle.class)"
gnss_pos = code.find(gnss_needle)
if gnss_pos < 0:
    out("FAIL", "GNSS Lifecycle startService absent (do not drop; keep bool gate)")
else:
    loc_else = feature_else_ancestors(code, gnss_pos, "FEATURE_LOCATION")
    if loc_else:
        lines = ", ".join(str(line_of(code, p[0])) for p in loc_else)
        out(
            "FAIL",
            f"GNSS start invented inside FEATURE_LOCATION else (else opens {lines})",
        )
    else:
        out("PASS", "GNSS start is not inside a FEATURE_LOCATION else (not invented)")
    ln = line_of(code, gnss_pos)
    window = "\n".join(sysj.splitlines()[max(0, ln - 8) : ln])
    if "config_enableGnssTimeUpdateService" in window:
        out(
            "PASS",
            f"GNSS start L{ln} still behind config_enableGnssTimeUpdateService",
        )
    else:
        out(
            "FAIL",
            f"GNSS start L{ln} missing config_enableGnssTimeUpdateService in 8-line window",
        )

if re.search(
    r'<bool\s+name="config_enableGnssTimeUpdateService"\s*>false</bool>',
    gnss_cfg,
):
    out("PASS", "AOSP config.xml config_enableGnssTimeUpdateService is false")
else:
    out("FAIL", "AOSP config_enableGnssTimeUpdateService is not false")

gt_hits = []
src_suffixes = {".xml", ".mk", ".java"}
for p in (root / "vendor/guardtalk").rglob("*"):
    if not p.is_file():
        continue
    parts = set(p.parts)
    if "qa" in parts and "docs" in parts:
        continue
    if "web-installer" in parts:
        continue
    if p.suffix.lower() not in src_suffixes:
        continue
    try:
        txt = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    if "config_enableGnssTimeUpdateService" in txt:
        gt_hits.append(str(p.relative_to(root)))
if gt_hits:
    out("FAIL", f"vendor/guardtalk GNSS overlay/override: {gt_hits}")
else:
    out("PASS", "no vendor/guardtalk xml/mk/java GNSS overlay of config_enableGnssTimeUpdateService")

# Ready-path still null-checks countryDetectorF (skip when FEATURE absent).
if "if (countryDetectorF != null)" in sysj:
    out("PASS", "MakeCountryDetectionServiceReady still null-checks countryDetectorF")
else:
    out("FAIL", "countryDetectorF null-check missing (ready-path would NPE when skipped)")

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
        '<feature name="android.hardware.location*" tags',
    )

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
gbv PRODUCT_PROPERTY_OVERRIDES | grep -v 'Build sandboxing' > "$DUMP_PROPS"
set -e
echo "DUMP_PKGS_BYTES=$(wc -c < "$DUMP_PKGS") DUMP_PKGS_WORDS=$(wc -w < "$DUMP_PKGS")"
echo "DUMP_PROPS_BYTES=$(wc -c < "$DUMP_PROPS")"

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
echo "--- user PRODUCT_PACKAGES (HTMLViewer/UMP KEEP; radios not restored) ---"
for tok in "${KEEP_PKGS[@]}"; do
  if token_in_file "$DUMP_PKGS" "$tok"; then
    pass "user PRODUCT_PACKAGES: ${tok} PRESENT (KEEP)"
  else
    fail "user PRODUCT_PACKAGES missing KEEP ${tok}"
  fi
done
if token_in_file "$DUMP_PKGS" "Bluetooth"; then
  fail "user PRODUCT_PACKAGES still has Bluetooth (radio re-enable)"
else
  pass "user PRODUCT_PACKAGES: Bluetooth ABSENT"
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
echo "--- runtime LTZ/CountryDetector-absent / m / adb HOLD (do not invent PASS) ---"
hold "runtime LTZ-absent not proven (no system_server log / service list; m not run)"
hold "runtime CountryDetector-absent not proven (no service list; m not run)"
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
echo "--- LMS / EXCISE suites not overwritten ---"
LMS_SHA_AFTER="$(sha256_of "$LMS_SUITE")"
EXCISE_SHA_AFTER="$(sha256_of "$EXCISE_SUITE")"
if [[ "$LMS_SHA_AFTER" == "$LMS_SHA_BEFORE" ]]; then
  pass "LMS suite SHA256 unchanged ($LMS_SHA_AFTER)"
else
  fail "LMS suite SHA256 changed (overwrite)"
fi
if [[ "$EXCISE_SHA_AFTER" == "$EXCISE_SHA_BEFORE" ]]; then
  pass "EXCISE suite SHA256 unchanged ($EXCISE_SHA_AFTER)"
else
  fail "EXCISE suite SHA256 changed (overwrite)"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  RESULT=PASS
else
  RESULT=FAIL
fi
echo "RESULT: ${RESULT} (host)  bash_PASS=${PASS_N} bash_FAIL=${FAIL} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "LTZ_RUNTIME_ABSENT=HOLD"
echo "COUNTRYDETECTOR_RUNTIME_ABSENT=HOLD"
echo "M=HOLD"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
echo "Q-ONDEVICE=not started"
echo "LMS_SUITE_UNTOUCHED=true"
echo "EXCISE_SUITE_UNTOUCHED=true"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
exit 0
