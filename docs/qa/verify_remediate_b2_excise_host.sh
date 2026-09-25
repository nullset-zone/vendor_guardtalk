#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B2-EXCISE (pair of T-REMEDIATE-B2-EXCISE
# items 8, 10, 12, 13). Do not trust Backend/Architect lunch dumps.
# Host static + lunch komodo-trunk_staging-user (not userdebug).
# LMS start + DeviceLock APEX + vendor.pktrouter leftover + adb → HOLD
# (do not invent PASS). Do not invent on-device GNSS-dead.
# No product edits. No USB GO. No wipe. No m. No commit.
# Do not start Q-REMEDIATE-B2-ONDEVICE. Do not overwrite kernel suite.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_excise_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

APPS="vendor/guardtalk/feature-excised/apps-excised.mk"
LOC="vendor/guardtalk/feature-excised/loc-excised.mk"
FEAT="vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
HANDHELD="vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml"
GOS="frameworks/base/services/core/java/com/android/server/pm/GosPackageStatePermission.java"
SYS="frameworks/base/services/java/com/android/server/SystemServer.java"
PKT="vendor/google_devices/komodo/proprietary/vendor/etc/init/pktrouter.rc"
BIP="vendor/google_devices/komodo/proprietary/vendor/etc/init/bipchmgr.rc"
VPROP="vendor/google_devices/komodo/sysprop/vendor.prop"
STALE_FL="out/target/product/komodo/system/priv-app/FusedLocation"
STALE_GMS="out/target/product/komodo/system/priv-app/GmsCompat"
STALE_DLC="out/target/product/komodo/system/priv-app/DeviceLockController"

