#!/usr/bin/env bash
# T-EXCISE-ROOT-IGNORE-DURABILITY — host gate for the workspace-root .ignore.
#
# Fails when the ignore file under test is missing, when any non-comment
# pattern is the unanchored bare `out/`, or when any of these anchored
# patterns is absent:
#   /out/
#   /out_adevtool_deps/
#   /out_adevtool_deps.stale-*/
#   /*.stale-*/
# Also fails when the 68 tracked fixtures that contain an out/ path segment
# are not all visible to ripgrep, or when any of those fixtures is
# tracked-but-ignored by git.
#
# The live root .ignore is never written. Point GT_ROOT_IGNORE at a copy to
# prove a bare out/ pattern fails without replacing the checkout file.
# Fixture visibility always uses the live tree (ripgrep reads $ROOT/.ignore).
#
# Usage (from the worktree root):
#   bash vendor/guardtalk/docs/qa/verify_root_ignore_durability_static.sh
# Env:
#   GT_ROOT_IGNORE   ignore file under test (default: $ROOT/.ignore)
#   ROOT             workspace root override
#
# Host static. No commit. No flash. Does not claim BOOT_VERIFIED.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ROOT:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
IGNORE="${GT_ROOT_IGNORE:-$ROOT/.ignore}"
GT_REPO="$ROOT/vendor/guardtalk"
FIXTURE_PREFIX="docs/qa/fixtures"
EXPECTED_NESTED=68

FAIL=0
PASS_N=0
HOLD_N=0
pass() { printf 'PASS: %s\n' "$*"; PASS_N=$((PASS_N + 1)); }
fail() { printf 'FAIL: %s\n' "$*"; FAIL=1; }
hold() { printf 'HOLD: %s\n' "$*"; HOLD_N=$((HOLD_N + 1)); }

REQUIRED_PATTERNS=(
  '/out/'
  '/out_adevtool_deps/'
  '/out_adevtool_deps.stale-*/'
  '/*.stale-*/'
)

