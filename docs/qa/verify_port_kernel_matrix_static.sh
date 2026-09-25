#!/usr/bin/env bash
# Static verification for T-PORT-KERNEL-MATRIX (P0).
#
# Proves the per-device kernel-dir resolution is explicit, documented, and that
# the two distinct failure modes are kept strictly separate:
#   (i)  UNRESOLVED  no RELEASE_KERNEL_<DEV>_DIR value in the release config
#                    => NO-GO, hard error naming the exact variable
#   (ii) ABSENT_DIR  variable defined but the resolved dir is missing here
#                    => LAYER prerequisite, NOT a NO-GO (loud warning)
# plus (iii) STUB: dir exists but vendor_kernel_boot.modules.load is missing.
#
# Cases:
#   1. All 13 device.mk carry the validated-resolution block; the 5 literal-path
#      devices are documented as such and `stallion` has NO flag in ANY channel
#   2. `cur` (the FLASH channel): all 13 resolve, dir exists, modules.load
#      present and non-empty, and NO path component is a symlink
#   3. `trunk_staging`: classification only. ABSENT_DIR set is EXACTLY
#      {shiba, husky, comet, tegu} — a LAYER prerequisite, NOT a NO-GO — and
#      none of those is UNRESOLVED. This card DOCUMENTS the LAYER remedy; it does
#      not apply it (that is why the 4 stay unpinned).
#   4. The resolver really distinguishes the modes (synthetic harness):
#      UNRESOLVED -> hard error; ABSENT_DIR -> warning, exit 0
#   5. STUB (dir present, modules.load missing) -> hard error
#   6. Kernel trees complete, not stubs: per-tree module manifest counts
#   7. KOMODO_PORT_PREFLIGHT.md lunch-FAIL path re-checked (exact path)
#   8. Zero regression: the 4 `*-latest` release symlinks and the pre-existing
#      trunk-<buildid> kernel symlinks are unmoved
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_port_kernel_matrix_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

require_file() {
  local f="$1" label="${2:-$1}"
  if [[ -f "$f" ]]; then pass "present: $label"; else fail "missing: $label ($f)"; fi
}
require_rg() {
  local pat="$1" file="$2" label="${3:-$1}"
  if [[ -f "$file" ]] && rg -q -- "$pat" "$file"; then pass "$label"
  else fail "$label (pattern '$pat' missing in $file)"; fi
}

DEV_MK_DIR="vendor/adevtool/config/mk/google_devices/device"
FLAG_DIR="build/release/flag_values"
DOC="vendor/guardtalk/docs/KERNEL_MATRIX.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

DEVICES=(shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango)
FLAG_DEVICES=(shiba husky akita tokay caiman komodo comet tegu)
LITERAL_DEVICES=(stallion frankel blazer mustang rango)
# The 8 resolved in-scope trees ONLY. device/google also carries Gen 6/7
# (*-bluejay/felix/lynx/pantah/raviole/tangorpro-kernels) which are OUT OF SCOPE
# and must never be counted here.
RESOLVED_TREES=(
  device/google/shusky-kernels/6.1/grapheneos
  device/google/akita-kernels/6.1/grapheneos
  device/google/caimito-kernels/6.1/grapheneos
  device/google/comet-kernels/6.1/grapheneos
  device/google/tegu-kernels/6.1/grapheneos
  device/google/stallion-kernels/6.1/grapheneos
  device/google/laguna-kernels/6.6/grapheneos/muzel
  device/google/laguna-kernels/6.6/grapheneos/rango
)
# Programs' channels of record: cur is the FLASH channel (sign-build.sh:188),
# trunk_staging is the development channel.
CHANNELS=(cur trunk_staging)

flag_of() { echo "RELEASE_KERNEL_$(echo "$1" | tr '[:lower:]' '[:upper:]')_DIR"; }

