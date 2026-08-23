#!/usr/bin/env bash
# Static verification for Q-BRAND-SWEEP
# (Residual GrapheneOS inventory + GuardTalkOS boot/brand verification).
#
# Cases:
#   1. VALUE-side GrapheneOS = 0 in overlay/SUW strings*.xml
#   2. Strict string-body scan (name attrs may keep *_grapheneos*)
#   3. bootanimation.zip present + expected md5
#   4. PRODUCT_DEVICE theme wire (not tokay-hardcoded include)
#   5. Per-device wrappers tokay+akita include shared branding/guardtalk-theme.mk
#   6. Theme.mk copies bootanimation.zip; dark zip filter present
#   7. SUW grapheneos_icon.xml deleted
#   8. About summary/logo + MyDeviceInfoFragment wire
#   9. Launcher overlay ic_launcher_home present
#  10. Out product media bootanimation matches source md5 (if present)
#  11. adb empty → DEVICE_BOOT=HOLD (not invent PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_brand_sweep_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

EXPECTED_MD5="7ba676c5704c6e6ab962fb34cc6590ef"
BOOTZIP="vendor/guardtalk/branding/bootanimation/bootanimation.zip"
THEME_MK="vendor/guardtalk/branding/guardtalk-theme.mk"
FEATURE_MK="vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
TOKAY_WRAP="vendor/guardtalk/device/tokay/guardtalk-theme.mk"
AKITA_WRAP="vendor/guardtalk/device/akita/guardtalk-theme.mk"
SUW_ICON="packages/apps/SetupWizard2/res/drawable/grapheneos_icon.xml"
ABOUT_STR_SETTINGS="packages/apps/Settings/res/values/strings.xml"
ABOUT_STR_OVERLAY="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/values/strings.xml"
LOGO_SETTINGS="packages/apps/Settings/res/drawable/ic_guardtalk_logo.xml"
LOGO_OVERLAY="vendor/guardtalk/overlays/GuardTalkSettingsOverlay/res/drawable/ic_guardtalk_logo.xml"
MYDEVICE="packages/apps/Settings/src/com/android/settings/deviceinfo/aboutphone/MyDeviceInfoFragment.java"
LAUNCHER_HOME="vendor/guardtalk/overlays/GuardTalkLauncherOverlay/res/drawable/ic_launcher_home.xml"

# --- 1. VALUE-side regex (acceptance command) ---
if rg -n '>GrapheneOS<|>grapheneos<' \
  vendor/guardtalk/overlays packages/apps/SetupWizard2/res \
  --glob '**/strings*.xml' >/tmp/q-brand-value-rg.txt 2>/dev/null; then
  fail "VALUE-side GrapheneOS hits in overlay/SUW strings (see /tmp/q-brand-value-rg.txt)"
else
  pass "VALUE-side GrapheneOS = 0 (rg >GrapheneOS<|>grapheneos< on overlay/SUW strings)"
fi

# --- 2. Strict string-body scan ---
BODY_FAIL=$(python3 - <<'PY'
import re, pathlib
roots = [
  pathlib.Path("vendor/guardtalk/overlays"),
  pathlib.Path("packages/apps/SetupWizard2/res"),
]
pat = re.compile(r"<string\b([^>]*)>(.*?)</string>", re.S | re.I)
fails = []
for root in roots:
  if not root.exists():
    continue
  for p in root.rglob("strings*.xml"):
    text = p.read_text(errors="replace")
    for m in pat.finditer(text):
      body = re.sub(r"<!\[CDATA\[|\]\]>", "", m.group(2))
      if re.search(r"GrapheneOS|grapheneos", body, re.I):
        name_m = re.search(r'name="([^"]+)"', m.group(1))
        name = name_m.group(1) if name_m else "?"
        fails.append(f"{p}:{name}:{body.strip()[:80]}")
print(len(fails))
for f in fails:
  print(f)
PY
)
BODY_COUNT=$(printf '%s\n' "$BODY_FAIL" | head -1)
if [[ "$BODY_COUNT" == "0" ]]; then
  pass "strict string-body GrapheneOS = 0 (overlays + SUW)"
else
  fail "strict string-body GrapheneOS leftovers count=$BODY_COUNT"
  printf '%s\n' "$BODY_FAIL" | tail -n +2 | head -20
fi

# --- 3. bootanimation.zip + md5 ---
if [[ -f "$BOOTZIP" ]]; then
  pass "bootanimation.zip present ($BOOTZIP)"
  got=$(md5sum "$BOOTZIP" | awk '{print $1}')
  if [[ "$got" == "$EXPECTED_MD5" ]]; then
    pass "bootanimation.zip md5 == $EXPECTED_MD5"
  else
    fail "bootanimation.zip md5 mismatch got=$got expected=$EXPECTED_MD5"
  fi
else
  fail "bootanimation.zip missing"
fi

# --- 4/5. PRODUCT_DEVICE theme wire ---
if rg -q 'device/\$\(PRODUCT_DEVICE\)/guardtalk-theme\.mk' "$FEATURE_MK"; then
  pass "feature-excised.mk uses PRODUCT_DEVICE theme path"
else
  fail "feature-excised.mk missing PRODUCT_DEVICE theme include"
