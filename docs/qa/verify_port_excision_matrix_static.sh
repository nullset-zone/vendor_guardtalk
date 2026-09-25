#!/usr/bin/env bash
# Static verification for T-PORT-EXCISION-MATRIX (P0).
#
# Proves the shared excision core is VARIANT-DATA-DRIVEN (not per-device forks)
# and that an unregistered device FAILS LOUDLY instead of silently no-opping
# (the T-PORT-SHARED-CORE-FIX defect).
#
# Cases:
#   1. Registry + resolver present; no new per-device filter files were added
#   2. Positive: all 13 program devices resolve to the expected variant
#      (variant / SoC / kernel family / wifi / touch / fp stack / radio / blocklist)
#   3. Divergence PROVEN, not asserted: akita=zuma/bcmdhd4383/Goodix vs
#      tokay+komodo=zumapro/bcmdhd4390/QFP, cross-checked against the upstream
#      kernel-tree blocklists, the resolved blocklist payload, AND the adevtool
#      vendor skeleton (fingerprint stack truth)
#   4. Board-config dry run for the 4 in-force devices (akita/tokay/komodo/rango):
#      resolver + gt-excision-validate-device-blocklist PASS
#   5. Zero-regression by content: the blocklist each in-force device ends up
#      with is byte-path-identical to the path it used BEFORE this card
#   6. Fingerprint filter is data-driven and its union == the frozen baseline
#      (13 tokens); live filter drops fp packages and keeps face/biometrics-common
#   7. NEGATIVE: synthetic failure modes must all fail loudly (non-zero exit,
#      named error) — never silently pass
#   8. Gen 6 (gs101) / Gen 7 (gs201) codenames are absent (out of program scope)
#   9. docs/EXCISION_MATRIX.md publishes the variant matrix + add-a-device recipe
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_port_excision_matrix_static.sh
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
forbid_rg() {
  local pat="$1" file="$2" label="${3:-$1}"
  if [[ ! -f "$file" ]]; then fail "$label (file missing: $file)"; return; fi
  if rg -q -- "$pat" "$file"; then fail "$label (forbidden pattern '$pat' present in $file)"
  else pass "$label"; fi
}

REGISTRY="vendor/guardtalk/feature-excised/excision-variants.mk"
RESOLVER="vendor/guardtalk/feature-excised/excision-variant-select.mk"
FP="vendor/guardtalk/feature-excised/fp-excised.mk"
RADIO_BRIDGE="vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk"
FEAT_BRIDGE="vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
DOC="vendor/guardtalk/docs/EXCISION_MATRIX.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# tokens() <blocklist-file> -> sorted token list ("blocklist " prefix stripped)
tokens() { sed -n 's/^[[:space:]]*blocklist[[:space:]]*//p' "$1" 2>/dev/null | sort; }

echo "=== T-PORT-EXCISION-MATRIX case1: registry + resolver present, no per-device forks ==="

require_file "$REGISTRY" "excision-variants.mk (data registry)"
require_file "$RESOLVER" "excision-variant-select.mk (resolver)"
require_file "$FP" "fp-excised.mk"
require_file "$RADIO_BRIDGE" "radio-excised/guardtalk-radio-excised.mk"
require_file "$FEAT_BRIDGE" "feature-excised/guardtalk-feature-excised.mk"
require_rg 'GT_DEVICE_VARIANT_akita' "$REGISTRY" "registry maps akita"
require_rg 'GUARDTALK_DEVICE' "$RESOLVER" "resolver honours GUARDTALK_DEVICE"
require_rg 'excision-variant-select\.mk' "$RADIO_BRIDGE" "radio bridge resolves variant from data"
require_rg 'excision-variant-select\.mk' "$FEAT_BRIDGE" "feature bridge resolves variant from data"
require_rg 'GT_EXCISION_FP_DROP_PATTERNS' "$FP" "fp-excised consumes registry-derived token set"
forbid_rg 'bcmdhd4383|bcmdhd4390|bcmdhd4398' "$FP" "fp-excised has no Wi-Fi-soc branch (that data lives in the registry)"
# No new per-device filter files: feature-excised/ must not grow a per-codename mk.
extra_dev_filters="$(find vendor/guardtalk/feature-excised -maxdepth 1 -type f \
  \( -name 'akita*.mk' -o -name 'tokay*.mk' -o -name 'komodo*.mk' -o -name 'rango*.mk' \
     -o -name 'caiman*.mk' -o -name 'comet*.mk' -o -name 'tegu*.mk' -o -name 'shiba*.mk' \
     -o -name 'husky*.mk' -o -name 'stallion*.mk' -o -name 'frankel*.mk' -o -name 'blazer*.mk' \
     -o -name 'mustang*.mk' \) -print | wc -l | tr -d ' ')"