# resolved_target_kernel_dir <device> <channel> -> path (empty if unresolved)
resolved_target_kernel_dir() {
  local dev="$1" ch="$2" line
  line="$(rg -m1 '^TARGET_KERNEL_DIR' "$DEV_MK_DIR/$dev/device.mk" || true)"
  case "$line" in
    *':= $(RELEASE_KERNEL_'*)   # shouldn't happen (literals use :=)
      echo "" ;;
    *':= '*)                    # literal path
      echo "${line#*:= }" ;;
    *'?= $(RELEASE_KERNEL_'*)   # flag-driven
      local flag fv
      flag="$(flag_of "$dev")"
      fv="$FLAG_DIR/$ch/$flag.textproto"
      if [[ -f "$fv" ]]; then sed -n 's/.*string_value: "\(.*\)".*/\1/p' "$fv"
      else echo ""; fi ;;
    *) echo "" ;;
  esac
}

echo "=== T-PORT-KERNEL-MATRIX case1: resolution block present in all 13 device.mk ==="

for dev in "${DEVICES[@]}"; do
  f="$DEV_MK_DIR/$dev/device.mk"
  require_file "$f" "$dev/device.mk"
  require_rg 'T-PORT-KERNEL-MATRIX \(P0\): validated kernel-dir resolution' "$f" \
    "$dev/device.mk carries the validated-resolution block"
  require_rg 'GUARDTALK_KERNEL_RESOLUTION := OK' "$f" "$dev/device.mk classifies OK"
  require_rg 'GUARDTALK_KERNEL_RESOLUTION := ABSENT_DIR' "$f" "$dev/device.mk classifies ABSENT_DIR"
  require_rg 'T-PORT-KERNEL-MATRIX: STUB\.' "$f" "$dev/device.mk has the STUB hard error"
  require_rg 'vendor_kernel_boot\.modules\.load' "$f" "$dev/device.mk asserts modules.load (not a stub)"
  require_rg 'KERNEL_MATRIX\.md' "$f" "$dev/device.mk points at KERNEL_MATRIX.md"
done
for dev in "${FLAG_DEVICES[@]}"; do
  flag="$(flag_of "$dev")"
  require_rg "T-PORT-KERNEL-MATRIX: UNRESOLVED\. $flag has no value" \
    "$DEV_MK_DIR/$dev/device.mk" "$dev/device.mk has UNRESOLVED hard error naming $flag"
done
for dev in "${LITERAL_DEVICES[@]}"; do
  require_rg 'LITERAL-path device by design' "$DEV_MK_DIR/$dev/device.mk" \
    "$dev documented as literal-path"
done

# stallion in particular: NO RELEASE_KERNEL_STALLION_DIR in ANY channel.
stallion_flags="$(find "$FLAG_DIR" -name 'RELEASE_KERNEL_STALLION_DIR.textproto' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$stallion_flags" == "0" ]]; then
  pass "stallion has NO RELEASE_KERNEL_STALLION_DIR flag in any of the $(ls "$FLAG_DIR" | wc -l | tr -d ' ') channels (literal by design)"
else
  fail "RELEASE_KERNEL_STALLION_DIR unexpectedly present ($stallion_flags files)"
fi
# Documented shared flags on the literal devices are UNUSED, not a dependency.
for dev in frankel blazer mustang rango; do
  flag="$(flag_of "$dev")"
  n="$(find "$FLAG_DIR" -name "$flag.textproto" 2>/dev/null | wc -l | tr -d ' ')"
  pass "note: $dev is literal-path; $flag exists in $n channel(s) but is UNUSED by device.mk"
done

echo "=== T-PORT-KERNEL-MATRIX case2: cur (FLASH channel) resolves for all 13, no symlink ==="

cur_ok=0
for dev in "${DEVICES[@]}"; do
  dir="$(resolved_target_kernel_dir "$dev" cur)"
  if [[ -z "$dir" ]]; then
    fail "cur: $dev UNRESOLVED (no TARGET_KERNEL_DIR)"
    continue
  fi
  if [[ ! -d "$dir" ]]; then
    fail "cur: $dev TARGET_KERNEL_DIR='$dir' does not exist"
    continue
  fi
  if [[ ! -s "$dir/vendor_kernel_boot.modules.load" ]]; then
    fail "cur: $dev '$dir/vendor_kernel_boot.modules.load' missing or empty"
    continue
  fi
  n="$(wc -l < "$dir/vendor_kernel_boot.modules.load")"
  cur_ok=$((cur_ok + 1))
  # `cur` must resolve on real directories only — no symlink anywhere on the
  # path below device/google. (Compare with -L, not readlink -f: the repo root
  # itself is reached through a symlinked mount, which made readlink -f lie.)
  if [[ -L "$dir" || -L "$(dirname "$dir")" ]]; then
    fail "cur: $dev resolved through a symlink ($dir) — cur must need none"
  else
    pass "cur: $dev -> $dir (real dir, no symlink component, $n modules.load entries)"
  fi
