#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B5-BRANDING (pair of F-REMEDIATE-B5-BRANDING
# items 22, 23). Do not trust Frontend/Architect PNG dumps.
# Host static only. bootanimation.zip 1080×2400 is HOLD, never product FAIL.
# Empty adb → Welcome + boot HOLD. Not device-fixed. Do not lift PASS HOLD.
# No product edits. No USB GO. No wipe. No commit. Do not rebuild the zip.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b5_branding_host.sh
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
BOOT_KIT="vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/logo_1008x2244.png"
BOOT_ZIP="vendor/guardtalk/branding/bootanimation/bootanimation.zip"
SUW_PNG="vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/res/drawable-nodpi/guardtalk_welcome_square.png"
SUW_KIT="vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/07_setup_wizard/guardtalk_welcome_square_transparent.png"
SUW_XML="vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/res/drawable/guardtalk_welcome_square.xml"
SUW_MAN="vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/AndroidManifest.xml"
SUW_BP="vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/Android.bp"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

echo "=== Q-REMEDIATE-B5-BRANDING independent rematch (items 22, 23) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "USB_GO=not started"
echo "ZIP_REBUILD=not started (USERBUILD not delayed)"
echo

echo "--- required files ---"
require_file "$BOOT_PNG"
require_file "$SUW_PNG"
require_file "$SUW_MAN"
require_file "$SUW_BP"
require_file "$BOOT_ZIP"
if [[ -f "$BOOT_KIT" ]]; then
  pass "present brand-kit boot copy: $BOOT_KIT"
else
  fail "missing brand-kit boot copy: $BOOT_KIT"
fi
if [[ -f "$SUW_KIT" ]]; then
  pass "present brand-kit SUW copy: $SUW_KIT"
else
  fail "missing brand-kit SUW copy: $SUW_KIT"
fi

echo
echo "--- item 22 file(1) IHDR (libmagic; second decoder) ---"
if [[ -f "$BOOT_PNG" ]]; then
  FILE_OUT="$(file -b "$BOOT_PNG")"
  echo "file: $FILE_OUT"
  if echo "$FILE_OUT" | grep -q "1008 x 2244"; then
    pass "file(1) reports 1008 x 2244"
  else
    fail "file(1) did not report 1008 x 2244: $FILE_OUT"
  fi
  if echo "$FILE_OUT" | grep -qi "PNG"; then
    pass "file(1) reports PNG"
  else
    fail "file(1) did not report PNG: $FILE_OUT"
  fi
fi

echo
echo "--- item 23 file(1) overlay PNG ---"
if [[ -f "$SUW_PNG" ]]; then
  SUW_FILE_OUT="$(file -b "$SUW_PNG")"
  echo "file: $SUW_FILE_OUT"
  if echo "$SUW_FILE_OUT" | grep -q "1024 x 1024"; then
    pass "file(1) reports 1024 x 1024"
  else
    fail "file(1) did not report 1024 x 1024: $SUW_FILE_OUT"
  fi
  if echo "$SUW_FILE_OUT" | grep -qi "RGBA"; then
    pass "file(1) reports RGBA"
  else
    fail "file(1) did not report RGBA: $SUW_FILE_OUT"
  fi
fi

echo
echo "--- item 23 XML placeholder ABSENT ---"
if [[ -e "$SUW_XML" ]]; then
  fail "NEGATIVE HIT: $SUW_XML still present"
else
  pass "res/drawable/guardtalk_welcome_square.xml ABSENT"
fi
if [[ -d "vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/res/drawable" ]]; then
  XML_LEFT="$(find vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/res/drawable -maxdepth 1 -type f -name '*.xml' -print || true)"
  if [[ -n "$XML_LEFT" ]]; then
    fail "NEGATIVE HIT: leftover drawable XML: $XML_LEFT"
  else
    pass "overlay res/drawable has no XML files"
  fi
fi

echo
echo "--- overlay package ---"
if [[ -f "$SUW_MAN" ]] && rg -qF 'package="com.guardtalk.overlay.setupwizard"' "$SUW_MAN"; then
  pass "AndroidManifest package=com.guardtalk.overlay.setupwizard"
else
  fail "AndroidManifest missing package=com.guardtalk.overlay.setupwizard"
fi
if [[ -f "$SUW_MAN" ]] && rg -qF 'android:targetPackage="app.grapheneos.setupwizard"' "$SUW_MAN"; then
  pass "overlay targets app.grapheneos.setupwizard"
else
  fail "overlay targetPackage is not app.grapheneos.setupwizard"
fi

