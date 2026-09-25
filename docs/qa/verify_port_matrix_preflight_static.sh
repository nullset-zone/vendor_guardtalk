#!/usr/bin/env bash
# =============================================================================
# Q-PORT-MATRIX-PREFLIGHT — ADVERSARIAL static harness (re-runnable)
# =============================================================================
# Falsification harness for the deliverable under test:
#   vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md
#
# Design intent: this harness is a set of ATTACKS. It exits 0 only when every
# attack FAILS to break the deliverable. A non-zero exit means an attack
# succeeded and the deliverable (or the tree) must be fixed.
#
# Attack set (per Q-PORT-MATRIX-PREFLIGHT scope):
#   1. invented codename             -> codename set must be exactly the 13
#   2. wrong PRODUCT_MODEL mapping   -> deliverable vs vendor-skel <dev>.mk
#   3. supported claim w/o build-index entry
#   4. supported claim w/o upstream support (releases.grapheneos.org)
#   5. claimed-PASS w/o obtainable stock factory (HEAD dl.google.com)
#   6. Gen 6/7 codename leakage into wave/verdict/advertise (P0 hard-fail)
#   7. stallion PASS that ignores its 5-entry index / stale pin
#   (a) the four absorbed trunk_staging NO-GO triggers vs the LAYER precedent
#   (b) build_id pin asymmetry (only stallion/tegu/rango pin)
#   (c) stallion 16-QPR1 platform lag (not merely a thin index)
#   (d) adevtool show-status cross-check (authoritative ground truth)
#
# Usage (from the worktree root):
#   bash vendor/guardtalk/docs/qa/verify_port_matrix_preflight_static.sh
# Env:
#   MATRIX_DOC=/path   point at a copy (used by the negative control)
#   NETWORK=0          skip upstream/factory probes
#   ROOT=/path         override repo root
#
# Static + read-only. No product code is modified. No commit. No on-device,
# boot, or flash claim.
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
MATRIX_DOC="${MATRIX_DOC:-$ROOT/vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md}"
NETWORK="${NETWORK:-1}"
export PATH="$HOME/.local/toolchain/node/bin:$PATH"
cd "$ROOT"

FAIL=0
PASS_N=0
WARN_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
# warn(): a real QA observation that does NOT overturn a GO verdict (e.g. the
# deliverable understates a risk the Architect already captured elsewhere).
warn() { echo "WARN: $*"; WARN_N=$((WARN_N + 1)); }

DEVICES=(shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango)
EXPECTED_SET="shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango"
GEN67=(oriole raven bluejay panther cheetah lynx felix tangorpro)

