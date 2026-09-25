#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B2-APEX (pair of T-REMEDIATE-B2-APEX
# item 13 residual). Do not trust Backend/Architect lunch dumps.
# Host static + lunch komodo-trunk_staging-user (not userdebug).
# BCP/SSR DeviceLock jars PRESENT = HOLD (intentional Zygote; do not FAIL).
# Stale out/ APEX + adb empty = HOLD. Do not invent on-device/Zygote PASS.
# Do not lift PASS HOLD. Do not m. Do not overwrite the EXCISE suite.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_apex_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

APEX_MK="vendor/guardtalk/feature-excised/devicelock-apex-excised.mk"
FEAT="vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
APPS="vendor/guardtalk/feature-excised/apps-excised.mk"
BCP_MK="vendor/guardtalk/feature-excised/apex-bcp-excised.mk"
SSR="frameworks/base/core/java/android/app/SystemServiceRegistry.java"
ART="build/make/target/product/default_art_config.mk"
EXCISE_SUITE="vendor/guardtalk/docs/qa/verify_remediate_b2_excise_host.sh"
STALE_APEX_SYS="out/target/product/komodo/system/apex/com.android.devicelock.apex"
STALE_APEX_DIR="out/target/product/komodo/apex/com.android.devicelock"

FORBID_PKGS=(
  com.android.devicelock
  com.android.devicelock-debug
  DeviceLockController
  DeviceLockControllerDebug
  Gallery2
  GmsCompat
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
DUMP_PKGS="${ART_DIR}/Q-REMEDIATE-B2-APEX_PRODUCT_PACKAGES.txt"
DUMP_DEBUG="${ART_DIR}/Q-REMEDIATE-B2-APEX_PRODUCT_PACKAGES_DEBUG.txt"
DUMP_BCP="${ART_DIR}/Q-REMEDIATE-B2-APEX_PRODUCT_APEX_BOOT_JARS.txt"
DUMP_SSR="${ART_DIR}/Q-REMEDIATE-B2-APEX_PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS.txt"

token_in_file() {
  local file="$1" token="$2"
  tr ' \t' '\n' < "$file" | grep -Fxq -- "$token"
}

echo "=== Q-REMEDIATE-B2-APEX independent rematch (item 13 residual) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD_LIFTED=false"
echo "Q-ONDEVICE=not started"
echo "EXCISE_SUITE_OVERWRITE=false"
echo "USB_GO=not started"
echo "m=not run"
echo "T/F/Architect lunch dumps: not trusted"
echo

echo "--- required files ---"
require_file "$APEX_MK"
require_file "$FEAT"
require_file "$APPS"
require_file "$BCP_MK"
require_file "$SSR"
require_file "$ART"
require_file "$EXCISE_SUITE"

if [[ -f "$EXCISE_SUITE" ]]; then
  pass "EXCISE suite left in place (this file is a sibling)"
fi

echo
echo "--- packet rg (APEX drop / KEEP / BCP) ---"
rg -n 'com.android.devicelock|PRODUCT_PACKAGES|PRODUCT_APEX_BOOT_JARS|PRODUCT_APEX_STANDALONE' \
  "$APEX_MK" || true
echo
rg -n 'devicelock-apex-excised|apps-excised.mk' "$FEAT" || true
echo
rg -n 'GUARDTALK_APPS_KEEP|HTMLViewer|UniversalMediaPlayer|Gallery2|DeviceLockController|GmsCompat|com.android.devicelock' \
  "$APPS" | head -n 80 || true

echo
echo "--- static product wiring ---"
require_fixed "include vendor/guardtalk/feature-excised/apps-excised.mk" "$FEAT" \
  "feature-excised includes apps-excised.mk"
require_fixed "include vendor/guardtalk/feature-excised/devicelock-apex-excised.mk" "$FEAT" \
  "feature-excised includes dedicated APEX mk (not GmsCompat stanza)"
require_fixed "com.android.devicelock \\" "$APEX_MK" \
  "APEX drop list contains com.android.devicelock"
require_fixed "com.android.devicelock-debug" "$APEX_MK" \
  "APEX drop list contains com.android.devicelock-debug"
require_fixed "HTMLViewer \\" "$APPS" "apps-excised KEEP list contains HTMLViewer"
require_fixed "UniversalMediaPlayer" "$APPS" "apps-excised KEEP / add UniversalMediaPlayer"
require_fixed "Gallery2 \\" "$APPS" "apps-excised drop list still contains Gallery2"
require_fixed "DeviceLockController \\" "$APPS" \
  "apps-excised drop list still contains DeviceLockController"
require_fixed "GmsCompat \\" "$APPS" "apps-excised drop list still contains GmsCompat"
require_fixed "DeviceLockFrameworkInitializer" "$SSR" \
  "SystemServiceRegistry still hard-imports DeviceLockFrameworkInitializer"
require_fixed "com.android.devicelock:framework-devicelock" "$ART" \
  "default_art_config still lists framework-devicelock BCP"
require_fixed "com.android.devicelock:service-devicelock" "$ART" \
  "default_art_config still lists service-devicelock SSR"

# Comments may name BCP/SSR to document why they are NOT stripped.
# Only uncommented make code is a strip.
if rg -v '^\s*#' "$APEX_MK" | rg -q 'PRODUCT_APEX_BOOT_JARS'; then
  fail "devicelock-apex-excised.mk active code touches PRODUCT_APEX_BOOT_JARS (do not strip BCP)"
else
  pass "devicelock-apex-excised.mk active code does not touch PRODUCT_APEX_BOOT_JARS"
fi
if rg -v '^\s*#' "$APEX_MK" | rg -q 'PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS|PRODUCT_APEX_SYSTEM_SERVER_JARS'; then
  fail "devicelock-apex-excised.mk active code touches SSR/BCP system-server jars (do not strip)"
else
  pass "devicelock-apex-excised.mk active code does not touch SSR jar lists"
fi

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

feat = read("vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk")
apex = read("vendor/guardtalk/feature-excised/devicelock-apex-excised.mk")
apps = read("vendor/guardtalk/feature-excised/apps-excised.mk")
bcp = read("vendor/guardtalk/feature-excised/apex-bcp-excised.mk")
ssr = read("frameworks/base/core/java/android/app/SystemServiceRegistry.java")

drop = assignment_tokens(apex, "GUARDTALK_DEVICELOCK_APEX_DROP")
apps_drop = assignment_tokens(apps, "GUARDTALK_APPS_PACKAGES")
keep = assignment_tokens(apps, "GUARDTALK_APPS_KEEP")

for name in ("com.android.devicelock", "com.android.devicelock-debug"):
    if name in drop:
        out("PASS", f"{name} is in GUARDTALK_DEVICELOCK_APEX_DROP")
    else:
        out("FAIL", f"{name} missing from GUARDTALK_DEVICELOCK_APEX_DROP")

if "filter-out $(GUARDTALK_DEVICELOCK_APEX_DROP),$(PRODUCT_PACKAGES)" in apex.replace(" ", ""):
    out("PASS", "APEX mk filter-out writes PRODUCT_PACKAGES")
elif "filter-out" in apex and "PRODUCT_PACKAGES" in apex and "GUARDTALK_DEVICELOCK_APEX_DROP" in apex:
    out("PASS", "APEX mk filter-out PRODUCT_PACKAGES via GUARDTALK_DEVICELOCK_APEX_DROP")
else:
    out("FAIL", "APEX mk does not filter PRODUCT_PACKAGES")

apex_code = "\n".join(line.split("#", 1)[0] for line in apex.splitlines())
if "PRODUCT_APEX_BOOT_JARS" in apex_code or "PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS" in apex_code:
    out("FAIL", "APEX mk active code strips BCP/SSR (Zygote boot-loop class)")
else:
    out("PASS", "APEX mk active code does not strip BCP/SSR jar lists")

idx_apps = feat.find("include vendor/guardtalk/feature-excised/apps-excised.mk")
idx_apex = feat.find("include vendor/guardtalk/feature-excised/devicelock-apex-excised.mk")
if idx_apps >= 0 and idx_apex > idx_apps:
    out("PASS", "include order: apps-excised KEEP then dedicated APEX filter")
else:
    out("FAIL", "devicelock-apex-excised.mk is not included AFTER apps-excised.mk")

# KEEP restore is inside apps-excised; APEX include must still be later in the
# bridge so HTMLViewer/UMP cannot be stripped by this filter.
if "HTMLViewer" in keep and "UniversalMediaPlayer" in keep:
    out("PASS", "GUARDTALK_APPS_KEEP still has HTMLViewer and UniversalMediaPlayer")
else:
    out("FAIL", f"KEEP missing HTMLViewer/UMP: {keep}")

if "Gallery2" in apps_drop:
    out("PASS", "Gallery2 still in GUARDTALK_APPS_PACKAGES drop list")
else:
    out("FAIL", "Gallery2 missing from drop list (un-excise)")

if "Gallery2" in keep:
    out("FAIL", "Gallery2 restored via KEEP (un-excise)")
else:
    out("PASS", "Gallery2 is not in GUARDTALK_APPS_KEEP")

for name in ("GmsCompat", "DeviceLockController", "DeviceLockControllerDebug"):
    if name in apps_drop:
        out("PASS", f"{name} still in GmsCompat/controller drop stanza")
    else:
        out("FAIL", f"{name} missing from apps drop stanza")

if "com.android.devicelock" in apps_drop:
    out("FAIL", "com.android.devicelock folded into GmsCompat stanza")
else:
    out("PASS", "APEX token not in GUARDTALK_APPS_PACKAGES (dedicated mk)")

# Active (uncommented) BCP filter of DeviceLock in apex-bcp-excised.mk is FAIL.
active_bcp = []
for i, line in enumerate(bcp.splitlines(), 1):
    code = line.split("#", 1)[0]
    if "devicelock" in code.lower() and code.strip():
        active_bcp.append(f"{i}:{code.strip()}")
if active_bcp:
    out("FAIL", "apex-bcp-excised.mk actively mentions DeviceLock: " + "; ".join(active_bcp))
else:
    out("PASS", "apex-bcp-excised.mk has no active DeviceLock BCP strip")

if "import android.devicelock.DeviceLockFrameworkInitializer;" in ssr:
    out("HOLD", "SSR still hard-imports DeviceLockFrameworkInitializer (BCP required)")
else:
    out("FAIL", "SSR DeviceLockFrameworkInitializer import missing (BCP HOLD rationale gone)")

if "DeviceLockFrameworkInitializer.registerServiceWrappers()" in ssr:
    out("HOLD", "SSR still calls DeviceLockFrameworkInitializer.registerServiceWrappers()")
else:
    out("FAIL", "SSR DeviceLock registerServiceWrappers call missing")

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
gbv PRODUCT_PACKAGES_DEBUG | grep -v 'Build sandboxing' > "$DUMP_DEBUG"
gbv PRODUCT_APEX_BOOT_JARS | grep -v 'Build sandboxing' > "$DUMP_BCP"
gbv PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS | grep -v 'Build sandboxing' > "$DUMP_SSR"
set -e
echo "DUMP_PKGS_BYTES=$(wc -c < "$DUMP_PKGS") DUMP_PKGS_WORDS=$(wc -w < "$DUMP_PKGS")"
echo "DUMP_BCP_WORDS=$(wc -w < "$DUMP_BCP") DUMP_SSR_WORDS=$(wc -w < "$DUMP_SSR")"

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
echo "--- user PRODUCT_PACKAGES (APEX token + KEEP + no un-excise) ---"
for tok in "${FORBID_PKGS[@]}"; do
  if token_in_file "$DUMP_PKGS" "$tok"; then
    fail "user PRODUCT_PACKAGES still has ${tok} (disabled-but-present is FAIL)"
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

if token_in_file "$DUMP_DEBUG" "com.android.devicelock" || token_in_file "$DUMP_DEBUG" "com.android.devicelock-debug"; then
  fail "PRODUCT_PACKAGES_DEBUG still has com.android.devicelock*"
else
  pass "PRODUCT_PACKAGES_DEBUG: com.android.devicelock* ABSENT"
fi

echo
echo "--- BCP / SSR DeviceLock jars (PRESENT = HOLD, not FAIL) ---"
if token_in_file "$DUMP_BCP" "com.android.devicelock:framework-devicelock"; then
  hold "PRODUCT_APEX_BOOT_JARS: com.android.devicelock:framework-devicelock PRESENT (intentional Zygote; not FAIL)"
else
  fail "PRODUCT_APEX_BOOT_JARS missing com.android.devicelock:framework-devicelock (BCP stripped — Zygote risk)"
fi
if token_in_file "$DUMP_SSR" "com.android.devicelock:service-devicelock"; then
  hold "PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS: com.android.devicelock:service-devicelock PRESENT (intentional Zygote; not FAIL)"
else
  fail "PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS missing com.android.devicelock:service-devicelock (SSR stripped — Zygote risk)"
fi

echo
echo "--- stale out/ APEX is NOT product truth (m not run) ---"
if [[ -e "$STALE_APEX_SYS" || -e "$STALE_APEX_DIR" ]]; then
  hold "stale out/target/product/komodo DeviceLock APEX still present; not treated as product truth:"
  ls -ld "$STALE_APEX_SYS" "$STALE_APEX_DIR" 2>/dev/null || true
else
  hold "stale DeviceLock APEX out artifacts absent — still not a proven user image (m not run)"
fi
hold "m not run this QA stamp (not a built user image; never device-fixed)"
hold "on-device / Zygote DeviceLock-absent not claimed (do not invent PASS)"
hold "PASS HOLD remains (not lifted)"

echo
echo "--- adb / device HOLD ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN[[:space:]]'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; do not start ONDEVICE; not device-fixed"
else
  hold "adb devices empty / no komodo 54111FDAS000GN — device HOLD, never device-fixed"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "BCP_SSR=HOLD_IF_PRESENT"
echo "STALE_OUT_APEX=HOLD"
echo "DEVICE=HOLD"
echo "ZYGOTE=not claimed"
echo "PASS_HOLD=remains"
echo "Q-ONDEVICE=not started"
echo "EXCISE_SUITE=not overwritten"
exit "$FAIL"
