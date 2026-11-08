#!/usr/bin/env bash
# =============================================================================
# Q-EXCISE-13DEV-MATRIX — re-runnable 13-device airgap-claim harness (P0)
# =============================================================================
# Re-derives, from BUILT artifacts only, the per-device excision matrix for the
# 13 Gen 8/9/10 program devices and asserts the invariant set that the excision
# claim requires. Residuals that are KNOWN and documented are reported as
# RESIDUAL rows (never as "removal"); anything outside the documented residual
# set is a FAIL (regression).
#
# Authoritative input = the SHIPPED `releases/desktop-flash/<dev>-latest` stamp
# images (the built image the claim is about), read with `debugfs`. The
# `out/target/product/<dev>/` build tree is used only for the baseband `modem.img`
# residual (E-7b: modem.img is not staged into the stamps) and to expose
# out/-vs-stamp divergence.
#
# Variant is resolved from a BUILT artifact: the GuardTalk `vendor_dlkm`
# blocklist header, or (when that header is absent, as on the 4 `laguna` stamps)
# the vendor VINTF manifest provenance header.
#
# Modes:
#   (default)                 run over the real shipped stamps (13 devices)
#   GTQ_MX_MODE=fixture       read a synthesized tree instead of images;
#                             GTQ_MX_FIXTURE=<dir> points at the fixture root.
#   --build-negative-fixture <dir>
#                             synthesize a deliberately UN-EXCISED fixture and
#                             exit; use with GTQ_MX_MODE=fixture to prove the
#                             harness fails loudly. A harness that cannot fail
#                             is not evidence.
#   --help
#
# Env:
#   GTQ_MX_DEVICES   override device list (default: the 13 program devices)
#   GTQ_MX_OUT       output dir (default .agent-comm/evidence/Q-EXCISE-13DEV-MATRIX)
#   GTQ_MX_STAMPS    stamp root (default releases/desktop-flash). Unset, the
#                    script reads the live <dev>-latest symlinks with readlink
#                    (not readlink -f). Set only to point a fixture at a temp root.
#   GTQ_MX_INJECT_STAMP_EXPECT
#                    optional space-separated dev=stamp pairs. When a pair names
#                    the device under test, the live readlink must equal that
#                    stamp or INV-5 FAILs. Unset in production. A missing pointer
#                    still fails closed; the injection cannot force a PASS.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh
#   bash vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh \
#        --build-negative-fixture /tmp/gtq-mx-neg
#   GTQ_MX_MODE=fixture GTQ_MX_FIXTURE=/tmp/gtq-mx-neg \
#        bash vendor/guardtalk/docs/qa/verify_excise_13dev_matrix_static.sh; echo $?
#
# Exit: 0 = every invariant holds on every device and no undocumented residual.
#       non-zero = at least one invariant violated / undocumented residual.
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

STAMPS="${GTQ_MX_STAMPS:-releases/desktop-flash}"
LEDGER="vendor/guardtalk/docs/qa/excision_ledger.json"
MODE="${GTQ_MX_MODE:-stamp}"
FIXTURE="${GTQ_MX_FIXTURE:-}"
OUTDIR="${GTQ_MX_OUT:-.agent-comm/evidence/Q-EXCISE-13DEV-MATRIX}"
DEVICES="${GTQ_MX_DEVICES:-shiba husky akita tokay caiman komodo comet tegu stallion frankel blazer mustang rango}"

# --- documented residual register (see Q-EXCISE-13DEV-MATRIX_EVIDENCE.md) ---
# Devices that ship the Lassen location daemon stack (E-9). Absent elsewhere.
DOC_LOC_DEVICES="shiba husky"
# Devices whose shipped stamp leaves nitrous.ko unblocklisted (E-10).
DOC_NITROUS_UNBLOCKED="frankel blazer mustang rango"
# The 8 GKI BT/NFC modules that load and are unblocklisted on every stamp (E-14).
BT_MODULES="bluetooth.ko hci_uart.ko btbcm.ko btqca.ko btsdio.ko rfcomm.ko hidp.ko nfc.ko"
# Feature-permission XML stems the excision must drop for BT/NFC/Location (E-5).
FEATURE_XML_STEMS="android.hardware.bluetooth android.hardware.nfc android.hardware.location android.hardware.location.network android.hardware.location.gps"

