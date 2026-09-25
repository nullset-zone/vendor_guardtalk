#!/usr/bin/env bash
# Static + host rematch for Q-WEBINSTALL-DEVICES-INVENTORY.
# Independent of Backend claims. No USB. No picker-UI rematch (that is
# Q-WEBINSTALL-DEVICES-PICKER). Does not claim boot-green or live-flash.
#
# Cases:
#   1. Four latest stamps exist; SHA256SUMS present; listed files exist
#   2. rango-latest still rango-20260802-130756 inode 193110354
#   3. tokay/akita/komodo latest inodes unchanged
#   4. advertised set == tokay+akita+komodo+rango; no extra advertised without stamps
#   5. unstamped shiba/husky/caiman/tegu/comet have no *-latest stamp
#   6. ALLOWED_PRODUCTS / schema enum / packer ADVERTISED_DEVICES match DEC-015
#   7. packer --self-test packs rango; rejects shiba/husky/caiman
#   8. tsc 0; allowlist+channel+hosted-channel (+ QA extras) green
#   9. LIVE_FLASH_CLAIMED=false; no rango boot-green claim
#  10. USB / overlay HOLD (do not invent PASS)
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_webinstall_devices_inventory_static.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"
FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

NODE_BIN="/home/oss-c1/.cursor-server/bin/linux-x64/0c32194e3fb5ffaced9fb36430b860ec301e1fc0"
export PATH="${NODE_BIN}:${PATH}"

FLASH_DIR="releases/desktop-flash"
WI="vendor/guardtalk/web-installer"
PACKER="vendor/guardtalk/scripts/pack-webinstall-channel.sh"
HOSTED="vendor/guardtalk/scripts/pack-wizard-hosted-channels.sh"
TYPES="${WI}/src/types.ts"
ALLOW="${WI}/src/allowlist.ts"
ERRS="${WI}/src/errors.ts"
SCHEMA="${WI}/schema/channel-manifest.schema.json"
EXAMPLE="${WI}/schema/manifest.example.json"
CHANNEL_MD="vendor/guardtalk/docs/WEB_INSTALLER_CHANNEL.md"

EXPECTED_TOKAY="tokay-20260725-102506"
EXPECTED_AKITA="akita-20260725-101434"
EXPECTED_KOMODO="komodo-20260915-063833"
EXPECTED_RANGO="rango-20260802-130756"
EXPECTED_TOKAY_INODE="193110379"
EXPECTED_AKITA_INODE="193110357"
EXPECTED_KOMODO_INODE="193110380"
EXPECTED_RANGO_INODE="193110354"

inode_of() {
  stat -c '%i' "$1"
}

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case1: four latest stamps + SHA256SUMS ==="

declare -A STAMP_LINK=(
  [tokay]="${FLASH_DIR}/latest"
  [akita]="${FLASH_DIR}/akita-latest"
  [komodo]="${FLASH_DIR}/komodo-latest"
  [rango]="${FLASH_DIR}/rango-latest"
)
declare -A STAMP_NAME=(
  [tokay]="$EXPECTED_TOKAY"
  [akita]="$EXPECTED_AKITA"
  [komodo]="$EXPECTED_KOMODO"
  [rango]="$EXPECTED_RANGO"
)
declare -A STAMP_INODE=(
  [tokay]="$EXPECTED_TOKAY_INODE"
  [akita]="$EXPECTED_AKITA_INODE"
  [komodo]="$EXPECTED_KOMODO_INODE"
  [rango]="$EXPECTED_RANGO_INODE"
)

for product in tokay akita komodo rango; do
  link="${STAMP_LINK[$product]}"
  if [[ -L "$link" || -d "$link" ]]; then
    pass "stamp pointer present: $link"
  else
    fail "missing stamp pointer: $link"
    continue
  fi
  target="$(readlink "$link" || true)"
  expected="${STAMP_NAME[$product]}"
  if [[ "$target" == "$expected" ]]; then
    pass "$link -> $expected"
  else
    fail "$link -> '${target}' (expected $expected)"
  fi
  if [[ -f "${link}/SHA256SUMS" ]]; then
    pass "SHA256SUMS present: $product"
  else
    fail "SHA256SUMS missing: ${link}/SHA256SUMS"
  fi
  if [[ -f "${FLASH_DIR}/${expected}/SHA256SUMS" ]]; then
    pass "SHA256SUMS on resolved stamp: $expected"
  else
    fail "SHA256SUMS missing on resolved stamp: ${FLASH_DIR}/${expected}/SHA256SUMS"
  fi
  inode="$(inode_of "$link" 2>/dev/null || echo "")"
  want="${STAMP_INODE[$product]}"
  if [[ "$inode" == "$want" ]]; then
    pass "$product latest inode $inode"
  else
    fail "$product latest inode '${inode}' (expected $want) — stamp may have been retargeted"
  fi
