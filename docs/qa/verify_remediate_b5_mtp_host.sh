#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B5-MTP (pair of T-REMEDIATE-B5-MTP
# item 24 residual). Do not trust Backend/Architect dumps.
# Host static Java extract only. Empty adb → gadget HOLD, never on-device
# charging-only PASS. Do not overwrite verify_remediate_b5_defaults_host.sh.
# No USB GO. Do not m. Do not flash. Do not lift PASS HOLD.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b5_mtp_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

USB_JAVA="frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java"
HOOKS="frameworks/base/services/core/java/com/android/server/policy/keyguard/UsbPortSecurityHooks.java"
DEFAULTS_QA="vendor/guardtalk/docs/qa/verify_remediate_b5_defaults_host.sh"

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

echo "=== Q-REMEDIATE-B5-MTP independent rematch (item 24 residual) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "FLASH=not started"
echo "ONDEVICE_CHARGING_ONLY=HOLD (never invent PASS)"
echo "PASS_HOLD=remains"
echo

echo "--- required files ---"
require_file "$USB_JAVA"
require_file "$HOOKS"
require_file "$DEFAULTS_QA"

echo
echo "--- defaults suite must remain (this card must not overwrite it) ---"
if [[ -f "$DEFAULTS_QA" ]] && rg -q 'MTP_UNLOCKED_CLAIM=forbidden' "$DEFAULTS_QA" \
  && rg -q 'verify_remediate_b5_defaults_host.sh' "$DEFAULTS_QA"; then
  pass "verify_remediate_b5_defaults_host.sh still present (not overwritten)"
else
  fail "defaults suite missing or no longer the Q-DEFAULTS rematch"
fi

echo
echo "--- packet rg (UsbDeviceManager getChargingFunctions / mustDenyUsbData) ---"
rg -n "protected long getChargingFunctions|mustDenyUsbData|FUNCTION_NONE|FUNCTION_ADB|FUNCTION_MTP|UsbPortSecurityHooks" \
  "$USB_JAVA" | head -n 80 || true
echo
echo "--- packet rg (UsbPortSecurityHooks.mustDenyUsbDataFunctions) ---"
rg -n "public static boolean mustDenyUsbDataFunctions|mustDenyUsbData|failing closed|ctx == null" \
  "$HOOKS" | head -n 40 || true

echo
echo "--- static Java (rg; not a Backend dump) ---"
require_fixed "protected long getChargingFunctions()" "$USB_JAVA" \
  "getChargingFunctions() present"
require_fixed "protected boolean mustDenyUsbData()" "$USB_JAVA" \
  "mustDenyUsbData() present"
require_fixed "UsbPortSecurityHooks" "$USB_JAVA" \
  "UsbDeviceManager still names UsbPortSecurityHooks"
require_fixed "mustDenyUsbDataFunctions" "$USB_JAVA" \
  "UsbDeviceManager still names mustDenyUsbDataFunctions"
require_fixed "public static boolean mustDenyUsbDataFunctions(Context ctx)" "$HOOKS" \
  "UsbPortSecurityHooks.mustDenyUsbDataFunctions still present"
require_fixed "if (ctx == null)" "$HOOKS" \
  "mustDenyUsbDataFunctions still null-ctx fail-closed"
require_fixed 'Slog.e(TAG, "mustDenyUsbDataFunctions: failing closed", t);' "$HOOKS" \
  "mustDenyUsbDataFunctions still catch fail-closed"

echo
echo "--- python structural rematch (brace-matched extract; not a dump) ---"
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


def strip_java_comments(src):
    out_chars = []
    i = 0
    n = len(src)
    while i < n:
        if src[i : i + 2] == "//":
            i = src.find("\n", i)
            if i < 0:
                break
            out_chars.append("\n")
            i += 1
            continue
        if src[i : i + 2] == "/*":
            end = src.find("*/", i + 2)
            if end < 0:
                break
            out_chars.append(" ")
            i = end + 2
            continue
        out_chars.append(src[i])
        i += 1
    return "".join(out_chars)