# --- expected per-device registry (variant + accepted resolution tokens + stamp) ---
declare -A EXPECTED_VARIANT=(
  [shiba]=zuma_shusky [husky]=zuma_shusky [akita]=zuma_akita
  [tokay]=zumapro_caimito [caiman]=zumapro_caimito [komodo]=zumapro_caimito
  [comet]=zumapro_comet [tegu]=zumapro_tegu [stallion]=zumapro_stallion
  [frankel]=laguna_muzel [blazer]=laguna_muzel [mustang]=laguna_muzel [rango]=laguna_rango
)
declare -A ACCEPT_TOKENS=(
  [shiba]="zuma_shusky shiba" [husky]="zuma_shusky husky" [akita]="zuma_akita akita"
  [tokay]="zumapro_caimito tokay" [caiman]="zumapro_caimito tokay caiman" [komodo]="zumapro_caimito komodo"
  [comet]="zumapro_comet comet" [tegu]="zumapro_tegu tegu" [stallion]="zumapro_stallion stallion"
  [frankel]="laguna_muzel frankel" [blazer]="laguna_muzel blazer" [mustang]="laguna_muzel mustang" [rango]="laguna_rango rango"
)
# Expected stamp is the literal <dev>-latest symlink target (readlink, not
# readlink -f). There is no per-device stamp literal. A missing pointer fails
# closed — it never falls back to a global `latest` and never PASSes.

FAIL=0
PASS_N=0
HOLD_N=0
RES_N=0
CHECKS_N=0
pass(){ echo "PASS: $*"; PASS_N=$((PASS_N+1)); }
fail(){ echo "FAIL: $*"; FAIL=1; }
hold(){ echo "HOLD: $*"; HOLD_N=$((HOLD_N+1)); }
res(){  echo "RESIDUAL: $*"; RES_N=$((RES_N+1)); }

CANON() { # resolution token -> canonical variant id (or UNKNOWN)
  case "$1" in
    zuma_shusky) echo zuma_shusky;;
    akita|zuma_akita) echo zuma_akita;;
    tokay|caiman|komodo|zumapro_caimito) echo zumapro_caimito;;
    comet|zumapro_comet) echo zumapro_comet;;
    tegu|zumapro_tegu) echo zumapro_tegu;;
    stallion|zumapro_stallion) echo zumapro_stallion;;
    laguna_muzel|frankel|blazer|mustang) echo laguna_muzel;;
    laguna_rango|rango) echo laguna_rango;;
    *) echo UNKNOWN;;
  esac
}

stamp_dir() { # <dev> -> canonical dir of the <dev>-latest symlink, else a missing path
  local d="$1"
  local ptr="$STAMPS/$d-latest"
  local resolved=""
  if [[ -L "$ptr" ]]; then
    resolved="$(readlink -f "$ptr" 2>/dev/null || true)"
  fi
  if [[ -n "$resolved" && -d "$resolved" ]]; then
    printf '%s' "$resolved"
  else
    # No global `latest` fallback: a missing pointer must not open another device.
    printf '%s' "${ptr}.missing"
  fi
}

# Literal symlink text. Empty when the pointer is missing or not a symlink.
stamp_pointer_literal() {
  local ptr="$STAMPS/$1-latest"
  if [[ ! -L "$ptr" ]]; then
    printf ''
    return 1
  fi
  readlink "$ptr"
}

# --- artifact readers (stamp=debugfs images, fixture=plain tree) ---------------
fx_path(){ printf '%s/%s/%s%s' "$FIXTURE" "$1" "$2" "$3"; }
img_cat(){ # <dev> <img.img> <abs-path>
  local dev="$1" img="$2" p="$3"
  if [[ "$MODE" == "fixture" ]]; then cat "$(fx_path "$dev" "$img" "$p")" 2>/dev/null
  else debugfs -R "cat $p" "$(stamp_dir "$dev")/$img" 2>/dev/null; fi
}
img_exists(){ # <dev> <img.img> <abs-path>
  local dev="$1" img="$2" p="$3"
  if [[ "$MODE" == "fixture" ]]; then [[ -e "$(fx_path "$dev" "$img" "$p")" ]]
  else [[ -n "$(debugfs -R "stat $p" "$(stamp_dir "$dev")/$img" 2>/dev/null | grep '^Inode:')" ]]; fi
}
img_ls(){ # <dev> <img.img> <abs-dir> -> names, one per line
  local dev="$1" img="$2" p="$3"
  if [[ "$MODE" == "fixture" ]]; then ls -1 "$(fx_path "$dev" "$img" "$p")" 2>/dev/null
  else debugfs -R "ls $p" "$(stamp_dir "$dev")/$img" 2>/dev/null | tr ' ' '\n' | grep -vE '^$|^debugfs|^[0-9]+$'; fi
}
out_exists(){ [[ -e "out/target/product/$1/$2" ]]; }

