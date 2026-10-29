# shellcheck shell=bash
# =============================================================================
# GuardTalkOS web-installer — dependency resolution for host scripts
#
# WHY THIS EXISTS (T-WEBINSTALL-PATH-COUPLING-SWEEP):
#   The installer became consumable outside the Android `repo` checkout (as a
#   git submodule / standalone clone). Three host scripts still reached into
#   the old parent layout with two-or-more-level relative paths, and one of
#   them was ALREADY BROKEN in the parent layout too (`package.json`
#   "channels:pack" pointed at `vendor/scripts/`, which does not exist).
#
#   Every dependency is now resolved through an ORDERED CANDIDATE LIST:
#   in-repo first, then the parent product-repo location (a sibling
#   `scripts/` directory), then - where a tool genuinely lives further up an
#   Android tree - a BOUNDED upward probe for a named relative path. Nothing
#   here assumes how many directories sit above the installer, and nothing
#   prints a bare ENOENT: a miss produces the tried paths plus a remedy.
#
# CONTRACT (documented in ../README.md, "Environment contract")
#   GT_NODE_BIN              explicit Node.js interpreter (authoritative)
#   GUARDTALK_RELEASES_ROOT  desktop-flash release store
#   GUARDTALK_INSTALLER_ROOT installer tree (read by scripts/readiness-gate.mjs)
#
# EXIT CODES used by the callers of this library
#   0  resolved
#   2  cannot run: a required host dependency is absent (never a silent skip)
# =============================================================================

# gt_resolve_file LABEL CANDIDATE...
#   Echo the first candidate that exists and is a regular file; return 1 if none.
gt_resolve_file() {
    local _label="$1"
    shift
    local _c
    for _c in "$@"; do
        [ -n "$_c" ] || continue
        if [ -f "$_c" ]; then
            printf '%s\n' "$_c"
            return 0
        fi
    done
    return 1
}

# gt_resolve_dir LABEL CANDIDATE...
#   Same contract as gt_resolve_file, for a directory dependency.
gt_resolve_dir() {
    local _label="$1"
    shift
    local _c
    for _c in "$@"; do
        [ -n "$_c" ] || continue
        if [ -d "$_c" ]; then
            printf '%s\n' "$_c"
            return 0
        fi
    done
    return 1
}

# gt_find_up RELPATH START_DIR [MAX_DEPTH]#   Bounded upward probe: echo the first existing "<dir>/<relpath>" walking up
#   from START_DIR. Max depth is bounded (default 6) so a stray file in an
#   ancestor cannot be picked up from arbitrarily far away. Works for files and
#   directories (`-e`), which is why the release store can be probed too.
gt_find_up() {
    local _rel="$1" _dir="$2" _max="${3:-6}" _i=0
    while [ "$_i" -le "$_max" ] && [ -n "$_dir" ] && [ "$_dir" != "/" ]; do
        if [ -e "$_dir/$_rel" ]; then
            printf '%s\n' "$_dir/$_rel"
            return 0
        fi
        _dir="$(dirname "$_dir")"
        _i=$((_i + 1))
    done
    return 1
}

# gt_missing_die LABEL WHAT REMEDY CANDIDATE...
#   Actionable, fail-closed report: names the dependency, every path tried and
#   what to do about it. Never a bare "No such file or directory".
gt_missing_die() {
    local _label="$1" _what="$2" _remedy="$3"
    shift 3
    {
        printf 'ERROR: %s: cannot find %s\n' "$_label" "$_what"
        printf '       tried:\n'
        local _c
        for _c in "$@"; do
            [ -n "$_c" ] || continue
            printf '         - %s\n' "$_c"
        done
        printf '       fix: %s\n' "$_remedy"
    } >&2
    return 2
}

# gt_is_node_ok PATH -> 0 when PATH runs and reports Node.js >= 20
gt_is_node_ok() {
    local _p="$1" _v _major
    [ -n "$_p" ] || return 1
    [ -x "$_p" ] || return 1
    _v="$("$_p" --version 2>/dev/null)" || return 1
    case "$_v" in
        v[0-9]*) ;;
        *) return 1 ;;
    esac
    _major="${_v#v}"
    _major="${_major%%.*}"
    case "$_major" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$_major" -ge 20 ]
}

# gt_node_candidates -> one candidate interpreter path per line, ordered:
#   PATH, $NODE (the variable scripts/build-site.sh already honours), the
#   newest user-local toolchain, the Cursor server runtimes, then the usual
#   system locations. Nothing here is required to exist.
gt_node_candidates() {
    local _p
    _p="$(command -v node 2>/dev/null || true)"
    [ -n "${_p:-}" ] && printf '%s\n' "$_p"
    [ -n "${NODE:-}" ] && printf '%s\n' "$NODE"
    ls -1d "${HOME:-/nonexistent}"/.local/toolchain/node-*/bin/node 2>/dev/null | sort -rV || true
    ls -1d "${HOME:-/nonexistent}"/.cursor-server/bin/linux-x64/*/node 2>/dev/null | sort -r || true
    printf '%s\n' \
        /usr/local/bin/node \
        /usr/bin/node \
        /snap/bin/node \
        /opt/homebrew/bin/node
}

# gt_resolve_node -> echoes the interpreter path; returns 2 (and explains) if
# none exists. An explicit GT_NODE_BIN is authoritative and FAILS CLOSED when
# it is not a runnable Node.js >= 20 (a stale/wrong pin must not fall through
# to a different binary silently).
gt_resolve_node() {
    local _label="node"
    if [ -n "${GT_NODE_BIN:-}" ]; then
        if gt_is_node_ok "$GT_NODE_BIN"; then
            printf '%s\n' "$GT_NODE_BIN"
            return 0
        fi
        {
            printf 'ERROR: %s: GT_NODE_BIN=%s is not a runnable Node.js >= 20 interpreter\n' \
                "$_label" "$GT_NODE_BIN"
            printf '       fix: unset GT_NODE_BIN to auto-detect, or point it at a real node binary\n'
            printf '            (for example: export GT_NODE_BIN="$(command -v node)")\n'
        } >&2
        return 2
    fi
    local _c
    while IFS= read -r _c; do
        [ -n "$_c" ] || continue
        if gt_is_node_ok "$_c"; then
            printf '%s\n' "$_c"
            return 0
        fi
    done < <(gt_node_candidates)
    {
        printf 'ERROR: %s: no runnable Node.js >= 20 interpreter found\n' "$_label"
        printf '       tried (PATH, $NODE, toolchains, system locations):\n'
        gt_node_candidates | while IFS= read -r _c; do
            [ -n "$_c" ] || continue
            printf '         - %s\n' "$_c"
        done
        printf '       fix: export GT_NODE_BIN=/absolute/path/to/node (Node.js >= 20)\n'
    } >&2
    return 2
}