trim_line() {
  local s="$1"
  s="${s%$'\r'}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

count_lines() {
  local n
  n="$(grep -c . "$1" 2>/dev/null || true)"
  printf '%s' "${n:-0}"
}

declare -A PATTERN_SEEN=()

if [[ ! -f "$IGNORE" || ! -r "$IGNORE" ]]; then
  fail "ignore file missing or unreadable: $IGNORE"
else
  pass "ignore file present: $IGNORE"
  line_no=0
  bare_out=0
  while IFS= read -r raw || [[ -n "${raw}" ]]; do
    line_no=$((line_no + 1))
    trimmed="$(trim_line "$raw")"
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" == \#* ]] && continue
    PATTERN_SEEN["$trimmed"]=1
    if [[ "$trimmed" == "out/" ]]; then
      fail "unanchored bare out/ pattern at ${IGNORE}:${line_no}"
      bare_out=1
    fi
  done < "$IGNORE"
  if [[ "$bare_out" -eq 0 ]]; then
    pass "no unanchored bare out/ pattern"
  fi
  for req in "${REQUIRED_PATTERNS[@]}"; do
    if [[ -n "${PATTERN_SEEN[$req]+x}" ]]; then
      pass "anchored pattern present: ${req}"
    else
      fail "anchored pattern absent: ${req}"
    fi
  done
fi

# The workspace root is not a git repo. vendor/guardtalk cannot store ../.ignore.
# A clean checkout drops the root file. That is an operator HOLD, not a pattern
# failure: this card forbids the commit that would version a restorer.
if [[ -d "$GT_REPO/.git" || -f "$GT_REPO/.git" ]]; then
  outside_rc=0
  outside_msg="$(git -C "$GT_REPO" check-ignore -v -- "$ROOT/.ignore" 2>&1)" || outside_rc=$?
  # A path outside the work tree makes check-ignore exit 128 before any rule.
  if [[ "$outside_rc" -eq 128 ]]; then
    hold "root .ignore is outside the vendor/guardtalk git repository (check-ignore exit 128). A clean checkout cannot preserve it. Durability needs an operator commit of a tracked restorer; this gate does not commit."
  elif [[ "$outside_rc" -eq 0 ]]; then
    fail "root .ignore became visible to vendor/guardtalk check-ignore: ${outside_msg}"
  else
    hold "check-ignore of ${ROOT}/.ignore exited ${outside_rc}: ${outside_msg}"
  fi
else
  fail "vendor/guardtalk git metadata missing: $GT_REPO"
fi

tracked_nested_file="$(mktemp)"
visible_nested_file="$(mktemp)"
repo_ignored_file="$(mktemp)"
trap 'rm -f "$tracked_nested_file" "$visible_nested_file" "$repo_ignored_file"' EXIT

if [[ -d "$GT_REPO/.git" || -f "$GT_REPO/.git" ]]; then
  git -C "$GT_REPO" ls-files "$FIXTURE_PREFIX" \
    | grep -E '(^|/)out/' \
    | LC_ALL=C sort > "$tracked_nested_file" || true
  tracked_n="$(count_lines "$tracked_nested_file")"
  if [[ "$tracked_n" -eq "$EXPECTED_NESTED" ]]; then
    pass "tracked fixtures with an out/ path segment: ${tracked_n}"
  else
    fail "tracked fixtures with an out/ path segment: ${tracked_n} (expected ${EXPECTED_NESTED})"
  fi

  if ! command -v rg >/dev/null 2>&1; then
    fail "rg missing; cannot prove the 68 fixtures stay visible"
  else
    (
      cd "$ROOT"
      rg --files "vendor/guardtalk/${FIXTURE_PREFIX}"
    ) | sed 's|^vendor/guardtalk/||' \
      | grep -E '(^|/)out/' \
      | LC_ALL=C sort > "$visible_nested_file" || true
    visible_n="$(count_lines "$visible_nested_file")"
    missing_n="$(comm -23 "$tracked_nested_file" "$visible_nested_file" | grep -c . || true)"
    missing_n="${missing_n:-0}"
    if [[ "$missing_n" -eq 0 && "$tracked_n" -eq "$EXPECTED_NESTED" ]]; then
      pass "visible fixtures with an out/ path segment: ${tracked_n} of ${tracked_n}"
    else
      fail "visible fixtures with an out/ path segment: missing ${missing_n} of ${tracked_n} (rg listed ${visible_n})"
    fi
  fi

  fixture_ignored="$(git -C "$GT_REPO" ls-files -i -c --exclude-standard -- "$FIXTURE_PREFIX" | grep -c . || true)"
  fixture_ignored="${fixture_ignored:-0}"
  if [[ "$fixture_ignored" -eq 0 ]]; then
    pass "fixture tracked-but-ignored = 0"
  else
    fail "fixture tracked-but-ignored = ${fixture_ignored} (expected 0)"
  fi

  git -C "$GT_REPO" ls-files -i -c --exclude-standard | LC_ALL=C sort > "$repo_ignored_file" || true
  repo_n="$(count_lines "$repo_ignored_file")"
  if [[ "$repo_n" -eq 0 ]]; then
    pass "tracked-but-ignored = 0"
  else
    unexpected=0
    while IFS= read -r path || [[ -n "${path}" ]]; do
      [[ -z "$path" ]] && continue
      case "$path" in
        *__pycache__/*.pyc)
          if ! git -C "$GT_REPO" cat-file -e "HEAD:${path}" 2>/dev/null; then
            unexpected=1
            fail "tracked-but-ignored path is not in HEAD: ${path}"
          fi
          ;;
        *)
          unexpected=1
          fail "tracked-but-ignored path is not HEAD __pycache__ bytecode: ${path}"
          ;;
      esac
    done < "$repo_ignored_file"
    if [[ "$unexpected" -eq 0 ]]; then
      listed="$(paste -sd ',' "$repo_ignored_file")"
      hold "tracked-but-ignored repo-wide = ${repo_n} (not 0): ${listed}. Each path is __pycache__/*.pyc already in HEAD and matched by vendor/guardtalk/.gitignore. Fixture tracked-but-ignored = 0. The root .ignore is not a git exclude. Untracking them needs a commit, which this card forbids."
    fi
  fi
fi

printf 'PASS_COUNT=%s HOLD_COUNT=%s FAIL=%s\n' "$PASS_N" "$HOLD_N" "$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
