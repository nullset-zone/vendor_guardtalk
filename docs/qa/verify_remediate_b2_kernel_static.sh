#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B2-KERNEL (pair of T-REMEDIATE-B2-KERNEL
# item 9). Do not trust Backend/Architect reports.
# Do NOT use verify_sec_p5_static.sh as source of truth (historical paranoid 3).
# Rematch live init rc against paranoid 2. YAMA live Image HOLD if __lsm_yama
# absent. Device /proc/sys HOLD if adb empty. No product edits. No USB GO.
# No kernel Image rewrite. No commit. Do not start Q-ONDEVICE / Q-EXCISE /
# Q-TELEMETRY.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_kernel_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

HARDEN_RC="vendor/guardtalk/init/init.guardtalk.hardening.rc"
YAMA_FRAG="device/google/caimito-kernels/6.1/guardtalk-security-yama.config"
SYS_MAP="device/google/caimito-kernels/6.1/grapheneos/System.map"
SYS_MAP_TRUNK="device/google/caimito-kernels/6.1/trunk-14096387/System.map"
IMAGE="device/google/caimito-kernels/6.1/grapheneos/Image.lz4"
P5_SCRIPT="vendor/guardtalk/docs/qa/verify_sec_p5_static.sh"
POLICY="vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md"
FEAT_MK="vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
ANDROID_BP="vendor/guardtalk/init/Android.bp"
PERFETTO="system/core/rootdir/init-perfetto.rc"
STALE_KOMODO="out/target/product/komodo/system/etc/init/init.guardtalk.hardening.rc"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

stanza() {
  local marker="$1" file="$2"
  awk -v m="$marker" '
    BEGIN { p=0 }
    /^on / {
      if (index($0, m)) { p=1; next }
      else if (p) { exit }
    }
    p { print }
  ' "$file"
}

echo "=== Q-REMEDIATE-B2-KERNEL independent rematch (item 9) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "Q-ONDEVICE=not started"
echo "Q-EXCISE=not started"
echo "Q-TELEMETRY=not started"
echo "USB_GO=not started"
echo "P5_SCRIPT_SOT=false (historical paranoid 3; rematch against 2)"
echo

echo "--- required files ---"
require_file "$HARDEN_RC"
require_file "$YAMA_FRAG"
require_file "$SYS_MAP"
require_file "$IMAGE"
require_file "$FEAT_MK"
require_file "$ANDROID_BP"
require_file "$POLICY"

echo
echo "--- live init rc: paranoid 2 (FAIL if 3) ---"
if rg -q 'write /proc/sys/kernel/perf_event_paranoid 2' "$HARDEN_RC"; then
  pass "live rc writes perf_event_paranoid 2"
else
  fail "live rc missing write perf_event_paranoid 2"
fi
if rg -q 'perf_event_paranoid 3' "$HARDEN_RC"; then
  fail "live rc still has perf_event_paranoid 3"
else
  pass "live rc has no perf_event_paranoid 3"
fi
PARANOID_WRITES="$(rg -c 'write /proc/sys/kernel/perf_event_paranoid 2' "$HARDEN_RC" || true)"
if [[ "$PARANOID_WRITES" == "2" ]]; then
  pass "paranoid 2 written twice (late-init + boot_completed)"
else
  fail "expected 2 paranoid-2 writes, got ${PARANOID_WRITES:-0}"
fi

LATE="$(stanza late-init "$HARDEN_RC")"
BOOT="$(stanza boot_completed "$HARDEN_RC")"
if echo "$LATE" | rg -q 'write /proc/sys/kernel/perf_event_paranoid 2'; then
  pass "late-init writes perf_event_paranoid 2"
else
  fail "late-init missing perf_event_paranoid 2 write"
fi
if echo "$BOOT" | rg -q 'write /proc/sys/kernel/perf_event_paranoid 2'; then
  pass "boot_completed writes perf_event_paranoid 2"
else
  fail "boot_completed missing perf_event_paranoid 2 write"
fi

echo
echo "--- bpf=1 boot_completed only (not late-init) ---"
if echo "$LATE" | rg -q 'write /proc/sys/kernel/unprivileged_bpf_disabled'; then
  fail "late-init writes unprivileged_bpf_disabled (brick/NetBpfLoad)"
else
  pass "late-init does not write unprivileged_bpf_disabled"
fi
if echo "$BOOT" | rg -q 'write /proc/sys/kernel/unprivileged_bpf_disabled 1'; then
  pass "boot_completed writes unprivileged_bpf_disabled 1"
