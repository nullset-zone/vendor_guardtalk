#!/usr/bin/env bash
# =============================================================================
# Q-DEVICE-ALIGN-MATRIX — static gate (run from the worktree root)
# =============================================================================
# Fails when vendor/guardtalk/docs/device-alignment-matrix.json disagrees with
# the live device overlay directories in either direction:
#   * a directory under vendor/guardtalk/device/ that the matrix does not list
#   * a matrix device with no overlay directory
#   * a tracked overlay file the matrix marks present and the tree lacks
#   * a tracked overlay file the tree has and the matrix marks absent
#
# The matrix path is the one gen-device-alignment-matrix.py writes
# (vendor/guardtalk/docs/device-alignment-matrix.json). This script does not
# generate a second matrix and does not rewrite the committed snapshot.
#
# Also token-diffs the rango vendor_dlkm blocklist against its unreferenced
# laguna_rango mirror (DEC-DEVICE-ALIGN-007). Match count must be > 0.
# rg exit 1 (zero matches) is a failure, never a pass (DEC-DEVICE-ALIGN-012).
#
# Population pin: 15 overlay dirs x 8 tracked files (the generator's
# EXPECTED_DEVICE_COUNT and OVERLAY_FILES). An empty scan cannot pass.
#
# This gate does not certify a build, a flash, or a boot.
# FLASH_READY=false
# BOOT_VERIFIED=false
#
# Usage (from the worktree root):
#   bash vendor/guardtalk/docs/qa/verify_device_alignment_matrix_static.sh
#   bash vendor/guardtalk/docs/qa/verify_device_alignment_matrix_static.sh --self-test
#
# Injection seams (absolute or ROOT-relative). Defaults are the live tree.
#   DEVICE_ROOT       overlay directory parent (default vendor/guardtalk/device)
#   MATRIX_JSON       matrix snapshot
#   RANGO_BLOCKLIST   device/rango vendor_dlkm blocklist
#   MIRROR_BLOCKLIST  variants/laguna_rango vendor_dlkm blocklist
#
# rc: 0 agreement (and a non-zero blocklist token match)
#     1 disagreement, vacuous scan, or blocklist mismatch / zero-match
# --self-test: 0 every injection was detected and the temp tree was restored
# =============================================================================
set -uo pipefail

SELF_ABS="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1

if [[ ! -d "$ROOT/vendor/guardtalk/device" || ! -d "$ROOT/vendor/guardtalk/docs/qa" ]]; then
  echo "FAIL: ROOT does not resolve to the worktree (got $ROOT)"
  echo "FLASH_READY=false"
  echo "BOOT_VERIFIED=false"
  exit 1
fi

EXPECTED_DEVICES=15
EXPECTED_FILES=(
  BoardConfig-excised-late.mk
  guardtalk-flags.mk
  guardtalk-insmod.mk
  guardtalk-product-props.mk
  guardtalk-production-hardening.mk
  guardtalk-theme.mk
  guardtalk-audio.mk
  guardtalk-camera.mk
)

