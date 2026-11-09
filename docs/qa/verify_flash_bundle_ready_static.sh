#!/usr/bin/env bash
# Q-FLASH-READY-GATE — fail-closed "is this desktop-flash bundle actually
# flash-ready?" gate. Read-only. No flash. No device. No m. No commit.
#
# WHY THIS EXISTS (both defects shipped, both found by hand, late):
#   1. tangorpro-20261108-115310 was missing bootloader.img — and BOTH flashers
#      flash bootloader.img as step one. A bundle without it cannot be flashed.
#   2. That same bundle's copied flash-tangorpro.sh still had
#      REMOTE_DIR=".../tangorpro-20261018-123446" (the PREVIOUS stamp). Running
#      it on the Mac would have scp'd the camera-broken image and flashed THAT,
#      while the operator believed they were flashing the new build. Copying a
#      file does not rewrite the paths inside it.
#   Neither was caught by any of the existing gates. This gate closes both.
#
# FAIL CLOSED: every check below fails on "cannot determine", never on silence.
# A gate that cannot fail is not evidence.
#
# HOLD is reserved for what needs hardware (this host cannot reach the tablet).
# WARN is used only where the card says so (repacked-but-equivalent out/ images).
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_flash_bundle_ready_static.sh
#   bash vendor/guardtalk/docs/qa/verify_flash_bundle_ready_static.sh <bundle-dir>
#   EXPECT_FINGERPRINT='google/tangorpro/tangorpro:Baklava/BP4A.260205.001/eng.oss-c1:userdebug/test-keys' \
#     bash vendor/guardtalk/docs/qa/verify_flash_bundle_ready_static.sh <bundle-dir>
#
# Env overrides:
#   EXPECT_FINGERPRINT  optional. If unset, check 5 SKIPs with a loud line.
#   DEVICE              optional. Default: derived from the bundle basename.
#   AVBTOOL             optional. Default: out/host/linux-x86/bin/avbtool.
#
# Exit code = failure count (capped at 125 so it can never wrap to 0).
#   0  = every enforceable check passed (SKIP/HOLD/WARN permitted, and listed)
#   n  = n checks failed. Never silently PASS.
#
# IMPLEMENTATION NOTES (verified on this host, 2026-11-08):
#   * The card writes `avbtool verify_image --follow_chain`. This host's avbtool
#     (1.3.0) spells it `--follow_chain_partitions`; `--follow_chain` only works
#     by argparse prefix-abbreviation. This script probes --help and uses the
#     full spelling when present, so it cannot break on either.
#   * `avbtool verify_image --key <avb_pkmd.bin>` does NOT work: avbtool wants an
#     RSA *private key* PEM there, and errors "Could not read public key from
#     <blob>". So check 6 binds the blob to vbmeta by a stronger equivalent:
#     sha1(avb_pkmd.bin) == the "Public key (sha1)" that avbtool reads out of the
#     vbmeta image's own authentication block. That is a real cryptographic
#     binding, not a header sniff. The header/size sniff is kept as well, and
#     --key is still attempted and reported.
#   * `verify_image` resolves each descriptor's partition image relative to the
#     vbmeta image's own directory. Because check 1 passes the bundle's vbmeta,
#     the descriptors are checked against the COPIED images — which is the whole
#     point (a copy is not a re-sign).
#   * A vbmeta with zero descriptors makes `verify_image` succeed vacuously, so
#     check 1 also requires at least one "Successfully verified" descriptor line.
#
# READ-ONLY: this script opens files under releases/ and out/ for reading only.
# It never redirects into them, never uses mktemp inside them, and writes nothing
# to disk at all (all captures are shell variables). Seeded-defect testing is
# done by the QA operator on a throwaway copy under /tmp, not by this script.
#
# NOT CLAIMED BY THIS GATE: that the tablet boots. Integrity of a bundle on disk
# says nothing about a device. BOOT_VERIFIED=false always, here.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL_N=0
PASS_N=0
WARN_N=0
HOLD_N=0
SKIP_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL_N=$((FAIL_N + 1)); }
warn() { echo "WARN: $*"; WARN_N=$((WARN_N + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }
skip() { echo "SKIP: $*"; SKIP_N=$((SKIP_N + 1)); }

finish() {
  echo
  echo "=== SUMMARY ==="
  echo "BUNDLE=${BUNDLE:-<unresolved>}"
  echo "PASS_COUNT=${PASS_N} FAIL_COUNT=${FAIL_N} WARN_COUNT=${WARN_N} HOLD_COUNT=${HOLD_N} SKIP_COUNT=${SKIP_N}"
  echo "FLASHED=nothing  DEVICE=not touched  M_BUILD=not started"
  echo "BOOT_VERIFIED=false"
  echo "READ_ONLY=true (no writes to releases/ or out/ by this script)"
  if [[ "${FAIL_N}" -ne 0 ]]; then
    local rc="${FAIL_N}"
    if [[ "${rc}" -gt 125 ]]; then
      rc=125
      echo "NOTE: failure count ${FAIL_N} exceeds 125; exit code capped at 125 so it cannot wrap to 0."
    fi
    echo "RESULT: FAIL"
    exit "${rc}"
  fi
  echo "RESULT: PASS (bundle integrity on disk only — still BOOT_VERIFIED=false)"
  exit 0
}

# ---------------------------------------------------------------- bundle arg
BUNDLE_ARG="${1:-releases/desktop-flash/tangorpro-latest}"
BUNDLE_INPUT="${BUNDLE_ARG}"
if [[ "${BUNDLE_ARG}" != /* ]]; then
  BUNDLE_INPUT="${ROOT}/${BUNDLE_ARG}"
fi

echo "=== Q-FLASH-READY-GATE : desktop-flash bundle readiness (fail-closed) ==="
echo "ROOT=${ROOT}"
echo "BUNDLE_ARG=${BUNDLE_ARG}"
echo "LIVE_DEVICE_CLAIMED=false"
echo "FLASH=not started"
echo "BOOT_VERIFIED=false"
echo "READ_ONLY=true"
echo

if [[ ! -e "${BUNDLE_INPUT}" ]]; then
  fail "BUNDLE does not exist: ${BUNDLE_INPUT} (fail closed: nothing to verify)"
  echo "HINT: default is releases/desktop-flash/tangorpro-latest; pass a bundle dir as \$1."
  finish
fi
if [[ ! -d "${BUNDLE_INPUT}" ]]; then
  fail "BUNDLE is not a directory: ${BUNDLE_INPUT}"
  finish
fi

# -P resolves the tangorpro-latest symlink so the basename checks are honest.
BUNDLE="$(cd "${BUNDLE_INPUT}" && pwd -P)"
BUNDLE_BASE="$(basename "${BUNDLE}")"
BUNDLE_BASE_GIVEN="$(basename "$(cd "$(dirname "${BUNDLE_INPUT}")" && pwd -P)/$(basename "${BUNDLE_INPUT}")")"
DEVICE="${DEVICE:-$(printf '%s' "${BUNDLE_BASE}" | cut -d- -f1)}"
echo "BUNDLE=${BUNDLE}"
echo "BUNDLE_BASENAME=${BUNDLE_BASE}"
echo "DEVICE=${DEVICE}"
echo

# ------------------------------------------------------------------- avbtool
AVBTOOL="${AVBTOOL:-${ROOT}/out/host/linux-x86/bin/avbtool}"
HAVE_AVBTOOL=1
if [[ ! -x "${AVBTOOL}" ]]; then
  if command -v avbtool >/dev/null 2>&1; then
    AVBTOOL="$(command -v avbtool)"
  else
    HAVE_AVBTOOL=0
  fi
fi
echo "AVBTOOL=${AVBTOOL} present=$([[ "${HAVE_AVBTOOL}" -eq 1 ]] && echo yes || echo no)"
if [[ "${HAVE_AVBTOOL}" -eq 1 ]]; then
  echo "AVBTOOL_VERSION=$("${AVBTOOL}" version 2>/dev/null || echo unknown)"
fi
echo

# ===========================================================================
# CHECK 1 — AVB chain verifies on the COPIED bundle (not out/)
# ===========================================================================
# WHY: copying a file does not re-sign it. If the copy is truncated, was the
# wrong file, or is a stale sibling, the descriptor digest will not match. Doing
# this on out/ would prove the build is good, not that THIS bundle is good — and
# the bundle is what gets scp'd and flashed.
echo "--- CHECK 1: AVB chain verifies on the copied bundle ---"
echo "    why: a copy is not a re-sign; verify the artifact that will ship, not out/"
VB="${BUNDLE}/vbmeta.img"
if [[ ! -f "${VB}" ]]; then
  fail "CHECK 1: vbmeta.img missing at ${VB} — cannot verify the chain at all"
elif [[ ! -s "${VB}" ]]; then
  fail "CHECK 1: vbmeta.img is zero bytes at ${VB}"
elif [[ "${HAVE_AVBTOOL}" -ne 1 ]]; then
  fail "CHECK 1: avbtool not found (looked at out/host/linux-x86/bin/avbtool and PATH) — cannot verify, fail closed"
else
  AVB_HELP="$("${AVBTOOL}" verify_image --help 2>&1 || true)"
  FOLLOW=""
  if printf '%s' "${AVB_HELP}" | grep -q -- '--follow_chain_partitions'; then
    FOLLOW="--follow_chain_partitions"
  elif printf '%s' "${AVB_HELP}" | grep -q -- '--follow_chain'; then
    FOLLOW="--follow_chain"
  fi
  echo "    follow_flag=${FOLLOW:-<none: probing older avbtool>}"

  set +e
  if [[ -n "${FOLLOW}" ]]; then
    VERIFY_OUT="$("${AVBTOOL}" verify_image --image "${VB}" "${FOLLOW}" 2>&1)"
  else
    VERIFY_OUT="$("${AVBTOOL}" verify_image --image "${VB}" 2>&1)"
  fi
  VERIFY_RC=$?
  set -e

  printf '%s\n' "${VERIFY_OUT}" | sed 's/^/    | /'
  VERIFIED_N="$(printf '%s\n' "${VERIFY_OUT}" | grep -c 'Successfully verified' || true)"
  FROM_BUNDLE_N="$(printf '%s\n' "${VERIFY_OUT}" | grep -c -- "${BUNDLE}/" || true)"

  if [[ "${VERIFY_RC}" -ne 0 ]]; then
    fail "CHECK 1: avbtool verify_image exit ${VERIFY_RC} on the copied bundle — AVB chain is broken in THIS bundle"
  elif [[ "${VERIFIED_N}" -eq 0 ]]; then
    fail "CHECK 1: verify_image exit 0 but zero 'Successfully verified' descriptors — vacuous success (empty/descriptor-less vbmeta). Fail closed."
  elif [[ "${FROM_BUNDLE_N}" -eq 0 ]]; then
    fail "CHECK 1: verify_image verified ${VERIFIED_N} item(s) but none referenced ${BUNDLE}/ — it did not read the copied images. Fail closed."
  else
    pass "CHECK 1: AVB chain verified on the copied bundle (${VERIFIED_N} descriptors, ${FROM_BUNDLE_N} paths under ${BUNDLE})"
  fi
fi
echo

# ===========================================================================
# CHECK 2 — SHA256SUMS present, every line verifies, no unlisted *.img
# ===========================================================================
# WHY: SHA256SUMS is the only integrity record an operator can check with no
# tooling beyond coreutils. A missing line is an unverified image; a failing
# line is a corrupt or swapped image. Both must stop a flash.
echo "--- CHECK 2: SHA256SUMS present and complete ---"
echo "    why: an unlisted or mismatching image is an unverified image"
SUMS="${BUNDLE}/SHA256SUMS"
if [[ ! -f "${SUMS}" ]]; then
  fail "CHECK 2: SHA256SUMS missing at ${SUMS}"
elif [[ ! -s "${SUMS}" ]]; then
  fail "CHECK 2: SHA256SUMS is empty at ${SUMS}"
else
  # 2a. Refuse checksum files that point outside the bundle. A checksum list is
  # data, and data that names /etc/passwd or ../../x is not a bundle manifest.
  ESCAPING="$(awk 'NF>=2 {n=$2; sub(/^\*/,"",n); if (n ~ /^\// || n ~ /\.\.\//) print NR": "$2}' "${SUMS}" || true)"
  if [[ -n "${ESCAPING}" ]]; then
    fail "CHECK 2: SHA256SUMS references paths outside the bundle (refuse to treat as a bundle manifest): $(printf '%s' "${ESCAPING}" | tr '\n' ';')"
  else
    pass "CHECK 2: no SHA256SUMS entry escapes the bundle directory"
  fi

  # 2b. Every line must verify. --strict also rejects malformed lines; fall back
  # if this coreutils is too old to know the flag.
  STRICT=""
  if sha256sum --help 2>/dev/null | grep -q -- '--strict'; then
    STRICT="--strict"
  fi
  set +e
  SUMS_OUT="$(cd "${BUNDLE}" && sha256sum -c ${STRICT} SHA256SUMS 2>&1)"
  SUMS_RC=$?
  set -e
  printf '%s\n' "${SUMS_OUT}" | sed 's/^/    | /'
  SUMS_LINES="$(printf '%s\n' "${SUMS_OUT}" | grep -c 'OK$' || true)"
  SUMS_BAD="$(printf '%s\n' "${SUMS_OUT}" | grep -v ': OK$' | grep -v '^$' || true)"
  if [[ "${SUMS_RC}" -ne 0 || -n "${SUMS_BAD}" ]]; then
    fail "CHECK 2: sha256sum -c FAILED (exit ${SUMS_RC}). Non-OK lines: $(printf '%s' "${SUMS_BAD}" | head -n 10 | tr '\n' ';')"
  elif [[ "${SUMS_LINES}" -eq 0 ]]; then
    fail "CHECK 2: sha256sum -c reported zero OK lines — vacuous pass. Fail closed."
  else
    pass "CHECK 2: all ${SUMS_LINES} SHA256SUMS entries verify"
  fi

  # 2c. Every *.img in the directory must be listed. Done entirely in shell
  # variables (no temp files) so this script writes nothing anywhere.
  LISTED_NAMES="$(awk 'NF>=2 {n=$2; sub(/^\*/,"",n); sub(/^\.\//,"",n); print n}' "${SUMS}")"
  UNLISTED=""
  while IFS= read -r img; do
    [[ -n "${img}" ]] || continue
    if ! printf '%s\n' "${LISTED_NAMES}" | grep -Fxq -- "${img}"; then
      UNLISTED="${UNLISTED}${img} "
    fi
  done < <( cd "${BUNDLE}" && find . -maxdepth 1 \( -type f -o -type l \) -name '*.img' -printf '%f\n' )

  # 2d. And the reverse: a listed file that does not exist is a manifest lie.
  MISSING_FILE=""
  while IFS= read -r n; do
    [[ -n "${n}" ]] || continue
    [[ -e "${BUNDLE}/${n}" ]] || MISSING_FILE="${MISSING_FILE}${n} "
  done <<< "${LISTED_NAMES}"

  if [[ -n "${UNLISTED}" ]]; then
    fail "CHECK 2: image(s) present but NOT in SHA256SUMS (unverified): ${UNLISTED}"
  else
    pass "CHECK 2: every *.img in the bundle is listed in SHA256SUMS"
  fi
  if [[ -n "${MISSING_FILE}" ]]; then
    fail "CHECK 2: SHA256SUMS lists file(s) that do not exist: ${MISSING_FILE}"
  else
    pass "CHECK 2: every SHA256SUMS entry names a file that exists"
  fi
fi
echo

# ===========================================================================
# CHECK 3 — bootloader.img is present
# ===========================================================================
# WHY: this was missing from tangorpro-20261108-115310. Both flashers flash
# bootloader.img as step one, so the flash hard-fails halfway with the device
# already in bootloader — the worst moment to discover a missing file.
echo "--- CHECK 3: bootloader.img present ---"
echo "    why: both flashers flash bootloader.img FIRST; absent = unfinishable flash"
BL="${BUNDLE}/bootloader.img"
if [[ ! -e "${BL}" ]]; then
  fail "CHECK 3: bootloader.img MISSING at ${BL} — this bundle cannot be flashed (step one of both flashers)"
elif [[ ! -f "${BL}" ]]; then
  fail "CHECK 3: ${BL} exists but is not a regular file"
elif [[ ! -s "${BL}" ]]; then
  fail "CHECK 3: ${BL} is zero bytes — present in name only"
else
  pass "CHECK 3: bootloader.img present ($(stat -c '%s' "${BL}") bytes, sha256 $(sha256sum "${BL}" | cut -c1-16)...)"
fi
echo

# ===========================================================================
# CHECK 4 — the bundle's own flash-*.sh has REMOTE_DIR pointing at THIS bundle
# ===========================================================================
# WHY: this is the defect that actually shipped. flash-tangorpro.sh inside
# tangorpro-20261108-115310 still said
#   REMOTE_DIR=".../releases/desktop-flash/tangorpro-20261018-123446"
# because the file was COPIED from the previous stamp, not regenerated. Running
# it would scp the OLD (camera-broken) stamp and flash that, while the operator
# believed they were flashing the new build. Silent wrong-image flash: the worst
# failure class here. Basename comparison is the cheap, exact test.
echo "--- CHECK 4: copied flash script targets THIS bundle ---"
echo "    why: a copied flasher keeps the OLD stamp path; running it flashes the wrong image"
shopt -s nullglob
FLASHERS=("${BUNDLE}"/flash-*.sh)
shopt -u nullglob
if [[ ${#FLASHERS[@]} -eq 0 ]]; then
  skip "CHECK 4: no flash-*.sh inside the bundle — nothing to cross-check (operator must use scripts/flash-from-remote.sh)"
else
  for FL in "${FLASHERS[@]}"; do
    FL_BASE="$(basename "${FL}")"
    # Count assignments: more than one means the effective value is order
    # dependent, which a gate must not guess about.
    RD_LINES="$(grep -nE '^[[:space:]]*(export[[:space:]]+)?REMOTE_DIR=' "${FL}" || true)"
    RD_N="$(printf '%s\n' "${RD_LINES}" | grep -c 'REMOTE_DIR=' || true)"
    if [[ "${RD_N}" -eq 0 ]]; then
      fail "CHECK 4: ${FL_BASE} present but has no REMOTE_DIR= assignment — cannot prove it targets this bundle. Fail closed."
      continue
    fi
    if [[ "${RD_N}" -gt 1 ]]; then
      fail "CHECK 4: ${FL_BASE} assigns REMOTE_DIR ${RD_N} times — effective target is order-dependent, refuse to guess: $(printf '%s' "${RD_LINES}" | tr '\n' ';')"
      continue
    fi
    RD_RAW="${RD_LINES#*REMOTE_DIR=}"
    # Strip CR (a Mac-facing script may be CRLF) and surrounding whitespace, then
    # the quotes. Without the CR/whitespace strip, a correct bundle with a CRLF or
    # trailing-space line would FAIL here — a false positive that would block a
    # legitimate flash, which is its own kind of gate failure.
    RD_RAW="${RD_RAW%$'\r'}"
    RD_RAW="${RD_RAW#"${RD_RAW%%[![:space:]]*}"}"
    RD_RAW="${RD_RAW%"${RD_RAW##*[![:space:]]}"}"
    RD_RAW="${RD_RAW#\"}"; RD_RAW="${RD_RAW%\"}"
    RD_RAW="${RD_RAW#\'}"; RD_RAW="${RD_RAW%\'}"
    RD_RAW="${RD_RAW%$'\r'}"
    RD_RAW="${RD_RAW%"${RD_RAW##*[![:space:]]}"}"
    RD_BASE="$(basename "${RD_RAW}")"
    echo "    ${FL_BASE}: REMOTE_DIR=${RD_RAW}"
    echo "    ${FL_BASE}: REMOTE_DIR basename=${RD_BASE}"
    # Accept either the literal bundle name as passed, or the resolved name
    # (the default arg is the tangorpro-latest symlink).
    if [[ "${RD_BASE}" == "${BUNDLE_BASE}" || "${RD_BASE}" == "${BUNDLE_BASE_GIVEN}" ]]; then
      pass "CHECK 4: ${FL_BASE} REMOTE_DIR basename '${RD_BASE}' == this bundle — it will scp the right stamp"
    else
      fail "CHECK 4: ${FL_BASE} REMOTE_DIR basename '${RD_BASE}' != this bundle '${BUNDLE_BASE}' — RUNNING THIS SCRIPT WOULD FLASH A DIFFERENT STAMP"
    fi
  done
fi
echo

# ===========================================================================
# CHECK 5 — vbmeta embedded build fingerprint matches EXPECT_FINGERPRINT
# ===========================================================================
# WHY: proves the vbmeta in the bundle is the build the operator intended, not
# a sibling stamp's vbmeta dropped in during a copy. Optional because the
# expected value is operator intent, not something derivable from disk.
echo "--- CHECK 5: vbmeta build fingerprint matches expected ---"
echo "    why: a sibling stamp's vbmeta dropped into this dir looks fine until boot"
EXPECT_FP="${EXPECT_FINGERPRINT:-}"
if [[ -z "${EXPECT_FP}" ]]; then
  skip "CHECK 5: SKIP — EXPECT_FINGERPRINT is unset. Fingerprint is operator intent, not derivable from disk. Re-run with EXPECT_FINGERPRINT='<build fingerprint>' to enforce this check."
elif [[ "${HAVE_AVBTOOL}" -ne 1 ]]; then
  fail "CHECK 5: EXPECT_FINGERPRINT set but avbtool unavailable — cannot extract, fail closed"
elif [[ ! -f "${VB}" ]]; then
  fail "CHECK 5: EXPECT_FINGERPRINT set but vbmeta.img missing — cannot extract, fail closed"
else
  set +e
  INFO_OUT="$("${AVBTOOL}" info_image --image "${VB}" 2>&1)"
  INFO_RC=$?
  set -e
  if [[ "${INFO_RC}" -ne 0 ]]; then
    fail "CHECK 5: avbtool info_image exit ${INFO_RC} — cannot read vbmeta props"
  else
    FP_LINE="$(printf '%s\n' "${INFO_OUT}" | grep -F 'com.android.build.system.fingerprint' | head -n 1 || true)"
    if [[ -z "${FP_LINE}" ]]; then
      fail "CHECK 5: vbmeta has no com.android.build.system.fingerprint prop — cannot verify intent, fail closed"
    else
      GOT_FP="$(printf '%s\n' "${FP_LINE}" | sed -n "s/.*->[[:space:]]*'\(.*\)'.*/\1/p")"
      echo "    EXPECTED=${EXPECT_FP}"
      echo "    GOT     =${GOT_FP:-<unparsed: ${FP_LINE}>}"
      if [[ -z "${GOT_FP}" ]]; then
        fail "CHECK 5: could not parse fingerprint out of: ${FP_LINE}"
      elif [[ "${GOT_FP}" == "${EXPECT_FP}" ]]; then
        pass "CHECK 5: vbmeta system fingerprint matches EXPECT_FINGERPRINT"
      else
        fail "CHECK 5: fingerprint MISMATCH — bundle vbmeta is not the intended build (got '${GOT_FP}', expected '${EXPECT_FP}')"
      fi
    fi
  fi
fi
echo

# ===========================================================================
# CHECK 6 — avb_pkmd.bin is a valid AVB public key AND binds to vbmeta's key
# ===========================================================================
# WHY: avb_pkmd.bin is what the bootloader will compare vbmeta against under a
# locked bootloader. If it is truncated, is the wrong key, or is stale, the
# device refuses to boot the image the operator just flashed — after the flash.
# The card's "starts with 00 00 10 00" sniff is kept, but a header sniff alone
# cannot tell you the key is the RIGHT key, so this check also binds the blob to
# the vbmeta image by sha1 (see header notes: --key cannot consume a blob).
echo "--- CHECK 6: avb_pkmd.bin valid and matches vbmeta public key ---"
echo "    why: a wrong/stale key blob makes a locked bootloader reject the image AFTER flashing"
PKMD="${BUNDLE}/avb_pkmd.bin"
if [[ ! -f "${PKMD}" ]]; then
  fail "CHECK 6: avb_pkmd.bin missing at ${PKMD}"
elif [[ ! -s "${PKMD}" ]]; then
  fail "CHECK 6: avb_pkmd.bin is zero bytes at ${PKMD}"
else
  PKMD_SIZE="$(stat -c '%s' "${PKMD}")"
  PKMD_HDR="$(od -An -tx1 -N4 "${PKMD}" | tr -d ' \n')"
  echo "    size=${PKMD_SIZE} bytes  first4=${PKMD_HDR}"
  case "${PKMD_HDR}" in
    00001000)
      pass "CHECK 6: avb_pkmd.bin header 00 00 10 00 = AVB public key, RSA-4096 (${PKMD_SIZE} bytes)"
      # 4 (bits) + 4 (n0inv) + 512 (n) + 512 (rr)
      if [[ "${PKMD_SIZE}" -eq 1032 ]]; then
        pass "CHECK 6: RSA-4096 key blob length 1032 == 8 + 512 + 512 (well formed)"
      else
        fail "CHECK 6: RSA-4096 key blob length ${PKMD_SIZE} != expected 1032 — truncated or padded, not a valid AVB key"
      fi
      ;;
    00000800)
      pass "CHECK 6: avb_pkmd.bin header 00 00 08 00 = AVB public key, RSA-2048 (${PKMD_SIZE} bytes)"
      if [[ "${PKMD_SIZE}" -eq 520 ]]; then
        pass "CHECK 6: RSA-2048 key blob length 520 == 8 + 256 + 256 (well formed)"
      else
        fail "CHECK 6: RSA-2048 key blob length ${PKMD_SIZE} != expected 520 — truncated or padded, not a valid AVB key"
      fi
      ;;
    *)
      fail "CHECK 6: avb_pkmd.bin header ${PKMD_HDR} is neither 00001000 (RSA-4096) nor 00000800 (RSA-2048) — not an AVB public key blob"
      ;;
  esac
  # Binding: sha1 of the blob must equal the vbmeta's own "Public key (sha1)".
  if [[ ! -f "${VB}" ]]; then
    fail "CHECK 6: cannot bind avb_pkmd.bin — vbmeta.img missing"
  elif [[ "${HAVE_AVBTOOL}" -ne 1 ]]; then
    fail "CHECK 6: cannot bind avb_pkmd.bin — avbtool unavailable (fail closed)"
  else
    PK_SHA1="$(sha1sum "${PKMD}" | cut -d' ' -f1)"
    EMB_SHA1="$(printf '%s\n' "${INFO_OUT:-}" | sed -n 's/^Public key (sha1):[[:space:]]*//p' | head -n 1 | tr -d '[:space:]')"
    if [[ -z "${EMB_SHA1}" ]]; then
      # INFO_OUT is only populated by check 5; read it here if it was skipped.
      set +e
      EMB_SHA1="$(  "${AVBTOOL}" info_image --image "${VB}" 2>/dev/null \
                  | sed -n 's/^Public key (sha1):[[:space:]]*//p' | head -n 1 | tr -d '[:space:]' )"
      set -e
    fi
    echo "    avb_pkmd.bin sha1     = ${PK_SHA1}"
    echo "    vbmeta embedded sha1  = ${EMB_SHA1:-<unreadable>}"
    if [[ -z "${EMB_SHA1}" ]]; then
      fail "CHECK 6: could not read the vbmeta embedded public key sha1 — cannot bind the key blob (fail closed)"
    elif [[ "${PK_SHA1}" == "${EMB_SHA1}" ]]; then
      pass "CHECK 6: avb_pkmd.bin IS the key embedded in this vbmeta (sha1 match)"
    else
      fail "CHECK 6: avb_pkmd.bin does NOT match vbmeta's embedded key (sha1 ${PK_SHA1} != ${EMB_SHA1}) — locked bootloader would reject this image"
    fi
    # The card also asks to try --key if it can be run. It cannot (avbtool wants
    # a private-key PEM there). Report the attempt honestly rather than skip it.
    set +e
    KEY_OUT="$("${AVBTOOL}" verify_image --image "${VB}" --key "${PKMD}" 2>&1)"
    KEY_RC=$?
    set -e
    if [[ "${KEY_RC}" -eq 0 ]]; then
      pass "CHECK 6: avbtool verify_image --key accepted avb_pkmd.bin and verified the chain"
    elif printf '%s' "${KEY_OUT}" | grep -qi 'could not read public key'; then
      echo "    INFO: avbtool verify_image --key exit ${KEY_RC} — avbtool wants a private-key PEM at --key and cannot consume a raw AVB public-key blob."
      echo "    INFO: the sha1 binding above is the enforceable equivalent and did run; --key is not a usable check for a .bin blob."
    else
      warn "CHECK 6: avbtool verify_image --key exit ${KEY_RC} for a non-parsing reason: $(printf '%s' "${KEY_OUT}" | tail -n 2 | tr '\n' ' ')"
    fi
  fi
fi
echo

# ===========================================================================
# CHECK 7 — bundle vs out/target/product/<device> digests: WARN only
# ===========================================================================
# WHY: a bundle built from a slightly repacked but equivalent image is
# legitimate, so a differing digest must NOT block the flash. It is still worth
# printing, because an UNEXPECTED difference is how you catch "this bundle is not
# from that tree". Informational by design — the card says WARN, not FAIL.
echo "--- CHECK 7: bundle vs out/ digests (WARN only, never fails) ---"
echo "    why: a repacked-but-equivalent image is legitimate; an unexpected difference is a lead, not a stop"
OUT_DEV="out/target/product/${DEVICE}"
echo "    out dir: ${OUT_DEV}"
if [[ ! -d "${OUT_DEV}" ]]; then
  skip "CHECK 7: ${OUT_DEV} absent — no out/ artifact to compare against"
else
  for NAME in bootloader.img vbmeta.img; do
    B_F="${BUNDLE}/${NAME}"
    O_F="${OUT_DEV}/${NAME}"
    if [[ ! -e "${B_F}" ]]; then
      skip "CHECK 7: ${NAME} absent from bundle — nothing to compare"
    elif [[ ! -e "${O_F}" ]]; then
      skip "CHECK 7: ${NAME} absent from ${OUT_DEV} — nothing to compare"
    else
      B_SHA="$(sha256sum "${B_F}" | cut -d' ' -f1)"
      O_SHA="$(sha256sum "${O_F}" | cut -d' ' -f1)"
      if [[ "${B_SHA}" == "${O_SHA}" ]]; then
        pass "CHECK 7: ${NAME} identical to out/ (${B_SHA:0:16}...)"
      else
        warn "CHECK 7: ${NAME} DIFFERS from out/ — bundle=${B_SHA:0:16}... out=${O_SHA:0:16}... (WARN: can be a legitimate repack; confirm provenance if unexpected)"
      fi
    fi
  done
fi
echo

# ------------------------------------------------------------ scope honesty
hold "CHECK 0 (device): this gate proves on-disk bundle integrity only — no tablet was touched, so bootability is NOT claimed"
hold "CHECK 0 (device): BOOT_VERIFIED=false; a locked bootloader may still reject this image (anti-rollback, key epoch) at flash time"

finish