else
  fail "boot_completed missing unprivileged_bpf_disabled 1 write"
fi
BPF_WRITES="$(rg -c 'write /proc/sys/kernel/unprivileged_bpf_disabled 1' "$HARDEN_RC" || true)"
if [[ "$BPF_WRITES" == "1" ]]; then
  pass "exactly one bpf=1 write (boot_completed only)"
else
  fail "expected 1 bpf=1 write, got ${BPF_WRITES:-0}"
fi
if rg -q 'on property:.*sys.boot_completed=1' "$HARDEN_RC"; then
  pass "boot_completed property trigger present"
else
  fail "boot_completed property trigger missing"
fi

echo
echo "--- ptrace_scope=1 remains ---"
if echo "$LATE" | rg -q 'write /proc/sys/kernel/yama/ptrace_scope 1'; then
  pass "late-init writes ptrace_scope 1"
else
  fail "late-init missing ptrace_scope 1"
fi
if echo "$BOOT" | rg -q 'write /proc/sys/kernel/yama/ptrace_scope 1'; then
  pass "boot_completed writes ptrace_scope 1"
else
  fail "boot_completed missing ptrace_scope 1"
fi
if rg -q 'ptrace_scope 2' "$HARDEN_RC"; then
  fail "live rc has ptrace_scope 2 (regress)"
else
  pass "live rc does not raise ptrace_scope to 2"
fi

echo
echo "--- modules_disabled must not be set ---"
if rg -q 'write /proc/sys/kernel/modules_disabled' "$HARDEN_RC"; then
  fail "live rc writes modules_disabled (brick-risk)"
else
  pass "live rc does not write modules_disabled"
fi
if rg -q 'kernel.modules_disabled=1' "$HARDEN_RC"; then
  # Comment documenting that it is NOT set is expected.
  if rg -q 'write .*/modules_disabled' "$HARDEN_RC"; then
    fail "modules_disabled comment plus a write"
  else
    pass "modules_disabled mentioned only as intentionally not set"
  fi
else
  pass "no modules_disabled=1 assignment in live rc"
fi

echo
echo "--- PRODUCT_PACKAGES / Android.bp wiring ---"
if rg -q 'name: "init.guardtalk.hardening.rc"' "$ANDROID_BP"; then
  pass "Android.bp packages init.guardtalk.hardening.rc"
else
  fail "Android.bp missing hardening.rc prebuilt"
fi
if rg -qF 'PRODUCT_PACKAGES += init.guardtalk.hardening.rc' "$FEAT_MK"; then
  pass "feature-excised.mk PRODUCT_PACKAGES includes hardening.rc"
else
  fail "hardening.rc not in PRODUCT_PACKAGES"
fi

echo
echo "--- YAMA fragment CONFIG_SECURITY_YAMA=y ---"
if rg -q '^CONFIG_SECURITY_YAMA=y$' "$YAMA_FRAG"; then
  pass "fragment has CONFIG_SECURITY_YAMA=y"
else
  fail "fragment missing CONFIG_SECURITY_YAMA=y"
fi

echo
echo "--- fragment not Makefile-included ---"
MK_HITS="$(find device/google/caimito-kernels/6.1 -maxdepth 3 \
  \( -name 'Android.mk' -o -name 'Android.bp' -o -name 'Makefile' -o -name '*.mk' \) \
  2>/dev/null | wc -l | tr -d ' ')"
if [[ "$MK_HITS" == "0" ]]; then
  pass "no Makefile/Android.mk/Android.bp/*.mk under caimito-kernels/6.1"
else
  fail "unexpected makefiles under caimito-kernels/6.1: $MK_HITS"
fi
FRAG_REFS="$(rg -l 'guardtalk-security-yama' \
  device/google/caimito-kernels vendor/guardtalk --glob '!**/docs/qa/**' 2>/dev/null || true)"
if echo "$FRAG_REFS" | rg -q 'Android\.(mk|bp)|\.mk$|Makefile'; then
  fail "fragment referenced from a Makefile (unexpected include)"
else
  pass "fragment not referenced from any Makefile (docs/README only)"
fi

echo
echo "--- live System.map LSM list / __lsm_yama ---"
LSM_LIST="$(rg -n '__lsm_' "$SYS_MAP" || true)"
echo "$LSM_LIST"
if echo "$LSM_LIST" | rg -q '__lsm_capability' \
  && echo "$LSM_LIST" | rg -q '__lsm_selinux' \
  && echo "$LSM_LIST" | rg -q '__lsm_safesetid_security_init' \
  && echo "$LSM_LIST" | rg -q '__lsm_integrity'; then
  pass "live System.map LSM set includes capability/selinux/safesetid/integrity"