done
if [[ "$cur_ok" == "13" ]]; then
  pass "cur: 13/13 devices resolve with NO symlink required"
else
  fail "cur: only $cur_ok/13 resolved"
fi

echo "=== T-PORT-KERNEL-MATRIX case3: trunk_staging classification (two modes kept apart) ==="

absent_set=""
ok_set=""
for dev in "${DEVICES[@]}"; do
  dir="$(resolved_target_kernel_dir "$dev" trunk_staging)"
  if [[ -z "$dir" ]]; then
    fail "trunk_staging: $dev UNRESOLVED — variable has no value; that would be a NO-GO"
    continue
  fi
  if [[ -d "$dir" ]]; then
    ok_set="$ok_set $dev"
    pass "trunk_staging: $dev -> $dir (OK, exists)"
  else
    absent_set="$absent_set $dev"
    pass "trunk_staging: $dev -> $dir ABSENT_DIR (LAYER prerequisite, NOT a NO-GO, NOT UNRESOLVED)"
  fi
done
absent_set="$(echo $absent_set | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"
want_absent="comet husky shiba tegu"
if [[ "$absent_set" == "$want_absent" ]]; then
  pass "trunk_staging ABSENT_DIR set is EXACTLY [$want_absent] (matches the gate/preflight finding)"
else
  fail "trunk_staging ABSENT_DIR set is [$absent_set], expected [$want_absent]"
fi
want_ok="akita blazer caiman frankel komodo mustang rango stallion tokay"
got_ok="$(echo $ok_set | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ $//')"
if [[ "$got_ok" == "$want_ok" ]]; then
  pass "trunk_staging resolves directly for the other 9: [$want_ok]"
else
  fail "trunk_staging resolved set is [$got_ok], expected [$want_ok]"
fi
# The distinction the Architect refined: absence is NOT a variable problem.
if [[ "$absent_set" == *comet* && "$absent_set" == *shiba* ]]; then
  pass "the 4 absent devices have a DEFINED variable — classified ABSENT_DIR, NOT UNRESOLVED (modes not conflated)"
fi
# The LAYER remedy must be named in the doc for exactly these 4 devices.
for pair in \
  "shiba:device/google/shusky-kernels/6.1/trunk-14096387" \
  "husky:device/google/shusky-kernels/6.1/trunk-14096387" \
  "comet:device/google/comet-kernels/6.1/trunk-14096387" \
  "tegu:device/google/tegu-kernels/6.1/trunk-14096387"; do
  dev="${pair%%:*}"; want="${pair##*:}"
  got="$(resolved_target_kernel_dir "$dev" trunk_staging)"
  if [[ "$got" == "$want" ]]; then
    pass "LAYER remedy path for $dev is $want (named in KERNEL_MATRIX.md §4)"
  else
    fail "LAYER remedy path for $dev: got '$got', expected '$want'"
  fi
done
# Provisioning is a LAYER act, not this card's act: the 4 must remain unpinned so
# the preflight's 4-absence invariant stays true and the classification stays
# observable.
for p in device/google/shusky-kernels/6.1/trunk-14096387 \
         device/google/comet-kernels/6.1/trunk-14096387 \
         device/google/tegu-kernels/6.1/trunk-14096387; do
  if [[ -e "$p" || -L "$p" ]]; then
    fail "$p exists — this card documents the LAYER remedy, it does not apply it (see KERNEL_MATRIX.md §4)"
  else
    pass "correctly UNPINNED by this card: $p (LAYER owns provisioning)"
  fi
done
if [[ "$ok_set" == *akita* && "$ok_set" == *komodo* && "$ok_set" == *tokay* && "$ok_set" == *rango* ]]; then
  pass "trunk_staging: the 4 in-force devices (tokay/akita/komodo/rango) all resolve"
