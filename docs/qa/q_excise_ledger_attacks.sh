#!/usr/bin/env bash
# Q-EXCISE-LEDGER — required adversarial attacks (read-only).
#
# Each attack is a self-contained check against PRIMARY artifacts (out/ tree,
# shipped release stamps via debugfs, and the deliverable ledger JSON).
# Convention for this table: EXIT 0 == the ledger's claim HOLDS for that
# attack; EXIT non-zero == FINDING / LEDGER FALSIFIED on that attack.
#
# Raw outputs are written under .agent-comm/evidence/Q-EXCISE-LEDGER/.
# Usage: bash vendor/guardtalk/docs/qa/q_excise_ledger_attacks.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
EV=".agent-comm/evidence/Q-EXCISE-LEDGER"
mkdir -p "$EV"
J="vendor/guardtalk/docs/qa/excision_ledger.json"
H="vendor/guardtalk/docs/qa/q_excise_ledger_harness.py"
STAMPS="releases/desktop-flash"
TSV="$EV/attack_exit_codes.tsv"
: > "$TSV"

attack() { # id description
  local id="$1" desc="$2"
  printf '%-4s %-58s ' "$id" "$desc"
}

record() { # id verdict
  local id="$1" verdict="$2"
  printf 'EXIT=%-3s %s\n' "$RC" "$verdict"
  printf '%s\t%s\t%s\t%s\n' "$id" "$RC" "$verdict" "$DESC" >> "$TSV"
}

stamp_cat() { debugfs -R "cat $3" "$STAMPS/$1/$2" 2>/dev/null; }
stamp_has() { debugfs -R "stat $3" "$STAMPS/$1/$2" 2>/dev/null | grep -q 'Inode:'; }