done

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case2: SHA256SUMS listed files exist (no invented devices) ==="

for product in tokay akita komodo rango; do
  link="${STAMP_LINK[$product]}"
  sums="${link}/SHA256SUMS"
  [[ -f "$sums" ]] || continue
  missing=0
  while read -r _hash fname; do
    [[ -z "${fname:-}" ]] && continue
    if [[ ! -e "${link}/${fname}" ]]; then
      echo "  missing listed file: ${product}/${fname}"
      missing=$((missing + 1))
    fi
  done < <(awk '{print $1, $2}' "$sums")
  if [[ "$missing" -eq 0 ]]; then
    count="$(grep -cE '^[a-f0-9]{64} ' "$sums" || true)"
    pass "$product SHA256SUMS listed files exist (entries=$count)"
  else
    fail "$product SHA256SUMS lists $missing missing files"
  fi
done

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case3: no extra advertised devices without stamps ==="

# Advertised set is exactly the four. Any other *-latest must not be treated as advertised.
extra_latest="$(find "$FLASH_DIR" -maxdepth 1 \( -type l -o -type d \) -printf '%f\n' \
  | grep -E '^(latest|.+-latest)$' \
  | grep -Ev '^(latest|akita-latest|komodo-latest|rango-latest)$' \
  || true)"
if [[ -z "$extra_latest" ]]; then
  pass "no extra *-latest pointers beyond tokay/akita/komodo/rango"
else
  # Extra stamp pointers are OK only if they are NOT advertised.
  echo "  extra latest pointers: $extra_latest"
  hold "extra *-latest pointers exist but are not in DEC-015 advertised set (not a FAIL unless advertised)"
fi

for unstamped in shiba husky caiman tegu comet; do
  if [[ -e "${FLASH_DIR}/${unstamped}-latest" ]]; then
    fail "unstamped product has a *-latest pointer that must not be advertised: ${unstamped}-latest"
  else
    pass "no ${unstamped}-latest stamp pointer"
  fi
done

# Source allowlist must not advertise anything without a stamp.
if grep -Eq 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo", "rango"\]' "$TYPES"; then
  pass "ALLOWED_PRODUCTS source = tokay, akita, komodo, rango"
else
  fail "ALLOWED_PRODUCTS source unexpected ($TYPES)"
fi

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case4: schema enum + maxItems + reservedProducts ==="

if python3 - "$SCHEMA" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
enum = p["properties"]["product"]["enum"]
items = p["properties"]["advertisedDevices"]["items"]["enum"]
max_items = p["properties"]["advertisedDevices"]["maxItems"]
reserved_not = p["properties"]["reservedProducts"]["items"]["not"]["enum"]
want = ["tokay", "akita", "komodo", "rango"]
ok = enum == want and items == want and reserved_not == want and max_items >= 4
sys.exit(0 if ok else 1)
PY
then
  pass "schema product/advertisedDevices enum = tokay,akita,komodo,rango; maxItems>=4; reservedProducts forbids those four"
else
  fail "schema enum/maxItems/reservedProducts does not match DEC-WEBINSTALL-015"
fi

if python3 -c 'import json,sys; json.load(open("'"$EXAMPLE"'")); print("ok")' >/dev/null; then
  pass "manifest.example.json parses"
else
  fail "manifest.example.json is not valid JSON"
fi

if python3 - "$EXAMPLE" <<'PY'
import json, sys
ex = json.load(open(sys.argv[1]))
ok = ex.get("product") in ("tokay", "akita", "komodo", "rango")
ok = ok and isinstance(ex.get("advertisedDevices"), list)
ok = ok and all(d in ("tokay", "akita", "komodo", "rango") for d in ex["advertisedDevices"])
ok = ok and "shiba" not in ex["advertisedDevices"]
sys.exit(0 if ok else 1)
PY
then
  pass "manifest.example.json advertisedDevices subset of DEC-015"
else
  fail "manifest.example.json advertises a product outside DEC-015"
fi

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case5: packer allowlist + self-test ==="

if grep -Eq 'readonly ADVERTISED_DEVICES=\(tokay akita komodo rango\)' "$PACKER"; then
  pass "packer ADVERTISED_DEVICES = tokay akita komodo rango"