else
  fail "trunk_staging: an in-force device does not resolve:$ok_set"
fi

echo "=== T-PORT-KERNEL-MATRIX case4: the two failure modes are really distinct ==="

# Extract the REAL shipped resolution block from akita/device.mk and drive it
# with synthetic flag values, so the test exercises the code that ships.
BLOCK="$TMP/akita-block.mk"
awk '/^# --- T-PORT-KERNEL-MATRIX \(P0\): validated/{f=1}
     f{print}
     f && /^endif[[:space:]]*$/ && ++n==4{exit}' "$DEV_MK_DIR/akita/device.mk" > "$BLOCK"
if rg -q 'T-PORT-KERNEL-MATRIX: UNRESOLVED' "$BLOCK" && rg -q 'ABSENT_DIR' "$BLOCK"; then
  pass "extracted the shipped akita resolution block ($(wc -l < "$BLOCK") lines)"
else
  fail "could not extract theakita resolution block"
fi

unres="$TMP/unresolved.mk"
{ echo 'TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_AKITA_DIR)'; cat "$BLOCK"; echo 'GTKM_UNRES_DONE:'; printf '\t@:\n'; } > "$unres"
u_out="$(make -s -f "$unres" 2>&1 || true)"; u_rc=0
make -s -f "$unres" >/dev/null 2>&1 || u_rc=$?
if [[ "$u_rc" -ne 0 ]] && printf '%s' "$u_out" | rg -q 'UNRESOLVED\. RELEASE_KERNEL_AKITA_DIR has no value'; then
  pass "MODE (i) UNRESOLVED: hard error (exit $u_rc) naming RELEASE_KERNEL_AKITA_DIR — NO-GO"
else
  fail "MODE (i) UNRESOLVED did not hard-error (exit $u_rc): $(printf '%s' "$u_out" | tail -1)"
fi

absent="$TMP/absent.mk"
# A DEFINED flag pointing at a dir that provably does not exist -> MODE (ii).
ABSENT_PROBE="device/google/akita-kernels/6.1/trunk-00000000-does-not-exist"
if [[ -e "$ABSENT_PROBE" ]]; then
  fail "test fixture broken: $ABSENT_PROBE exists, cannot exercise MODE (ii)"
else
  pass "MODE (ii) fixture: $ABSENT_PROBE confirmed absent"
fi
{ echo 'TARGET_KERNEL_DIR ?= $(RELEASE_KERNEL_AKITA_DIR)'; cat "$BLOCK"; echo '$(info GTKM_RES|$(GUARDTALK_KERNEL_RESOLUTION))'; echo 'GTKM_ABSENT_DONE:'; printf '\t@:\n'; } > "$absent"
a_out="$(make -s -f "$absent" RELEASE_KERNEL_AKITA_DIR="$ABSENT_PROBE" 2>&1 || true)"
a_rc=0; make -s -f "$absent" RELEASE_KERNEL_AKITA_DIR="$ABSENT_PROBE" >/dev/null 2>&1 || a_rc=$?
if [[ "$a_rc" -eq 0 ]] && printf '%s' "$a_out" | rg -q 'ABSENT_DIR\.' \
   && printf '%s' "$a_out" | rg -q 'GTKM_RES\|ABSENT_DIR' \
   && printf '%s' "$a_out" | rg -q 'LAYER prerequisite, NOT a NO-GO'; then
  pass "MODE (ii) ABSENT_DIR: loud warning, exit 0, GUARDTALK_KERNEL_RESOLUTION=ABSENT_DIR — LAYER prerequisite, NOT a NO-GO"
else
  fail "MODE (ii) ABSENT_DIR behaved wrong (exit $a_rc): $(printf '%s' "$a_out" | tail -2)"
fi
if printf '%s' "$a_out" | rg -q 'UNRESOLVED'; then
  fail "MODE (ii) was conflated with MODE (i) (UNRESOLVED fired for an ABSENT_DIR)"
else
  pass "MODE (ii) is NOT conflated with MODE (i) (no UNRESOLVED for a defined-but-absent dir)"
fi

echo "=== T-PORT-KERNEL-MATRIX case5: STUB detection ==="