# --- negative fixture ----------------------------------------------------------
build_negative_fixture(){
  local dst="$1"
  rm -rf "$dst"; mkdir -p "$dst"
  # A single un-excised device is enough to prove the harness fails loudly.
  local dev=shiba d="$dst/shiba"
  mkdir -p "$d/vendor.img/etc/vintf" "$d/vendor.img/etc/init" "$d/vendor.img/bin/hw" \
           "$d/vendor.img/lib64/hw" "$d/vendor.img/etc/gnss" \
           "$d/vendor_dlkm.img/lib/modules" "$d/system_dlkm.img/lib/modules" \
           "$d/product.img/etc/permissions" "$d/system.img/etc/permissions"
  # Stock (non radio-free) VINTF manifest: no provenance header, radio HAL declared.
  cat > "$d/vendor.img/etc/vintf/manifest.xml" <<'XML'
<manifest version="9.0" type="device" target-level="8">
    <hal format="aidl">
        <name>android.hardware.radio</name>
        <fqname>IRadio/slot1</fqname>
    </hal>
</manifest>
XML
  # Userspace RIL residue (must be absent).
  printf '#!/bin/sh\n' > "$d/vendor.img/bin/hw/rild"; chmod +x "$d/vendor.img/bin/hw/rild"
  # Location daemon stack on a device that documented none (well, shiba is documented;
  # the point here is INV-1/2/3/4 below, but include it for completeness).
  printf 'service gpsd /vendor/bin/hw/gpsd\n    class main\n' > "$d/vendor.img/etc/init/init.gps.rc"
  : > "$d/vendor.img/bin/hw/gpsd"
  : > "$d/vendor.img/lib64/hw/gps.default.so"
  : > "$d/vendor.img/etc/gnss/gps.xml"
  # Feature-permission XML present (must be absent).
  : > "$d/product.img/etc/permissions/android.hardware.bluetooth.xml"
  : > "$d/system.img/etc/permissions/android.hardware.location.xml"
  # Wrong variant in the built blocklist header + nitrous unblocklisted.
  cat > "$d/vendor_dlkm.img/lib/modules/modules.blocklist" <<'BLK'
# GuardTalkOS — laguna_muzel (laguna / laguna) vendor_dlkm modules blocklist.
blocklist bcmdhd4383.ko
BLK
  printf 'nitrous.ko\n' > "$d/vendor_dlkm.img/lib/modules/modules.load"
  printf '%s\n' $BT_MODULES > "$d/system_dlkm.img/lib/modules/modules.load"
  : > "$d/system_dlkm.img/lib/modules/modules.blocklist"
  echo "built negative fixture at $dst"
}

if [[ "${1:-}" == "--build-negative-fixture" ]]; then
  build_negative_fixture "${2:?usage: --build-negative-fixture <dir>}"
  exit 0
fi
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,50p' "$0"; exit 0
fi

mkdir -p "$OUTDIR"
TSV="$OUTDIR/matrix.tsv"
: > "$TSV"
printf 'device\tvariant_exp\tvariant_resolved\ttoken_source\tinv_variant\tinv_radio_free_vintf\tinv_no_rild\tinv_feature_xml_absent\tinv_stamp\tbt_loaded\tbt_blocklisted\tnitrous_loaded\tnitrous_blocklisted\tloc_daemons\tloc_init_disabled\tloc_gps_so\tgnss_cfg\tradio_img_stamp\tmodem_img_out\tradio_disabled_stamp\tresiduals\tfails\n' >> "$TSV"

echo "==================================================================="
echo "Q-EXCISE-13DEV-MATRIX — 13-device airgap-claim harness"
echo "mode=$MODE root=$ROOT"
[[ "$MODE" == "fixture" ]] && echo "fixture=$FIXTURE"
echo "LIVE_FLASH_CLAIMED=false  DEVICE_RESULT=HOLD  Gate 5: HUMAN SKIP"
echo "==================================================================="
echo

