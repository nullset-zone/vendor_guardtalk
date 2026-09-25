#!/usr/bin/env bash
# Independent rematch for Q-OS-BACK-GESTURE (pair of F-OS-BACK-GESTURE).
# Do not trust Frontend/Architect reports. Host static only.
# Device gesture/3-button back HOLD if adb empty. No USB. No product edits.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_os_back_gesture_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; FAIL_N=$((FAIL_N + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }
FAIL_N=0

EXCISED="vendor/guardtalk/feature-excised/apps-excised.mk"
FW_CFG="frameworks/base/core/res/res/values/config.xml"
GEST_CFG="frameworks/base/packages/overlays/NavigationBarModeGesturalOverlay/res/values/config.xml"
BTN_CFG="frameworks/base/packages/overlays/NavigationBarMode3ButtonOverlay/res/values/config.xml"
GEST_MF="frameworks/base/packages/overlays/NavigationBarModeGesturalOverlay/AndroidManifest.xml"
BTN_MF="frameworks/base/packages/overlays/NavigationBarMode3ButtonOverlay/AndroidManifest.xml"
AGG_BP="frameworks/base/packages/overlays/Android.bp"
OBS="frameworks/base/core/java/com/android/internal/policy/GestureNavigationSettingsObserver.java"
EDGE="frameworks/base/packages/SystemUI/src/com/android/systemui/navigationbar/gestural/EdgeBackGestureHandler.java"
AOSP_MK="build/make/target/product/aosp_product.mk"
ADEVTOOL="vendor/google_devices/tokay/adevtool-version-check.mk"

echo "=== Q-OS-BACK-GESTURE independent rematch ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo

echo "=== RAW: rg GUARDTALK_OVERLAY_KEEP|NavigationBarMode*|frameworks-base-overlays $EXCISED ==="
rg -n "GUARDTALK_OVERLAY_KEEP|NavigationBarModeGesturalOverlay|NavigationBarMode3ButtonOverlay|frameworks-base-overlays" \
  "$EXCISED" || true
echo

echo "=== RAW: rg config_backGestureInset|config_navBarInteractionMode ==="
rg -n "config_backGestureInset|config_navBarInteractionMode" \
  "$FW_CFG" "$GEST_CFG" "$BTN_CFG" || true
echo

echo "=== RAW: rg config_backGestureInset|mEdgeWidth|isWithinTouchRegion observer+handler ==="
rg -n "config_backGestureInset|mEdgeWidth|isWithinTouchRegion" \
  "$OBS" "$EDGE" || true
echo

echo "=== RAW: rg ro.boot.vendor.overlay.theme $AOSP_MK ==="
rg -n "ro.boot.vendor.overlay.theme" "$AOSP_MK" || true
echo

echo "=== RAW: adb devices ==="
ADB_OUT="$(adb devices 2>&1 || true)"
printf '%s\n' "$ADB_OUT"
echo

python3 - "$ROOT" <<'PY'
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(sys.argv[1])
pass_n = fail_n = hold_n = 0

def out(kind, msg):
    global pass_n, fail_n, hold_n
    print(f"{kind}: {msg}")
    if kind == "PASS":
        pass_n += 1
    elif kind == "FAIL":
        fail_n += 1
    else:
        hold_n += 1

def makefile_assign_tokens(text, var):
    tokens = []
    lines = text.splitlines()
    i = 0
    pat = re.compile(rf"^{re.escape(var)}\s*(\+|:)*=\s*(.*)$")
    while i < len(lines):
        stripped = lines[i].split("#", 1)[0]
        m = pat.match(stripped)
        if not m:
            i += 1
            continue
        buf = m.group(2)
        while buf.rstrip().endswith("\\"):
            buf = buf.rstrip()[:-1] + " "
            i += 1
            if i >= len(lines):
                break
            buf += lines[i].split("#", 1)[0]
        tokens.extend(buf.split())
        i += 1
    return tokens

def dimen_value(xml_text, name):
    m = re.search(
        rf'<dimen\s+name="{re.escape(name)}"\s*>([^<]+)</dimen>',
        xml_text,
    )
    return m.group(1).strip() if m else None

def integer_value(xml_text, name):
    m = re.search(
        rf'<integer\s+name="{re.escape(name)}"\s*>([^<]+)</integer>',
        xml_text,
    )
    return m.group(1).strip() if m else None

def require_file(rel):
    p = root / rel
    if p.is_file():
        out("PASS", f"present: {rel}")
        return p
    out("FAIL", f"missing: {rel}")
    return None

