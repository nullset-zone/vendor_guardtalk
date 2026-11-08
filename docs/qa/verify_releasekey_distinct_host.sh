#!/usr/bin/env bash
# T-EXCISE-RELEASEKEY-DISTINCT-GATE
# Production-release classification. Not wired into verify_remediate_flashready_host.sh.
# Development material (byte match to keys/tokay or the AOSP test pair, or
# ro.build.tags other than release-keys) is HOLD: exit 0, PRODUCTION_RELEASE=false.
# GT_PRODUCTION_RELEASE_CLAIM=1 against that state is FAIL (anti-vacuity).
# PRODUCTION_RELEASE=true only when avb.pem exists, cmp -s says it differs from
# keys/tokay/avb.pem, both releasekey files differ from the AOSP test pair, and
# ro.build.tags=release-keys. This script does not generate or copy keys.
# Fingerprints are sha256 only. PEM and pk8 bytes are never printed.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_releasekey_distinct_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

AVB="vendor/guardtalk/branding/signing-keys/avb.pem"
AVB_DEV="keys/tokay/avb.pem"
REL_CERT="vendor/guardtalk/branding/signing-keys/releasekey.x509.pem"
REL_PK8="vendor/guardtalk/branding/signing-keys/releasekey.pk8"
TEST_CERT="build/make/target/product/security/testkey.x509.pem"
TEST_PK8="build/make/target/product/security/testkey.pk8"
PROP="out/target/product/komodo/system/build.prop"

# cmp -s only. identical = exit 0. distinct = exit 1. absent = missing or cmp error.
cmp_class() {
  local left="$1" right="$2" rc
  if [[ ! -f "$left" || ! -f "$right" ]]; then
    printf '%s\n' absent
    return 0
  fi
  if cmp -s "$left" "$right"; then
    printf '%s\n' identical
  else
    rc=$?
    if [[ "$rc" -eq 1 ]]; then
      printf '%s\n' distinct
    else
      printf '%s\n' absent
    fi
  fi
}

sha256_fp() {
  local f="$1"
  if [[ -f "$f" ]]; then
    sha256sum "$f" | awk '{print $1}'
  else
    printf '%s\n' absent
  fi
}

read_tags() {
  local prop="$1" line value
  if [[ ! -f "$prop" ]]; then
    printf '%s\n' absent
    return 0
  fi
  line="$(grep -E '^ro\.build\.tags=' "$prop" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    printf '%s\n' missing
    return 0
  fi
  value="${line#ro.build.tags=}"
  value="${value//$'\r'/}"
  printf '%s\n' "$value"
}

echo "=== T-EXCISE-RELEASEKEY-DISTINCT-GATE production release classification ==="
echo "ROOT=${ROOT}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "BOOT_VERIFIED=false"
echo "aggregator=not invoked"

avb_c="$(cmp_class "$AVB" "$AVB_DEV")"
cert_c="$(cmp_class "$REL_CERT" "$TEST_CERT")"
pk8_c="$(cmp_class "$REL_PK8" "$TEST_PK8")"
tags="$(read_tags "$PROP")"

echo "avb.pem cmp keys/tokay/avb.pem: ${avb_c}"
echo "avb.pem sha256=$(sha256_fp "$AVB")"
echo "keys/tokay/avb.pem sha256=$(sha256_fp "$AVB_DEV")"
echo "releasekey.x509.pem cmp testkey.x509.pem: ${cert_c}"
echo "releasekey.x509.pem sha256=$(sha256_fp "$REL_CERT")"
echo "testkey.x509.pem sha256=$(sha256_fp "$TEST_CERT")"
echo "releasekey.pk8 cmp testkey.pk8: ${pk8_c}"
echo "releasekey.pk8 sha256=$(sha256_fp "$REL_PK8")"
echo "testkey.pk8 sha256=$(sha256_fp "$TEST_PK8")"
echo "ro.build.tags=${tags}"

production=0
if [[ "$avb_c" == distinct && "$cert_c" == distinct && "$pk8_c" == distinct && "$tags" == "release-keys" ]]; then
  production=1
fi

if [[ "$production" -eq 1 ]]; then
  pass "avb.pem exists and is not byte-identical to keys/tokay/avb.pem"
  pass "releasekey.x509.pem is not byte-identical to the AOSP test cert"
  pass "releasekey.pk8 is not byte-identical to the AOSP test pk8"
  pass "ro.build.tags=release-keys"
  echo "PRODUCTION_RELEASE=true"
  echo "PASS=${PASS_N} HOLD=${HOLD_N} FAIL=${FAIL}"
  echo "RESULT: PASS"
  exit 0
fi

if [[ "$avb_c" == identical ]]; then
  hold "avb.pem matches keys/tokay/avb.pem (development material)"
elif [[ "$avb_c" == absent ]]; then
  hold "distinct avb.pem absent"
fi
if [[ "$cert_c" == identical ]]; then
  hold "releasekey.x509.pem matches AOSP testkey.x509.pem (development material)"
elif [[ "$cert_c" == absent ]]; then
  hold "distinct releasekey.x509.pem absent"
fi
if [[ "$pk8_c" == identical ]]; then
  hold "releasekey.pk8 matches AOSP testkey.pk8 (development material)"
elif [[ "$pk8_c" == absent ]]; then
  hold "distinct releasekey.pk8 absent"
fi
if [[ "$tags" != "release-keys" ]]; then
  hold "ro.build.tags is not release-keys (tags=${tags})"
fi

echo "PRODUCTION_RELEASE=false"

if [[ "${GT_PRODUCTION_RELEASE_CLAIM:-}" == "1" ]]; then
  reason=""
  if [[ "$avb_c" == identical || "$cert_c" == identical || "$pk8_c" == identical ]]; then
    reason="installed material matches development sources"
  fi
  if [[ "$tags" != "release-keys" ]]; then
    if [[ -n "$reason" ]]; then
      reason="${reason}; ro.build.tags is not release-keys"
    else
      reason="ro.build.tags is not release-keys"
    fi
  fi
  if [[ "$avb_c" == absent || "$cert_c" == absent || "$pk8_c" == absent ]]; then
    if [[ -n "$reason" ]]; then
      reason="${reason}; distinct production key absent"
    else
      reason="distinct production key absent"
    fi
  fi
  if [[ -z "$reason" ]]; then
    reason="production release conditions are not met"
  fi
  fail "GT_PRODUCTION_RELEASE_CLAIM=1 refused: ${reason}"
fi

echo "PASS=${PASS_N} HOLD=${HOLD_N} FAIL=${FAIL}"
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: HOLD"
exit 0
