#!/usr/bin/env bash
# =============================================================================
# T-EXCISE-FLASH-ROLLBACK — host verification harness (no USB, no real flash)
# =============================================================================
# Proves the rollback path built by gt-rollback-to-stock.sh. All of it is
# host-side: nothing is attached, nothing is flashed.
#
#   A. STATIC      — tool syntax, manifest shape, fail-closed markers present.
#   B. FIXTURE     — a tiny fake root + manifest exercises the HAPPY path, so the
#                    suite is NON-VACUOUS (a path that always fails is rejected).
#   C. LIVE        — the real shipped stock artifacts resolve; a real sha256 of
#                    one standard and one laguna device matches the live pin; the
#                    live structural walk honours --no-hash as HOLD (never PASS).
#   D. INJECTIONS  — every declared failure condition is injected into the
#                    fixture and the harness asserts a genuine STOP with the
#                    expected ROLLBACK-FAIL-CLOSED marker.
#
# Read-only w.r.t. the product: the tool is executed, never edited. The fixture
# is a throwaway tmpdir. Exit 0 = all assertions PASS.
#
# NOTE ON SCOPE: this harness proves resolution + hashing + fail-closed guards on
# the HOST. BOOT_VERIFIED=false — it is NOT a device proof and NOT a rollback.
# =============================================================================
set -u

REPO="${REPO:-/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree}"
TOOL="$REPO/vendor/guardtalk/scripts/gt-rollback-to-stock.sh"
MANIFEST_LIVE="$REPO/vendor/guardtalk/scripts/gt-rollback-manifest.tsv"
READY_REPORTER="$REPO/scripts/gt-ready-devices.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/gt-rollback-verify.XXXXXX")"
KEEP="${KEEP:-0}"
if [ "$KEEP" = "1" ]; then
    echo "KEEP=1 — work dir preserved at $WORK"
else
    trap 'rm -rf "$WORK"' EXIT
fi

PASS=0; FAIL=0; HOLD=0
ok()   { echo "PASS  $*"; PASS=$((PASS + 1)); }
bad()  { echo "FAIL  $*"; FAIL=$((FAIL + 1)); }
hold() { echo "HOLD  $*"; HOLD=$((HOLD + 1)); }

[ -f "$TOOL" ] || { echo "FATAL: missing $TOOL" >&2; exit 1; }
[ -f "$MANIFEST_LIVE" ] || { echo "FATAL: missing $MANIFEST_LIVE" >&2; exit 1; }

echo "=== T-EXCISE-FLASH-ROLLBACK host harness ==="
echo "tool     : $TOOL"
echo "manifest : $MANIFEST_LIVE"
echo ""

# ---------------------------------------------------------------------------
# A. STATIC
# ---------------------------------------------------------------------------
echo "--- A. static ---"
if bash -n "$TOOL" 2>"$WORK/bashn.err"; then
    ok "gt-rollback-to-stock.sh: bash -n clean"
else
    bad "gt-rollback-to-stock.sh: bash -n failed"; sed 's/^/      /' "$WORK/bashn.err"
fi

for m in E-MANIFEST-MISSING E-DEVICE-UNKNOWN E-ARTIFACT-MISSING E-ARTIFACT-DANGLING-SYMLINK \
         E-ARTIFACT-SIZE E-ARTIFACT-HASH E-BUNDLE-UNPINNED E-COMMAND-UNRESOLVED \
         E-EXECUTE-NO-CONFIRM E-FIRMWARE-NOT-AUTHORISED E-EXECUTE-NO-FASTBOOT \
         E-EXECUTE-NO-DEVICE E-EXECUTE-WRONG-DEVICE E-EXECUTE-LOCKED E-EXECUTE-MULTI-DEVICE \
         E-DEVICE-RESIDUAL E-HOLD-NO-HASH E-GOOGLE-SHA8-MISMATCH; do
    if grep -q "ROLLBACK-FAIL-CLOSED: $m" "$TOOL" || grep -q -- "$m" "$TOOL"; then
        ok "fail-closed marker present: $m"
    else
        bad "fail-closed marker MISSING from tool: $m"
    fi
done

