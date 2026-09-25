#!/usr/bin/env bash
# Generate the Q-EXCISE-LEDGER negative-control fixture.
#
# Mirrors ONLY the primary artifacts the harness reads, then deliberately
# UN-EXCISES shiba's shipped vendor_dlkm blocklist (drops `blocklist nitrous`
# and the gnss entries) so the harness must detect reachable BT/GNSS kernel
# modules. Read-only w.r.t. the product tree.
#
# Usage: bash vendor/guardtalk/docs/qa/make_fixture_un_excised.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
OUT="$ROOT/vendor/guardtalk/docs/qa/fixtures/un-excised"
STAMPS="$ROOT/releases/desktop-flash"

declare -A STAMP=(
  [shiba]=shiba-latest [husky]=husky-latest [akita]=akita-latest
  [tokay]=tokay-20260725-102506 [caiman]=caiman-latest [komodo]=komodo-latest
  [comet]=comet-latest [tegu]=tegu-latest [stallion]=stallion-latest
  [frankel]=frankel-latest [blazer]=blazer-latest [mustang]=mustang-latest
  [rango]=rango-latest
)

rm -rf "$OUT"
mkdir -p "$OUT"

for dev in "${!STAMP[@]}"; do
  st="${STAMP[$dev]}"
  prod="$ROOT/out/target/product/$dev"
  dst="$OUT/out/target/product/$dev"

  # ---- out/ tree artifacts the harness consults -------------------------
  # NOTE: `cat >` (not `cp`) — several built files carry an ACL that makes
  # `cp` fail on the final metadata pass even though the data copies fine.
  mkdir -p "$dst"
  mirror() { # src dst
    [ -f "$1" ] || return 0
    mkdir -p "$(dirname "$2")"
    cat "$1" > "$2" 2>/dev/null || true
  }
  mirror "$prod/installed-files-vendor.txt" "$dst/installed-files-vendor.txt"
  # presence-only artifacts: placeholders are sufficient (harness tests existence)
  touch_file() { # src dst
    [ -f "$1" ] || return 0
    mkdir -p "$(dirname "$2")"; : > "$2"
  }
  touch_file "$prod/radio.img" "$dst/radio.img"
  touch_file "$prod/modem.img" "$dst/modem.img"
  touch_file "$prod/product/etc/permissions/android.hardware.telephony.euicc.xml" \
             "$dst/product/etc/permissions/android.hardware.telephony.euicc.xml"
  for rel in bin/hw/gpsd bin/hw/lhd bin/hw/scd etc/init/init.gps.rc; do
    touch_file "$prod/vendor/$rel" "$dst/vendor/$rel"
  done
  for f in "$prod/vendor/bin/hw/"*uwb*; do
    [ -e "$f" ] || continue
    touch_file "$f" "$dst/vendor/bin/hw/$(basename "$f")"
  done
  for f in "$prod/vendor/overlay/"*[Nn]fc*.apk; do
    [ -e "$f" ] || continue
    touch_file "$f" "$dst/vendor/overlay/$(basename "$f")"
  done
  for f in "$prod/vendor/etc/"libnfc*.conf "$prod/vendor/etc/"*nfc*.conf; do
    [ -e "$f" ] || continue
    touch_file "$f" "$dst/vendor/etc/$(basename "$f")"
  done

  # ---- shipped stamp dlkm text artifacts ---------------------------------
  for img in system_dlkm.img vendor_dlkm.img; do
    imgdir="$OUT/stamps/$st/$img/lib/modules"
    mkdir -p "$imgdir"
    image="$STAMPS/$st/$img"
    if [ -f "$image" ]; then
      debugfs -R "cat /lib/modules/modules.load" "$image" 2>/dev/null > "$imgdir/modules.load" || true
      debugfs -R "cat /lib/modules/modules.blocklist" "$image" 2>/dev/null > "$imgdir/modules.blocklist" || true
    fi
  done
done

# ---- DELIBERATE CORRUPTION: un-excise shiba (nitrous + gnss reachable) -----
shiba_blk="$OUT/stamps/shiba-latest/vendor_dlkm.img/lib/modules/modules.blocklist"
if [ -f "$shiba_blk" ]; then
  grep -vE '^\s*blocklist\s+(nitrous|gnssif|gnss_spi)(\.ko)?\s*$' "$shiba_blk" > "$shiba_blk.tmp"
  mv "$shiba_blk.tmp" "$shiba_blk"
fi

echo "fixture written: $OUT"
echo "  (shiba vendor_dlkm blocklist deliberately UN-EXCISED: nitrous/gnss unblocked)"