excised = require_file("vendor/guardtalk/feature-excised/apps-excised.mk")
fw_cfg = require_file("frameworks/base/core/res/res/values/config.xml")
gest_cfg = require_file(
    "frameworks/base/packages/overlays/NavigationBarModeGesturalOverlay/res/values/config.xml"
)
btn_cfg = require_file(
    "frameworks/base/packages/overlays/NavigationBarMode3ButtonOverlay/res/values/config.xml"
)
gest_mf = require_file(
    "frameworks/base/packages/overlays/NavigationBarModeGesturalOverlay/AndroidManifest.xml"
)
btn_mf = require_file(
    "frameworks/base/packages/overlays/NavigationBarMode3ButtonOverlay/AndroidManifest.xml"
)
agg_bp = require_file("frameworks/base/packages/overlays/Android.bp")
obs = require_file(
    "frameworks/base/core/java/com/android/internal/policy/GestureNavigationSettingsObserver.java"
)
edge = require_file(
    "frameworks/base/packages/SystemUI/src/com/android/systemui/navigationbar/gestural/EdgeBackGestureHandler.java"
)
aosp_mk = require_file("build/make/target/product/aosp_product.mk")
require_file("frameworks/base/packages/SystemUI/src/com/android/systemui/navigationbar/views/buttons/KeyButtonView.java")

GEST = "NavigationBarModeGesturalOverlay"
BTN = "NavigationBarMode3ButtonOverlay"
AGG = "frameworks-base-overlays"
CUTOUT = [
    "AvoidAppsInCutoutOverlay",
    "NoCutoutOverlay",
    "TransparentNavigationBarOverlay",
    "DisplayCutoutEmulationCornerOverlay",
    "DisplayCutoutEmulationDoubleOverlay",
    "DisplayCutoutEmulationHoleOverlay",
    "DisplayCutoutEmulationNarrowOverlay",
    "DisplayCutoutEmulationTallOverlay",
    "DisplayCutoutEmulationWaterfallOverlay",
    "DisplayCutoutEmulationWideOverlay",
]

if excised:
    mk = excised.read_text(encoding="utf-8")
    drop = makefile_assign_tokens(mk, "GUARDTALK_APPS_PACKAGES")
    keep = makefile_assign_tokens(mk, "GUARDTALK_OVERLAY_KEEP")
    prod_plus = makefile_assign_tokens(mk, "PRODUCT_PACKAGES")
    drop_set = set(drop)
    keep_set = set(keep)
    inter = keep_set & drop_set

    if GEST in drop_set:
        out("PASS", f"{GEST} still listed in drop list GUARDTALK_APPS_PACKAGES")
    else:
        out("FAIL", f"{GEST} missing from drop list")
    if BTN in drop_set:
        out("PASS", f"{BTN} still listed in drop list GUARDTALK_APPS_PACKAGES")
    else:
        out("FAIL", f"{BTN} missing from drop list")
    if GEST in keep_set:
        out("PASS", f"{GEST} in GUARDTALK_OVERLAY_KEEP")
    else:
        out("FAIL", f"{GEST} missing from GUARDTALK_OVERLAY_KEEP (KEEP restore missing)")
    if BTN in keep_set:
        out("PASS", f"{BTN} in GUARDTALK_OVERLAY_KEEP")
    else:
        out("FAIL", f"{BTN} missing from GUARDTALK_OVERLAY_KEEP (KEEP restore missing)")
    if GEST in inter and BTN in inter:
        out("PASS", f"KEEP ∩ drop-list restores {GEST} and {BTN}")
    else:
        out("FAIL", f"KEEP ∩ drop-list missing nav overlays; inter={sorted(inter & {GEST, BTN})}")

    restore_re = (
        r"PRODUCT_PACKAGES\s*\+=\s*\$\(filter\s+\$\(GUARDTALK_OVERLAY_KEEP\),"
        r"\$\(GUARDTALK_APPS_PACKAGES\)\)"
    )
    if re.search(restore_re, mk):
        out("PASS", "PRODUCT_PACKAGES += $(filter $(GUARDTALK_OVERLAY_KEEP),$(GUARDTALK_APPS_PACKAGES)) present")
    else:
        out("FAIL", "KEEP restore PRODUCT_PACKAGES filter line missing")

    # filter-out must precede KEEP restore
    fo = mk.find("PRODUCT_PACKAGES := $(filter-out $(GUARDTALK_APPS_PACKAGES),$(PRODUCT_PACKAGES))")
    rs = mk.find("PRODUCT_PACKAGES += $(filter $(GUARDTALK_OVERLAY_KEEP),$(GUARDTALK_APPS_PACKAGES))")
    if fo != -1 and rs != -1 and fo < rs:
        out("PASS", "filter-out precedes KEEP restore (drop then re-add)")
    else:
        out("FAIL", f"filter-out/KEEP restore order broken fo={fo} rs={rs}")

    if AGG in drop_set:
        out("PASS", f"{AGG} still in drop list")
    else:
        out("FAIL", f"{AGG} not in drop list (aggregator re-enabled)")
    if AGG in keep_set:
        out("FAIL", f"{AGG} in KEEP (cutout/transparent-nav would restore via aggregator)")
    else:
        out("PASS", f"{AGG} not in KEEP (aggregator stays excised)")
    if AGG in prod_plus:
        out("FAIL", f"{AGG} re-added via PRODUCT_PACKAGES += in apps-excised.mk")
    else:
        out("PASS", f"{AGG} not in PRODUCT_PACKAGES += tokens")

    restored_cutout = [c for c in CUTOUT if c in keep_set]
    if restored_cutout:
        out("FAIL", f"cutout/transparent-nav overlays re-enabled via KEEP: {restored_cutout}")
    else:
        out("PASS", "cutout / TransparentNavigationBarOverlay not in KEEP")
    missing_cutout_drop = [c for c in CUTOUT if c not in drop_set]
    if missing_cutout_drop:
        out("FAIL", f"cutout overlays missing from drop list: {missing_cutout_drop}")
    else:
        out("PASS", "all cutout / TransparentNavigationBarOverlay names remain in drop list")

    # Negative: KEEP restore missing would empty the intersection
    if not inter:
        out("FAIL", "negative KEEP-missing: intersection empty")
    else:
        out("PASS", "negative KEEP-missing: intersection non-empty (restore would fire)")

