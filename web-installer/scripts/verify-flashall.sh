#!/usr/bin/env bash
# Host rematch for the T-WEBINSTALL-FLASHALL-* lane (INVENTORY + CHANNEL-COMPLETE
# + READINESS-GATE + FRESHNESS). Independent of the frontend lane's claims.
#
# One command, one exit code. Runs the whole chain:
#   1. the generated inventory matrix is up to date (derived, not hand-written)
#   2. the readiness gate -> ONE exit code (summary <=> exit)
#   3. the freshness invariant is wired into that gate
#   4. every advertised device is genuinely packed from a CURRENT stamp
#   5. the FLASHALL test files pass
#   6. tsc --noEmit is clean
#
# No USB. No live flash. No boot-green claim. Never invents a channel.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/web-installer/scripts/verify-flashall.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
WI="${ROOT}/vendor/guardtalk/web-installer"
NODE_BIN="${GT_NODE_BIN:-/home/oss-c1/.cursor-server/bin/linux-x64/2d29876d567da1607532b23bbf2cd5ddbca496f0/node}"
FLASH_DIR="${ROOT}/releases/desktop-flash"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

if [[ ! -x "$NODE_BIN" ]]; then
  echo "FAIL: node not found at GT_NODE_BIN=$NODE_BIN" >&2
  exit 1
fi

echo "=== FLASHALL case1: generated inventory matrix is up to date (derived) ==="
if "$NODE_BIN" "$WI/scripts/gen-flash-matrix.mjs" --check >/tmp/flashall-matrix.log 2>&1; then
  pass "flash-matrix.json is reproducible from the tree ($(grep -o 'packed=[0-9]*.*' /tmp/flashall-matrix.log || true))"
else
  fail "flash-matrix.json has drifted from the tree — regenerate with scripts/gen-flash-matrix.mjs"
  cat /tmp/flashall-matrix.log
fi
if [[ -f "$WI/docs/flash-matrix.json" && -f "$WI/docs/flash-matrix.md" ]]; then
  pass "inventory artifact present (json + md)"
else
  fail "inventory artifact missing under docs/"
fi
if grep -q 'generationCommand' "$WI/docs/flash-matrix.json" \
  && grep -q '"revision"' "$WI/docs/flash-matrix.json"; then
  pass "artifact records its generation command + revision"
else
  fail "artifact does not record generationCommand/revision"
fi

echo "=== FLASHALL case2: readiness gate -> ONE exit code (summary <=> exit) ==="
gate_out="$("$NODE_BIN" "$WI/scripts/readiness-gate.mjs" 2>&1)"; gate_rc=$?
echo "$gate_out"
if [[ -n "$gate_out" ]]; then
  word="$(echo "$gate_out" | sed -n 's/^READINESS-GATE: \([A-Z]*\) (exit \([0-9]*\)).*/\1 \2/p')"
  if [[ -n "$word" ]]; then
    gw="${word% *}"; ge="${word#* }"
    if [[ "$ge" == "$gate_rc" ]] && { [[ "$gw" == "PASS" && "$gate_rc" -eq 0 ]] || [[ "$gw" == "FAIL" && "$gate_rc" -eq 1 ]] || [[ "$gw" == "ERROR" && "$gate_rc" -eq 2 ]]; }; then
      pass "gate summary word '$gw' agrees with exit code $gate_rc"
    else
      fail "gate summary '$gw'/$ge disagrees with exit code $gate_rc (DEC-ARCH-027 divergence)"
    fi
  else
    fail "gate did not print a READINESS-GATE summary line"
  fi
else
  fail "gate produced no output"
fi
if [[ "$gate_rc" -eq 0 ]]; then
  pass "readiness gate PASSES on the current tree"
else
  fail "readiness gate does NOT pass on the current tree (exit $gate_rc)"
fi

echo "=== FLASHALL case3: freshness invariant is wired into the gate ==="
if "$NODE_BIN" "$WI/scripts/readiness-gate.mjs" | grep -q '\[ok\] channel-freshness:'; then
  pass "gate exposes a channel-freshness clause"
else
  fail "gate has no channel-freshness clause"
fi
if grep -q 'channel-freshness.mjs' "$WI/scripts/readiness-gate.mjs"; then
  pass "gate imports the shared freshness module (single implementation)"
else
  fail "gate does not import scripts/channel-freshness.mjs (rule re-implemented)"
fi