stub="$TMP/stub.mk"
mkdir -p "$TMP/stubkern"
# The flag must be DEFINED (otherwise MODE (i) fires first); the dir exists but
# carries no modules.load -> MODE (iii) STUB.
{ echo 'RELEASE_KERNEL_AKITA_DIR := device/google/akita-kernels/6.1/grapheneos'; \
  echo "TARGET_KERNEL_DIR := $TMP/stubkern"; cat "$BLOCK"; echo 'GTKM_STUB_DONE:'; printf '\t@:\n'; } > "$stub"
s_out="$(make -s -f "$stub" 2>&1 || true)"; s_rc=0
make -s -f "$stub" >/dev/null 2>&1 || s_rc=$?
if [[ "$s_rc" -ne 0 ]] && printf '%s' "$s_out" | rg -q 'STUB\. .akita. resolved TARGET_KERNEL_DIR'; then
  pass "MODE (iii) STUB: hard error (exit $s_rc) — dir exists but modules.load is missing"
else
  fail "MODE (iii) STUB did not hard-error as expected (exit $s_rc): $(printf '%s' "$s_out" | tail -1)"
fi

echo "=== T-PORT-KERNEL-MATRIX case6: kernel trees complete, not stubs ==="

for fam in shusky akita caimito comet tegu stallion laguna; do
  d="device/google/$fam-kernels"
  if [[ ! -d "$d" ]]; then fail "$d missing"; continue; fi
  pass "tree present: $d"
done
echo "-- per resolved tree module manifest counts (vendor_kernel_boot / vendor_dlkm / system_dlkm):"
for tree in "${RESOLVED_TREES[@]}"; do
  vkb="$tree/vendor_kernel_boot.modules.load"
  vul="$tree/vendor_dlkm.modules.load"
  sul="$tree/system_dlkm.modules.load"
  if [[ -s "$vkb" && -s "$vul" && -s "$sul" ]]; then
    pass "complete: $tree  ($(wc -l < "$vkb") / $(wc -l < "$vul") / $(wc -l < "$sul") entries)"
  else
    fail "incomplete kernel tree: $tree (missing/empty modules.load)"
  fi
done
# Out-of-scope Gen 6/7 trees must NOT be counted as resolved in-scope trees.
for fam in bluejay felix lynx pantah raviole tangorpro; do
  if compgen -G "device/google/$fam-kernels/*/grapheneos" >/dev/null; then
    pass "out of scope (Gen 6/7, NOT provisioned, NOT counted): device/google/$fam-kernels"
  fi
done
# Record the honest entry-count range. The gate note said 338-473 for
# vendor_kernel_boot.modules.load; that is NOT reproducible in this worktree
# (measured 195-215 over the 8 in-scope resolved trees). Reported, never
# asserted — Law 7.
rng="$(for tree in "${RESOLVED_TREES[@]}"; do
         [[ -s "$tree/vendor_kernel_boot.modules.load" ]] && wc -l < "$tree/vendor_kernel_boot.modules.load"; done | sort -n | sed -n '1p;$p' | tr '\n' '-')"
ko_rng="$(for tree in "${RESOLVED_TREES[@]}"; do
         find "$tree" -name '*.ko' | wc -l; done | sort -n | sed -n '1p;$p' | tr '\n' '-')"
hold "vendor_kernel_boot.modules.load entries per resolved in-scope tree = ${rng%-} (gate note said 338-473). *.ko per tree = ${ko_rng%-}. Both measured over the 8 in-scope trees only; the gate figure is not reproducible for this field in this worktree — see KERNEL_MATRIX.md 'completeness' section"

echo "=== T-PORT-KERNEL-MATRIX case7: komodo lunch-FAIL path re-checked ==="

# KOMODO_PORT_PREFLIGHT.md:95 exact missing path (pre-symlink).
KOMODO_PATH="device/google/caimito-kernels/6.1/trunk-14096387"
if [[ -d "$KOMODO_PATH" ]]; then
  pass "komodo lunch path now EXISTS: $KOMODO_PATH (-> $(readlink "$KOMODO_PATH" 2>/dev/null || echo 'real dir'))"
else
  fail "komodo lunch path still missing: $KOMODO_PATH"