# Manifest shape: every field non-empty (read(1) with a tab-only IFS collapses
# runs of tabs, so an empty column would silently shift fields).
if awk -F'\t' '!/^#/ && NF{ if ($1==""||$2==""||$3==""||$4==""||$5==""||$6==""||$7=="") { print "EMPTY:" NR; bad=1 } } END{ exit bad?1:0 }' "$MANIFEST_LIVE" >/dev/null 2>&1; then
    ok "manifest: no empty fields (7 columns, non-collapsing)"
else
    bad "manifest: has empty fields — read(1) would collapse columns"
fi
_sha_bad="$(awk -F'\t' '!/^#/ && NF{ if ($6 !~ /^[0-9a-f]{64}$/) print NR }' "$MANIFEST_LIVE" | head -1)"
if [ -z "$_sha_bad" ]; then
    ok "manifest: every sha256 is 64 lowercase hex"
else
    bad "manifest: malformed sha256 at line $_sha_bad"
fi

# Device set must equal the canonical reporter's DEVICES block (no duplication,
# and drift is detected rather than absorbed).
MAN_DEVS="$(awk -F'\t' '!/^#/ && NF{ print $1 }' "$MANIFEST_LIVE" | awk '!s[$0]++' | sort)"
if [ -f "$READY_REPORTER" ]; then
    REP_DEVS="$(awk '/^DEVICES="/{f=1;next} f&&/^"$/{f=0} f{print}' "$READY_REPORTER" | cut -d'|' -f1 | sort)"
    if [ "$MAN_DEVS" = "$REP_DEVS" ]; then
        ok "manifest device set == gt-ready-devices.sh DEVICES ($(printf '%s\n' "$MAN_DEVS" | grep -c .) devices)"
    else
        bad "manifest device set != gt-ready-devices.sh DEVICES"
        diff <(printf '%s\n' "$MAN_DEVS") <(printf '%s\n' "$REP_DEVS") | sed 's/^/      /' || true
    fi
else
    hold "gt-ready-devices.sh not found — device-set cross-check skipped"
fi

_n_sf="$(awk -F'\t' '!/^#/ && $3=="stock-factory"{c++} END{print c+0}' "$MANIFEST_LIVE")"
if [ "$_n_sf" -ge 13 ]; then ok "manifest: $_n_sf stock-factory rows (>=13)"; else bad "manifest: only $_n_sf stock-factory rows (expected >=13)"; fi

echo ""

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------
DEVICES="$(printf '%s\n' "$MAN_DEVS" | grep .)"
LAGUNA="frankel blazer mustang rango"

