#!/bin/sh
# AEGIS pre-commit approval gate - shim.
#
# Git executes hooks from <git-dir>/hooks/, and git never versions hooks. This
# shim exists so the gate logic CAN be versioned: it is tracked in this
# repository alongside the checker it delegates to:
#
#   <repo>/scripts/pre-commit-approval-check.sh    <- this shim (versioned)
#   <repo>/scripts/pre-commit-approval-check.py    <- the real checker (versioned)
#   <repo>/scripts/install-commit-approval-hook.sh <- versioned installer
#
# The shim locates the checker by walking up from the git toplevel looking for
# <dir>/scripts/pre-commit-approval-check.py. In a normal checkout that walk-up
# resolves immediately to the versioned copy tracked next to this file. (For a
# checkout nested in the Android `repo` workspace, the workspace-root scripts/
# entry is a symlink to that same tracked file, so there is still exactly one
# copy of the logic - no duplication.)
#
# Install (from anywhere inside the repository):
#   scripts/install-commit-approval-hook.sh
#
# Manual equivalent:
#   install -m 0755 scripts/pre-commit-approval-check.sh <git-dir>/hooks/pre-commit
#
# If the checker cannot be found the shim refuses the commit (fail-closed).
# Exit codes are propagated from the checker: 0 = allow, 1 = block.
set -u

toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || toplevel=$(pwd)
dir=$toplevel
checker=""
while [ -n "$dir" ]; do
    if [ -f "$dir/scripts/pre-commit-approval-check.py" ]; then
        checker="$dir/scripts/pre-commit-approval-check.py"
        break
    fi
    parent=$(dirname "$dir")
    [ "$parent" = "$dir" ] && break
    dir=$parent
done

if [ -z "$checker" ]; then
    echo "[AEGIS] pre-commit approval checker not found (expected" >&2
    echo "        <repo>/scripts/pre-commit-approval-check.py);" >&2
    echo "        refusing commit (fail-closed)." >&2
    exit 1
fi

exec python3 "$checker" "$@"