# --- overlay resource values ---
if gest_cfg:
    gtxt = gest_cfg.read_text(encoding="utf-8")
    inset = dimen_value(gtxt, "config_backGestureInset")
    mode = integer_value(gtxt, "config_navBarInteractionMode")
    if inset == "30dp":
        out("PASS", "gestural overlay config_backGestureInset=30dp")
    else:
        out("FAIL", f"gestural overlay config_backGestureInset={inset!r} (want 30dp)")
    if mode == "2":
        out("PASS", "gestural overlay config_navBarInteractionMode=2")
    else:
        out("FAIL", f"gestural overlay config_navBarInteractionMode={mode!r} (want 2)")

if btn_cfg:
    btxt = btn_cfg.read_text(encoding="utf-8")
    inset = dimen_value(btxt, "config_backGestureInset")
    mode = integer_value(btxt, "config_navBarInteractionMode")
    if mode == "0":
        out("PASS", "3-button overlay config_navBarInteractionMode=0")
    else:
        out("FAIL", f"3-button overlay config_navBarInteractionMode={mode!r} (want 0)")
    if inset is None:
        out("PASS", "3-button overlay does not bake config_backGestureInset")
    elif inset == "30dp":
        out("FAIL", "3-button overlay bakes config_backGestureInset=30dp (pager steal in button mode)")
    else:
        out("FAIL", f"3-button overlay unexpectedly sets config_backGestureInset={inset!r}")

    # tablet/land variants must not sneak 30dp in
    btn_dir = root / "frameworks/base/packages/overlays/NavigationBarMode3ButtonOverlay"
    sneak = []
    for p in btn_dir.rglob("*.xml"):
        t = p.read_text(encoding="utf-8")
        if "config_backGestureInset" in t:
            sneak.append(str(p.relative_to(root)))
    if sneak:
        out("FAIL", f"3-button overlay tree defines config_backGestureInset: {sneak}")
    else:
        out("PASS", "3-button overlay tree has no config_backGestureInset in any xml")

if fw_cfg:
    ftxt = fw_cfg.read_text(encoding="utf-8")
    inset = dimen_value(ftxt, "config_backGestureInset")
    if inset == "0dp":
        out("PASS", "framework config_backGestureInset=0dp (not baked; pager-safe in button mode)")
    else:
        out("FAIL", f"framework config_backGestureInset={inset!r} (want 0dp)")