if [[ "$extra_dev_filters" == "0" ]]; then
  pass "no per-codename filter files in feature-excised/ (selection is data-driven)"
else
  fail "$extra_dev_filters per-codename filter file(s) in feature-excised/ (must be data-driven)"
fi

echo "=== T-PORT-EXCISION-MATRIX case2: all 13 program devices resolve from data ==="

PROBE="$TMP/probe.mk"
cat > "$PROBE" <<'EOF'
include vendor/guardtalk/feature-excised/excision-variant-select.mk
$(info GTQ|$(GT_EXCISION_DEVICE)|$(GT_VARIANT)|$(GT_VARIANT_SOC)|$(GT_VARIANT_KERNEL_FAMILY)|$(GT_VARIANT_WIFI_MODULES)|$(GT_VARIANT_TOUCH_MODULES)|$(GT_VARIANT_FP_STACK)|$(GT_VARIANT_RADIO_SET)|$(GT_EXCISION_BLOCKLIST_FILE))
GTQ_PROBE_DONE:
	@:
EOF

# device|variant|soc|kernel_family|wifi|touch|fp|radio  (blocklist checked in case5)
EXPECTED=(
  "shiba|zuma_shusky|zuma|shusky|bcmdhd4398|goodix_brl_touch sec_touch|goodix|shannon"
  "husky|zuma_shusky|zuma|shusky|bcmdhd4398|goodix_brl_touch sec_touch|goodix|shannon"
  "akita|zuma_akita|zuma|akita|bcmdhd4383|goodix_brl_touch|goodix|shannon"
  "tokay|zumapro_caimito|zumapro|caimito|bcmdhd4390|syna_touch sec_touch|qfp|shannon"
  "caiman|zumapro_caimito|zumapro|caimito|bcmdhd4390|syna_touch sec_touch|qfp|shannon"
  "komodo|zumapro_caimito|zumapro|caimito|bcmdhd4390|syna_touch sec_touch|qfp|shannon"
  "comet|zumapro_comet|zumapro|comet|bcmdhd4390|goodix_brl_touch syna_touch sec_touch|goodix|shannon"
  "tegu|zumapro_tegu|zumapro|tegu|bcmdhd4383|syna_touch|goodix|shannon"
  "stallion|zumapro_stallion|zumapro|stallion|bcmdhd4383|focal_touch|goodix|shannon"
  "frankel|laguna_muzel|laguna|laguna|bcmdhd4383 bcmdhd4390|syna_touch focal_touch fst2|qfp|shannon"
  "blazer|laguna_muzel|laguna|laguna|bcmdhd4383 bcmdhd4390|syna_touch focal_touch fst2|qfp|shannon"
  "mustang|laguna_muzel|laguna|laguna|bcmdhd4383 bcmdhd4390|syna_touch focal_touch fst2|qfp|shannon"
  "rango|laguna_rango|laguna|laguna|bcmdhd4383 bcmdhd4390|syna_touch focal_touch fst2|goodix|shannon"
)
soc_of() { case "$1" in shiba|husky|akita) echo zuma;; frankel|blazer|mustang|rango) echo laguna;; *) echo zumapro;; esac; }

RESOLVED="$TMP/resolved.txt"
: > "$RESOLVED"
for row in "${EXPECTED[@]}"; do
  dev="${row%%|*}"; want="${row#*|}"
  out="$(make -s -f "$PROBE" GUARDTALK_DEVICE="$dev" TARGET_BOARD_PLATFORM="$(soc_of "$dev")" 2>&1 || true)"
  line="$(printf '%s\n' "$out" | rg '^GTQ\|' | head -1 || true)"
  printf '%s\n' "$line" >> "$RESOLVED"
  if [[ -z "$line" ]]; then
    fail "resolve $dev produced no GTQ row (make output: $(printf '%s' "$out" | tail -1))"
    continue
  fi
  got="$(printf '%s\n' "$line" | cut -d'|' -f3-9)"
  if [[ "$got" == "$want" ]]; then
    pass "resolve $dev → $(printf '%s' "$line" | cut -d'|' -f3) [$(printf '%s' "$line" | cut -d'|' -f5) / $(printf '%s' "$line" | cut -d'|' -f8)]"
  else
    fail "resolve $dev → '$got' expected '$want'"
  fi