else
  fail "live System.map LSM set missing expected entries"
fi
if rg -q '__lsm_yama' "$SYS_MAP"; then
  fail "__lsm_yama PRESENT in live System.map (unexpected; do not invent Image.lz4)"
else
  hold "live grapheneos/System.map __lsm_yama ABSENT (YAMA not in prebuilt Image)"
fi
if [[ -f "$SYS_MAP_TRUNK" ]] && rg -q '__lsm_yama' "$SYS_MAP_TRUNK"; then
  fail "__lsm_yama PRESENT in trunk-14096387/System.map"
elif [[ -f "$SYS_MAP_TRUNK" ]]; then
  hold "trunk-14096387/System.map __lsm_yama ABSENT (same prebuilt LSM set)"
else
  hold "trunk-14096387/System.map missing"
fi

echo
echo "--- Image.lz4 not rewritten ---"
if [[ -f "$IMAGE" ]]; then
  IMG_MTIME="$(stat -c '%y' "$IMAGE" | cut -d. -f1)"
  FRAG_MTIME="$(stat -c '%y' "$YAMA_FRAG" | cut -d. -f1)"
  echo "Image.lz4 mtime=$IMG_MTIME"
  echo "fragment mtime=$FRAG_MTIME"
  hold "Image.lz4 present (mtime $IMG_MTIME); fragment newer; not treated as rebuilt"
else
  fail "Image.lz4 missing"
fi

echo
echo "--- historical P5 script is NOT source of truth ---"
if [[ -f "$P5_SCRIPT" ]] && rg -q "perf_event_paranoid 3" "$P5_SCRIPT"; then
  hold "verify_sec_p5_static.sh still asserts paranoid 3 (historical P5; not SoT)"
else
  pass "P5 script no longer asserts paranoid 3 (unexpected for this rematch)"
fi
if rg -q 'kernel.perf_event_paranoid.*2' "$POLICY" \
  || rg -q '`kernel.perf_event_paranoid` | `2`' "$POLICY"; then
  pass "PRODUCTION_HARDENING_POLICY.md table lists paranoid 2"
else
  fail "policy table missing paranoid 2"
fi

echo
echo "--- init-perfetto residual (not this card) ---"
if [[ -f "$PERFETTO" ]] && rg -q 'perf_event_paranoid' "$PERFETTO"; then
  hold "init-perfetto.rc can still write paranoid -1/1/3 (traced/perf_harden; not item 9 SoT)"
else
  pass "init-perfetto.rc has no paranoid writes"
fi

echo
echo "--- stale out/ copies (m not run) ---"
if [[ -f "$STALE_KOMODO" ]] && rg -q 'perf_event_paranoid 3' "$STALE_KOMODO"; then
  hold "stale out/komodo init.guardtalk.hardening.rc still has paranoid 3 until rebuild"
else
  if [[ -f "$STALE_KOMODO" ]]; then
    pass "stale komodo out rc no longer has paranoid 3"
  else
    hold "no stale komodo out rc"
  fi
fi
STALE_BPF="$(rg -l 'unprivileged_bpf_disabled' out/target/product/*/system/etc/init/init.guardtalk.hardening.rc 2>/dev/null || true)"
if [[ -z "$STALE_BPF" ]]; then
  hold "stale out product rc copies lack bpf=1 (m not run)"
else
  pass "some out copies already have bpf=1"
fi

echo
echo "--- adb / on-device /proc/sys ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
ADB_DEV="$(echo "$ADB_OUT" | awk 'NR>1 && $2=="device" {print $1}')"
if [[ -z "${ADB_DEV:-}" ]]; then
  hold "adb empty; on-device /proc/sys HOLD; Q-ONDEVICE not started"
else
  hold "adb has $ADB_DEV but Q-ONDEVICE is BLOCKED; /proc/sys not claimed live"
fi

echo
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=1 EXIT=1"
  echo "LIVE_DEVICE_CLAIMED=false"
  echo "YAMA_LIVE_IMAGE=HOLD"
  echo "PROC_SYS=HOLD"
  echo "DEVICE=HOLD"
  exit 1
fi
echo "RESULT: PASS (host static)  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=0 EXIT=0"
echo "LIVE_DEVICE_CLAIMED=false"
echo "YAMA_LIVE_IMAGE=HOLD"
echo "PROC_SYS=HOLD"
echo "DEVICE=HOLD"
echo "P5_SCRIPT=HOLD (not SoT)"
exit 0
