#!/usr/bin/env bash
# Static verification for Q-SEC-P3-QS (Phase-3 Quick Settings catalog).
# Covers stock catalog exactness, AutoRebootTile contracts, forbidden tiles,
# product labels / editor docs, and prior green SystemUI / overlay cites.
# (no device required).
# Usage: from GrapheneOS-worktree root:
#   bash vendor/guardtalk/docs/qa/verify_sec_p3_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }

require_file() {
  local f="$1" label="${2:-$1}"
  if [[ -f "$f" ]]; then
    pass "present: $label"
  else
    fail "missing: $label ($f)"
  fi
}

require_rg() {
  local pat="$1" file="$2" label="$3"
  if [[ -f "$file" ]] && rg -q -- "$pat" "$file"; then
    pass "$label"
  else
    fail "$label (pattern missing in $file)"
  fi
}

# Extract a <string name="LIST">...</string> value (may span lines).
extract_qs_list() {
  local list="$1" file="$2"
  awk -v n="$list" '
    $0 ~ "name=\"" n "\"" {grab=1}
    grab {print}
    grab && /<\/string>/ {exit}
  ' "$file" | tr -d '\n' | sed -E 's/.*>([^<]*)<.*/\1/' | tr -d '[:space:]'
}

# True if comma-separated list contains exact token.
list_has_token() {
  local list="$1" tok="$2"
  echo ",${list}," | rg -q ",${tok},"
}

# --- Paths ---
SYSUI_OV="vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/config.xml"
SYSUI_STR="vendor/guardtalk/overlays/GuardTalkSystemUIOverlay/res/values/strings.xml"
AR_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/AutoRebootTile.java"
AR_MOD="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/AutoRebootModule.kt"
REF_MOD="frameworks/base/packages/SystemUI/src/com/android/systemui/dagger/ReferenceSystemUIModule.java"
MIC_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/MicrophoneToggleTile.java"
CAM_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/CameraToggleTile.java"
BAT_TILE="frameworks/base/packages/SystemUI/src/com/android/systemui/qs/tiles/BatterySaverTile.java"
AR_POL="frameworks/base/core/java/android/guardtalk/GuardTalkAutoRebootPolicy.java"
AR_PREF="packages/apps/Settings/src/com/android/settings/security/guardtalk/GuardTalkAutoRebootPreferenceController.java"
MK="vendor/guardtalk/device/tokay/guardtalk-tokay.mk"
DOC_POL="vendor/guardtalk/docs/QS_TILES_POLICY.md"
DOC_ED="vendor/guardtalk/docs/QS_EDITOR_UI_NOTES.md"
QS_DIR="frameworks/base/packages/SystemUI/src/com/android/systemui/qs"

echo "=== Q-SEC-P3-QS: policy / editor docs ==="

require_file "$DOC_POL" "QS_TILES_POLICY.md"
require_file "$DOC_ED" "QS_EDITOR_UI_NOTES.md"
require_rg 'mictoggle|cameratoggle|battery|autoreboot' "$DOC_POL" \
  "QS_TILES_POLICY documents four Phase-3 specs"
require_rg 'catalog only|Catalog only|not forced onto default' "$DOC_POL" \
  "QS_TILES_POLICY: Auto-reboot catalog-only"
require_rg 'Short press|short-press|Off.*last' "$DOC_POL" \
  "QS_TILES_POLICY: short-press Off↔last profile"
require_rg 'Long press|long-press|Exploit protection' "$DOC_POL" \
  "QS_TILES_POLICY: long-press Exploit protection"
require_rg 'quick_settings_tiles_stock' "$DOC_ED" \
  "QS_EDITOR_UI_NOTES references stock catalog"
require_rg 'no.*autoreboot|catalog-only|\*\*no\*\* `autoreboot`' "$DOC_ED" \
  "QS_EDITOR_UI_NOTES: autoreboot not on default panels"

echo "=== Q-SEC-P3-QS: stock catalog has four Phase-3 tiles ==="

require_file "$SYSUI_OV" "GuardTalkSystemUIOverlay config"
STOCK="$(extract_qs_list quick_settings_tiles_stock "$SYSUI_OV")"
if [[ -z "$STOCK" ]]; then
  fail "could not extract quick_settings_tiles_stock"
else
  for tok in mictoggle cameratoggle battery autoreboot; do
    if list_has_token "$STOCK" "$tok"; then
      pass "stock catalog contains '${tok}'"
    else
      fail "stock catalog missing '${tok}'"
    fi
  done
  # Phase-3 grouping for editor discoverability
  if echo "$STOCK" | rg -q 'battery,mictoggle,cameratoggle,autoreboot'; then
    pass "stock groups Phase-3 specs adjacently (battery,mictoggle,cameratoggle,autoreboot)"
  else
    fail "stock missing adjacent Phase-3 group battery,mictoggle,cameratoggle,autoreboot"
  fi