done
n_resolved="$(rg -c '^GTQ\|' "$RESOLVED" || true)"
if [[ "${n_resolved:-0}" == "13" ]]; then
  pass "13/13 program devices resolved from registry data"
else
  fail "expected 13 resolved rows, got ${n_resolved:-0}"
fi

echo "=== T-PORT-EXCISION-MATRIX case3: divergence proven against upstream kernel trees ==="

# Upstream truth (read-only): the kernel tree's own vendor_dlkm.modules.blocklist.
require_rg '^blocklist bcmdhd4383$' \
  device/google/akita-kernels/6.1/grapheneos/vendor_dlkm.modules.blocklist \
  "upstream akita tree blocklists bcmdhd4383 (zuma Wi-Fi)"
require_rg '^blocklist bcmdhd4390$' \
  device/google/caimito-kernels/6.1/grapheneos/vendor_dlkm.modules.blocklist \
  "upstream caimito tree blocklists bcmdhd4390 (zumapro Wi-Fi)"
forbid_rg '^blocklist bcmdhd4390$' \
  device/google/akita-kernels/6.1/grapheneos/vendor_dlkm.modules.blocklist \
  "upstream akita tree does NOT blocklist bcmdhd4390"

akita_row="$(rg '^GTQ\|akita\|' "$RESOLVED" || true)"
komodo_row="$(rg '^GTQ\|komodo\|' "$RESOLVED" || true)"
tokay_row="$(rg '^GTQ\|tokay\|' "$RESOLVED" || true)"
akita_blk="$(printf '%s' "$akita_row" | cut -d'|' -f10)"
komodo_blk="$(printf '%s' "$komodo_row" | cut -d'|' -f10)"
tokay_blk="$(printf '%s' "$tokay_row" | cut -d'|' -f10)"

# The resolved payload must carry the variant's Wi-Fi token and must NOT carry
# the other SoC's token — proven against the file the resolver actually returned.
if tokens "$akita_blk" | rg -qx 'bcmdhd4383'; then
  pass "akita resolved blocklist carries bcmdhd4383 ($akita_blk)"
else
  fail "akita resolved blocklist $akita_blk missing bcmdhd4383"
fi
if tokens "$akita_blk" | rg -qx 'bcmdhd4390'; then
  fail "akita resolved blocklist $akita_blk wrongly carries bcmdhd4390"
else
  pass "akita resolved blocklist omits bcmdhd4390"
fi
for d in tokay komodo; do
  if [[ $d == tokay ]]; then blk="$tokay_blk"; else blk="$komodo_blk"; fi
  if tokens "$blk" | rg -qx 'bcmdhd4390'; then
    pass "$d resolved blocklist carries bcmdhd4390 ($blk)"
  else
    fail "$d resolved blocklist $blk missing bcmdhd4390"
  fi
  if tokens "$blk" | rg -qx 'bcmdhd4383'; then
    fail "$d resolved blocklist $blk wrongly carries bcmdhd4383"
  else
    pass "$d resolved blocklist omits bcmdhd4383"
  fi
done

# Independent cross-check of the FP_STACK column against the adevtool vendor
# skeleton (upstream truth for which fingerprint HAL a device ships).
qfp_devs="tokay caiman komodo frankel blazer mustang"
goodix_devs="shiba husky akita comet tegu stallion rango"
for d in $qfp_devs; do
  skel="vendor/adevtool/vendor-skels/google_devices/$d/$d.mk"
  row="$(rg "^GTQ\\|$d\\|" "$RESOLVED" || true)"
  reg_fp="$(printf '%s' "$row" | cut -d'|' -f8)"
  if [[ -f "$skel" ]] && rg -q 'fingerprint-ext-V2-ndk' "$skel" \
     && ! rg -q 'fingerprint-service\.goodix' "$skel"; then
    pass "vendor-skel $d = QFP (upstream fingerprint truth)"
  else
    fail "vendor-skel $d does not look QFP ($skel)"
  fi
  if [[ "$reg_fp" == "qfp" ]]; then
    pass "registry $d FP_STACK=qfp matches vendor-skel"
  else
    fail "registry $d FP_STACK='$reg_fp' != vendor-skel qfp"
  fi