abs_under_root() {
  local p="$1"
  if [[ "$p" == /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s\n' "$ROOT/$p"
  fi
}

DEVICE_ROOT="$(abs_under_root "${DEVICE_ROOT:-vendor/guardtalk/device}")"
MATRIX_JSON="$(abs_under_root "${MATRIX_JSON:-vendor/guardtalk/docs/device-alignment-matrix.json}")"
RANGO_BLOCKLIST="$(abs_under_root "${RANGO_BLOCKLIST:-vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist}")"
MIRROR_BLOCKLIST="$(abs_under_root "${MIRROR_BLOCKLIST:-vendor/guardtalk/feature-excised/variants/laguna_rango/vendor_dlkm.modules.blocklist}")"

FAIL=0
FAIL_N=0
PASS_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; FAIL_N=$((FAIL_N + 1)); }

finish() {
  echo "PASS_COUNT=${PASS_N}"
  echo "FAIL_COUNT=${FAIL_N}"
  echo "FLASH_READY=false"
  echo "BOOT_VERIFIED=false"
  exit "$FAIL"
}

# Extract ^blocklist <token> lines. rc=1 or a 0-count is a hard failure
# BEFORE any equality comparison, so two empty files cannot cmp equal and pass.
# Not called from a command substitution: fail() must stay in this process.
extract_blocklist_tokens() {
  local src="$1" dest="$2" rc=0
  TOKEN_N=""
  if [[ ! -f "$src" ]]; then
    fail "[blocklist] missing file: $src"
    return 1
  fi
  rg -N -- '^blocklist[[:space:]]+\S+' "$src" >"$dest" || rc=$?
  if [[ "$rc" -eq 1 ]]; then
    fail "[blocklist] rg rc=1 (zero matches) in $src — zero-match pass forbidden (DEC-DEVICE-ALIGN-012)"
    return 1
  fi
  if [[ "$rc" -ne 0 ]]; then
    fail "[blocklist] rg rc=${rc} reading $src"
    return 1
  fi
  TOKEN_N="$(wc -l <"$dest" | tr -d '[:space:]')"
  if [[ -z "$TOKEN_N" || "$TOKEN_N" -le 0 ]]; then
    fail "[blocklist] match count ${TOKEN_N:-0} in $src — count must be > 0"
    TOKEN_N=""
    return 1
  fi
  return 0
}

check_blocklists() {
  local tmp="$1" na="" nb=""
  extract_blocklist_tokens "$RANGO_BLOCKLIST" "$tmp/rango.tokens" || return 0
  na="$TOKEN_N"
  extract_blocklist_tokens "$MIRROR_BLOCKLIST" "$tmp/mirror.tokens" || return 0
  nb="$TOKEN_N"
  if [[ "$na" -le 0 || "$nb" -le 0 ]]; then
    fail "[blocklist] match count rango=${na} mirror=${nb} — count must be > 0"
    return 0
  fi
  if ! cmp -s "$tmp/rango.tokens" "$tmp/mirror.tokens"; then
    fail "[blocklist] token mismatch between device/rango and variants/laguna_rango (rango_count=${na} mirror_count=${nb})"
    return 0
  fi
  echo "BLOCKLIST_MATCH_COUNT=${na}"
  pass "[blocklist] rango device copy token-identical to laguna_rango mirror (match_count=${na} > 0)"
}

check_overlays() {
  local tmp="$1" py_rc=0
  if [[ ! -d "$DEVICE_ROOT" ]]; then
    fail "[dirs] device overlay root missing: $DEVICE_ROOT"
    return 0
  fi
  if [[ ! -f "$MATRIX_JSON" ]]; then
    fail "[matrix] missing matrix: $MATRIX_JSON"
    return 0
  fi

  python3 - "$MATRIX_JSON" >"$tmp/manifest" 2>"$tmp/manifest.err" <<'PY'
import json
import re
import sys

path = sys.argv[1]
dev_re = re.compile(r"^[a-z0-9]+$")
file_re = re.compile(r"^[A-Za-z0-9._-]+$")
try:
    with open(path, encoding="utf-8") as handle:
        doc = json.load(handle)
except json.JSONDecodeError as exc:
    print(f"ERROR invalid JSON: {exc}", file=sys.stderr)
    sys.exit(1)

for key in ("FLASH_READY", "BOOT_VERIFIED"):
    if key in doc and doc[key] is not False:
        print(f"ERROR {key} must stay false in the matrix", file=sys.stderr)
        sys.exit(1)

tracked = doc.get("overlay_files_tracked")
devices = doc.get("devices")
if not isinstance(tracked, list) or not tracked:
    print("ERROR overlay_files_tracked is empty", file=sys.stderr)
    sys.exit(1)
if not isinstance(devices, list) or not devices:
    print("ERROR devices is empty", file=sys.stderr)
    sys.exit(1)
if doc.get("device_count") != len(devices):
    print(
        f"ERROR device_count {doc.get('device_count')!r} != row count {len(devices)}",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"DEVICE_COUNT\t{doc.get('device_count')}")
print(f"TRACKED\t{len(tracked)}")
seen_files = set()
for name in tracked:
    if not isinstance(name, str) or not file_re.fullmatch(name) or name in seen_files:
        print(f"ERROR bad overlay file name: {name!r}", file=sys.stderr)
        sys.exit(1)
    seen_files.add(name)
    print(f"FILE\t{name}")

seen = set()
for row in devices:
    if not isinstance(row, dict):
        print("ERROR device row is not an object", file=sys.stderr)
        sys.exit(1)
    dev = row.get("device")
    if not isinstance(dev, str) or not dev_re.fullmatch(dev) or dev in seen:
        print(f"ERROR bad or duplicate device: {dev!r}", file=sys.stderr)
        sys.exit(1)
    seen.add(dev)
    presence = row.get("presence")
    if not isinstance(presence, dict):
        print(f"ERROR {dev} presence is missing", file=sys.stderr)
        sys.exit(1)
    if set(presence) != set(tracked):
        extra = sorted(set(presence) - set(tracked))
        missing = sorted(set(tracked) - set(presence))
        print(
            f"ERROR {dev} presence keys extra={extra} missing={missing}",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"DEV\t{dev}")
    for name in tracked:
        val = presence[name]
        if val is True:
            bit = "1"
        elif val is False:
            bit = "0"
        else:
            print(f"ERROR {dev} {name} presence is not boolean", file=sys.stderr)
            sys.exit(1)
        print(f"PRES\t{dev}\t{name}\t{bit}")
PY
  py_rc=$?
  if [[ "$py_rc" -ne 0 ]]; then
    fail "[matrix] could not read $MATRIX_JSON (python rc=${py_rc})"
    if [[ -s "$tmp/manifest.err" ]]; then
      while IFS= read -r line; do
        fail "[matrix] $line"
      done <"$tmp/manifest.err"
    fi
    return 0
  fi

  local -a json_devs=() live_devs=() files=()
  local -A json_set=() live_set=() presence=()
  local kind a b c json_count="" tracked_n=""
  while IFS=$'\t' read -r kind a b c; do
    case "$kind" in
      DEVICE_COUNT) json_count="$a" ;;
      TRACKED) tracked_n="$a" ;;
      FILE) files+=("$a") ;;
      DEV) json_devs+=("$a") ;;
      PRES) presence["$a/$b"]="$c" ;;
      "") ;;
      *) fail "[matrix] unexpected manifest row: $kind" ;;
    esac
  done <"$tmp/manifest"

  local nullglob_was=0
  shopt -q nullglob && nullglob_was=1
  shopt -s nullglob
  local d base
  for d in "$DEVICE_ROOT"/*; do
    [[ -d "$d" ]] || continue
    base="$(basename "$d")"
    [[ "$base" == .* ]] && continue
    if [[ ! "$base" =~ ^[a-z0-9]+$ ]]; then
      fail "[dirs] unexpected overlay dir name: $base"
      continue
    fi
    live_devs+=("$base")
  done
  [[ "$nullglob_was" -eq 0 ]] && shopt -u nullglob

  local exp name missing=0
  if [[ "$tracked_n" -ne ${#EXPECTED_FILES[@]} || ${#files[@]} -ne ${#EXPECTED_FILES[@]} ]]; then
    fail "[overlay] expected ${#EXPECTED_FILES[@]} tracked overlay files, json has ${tracked_n:-0}"
  fi
  declare -A file_set=()
  for name in "${files[@]}"; do file_set["$name"]=1; done
  for exp in "${EXPECTED_FILES[@]}"; do
    if [[ -z "${file_set[$exp]:-}" ]]; then
      fail "[overlay] matrix overlay_files_tracked is missing $exp"
      missing=1
    fi
  done
  for name in "${files[@]}"; do
    local found=0
    for exp in "${EXPECTED_FILES[@]}"; do
      [[ "$name" == "$exp" ]] && found=1
    done
    if [[ "$found" -eq 0 ]]; then
      fail "[overlay] matrix tracks unexpected file $name"
      missing=1
    fi
  done

  if [[ ${#live_devs[@]} -eq 0 || ${#json_devs[@]} -eq 0 ]]; then
    fail "[dirs] zero device overlay dirs (live=${#live_devs[@]} json=${#json_devs[@]}) — vacuous scan forbidden"
  fi
  if [[ "$json_count" != "$EXPECTED_DEVICES" || ${#json_devs[@]} -ne $EXPECTED_DEVICES || ${#live_devs[@]} -ne $EXPECTED_DEVICES ]]; then
    fail "[dirs] expected ${EXPECTED_DEVICES} overlay dirs, live=${#live_devs[@]} json_rows=${#json_devs[@]} json_device_count=${json_count:-empty}"
  else
    pass "[dirs] 15 overlay dirs on disk and in the matrix (count > 0)"
  fi

  local dev
  for dev in "${json_devs[@]}"; do json_set["$dev"]=1; done
  for dev in "${live_devs[@]}"; do
    if [[ -n "${live_set[$dev]:-}" ]]; then
      fail "[dirs] duplicate live overlay dir: $dev"
    fi
    live_set["$dev"]=1
  done
  for dev in "${live_devs[@]}"; do
    if [[ -z "${json_set[$dev]:-}" ]]; then
      fail "[dirs] $dev only in tree (overlay dir not in matrix)"
    fi
  done
  for dev in "${json_devs[@]}"; do
    if [[ -z "${live_set[$dev]:-}" ]]; then
      fail "[dirs] $dev only in matrix (overlay dir missing from tree)"
    fi
  done

  if [[ "$missing" -ne 0 || ${#files[@]} -eq 0 || ${#json_devs[@]} -eq 0 ]]; then
    fail "[overlay] presence comparison skipped — tracked file set is unusable"
    return 0
  fi

  local bit path compared=0 cell_fail=0
  for dev in "${json_devs[@]}"; do
    for name in "${files[@]}"; do
      bit="${presence[$dev/$name]:-}"
      compared=$((compared + 1))
      path="$DEVICE_ROOT/$dev/$name"
      if [[ "$bit" != "0" && "$bit" != "1" ]]; then
        fail "[overlay] $dev/$name missing presence bit"
        cell_fail=1
        continue
      fi
      if [[ "$bit" == "1" && ! -f "$path" ]]; then
        fail "[overlay] $dev/$name JSON present, tree absent"
        cell_fail=1
      elif [[ "$bit" == "0" && -f "$path" ]]; then
        fail "[overlay] $dev/$name tree present, JSON absent"
        cell_fail=1
      fi
    done
  done

  local expect_cells=$((EXPECTED_DEVICES * ${#EXPECTED_FILES[@]}))
  if [[ "$compared" -le 0 ]]; then
    fail "[overlay] compared 0 presence cells — vacuous scan forbidden"
  elif [[ "$compared" -ne "$expect_cells" ]]; then
    fail "[overlay] expected ${expect_cells} presence comparisons, got ${compared}"
  else
    pass "[overlay] compared ${compared} presence cells (15 devices x 8 files, count > 0)"
  fi
  if [[ "$cell_fail" -eq 0 && "$compared" -eq "$expect_cells" ]]; then
    pass "[overlay] matrix and live tree agree in both directions"
  fi
}

run_gate() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  check_overlays "$tmp"
  check_blocklists "$tmp"
  finish
}

# --- self-test --------------------------------------------------------------
# Builds agreement in a temp copy, then injects one delta at a time.
# The committed matrix and the live device tree are not written.
self_test() {
  local work pristine self_fail=0
  local before_theme after_theme before_flags after_flags
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT

  before_theme="$(sha256sum "$ROOT/vendor/guardtalk/device/akita/guardtalk-theme.mk")"
  before_flags="$(sha256sum "$ROOT/vendor/guardtalk/device/tangorpro/guardtalk-flags.mk")"

  echo "NOTE: positive control rewrites presence bits in a temp JSON only. It does not claim the committed matrix matches the live tree."
  echo "FLASH_READY=false"
  echo "BOOT_VERIFIED=false"

  cp -a "$ROOT/vendor/guardtalk/device" "$work/pristine"

  reconcile() {
    python3 - "$ROOT/vendor/guardtalk/docs/device-alignment-matrix.json" "$work/device" "$work/matrix.json" <<'PY'
import json
import sys
from pathlib import Path

src, device_root, dest = sys.argv[1:]
doc = json.loads(Path(src).read_text(encoding="utf-8"))
root = Path(device_root)
for row in doc["devices"]:
    for name in doc["overlay_files_tracked"]:
        row["presence"][name] = (root / row["device"] / name).is_file()
Path(dest).write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
PY
  }

  fresh_device() {
    rm -rf "$work/device"
    cp -a "$work/pristine" "$work/device"
    reconcile
  }

  invoke() {
    local log="$1" rango="${2:-}" mirror="${3:-}"
    if [[ -n "$rango" ]]; then
      env DEVICE_ROOT="$work/device" MATRIX_JSON="$work/matrix.json" \
        RANGO_BLOCKLIST="$rango" MIRROR_BLOCKLIST="$mirror" \
        bash "$SELF_ABS" >"$log" 2>&1
    else
      env -u RANGO_BLOCKLIST -u MIRROR_BLOCKLIST \
        DEVICE_ROOT="$work/device" MATRIX_JSON="$work/matrix.json" \
        bash "$SELF_ABS" >"$log" 2>&1
    fi
    child_rc=$?
  }

  expect_rc() {
    local name="$1" want="$2"
    if [[ "$child_rc" -eq "$want" ]]; then
      echo "SELF-PASS: ${name} rc=${child_rc}"
    else
      echo "SELF-FAIL: ${name} rc=${child_rc} expected ${want}"
      self_fail=1
    fi
  }

  expect_log() {
    local name="$1" log="$2" needle="$3"
    if grep -F -q -- "$needle" "$log"; then
      echo "SELF-PASS: ${name} log contains: ${needle}"
    else
      echo "SELF-FAIL: ${name} log missing: ${needle}"
      self_fail=1
    fi
  }

  forbid_log() {
    local name="$1" log="$2" needle="$3"
    if grep -F -q -- "$needle" "$log"; then
      echo "SELF-FAIL: ${name} log unexpectedly contains: ${needle}"
      self_fail=1
    else
      echo "SELF-PASS: ${name} log lacks: ${needle}"
    fi
  }

  # Targets taken from the reconciled fixture, not hardcoded as the proof.
  fresh_device
  python3 - "$work/matrix.json" "$work/device" >"$work/targets" <<'PY'
import json
import sys
from pathlib import Path

doc = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
root = Path(sys.argv[2])
remove = add = ""
for row in doc["devices"]:
    dev = row["device"]
    for name in doc["overlay_files_tracked"]:
        rel = f"{dev}/{name}"
        exists = (root / dev / name).is_file()
        if exists and row["presence"][name] is True and not remove:
            remove = rel
        if (not exists) and row["presence"][name] is False and not add:
            add = rel
if not remove or not add:
    print("ERROR could not find both a present and an absent overlay", file=sys.stderr)
    sys.exit(1)
print(remove)
print(add)
PY
  if [[ $? -ne 0 ]]; then
    echo "SELF-FAIL: could not choose injection targets"
    echo "FLASH_READY=false"
    echo "BOOT_VERIFIED=false"
    exit 1
  fi
  local remove_rel add_rel
  remove_rel="$(sed -n '1p' "$work/targets")"
  add_rel="$(sed -n '2p' "$work/targets")"
  echo "INJECT_REMOVE=${remove_rel}"
  echo "INJECT_ADD=${add_rel}"

  # 1. Positive control: reconciled temp snapshot + real blocklists.
  fresh_device
  invoke "$work/positive.log"
  expect_rc "positive-control" 0
  expect_log "positive-control" "$work/positive.log" "token-identical"
  expect_log "positive-control" "$work/positive.log" "agree in both directions"
  forbid_log "positive-control" "$work/positive.log" "FAIL:"
  local match_count
  match_count="$(sed -n 's/^BLOCKLIST_MATCH_COUNT=//p' "$work/positive.log" | head -n 1)"
  if [[ -n "${match_count}" && "$match_count" -gt 0 ]]; then
    echo "SELF-PASS: positive-control BLOCKLIST_MATCH_COUNT=${match_count} > 0"
  else
    echo "SELF-FAIL: positive-control BLOCKLIST_MATCH_COUNT=${match_count:-empty} is not > 0"
    self_fail=1
  fi

  # 2. Remove one overlay the matrix marks present.
  fresh_device
  rm -f -- "$work/device/$remove_rel"
  invoke "$work/remove.log"
  expect_rc "remove-overlay" 1
  expect_log "remove-overlay" "$work/remove.log" "[overlay] ${remove_rel} JSON present, tree absent"
  cp -a "$work/pristine/$remove_rel" "$work/device/$remove_rel"
  if cmp -s "$work/pristine/$remove_rel" "$work/device/$remove_rel"; then
    echo "SELF-PASS: restore cmp identical for ${remove_rel}"
  else
    echo "SELF-FAIL: restore cmp mismatch for ${remove_rel}"
    self_fail=1
  fi
  if diff -rq "$work/pristine" "$work/device" >"$work/remove.restore.diff"; then
    echo "SELF-PASS: remove-overlay temp tree restored (diff empty)"
  else
    echo "SELF-FAIL: remove-overlay temp tree not restored"
    self_fail=1
  fi

  # 3. Add one overlay the matrix marks absent.
  fresh_device
  if [[ -e "$work/device/$add_rel" ]]; then
    echo "SELF-FAIL: add target already exists: ${add_rel}"
    self_fail=1
  else
    : >"$work/device/$add_rel"
    invoke "$work/add.log"
    expect_rc "add-overlay" 1
    expect_log "add-overlay" "$work/add.log" "[overlay] ${add_rel} tree present, JSON absent"
    rm -f -- "$work/device/$add_rel"
    if diff -rq "$work/pristine" "$work/device" >"$work/add.restore.diff"; then
      echo "SELF-PASS: add-overlay temp tree restored (diff empty)"
    else
      echo "SELF-FAIL: add-overlay temp tree not restored"
      self_fail=1
    fi
  fi

  # 4. Extra overlay directory (tree has a device the matrix does not).
  fresh_device
  mkdir "$work/device/zzinjected"
  invoke "$work/extra-dir.log"
  expect_rc "extra-dir" 1
  expect_log "extra-dir" "$work/extra-dir.log" "[dirs] zzinjected only in tree (overlay dir not in matrix)"
  rm -rf "$work/device/zzinjected"
  if diff -rq "$work/pristine" "$work/device" >/dev/null; then
    echo "SELF-PASS: extra-dir temp tree restored"
  else
    echo "SELF-FAIL: extra-dir temp tree not restored"
    self_fail=1
  fi

  # 5. Remove one overlay directory (matrix has a device the tree lacks).
  fresh_device
  rm -rf "$work/device/emu64a"
  invoke "$work/missing-dir.log"
  expect_rc "missing-dir" 1
  expect_log "missing-dir" "$work/missing-dir.log" "[dirs] emu64a only in matrix (overlay dir missing from tree)"
  cp -a "$work/pristine/emu64a" "$work/device/emu64a"
  if diff -rq "$work/pristine" "$work/device" >/dev/null; then
    echo "SELF-PASS: missing-dir temp tree restored"
  else
    echo "SELF-FAIL: missing-dir temp tree not restored"
    self_fail=1
  fi

  # 6. Comment-only blocklists: rg rc=1 must not pass via empty cmp.
  fresh_device
  printf '# no blocklist tokens\n' >"$work/empty-a.txt"
  printf '# still no tokens\n' >"$work/empty-b.txt"
  invoke "$work/zero.log" "$work/empty-a.txt" "$work/empty-b.txt"
  expect_rc "zero-match-blocklist" 1
  expect_log "zero-match-blocklist" "$work/zero.log" "rg rc=1 (zero matches)"
  forbid_log "zero-match-blocklist" "$work/zero.log" "token-identical"

  # 7. Non-zero but unequal token streams.
  fresh_device
  printf 'blocklist aaa.ko\n' >"$work/mis-a.txt"
  printf 'blocklist bbb.ko\n' >"$work/mis-b.txt"
  invoke "$work/mismatch.log" "$work/mis-a.txt" "$work/mis-b.txt"
  expect_rc "token-mismatch" 1
  expect_log "token-mismatch" "$work/mismatch.log" "token mismatch"
  forbid_log "token-mismatch" "$work/mismatch.log" "rg rc=1 (zero matches)"
  forbid_log "token-mismatch" "$work/mismatch.log" "token-identical"

  after_theme="$(sha256sum "$ROOT/vendor/guardtalk/device/akita/guardtalk-theme.mk")"
  after_flags="$(sha256sum "$ROOT/vendor/guardtalk/device/tangorpro/guardtalk-flags.mk")"
  if [[ "$before_theme" == "$after_theme" && "$before_flags" == "$after_flags" ]]; then
    echo "SELF-PASS: live overlay files unchanged (sha256)"
  else
    echo "SELF-FAIL: live overlay files changed during self-test"
    self_fail=1
  fi

  if [[ "$self_fail" -eq 0 ]]; then
    echo "SELF-TEST PASSED"
    echo "FLASH_READY=false"
    echo "BOOT_VERIFIED=false"
    exit 0
  fi
  echo "SELF-TEST FAILED"
  echo "FLASH_READY=false"
  echo "BOOT_VERIFIED=false"
  exit 1
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
fi
if [[ $# -gt 0 ]]; then
  echo "FAIL: unknown argument: $1"
  echo "FLASH_READY=false"
  echo "BOOT_VERIFIED=false"
  exit 1
fi
run_gate
