#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B5-BOOTZIP (pair of F-REMEDIATE-B5-BOOTZIP
# item 22 residual). Do not trust Frontend/Architect zip dumps.
# Host static only. Do not crop or rewrite the PNG or zip. QA scripts only.
# Dark zip 1080×2400 is OK (not PRODUCT_COPY). Empty adb → on-device boot HOLD.
# Brand-sweep EXPECTED_MD5 may still pin the old 1080 zip — HOLD, never FAIL
# the product zip for a stale sweep hash. Do not lift PASS HOLD.
# Do not overwrite verify_remediate_b5_branding_host.sh.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b5_bootzip_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

BOOT_PNG="vendor/guardtalk/branding/bootanimation/logo_1008x2244.png"
BOOT_ZIP="vendor/guardtalk/branding/bootanimation/bootanimation.zip"
DARK_ZIP="vendor/guardtalk/branding/bootanimation/bootanimation-dark.zip"
KIT_ZIP="vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip"
KIT_PNG="vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/logo_1008x2244.png"
KIT_DESC="vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/desc.txt"
THEME_MK="vendor/guardtalk/branding/guardtalk-theme.mk"
EMU_MK="vendor/guardtalk/device/emu64a/guardtalk-emu-layer.mk"
SWEEP="vendor/guardtalk/docs/qa/verify_brand_sweep_static.sh"
BRANDING_QA="vendor/guardtalk/docs/qa/verify_remediate_b5_branding_host.sh"
STALE_SWEEP_MD5="7ba676c5704c6e6ab962fb34cc6590ef"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

echo "=== Q-REMEDIATE-B5-BOOTZIP independent rematch (item 22 residual) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo "M_BUILD=not started"
echo "ZIP_REWRITE=not started (QA must not rewrite product zip/PNG)"
echo

echo "--- required files ---"
require_file "$BOOT_PNG"
require_file "$BOOT_ZIP"
require_file "$KIT_ZIP"
require_file "$KIT_PNG"
require_file "$KIT_DESC"
require_file "$DARK_ZIP"
require_file "$THEME_MK"
require_file "$EMU_MK"
require_file "$SWEEP"
require_file "$BRANDING_QA"

echo
echo "--- branding QA script must remain (this card must not overwrite it) ---"
if [[ -f "$BRANDING_QA" ]] && rg -q 'bootanimation.zip desc.txt still 1080' "$BRANDING_QA"; then
  pass "verify_remediate_b5_branding_host.sh still HOLDs 1080 zip (not overwritten)"
else
  fail "verify_remediate_b5_branding_host.sh missing or no longer HOLDs 1080 zip"
fi

echo
echo "--- file(1) source PNG (libmagic; not a Frontend dump) ---"
if [[ -f "$BOOT_PNG" ]]; then
  FILE_OUT="$(file -b "$BOOT_PNG")"
  echo "file: $FILE_OUT"
  if echo "$FILE_OUT" | grep -q "1008 x 2244"; then
    pass "file(1) reports 1008 x 2244"
  else
    fail "file(1) did not report 1008 x 2244: $FILE_OUT"
  fi
fi

echo
echo "--- unzip -v product (Method Stored) ---"
if [[ -f "$BOOT_ZIP" ]]; then
  unzip -v "$BOOT_ZIP"
  if unzip -v "$BOOT_ZIP" | grep -E 'Defl|Deflated' >/dev/null; then
    fail "product zip has Deflated members (AOSP bootanimation requires STORED)"
  else
    pass "unzip -v product: no Deflated members"
  fi
fi

echo
echo "--- PRODUCT_COPY wiring (source only; do not m) ---"
if rg -qF '$(guardtalk_bootanim):$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip' "$THEME_MK" \
  && rg -qF 'guardtalk_bootanim_dir := vendor/guardtalk/branding/bootanimation' "$THEME_MK"; then
  pass "guardtalk-theme.mk PRODUCT_COPY product zip (komodo path)"