# =========================================================================
DESC="A1 variant cross-family resolution (shusky/akita, muzel/rango)"
attack A1 "$DESC"
(
  fail=0
  declare -A want=( [shiba]=shusky [husky]=shusky [akita]=akita [tokay]=caimito \
    [caiman]=caimito [komodo]=caimito [comet]=comet [tegu]=tegu [stallion]=stallion \
    [frankel]=laguna [blazer]=laguna [mustang]=laguna [rango]=rango )
  declare -A seen
  for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
    st="$d-latest"; [ "$d" = tokay ] && st="tokay-20260725-102506"
    hdr=$(stamp_cat "$st" vendor_dlkm.img /lib/modules/modules.blocklist | grep -m1 GuardTalkOS)
    if [ -z "$hdr" ]; then
      echo "  $d: shipped blocklist has NO provenance header (resolved-variant file did not reach the image)"
    elif ! echo "$hdr" | grep -qi "${want[$d]}"; then
      echo "  CROSS-FAMILY: $d shipped blocklist names a different family -> $hdr"; fail=1
    fi
    h=$(sha256sum "$ROOT/out/target/product/$d/vendor_dlkm/lib/modules/modules.blocklist" 2>/dev/null | cut -c1-12)
    if [ -n "${seen[$h]:-}" ]; then
      pf="${want[${seen[$h]}]}"; cf="${want[$d]}"
      [ "$pf" != "$cf" ] && { echo "  CROSS-FAMILY: ${seen[$h]} ($pf) and $d ($cf) share blocklist $h"; fail=1; }
    else seen[$h]="$d"; fi
  done
  exit $fail
) > "$EV/A1_variant.out" 2>&1
RC=$?; cat "$EV/A1_variant.out"; record A1 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# A1b: shipped resolved-variant blocklist provenance absent on the 4 laguna stamps
DESC="A1b shipped blocklist provenance absent (laguna stamps are stock)"
attack A1b "$DESC"
(
  fail=0
  for d in frankel blazer mustang rango; do
    st="$d-latest"
    hdr=$(stamp_cat "$st" vendor_dlkm.img /lib/modules/modules.blocklist | grep -m1 GuardTalkOS)
    [ -z "$hdr" ] && { echo "  $d: shipped vendor_dlkm blocklist is stock (no GuardTalkOS excision header)"; fail=1; }
  done
  exit $fail
) > "$EV/A1b_provenance.out" 2>&1
RC=$?; cat "$EV/A1b_provenance.out"; record A1b "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# =========================================================================
DESC="A2 module the ledger calls blocked that is loaded+unblocked in the shipped stamp"
attack A2 "$DESC"
(
  fail=0
  for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
    st="$d-latest"; [ "$d" = tokay ] && st="tokay-20260725-102506"
    for m in nitrous gnssif gnss_spi; do
      case "$m" in
        nitrous) img=vendor_dlkm.img ;;
        *)       img=vendor_dlkm.img ;;
      esac
      load=$(stamp_cat "$st" "$img" /lib/modules/modules.load)
      blk=$(stamp_cat "$st" "$img" /lib/modules/modules.blocklist)
      if echo "$load" | grep -qE "(^|[ /])$m\.ko" && ! echo "$blk" | sed 's/\.ko$//' | grep -qE "blocklist[[:space:]]+$m$"; then
        echo "  $d: $m.ko is in modules.load and NOT blocklisted in shipped $img"
        fail=1
      fi
    done
  done
  exit $fail
) > "$EV/A2_blocked_but_present.out" 2>&1
RC=$?; cat "$EV/A2_blocked_but_present.out"; record A2 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# =========================================================================
DESC="A3 feature-permission XML the ledger treats as dropped but ships"
attack A3 "$DESC"
(
  fail=0
  echo "  named BT/NFC/Location android.hardware.*.xml (E-5) — absent check:"
  for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
    for x in android.hardware.bluetooth.xml android.hardware.nfc.xml android.hardware.location.xml; do
      if [ -f "$ROOT/out/target/product/$d/product/etc/permissions/$x" ] \
      || [ -f "$ROOT/out/target/product/$d/system/etc/permissions/$x" ]; then
        echo "  PRESENT $d $x"; fail=1
      fi
    done
  done
  echo "  rango NFC userspace residual (ledger nfc_userspace_hal = Tier A):"
  grep -in nfc "$ROOT/out/target/product/rango/installed-files-vendor.txt" | sed 's/^/    /' || true
  stamp_has rango-latest vendor.img /overlay/NfcOverlayRangoGsi.apk \
    && { echo "  FALSIFIED: rango shipped vendor.img has NFC overlay"; fail=1; } || true
  stamp_has rango-latest vendor.img /etc/libnfc-hal-st_evt.conf \
    && { echo "  FALSIFIED: rango shipped vendor.img has libnfc-hal-st_evt.conf"; fail=1; } || true
  exit $fail
) > "$EV/A3_feature_xml.out" 2>&1
RC=$?; cat "$EV/A3_feature_xml.out"; record A3 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# =========================================================================
DESC="A4 late filter-out that never fired (claim vs built artifact)"
attack A4 "$DESC"
(
  fail=0
  for d in shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango; do
    st="$d-latest"; [ "$d" = tokay ] && st="tokay-20260725-102506"
    load=$(stamp_cat "$st" vendor_dlkm.img /lib/modules/modules.load)
    blk=$(stamp_cat "$st" vendor_dlkm.img /lib/modules/modules.blocklist)
    for m in gnssif gnss_spi; do
      if echo "$load" | grep -qE "(^|[ /])$m\.ko" \
         && ! echo "$blk" | sed 's/\.ko$//' | grep -qE "blocklist[[:space:]]+$m$"; then
        echo "  $d: gnss filter-out did not reach the shipped image ($m.ko loaded, unblocked)"; fail=1
      fi
    done
  done
  # shiba/husky userspace gnss filter-out (loc-excised.mk filters 'gnss*' names)
  for d in shiba husky; do
    stamp_has "$d-latest" vendor.img /bin/hw/gpsd && { echo "  $d: gpsd shipped despite loc-excised filter-out (ledger already Tier C)"; }
  done
  exit $fail
) > "$EV/A4_filter_out.out" 2>&1
RC=$?; cat "$EV/A4_filter_out.out"; record A4 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# =========================================================================
DESC="A5 cell that cites a makefile as evidence (must be 0)"
attack A5 "$DESC"
(
  a=$(jq '[.devices[].artifacts[]|select(.evidence_kind=="makefile")]|length' "$J")
  b=$(jq '[.devices[].artifacts[].path|select(endswith(".mk"))]|length' "$J")
  c=$(grep -o -E 'makefile|\.mk' "$J" | wc -l)
  echo "  evidence_kind==makefile: $a ; .mk paths: $b ; raw substrings: $c"
  [ "$a" = 0 ] && [ "$b" = 0 ] && [ "$c" = 0 ]
) > "$EV/A5_makefile.out" 2>&1
RC=$?; cat "$EV/A5_makefile.out"; record A5 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# =========================================================================
DESC="A6 tier errors: A actually B, B actually C"
attack A6 "$DESC"
python3 "$H" --mode ledger > "$EV/A6_tier_diff.out" 2>&1
RC=$?; tail -4 "$EV/A6_tier_diff.out"; record A6 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# =========================================================================
DESC="A7 independently re-derive >=10 cells"
attack A7 "$DESC"
python3 "$H" --mode artifacts > "$EV/A7_rederive.out" 2>&1
RC=$?; tail -3 "$EV/A7_rederive.out"; record A7 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

# =========================================================================
DESC="A8 missing stamp / dangling -latest"
attack A8 "$DESC"
python3 "$H" --mode attacks > "$EV/A8_stamps.out" 2>&1
RC=$?
grep -E 'MISSING|DANGLING' "$EV/A8_stamps.out" | sed 's/^/  /'
grep -E 'tokay-latest present|global latest ->|rango-latest ->|A8 ' "$EV/A8_stamps.out" | sed 's/^/  /'
grep -q 'tokay-latest present *: True' "$EV/A8_stamps.out" && RC=1
record A8 "$([ $RC -eq 0 ] && echo HOLDS || echo FALSIFIED)"

echo
echo "TSV: $TSV"
column -t -s$'\t' "$TSV"