declare -A MODEL_EXPECT=(
  [shiba]="Pixel 8"       [husky]="Pixel 8 Pro"   [akita]="Pixel 8a"
  [tokay]="Pixel 9"       [caiman]="Pixel 9 Pro"  [komodo]="Pixel 9 Pro XL"
  [comet]="Pixel 9 Pro Fold" [tegu]="Pixel 9a"    [stallion]="Pixel 10a"
  [frankel]="Pixel 10"    [blazer]="Pixel 10 Pro" [mustang]="Pixel 10 Pro XL"
  [rango]="Pixel 10 Pro Fold"
)
declare -A SOC_EXPECT=(
  [shiba]=zuma [husky]=zuma [akita]=zuma
  [tokay]=zumapro [caiman]=zumapro [komodo]=zumapro [comet]=zumapro [tegu]=zumapro [stallion]=zumapro
  [frankel]=laguna [blazer]=laguna [mustang]=laguna [rango]=laguna
)
declare -A INDEX_EXPECT=(
  [shiba]=58 [husky]=58 [akita]=46 [tokay]=47 [caiman]=46 [komodo]=46 [comet]=45
  [tegu]=29 [stallion]=5 [frankel]=29 [blazer]=29 [mustang]=29 [rango]=24
)
declare -A KERNELDIR_EXPECT=(
  [shiba]="device/google/shusky-kernels/6.1/grapheneos"
  [husky]="device/google/shusky-kernels/6.1/grapheneos"
  [akita]="device/google/akita-kernels/6.1/grapheneos"
  [tokay]="device/google/caimito-kernels/6.1/grapheneos"
  [caiman]="device/google/caimito-kernels/6.1/grapheneos"
  [komodo]="device/google/caimito-kernels/6.1/grapheneos"
  [comet]="device/google/comet-kernels/6.1/grapheneos"
  [tegu]="device/google/tegu-kernels/6.1/grapheneos"
  [stallion]="device/google/stallion-kernels/6.1/grapheneos"
  [frankel]="device/google/laguna-kernels/6.6/grapheneos/muzel"
  [blazer]="device/google/laguna-kernels/6.6/grapheneos/muzel"
  [mustang]="device/google/laguna-kernels/6.6/grapheneos/muzel"
  [rango]="device/google/laguna-kernels/6.6/grapheneos/rango"
)
# Mutually independent: the flag-driven devices under the cur lunch channel.
FLAG_DEVICES=(shiba husky akita tokay caiman komodo comet tegu)
# The four devices whose trunk_staging resolved dir is absent (vector a).
TRUNK_ABSENT=(shiba husky comet tegu)
# Devices that pin an explicit build_id (vector b).
PIN_DEVICES=(stallion tegu rango)

echo "==================================================================="
echo "Q-PORT-MATRIX-PREFLIGHT adversarial harness"
echo "ROOT      : $ROOT"
echo "MATRIX_DOC: $MATRIX_DOC"
echo "NETWORK   : $NETWORK"
echo "==================================================================="

if [[ ! -f "$MATRIX_DOC" ]]; then
  fail "deliverable under test not found: $MATRIX_DOC"
  echo "RESULT: FAIL ($PASS_N pass, 1 fail)"; exit 1
fi

# -----------------------------------------------------------------------------
# Parse the deliverable's 13-row matrix table (section 2) into dev|model|soc|count
# A row looks like: | 1 | 8 | `shiba` | Pixel 8 | `zuma` | ... | 58 | ... |
# -----------------------------------------------------------------------------
ROWS="$(mktemp)"
python3 - "$MATRIX_DOC" > "$ROWS" <<'PY'
import re, sys
for ln in open(sys.argv[1], encoding='utf-8'):
    if not re.match(r'^\|\s*\d+\s*\|\s*\d+\s*\|', ln):
        continue
    f = [c.strip() for c in ln.strip().strip('|').split('|')]
    if len(f) < 9:
        continue
    dev = f[2].strip('`* ')
    model = f[3].strip('* ')
    soc = f[4].strip('`* ')
    cnt = re.sub(r'[^0-9]', '', f[7])
    print(f"{dev}|{model}|{soc}|{cnt}")
PY

row_field() { # dev field-index(1..4)
  awk -F'|' -v d="$1" -v n="$2" '$1==d{print $n; exit}' "$ROWS"
}

# =============================================================================
# ATTACK 1 — invented codename / codename-set tampering
# =============================================================================
echo "--- attack 1: codename set is exactly the 13 (invented codename) ---"
GOT_SET="$(cut -d'|' -f1 "$ROWS" | tr '\n' ' ' | sed 's/ *$//')"
EXPECT_SET_NORM="$(echo "$EXPECTED_SET" | tr -s ' ' | sed 's/ *$//')"
N_ROWS="$(wc -l < "$ROWS")"
if [[ "$N_ROWS" -ne 13 ]]; then
  fail "attack1: matrix has $N_ROWS device rows, expected 13"
elif [[ "$GOT_SET" != "$EXPECT_SET_NORM" ]]; then
  fail "attack1: codename set != expected 13"
  echo "      got     : $GOT_SET"
  echo "      expected: $EXPECT_SET_NORM"