else
  fail "guardtalk-theme.mk missing product-zip PRODUCT_COPY"
fi
if rg -q 'bootanimation-dark\.zip' "$THEME_MK" && rg -q '_gt_filtered_bootanim_copy_files' "$THEME_MK"; then
  pass "guardtalk-theme.mk dark-zip filter present (dark zip not PRODUCT_COPY)"
else
  fail "guardtalk-theme.mk dark-zip filter missing"
fi
if rg -qF 'GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip:$(TARGET_COPY_OUT_PRODUCT)/media/bootanimation.zip' "$EMU_MK"; then
  pass "emu64a PRODUCT_COPY brand-kit bootanimation.zip"
else
  fail "emu64a missing brand-kit bootanimation PRODUCT_COPY"
fi

echo
echo "--- python zipfile STORED + IHDR + byte-identity (stdlib; no PIL) ---"
set +e
python3 - "$ROOT" <<'PY'
import hashlib
import re
import struct
import sys
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
fail = 0
pass_n = 0
hold_n = 0
ZIP_STORED = 0
STALE_SWEEP = "7ba676c5704c6e6ab962fb34cc6590ef"


def out(kind, msg):
    global fail, pass_n, hold_n
    print(f"{kind}: {msg}")
    if kind == "PASS":
        pass_n += 1
    elif kind == "FAIL":
        fail = 1
    else:
        hold_n += 1