# GuardTalk overlays must not bake 30dp into framework resources
gt_overlays = root / "vendor/guardtalk/overlays"
if gt_overlays.is_dir():
    baked = []
    for p in gt_overlays.rglob("*.xml"):
        if "config_backGestureInset" in p.read_text(encoding="utf-8", errors="replace"):
            baked.append(str(p.relative_to(root)))
    if baked:
        out("FAIL", f"GuardTalk overlays bake config_backGestureInset: {baked}")
    else:
        out("PASS", "GuardTalk overlays do not override config_backGestureInset")

# --- exclusive overlay category + boot theme ---
ANDROID = "{http://schemas.android.com/apk/res/android}"

def overlay_meta(path):
    tree = ET.parse(path)
    man = tree.getroot()
    pkg = man.get("package")
    ov = man.find("overlay")
    if ov is None:
        return pkg, None, None, None
    target = ov.get(ANDROID + "targetPackage") or ov.get("android:targetPackage")
    cat = ov.get(ANDROID + "category") or ov.get("android:category")
    prio = ov.get(ANDROID + "priority") or ov.get("android:priority")
    return pkg, target, cat, prio

if gest_mf:
    pkg, target, cat, prio = overlay_meta(gest_mf)
    if pkg == "com.android.internal.systemui.navbar.gestural":
        out("PASS", "gestural overlay package com.android.internal.systemui.navbar.gestural")
    else:
        out("FAIL", f"gestural overlay package={pkg!r}")
    if target == "android" and cat == "com.android.internal.navigation_bar_mode":
        out("PASS", "gestural overlay exclusive category navigation_bar_mode target=android")
    else:
        out("FAIL", f"gestural overlay target={target!r} category={cat!r}")

if btn_mf:
    pkg, target, cat, prio = overlay_meta(btn_mf)
    if pkg == "com.android.internal.systemui.navbar.threebutton":
        out("PASS", "3-button overlay package com.android.internal.systemui.navbar.threebutton")
    else:
        out("FAIL", f"3-button overlay package={pkg!r}")
    if target == "android" and cat == "com.android.internal.navigation_bar_mode":
        out("PASS", "3-button overlay exclusive category navigation_bar_mode target=android")
    else:
        out("FAIL", f"3-button overlay target={target!r} category={cat!r}")

if aosp_mk:
    atxt = aosp_mk.read_text(encoding="utf-8")
    if "ro.boot.vendor.overlay.theme=com.android.internal.systemui.navbar.gestural" in atxt:
        out("PASS", "aosp_product.mk already sets ro.boot.vendor.overlay.theme=navbar.gestural")
    else:
        out("FAIL", "aosp_product.mk missing gestural overlay.theme")

if agg_bp:
    bpt = agg_bp.read_text(encoding="utf-8")
    if 'name: "frameworks-base-overlays"' in bpt:
        out("PASS", "aggregator phony frameworks-base-overlays still defined in source")
    else:
        out("FAIL", "aggregator phony missing from overlays/Android.bp")
    for name in (GEST, BTN, "TransparentNavigationBarOverlay", "NoCutoutOverlay"):
        if f'"{name}"' in bpt:
            out("PASS", f"aggregator required still lists {name} (source intact; product filter drops phony)")
        else:
            out("FAIL", f"aggregator required lost {name}")

# --- observer / handler consume inset ---
if obs:
    otxt = obs.read_text(encoding="utf-8")
    if "config_backGestureInset" in otxt and "getUnscaledInset" in otxt:
        out("PASS", "GestureNavigationSettingsObserver reads config_backGestureInset via getUnscaledInset")
    else:
        out("FAIL", "GestureNavigationSettingsObserver does not consume config_backGestureInset")
    if "getLeftSensitivity" in otxt and "getRightSensitivity" in otxt:
        out("PASS", "observer exposes getLeftSensitivity/getRightSensitivity")
    else:
        out("FAIL", "observer missing sensitivity getters")
    # 0dp inset must not be inflated by DeviceConfig
    if "defaultInset > 0" in otxt:
        out("PASS", "observer only applies DeviceConfig edge width when defaultInset > 0")
    else:
        out("HOLD", "observer DeviceConfig >0 guard not found as expected")