fi

echo "=== Q-SEC-P3-QS: Auto-reboot NOT in default / new_default ==="

for list in quick_settings_tiles_default quick_settings_tiles_new_default; do
  val="$(extract_qs_list "$list" "$SYSUI_OV")"
  if [[ -z "$val" ]]; then
    fail "could not extract ${list}"
    continue
  fi
  if list_has_token "$val" "autoreboot"; then
    fail "${list} unexpectedly contains autoreboot"
  else
    pass "${list} has no autoreboot (catalog-only)"
  fi
  # Mic / Camera / Battery Saver remain on default panels
  for tok in mictoggle cameratoggle battery; do
    if list_has_token "$val" "$tok"; then
      pass "${list} retains '${tok}'"
    else
      fail "${list} missing expected '${tok}'"
    fi
  done
done

echo "=== Q-SEC-P3-QS: tile class registration ==="

require_file "$MIC_TILE" "MicrophoneToggleTile"
require_file "$CAM_TILE" "CameraToggleTile"
require_file "$BAT_TILE" "BatterySaverTile"
require_file "$AR_TILE" "AutoRebootTile"
require_file "$AR_MOD" "AutoRebootModule"
require_rg 'TILE_SPEC = "mictoggle"' "$MIC_TILE" "MicrophoneToggleTile TILE_SPEC=mictoggle"
require_rg 'TILE_SPEC = "cameratoggle"' "$CAM_TILE" "CameraToggleTile TILE_SPEC=cameratoggle"
require_rg 'TILE_SPEC = "battery"' "$BAT_TILE" "BatterySaverTile TILE_SPEC=battery"
require_rg 'TILE_SPEC = "autoreboot"' "$AR_TILE" "AutoRebootTile TILE_SPEC=autoreboot"
require_rg 'AutoRebootModule\.class' "$REF_MOD" "ReferenceSystemUIModule includes AutoRebootModule"
require_rg '@StringKey\(AutoRebootTile\.TILE_SPEC\)' "$AR_MOD" \
  "AutoRebootModule binds TILE_SPEC into tileMap"
rg -q 'ro\.guardtalk\.auto_reboot_profiles=1' "$MK" \
  && pass "product prop auto_reboot_profiles=1" \
  || fail "missing product prop auto_reboot_profiles=1"

echo "=== Q-SEC-P3-QS: AutoRebootTile short/long-press contracts ==="

# Short-press: Off ↔ last non-Off (default 8h)
require_rg 'handleClick' "$AR_TILE" "AutoRebootTile.handleClick present"
require_rg 'PREF_LAST_ENABLED_TIMEOUT_MS|guardtalk_qs_auto_reboot_last_timeout_ms' "$AR_TILE" \
  "AutoRebootTile persists last non-Off profile"
require_rg 'PROFILE_OFF_MS' "$AR_TILE" "short-press can set Off (PROFILE_OFF_MS)"
require_rg 'getRestoreTimeoutMs|DEFAULT_PROFILE_MS' "$AR_TILE" \
  "short-press restores last/default profile"
require_rg 'DEFAULT_PROFILE_MS = \(int\) TimeUnit\.HOURS\.toMillis\(8\)' "$AR_POL" \
  "DEFAULT_PROFILE_MS is 8h"
require_rg 'ExtSettings\.AUTO_REBOOT_TIMEOUT' "$AR_TILE" \
  "short-press writes ExtSettings.AUTO_REBOOT_TIMEOUT"

# Long-press: same Security → Auto-reboot deep-link (Exploit protection)
require_rg 'getLongClickIntent' "$AR_TILE" "AutoRebootTile.getLongClickIntent present"
require_rg 'ExploitProtectionActivity' "$AR_TILE" \
  "long-press targets ExploitProtectionActivity"
require_rg 'ExploitProtectionFragment' "$AR_TILE" \
  "long-press shows ExploitProtectionFragment"
require_rg 'ExploitProtectionActivity' "$AR_PREF" \
  "Security Auto-reboot row uses ExploitProtectionActivity"
require_rg 'ExploitProtectionFragment' "$AR_PREF" \
  "Security Auto-reboot row uses ExploitProtectionFragment"

echo "=== Q-SEC-P3-QS: no forbidden Lockdown/USB/Wipe/Duress QS ==="

