#!/bin/sh
# AEGIS pre-commit approval gate - versioned installer.
#
# Installs the tracked shim `scripts/pre-commit-approval-check.sh` as this
# repository's active pre-commit hook (`<git-dir>/hooks/pre-commit`), so commit
# approval enforcement is reproducible from a fresh clone:
#
#   scripts/install-commit-approval-hook.sh
#
# Hooks are never tracked by git, which is exactly why this installer exists:
# the durable source of truth is `scripts/`, and the hook is derived from it.
#
# Idempotent and safe to re-run (e.g. after `repo sync` / re-clone).
# Exit codes: 0 = installed and verified, 1 = failure.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
shim="$script_dir/pre-commit-approval-check.sh"
checker="$script_dir/pre-commit-approval-check.py"

if [ ! -f "$shim" ]; then
    echo "[AEGIS] installer: shim not found at $shim" >&2
    exit 1
fi
if [ ! -f "$checker" ]; then
    echo "[AEGIS] installer: checker not found at $checker" >&2
    exit 1
fi

if ! git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null); then
    echo "[AEGIS] installer: not inside a git repository; refusing." >&2
    exit 1
fi

hooks_dir="$git_dir/hooks"
target="$hooks_dir/pre-commit"

mkdir -p "$hooks_dir"
install -m 0755 "$shim" "$target"

if [ ! -x "$target" ]; then
    echo "[AEGIS] installer: $target is not executable; FAILED." >&2
    exit 1
fi

echo "[AEGIS] Installed commit-approval hook: $target"
echo "[AEGIS] Enforcement is fail-closed; declare AEGIS_TASK_ID=<APPROVED-id> to commit."
exit 0