FORBID_PKGS=(
  GmsCompat
  GmsCompatConfig
  GmsCompatLib
  AppCompatConfig
  FusedLocation
  gnssd
  NetworkLocation
  bipchmgr
  wfc-pkt-router
  DeviceLockController
  DeviceLockControllerDebug
)
KEEP_PKGS=(
  HTMLViewer
  UniversalMediaPlayer
)
FORBID_COPY=(
  /etc/init/init.gnss.rc
  /etc/init/pixel-gnss-default.rc
  /etc/init/pktrouter.rc
  /etc/init/bipchmgr.rc
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
DUMP_PKGS="${ART_DIR}/Q-REMEDIATE-B2-EXCISE_PRODUCT_PACKAGES.txt"
DUMP_SSA="${ART_DIR}/Q-REMEDIATE-B2-EXCISE_PRODUCT_SYSTEM_SERVER_APPS.txt"
DUMP_COPY="${ART_DIR}/Q-REMEDIATE-B2-EXCISE_PRODUCT_COPY_FILES.txt"

# File-based token match. Do not store PRODUCT_PACKAGES in a bash word
# (nsjail noise + command-sub can flake KEEP tokens that are present on disk).
token_in_file() {
  local file="$1" token="$2"
  tr ' \t' '\n' < "$file" | grep -Fxq -- "$token"
}

copy_needle_in_file() {
  local file="$1" needle="$2"
  tr ' :' '\n' < "$file" | grep -Fq -- "$needle"
}

echo "=== Q-REMEDIATE-B2-EXCISE independent rematch (items 8,10,12,13) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "Q-KERNEL=sibling not overwritten"
echo "Q-TELEMETRY=not started"
echo "USB_GO=not started"
echo "GNSS_DEAD_ONDEVICE=not claimed"
echo

echo "--- required files ---"
require_file "$APPS"
require_file "$LOC"
require_file "$FEAT"
require_file "$HANDHELD"
require_file "$GOS"
require_file "$SYS"
require_file "$PKT"
require_file "$BIP"
require_file "$VPROP"

echo
echo "--- packet rg (GmsCompat / AppCompatConfig / KEEP) ---"
rg -n 'GmsCompat|AppCompatConfig|HTMLViewer|UniversalMediaPlayer|DeviceLockController' \
  "$APPS" || true
echo
echo "--- packet rg (FusedLocation / gnssd / pkt / bip) ---"
rg -n 'FusedLocation|gnssd|NetworkLocation|pktrouter|bipchmgr|wfc-pkt-router' \
  "$LOC" || true
echo
echo "--- packet rg (GmsCompatApp.PKG_NAME) ---"
rg -n 'GmsCompatApp.PKG_NAME' "$GOS" || true
echo
echo "--- packet rg (LMS Lifecycle) ---"
rg -n 'LocationManagerService.Lifecycle' "$SYS" || true
echo
echo "--- packet rg (service stanzas in vendor init) ---"
rg -n 'service ' "$PKT" "$BIP" || true

echo
echo "--- static product wiring ---"
require_fixed "include vendor/guardtalk/feature-excised/apps-excised.mk" "$FEAT" \
  "feature-excised includes apps-excised.mk"
require_fixed "include vendor/guardtalk/feature-excised/loc-excised.mk" "$FEAT" \
  "feature-excised includes loc-excised.mk"
require_fixed "FusedLocation \\" "$LOC" "loc-excised drop list contains FusedLocation"
require_fixed "gnssd \\" "$LOC" "loc-excised drop list contains gnssd"
require_fixed "NetworkLocation \\" "$LOC" "loc-excised drop list contains NetworkLocation"
require_fixed "bipchmgr \\" "$LOC" "loc-excised drop list contains bipchmgr"
require_fixed "wfc-pkt-router" "$LOC" "loc-excised drop list contains wfc-pkt-router"
require_fixed "filter-out FusedLocation" "$LOC" \
  "loc-excised filter-out FusedLocation from PRODUCT_SYSTEM_SERVER_APPS"
require_fixed "/etc/init/init.gnss.rc" "$LOC" "loc-excised drops init.gnss.rc from COPY_FILES"
require_fixed "/etc/init/pixel-gnss-default.rc" "$LOC" \
  "loc-excised drops pixel-gnss-default.rc from COPY_FILES"
require_fixed "/etc/init/pktrouter.rc" "$LOC" "loc-excised drops pktrouter.rc from COPY_FILES"
require_fixed "/etc/init/bipchmgr.rc" "$LOC" "loc-excised drops bipchmgr.rc from COPY_FILES"
require_fixed "GmsCompat \\" "$APPS" "apps-excised drop list contains GmsCompat"
require_fixed "GmsCompatConfig \\" "$APPS" "apps-excised drop list contains GmsCompatConfig"
require_fixed "GmsCompatLib \\" "$APPS" "apps-excised drop list contains GmsCompatLib"
require_fixed "AppCompatConfig \\" "$APPS" "apps-excised drop list contains AppCompatConfig"
require_fixed "DeviceLockController \\" "$APPS" "apps-excised drop list contains DeviceLockController"
require_fixed "DeviceLockControllerDebug" "$APPS" \
  "apps-excised drop list contains DeviceLockControllerDebug"
require_fixed "HTMLViewer \\" "$APPS" "apps-excised KEEP list contains HTMLViewer"
require_fixed "UniversalMediaPlayer" "$APPS" "apps-excised KEEP / add UniversalMediaPlayer"
require_fixed "PRODUCT_PACKAGES += UniversalMediaPlayer" "$APPS" \
  "apps-excised explicitly adds UniversalMediaPlayer after filter-out"
require_fixed "GmsCompatApp.PKG_NAME.equals(pkgName)" "$GOS" \
  "GosPackageStatePermission special-cases GmsCompatApp.PKG_NAME"
require_fixed "tolerated (GmsCompat excised)" "$GOS" \
  "GosPackageStatePermission log-and-return for missing GmsCompat"

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
    """Collect tokens from VAR := / += continuation lists (comments stripped)."""
    tokens = []
    lines = src.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        code = raw.split("#", 1)[0].rstrip()
        # Make := and += both count (apps KEEP / loc drop use :=).
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

apps = read("vendor/guardtalk/feature-excised/apps-excised.mk")
loc = read("vendor/guardtalk/feature-excised/loc-excised.mk")
feat = read("vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk")
gos = read("frameworks/base/services/core/java/com/android/server/pm/GosPackageStatePermission.java")
sysj = read("frameworks/base/services/java/com/android/server/SystemServer.java")
pkt = read("vendor/google_devices/komodo/proprietary/vendor/etc/init/pktrouter.rc")
bip = read("vendor/google_devices/komodo/proprietary/vendor/etc/init/bipchmgr.rc")
handheld = read("vendor/guardtalk/feature-excised/handheld_core_hardware.prebuilt.xml")
vprop = read("vendor/google_devices/komodo/sysprop/vendor.prop")

drop = assignment_tokens(apps, "GUARDTALK_APPS_PACKAGES")
keep = assignment_tokens(apps, "GUARDTALK_APPS_KEEP")
loc_drop = assignment_tokens(loc, "GUARDTALK_LOC_PACKAGES")

for name in (
    "GmsCompat",
    "GmsCompatConfig",
    "GmsCompatLib",
    "AppCompatConfig",
    "DeviceLockController",
    "DeviceLockControllerDebug",
):
    if name in drop:
        out("PASS", f"{name} is in GUARDTALK_APPS_PACKAGES drop list (remove, not disabled)")
    else:
        out("FAIL", f"{name} missing from GUARDTALK_APPS_PACKAGES drop list")

for name in ("HTMLViewer", "UniversalMediaPlayer"):
    if name in keep:
        out("PASS", f"{name} is in GUARDTALK_APPS_KEEP")
    else:
        out("FAIL", f"{name} missing from GUARDTALK_APPS_KEEP")

for name in ("GmsCompat", "GmsCompatConfig", "GmsCompatLib", "AppCompatConfig"):
    if name in keep:
        out("FAIL", f"{name} is in KEEP (Law 0 requires remove)")
    else:
        out("PASS", f"{name} is not restored via GUARDTALK_APPS_KEEP")

if "HTMLViewer" in drop:
    out("FAIL", "HTMLViewer is in drop list (KEEP must remain)")
else:
    out("PASS", "HTMLViewer is not in GUARDTALK_APPS_PACKAGES drop list")

if "PRODUCT_PACKAGES += UniversalMediaPlayer" in apps:
    out("PASS", "UniversalMediaPlayer is explicitly re-added after filter-out")
else:
    out("FAIL", "UniversalMediaPlayer add-after-filter missing")

for name in ("FusedLocation", "gnssd", "NetworkLocation", "bipchmgr", "wfc-pkt-router"):
    if name in loc_drop:
        out("PASS", f"{name} is in GUARDTALK_LOC_PACKAGES drop list")
    else:
        out("FAIL", f"{name} missing from GUARDTALK_LOC_PACKAGES")

if "filter-out FusedLocation" in loc and "PRODUCT_SYSTEM_SERVER_APPS" in loc:
    out("PASS", "loc-excised writes back PRODUCT_SYSTEM_SERVER_APPS without FusedLocation")
else:
    out("FAIL", "PRODUCT_SYSTEM_SERVER_APPS FusedLocation filter missing")

for needle in (
    "/etc/init/init.gnss.rc",
    "/etc/init/pixel-gnss-default.rc",
    "/etc/init/pktrouter.rc",
    "/etc/init/bipchmgr.rc",
):
    if needle in loc:
        out("PASS", f"loc-excised COPY_FILES drop includes {needle}")
    else:
        out("FAIL", f"loc-excised COPY_FILES drop missing {needle}")

idx_apps = feat.find("include vendor/guardtalk/feature-excised/apps-excised.mk")
idx_loc = feat.find("include vendor/guardtalk/feature-excised/loc-excised.mk")
if idx_apps >= 0 and idx_loc > idx_apps:
    out("PASS", "include order: apps-excised then loc-excised")
else:
    out("FAIL", "apps-excised / loc-excised include order unexpected")

# GmsCompat tolerate-missing must run even if IS_DEBUGGABLE.
m = re.search(
    r"void apply\(String pkgName, Computer computer\)\s*\{(?P<body>.*?)^\s*void apply\(@AppIdInt",
    gos,
    re.S | re.M,
)
if not m:
    out("FAIL", "could not locate GosPackageStatePermission.Builder.apply(String)")
else:
    body = m.group("body")
    gms = body.find("GmsCompatApp.PKG_NAME.equals(pkgName)")
    thr = body.find("if (Build.IS_DEBUGGABLE)")
    ret = body.find("return;")
    if gms >= 0 and "tolerated (GmsCompat excised)" in body:
        out("PASS", "GmsCompat special-case present in apply(String)")
    else:
        out("FAIL", "GmsCompat tolerate-missing block missing")
    if gms >= 0 and thr >= 0 and gms < thr:
        out("PASS", "GmsCompat log-and-return precedes IS_DEBUGGABLE throw")
    else:
        out("FAIL", "GmsCompat special-case does not precede IS_DEBUGGABLE throw")
    # Ensure the GmsCompat branch returns (does not fall through to throw).
    gms_slice = body[gms:thr] if gms >= 0 and thr >= 0 else ""
    if "return;" in gms_slice:
        out("PASS", "GmsCompat branch returns before IS_DEBUGGABLE")
    else:
        out("FAIL", "GmsCompat branch does not return before IS_DEBUGGABLE")

def service_stanzas(src, label):
    hits = []
    for i, line in enumerate(src.splitlines(), 1):
        if re.match(r"^\s*service\s+\S+", line):
            hits.append(f"{label}:{i}:{line.strip()}")
    return hits

pkt_svc = service_stanzas(pkt, "pktrouter.rc")
bip_svc = service_stanzas(bip, "bipchmgr.rc")
if pkt_svc:
    out("FAIL", "pktrouter.rc still has service stanzas: " + "; ".join(pkt_svc))
else:
    out("PASS", "pktrouter.rc has no service stanzas")
if bip_svc:
    out("FAIL", "bipchmgr.rc still has service stanzas: " + "; ".join(bip_svc))
else:
    out("PASS", "bipchmgr.rc has no service stanzas")

feat_tags = re.findall(
    r'<feature\s+name="android\.hardware\.location(?:\.[^"]*)?"',
    handheld,
)
if feat_tags:
    out("FAIL", f"handheld_core_hardware still declares location features: {feat_tags}")
else:
    out("PASS", "handheld_core_hardware declares no android.hardware.location* features")

lms = [
    i
    for i, line in enumerate(sysj.splitlines(), 1)
    if "LocationManagerService.Lifecycle" in line and "startService" in line
]
if lms:
    out(
        "HOLD",
        "LocationManagerService.Lifecycle still starts in SystemServer.java "
        f"(lines {lms}; not FEATURE-gated; not GNSS-dead)",
    )
else:
    out("PASS", "LocationManagerService.Lifecycle start absent (unexpected for this card)")

bt = "hasSystemFeature" in sysj and "FEATURE_BLUETOOTH" in sysj
if bt and lms:
    out(
        "HOLD",
        "BT start is FEATURE_BLUETOOTH-gated; location Lifecycle is not — LMS HOLD stands",
    )

if re.search(r"^vendor\.pktrouter=1\s*$", vprop, re.M):
    out("HOLD", "vendor.pktrouter=1 leftover in vendor.prop (no-op without rc; not FAIL)")
else:
    out("PASS", "vendor.pktrouter=1 not present in vendor.prop")

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
gbv PRODUCT_COPY_FILES | grep -v 'Build sandboxing' > "$DUMP_COPY"
set -e
echo "DUMP_PKGS_BYTES=$(wc -c < "$DUMP_PKGS") DUMP_PKGS_WORDS=$(wc -w < "$DUMP_PKGS")"
echo "DUMP_SSA_WORDS=$(wc -w < "$DUMP_SSA") DUMP_COPY_BYTES=$(wc -c < "$DUMP_COPY")"

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
echo "--- user PRODUCT_PACKAGES (Law 0 remove, not disabled) ---"
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

if token_in_file "$DUMP_PKGS" "com.android.devicelock"; then
  hold "user PRODUCT_PACKAGES: com.android.devicelock APEX PRESENT (BCP leftover; not FAIL this card)"
else
  pass "user PRODUCT_PACKAGES: com.android.devicelock ABSENT"
fi

echo
echo "--- user PRODUCT_SYSTEM_SERVER_APPS ---"
if token_in_file "$DUMP_SSA" "FusedLocation"; then
  fail "PRODUCT_SYSTEM_SERVER_APPS still has FusedLocation"
else
  pass "PRODUCT_SYSTEM_SERVER_APPS: FusedLocation ABSENT"
fi

echo
echo "--- user PRODUCT_COPY_FILES (gnss / pkt / bip rc) ---"
for needle in "${FORBID_COPY[@]}"; do
  if copy_needle_in_file "$DUMP_COPY" "$needle"; then
    fail "PRODUCT_COPY_FILES still has ${needle}"
  else
    pass "PRODUCT_COPY_FILES: ${needle} ABSENT"
  fi
done

echo
echo "--- stale out/ APKs are NOT product truth (m not run) ---"
if [[ -e "$STALE_FL" || -e "$STALE_GMS" || -e "$STALE_DLC" ]]; then
  hold "stale out/target/product/komodo APKs still present; not treated as product truth:"
  ls -ld "$STALE_FL" "$STALE_GMS" "$STALE_DLC" 2>/dev/null || true
else
  hold "stale FusedLocation/GmsCompat/DeviceLockController out APKs absent — still not a proven user image (m not run)"
fi
hold "m not run this QA stamp (not a built user image; never device-fixed)"
hold "on-device GNSS-dead not claimed (Q-ONDEVICE not started)"

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
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "LMS_START=HOLD"
echo "DEVICELOCK_APEX=HOLD_IF_PRESENT"
echo "PKTRTR_PROP=HOLD_IF_PRESENT"
echo "GNSS_DEAD_ONDEVICE=HOLD"
echo "DEVICE=HOLD"
echo "Q-ONDEVICE=not started"
exit "$FAIL"