else
  fail "packer ADVERTISED_DEVICES unexpected"
fi

if grep -q 'pack_channel "$rango_stamp"' "$PACKER" \
  && grep -q 'rango-dev pointer missing' "$PACKER"; then
  pass "packer self-test packs rango and requires rango-dev pointer"
else
  fail "packer self-test missing rango pack / rango-dev pointer"
fi

if grep -q 'for unstamped in shiba husky caiman' "$PACKER"; then
  pass "packer self-test rejects shiba/husky/caiman"
else
  fail "packer self-test missing unstamped reject loop"
fi

if grep -q 'pack_one rango' "$HOSTED" \
  && grep -q 'rango-latest' "$HOSTED"; then
  pass "hosted packer includes rango from rango-latest"
else
  fail "hosted packer missing rango line"
fi

if bash -n "$PACKER"; then
  pass "bash -n pack-webinstall-channel.sh"
else
  fail "bash -n pack-webinstall-channel.sh"
fi
if bash -n "$HOSTED"; then
  pass "bash -n pack-wizard-hosted-channels.sh"
else
  fail "bash -n pack-wizard-hosted-channels.sh"
fi

packer_log="$(mktemp)"
if bash "$PACKER" --self-test >"$packer_log" 2>&1; then
  if grep -q 'SELF_TEST_OK' "$packer_log"; then
    pass "packer --self-test SELF_TEST_OK"
  else
    fail "packer --self-test exit 0 but missing SELF_TEST_OK"
  fi
else
  fail "packer --self-test exit non-zero"
  cat "$packer_log"
fi
rm -f "$packer_log"

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case6: tsc + tsx allowlist/channel/hosted (+ QA extras) ==="

if [[ -x "${WI}/node_modules/.bin/tsc" ]]; then
  tsc_log="$(mktemp)"
  tsc_rc=0
  ( cd "$WI" && ./node_modules/.bin/tsc --noEmit --pretty false >"$tsc_log" 2>&1 ) || tsc_rc=$?
  if [[ "$tsc_rc" -eq 0 ]]; then
    pass "tsc --noEmit 0"
  else
    # Inventory card: picker/routes tests may be mid-edit (F parallel). Those are
    # HOLD/INFO, not T FAIL. Errors in allowlist/schema/channel src remain FAIL.
    inv_hits="$(grep -E '^(src/|schema/|test/allowlist|test/channel|test/hosted-channel|test/devices-inventory|test/claims)' "$tsc_log" || true)"
    if [[ -n "$inv_hits" ]]; then
      fail "tsc --noEmit non-zero on inventory paths"
      echo "$inv_hits"
    else
      hold "tsc --noEmit non-zero only on picker/route files (F-WEBINSTALL-DEVICES-PICKER race; not this inventory FAIL)"
      head -20 "$tsc_log"
    fi
  fi
  rm -f "$tsc_log"
else
  fail "tsc binary missing under ${WI}/node_modules"
fi

tsx_files=(test/allowlist.test.ts test/channel.test.ts test/hosted-channel.test.ts)
if [[ -f "${WI}/test/devices-inventory.test.ts" ]]; then
  tsx_files+=(test/devices-inventory.test.ts)
fi
tsx_log="$(mktemp)"
if ( cd "$WI" && ./node_modules/.bin/tsx --test "${tsx_files[@]}" >"$tsx_log" 2>&1 ); then
  pass "tsx inventory tests exit 0"
  grep -E '# (tests|pass|fail|cancelled|skipped|todo)' "$tsx_log" || true
else
  fail "tsx inventory tests failed"
  cat "$tsx_log"
fi
rm -f "$tsx_log"

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case7: WrongProductError + rango accepted in source ==="

if grep -q 'ALLOWED_PRODUCTS.join' "$ERRS"; then
  pass "WrongProductError lists ALLOWED_PRODUCTS"
else
  fail "WrongProductError does not join ALLOWED_PRODUCTS"
fi

if grep -q 'assertAllowedProduct' "$ALLOW" \
  && grep -q 'experimental / boot HOLD' "$ALLOW"; then
  pass "allowlist comments rango experimental / boot HOLD"
else
  fail "allowlist missing rango HOLD comment"
fi

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case8: LIVE_FLASH_CLAIMED + no boot-green claim ==="

if grep -Eq 'export const LIVE_FLASH_CLAIMED = false;' "$TYPES"; then
  pass "LIVE_FLASH_CLAIMED = false"
else
  fail "LIVE_FLASH_CLAIMED is not false"