# emit_manifest_for_root <root> <out>  — hash the fixture artifacts into a manifest.
emit_manifest_for_root() {
    _root="$1"; _out="$2"
    : > "$_out"
    for _d in $DEVICES; do
        _m="$(awk -F'\t' -v d="$_d" '!/^#/ && $1==d{print $2; exit}' "$MANIFEST_LIVE")"
        _zip="$(ls "$_root"/vendor/adevtool/dl/"$_d"-cp1a.*-factory-*.zip 2>/dev/null | head -1)"
        [ -n "$_zip" ] || continue
        _sha="$(sha256sum "$_zip" | awk '{print $1}')"
        _sz="$(stat -c %s "$_zip" 2>/dev/null || stat -f %z "$_zip")"
        _build="$(basename "$_zip" .zip | sed 's/-factory-[0-9a-f]\{8\}$//')"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_d" "$_m" "stock-factory" "$_build" "${_zip#"$_root"/}" "$_sha" "$_sz" >> "$_out"
    done
    for _d in $LAGUNA; do
        _m="$(awk -F'\t' -v d="$_d" '!/^#/ && $1==d{print $2; exit}' "$MANIFEST_LIVE")"
        for _f in "$_root"/releases/desktop-flash/"$_d"-rescue-boot/*.img; do
            [ -e "$_f" ] || continue
            _sha="$(sha256sum "$_f" | awk '{print $1}')"
            _sz="$(stat -c %s "$_f" 2>/dev/null || stat -f %z "$_f")"
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_d" "$_m" "unbrick-rescue" "rescue-chain" "${_f#"$_root"/}" "$_sha" "$_sz" >> "$_out"
        done
    done
}

# make_fixture <root> — tiny fake stock root with correctly-named (sha8) zips.
make_fixture() {
    _root="$1"
    mkdir -p "$_root/vendor/adevtool/dl" "$_root/releases/desktop-flash"
    for _d in $DEVICES; do
        _stage="$_root/vendor/adevtool/dl/$_d-cp1a.260505.005"
        mkdir -p "$_stage"
        printf '#!/bin/sh\nfastboot -w update image-%s-cp1a.260505.005.zip\n' "$_d" > "$_stage/flash-all.sh"
        printf 'stub inner image zip for %s\n' "$_d"                > "$_stage/image-$_d-cp1a.260505.005.zip"
        printf 'stub bootloader for %s\n' "$_d"                    > "$_stage/bootloader-$_d-test.img"
        printf 'stub radio for %s\n' "$_d"                         > "$_stage/radio-$_d-test.img"
        _tmp="$_root/.tmp-$_d.zip"
        ( cd "$_root/vendor/adevtool/dl" && zip -qr "$_tmp" "$_d-cp1a.260505.005" )
        rm -rf "$_stage"
        _sha="$(sha256sum "$_tmp" | awk '{print $1}')"
        mv "$_tmp" "$_root/vendor/adevtool/dl/$_d-cp1a.260505.005-factory-${_sha:0:8}.zip"
    done
    for _d in $LAGUNA; do
        _rd="$_root/releases/desktop-flash/$_d-rescue-boot"
        mkdir -p "$_rd"
        for _i in boot init_boot vendor_boot vendor_kernel_boot dtbo pvmfw vbmeta; do
            printf 'stub rescue %s %s\n' "$_d" "$_i" > "$_rd/$_i.img"
        done
    done
}

FAKE_ROOT="$WORK/fixture"
FAKE_MAN="$WORK/fixture-manifest.tsv"
make_fixture "$FAKE_ROOT"
emit_manifest_for_root "$FAKE_ROOT" "$FAKE_MAN"

export GT_ROLLBACK_ROOT="$FAKE_ROOT"
export GT_ROLLBACK_MANIFEST="$FAKE_MAN"

run_ok() { # run_ok <label> <cmd...>
    _label="$1"; shift
    _out="$("$@" 2>&1)"; _rc=$?
    if [ "$_rc" -eq 0 ]; then ok "$_label"; else bad "$_label — expected exit 0, got $_rc"; printf '%s\n' "$_out" | sed 's/^/      /'; fi
}
run_fc() { # run_fc <label> <marker> <cmd...>
    _label="$1"; _marker="$2"; shift 2
    _out="$("$@" 2>&1)"; _rc=$?
    if [ "$_rc" -eq 0 ]; then
        bad "$_label — expected fail-closed non-zero exit, got 0"
    elif printf '%s' "$_out" | grep -q -- "ROLLBACK-FAIL-CLOSED: $_marker"; then
        ok "$_label (exit=$_rc, $_marker)"
    else
        bad "$_label — marker $_marker not found (exit=$_rc)"
        printf '%s\n' "$_out" | tail -12 | sed 's/^/      /'
    fi
}
run_fc_any() { # run_fc_any <label> <grep-pattern> <cmd...>  (non-zero exit + pattern anywhere)
    _label="$1"; _pat="$2"; shift 2
    _out="$("$@" 2>&1)"; _rc=$?
    if [ "$_rc" -eq 0 ]; then
        bad "$_label — expected non-zero exit, got 0"
    elif printf '%s' "$_out" | grep -q -e "$_pat"; then
        ok "$_label (exit=$_rc)"
    else
        bad "$_label — pattern not found (exit=$_rc)"; printf '%s\n' "$_out" | tail -12 | sed 's/^/      /'
    fi
}

# ---------------------------------------------------------------------------
# B. FIXTURE happy path (non-vacuity: the path CAN pass)
# ---------------------------------------------------------------------------
echo "--- B. fixture (happy path; proves the suite is not vacuous) ---"
run_ok "fixture: plan exits 0 across all devices" bash "$TOOL" plan
run_ok "fixture: attest exits 0 (all pins match)"  bash "$TOOL" attest
_ok_lines="$(GT_ROLLBACK_ROOT="$FAKE_ROOT" GT_ROLLBACK_MANIFEST="$FAKE_MAN" bash "$TOOL" plan 2>/dev/null | grep -c '^\[OK\]')"
if [ "$_ok_lines" = "$(printf '%s\n' "$DEVICES" | grep -c .)" ]; then
    ok "fixture: plan reports [OK] for every device ($_ok_lines)"
else
    bad "fixture: plan [OK] count $_ok_lines != device count"
fi
run_ok "fixture: unbrick of a laguna device exits 0" bash "$TOOL" unbrick --device blazer
run_ok "fixture: unbrick of a non-laguna device exits 0" bash "$TOOL" unbrick --device shiba
echo ""

# ---------------------------------------------------------------------------
# D. FIXTURE injections (each declared failure condition must STOP)
# ---------------------------------------------------------------------------
echo "--- D. injections (fail-closed, non-vacuous) ---"

# D1 manifest missing
run_fc "D1  manifest missing"            E-MANIFEST-MISSING \
    env GT_ROLLBACK_MANIFEST="$WORK/does-not-exist.tsv" bash "$TOOL" plan

# D2 unknown device
run_fc "D2  unknown device"              E-DEVICE-UNKNOWN \
    bash "$TOOL" plan --device no-such-device

# D3 artifact missing
D3="$WORK/d3"; cp -a "$FAKE_ROOT" "$D3"; rm -f "$D3"/vendor/adevtool/dl/shiba-cp1a.*-factory-*.zip
run_fc "D3  factory artifact missing"    E-ARTIFACT-MISSING \
    env GT_ROLLBACK_ROOT="$D3" bash "$TOOL" plan --device shiba

# D4 dangling symlink
D4="$WORK/d4"; cp -a "$FAKE_ROOT" "$D4"; rm -f "$D4"/vendor/adevtool/dl/akita-cp1a.*-factory-*.zip
ln -s "$WORK/no-such-target" "$D4/vendor/adevtool/dl/akita-cp1a.260505.005-factory-deadbeef.zip"
# point the manifest pin at the (dangling) symlink name
awk -F'\t' 'BEGIN{OFS="\t"} $1=="akita" && $3=="stock-factory" { $5="vendor/adevtool/dl/akita-cp1a.260505.005-factory-deadbeef.zip" } {print}' \
    "$FAKE_MAN" > "$WORK/d4-man.tsv"
run_fc "D4  dangling symlink artifact"   E-ARTIFACT-DANGLING-SYMLINK \
    env GT_ROLLBACK_ROOT="$D4" GT_ROLLBACK_MANIFEST="$WORK/d4-man.tsv" bash "$TOOL" plan --device akita

# D5 size mismatch (truncate in place)
D5="$WORK/d5"; cp -a "$FAKE_ROOT" "$D5"
_z5="$(ls "$D5"/vendor/adevtool/dl/tegu-cp1a.*-factory-*.zip | head -1)"
_sz5="$(stat -c %s "$_z5" 2>/dev/null || stat -f %z "$_z5")"
head -c $(( _sz5 - 1 )) "$_z5" > "$_z5.tmp" && mv "$_z5.tmp" "$_z5"
run_fc "D5  artifact size mismatch"      E-ARTIFACT-SIZE \
    env GT_ROLLBACK_ROOT="$D5" bash "$TOOL" plan --device tegu

# D6 hash mismatch (same size, flipped byte)
D6="$WORK/d6"; cp -a "$FAKE_ROOT" "$D6"
_z6="$(ls "$D6"/vendor/adevtool/dl/comet-cp1a.*-factory-*.zip | head -1)"
printf 'X' | dd of="$_z6" bs=1 seek=20 conv=notrunc status=none
run_fc "D6  artifact hash mismatch"      E-ARTIFACT-HASH \
    env GT_ROLLBACK_ROOT="$D6" bash "$TOOL" plan --device comet

# D7 unpinned artifact in a rescue bundle
D7="$WORK/d7"; cp -a "$FAKE_ROOT" "$D7"
printf 'smuggled\n' > "$D7/releases/desktop-flash/blazer-rescue-boot/extra.img"
run_fc "D7  unpinned rescue member"      E-BUNDLE-UNPINNED \
    env GT_ROLLBACK_ROOT="$D7" bash "$TOOL" plan --device blazer

# D8 command unresolved: zip resolves+hashes (re-pinned) but lacks flash-all.sh
D8="$WORK/d8"; cp -a "$FAKE_ROOT" "$D8"
_s8="$(ls "$D8"/vendor/adevtool/dl/mustang-cp1a.*-factory-*.zip | head -1)"
rm -f "$_s8"
( cd "$D8/vendor/adevtool/dl" && mkdir -p mustang-cp1a.260505.005 && printf 'x\n' > mustang-cp1a.260505.005/image-mustang-cp1a.260505.005.zip && zip -qr "$WORK/d8.zip" mustang-cp1a.260505.005 && rm -rf mustang-cp1a.260505.005 )
_h8="$(sha256sum "$WORK/d8.zip" | awk '{print $1}')"
mv "$WORK/d8.zip" "$D8/vendor/adevtool/dl/mustang-cp1a.260505.005-factory-${_h8:0:8}.zip"
emit_manifest_for_root "$D8" "$WORK/d8-man.tsv"
run_fc "D8  factory zip commands unresolved" E-COMMAND-UNRESOLVED \
    env GT_ROLLBACK_ROOT="$D8" GT_ROLLBACK_MANIFEST="$WORK/d8-man.tsv" bash "$TOOL" plan --device mustang

# D9 pinned sha does not match Google's filename sha8
D9="$WORK/d9"; cp -a "$FAKE_ROOT" "$D9"
_z9src="$(ls "$D9"/vendor/adevtool/dl/frankel-cp1a.*-factory-*.zip | head -1)"
cp "$_z9src" "$D9/vendor/adevtool/dl/frankel-cp1a.260505.005-factory-00000000.zip"
emit_manifest_for_root "$D9" "$WORK/d9-man.tsv"   # re-pin (hash ok) but keep wrong suffix name
rm -f "$_z9src"
run_fc "D9  google sha8 prefix mismatch" E-GOOGLE-SHA8-MISMATCH \
    env GT_ROLLBACK_ROOT="$D9" GT_ROLLBACK_MANIFEST="$WORK/d9-man.tsv" bash "$TOOL" plan --device frankel

# D10 execute without operator confirmation
run_fc "D10 execute without --i-understand" E-EXECUTE-NO-CONFIRM \
    bash "$TOOL" execute --device shiba

# D11 firmware flash not authorised
run_fc "D11 firmware flash not authorised" E-FIRMWARE-NOT-AUTHORISED \
    bash "$TOOL" execute --device shiba --i-understand-this-erases-the-device --flash-firmware

# D12 fastboot absent
D12="$WORK/d12"; cp -a "$FAKE_ROOT" "$D12"
run_fc "D12 fastboot not found"  E-EXECUTE-NO-FASTBOOT \
    env GT_ROLLBACK_FASTBOOT="$WORK/no-fastboot" GT_ROLLBACK_ROOT="$D12" \
    bash "$TOOL" execute --device shiba --i-understand-this-erases-the-device

# Stub fastboot for the on-device guard injections.
STUBDIR="$WORK/stubs"; mkdir -p "$STUBDIR"
cat > "$STUBDIR/fastboot" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --version) echo "fastboot version 35.0.2-12345678"; exit 0 ;;
  devices)   printf '%s\n' "${FB_DEVICES-54111FDAS000GN	fastboot}"; exit 0 ;;
  getvar)
     case "$2" in
       product)  echo "product: ${FB_PRODUCT-shiba}" ;;
       unlocked) echo "unlocked: ${FB_UNLOCKED-yes}" ;;
       *)        echo "getvar: ${2:-}"; : ;;
     esac; exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$STUBDIR/fastboot"

D13="$WORK/d13"; cp -a "$FAKE_ROOT" "$D13"
run_fc "D13 no device attached"   E-EXECUTE-NO-DEVICE \
    env GT_ROLLBACK_FASTBOOT="$STUBDIR/fastboot" GT_ROLLBACK_ROOT="$D13" FB_DEVICES="" \
    bash "$TOOL" execute --device shiba --i-understand-this-erases-the-device

run_fc "D14 two devices attached" E-EXECUTE-MULTI-DEVICE \
    env GT_ROLLBACK_FASTBOOT="$STUBDIR/fastboot" GT_ROLLBACK_ROOT="$D13" \
    FB_DEVICES=$'A\tfastboot\nB\tfastboot' \
    bash "$TOOL" execute --device shiba --i-understand-this-erases-the-device

run_fc "D15 wrong device attached" E-EXECUTE-WRONG-DEVICE \
    env GT_ROLLBACK_FASTBOOT="$STUBDIR/fastboot" GT_ROLLBACK_ROOT="$D13" FB_PRODUCT="akita" \
    bash "$TOOL" execute --device shiba --i-understand-this-erases-the-device

run_fc "D16 device locked"        E-EXECUTE-LOCKED \
    env GT_ROLLBACK_FASTBOOT="$STUBDIR/fastboot" GT_ROLLBACK_ROOT="$D13" FB_UNLOCKED="no" \
    bash "$TOOL" execute --device shiba --i-understand-this-erases-the-device

# D17 POSITIVE control: correct stub + echo => guards PASS (suite is not always-fail)
D17="$WORK/d17"; cp -a "$FAKE_ROOT" "$D17"
_out17="$(GT_ROLLBACK_FASTBOOT="$STUBDIR/fastboot" GT_ROLLBACK_ROOT="$D17" \
          GT_ROLLBACK_EXECUTE_ECHO=1 FB_PRODUCT="shiba" FB_UNLOCKED="yes" \
          bash "$TOOL" execute --device shiba --i-understand-this-erases-the-device 2>&1)"; _rc17=$?
if [ "$_rc17" -eq 0 ] && printf '%s' "$_out17" | grep -q 'NOTHING FLASHED'; then
    ok "D17 execute guards PASS on a valid stub (echo, nothing flashed)"
else
    bad "D17 execute guards did not reach the echo happy path (exit=$_rc17)"; printf '%s\n' "$_out17" | tail -12 | sed 's/^/      /'
fi
if printf '%s' "$_out17" | grep -qE 'fastboot -w update'; then
    ok "D17 exact restore command emitted (fastboot -w update image-...) "
else
    bad "D17 restore command not emitted"
fi
echo ""

# ---------------------------------------------------------------------------
# C. LIVE tree
# ---------------------------------------------------------------------------
echo "--- C. live tree ---"
# Drop the fixture overrides so the tool resolves the real workspace root and the
# shipped manifest.
unset GT_ROLLBACK_ROOT GT_ROLLBACK_MANIFEST
# C1 structural walk on the real artifacts: --no-hash => HOLD, and MUST exit
#    non-zero (a skipped hash can never be a PASS).
_live="$(bash "$TOOL" plan --no-hash 2>&1)"; _rc_live=$?
_n_hold="$(printf '%s\n' "$_live" | grep -c '^\[HOLD\]')"
if [ "$_rc_live" -ne 0 ]; then ok "live plan --no-hash exits non-zero (HOLD is never PASS, exit=$_rc_live)"; else bad "live plan --no-hash exited 0 — a skipped hash leaked a PASS"; fi
if [ "$_n_hold" = "$(printf '%s\n' "$DEVICES" | grep -c .)" ]; then ok "live plan --no-hash: $_n_hold devices structurally resolve (existence+size+commands)"; else bad "live plan --no-hash: [HOLD] count $_n_hold != device count"; fi

# C2 real sha256 of one standard + one laguna device vs the live pin.
run_ok "live attest: shiba (standard) sha256 matches pin" bash "$TOOL" attest --device shiba
run_ok "live attest: rango (laguna, +rescue) sha256 matches pin" bash "$TOOL" attest --device rango

# C3 full 13-device hash attestation is opt-in (multi-GB read); otherwise HOLD.
if [ "${GT_ROLLBACK_FULL_HASH:-0}" = "1" ]; then
    run_ok "live attest: ALL 13 devices (full multi-GB hash)" bash "$TOOL" attest
else
    hold "live attest: all 13 (multi-GB) not run — set GT_ROLLBACK_FULL_HASH=1 (recorded separately in evidence)"
fi
echo ""

echo "=== harness summary: PASS=$PASS FAIL=$FAIL HOLD=$HOLD ==="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