# Forbidden class names / TILE_SPEC tokens in SystemUI qs tree
if rg -n 'LockdownTile|UsbTile|SecureWipeTile|DuressTile|TILE_SPEC = "lockdown"|TILE_SPEC = "usb"|TILE_SPEC = "wipe"|TILE_SPEC = "duress"' \
  "$QS_DIR" >/dev/null 2>&1; then
  fail "forbidden QS tile class or TILE_SPEC found under SystemUI qs/"
else
  pass "no Lockdown/USB/Wipe/Duress QS tile classes or TILE_SPEC tokens"
fi

# Catalog / default / new_default must not list forbidden tokens as tiles
for list in quick_settings_tiles_stock quick_settings_tiles_default quick_settings_tiles_new_default; do
  val="$(extract_qs_list "$list" "$SYSUI_OV" | tr '[:upper:]' '[:lower:]')"
  bad=0
  for tok in lockdown usb wipe duress; do
    if list_has_token "$val" "$tok"; then
      fail "QS ${list} contains forbidden tile '${tok}'"
      bad=1
    fi
  done
  if [[ $bad -eq 0 ]]; then
    pass "QS ${list} has no Lockdown/USB/Wipe/Duress tokens"
  fi
done

# Docs assert forbidden tiles
require_rg 'Lockdown|USB|Secure wipe|Duress' "$DOC_POL" \
  "QS_TILES_POLICY lists forbidden tiles"
require_rg 'Lockdown|USB|Secure wipe|Duress' "$DOC_ED" \
  "QS_EDITOR_UI_NOTES lists forbidden tiles"
require_rg '[Ff]orbidden tiles absent|lockdown, usb, wipe, duress' "$SYSUI_OV" \
  "overlay comments assert forbidden tiles absent"

echo "=== Q-SEC-P3-QS: product labels (editor + tile) ==="

require_file "$SYSUI_STR" "GuardTalkSystemUIOverlay strings"
require_rg 'name="quick_settings_mic_label">Mic<' "$SYSUI_STR" "label Mic"
require_rg 'name="quick_settings_camera_label">Camera<' "$SYSUI_STR" "label Camera"
require_rg 'name="battery_detail_switch_title">Battery Saver<' "$SYSUI_STR" \
  "label Battery Saver"
require_rg 'name="quick_settings_auto_reboot_label">Auto-reboot<' "$SYSUI_STR" \
  "label Auto-reboot"
require_rg 'Do not introduce Lockdown' "$SYSUI_STR" \
  "strings.xml forbids Lockdown/USB/Wipe/Duress tile strings"

echo "=== Q-SEC-P3-QS: prior green SystemUI / overlay builds (cite) ==="

cite_ok=0
if rg -q 'T-SEC-P3-QS APPROVED' .agent-comm/completed/DONE_LOG.md \
  && rg -q 'm SystemUI green' .agent-comm/completed/DONE_LOG.md; then
  pass "DONE_LOG cites T-SEC-P3-QS m SystemUI green"
  cite_ok=1
else
  fail "DONE_LOG missing T-SEC-P3-QS SystemUI green cite"
fi
if rg -q 'F-SEC-P3-QS-EDITOR APPROVED' .agent-comm/completed/DONE_LOG.md \
  && rg -q 'SystemUI\+overlay green|SystemUI\+overlay EXIT=0|overlay green' \
       .agent-comm/completed/DONE_LOG.md; then
  pass "DONE_LOG cites F-SEC-P3-QS-EDITOR SystemUI+overlay green"
  cite_ok=1
else
  fail "DONE_LOG missing F-SEC-P3-QS-EDITOR overlay green cite"
fi
if rg -q 'm SystemUI' "$DOC_POL" && rg -q 'm SystemUI' "$DOC_ED"; then
  pass "policy/editor docs document m SystemUI verification"
  cite_ok=1
else
  fail "docs missing m SystemUI verification command"
fi
# Root task cards also record EXIT=0
if rg -q 'm SystemUI.*EXIT=0|SystemUI\+overlay EXIT=0' TASK_QUEUE.md; then
  pass "root TASK_QUEUE records Phase-3 SystemUI/overlay EXIT=0"
  cite_ok=1
else
  fail "root TASK_QUEUE missing Phase-3 EXIT=0 cite"
fi
[[ $cite_ok -eq 1 ]] || fail "no prior green SystemUI citations found"

echo "=== SUMMARY ==="
if [[ $FAIL -eq 0 ]]; then
  echo "ALL STATIC CHECKS PASSED"
  echo "PASS_COUNT=${PASS_N} FAIL_COUNT=0 EXIT=0"
  exit 0
fi
echo "SOME CHECKS FAILED"
echo "PASS_COUNT=${PASS_N} FAIL_COUNT>0 EXIT=1"
exit 1