done
for d in $goodix_devs; do
  skel="vendor/adevtool/vendor-skels/google_devices/$d/$d.mk"
  row="$(rg "^GTQ\\|$d\\|" "$RESOLVED" || true)"
  reg_fp="$(printf '%s' "$row" | cut -d'|' -f8)"
  if [[ -f "$skel" ]] && rg -q 'goodix' "$skel"; then
    pass "vendor-skel $d = Goodix (upstream fingerprint truth)"
  else
    fail "vendor-skel $d does not look Goodix ($skel)"
  fi
  if [[ "$reg_fp" == "goodix" ]]; then
    pass "registry $d FP_STACK=goodix matches vendor-skel"
  else
    fail "registry $d FP_STACK='$reg_fp' != vendor-skel goodix"
  fi
done

echo "=== T-PORT-EXCISION-MATRIX case4: board-config dry run (4 in-force devices) ==="

BOARD_PROBE="$TMP/board.mk"
cat > "$BOARD_PROBE" <<'EOF'
AB_OTA_PARTITIONS := boot system vendor
BOARD_KERNEL_CMDLINE := androidboot.hardware=test
include vendor/guardtalk/device/$(GTB_DEV)/BoardConfig-excised-late.mk
$(info GTB|$(GT_VARIANT)|$(BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE)|$(AB_OTA_PARTITIONS)|$(BOARD_KERNEL_CMDLINE))
GTB_BOARD_DONE:
	@:
EOF

for dev in akita tokay komodo rango; do
  out="$(make -s -f "$BOARD_PROBE" GTB_DEV="$dev" 2>&1 || true)"
  line="$(printf '%s\n' "$out" | rg '^GTB\|' | head -1 || true)"
  if [[ -z "$line" ]]; then
    fail "board dry run $dev produced no resolution ($(printf '%s' "$out" | rg '\*\*\*' | head -1))"
    continue
  fi
  blk="$(printf '%s' "$line" | cut -d'|' -f3)"
  abp="$(printf '%s' "$line" | cut -d'|' -f4)"
  cmd="$(printf '%s' "$line" | cut -d'|' -f5)"
  pass "board dry run $dev → variant $(printf '%s' "$line" | cut -d'|' -f2), blocklist $blk"
  if [[ -f "$blk" ]]; then pass "  $dev blocklist file exists"; else fail "  $dev blocklist missing: $blk"; fi
  if [[ "$abp" == "boot system vendor" ]]; then pass "  $dev modem filtered out of AB_OTA_PARTITIONS ($abp)"
  else fail "  $dev AB_OTA_PARTITIONS unexpected: '$abp'"; fi
  if printf '%s' "$cmd" | rg -q 'androidboot\.radio\.disabled=1'; then pass "  $dev cmdline has androidboot.radio.disabled=1"
  else fail "  $dev cmdline missing radio.disabled=1 ('$cmd')"; fi
  if ! printf '%s' "$out" | rg -q '\*\*\*|Stop\.'; then pass "  $dev gt-excision-validate-device-blocklist PASS"
  else fail "  $dev validate errored: $(printf '%s' "$out" | rg '\*\*\*' | head -1)"; fi
done

echo "=== T-PORT-EXCISION-MATRIX case5: zero-regression — resolved blocklist == pre-card path ==="

# Pre-card BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE for each in-force device.
declare -A PRE_CARD_BLOCKLIST=(
  [akita]="vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist"
  [tokay]="vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist"
  [komodo]="vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist"
  [rango]="vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist"
)
for dev in akita tokay komodo rango; do
  out="$(make -s -f "$BOARD_PROBE" GTB_DEV="$dev" 2>&1 || true)"
  got="$(printf '%s\n' "$out" | rg '^GTB\|' | head -1 | cut -d'|' -f3)"
  want="${PRE_CARD_BLOCKLIST[$dev]}"
  if [[ "$got" == "$want" ]]; then
    pass "$dev resolved blocklist path identical to pre-card ($got)"
  else
    fail "$dev blocklist path moved: got '$got' want '$want'"
  fi