fi
if grep -Eq 'LIVE_FLASH_CLAIMED = true' "$TYPES"; then
  fail "LIVE_FLASH_CLAIMED = true present"
else
  pass "no LIVE_FLASH_CLAIMED = true"
fi

# Positive boot-green claim (not the documented negation).
boot_green_hits="$(grep -nE 'rango.{0,40}(is|as) (production-)?boot-green|(production-)?boot-green.{0,40}rango' \
  "$TYPES" "$ALLOW" "$SCHEMA" "$PACKER" "$CHANNEL_MD" 2>/dev/null \
  | grep -viE 'not |no |never |do not |must not |forbid' \
  || true)"
if [[ -z "$boot_green_hits" ]]; then
  pass "no positive rango boot-green claim in inventory sources"
else
  fail "positive rango boot-green claim: $boot_green_hits"
fi

if grep -q 'experimental / boot HOLD' "$TYPES" \
  && grep -q 'not production-boot-green' "$TYPES"; then
  pass "types.ts chips rango experimental / boot HOLD, not boot-green"
else
  fail "types.ts missing rango HOLD / not-boot-green chip"
fi

if grep -q 'Do not claim rango boot-green' "$CHANNEL_MD"; then
  pass "WEB_INSTALLER_CHANNEL.md forbids rango boot-green claim"
else
  fail "WEB_INSTALLER_CHANNEL.md missing boot-green forbid"
fi

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case9: historical closed-Q pin (residual, not this card) ==="

hist1="vendor/guardtalk/docs/qa/verify_rango_boot_remediate_static.sh"
hist2="vendor/guardtalk/docs/qa/verify_pixel9_nonregression_static.sh"
if grep -q 'rango not advertised' "$hist1" \
  && grep -q 'no rango advertise' "$hist2"; then
  hold "historical Q-RANGO-BOOT-REMEDIATE / Q-PIXEL9-NONREGRESSION verifiers still pin pre-DEC-015 advertise (superseded residual; not this card FAIL)"
else
  fail "historical closed-Q advertise-reject-rango pins not found (unexpected; rematch the residual)"
fi

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case9b: picker/dist residual (other card) ==="

DIST_TYPES="${WI}/dist/src/types.js"
if [[ -f "$DIST_TYPES" ]] && grep -Eq 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo"\]' "$DIST_TYPES"; then
  hold "dist/src/types.js still tokay+akita+komodo (served picker rebuild is Q-WEBINSTALL-DEVICES-PICKER / F, not this inventory rematch)"
elif [[ -f "$DIST_TYPES" ]] && grep -Eq 'ALLOWED_PRODUCTS = \["tokay", "akita", "komodo", "rango"\]' "$DIST_TYPES"; then
  pass "dist ALLOWED_PRODUCTS already includes rango (picker card still owns UI rematch)"
else
  hold "dist/src/types.js absent or unexpected — picker rematch is a different card"
fi

WIZARD_DEV="${WI}/wizard/devices.ts"
if grep -q 'Rango / shiba / husky / caiman are not offered' "$WIZARD_DEV" \
  || grep -q 'rango stays hidden' "${WI}/routes/install/early-steps.ts"; then
  hold "picker copy still hides rango (F-WEBINSTALL-DEVICES-PICKER / Q-PICKER; not this inventory FAIL)"
else
  hold "picker copy may already include rango — UI rematch still belongs to Q-WEBINSTALL-DEVICES-PICKER"
fi

echo "=== Q-WEBINSTALL-DEVICES-INVENTORY case10: USB / overlay HOLD ==="

if command -v adb >/dev/null 2>&1; then
  adb_out="$(adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1}')"
  if [[ -n "$adb_out" ]]; then
    hold "adb device(s) present but USB flash NOT executed (dispatch: USB HOLD)"
  else
    hold "adb present but no device — USB E2E HOLD (not invent PASS)"
  fi
else
  hold "adb binary unavailable — USB E2E HOLD"
fi

if [[ -z "${DISPLAY:-}" ]]; then
  hold "overlay HOLD — DISPLAY unset (no host browser rematch; picker is Q-WEBINSTALL-DEVICES-PICKER)"
else
  hold "overlay HOLD — picker UI rematch is a different card (Q-WEBINSTALL-DEVICES-PICKER)"
fi
hold "no live-flash PASS; no boot-green PASS (DEC-009 / DEC-WEBINSTALL-015)"

echo ""
echo "=== Q-WEBINSTALL-DEVICES-INVENTORY static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