def png_ihdr(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not PNG")
    length = struct.unpack(">I", data[8:12])[0]
    ctype = data[12:16]
    if ctype != b"IHDR" or length < 13:
        raise ValueError(f"first chunk {ctype!r} len={length}")
    w, h, bit, color, comp, filt, inter = struct.unpack(">IIBBBBB", data[16:29])
    return w, h, bit, color


logo_path = root / "vendor/guardtalk/branding/bootanimation/logo_1008x2244.png"
logo = logo_path.read_bytes()
logo_md5 = hashlib.md5(logo).hexdigest()
print(f"LOGO_MD5 {logo_md5} len={len(logo)}")
try:
    lw, lh, lbit, lcolor = png_ihdr(logo)
except Exception as e:
    out("FAIL", f"logo IHDR: {e}")
    print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
    sys.exit(1)
print(f"LOGO_IHDR w={lw} h={lh} bit={lbit} color={lcolor}")
if (lw, lh) == (1008, 2244):
    out("PASS", "logo IHDR exactly 1008×2244")
else:
    out("FAIL", f"logo IHDR {lw}×{lh} (expected 1008×2244)")

kit_logo = root / (
    "vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/"
    "01_boot_animation/logo_1008x2244.png"
)
if kit_logo.is_file() and kit_logo.read_bytes() == logo:
    out("PASS", "brand-kit logo PNG bytes match product logo")
else:
    out("FAIL", "brand-kit logo PNG bytes differ or missing")


def rematch_zip(label, zpath, expect_wh, expect_eq_logo):
    zpath = Path(zpath)
    if not zpath.is_file():
        out("FAIL", f"{label} zip missing: {zpath}")
        return None
    raw = zpath.read_bytes()
    zmd5 = hashlib.md5(raw).hexdigest()
    print(f"{label}_ZIP_MD5 {zmd5} len={len(raw)}")
    with zipfile.ZipFile(zpath) as zf:
        names = zf.namelist()
        print(f"{label}_NAMES {names if expect_eq_logo else names[:8]} count={len(names)}")
        not_stored = [
            f"{info.filename}:{info.compress_type}"
            for info in zf.infolist()
            if info.compress_type != ZIP_STORED
        ]
        if not_stored:
            out(
                "FAIL",
                f"{label} non-STORED members {not_stored} (expected ZIP_STORED=0)",
            )
        else:
            out("PASS", f"{label} all {len(zf.infolist())} members STORED")
        if "desc.txt" not in names:
            out("FAIL", f"{label} zip missing desc.txt")
            return zmd5
        desc = zf.read("desc.txt").decode("utf-8", "replace")
        first = desc.splitlines()[0] if desc else ""
        print(f"{label}_DESC_FIRST {first!r}")
        want = f"{expect_wh[0]} {expect_wh[1]} 24"
        if first == want:
            out("PASS", f"{label} desc.txt first line {want!r}")
        else:
            out("FAIL", f"{label} desc.txt first line {first!r} (expected {want!r})")
        pngs = [n for n in names if n.lower().endswith(".png")]
        if expect_eq_logo:
            if pngs == ["part0/000.png", "part1/000.png"]:
                out("PASS", f"{label} zip has part0/000.png and part1/000.png only")
            else:
                out("FAIL", f"{label} unexpected PNG members: {pngs}")
            targets = pngs
        else:
            print(f"{label}_PNG_COUNT {len(pngs)}")
            targets = pngs[:1]
        bad_ihdr = []
        logo_hits = []
        for n in pngs:
            data = zf.read(n)
            try:
                w, h, bit, color = png_ihdr(data)
            except Exception as e:
                out("FAIL", f"{label} {n} IHDR: {e}")
                continue
            if n in targets:
                print(f"{label}_IHDR {n} w={w} h={h} bit={bit} color={color}")
            if (w, h) != expect_wh:
                bad_ihdr.append(f"{n}:{w}x{h}")
            if data == logo:
                logo_hits.append(n)
        if bad_ihdr:
            out("FAIL", f"{label} IHDR not {expect_wh[0]}×{expect_wh[1]}: {bad_ihdr}")
        else:
            out(
                "PASS",
                f"{label} {len(pngs)} PNG IHDR {expect_wh[0]}×{expect_wh[1]}",
            )
        if expect_eq_logo:
            for n in pngs:
                if n in logo_hits:
                    out("PASS", f"{label} {n} bytes identical to logo_1008x2244.png")
                else:
                    out("FAIL", f"{label} {n} bytes differ from logo_1008x2244.png")
        else:
            if logo_hits:
                out("FAIL", f"{label} unexpectedly contains 1008 logo frames: {logo_hits}")
            else:
                out("PASS", f"{label} frames are not the 1008 logo (1080 dark zip OK)")
    return zmd5


prod_md5 = rematch_zip(
    "product",
    root / "vendor/guardtalk/branding/bootanimation/bootanimation.zip",
    (1008, 2244),
    True,
)
kit_md5 = rematch_zip(
    "kit",
    root
    / "vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip",
    (1008, 2244),
    True,
)
if prod_md5 and kit_md5 and prod_md5 == kit_md5:
    out("PASS", "product zip bytes identical to brand-kit copy")
elif prod_md5 and kit_md5:
    out("FAIL", f"product zip md5 {prod_md5} != kit zip md5 {kit_md5}")

kit_desc = root / (
    "vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/desc.txt"
)
if kit_desc.is_file():
    first = kit_desc.read_text(encoding="utf-8", errors="replace").splitlines()[0]
    if first == "1008 2244 24":
        out("PASS", "brand-kit desc.txt file first line '1008 2244 24'")
    else:
        out("FAIL", f"brand-kit desc.txt file first line {first!r}")
else:
    out("FAIL", "brand-kit desc.txt file missing")

dark_md5 = rematch_zip(
    "dark",
    root / "vendor/guardtalk/branding/bootanimation/bootanimation-dark.zip",
    (1080, 2400),
    False,
)
if dark_md5 == STALE_SWEEP:
    out("PASS", "dark zip md5 still 7ba676c5704c6e6ab962fb34cc6590ef (untouched)")
elif dark_md5:
    out("HOLD", f"dark zip md5 {dark_md5} (expected untouched 7ba676c5…)")

sweep = root / "vendor/guardtalk/docs/qa/verify_brand_sweep_static.sh"
text = sweep.read_text(encoding="utf-8", errors="replace") if sweep.is_file() else ""
m = re.search(r'EXPECTED_MD5="([0-9a-f]+)"', text)
pinned = m.group(1) if m else None
print(f"SWEEP_EXPECTED_MD5 {pinned}")
print(f"PRODUCT_ZIP_MD5 {prod_md5}")
if pinned and prod_md5 and pinned == prod_md5:
    out("PASS", "brand-sweep EXPECTED_MD5 matches product zip")
elif pinned == STALE_SWEEP:
    out(
        "HOLD",
        "brand-sweep EXPECTED_MD5 still pins old 1080 zip / dark zip "
        f"{STALE_SWEEP}; not a product FAIL",
    )
elif pinned and prod_md5:
    out(
        "HOLD",
        f"brand-sweep EXPECTED_MD5={pinned} != product {prod_md5}; not a product FAIL",
    )
else:
    out("HOLD", "brand-sweep EXPECTED_MD5 pin not parsed; not a product FAIL")

print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
sys.exit(1 if fail else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -eq 0 ]]; then
  pass "python zip rematch exit 0"