done
if diff <(tokens vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist) \
        <(tokens vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist) >/dev/null; then
  pass "komodo pin is token-identical to variant zumapro_caimito canonical file"
else
  fail "komodo pin token-drifts from variant zumapro_caimito canonical file"
fi
if diff <(tokens vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist) \
        <(tokens vendor/guardtalk/feature-excised/variants/laguna_muzel/vendor_dlkm.modules.blocklist) >/dev/null; then
  pass "rango pin is token-identical to variant laguna canonical copy"
else
  fail "rango pin token-drifts from variant laguna canonical copy"
fi

echo "=== T-PORT-EXCISION-MATRIX case6: fingerprint filter data-driven + baseline-covered ==="

FP_PROBE="$TMP/fp.mk"
cat > "$FP_PROBE" <<'EOF'
GUARDTALK_DEVICE := akita
PRODUCT_PACKAGES := \
  android.hardware.biometrics.fingerprint-V3-ndk.vendor \
  android.hardware.fingerprint.prebuilt.xml \
  com.google.hardware.biometrics.fingerprint.fingerprint-ext-V2-ndk \
  vendor.qti.hardware.fingerprint.aidl-V1-ndk \
  dump_fingerprint qfp-daemon \
  android.hardware.biometrics.fingerprint-service.goodix \
  libvendor.goodix.hardware.biometrics.fingerprint@2.1 \
  goodixfingerprint goodix_sfps_suez goodixbinderservice-aidl-V1-ndk \
  com.android.hardware.biometrics.face.virtual \
  android.hardware.biometrics.common-V3-ndk.vendor TrichromeWebView SomeUnrelatedPkg
PRODUCT_COPY_FILES := vendor/x/qfp-daemon.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/qfp-daemon.rc
include vendor/guardtalk/feature-excised/excision-variant-select.mk
include vendor/guardtalk/feature-excised/fp-excised.mk
$(info GTPT|$(words $(GT_FP_DROP_PATTERNS)))
$(info GTPP|$(PRODUCT_PACKAGES))
$(info GTCC|$(PRODUCT_COPY_FILES))
GTP_FP_DONE:
	@:
EOF
fp_out="$(make -s -f "$FP_PROBE" 2>&1 || true)"
fp_n="$(printf '%s\n' "$fp_out" | sed -n 's/^GTPT|//p' | head -1)"
pkgs="$(printf '%s\n' "$fp_out" | sed -n 's/^GTPP|//p' | head -1)"
copies="$(printf '%s\n' "$fp_out" | sed -n 's/^GTCC|//p' | head -1)"
if [[ "${fp_n:-0}" == "13" ]]; then
  pass "registry-derived fp drop-pattern set == 13 (frozen baseline fully covered)"
else
  fail "fp drop-pattern count '${fp_n:-none}' != 13"
fi
fp_leak=0
for tok in biometrics.fingerprint fingerprint.prebuilt qfp-daemon goodixfingerprint goodix_sfps goodixbinderservice dump_fingerprint; do
  if printf '%s' "$pkgs" | rg -q -- "$tok"; then
    fail "fp filter LEAKED package token '$tok'"
    fp_leak=1
  fi
done
[[ "$fp_leak" == "0" ]] && pass "all fingerprint packages dropped from PRODUCT_PACKAGES"
for keep in com.android.hardware.biometrics.face.virtual android.hardware.biometrics.common-V3-ndk.vendor TrichromeWebView SomeUnrelatedPkg; do
  if printf '%s' "$pkgs" | rg -q -F -- "$keep"; then pass "  preserved: $keep"
  else fail "  wrongly dropped: $keep"; fi
done
if [[ -z "$copies" ]]; then pass "fingerprint init .rc copy-files dropped"
else fail "fingerprint copy-files survived: $copies"; fi

# Standalone include (registry not loaded) must still use the frozen baseline.
STANDALONE="$TMP/fp-standalone.mk"
cat > "$STANDALONE" <<'EOF'
PRODUCT_PACKAGES := qfp-daemon goodixfingerprint com.android.hardware.biometrics.face.virtual
PRODUCT_COPY_FILES :=
include vendor/guardtalk/feature-excised/fp-excised.mk
$(info GTST|$(words $(GT_FP_DROP_PATTERNS))|$(PRODUCT_PACKAGES))
GTST_FP_DONE:
	@:
EOF
st_out="$(make -s -f "$STANDALONE" 2>&1 || true)"
if printf '%s' "$st_out" | rg -q '^GTST\|13\|com\.android\.hardware\.biometrics\.face\.virtual$'; then
  pass "standalone fp-excised include falls back to the 13-token baseline"
else
  fail "standalone fp-excised baseline wrong: $(printf '%s' "$st_out" | rg '^GTST' | head -1)"
fi

echo "=== T-PORT-EXCISION-MATRIX case7: NEGATIVE — no silent no-op anywhere ==="

neg_case() { # <name> <must-match-regex> <expected-exit-nonzero> <make args...>
  local name="$1" want="$2" ; shift 2
  local out rc=0
  out="$(make -s -f "$PROBE" "$@" 2>&1 || true)"
  make -s -f "$PROBE" "$@" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    fail "NEG $name: exited 0 (SILENT NO-OP — must fail loudly)"
    return
  fi
  if printf '%s' "$out" | rg -q -- "$want"; then
    pass "NEG $name: failed loudly (exit $rc) — $(printf '%s' "$out" | rg -o -- "$want" | head -1)"
  else
    fail "NEG $name: failed but message did not match /$want/ (got: $(printf '%s' "$out" | rg '\*\*\*' | head -1))"
  fi
}

# NEG-1: device not registered AND SoC unknown.
neg_case "unregistered-device-unknown-soc" "is not registered .* is UNKNOWN" \
  GUARDTALK_DEVICE=zzz_synth_dev TARGET_BOARD_PLATFORM=zzz_synth_soc
# NEG-2: device not registered, SoC matches >1 variant → ambiguous, never guessed.
neg_case "unregistered-device-ambiguous-soc" "AMBIGUOUS \(candidates:" \
  GUARDTALK_DEVICE=zzz_synth_dev TARGET_BOARD_PLATFORM=zumapro
# NEG-3: device not registered and no SoC to fall back on.
neg_case "unregistered-device-no-soc" "has NO excision variant entry" \
  GUARDTALK_DEVICE=zzz_synth_dev TARGET_BOARD_PLATFORM=
# NEG-4: no device identity at all.
neg_case "no-device-identity" "no known device identity" \
  GUARDTALK_DEVICE= TARGET_DEVICE= PRODUCT_DEVICE=
# NEG-5: explicit variant name that is not in the registry.
neg_case "unknown-variant-name" "unknown excision variant 'bogus_variant'" \
  GUARDTALK_DEVICE=akita GUARDTALK_EXCISION_VARIANT=bogus_variant TARGET_BOARD_PLATFORM=zuma

# NEG-6/7: a pin that is NOT the variant's registered canonical file.
DRIFT_A="$TMP/drift-a.mk"
cat > "$DRIFT_A" <<'EOF'
TARGET_BOARD_PLATFORM := zumapro
GUARDTALK_DEVICE := komodo
include vendor/guardtalk/feature-excised/excision-variant-select.mk
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GTB_BLK)
$(call gt-excision-validate-device-blocklist)
$(info GTDRIFT_REACHED)
GTDRIFT_A_DONE:
	@:
EOF
neg_path() { # <name> <want-regex> <board-path>
  local name="$1" want="$2" blk="$3" out rc=0
  out="$(make -s -f "$DRIFT_A" GTB_BLK="$blk" 2>&1 || true)"
  make -s -f "$DRIFT_A" GTB_BLK="$blk" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then fail "NEG $name: exited 0 (silent blocklist drift accepted)"; return; fi
  if printf '%s' "$out" | rg -q 'GTDRIFT_REACHED'; then fail "NEG $name: validate did not abort"; return; fi
  if printf '%s' "$out" | rg -q -- "$want"; then
    pass "NEG $name: failed loudly (exit $rc)"
  else
    fail "NEG $name: wrong error (got: $(printf '%s' "$out" | rg '\*\*\*' | head -1))"
  fi
}
neg_path "blocklist-pin-not-variant-file" "resolves to" \
  "vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist"
neg_path "blocklist-pin-missing-file" "which does not exist" \
  "vendor/guardtalk/device/komodo/nope.modules.blocklist"