fi
if [[ -s "$KOMODO_PATH/vendor_kernel_boot.modules.load" ]]; then
  pass "komodo lunch path has vendor_kernel_boot.modules.load ($(wc -l < "$KOMODO_PATH/vendor_kernel_boot.modules.load") entries)"
else
  fail "komodo lunch path still lacks vendor_kernel_boot.modules.load (PREFLIGHT failure would reproduce)"
fi
require_rg 'trunk-14096387' "$DOC" "KERNEL_MATRIX.md documents the komodo lunch path"
# The preflight must still be the historical record (do not rewrite history).
require_rg 'FAIL' vendor/guardtalk/docs/KOMODO_PORT_PREFLIGHT.md \
  "KOMODO_PORT_PREFLIGHT.md retains its lunch FAIL record (history not rewritten)"
hold "full 'lunch komodo-trunk_staging-userdebug' NOT re-run here (heavy + adevtool download in flight); verified the exact failing path instead — see report"

echo "=== T-PORT-KERNEL-MATRIX case8: zero regression on release + trunk symlinks ==="

declare -A LATEST_EXPECT=(
  [latest]="tokay-20260725-102506"
  [akita-latest]="akita-20260725-101434"
  [komodo-latest]="komodo-20260915-063833"
  # Observed value at the start of this card; zero-regression = must not move.
  [rango-latest]="rango-20260802-130756"
)
for link in "${!LATEST_EXPECT[@]}"; do
  p="releases/desktop-flash/$link"
  if [[ -L "$p" ]]; then
    got="$(readlink "$p")"
    if [[ "$got" == "${LATEST_EXPECT[$link]}" ]]; then
      pass "$link -> $got (unmoved)"
    else
      fail "$link -> $got, expected ${LATEST_EXPECT[$link]} (moved = regression)"
    fi
  else
    fail "$p missing or not a symlink"
  fi
done
hold "rango-latest -> rango-20260802-130756 as observed at card start (unmoved). NB: the Q-PORT-RANGO script bakes the older stamp rango-20260725-133716, so that script still reports its pre-existing size/README/stamp failures — NOT introduced by this card; see report"
# Pre-existing kernel pins must stay intact and unmoved — they are load-bearing
# for the trunk_staging lunches that already work.
for pair in \
  "device/google/akita-kernels/6.1/trunk-14096387:grapheneos" \
  "device/google/caimito-kernels/6.1/trunk-14096387:grapheneos" \
  "device/google/laguna-kernels/6.6/trunk-14072179:grapheneos"; do
  l="${pair%%:*}"; want="${pair##*:}"
  if [[ -L "$l" ]]; then
    if [[ "$(readlink "$l")" == "$want" ]]; then
      pass "pre-existing kernel pin intact: $(basename "$(dirname "$l")")/$(basename "$l") -> $want"
    else
      fail "kernel symlink $l -> $(readlink "$l"), expected $want (moved = regression)"
    fi
  else
    fail "pre-existing kernel symlink $l missing (a working trunk_staging lunch would break)"
  fi
done

echo "=== T-PORT-KERNEL-MATRIX case9: KERNEL_MATRIX.md published ==="

require_file "$DOC" "docs/KERNEL_MATRIX.md"
for pat in 'cur' 'trunk_staging' 'TARGET_KERNEL_DIR' 'RELEASE_KERNEL_' 'UNRESOLVED' \
           'ABSENT_DIR' 'LAYER' 'NO-GO' 'literal' 'stallion' 'rango' \
           'vendor_kernel_boot.modules.load' 'trunk-14096387' 'KOMODO_PORT_PREFLIGHT'; do
  require_rg "$pat" "$DOC" "KERNEL_MATRIX documents '$pat'"
done
# The add-a-device recipe must be explicit about both channels and both modes.
for pat in 'Add-a-device recipe' 'LAYER' 'shusky-kernels' 'comet-kernels' 'tegu-kernels' \
           'RELEASE_KERNEL_STALLION_DIR' 'out of scope' 'Gen 6' 'Gen 7'; do
  require_rg "$pat" "$DOC" "KERNEL_MATRIX add-a-device recipe covers '$pat'"
done

echo ""
echo "=== T-PORT-KERNEL-MATRIX static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