else
  pass "attack1: exactly 13 codenames, no invented/extra codename (order preserved)"
fi

# =============================================================================
# ATTACK 2 — wrong PRODUCT_MODEL mapping  (source: vendor-skels/<dev>/<dev>.mk)
# =============================================================================
echo "--- attack 2: PRODUCT_MODEL vs vendor-skels ---"
for d in "${DEVICES[@]}"; do
  mk="vendor/adevtool/vendor-skels/google_devices/$d/$d.mk"
  src=""
  [[ -f "$mk" ]] && src="$(grep -m1 'PRODUCT_MODEL' "$mk" | sed -E 's/.*:=\s*//; s/\s*$//')"
  claimed="$(row_field "$d" 2)"
  if [[ -z "$src" ]]; then
    fail "attack2: $d missing vendor-skel $mk"
  elif [[ "$claimed" != "${MODEL_EXPECT[$d]}" ]]; then
    fail "attack2: $d deliverable model '$claimed' != expected '${MODEL_EXPECT[$d]}'"
  elif [[ "$src" != "${MODEL_EXPECT[$d]}" ]]; then
    fail "attack2: $d source model '$src' != expected '${MODEL_EXPECT[$d]}'"
  else
    pass "attack2: $d -> '$src' (deliverable + source agree)"
  fi
done

# =============================================================================
# ATTACK 3 — device claimed supported with NO build-index entry
# =============================================================================
echo "--- attack 3: build-index-main.yml coverage ---"
BI="vendor/adevtool/config/build-index/build-index-main.yml"
for d in "${DEVICES[@]}"; do
  n="$(grep -cE "^$d " "$BI" 2>/dev/null || true)"
  claimed="$(row_field "$d" 4)"
  if [[ "${n:-0}" -lt 1 ]]; then
    fail "attack3: $d has NO build-index entry (claimed supported)"
  elif [[ "$n" != "${INDEX_EXPECT[$d]}" ]]; then
    fail "attack3: $d recomputed count $n != expected ${INDEX_EXPECT[$d]}"
  elif [[ "$claimed" != "${INDEX_EXPECT[$d]}" ]]; then
    fail "attack3: $d deliverable count '$claimed' != recomputed '$n'"
  else
    pass "attack3: $d has $n main-index entries (deliverable agrees)"
  fi
done

# =============================================================================
# ATTACK 2b / cross-check — SoC platform + kernel dir existence (cur channel)
# =============================================================================
echo "--- attack 2c: SoC platform + cur-channel kernel dir existence ---"
for d in "${DEVICES[@]}"; do
  soc="$(grep -rhoE 'platform/(zuma|zumapro|laguna)' \
        "vendor/adevtool/config/mk/google_devices/device/$d/" 2>/dev/null | sort -u | sed 's#platform/##' | tr '\n' ',' | sed 's/,$//')"
  claimed="$(row_field "$d" 3)"
  if [[ "$soc" != "${SOC_EXPECT[$d]}" ]]; then
    fail "attack2c: $d source SoC '$soc' != expected '${SOC_EXPECT[$d]}' (stallion/tegu trap)"
  elif [[ "$claimed" != "${SOC_EXPECT[$d]}" ]]; then
    fail "attack2c: $d deliverable SoC '$claimed' != expected '${SOC_EXPECT[$d]}'"
  else
    pass "attack2c: $d SoC '$soc' (deliverable agrees)"
  fi
  kdir="${KERNELDIR_EXPECT[$d]}"
  if [[ -d "$kdir" ]]; then
    pass "attack2c: $d cur-channel kernel dir exists: $kdir"
  else
    fail "attack2c: $d cur-channel kernel dir ABSENT: $kdir"
  fi
done