def extract_method(src, sig):
    hits = [m.start() for m in re.finditer(re.escape(sig), src)]
    if not hits:
        return None, -1, -1, 0
    idx = hits[0]
    brace = src.find("{", idx)
    if brace < 0:
        return None, -1, -1, len(hits)
    depth = 0
    i = brace
    while i < len(src):
        c = src[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                start_line = src[:idx].count("\n") + 1
                end_line = src[: i].count("\n") + 1
                return src[idx : i + 1], start_line, end_line, len(hits)
        i += 1
    return None, -1, -1, len(hits)


def compact(s):
    return re.sub(r"\s+", " ", s).strip()


usb_rel = "frameworks/base/services/usb/java/com/android/server/usb/UsbDeviceManager.java"
hooks_rel = (
    "frameworks/base/services/core/java/com/android/server/policy/keyguard/"
    "UsbPortSecurityHooks.java"
)
usb_path = root / usb_rel
hooks_path = root / hooks_rel
if not usb_path.is_file():
    out("FAIL", f"unreadable {usb_rel}")
    print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
    sys.exit(1)
if not hooks_path.is_file():
    out("FAIL", f"unreadable {hooks_rel}")
    print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
    sys.exit(1)

usb = usb_path.read_text(encoding="utf-8", errors="replace")
hooks = hooks_path.read_text(encoding="utf-8", errors="replace")

gcf, gs, ge, gcount = extract_method(usb, "protected long getChargingFunctions()")
print(f"GETCHARGINGFUNCTIONS_SPAN L{gs}-{ge} COUNT={gcount}")
if gcf is None:
    out("FAIL", "getChargingFunctions() not extracted")
    print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
    sys.exit(1)
if gcount != 1:
    out("FAIL", f"getChargingFunctions() definition count {gcount} (expected 1)")
else:
    out("PASS", "exactly one getChargingFunctions() definition")

print("GETCHARGINGFUNCTIONS_BODY")
print(gcf)

stripped = strip_java_comments(gcf)
returns = re.findall(r"return\s+([^;]+);", stripped)
print(f"GETCHARGINGFUNCTIONS_RETURNS {returns}")
if any("FUNCTION_MTP" in r for r in returns):
    out("FAIL", "NEGATIVE HIT: getChargingFunctions() returns FUNCTION_MTP")
else:
    out("PASS", "getChargingFunctions() has no return FUNCTION_MTP")
if re.search(r"UsbManager\.FUNCTION_MTP", stripped):
    out("FAIL", "NEGATIVE HIT: FUNCTION_MTP still present in getChargingFunctions() body")
else:
    out("PASS", "FUNCTION_MTP absent from getChargingFunctions() body (comments stripped)")

if "mustDenyUsbData()" not in stripped:
    out("FAIL", "getChargingFunctions() does not call mustDenyUsbData()")
else:
    out("PASS", "getChargingFunctions() calls mustDenyUsbData()")
if "isAdbEnabled()" not in stripped:
    out("FAIL", "getChargingFunctions() does not call isAdbEnabled()")
else:
    out("PASS", "getChargingFunctions() calls isAdbEnabled()")

deny_idx = stripped.find("mustDenyUsbData()")
adb_idx = stripped.find("isAdbEnabled()")
if deny_idx >= 0 and adb_idx >= 0 and deny_idx < adb_idx:
    out("PASS", "mustDenyUsbData() is evaluated before isAdbEnabled()")
else:
    out("FAIL", "mustDenyUsbData() is not first (locked deny could be skipped for ADB)")

want_deny = re.search(
    r"if\s*\(\s*mustDenyUsbData\(\s*\)\s*\)\s*\{\s*"
    r"return\s+UsbManager\.FUNCTION_NONE\s*;\s*\}",
    stripped,
)
if want_deny:
    out("PASS", "mustDenyUsbData() → return UsbManager.FUNCTION_NONE")
else:
    out("FAIL", "mustDenyUsbData() branch does not return FUNCTION_NONE")

want_adb = re.search(
    r"if\s*\(\s*isAdbEnabled\(\s*\)\s*\)\s*\{\s*"
    r"return\s+UsbManager\.FUNCTION_ADB\s*;\s*\}",
    stripped,
)
if want_adb:
    out("PASS", "isAdbEnabled() → return UsbManager.FUNCTION_ADB")
else:
    out("FAIL", "isAdbEnabled() branch does not return FUNCTION_ADB")

want_else = re.search(
    r"if\s*\(\s*isAdbEnabled\(\s*\)\s*\)\s*\{\s*"
    r"return\s+UsbManager\.FUNCTION_ADB\s*;\s*\}\s*else\s*\{\s*"
    r"return\s+UsbManager\.FUNCTION_NONE\s*;\s*\}",
    stripped,
)
if want_else:
    out("PASS", "else → return UsbManager.FUNCTION_NONE (not MTP)")
else:
    out("FAIL", "else branch does not return FUNCTION_NONE")

allowed = {"UsbManager.FUNCTION_NONE", "UsbManager.FUNCTION_ADB"}
unexpected = [r.strip() for r in returns if r.strip() not in allowed]
if unexpected:
    out("FAIL", f"unexpected getChargingFunctions() returns: {unexpected}")
else:
    out("PASS", "all getChargingFunctions() returns are FUNCTION_NONE or FUNCTION_ADB")
if len(returns) == 3:
    out("PASS", "getChargingFunctions() has exactly three return statements")
else:
    out("FAIL", f"getChargingFunctions() return count {len(returns)} (expected 3)")

md, ms, me, mcount = extract_method(usb, "protected boolean mustDenyUsbData()")
print(f"MUSTDENYUSBDATA_SPAN L{ms}-{me} COUNT={mcount}")
if md is None:
    out("FAIL", "mustDenyUsbData() not extracted")
else:
    print("MUSTDENYUSBDATA_BODY")
    print(md)
    md_s = compact(strip_java_comments(md))
    print(f"MUSTDENYUSBDATA_COMPACT {md_s}")
    if mcount != 1:
        out("FAIL", f"mustDenyUsbData() definition count {mcount} (expected 1)")
    else:
        out("PASS", "exactly one mustDenyUsbData() definition")
    if re.search(
        r"return\s+com\.android\.server\.policy\.keyguard\.UsbPortSecurityHooks"
        r"\s*\.\s*mustDenyUsbDataFunctions\s*\(\s*mContext\s*\)\s*;",
        strip_java_comments(md),
    ):
        out(
            "PASS",
            "mustDenyUsbData() still calls UsbPortSecurityHooks.mustDenyUsbDataFunctions(mContext)",
        )
    else:
        out(
            "FAIL",
            "mustDenyUsbData() no longer delegates to UsbPortSecurityHooks.mustDenyUsbDataFunctions",
        )
    if re.search(r"return\s+false\s*;", strip_java_comments(md)):
        out("FAIL", "NEGATIVE HIT: mustDenyUsbData() returns false (deny weakened)")
    else:
        out("PASS", "mustDenyUsbData() does not return constant false")

hooks_fn, hs, he, hcount = extract_method(
    hooks, "public static boolean mustDenyUsbDataFunctions(Context ctx)"
)
print(f"HOOKS_SPAN L{hs}-{he} COUNT={hcount}")
if hooks_fn is None:
    out("FAIL", "UsbPortSecurityHooks.mustDenyUsbDataFunctions not extracted")
else:
    hs_s = strip_java_comments(hooks_fn)
    if hcount != 1:
        out("FAIL", f"mustDenyUsbDataFunctions definition count {hcount}")
    else:
        out("PASS", "exactly one mustDenyUsbDataFunctions definition")
    if re.search(r"if\s*\(\s*ctx\s*==\s*null\s*\)\s*\{\s*return\s+true\s*;", hs_s):
        out("PASS", "hooks null-ctx still fail-closed (return true)")
    else:
        out("FAIL", "hooks null-ctx fail-closed missing")
    if re.search(r"catch\s*\(\s*Throwable\s+\w+\s*\)\s*\{[\s\S]*?return\s+true\s*;", hs_s):
        out("PASS", "hooks catch still fail-closed (return true)")
    else:
        out("FAIL", "hooks catch fail-closed missing")
    if "GuardTalkUsbProtectionPolicy.mustDenyUsbData(deviceLocked, userUnlocked)" in compact(
        hs_s
    ):
        out("PASS", "hooks still delegate to GuardTalkUsbProtectionPolicy.mustDenyUsbData")
    else:
        out("FAIL", "hooks no longer call GuardTalkUsbProtectionPolicy.mustDenyUsbData")

adb_fn, ads, ade, adcount = extract_method(
    usb, "protected String applyAdbFunction(String functions)"
)
print(f"APPLYADBFUNCTION_SPAN L{ads}-{ade} COUNT={adcount}")
if adb_fn is None:
    out("FAIL", "applyAdbFunction() not extracted")
else:
    ad_s = strip_java_comments(adb_fn)
    if "mustDenyUsbData()" in ad_s and "UsbManager.USB_FUNCTION_MTP" in ad_s:
        out("PASS", "applyAdbFunction still strips USB_FUNCTION_MTP when mustDenyUsbData()")
    else:
        out("FAIL", "applyAdbFunction deny strip of MTP missing (locked deny weakened)")
    if "UsbManager.USB_FUNCTION_PTP" in ad_s and "UsbManager.USB_FUNCTION_ADB" in ad_s:
        out("PASS", "applyAdbFunction still strips PTP and ADB when denied")
    else:
        out("FAIL", "applyAdbFunction deny strip of PTP/ADB missing")

xfer, xs, xe, xcount = extract_method(usb, "protected boolean isUsbTransferAllowed()")
print(f"ISUSBTRANSFERALLOWED_SPAN L{xs}-{xe} COUNT={xcount}")
if xfer is None:
    out("FAIL", "isUsbTransferAllowed() not extracted")
else:
    xf = strip_java_comments(xfer)
    if re.search(
        r"if\s*\(\s*mustDenyUsbData\(\s*\)\s*\)\s*\{\s*return\s+false\s*;", xf
    ):
        out("PASS", "isUsbTransferAllowed still fail-closed on mustDenyUsbData()")
    else:
        out("FAIL", "isUsbTransferAllowed no longer fail-closed on mustDenyUsbData()")

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
echo "--- adversarial: getChargingFunctions must not return MTP ---"
# Comment-stripped proof is the python block. rg here is a second host view.
if python3 - "$ROOT/$USB_JAVA" <<'PY'
import re, sys
from pathlib import Path
src = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
sig = "protected long getChargingFunctions()"
idx = src.find(sig)
brace = src.find("{", idx)
depth = 0
i = brace
while i < len(src):
    if src[i] == "{":
        depth += 1
    elif src[i] == "}":
        depth -= 1
        if depth == 0:
            body = src[idx:i+1]
            break
    i += 1
else:
    sys.exit(2)
# strip comments then require no FUNCTION_MTP return
out = []
j = 0
while j < len(body):
    if body[j:j+2] == "//":
        j = body.find("\n", j)
        if j < 0:
            break
        out.append("\n")
        j += 1
        continue
    if body[j:j+2] == "/*":
        end = body.find("*/", j+2)
        if end < 0:
            break
        out.append(" ")
        j = end + 2
        continue
    out.append(body[j]); j += 1
stripped = "".join(out)
sys.exit(0 if "FUNCTION_MTP" not in stripped else 1)
PY
then
  pass "second-view extract: FUNCTION_MTP absent from getChargingFunctions()"
else
  fail "NEGATIVE HIT: second-view extract still sees FUNCTION_MTP in getChargingFunctions()"
fi

echo
echo "--- stale out/ (HOLD, never product FAIL; m not run) ---"
STALE_PROP="out/target/product/komodo/product/etc/build.prop"
if [[ -f "$STALE_PROP" ]]; then
  hold "stale out/ product build.prop present — not a rebuilt user image (m not run by QA)"
else
  hold "stale out/ product build.prop absent — still not a proven built user image"
fi
hold "m not run this QA stamp (gadget image not rebuilt; never device-fixed)"

echo
echo "--- adb (gadget HOLD if empty; never invent charging-only PASS) ---"
ADB_OUT="$(adb devices -l 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN'; then
  hold "adb sees 54111FDAS000GN — this card is host-static; on-device charging-only not proven; do not lift PASS HOLD"
else
  hold "adb devices -l empty / no komodo 54111FDAS000GN — gadget HOLD, never on-device charging-only PASS"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "GADGET=HOLD"
echo "ONDEVICE_CHARGING_ONLY=HOLD"
echo "PASS_HOLD=remains"
echo "M_BUILD=not started"
echo "USB_GO=not started"
exit "$FAIL"