else
  fail "python zip rematch exit $PY_RC"
fi

echo
echo "--- brand-sweep script: stale pin must HOLD not FAIL product ---"
if rg -n 'EXPECTED_MD5=' "$SWEEP"; then
  if rg -q 'hold "bootanimation.zip md5=' "$SWEEP" || rg -q 'HOLD.*EXPECTED_MD5' "$SWEEP"; then
    pass "verify_brand_sweep_static.sh HOLDs stale bootanimation.md5 (does not FAIL product)"
  elif rg -q 'fail "bootanimation.zip md5 mismatch' "$SWEEP"; then
    fail "verify_brand_sweep_static.sh still FAILs product zip on stale EXPECTED_MD5"
  else
    hold "verify_brand_sweep_static.sh md5 mismatch path not classified"
  fi
else
  fail "verify_brand_sweep_static.sh missing EXPECTED_MD5"
fi

echo
echo "--- secrets (pem/pk8/.env under branding) ---"
SECRETS="$(find vendor/guardtalk/branding \
  \( -name '*.pem' -o -name '*.pk8' -o -name '.env' -o -name '*.env' \) -print 2>/dev/null || true)"
if [[ -z "$SECRETS" ]]; then
  pass "no pem/pk8/.env under branding"
else
  fail "NEGATIVE HIT: secret-like files: $SECRETS"
fi

echo
echo "--- stale out/ product media (no m this card) ---"
OUT_HITS=0
for prod in komodo tokay akita emu64a; do
  outz="out/target/product/${prod}/product/media/bootanimation.zip"
  if [[ -f "$outz" ]]; then
    OUT_HITS=1
    om=$(md5sum "$outz" | awk '{print $1}')
    src=$(md5sum "$BOOT_ZIP" | awk '{print $1}')
    echo "out/${prod} md5=$om source=$src"
    if [[ "$om" == "$src" ]]; then
      hold "out/${prod} product/media/bootanimation.zip matches source (still not device-fixed; did not m this card)"
    else
      hold "out/${prod} product/media/bootanimation.zip md5=$om != source $src (stale out; not product FAIL)"
    fi
  fi
done
if [[ "$OUT_HITS" -eq 0 ]]; then
  hold "out/*/product/media/bootanimation.zip absent (no m this card)"
fi

echo
echo "--- adb (device HOLD if empty) ---"
ADB_OUT="$(adb devices -l 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; on-device boot not device-fixed; do not lift PASS HOLD"
else
  hold "adb devices -l empty / no komodo 54111FDAS000GN — on-device boot HOLD, never device-fixed"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
echo "M_BUILD=not started"
exit "$FAIL"