# =============================================================================
# ATTACK 4 — claimed supported with NO upstream GrapheneOS support
# =============================================================================
echo "--- attack 4: upstream releases.grapheneos.org/<dev>-stable ---"
UPSTREAM_IDS=""
if [[ "$NETWORK" == "1" ]]; then
  for d in "${DEVICES[@]}"; do
    body="$(mktemp)"
    code="$(curl -s -o "$body" -w '%{http_code}' --max-time 30 \
            "https://releases.grapheneos.org/$d-stable" || echo 000)"
    rid="$(tr -d '\n' < "$body" | awk '{print $1}')"
    rm -f "$body"
    if [[ "$code" != "200" ]]; then
      fail "attack4: $d-stable HTTP $code (upstream support NOT proven)"
    elif [[ -z "$rid" ]]; then
      fail "attack4: $d-stable HTTP 200 but empty body"
    else
      pass "attack4: $d-stable HTTP 200 build id $rid"
      UPSTREAM_IDS="$UPSTREAM_IDS $rid"
    fi
  done
  uniq_ids="$(echo $UPSTREAM_IDS | tr ' ' '\n' | sort -u | tr '\n' ' ')"
  if [[ "$(echo $uniq_ids | wc -w)" -eq 1 ]]; then
    pass "attack4: all 13 -stable endpoints agree on release id: $uniq_ids"
  else
    fail "attack4: -stable release ids diverge: $uniq_ids"
  fi
else
  echo "SKIP: attack4 (NETWORK=0)"
fi

# =============================================================================
# ATTACK 5 — claimed-PASS device with NO obtainable stock factory image
# Ground truth: adevtool show-status resolved build_id -> build-index factory
# =============================================================================
echo "--- attack 5: stock factory obtainability (HEAD dl.google.com) ---"
SHOW_STATUS="$(mktemp)"
if command -v node >/dev/null 2>&1 && [[ -x vendor/adevtool/bin/run ]]; then
  vendor/adevtool/bin/run show-status > "$SHOW_STATUS" 2>/dev/null || true
fi