echo "=== FLASHALL case4: every advertised device is packed from a CURRENT stamp ==="
advertised="$(sed -n 's/^export const ALLOWED_PRODUCTS = \[\(.*\)\] as const;/\1/p' "$WI/src/types.ts" | tr -d '"' | tr -d ' ' | tr ',' '\n')"
for product in $advertised; do
  ch="${WI}/channels/${product}"
  if [[ ! -f "${ch}/manifest.json" ]]; then
    fail "${product}: advertised but NOT packed (no manifest.json)"
    continue
  fi
  current="$(basename "$(readlink -f "${FLASH_DIR}/${product}-latest" 2>/dev/null || echo "")" 2>/dev/null || true)"
  packed="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["sourceStamp"])' "${ch}/manifest.json")"
  if [[ -n "$current" && "$packed" == "$current" ]]; then
    pass "${product}: packed from CURRENT stamp ${packed}"
  else
    fail "${product}: packed from ${packed} but current stamp is ${current:-<none>} (STALE)"
  fi
  if [[ "$packed" =~ -202607[0-9]{2}- ]]; then
    fail "${product}: July stamp survived the repack (${packed})"
  fi
  if grep -qE 'BEGIN (RSA |EC |OPENSSH )?PRIVATE' "${ch}/avb_pkmd.bin" 2>/dev/null; then
    fail "${product}: avb_pkmd.bin looks like a private key"
  else
    pass "${product}: avb_pkmd.bin is public-only"
  fi
done
if [[ -z "$advertised" ]]; then
  fail "no advertised products parsed from src/types.ts"
fi

echo "=== FLASHALL case5: no stub channel / no secret-shaped file under channels/ ==="
stub="$(find "$WI/channels" -mindepth 1 -maxdepth 1 -type d | while read -r d; do
  [[ -f "$d/manifest.json" ]] || echo "$d"
done)"
if [[ -z "$stub" ]]; then
  pass "no half-built channel dir (every channel has a manifest)"
else
  fail "half-built channel dir(s): $stub"
fi
secrets="$(find "$WI/channels" \( -name '*.pem' -o -name '*.pk8' -o -name '.env' \) -print 2>/dev/null || true)"
if [[ -z "$secrets" ]]; then
  pass "no secret-shaped file under channels/"
else
  fail "secret-shaped file(s) under channels/: $secrets"
fi

echo "=== FLASHALL case6: packer fail-closed paths intact ==="
if bash "$ROOT/vendor/guardtalk/scripts/pack-webinstall-channel.sh" --self-test 2>&1 | grep -q 'SELF_TEST_OK'; then
  pass "packer --self-test SELF_TEST_OK"
else
  fail "packer --self-test did not report SELF_TEST_OK"
fi

echo "=== FLASHALL case7: FLASHALL test files ==="
tests=(test/flash-matrix.test.ts test/channel-complete.test.ts test/readiness-gate.test.ts test/channel-freshness.test.ts)
test_log="$(mktemp)"
if ( cd "$WI" && "$NODE_BIN" ./node_modules/tsx/dist/cli.mjs --test --test-timeout=120000 "${tests[@]}" >"$test_log" 2>&1 ); then
  pass "FLASHALL tests exit 0 ($(grep -E '^# pass' "$test_log" | head -1 || true))"
else
  fail "FLASHALL tests failed"
  tail -30 "$test_log"
fi
rm -f "$test_log"

echo "=== FLASHALL case8: tsc --noEmit ==="
tsc_log="$(mktemp)"
tsc_rc=0
( cd "$WI" && "$NODE_BIN" ./node_modules/typescript/bin/tsc --noEmit >"$tsc_log" 2>&1 ) || tsc_rc=$?
if [[ "$tsc_rc" -eq 0 ]]; then
  pass "tsc --noEmit exit 0"
else
  fail "tsc --noEmit exit $tsc_rc"
  head -20 "$tsc_log"
fi
rm -f "$tsc_log"

echo "=== FLASHALL case9: no live-flash / boot claim ==="
if grep -qE 'export const LIVE_FLASH_CLAIMED = false;' "$WI/src/types.ts"; then
  pass "LIVE_FLASH_CLAIMED = false"
else
  fail "LIVE_FLASH_CLAIMED is not false"
fi
if python3 -c 'import json,sys;s=json.load(open(sys.argv[1]));sys.exit(0 if s["flashCapability"]["liveFlashClaimed"] is False else 1)' "$WI/status.json"; then
  pass "status.json flashCapability.liveFlashClaimed = false"
else
  fail "status.json flashCapability.liveFlashClaimed is not false"
fi
hold "no real USB/WebUSB flash performed; no device attached (BOOT_VERIFIED=false)"

echo ""
echo "=== FLASHALL summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "FLASHALL VERIFY FAILED"
  exit 1
fi
echo "FLASHALL VERIFY PASSED"
exit 0