# NEG-8/9: a *registered* pin whose TOKENS drift from the variant canonical.
# Here the pin path IS the registered one, so only the token guard can catch it.
DRIFT_B="$TMP/drift-b.mk"
cat > "$DRIFT_B" <<'EOF'
TARGET_BOARD_PLATFORM := zumapro
GUARDTALK_DEVICE := komodo
include vendor/guardtalk/feature-excised/excision-variants.mk
GT_DEVICE_BLOCKLIST_komodo := $(GTB_PIN)
include vendor/guardtalk/feature-excised/excision-variant-select.mk
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GTB_PIN)
$(call gt-excision-validate-device-blocklist)
$(info GTDRIFT_REACHED)
GTDRIFT_B_DONE:
	@:
EOF
neg_tokens() { # <name> <want-regex> <pin-path>
  local name="$1" want="$2" pin="$3" out rc=0
  out="$(make -s -f "$DRIFT_B" GTB_PIN="$pin" 2>&1 || true)"
  make -s -f "$DRIFT_B" GTB_PIN="$pin" >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then fail "NEG $name: exited 0 (silent token drift accepted)"; return; fi
  if printf '%s' "$out" | rg -q 'GTDRIFT_REACHED'; then fail "NEG $name: validate did not abort"; return; fi
  if printf '%s' "$out" | rg -q -- "$want"; then
    pass "NEG $name: failed loudly (exit $rc)"
  else
    fail "NEG $name: wrong error (got: $(printf '%s' "$out" | rg '\*\*\*' | head -1))"
  fi
}
tokens vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist \
  | sed 's/^/blocklist /' > "$TMP/komodo-extra.blocklist"
printf 'blocklist EXTRA_INVENTED_TOKEN\n' >> "$TMP/komodo-extra.blocklist"
neg_tokens "blocklist-pin-token-drift-extra" "has extra tokens" "$TMP/komodo-extra.blocklist"
tokens vendor/guardtalk/device/komodo/vendor_dlkm.modules.blocklist \
  | sed 's/^/blocklist /' | grep -v 'nitrous' > "$TMP/komodo-missing.blocklist"
neg_tokens "blocklist-pin-token-drift-missing" "is MISSING tokens" "$TMP/komodo-missing.blocklist"

# NEG-9: registry-derived FP union narrower than the frozen baseline.
NARROW="$TMP/narrow.mk"
cat > "$NARROW" <<'EOF'
include vendor/guardtalk/feature-excised/excision-variants.mk
GT_EXCISION_FP_DROP_PATTERNS := qfp-daemon
include vendor/guardtalk/feature-excised/fp-excised.mk
$(info GTNARROW_REACHED)
GTNARROW_NARROW_DONE:
	@:
EOF
n_out="$(make -s -f "$NARROW" 2>&1 || true)"
n_rc=0; make -s -f "$NARROW" >/dev/null 2>&1 || n_rc=$?
if [[ "$n_rc" -ne 0 ]] && printf '%s' "$n_out" | rg -q 'missing baseline token\(s\)' \
   && ! printf '%s' "$n_out" | rg -q 'GTNARROW_REACHED'; then
  pass "NEG fp-registry-narrowed: failed loudly (exit $n_rc) — refuses to narrow the excision"
else
  fail "NEG fp-registry-narrowed: did not abort (exit $n_rc)"
fi

echo "=== T-PORT-EXCISION-MATRIX case8: Gen 6/7 codenames absent (out of program scope) ==="

for forbidden in oriole raven bluejay panther cheetah lynx felix tangorpro; do
  if rg -q "^GT_DEVICE_VARIANT_${forbidden}[[:space:]]*:=" "$REGISTRY"; then
    fail "Gen 6/7 codename '$forbidden' registered (out of scope, forbidden)"
  else
    pass "Gen 6/7 codename '$forbidden' absent from registry"
  fi
done

echo "=== T-PORT-EXCISION-MATRIX case9: EXCISION_MATRIX.md publishes matrix + recipe ==="

require_file "$DOC" "docs/EXCISION_MATRIX.md"
for pat in 'bcmdhd4383' 'bcmdhd4390' 'goodix_brl_touch' 'syna_touch' 'QFP' 'Goodix' \
           'Add a device' 'GT_DEVICE_VARIANT_' 'excision-variant-select\.mk' \
           'silent no-op' 'zuma' 'zumapro' 'laguna' 'T-PORT-EXCISION-MATRIX'; do
  require_rg "$pat" "$DOC" "EXCISION_MATRIX documents '$pat'"
done

echo ""
echo "=== T-PORT-EXCISION-MATRIX static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