for dev in $DEVICES; do
  f=0
  inv_variant=FAIL; inv_vintf=FAIL; inv_rild=FAIL; inv_fx=FAIL; inv_stamp=FAIL
  resid=""
  printf -- '--- %s ---\n' "$dev"

  # ---- INV-1: variant resolved from a BUILT artifact equals the expected one ----
  bhdr="$(img_cat "$dev" vendor_dlkm.img /lib/modules/modules.blocklist | grep -m1 'GuardTalkOS')"
  htok="$(printf '%s' "$bhdr" | sed -n 's/.*GuardTalkOS[^A-Za-z0-9_]*\([A-Za-z0-9_]*\).*/\1/p')"
  manifest="$(img_cat "$dev" vendor.img /etc/vintf/manifest.xml || true)"
  vhdr="$(printf '%s\n' "$manifest" | grep -oE 'vendor_manifest_no_radio[^ ]*\.xml' | head -1 || true)"
  observed="$(printf '%s\n' "$manifest" | grep -oE 'vendor_manifest[^[:space:]]*\.xml' | head -1 || true)"
  vsuf="$(printf '%s' "$vhdr" | sed -n 's/^vendor_manifest_no_radio_\(.*\)\.xml$/\1/p')"
  if [[ -n "$htok" ]]; then rtok="$htok"; rsrc="vendor_dlkm-blocklist-header"
  elif [[ -n "$vsuf" ]]; then rtok="$vsuf"; rsrc="vintf-provenance-header"
  else rtok=""; rsrc="none"; fi
  rvar="$(CANON "${rtok:-NONE}")"
  if [[ " ${ACCEPT_TOKENS[$dev]} " == *" ${rtok} "* && "$rvar" == "${EXPECTED_VARIANT[$dev]}" ]]; then
    inv_variant=PASS; pass "$dev variant resolved '$rtok' ($rsrc) == expected ${EXPECTED_VARIANT[$dev]}"
  else
    f=1; fail "$dev variant resolved '$rtok' ($rsrc) -> '$rvar' but expected ${EXPECTED_VARIANT[$dev]} (accepted: ${ACCEPT_TOKENS[$dev]})"
  fi

  # ---- INV-2: radio HALs absent. Missing radio-free provenance is HOLD, not a radio-HAL failure. ----
  radio_hal="$(printf '%s\n' "$manifest" | grep -cE '<name>android\.hardware\.(radio|telephony|ims|iwlan)' || true)"
  if [[ -z "${manifest//[[:space:]]/}" ]]; then
    f=1; fail "$dev vendor VINTF manifest unreadable or empty — radio HAL count not evaluated"
  elif [[ "$radio_hal" != "0" ]]; then
    f=1; fail "$dev vendor VINTF not radio-free (provenance='${vhdr:-NONE}', radio HALs=$radio_hal)"
  elif [[ "$vhdr" == vendor_manifest_no_radio* ]]; then
    inv_vintf=PASS; pass "$dev vendor VINTF is radio-free ($vhdr; 0 radio/telephony/ims/iwlan HALs)"
  else
    inv_vintf=HOLD
    hold "$dev vendor VINTF radio HALs=0 but radio-free provenance artifact absent (expected vendor_manifest_no_radio*.xml, observed='${observed:-NONE}') — radio-free claim BLOCKED"
  fi
  # residual: BT HAL still declared (F-003)
  bt_hal="$(printf '%s\n' "$manifest" | grep -cE '<name>android\.hardware\.bluetooth</name>' || true)"
  [[ "$bt_hal" != "0" ]] && resid="$resid bt_hal_declared"

  # ---- INV-3: userspace RIL residue absent ----
  rild_hits=0
  for img in vendor.img system.img system_ext.img; do
    for p in /bin/rild /bin/rild_external /bin/hw/rild; do img_exists "$dev" "$img" "$p" && rild_hits=$((rild_hits+1)); done
  done
  if [[ "$rild_hits" == "0" ]]; then inv_rild=PASS; pass "$dev no userspace rild/rild_external residue"
  else f=1; fail "$dev userspace RIL residue present ($rild_hits hit(s))"; fi

  # ---- INV-4: feature-permission XMLs absent for BT/NFC/Location ----
  fx_hits=0
  for img in product.img system.img vendor.img; do
    for stem in $FEATURE_XML_STEMS; do
      for suf in "" ".prebuilt"; do
        img_exists "$dev" "$img" "/etc/permissions/${stem}${suf}.xml" && fx_hits=$((fx_hits+1))
      done
    done
  done
  if [[ "$fx_hits" == "0" ]]; then inv_fx=PASS; pass "$dev feature-permission XMLs absent for BT/NFC/Location"
  else f=1; fail "$dev $fx_hits feature-permission XML(s) present for BT/NFC/Location"; fi

  # ---- INV-5: stamp identity is the live <dev>-latest symlink (readlink, not -f) ----
  if [[ "$MODE" == "stamp" ]]; then
    ptr="$STAMPS/${dev}-latest"
    literal="$(stamp_pointer_literal "$dev" || true)"
    injected=""
    if [[ -n "${GTQ_MX_INJECT_STAMP_EXPECT:-}" ]]; then
      for pair in $GTQ_MX_INJECT_STAMP_EXPECT; do
        case "$pair" in
          "${dev}="*) injected="${pair#*=}" ;;
        esac
      done
    fi
    canon=""
    if [[ -L "$ptr" ]]; then
      canon="$(basename "$(readlink -f "$ptr" 2>/dev/null || true)")"
    fi
    stamp_id_glob="${dev}-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]"
    if [[ ! -L "$ptr" ]]; then
      f=1; fail "$dev stamp pointer missing or not a symlink ($ptr) — fail closed"
    elif [[ -z "$literal" ]]; then
      f=1; fail "$dev stamp pointer readlink is empty ($ptr) — fail closed"
    elif [[ "$literal" == /* || "$literal" == */* || "$literal" == *..* ]]; then
      f=1; fail "$dev stamp pointer target '$literal' is not a single relative stamp id — fail closed"
    elif [[ "$literal" != $stamp_id_glob ]]; then
      f=1; fail "$dev stamp pointer target '$literal' is not a ${dev}-YYYYMMDD-HHMMSS id — fail closed"
    elif [[ ! -d "$STAMPS/$literal" ]]; then
      f=1; fail "$dev stamp pointer target '$literal' does not exist — fail closed"
    elif [[ "$canon" != "$literal" ]]; then
      f=1; fail "$dev stamp canonical name '$canon' disagrees with readlink '$literal'"
    elif [[ -n "$injected" && "$literal" != "$injected" ]]; then
      f=1; fail "$dev stamp mismatch: live readlink='$literal' injected expected='$injected'"
    else
      inv_stamp=PASS; pass "$dev stamp ${dev}-latest -> $literal (live readlink)"
    fi
  else
    inv_stamp=PASS; printf ''   # fixture mode: no stamp symlinks to assert
  fi

  # ---- BT: 8 GKI modules loaded/blocklisted + nitrous ----
  bt_loaded=0; bt_blk=0
  mload="$(img_cat "$dev" system_dlkm.img /lib/modules/modules.load)"
  mblk="$(img_cat "$dev" system_dlkm.img /lib/modules/modules.blocklist)"
  for m in $BT_MODULES; do
    printf '%s\n' "$mload" | grep -qx -- "$m" && bt_loaded=$((bt_loaded+1))
    printf '%s\n' "$mblk"  | grep -qE "^blocklist[[:space:]]+$m\$" && bt_blk=$((bt_blk+1))
  done
  nload=0; nblk=0
  printf '%s\n' "$(img_cat "$dev" vendor_dlkm.img /lib/modules/modules.load)" | grep -qx 'nitrous.ko' && nload=1
  printf '%s\n' "$(img_cat "$dev" vendor_dlkm.img /lib/modules/modules.blocklist)" | grep -qE '^blocklist[[:space:]]+nitrous(\.ko)?$' && nblk=1
  [[ "$nload" == "1" && "$nblk" == "0" ]] && resid="$resid nitrous_unblocklisted"
  [[ "$bt_loaded" != "0" && "$bt_blk" == "0" ]] && resid="$resid bt_gki_${bt_loaded}_loaded_unblocklisted"
  printf '      BT GKI loaded=%s blocklisted=%s ; nitrous loaded=%s blocklisted=%s\n' \
    "$bt_loaded" "$bt_blk" "$nload" "$nblk"

  # ---- location daemon stack + init disabled ----
  loc=""
  for b in gpsd lhd scd; do img_exists "$dev" vendor.img "/bin/hw/$b" && loc="$loc $b"; done
  loc="${loc# }"
  igrc=no; igdis=0
  if img_exists "$dev" vendor.img /etc/init/init.gps.rc; then
    igrc=yes; igdis="$(img_cat "$dev" vendor.img /etc/init/init.gps.rc | grep -cE '^[[:space:]]*disabled')"
  fi
  gsof=no; img_exists "$dev" vendor.img /lib64/hw/gps.default.so && gsof=yes
  gnss="$(img_ls "$dev" vendor.img /etc/gnss | grep -E '\.(xml|conf|cer)$' | paste -sd, -)"
  if [[ -n "$loc" ]]; then
    resid="$resid loc_daemons:${loc// /,}"
    if [[ " $DOC_LOC_DEVICES " == *" $dev "* ]]; then
      res "$dev location daemons present ($loc), init.gps.rc=$igrc disabled=${igdis} — documented E-9 residual"
    else
      f=1; fail "$dev UNEXPECTED location daemon residue ($loc) — outside documented set [$DOC_LOC_DEVICES]"
    fi
  fi

  # ---- baseband firmware residual (never a removal) ----
  rimg=no
  if [[ "$MODE" == "fixture" ]]; then [[ -e "$(fx_path "$dev" radio.img "/")" || -e "$FIXTURE/$dev/radio.img" ]] && rimg=yes
  else [[ -e "$(stamp_dir "$dev")/radio.img" ]] && rimg=yes; fi
  mimg=no; out_exists "$dev" modem.img && mimg=yes
  if [[ "$MODE" == "stamp" ]]; then
    if [[ "$rimg" == yes && "$mimg" == yes ]]; then
      res "$dev baseband firmware PRESENT (radio.img stamp=$(stat -c%s "$(stamp_dir "$dev")/radio.img") B, modem.img out=$(stat -c%s "out/target/product/$dev/modem.img") B) — Tier B residual, not a removal"
      resid="$resid baseband_fw"
    else
      res "$dev baseband firmware observation: radio.img=$rimg modem.img=$mimg"
    fi
  fi
  # radio.disabled mitigation flag (informational; E-12 subject)
  rd=no
  if [[ "$MODE" == "stamp" ]]; then strings "$(stamp_dir "$dev")/vendor_boot.img" 2>/dev/null | grep -q 'androidboot.radio.disabled' && rd=yes; fi

  # ---- undocumented nitrous regression check ----
  if [[ "$nload" == "1" && "$nblk" == "0" ]]; then
    if [[ " $DOC_NITROUS_UNBLOCKED " != *" $dev "* ]]; then
      f=1; fail "$dev UNEXPECTED nitrous.ko loaded+unblocklisted — outside documented set [$DOC_NITROUS_UNBLOCKED]"
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$dev" "${EXPECTED_VARIANT[$dev]}" "$rvar" "$rsrc" "$inv_variant" "$inv_vintf" "$inv_rild" "$inv_fx" "$inv_stamp" \
    "$bt_loaded" "$bt_blk" "$nload" "$nblk" "${loc:-none}" "$igrc/d$igdis" "$gsof" "${gnss:-none}" "$rimg" "$mimg" "$rd" \
    "${resid# }" "$f" >> "$TSV"

  printf '      residual register:%s\n\n' "${resid:- (none)}"
done

echo "==================================================================="
echo "Q-EXCISE-13DEV-MATRIX summary"
echo "devices=$DEVICES"
echo "PASS=$PASS_N  HOLD=$HOLD_N  RESIDUAL=$RES_N  FAIL=$FAIL"
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
echo "matrix TSV: $TSV"
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL — at least one invariant violated or undocumented residual"
  echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
  exit 1
fi
echo "RESULT: PASS — every hard invariant holds on every device; residuals are the documented register only"
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=0"
if [[ "$HOLD_N" -ne 0 ]]; then
  echo "NOTE: HOLD=$HOLD_N. A HOLD blocks the named claim. It is not a PASS of that claim."
fi
echo "NOTE: this harness proves the matrix, NOT the absence of the documented residuals."
exit 0