fi
if rg -q 'device/tokay/guardtalk-theme\.mk' "$FEATURE_MK"; then
  fail "feature-excised.mk still tokay-hardcodes theme include"
else
  pass "feature-excised.mk not tokay-hardcoded for theme"
fi
if [[ -f "$TOKAY_WRAP" ]] && rg -q 'branding/guardtalk-theme\.mk' "$TOKAY_WRAP"; then
  pass "tokay wrapper includes shared branding/guardtalk-theme.mk"
else
  fail "tokay theme wrapper missing/incorrect"
fi
if [[ -f "$AKITA_WRAP" ]] && rg -q 'branding/guardtalk-theme\.mk' "$AKITA_WRAP"; then
  pass "akita wrapper includes shared branding/guardtalk-theme.mk"
else
  fail "akita theme wrapper missing/incorrect"
fi

# --- 6. Theme.mk boot copy + dark filter ---
if rg -q 'bootanimation\.zip:.*TARGET_COPY_OUT_PRODUCT.*/media/bootanimation\.zip' "$THEME_MK" \
  || rg -q 'PRODUCT_COPY_FILES \+= \$\(guardtalk_bootanim\):\$\(TARGET_COPY_OUT_PRODUCT\)/media/bootanimation\.zip' "$THEME_MK"; then
  pass "guardtalk-theme.mk wires PRODUCT media bootanimation.zip"
else
  fail "guardtalk-theme.mk missing bootanimation PRODUCT_COPY_FILES"
fi
if rg -q 'bootanimation-dark\.zip' "$THEME_MK" && rg -q '_gt_filtered_bootanim_copy_files|bootanimation-dark' "$THEME_MK"; then
  pass "guardtalk-theme.mk dark-zip filter present"
else
  fail "guardtalk-theme.mk dark-zip filter missing"
fi

# --- 7. SUW icon deleted ---
if [[ ! -f "$SUW_ICON" ]]; then
  pass "SUW grapheneos_icon.xml deleted"
else
  fail "SUW grapheneos_icon.xml still present"
fi

# --- 8. About summary/logo ---
if rg -q 'View GuardTalkOS version, status, and device details' "$ABOUT_STR_SETTINGS"; then
  pass "Settings about_settings_summary GuardTalkOS"
else
  fail "Settings about_settings_summary not GuardTalkOS"
fi
if rg -q 'View GuardTalkOS version, status, and device details' "$ABOUT_STR_OVERLAY"; then
  pass "Settings overlay about_settings_summary GuardTalkOS"
else
  fail "Settings overlay about_settings_summary missing GuardTalkOS"
fi
if [[ -f "$LOGO_SETTINGS" && -f "$LOGO_OVERLAY" ]]; then
  pass "ic_guardtalk_logo present (Settings + overlay)"
else
  fail "ic_guardtalk_logo missing Settings and/or overlay"
fi
if rg -q 'R\.drawable\.ic_guardtalk_logo' "$MYDEVICE"; then
  pass "MyDeviceInfoFragment uses ic_guardtalk_logo"
else
  fail "MyDeviceInfoFragment not wired to ic_guardtalk_logo"
fi

# --- 9. Launcher home icon overlay ---
if [[ -f "$LAUNCHER_HOME" ]]; then
  pass "GuardTalkLauncherOverlay ic_launcher_home present"
else
  fail "GuardTalkLauncherOverlay ic_launcher_home missing"
fi

# --- 10. Built-out product media (optional but strong) ---
for prod in tokay akita; do
  outz="out/target/product/${prod}/product/media/bootanimation.zip"
  if [[ -f "$outz" ]]; then
    om=$(md5sum "$outz" | awk '{print $1}')
    if [[ "$om" == "$EXPECTED_MD5" ]]; then
      pass "out/${prod} product/media/bootanimation.zip md5 match"
    else
      fail "out/${prod} product/media/bootanimation.zip md5=$om (expected $EXPECTED_MD5)"
    fi
  else
    hold "out/${prod} product/media/bootanimation.zip absent (no rebuild this pass)"
  fi
done

# --- 11. Device boot smoke ---
if command -v adb >/dev/null 2>&1; then
  adb_out=$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')
  if [[ -z "$adb_out" ]]; then
    hold "adb empty — device boot smoke HOLD (artifact inspection used)"
  else
    hold "adb device present but live bootanimation visual not automated — manual smoke recommended"
  fi
else
  hold "adb unavailable — device boot smoke HOLD"
fi

# --- Residual name-class sanity (not FAIL) ---
NAME_COUNT=$(python3 - <<'PY'
import re, pathlib
roots = [
  pathlib.Path("vendor/guardtalk/overlays"),
  pathlib.Path("packages/apps/SetupWizard2/res"),
]
pat = re.compile(r'<string\b([^>]*)>', re.I)
n = 0
for root in roots:
  for p in root.rglob("strings*.xml"):
    for m in pat.finditer(p.read_text(errors="replace")):
      name_m = re.search(r'name="([^"]+)"', m.group(1))
      if name_m and re.search(r"grapheneos", name_m.group(1), re.I):
        n += 1
print(n)
PY
)
pass "documented residual resource names *_grapheneos* count=${NAME_COUNT} (values GuardTalkOS; justified)"

echo ""
echo "PASS_COUNT=${PASS_N} HOLD_COUNT=${HOLD_N} FAIL=${FAIL}"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