echo
echo "--- python IHDR + luma-sum>80 bbox + SUW RGBA corners (zlib decoder) ---"
set +e
python3 - "$ROOT" <<'PY'
import struct
import sys
import zipfile
import zlib
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


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def decode_png(path):
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not png: {path}")
    pos = 8
    ihdr = None
    idat = []
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        ctype = data[pos + 4 : pos + 8]
        cdata = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            w, h, bit, color, comp, filt, inter = struct.unpack(">IIBBBBB", cdata)
            ihdr = {
                "w": w,
                "h": h,
                "bit": bit,
                "color": color,
                "comp": comp,
                "filt": filt,
                "inter": inter,
            }
        elif ctype == b"IDAT":
            idat.append(cdata)
        elif ctype == b"IEND":
            break
    if ihdr is None:
        raise ValueError("no IHDR")
    if ihdr["bit"] != 8 or ihdr["inter"] != 0 or ihdr["comp"] != 0:
        raise ValueError(f"unsupported ihdr {ihdr}")
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[ihdr["color"]]
    raw = zlib.decompress(b"".join(idat))
    stride = ihdr["w"] * channels
    rows = []
    i = 0
    prev = bytearray(stride)
    for _y in range(ihdr["h"]):
        ftype = raw[i]
        i += 1
        scan = bytearray(raw[i : i + stride])
        i += stride
        if ftype == 0:
            pass
        elif ftype == 1:
            for x in range(stride):
                left = scan[x - channels] if x >= channels else 0
                scan[x] = (scan[x] + left) & 255
        elif ftype == 2:
            for x in range(stride):
                scan[x] = (scan[x] + prev[x]) & 255
        elif ftype == 3:
            for x in range(stride):
                left = scan[x - channels] if x >= channels else 0
                scan[x] = (scan[x] + ((left + prev[x]) // 2)) & 255
        elif ftype == 4:
            for x in range(stride):
                left = scan[x - channels] if x >= channels else 0
                up = prev[x]
                ul = prev[x - channels] if x >= channels else 0
                scan[x] = (scan[x] + paeth(left, up, ul)) & 255
        else:
            raise ValueError(f"bad filter {ftype}")
        rows.append(bytes(scan))
        prev = scan
    return ihdr, rows, channels


def pix(rows, ch, x, y):
    row = rows[y]
    o = x * ch
    return tuple(row[o : o + ch])


def bbox_rgb_sum(ihdr, rows, ch, thresh):
    w, h = ihdr["w"], ihdr["h"]
    minx, miny, maxx, maxy = w, h, -1, -1
    n = 0
    for y, row in enumerate(rows):
        for x in range(w):
            o = x * ch
            s = row[o] + row[o + 1] + row[o + 2]
            if s > thresh:
                n += 1
                if x < minx:
                    minx = x
                if x > maxx:
                    maxx = x
                if y < miny:
                    miny = y
                if y > maxy:
                    maxy = y
    if maxx < 0:
        return None, 0
    return (minx, miny, maxx, maxy), n


boot = root / "vendor/guardtalk/branding/bootanimation/logo_1008x2244.png"
try:
    ihdr, rows, ch = decode_png(boot)
except Exception as e:
    out("FAIL", f"boot PNG decode: {e}")
    print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
    sys.exit(1)

print(
    f"BOOT_IHDR w={ihdr['w']} h={ihdr['h']} bit={ihdr['bit']} "
    f"color={ihdr['color']} ch={ch}"
)
if ihdr["w"] == 1008 and ihdr["h"] == 2244:
    out("PASS", "python IHDR exactly 1008×2244")
else:
    out("FAIL", f"python IHDR {ihdr['w']}×{ihdr['h']} (expected 1008×2244)")
if ihdr["color"] == 2:
    out("PASS", "boot PNG color type 2 (RGB)")
else:
    out("FAIL", f"boot PNG color type {ihdr['color']} (expected 2 RGB)")

tl = pix(rows, ch, 0, 0)
tr = pix(rows, ch, ihdr["w"] - 1, 0)
bl = pix(rows, ch, 0, ihdr["h"] - 1)
br = pix(rows, ch, ihdr["w"] - 1, ihdr["h"] - 1)
print(f"BOOT_CORNERS tl={tl} tr={tr} bl={bl} br={br}")
if all(p == (10, 11, 12) for p in (tl, tr, bl, br)):
    out("PASS", "boot canvas corners are dark (10,11,12) — luma-sum>30 is unsafe")
else:
    out(
        "HOLD",
        f"boot corners not the documented (10,11,12) canvas; measured {tl}/{tr}/{bl}/{br}",
    )

bb30, n30 = bbox_rgb_sum(ihdr, rows, ch, 30)
print(f"BOOT_BBOX luma-sum>30 {bb30} n={n30}")
w, h = ihdr["w"], ihdr["h"]
if bb30 == (0, 0, w - 1, h - 1):
    out(
        "PASS",
        "adversarial: luma-sum>30 bbox is the full canvas (decoder trap; not used for AC)",
    )
else:
    out(
        "FAIL",
        f"luma-sum>30 did not fill the canvas ({bb30}); cannot prove the >30 trap",
    )

bb80, n80 = bbox_rgb_sum(ihdr, rows, ch, 80)
print(f"BOOT_BBOX luma-sum>80 {bb80} n={n80}")
if bb80 is None:
    out("FAIL", "luma-sum>80 found no content (empty / too dark)")
else:
    minx, miny, maxx, maxy = bb80
    inset_l = minx
    inset_r = w - 1 - maxx
    inset_t = miny
    inset_b = h - 1 - maxy
    print(f"BOOT_INSETS L={inset_l} R={inset_r} T={inset_t} B={inset_b}")
    need_lr = int(0.12 * w)  # 120.96 → require >= 120
    need_t = int(0.14 * h)  # 314.16 → require >= 314
    need_b = int(0.12 * h)  # 269.28 → require >= 269
    if inset_l >= need_lr and inset_r >= need_lr and inset_t >= need_t and inset_b >= need_b:
        out(
            "PASS",
            f"G content inside ~12%/14%/12% safe zone (insets L/R {inset_l}/{inset_r} "
            f"T {inset_t} B {inset_b}; need L/R>={need_lr} T>={need_t} B>={need_b})",
        )
    else:
        out(
            "FAIL",
            f"content outside safe zone insets L/R {inset_l}/{inset_r} T {inset_t} "
            f"B {inset_b} (need L/R>={need_lr} T>={need_t} B>={need_b})",
        )
    # Architect rematch target (independent confirmation, not a Frontend dump)
    if bb80 == (348, 900, 659, 1219) and inset_l == 348 and inset_r == 348 and inset_t == 900 and inset_b == 1024:
        out(
            "PASS",
            "luma-sum>80 bbox exactly (348,900)–(659,1219) insets L/R 348 T 900 B 1024",
        )
    else:
        out(
            "HOLD",
            f"luma-sum>80 bbox {bb80} insets L/R {inset_l}/{inset_r} T {inset_t} B {inset_b} "
            f"(Architect target (348,900)–(659,1219) L/R 348 T 900 B 1024)",
        )

kit_boot = root / "vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/logo_1008x2244.png"
if kit_boot.is_file() and kit_boot.read_bytes() == boot.read_bytes():
    out("PASS", "brand-kit boot PNG bytes match bootanimation/logo_1008x2244.png")
else:
    out("FAIL", "brand-kit boot PNG bytes differ or missing")

suw = root / (
    "vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/"
    "res/drawable-nodpi/guardtalk_welcome_square.png"
)
try:
    s_ihdr, s_rows, s_ch = decode_png(suw)
except Exception as e:
    out("FAIL", f"SUW PNG decode: {e}")
    print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
    sys.exit(1)

print(
    f"SUW_IHDR w={s_ihdr['w']} h={s_ihdr['h']} bit={s_ihdr['bit']} "
    f"color={s_ihdr['color']} ch={s_ch}"
)
if s_ihdr["w"] == 1024 and s_ihdr["h"] == 1024:
    out("PASS", "SUW overlay IHDR 1024×1024")
else:
    out("FAIL", f"SUW overlay IHDR {s_ihdr['w']}×{s_ihdr['h']} (expected 1024×1024)")
if s_ihdr["color"] == 6:
    out("PASS", "SUW overlay PNG color type 6 (RGBA)")
else:
    out("FAIL", f"SUW overlay PNG color type {s_ihdr['color']} (expected 6 RGBA)")

sw, sh = s_ihdr["w"], s_ihdr["h"]
corners = [
    pix(s_rows, s_ch, 0, 0),
    pix(s_rows, s_ch, sw - 1, 0),
    pix(s_rows, s_ch, 0, sh - 1),
    pix(s_rows, s_ch, sw - 1, sh - 1),
]
print(f"SUW_CORNERS {corners}")
if s_ch == 4 and all(p[3] == 0 for p in corners):
    out("PASS", "SUW four corners alpha=0")
else:
    out("FAIL", f"SUW corners not fully transparent: {corners}")

center = pix(s_rows, s_ch, sw // 2, sh // 2)
print(f"SUW_CENTER {center}")
if s_ch == 4 and center[3] > 0:
    out("PASS", f"SUW center has branded content (alpha={center[3]})")
else:
    out("FAIL", f"SUW center has no visible content: {center}")

nz = 0
for row in s_rows:
    for x in range(sw):
        if row[x * s_ch + 3]:
            nz += 1
if nz > 0:
    out("PASS", f"SUW has {nz} nonzero-alpha pixels (not an empty transparent sheet)")
else:
    out("FAIL", "SUW has zero nonzero-alpha pixels")

kit_suw = root / (
    "vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/07_setup_wizard/"
    "guardtalk_welcome_square_transparent.png"
)
if kit_suw.is_file() and kit_suw.read_bytes() == suw.read_bytes():
    out("PASS", "brand-kit SUW PNG bytes match overlay drawable-nodpi PNG")
else:
    out("FAIL", "brand-kit SUW PNG bytes differ or missing")

xml = root / (
    "vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/"
    "res/drawable/guardtalk_welcome_square.xml"
)
if xml.exists():
    out("FAIL", "python: guardtalk_welcome_square.xml still exists")
else:
    out("PASS", "python: guardtalk_welcome_square.xml ABSENT")

zpath = root / "vendor/guardtalk/branding/bootanimation/bootanimation.zip"
if not zpath.is_file():
    out("FAIL", "bootanimation.zip missing (pre-existing asset regression)")
else:
    with zipfile.ZipFile(zpath) as zf:
        desc = zf.read("desc.txt").decode("utf-8", "replace")
    first = desc.splitlines()[0].strip() if desc.strip() else ""
    print(f"ZIP_DESC_FIRST {first!r}")
    parts = first.split()
    if len(parts) >= 2 and parts[0] == "1080" and parts[1] == "2400":
        out(
            "HOLD",
            "bootanimation.zip desc.txt still 1080×2400 (USERBUILD not delayed; not product FAIL)",
        )
    else:
        out(
            "HOLD",
            f"bootanimation.zip desc.txt {first!r} — zip rebuild still not this card; not product FAIL",
        )

print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
sys.exit(1 if fail else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -eq 0 ]]; then
  pass "python PNG rematch exit 0"
else
  fail "python PNG rematch exit $PY_RC"
fi

echo
echo "--- secrets (pem/pk8/.env under branding + overlay) ---"
SECRETS="$(find vendor/guardtalk/branding vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay \
  \( -name '*.pem' -o -name '*.pk8' -o -name '.env' -o -name '*.env' \) -print 2>/dev/null || true)"
if [[ -z "$SECRETS" ]]; then
  pass "no pem/pk8/.env under branding + SetupWizard overlay"
else
  fail "NEGATIVE HIT: secret-like files: $SECRETS"
fi
# git index (tracked) must also be empty for those names in-scope
GIT_SECRETS="$(git ls-files -- \
  'vendor/guardtalk/branding/**/*.pem' \
  'vendor/guardtalk/branding/**/*.pk8' \
  'vendor/guardtalk/branding/**/.env' \
  'vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/**/*.pem' \
  'vendor/guardtalk/overlays/GuardTalkSetupWizardOverlay/**/*.pk8' \
  2>/dev/null || true)"
if [[ -z "$GIT_SECRETS" ]]; then
  pass "git index has no pem/pk8/.env under branding + overlay"
else
  fail "NEGATIVE HIT: git-tracked secret-like files: $GIT_SECRETS"
fi

echo
echo "--- identify (optional; ImageMagick) ---"
if command -v identify >/dev/null 2>&1; then
  identify "$BOOT_PNG" || true
  identify "$SUW_PNG" || true
  pass "identify present (sidecar decoder)"
else
  hold "identify not installed — python zlib IHDR used; not product FAIL"
fi

echo
echo "--- adb (device HOLD if empty) ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | grep -q '54111FDAS000GN[[:space:]]'; then
  hold "adb sees 54111FDAS000GN — this card is host-only; Welcome + boot not device-fixed; do not lift PASS HOLD"
else
  hold "adb devices empty / no komodo 54111FDAS000GN — Welcome + boot HOLD, never device-fixed"
fi

echo
echo "RESULT: $([[ "$FAIL" -eq 0 ]] && echo PASS || echo FAIL) (host)  bash_PASS=${PASS_N} bash_HOLD=${HOLD_N} PY_RC=${PY_RC}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "ZIP=HOLD"
echo "DEVICE=HOLD"
echo "PASS_HOLD=remains"
exit "$FAIL"