if edge:
    etxt = edge.read_text(encoding="utf-8")
    if "mEdgeWidthLeft" in etxt and "mEdgeWidthRight" in etxt:
        out("PASS", "EdgeBackGestureHandler has mEdgeWidthLeft/Right")
    else:
        out("FAIL", "EdgeBackGestureHandler missing mEdgeWidth fields")
    if "getLeftSensitivity" in etxt and "getRightSensitivity" in etxt:
        out("PASS", "EdgeBackGestureHandler loads edge widths from observer sensitivities")
    else:
        out("FAIL", "EdgeBackGestureHandler does not call observer sensitivities")
    if "isWithinTouchRegion" in etxt:
        out("PASS", "EdgeBackGestureHandler.isWithinTouchRegion present")
    else:
        out("FAIL", "EdgeBackGestureHandler.isWithinTouchRegion missing")
    if "mUsingThreeButtonNav" in etxt and "!mUsingThreeButtonNav" in etxt:
        out("PASS", "edge handler requires !mUsingThreeButtonNav (swipe does not steal in 3-button mode)")
    else:
        out("FAIL", "edge handler does not gate gestures on !mUsingThreeButtonNav")
    if "mInGestureNavMode" in etxt:
        out("PASS", "edge handler tracks mInGestureNavMode")
    else:
        out("FAIL", "edge handler missing mInGestureNavMode")

# KeyButtonView KEYCODE_BACK (3-button path)
kbv = root / "frameworks/base/packages/SystemUI/src/com/android/systemui/navigationbar/views/buttons/KeyButtonView.java"
if kbv.is_file():
    ktxt = kbv.read_text(encoding="utf-8")
    if "KEYCODE_BACK" in ktxt:
        out("PASS", "KeyButtonView still handles KEYCODE_BACK (3-button on-screen back)")
    else:
        out("FAIL", "KeyButtonView missing KEYCODE_BACK")

# Residual: Settings gesture picker still hidden (not a FAIL of this pair)
settings_ov = root / "vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/config.xml"
if settings_ov.is_file():
    st = settings_ov.read_text(encoding="utf-8")
    m = re.search(r'<bool\s+name="config_show_gesture_settings"\s*>([^<]+)</bool>', st)
    if m and m.group(1).strip() == "false":
        out("PASS", "residual documented: config_show_gesture_settings=false (picker still hidden)")
    else:
        out("HOLD", f"config_show_gesture_settings unexpected: {m.group(1) if m else None}")

# adevtool pin — lunch HOLD without running lunch
pin = root / "vendor/google_devices/tokay/adevtool-version-check.mk"
if pin.is_file():
    ptxt = pin.read_text(encoding="utf-8")
    want = re.search(r"rev-parse HEAD\),([a-f0-9]+)", ptxt)
    expected = want.group(1) if want else None
    try:
        got = subprocess.check_output(
            ["git", "-C", str(root / "vendor/adevtool"), "rev-parse", "HEAD"],
            text=True,
        ).strip()
    except Exception as exc:
        got = None
        out("HOLD", f"vendor/adevtool HEAD unreadable: {exc}")
        got = ""
    if expected and got and got != expected:
        out("HOLD", f"lunch tokay HOLD — adevtool pin mismatch got={got} want={expected}; adevtool-version-check.mk not edited")
    elif expected and got == expected:
        out("HOLD", "adevtool pin matches; lunch not run this rematch (static overlay card)")
    elif expected is None:
        out("HOLD", "adevtool pin SHA not parsed; lunch not run")

print()
print(f"SUITE_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail_n} HOLD_COUNT={hold_n}")
sys.exit(1 if fail_n else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -ne 0 ]]; then
  FAIL=1
fi

echo
echo "=== adb device proof ==="
if ! command -v adb >/dev/null 2>&1; then
  hold "adb binary not on PATH — swipe/3-button back not proven; not device-fixed"
else
  echo "$ADB_OUT"
  if echo "$ADB_OUT" | awk 'NR>1 && $2=="device" {found=1} END{exit found?0:1}'; then
    echo "--- dumpsys overlay (navbar) ---"
    adb shell dumpsys overlay 2>/dev/null | rg -n "navbar.gestural|navbar.threebutton|NavigationBarMode" || hold "dumpsys overlay navbar lines empty"
    pass "adb device present — overlay dumpsys captured (see output)"
  else
    hold "adb devices empty — swipe-from-edge and 3-button back not proven; not device-fixed"
  fi
fi

echo
echo "LIVE_DEVICE_CLAIMED=false"
if [[ "$FAIL" -ne 0 || "$PY_RC" -ne 0 ]]; then
  echo "RESULT: FAIL  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL_N=$FAIL_N PY_RC=$PY_RC"
  exit 1
fi
echo "RESULT: PASS (static)  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=0"
echo "Device gesture/3-button back: HOLD unless adb proof above."
exit 0