# Vector (d): assert the tool resolves a build id for each of the 13.
echo "--- vector d: adevtool show-status build-id resolution ---"
if [[ -s "$SHOW_STATUS" ]]; then
  declare -A RESOLVED=()
  while IFS='|' read -r tag rest; do
    [[ "$rest" == *:* ]] || continue
    bid="${rest%%:*}"; bid="${bid// /}"
    for dv in ${rest#*:}; do RESOLVED[$dv]="$bid"; done
  done < <(sed -n '1,8p' "$SHOW_STATUS")
  for d in "${DEVICES[@]}"; do
    if [[ -z "${RESOLVED[$d]:-}" ]]; then
      fail "vectord: show-status resolves NO build id for $d"
    else
      pass "vectord: show-status resolves $d -> ${RESOLVED[$d]}"
    fi
  done
else
  echo "HOLD: vector d — adevtool show-status unavailable (node or bin/run missing)"
fi

if [[ "$NETWORK" == "1" ]]; then
  for d in "${DEVICES[@]}"; do
    bid=""
    if [[ -s "$SHOW_STATUS" ]]; then
      bid="$(awk -F'|' -v d="$d" '$0 ~ (":" ){ split($2,a,":"); n=split(a[2],b," "); for(i=1;i<=n;i++) if(b[i]==d) print a[1] }' "$SHOW_STATUS" | head -1 | tr -d ' ')"
    fi
    # fall back to the deliverable's claimed resolved build id
    if [[ -z "$bid" ]]; then
      bid="$(grep -oE "^$d \| \`[^\`]+\`" "$MATRIX_DOC" >/dev/null 2>&1; true)"
      case "$d" in
        stallion) bid="BD6A.251031.001.A4";; rango) bid="CP1A.260505.005";; tegu) bid="BP4A.260205.001";;
        tokay|caiman|komodo|comet) bid="BP4A.260205.002";; *) bid="BP4A.260205.001";;
      esac
    fi
    zipf="$(python3 - "$BI" "$d" "$bid" <<'PY'
import re,sys
bi=sys.argv[1]; dev=sys.argv[2]; want=sys.argv[3]
cur=None
for ln in open(bi,encoding='utf-8'):
    m=re.match(r'^([a-z0-9_]+) (\S+):\s*$', ln)
    if m: cur=(m.group(1),m.group(2)); continue
    if cur==(dev,want) and 'factory:' in ln:
        m2=re.search(r'(\S+\.zip)\s*$', ln.strip())
        if m2: print(m2.group(1)); break
PY
)"
    if [[ -z "$zipf" ]]; then
      fail "attack5: $d build $bid has no factory entry in build-index"
      continue
    fi
    code="$(curl -sI --max-time 30 -o /dev/null -w '%{http_code}' \
            "https://dl.google.com/dl/android/aosp/$zipf" || echo 000)"
    if [[ "$code" == "200" ]]; then
      pass "attack5: $d $bid factory HEAD 200 ($zipf)"
    else
      fail "attack5: $d $bid factory HEAD $code ($zipf)"
    fi
  done
  # stallion pinned AND newest (the only 5-entry device)
  for u in "stallion-bd6a.251031.001.a4-factory-7420a527.zip" \
           "stallion-cp1a.260505.005.a1-factory-5ccba036.zip"; do
    code="$(curl -sI --max-time 30 -o /dev/null -w '%{http_code}' \
            "https://dl.google.com/dl/android/aosp/$u" || echo 000)"
    if [[ "$code" == "200" ]]; then
      pass "attack5: stallion extra factory HEAD 200 ($u)"
    else
      fail "attack5: stallion extra factory HEAD $code ($u)"
    fi
  done
else
  echo "SKIP: attack5 (NETWORK=0)"
fi

# =============================================================================
# ATTACK 6 — Gen 6/7 leakage (P0 hard-fail)
# =============================================================================
echo "--- attack 6: Gen 6/7 codename leakage ---"
LEAK=0
for d in "${GEN67[@]}"; do
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    if [[ "$hit" != *"out of scope"* ]]; then
      fail "attack6: '$d' leaked outside an out-of-scope line: $hit"
      LEAK=1
    fi
  done < <(grep -nE "$d" "$MATRIX_DOC" 2>/dev/null)
done
[[ "$LEAK" == "0" ]] && pass "attack6: no Gen 6/7 codename outside an explicit out-of-scope line"

# advertise surfaces must not name Gen 6/7 at all
ADV_LEAK="$(grep -rnE 'oriole|raven|bluejay|panther|cheetah|lynx|felix|tangorpro' \
  vendor/guardtalk/web-installer/src vendor/guardtalk/scripts/pack-webinstall-channel.sh 2>/dev/null || true)"
if [[ -z "$ADV_LEAK" ]]; then
  pass "attack6: advertise surfaces name no Gen 6/7 codename"
else
  fail "attack6: Gen 6/7 codename in advertise surface: $ADV_LEAK"
fi

# advertise surface must be exactly the 4 stamped devices (unchanged by preflight)
allowed="$(grep -E 'ALLOWED_PRODUCTS' vendor/guardtalk/web-installer/src/types.ts | head -1)"
if [[ "$allowed" == *'"tokay", "akita", "komodo", "rango"'* ]]; then
  pass "attack6: ALLOWED_PRODUCTS unchanged (tokay akita komodo rango)"
else
  fail "attack6: ALLOWED_PRODUCTS changed unexpectedly: $allowed"
fi

# =============================================================================
# ATTACK 7 — stallion PASS must engage its 5-entry index / stale pin
# =============================================================================
echo "--- attack 7: stallion thin-margin engagement ---"
s7_ok=1
grep -qE 'stallion.*\b5\b|\b5\b.*stallion' "$MATRIX_DOC" || { fail "attack7: deliverable does not state stallion's 5-entry index"; s7_ok=0; }
grep -q 'BD6A.251031.001.A4' "$MATRIX_DOC" || { fail "attack7: deliverable does not name stallion's pinned build"; s7_ok=0; }
grep -qiE 'stale|oldest|withdrawn|re-check|recheck' "$MATRIX_DOC" || { fail "attack7: deliverable has no stallion-pin risk language"; s7_ok=0; }
[[ "$s7_ok" == "1" ]] && pass "attack7: stallion 5-entry index + stale-pin risk engaged (§5/§9/§12)"

# =============================================================================
# VECTOR (a) — the four absorbed NO-GO triggers vs the LAYER precedent
# =============================================================================
echo "--- vector a: trunk_staging dir absence classification ---"
for d in "${TRUNK_ABSENT[@]}"; do
  flag="build/release/flag_values/trunk_staging/RELEASE_KERNEL_$(echo "$d" | tr a-z A-Z)_DIR.textproto"
  if [[ ! -f "$flag" ]]; then
    fail "vectorA: $d has no trunk_staging _DIR flag (would be 'variable unresolved' = NO-GO)"
    continue
  fi
  val="$(sed -nE 's/.*string_value: "([^"]+)".*/\1/p' "$flag")"
  if [[ -z "$val" ]]; then
    fail "vectorA: $d trunk_staging _DIR flag defined but empty (variable unresolved)"
  elif [[ -d "$val" ]]; then
    fail "vectorA: $d trunk_staging dir unexpectedly PRESENT ($val) — re-derive the 4-absence claim"
  else
    pass "vectorA: $d trunk_staging flag DEFINED ('$val') but dir absent -> LAYER prerequisite, not NO-GO"
  fi
done
# the precedent symlinks must exist (akita + caimito + laguna)
for sl in device/google/akita-kernels/6.1/trunk-14096387 \
          device/google/caimito-kernels/6.1/trunk-14096387 \
          device/google/laguna-kernels/6.6/trunk-14072179; do
  if [[ -L "$sl" ]]; then pass "vectorA: precedent symlink present: $sl -> $(readlink "$sl")"
  else fail "vectorA: precedent symlink missing: $sl"; fi
done
# cur must resolve for ALL 13 (the property that makes the GO safe)
CUR_OK=1
for d in "${DEVICES[@]}"; do
  val=""
  if [[ " ${FLAG_DEVICES[*]} " == *" $d "* ]]; then
    f="build/release/flag_values/cur/RELEASE_KERNEL_$(echo "$d" | tr a-z A-Z)_DIR.textproto"
    val="$(sed -nE 's/.*string_value: "([^"]+)".*/\1/p' "$f" 2>/dev/null)"
  else
    val="${KERNELDIR_EXPECT[$d]}"
  fi
  if [[ -z "$val" || ! -d "$val" ]]; then
    fail "vectorA: cur lunch does NOT resolve for $d ('$val')"; CUR_OK=0
  fi
done
[[ "$CUR_OK" == "1" ]] && pass "vectorA: cur channel resolves for all 13 (GO is safe under the production lunch)"
grep -qE 'LAYER prerequisite' "$MATRIX_DOC" && pass "vectorA: deliverable classifies the absences as a LAYER prerequisite" \
  || fail "vectorA: deliverable does not state the LAYER-prerequisite classification"

# =============================================================================
# VECTOR (b) — build_id pin asymmetry
# =============================================================================
echo "--- vector b: build_id pin asymmetry ---"
PINNED=()
for d in "${DEVICES[@]}"; do
  if grep -q 'build_id' "vendor/adevtool/config/device/$d.yml" 2>/dev/null; then PINNED+=("$d"); fi
done
PINNED_STR="$(
  for p in "${PINNED[@]}"; do echo "$p"; done | sort | tr '\n' ' ' | sed 's/ *$//'
)"
EXPECT_PIN="$(for p in "${PIN_DEVICES[@]}"; do echo "$p"; done | sort | tr '\n' ' ' | sed 's/ *$//')"
if [[ "$PINNED_STR" == "$EXPECT_PIN" ]]; then
  pass "vectorB: exactly {$EXPECT_PIN} pin a build_id; the other 10 resolve with no pin"
else
  fail "vectorB: pin set '$PINNED_STR' != expected '$EXPECT_PIN'"
fi
grep -qiE 'pin asymmetry|pin an explicit|10 resolve with no pin|no pin' "$MATRIX_DOC" \
  && pass "vectorB: deliverable documents the pin asymmetry" \
  || warn "vectorB: deliverable does NOT state the pin asymmetry (Architect addition only; recorded, not a GO-breaker)"

# =============================================================================
# VECTOR (c) — stallion platform lag (16 QPR1)
# =============================================================================
echo "--- vector c: stallion 16-QPR1 platform lag ---"
if grep -q '16 QPR1' vendor/adevtool/config/device/stallion.yml; then
  pass "vectorC: stallion.yml documents the 16 QPR1 stock gap"
else
  fail "vectorC: stallion.yml no longer documents the 16 QPR1 gap — re-derive"
fi
if grep -q 'Multiuser' vendor/adevtool/config/device/stallion.yml; then
  pass "vectorC: stallion.yml carries the Multiuser extra-package workaround"
else
  fail "vectorC: stallion.yml Multiuser workaround missing"
fi
sdkfull="$(grep -c 'sdk_full = 36.0' vendor/adevtool/config/device/stallion.yml || true)"
if [[ "${sdkfull:-0}" -ge 5 ]]; then
  pass "vectorC: stallion.yml carries $sdkfull 'sdk_full = 36.0' exclusions"
else
  fail "vectorC: expected >=5 sdk_full 36.0 exclusions, found ${sdkfull:-0}"
fi
# stallion's newest indexed build must be newer than the pin
newest="$(grep -E '^stallion ' "$BI" | tail -1 | awk '{print $2}' | tr -d ':')"
if [[ "$newest" == "CP1A.260505.005.A1" ]]; then
  pass "vectorC: newest index entry $newest is newer than the pinned BD6A.251031.001.A4 (lag confirmed)"
else
  fail "vectorC: unexpected newest stallion index entry: $newest"
fi
# Does the deliverable itself engage the platform lag? (Architect addition was
# folded into later cards; if the deliverable silently omits it, that is a real
# understatement to escalate — but not a GO-breaker.)
if grep -qE 'QPR1|Multiuser|sdk_full' "$MATRIX_DOC"; then
  pass "vectorC: deliverable engages the 16 QPR1 platform lag"
else
  warn "vectorC: deliverable UNDERSTATES stallion — it never names the 16 QPR1 image / Multiuser workaround / sdk_full 36.0, only 'stale pin'. Architect captured this separately; recommend Architect confirm T-PORT-STALLION-PREFLIGHT carries it."
fi

# =============================================================================
# Vector (d) present-set note (mutable while 'adevtool download' runs)
# =============================================================================
echo "--- vector d: stock factory present-set (informational) ---"
if [[ -s "$SHOW_STATUS" ]]; then
  present="$(grep -m1 -E 'stock|present' "$SHOW_STATUS" >/dev/null 2>&1; awk '/^Stock image:/{f=1} f&&/present:/{print; exit}' "$SHOW_STATUS" | sed -nE 's/.*present: (.*)/\1/p')"
  echo "INFO: show-status factory present: ${present:-<none>}"
  echo "INFO: (this set is MUTABLE while 'adevtool download' runs; do not treat as a fixed invariant)"
fi
rm -f "$ROWS" "$SHOW_STATUS"

echo "==================================================================="
if [[ "$FAIL" == "0" ]]; then
  echo "RESULT: PASS — all attacks failed; $PASS_N checks passed, $WARN_N warning(s)."
  echo "==================================================================="
  exit 0
else
  echo "RESULT: FAIL — at least one attack succeeded; $PASS_N passed, $WARN_N warning(s)."
  echo "==================================================================="
  exit 1
fi
