#!/usr/bin/env bash
# =============================================================================
# GuardTalkOS — flash-readiness reporter (runs on the BUILD HOST)
#
# Read-only. Never builds, never flashes, never writes to a stamp.
#
# Usage:
#   bash gt-ready-devices.sh                 # TSV report; exits 0
#   bash gt-ready-devices.sh --strict        # exit 1 unless EVERY device is READY or READY-ACK
#   bash gt-ready-devices.sh --strict-stamp-only  # exit 1 unless EVERY device is plain READY
#   bash gt-ready-devices.sh --json          # machine-readable report (per-clause provenance)
#   bash gt-ready-devices.sh --strict --json # JSON on stdout + strict summary on stderr
#
# Emits one TSV line per supported device, in wizard display order:
#
#   <codename>\t<model>\t<stamp>\t<STATUS>\t<reason>\t<remedy>
#
# STATUS is one of:
#   READY     — every gate clause AND every classifier clause passes, AND at least
#               one READY-conferring clause is decidable from THIS stamp's bytes
#               (provenance `stamp`). NOT REACHABLE TODAY, by design: the only
#               READY-conferring clause is `family_boot_proven`, which is
#               platform-level and stamp-INDEPENDENT. Making READY reachable is a
#               deliberate act: add a per-stamp boot artifact (a `stamp`-provenance
#               clause with confers_ready=true) — DEC-ARCH-025.
#   READY-ACK — like HOLD (host clauses PASS, no stamp-conferring clause), but a
#               VALID, stamp-SPECIFIC operator acknowledgement exists that
#               deliberately accepts the NOT-STAMP-VERIFIED residual for THIS
#               stamp. NEVER rendered as plain READY and never a family claim:
#               the status NAMES the ack artifact, and the ack is bound to the
#               exact device + stamp id + the stamp's SHA256SUMS digest. The ack
#               accepts a KNOWN residual; it does NOT create boot evidence.
#               (T-EXCISE-READY-ACK-TIER.)
#   HOLD      — every gate and classifier clause passes, but the only
#               READY-conferring clause is stamp-INDEPENDENT (`family`). Rendered
#               as HOLD / NOT-STAMP-VERIFIED, never as plain READY. This is a
#               provenance/rendering outcome, NOT a host-clause failure: the
#               per-clause list shows every `stamp` clause PASS. An absent,
#               rejected or mismatched acknowledgement leaves the device here
#               (fail-closed).
#   BUILD-OK  — gates pass, but a classifier clause fails: boot is UNVERIFIED
#               (laguna family) or the stamp carries an unresolved FIRST-FLASH
#               RISK block. A BUILD-OK bundle is intact on the host; it is NOT
#               boot-verified.
#   PENDING   — a gate clause fails today (unchanged).
#
# Host gate clauses (all must hold for READY/HOLD/BUILD-OK) — DEC-PORT-GEN8910-WAVE2 §D4:
#   1. a <dev>-latest pointer exists (tokay's legacy generic `latest` alias was
#      retired by T-EXCISE-TOKAY-LATEST-REPOINT)
#   2. the stamp has a SHA256SUMS and `sha256sum -c` passes
#   3. the stamp vendor.img manifest is radio-excised (0 radio/ril refs)
#   4. the stamp bundle carries the flash-script's required files
#
# PER-CLAUSE PROVENANCE (T-EXCISE-READY-STRICT-CLOSURE amendment, Architect 2026-09-30T13:00+04:00):
#   Every clause in the --json clause list is labelled:
#     stamp  — decidable from THIS stamp's bytes (pointer/stamp-dir, SHA256SUMS,
#              required files, radio excision, first-flash risk block).
#     family — platform-level and stamp-INDEPENDENT (family boot-proven on this
#              platform). It cites NO bytes of the stamp that would be flashed.
#   The READY *verdict* is conferred only by a clause with provenance=stamp and
#   confers_ready=true. A READY that would rest ONLY on a `family` clause is
#   rendered HOLD / NOT-STAMP-VERIFIED (DEC-ARCH-025: the claim must describe the
#   artifact that would actually be flashed). This is a labelling change: no gate
#   clause result changes, no device moves to PENDING, no boot is claimed.
#
# RULING R5 (.agent-comm/evidence/B-PORT-LAGUNA-STATE.md §7): on-device boot is a
# separate, host-unverifiable residual. NOTHING here proves a build boots. The
# reporter must not be read as a boot guarantee. BOOT_VERIFIED=false is absolute.
#
# OPERATOR ACKNOWLEDGEMENT TIER (T-EXCISE-READY-ACK-TIER, Law 0 ruling 2026-09-30):
#   The strict reading is ratified: NO device is plain READY. But an operator may
#   DELIBERATELY make a NOT-STAMP-VERIFIED stamp flashable by recording an
#   explicit, STAMP-SPECIFIC acknowledgement. It is NOT a family claim and NOT a
#   silent READY.
#
#   Artifact path : <ACK_DIR>/<codename>.ack
#                   ACK_DIR defaults to <release tree>/acks (i.e.
#                   releases/desktop-flash/acks) and is overridable for tests and
#                   fixtures via GT_READY_ACK_DIR.
#
#   Format        : strict key=value lines; blank lines and lines starting with
#                   '#' are ignored. Any unknown key, any DUPLICATE key, a
#                   malformed line, or a missing/empty required key makes the ack
#                   INVALID (fail-closed). Required keys:
#                     ack_version=1
#                     type=operator-ack
#                     ruling_id=<non-empty operator ruling id>
#                     operator=<non-empty operator handle>
#                     device=<codename>            (must equal the device)
#                     stamp=<stamp dir name>       (must equal the resolved stamp)
#                     sha256sums_sha256=<64 lowercase hex>
#                         sha256 of THIS stamp's SHA256SUMS manifest file bytes.
#                         Because gate 2 also requires `sha256sum -c SHA256SUMS`
#                         to pass, this one digest binds every byte listed in the
#                         manifest (the flash-script required image set).
#                     residual=<non-empty free text: the residual being accepted>
#                   Optional (recorded, not validated):
#                     acknowledged_at=<ISO-8601 timestamp>
#
#   Binding / boundary (hard): an ack is valid ONLY for the exact device AND stamp
#   id AND SHA256SUMS digest it names. A CHANGED stamp (different stamp id, or a
#   changed SHA256SUMS digest) INVALIDATES the ack -> the device stays/returns to
#   HOLD. An ack for one device/stamp can NEVER mark another device or another
#   stamp flashable. An ack is applied ONLY to a host-green device
#   (host_classification=READY): it can NEVER rescue PENDING (a host gate failed)
#   or BUILD-OK (the build itself is not boot-verified).
#
# macOS / bash 3.2 compatible (no declare -A, no ${v,,}, no mapfile). Read-only.
# =============================================================================
set -u

STRICT=0
STRICT_STAMP_ONLY=0
JSON=0
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        --strict-stamp-only) STRICT=1; STRICT_STAMP_ONLY=1 ;;
        --json)   JSON=1 ;;
        -h|--help)
            printf '%s\n' \
                "usage: gt-ready-devices.sh [--strict | --strict-stamp-only] [--json]" \
                "" \
                "  (no args)            print one TSV line per device; exit 0" \
                "  --strict             exit 1 unless EVERY device is READY or READY-ACK" \
                "                       (a valid operator acknowledgement satisfies strict;" \
                "                        it is a recorded acceptance of the residual, NOT a" \
                "                        stamp proof and NOT boot evidence)" \
                "  --strict-stamp-only  exit 1 unless EVERY device is plain READY; a valid" \
                "                       acknowledgement does NOT satisfy this stricter mode" \
                "  --json               machine-readable report with per-clause provenance" \
                "  -h,--help            this text" \
                "" \
                "STATUS (TSV column 4): READY | READY-ACK | HOLD | BUILD-OK | PENDING" \
                "  READY      host + stamp clauses pass AND a stamp-provenance clause" \
                "             confers readiness (NOT reachable today)." \
                "  READY-ACK  host clauses pass but NOT-stamp-verified; a valid, stamp-" \
                "             SPECIFIC operator acknowledgement accepts the residual for" \
                "             THIS stamp. Names the ack artifact; never plain READY." \
                "  HOLD       host clauses pass but NOT-stamp-verified and NOT acknowledged." \
                "  BUILD-OK   a classifier clause fails (boot unverified / first-flash risk)." \
                "  PENDING    a host gate clause fails." \
                "" \
                "OPERATOR ACKNOWLEDGEMENT (READY-ACK):" \
                "  path    <ACK_DIR>/<codename>.ack  (ACK_DIR defaults to" \
                "          releases/desktop-flash/acks; override with GT_READY_ACK_DIR)" \
                "  format  strict key=value; required: ack_version=1, type=operator-ack," \
                "          ruling_id, operator, device, stamp, sha256sums_sha256 (sha256" \
                "          of the stamp's SHA256SUMS), residual; optional acknowledged_at." \
                "  binding an ack is valid ONLY for the exact device + stamp id +" \
                "          SHA256SUMS digest it names. A changed stamp, a changed" \
                "          SHA256SUMS, or an ack for another stamp/device is REJECTED" \
                "          (fail-closed) and the device stays HOLD. An ack never rescues" \
                "          PENDING or BUILD-OK and never creates boot evidence." \
                "" \
                "Exit codes: 0 = report produced (and, with --strict*, every requested-tier" \
                "device met it); 1 = --strict* and a device did not; 2 = bad usage."
            exit 0
            ;;
        *)
            printf 'gt-ready-devices: unknown argument: %s (see --help)\n' "$arg" >&2
            exit 2
            ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
cd "$ROOT" || exit 1
# GT_READY_REL is a test hook: point the reporter at a fixture tree instead of
# the live releases/desktop-flash/ (used by the static wizard test and by the
# tampered-stamp negative control in T-EXCISE-READY-STRICT-CLOSURE).
REL="${GT_READY_REL:-releases/desktop-flash}"

# Operator acknowledgement artifacts (READY-ACK). Default: live alongside the
# release tree they certify, in <REL>/acks. Overridable for fixtures via
# GT_READY_ACK_DIR. The reporter NEVER writes here — it is read-only.
ACK_DIR="${GT_READY_ACK_DIR:-$REL/acks}"

# codename|model — display order: Pixel 8, 9, 10 generations.
DEVICES="
shiba|Pixel 8
husky|Pixel 8 Pro
akita|Pixel 8a
tokay|Pixel 9
caiman|Pixel 9 Pro
komodo|Pixel 9 Pro XL
tegu|Pixel 9a
comet|Pixel 9 Pro Fold
frankel|Pixel 10
blazer|Pixel 10 Pro
mustang|Pixel 10 Pro XL
stallion|Pixel 10a
rango|Pixel 10 Pro Fold
"

# Files scripts/flash-from-remote.sh expects to be able to download.
REQUIRED="bootloader.img radio.img boot.img init_boot.img vendor_boot.img
vendor_kernel_boot.img pvmfw.img dtbo.img vbmeta.img vbmeta_system.img
vbmeta_vendor.img system.img system_ext.img product.img vendor.img
vendor_dlkm.img system_dlkm.img super_empty.img"

# -----------------------------------------------------------------------------
# Canonical laguna family — the ONE definition in the readiness/wizard path.
# The wizard must NOT re-list these codenames: it consumes STATUS + REMEDY from
# this report, so a change here propagates without a second copy to drift.
#
# CROSS-REFERENCE: scripts/flash-from-remote.sh gates BOTH the stock factory
# rescue-boot path and the "NEVER try the on-device boot chain" arm on this same
# set, as the literal case arms `rango|frankel|blazer|mustang` (see its header
# and its `case "${FLASH_DEVICE:-}"` arms). That file is owned by
# T-PORT-LAGUNA-HYBRID; if the set changes there, change it here.
# Overridable for tests/CI via GT_LAGUNA_DEVICES (set it empty to simulate the
# post-boot-proof state where no family is BUILD-OK anymore).
# -----------------------------------------------------------------------------
LAGUNA_DEVICES="${GT_LAGUNA_DEVICES-rango frankel blazer mustang}"

# is_laguna <codename> — case-glob membership test (bash 3.2, no assoc arrays).
is_laguna() {
    case "${1:-}" in
        ""|*[!a-z0-9_]*) return 1 ;;
    esac
    case " ${LAGUNA_DEVICES} " in
        *" $1 "*) return 0 ;;
        *)        return 1 ;;
    esac
}

# json_str <text> — escape a string for a JSON double-quoted value (RFC 8259).
#
# T-EXCISE-READY-ACK-JSON-CONTROL-ESCAPE (D3): the previous body escaped only
# backslash and double-quote and stripped LF, so TAB (0x09), CR (0x0D), BS
# (0x08), FF (0x0C), VT (0x0B), ESC (0x1B) and every other C0 control passed
# through RAW. An ack value containing one therefore made `--json` print invalid
# JSON while the script still exited 0 — a consumer trusting the exit code got an
# unparseable report (RFC 8259: control characters in strings MUST be escaped).
#
# Method: encode the value to a per-byte HEX stream, then map each byte back to
# itself or to its JSON escape. A pure-hex intermediate is unambiguous (it can
# contain no quote, backslash, or control byte), so no escaping can be re-escaped
# and the pass is idempotent-safe. `od -An -v -tx1` is a coreutils tool with no
# locale dependence; no `LC_ALL`/sed byte-class assumptions.
#
# Backwards compatibility is REQUIRED and proven: for control-free input that
# contains no LF every byte maps to itself, so the output is BYTE-FOR-BYTE
# identical to the old body (the tr -d '\n' LF strip is preserved exactly).
json_str() {
    LC_ALL=C printf '%s' "${1:-}" \
        | od -An -v -tx1 2>/dev/null \
        | tr -d ' \n' \
        | sed -e 's/../& /g' \
        | tr ' ' '\n' \
        | while IFS= read -r _jbyte; do
              [ -n "$_jbyte" ] || continue
              case "$_jbyte" in
                  0a) : ;;                    # historical behaviour: strip LF
                  08) printf '%s' '\b' ;;
                  09) printf '%s' '\t' ;;
                  0c) printf '%s' '\f' ;;
                  0d) printf '%s' '\r' ;;
                  22) printf '%s' '\"' ;;      # historical: escape double-quote
                  5c) printf '%s' '\\' ;;      # historical: escape backslash
                  1f|0[0-9a-f]|1[0-9a-e])
                      printf '%s' "\\u00$_jbyte" ;;
                  *)  printf '%b' "\\x$_jbyte" ;;
              esac
          done
}

# -----------------------------------------------------------------------------
# Operator acknowledgement probe (T-EXCISE-READY-ACK-TIER). READ-ONLY.
#
# Sets: ACK_STATUS (none|valid|invalid), ACK_EVIDENCE, ACK_ARTIFACT, ACK_RULING,
#       ACK_OPERATOR, ACK_STAMP, ACK_SUMS_SHA, ACK_RESIDUAL.
#
# Fails CLOSED: a malformed line, an unknown/duplicate key, a missing/empty
# required key, a non-hex/!64 sha256sums_sha256, an unreadable manifest, or ANY
# device / stamp-id / SHA256SUMS-digest mismatch yields ACK_STATUS=invalid. The
# caller then leaves the device in HOLD. The ack is applied to a host-green
# device ONLY (never PENDING, never BUILD-OK).
# -----------------------------------------------------------------------------
ack_reject() { ACK_STATUS="invalid"; ACK_EVIDENCE="$1"; }

ack_probe() { # <dev> <stamp> <stampdir>
    _a_dev="$1"; _a_stamp="$2"; _a_sdir="$3"
    ACK_ARTIFACT="$ACK_DIR/$_a_dev.ack"
    ACK_STATUS="none"
    ACK_RULING=""; ACK_OPERATOR=""; ACK_STAMP=""; ACK_SUMS_SHA=""; ACK_RESIDUAL=""
    ACK_EVIDENCE="no acknowledgement artifact at $ACK_ARTIFACT (device stays HOLD)"

    [ -f "$ACK_ARTIFACT" ] || return 0

    _v_version=""; _v_type=""; _v_ruling=""; _v_operator=""
    _v_device=""; _v_stamp=""; _v_sums=""; _v_residual=""; _v_at=""
    _seen_keys=""
    while IFS= read -r _a_line || [ -n "$_a_line" ]; do
        _a_line="${_a_line%$'\r'}"
        case "$_a_line" in
            ''|\#*) continue ;;
        esac
        case "$_a_line" in
            *=*) ;;
            *) ack_reject "malformed ack line (no '=') in $ACK_ARTIFACT"; return 0 ;;
        esac
        _a_key="${_a_line%%=*}"
        _a_val="${_a_line#*=}"
        case "$_a_key" in
            ack_version)       _v_version="$_a_val" ;;
            type)              _v_type="$_a_val" ;;
            ruling_id)         _v_ruling="$_a_val" ;;
            operator)          _v_operator="$_a_val" ;;
            device)            _v_device="$_a_val" ;;
            stamp)             _v_stamp="$_a_val" ;;
            sha256sums_sha256) _v_sums="$_a_val" ;;
            residual)          _v_residual="$_a_val" ;;
            acknowledged_at)   _v_at="$_a_val" ;;
            *) ack_reject "unknown ack key '$_a_key'"; return 0 ;;
        esac
        # Duplicate detection tracks SEEN keys, not non-empty values, so an
        # empty FIRST occurrence (e.g. `operator=` then `operator=qa-engineer`)
        # still makes the ack INVALID — fail-CLOSED per the documented contract
        # (script header, "any DUPLICATE key … makes the ack INVALID").
        case " $_seen_keys " in
            *" $_a_key "*) ack_reject "duplicate ack key '$_a_key'"; return 0 ;;
        esac
        _seen_keys="$_seen_keys $_a_key"
    done < "$ACK_ARTIFACT"

    [ "$_v_version" = "1" ] || { ack_reject "ack_version is '${_v_version:-<missing>}', expected 1"; return 0; }
    [ "$_v_type" = "operator-ack" ] || { ack_reject "type is '${_v_type:-<missing>}', expected 'operator-ack'"; return 0; }
    [ -n "$_v_ruling" ]   || { ack_reject "missing/empty required key 'ruling_id'"; return 0; }
    [ -n "$_v_operator" ] || { ack_reject "missing/empty required key 'operator'"; return 0; }
    [ -n "$_v_device" ]   || { ack_reject "missing/empty required key 'device'"; return 0; }
    [ -n "$_v_stamp" ]    || { ack_reject "missing/empty required key 'stamp'"; return 0; }
    [ -n "$_v_sums" ]     || { ack_reject "missing/empty required key 'sha256sums_sha256'"; return 0; }
    [ -n "$_v_residual" ] || { ack_reject "missing/empty required key 'residual'"; return 0; }

    [ "$_v_device" = "$_a_dev" ] || { ack_reject "ack names device '$_v_device', not '$_a_dev' (an ack for one device can never mark another flashable)"; return 0; }
    [ "$_v_stamp" = "$_a_stamp" ] || { ack_reject "ack names stamp '$_v_stamp', not '$_a_stamp' (a changed stamp id invalidates the ack)"; return 0; }

    case "$_v_sums" in
        *[!0-9a-f]*) ack_reject "sha256sums_sha256 is not lowercase hex"; return 0 ;;
    esac
    [ "${#_v_sums}" = 64 ] || { ack_reject "sha256sums_sha256 is ${#_v_sums} hex chars, expected 64"; return 0; }

    if [ -z "$_a_sdir" ] || [ ! -f "$_a_sdir/SHA256SUMS" ]; then
        ack_reject "cannot bind ack: no SHA256SUMS at ${_a_sdir:-<no stamp directory>}"; return 0
    fi
    _a_actual="$(sha256sum "$_a_sdir/SHA256SUMS" 2>/dev/null | cut -d' ' -f1)"
    [ -n "$_a_actual" ] || { ack_reject "could not compute the SHA256SUMS digest of $_a_stamp"; return 0; }
    [ "$_a_actual" = "$_v_sums" ] || { ack_reject "SHA256SUMS digest mismatch for $_a_stamp (ack ${_v_sums}, stamp ${_a_actual}) — the stamp changed since the acknowledgement"; return 0; }

    ACK_STATUS="valid"
    ACK_RULING="$_v_ruling"; ACK_OPERATOR="$_v_operator"; ACK_STAMP="$_v_stamp"
    ACK_SUMS_SHA="$_v_sums"; ACK_RESIDUAL="$_v_residual"
    ACK_EVIDENCE="valid operator-ack $ACK_ARTIFACT (ruling $_v_ruling; operator $_v_operator; stamp $_v_stamp; SHA256SUMS sha256 $_v_sums)"
    return 0
}

# -----------------------------------------------------------------------------
# Clause accumulator (per device). A clause is:
#   id | provenance(stamp|family) | result(pass|fail|skip) | role(gate|classifier)
#   | confers_ready(true|false) | evidence
#
# Roles:
#   gate       — a host-verifiable, fail-closed precondition. Any gate fail/skip
#                ⇒ PENDING.
#   classifier — does not gate flashing; a fail ⇒ BUILD-OK (boot UNVERIFIED).
#   ack        — the operator-acknowledgement clause (READY-ACK). It never changes
#                a host verdict; it records whether a valid, stamp-bound operator
#                ack exists and whether it was APPLIED (host-green only).
#
# The READY verdict requires a PASSing classifier with confers_ready=true AND
# provenance=stamp. That combination does not exist today (only the `family`
# clause confers readiness), so every fully-passing device renders HOLD.
# -----------------------------------------------------------------------------
CLAUSES_JSON=""
GATE_FAIL=0
CLASSIFIER_FAIL=0
STAMP_CONFERRING_PASS=0
FIRST_GATE_FAIL=""

clause_reset() { CLAUSES_JSON=""; GATE_FAIL=0; CLASSIFIER_FAIL=0; STAMP_CONFERRING_PASS=0; FIRST_GATE_FAIL=""; }

clause_add() { # id provenance result role confers_ready evidence
    _id="$1"; _prov="$2"; _res="$3"; _role="$4"; _conf="$5"; _ev="$6"
    _frag="{\"id\":\"$_id\",\"provenance\":\"$_prov\",\"result\":\"$_res\",\"role\":\"$_role\",\"confers_ready\":$_conf,\"evidence\":\"$(json_str "$_ev")\"}"
    if [ -z "$CLAUSES_JSON" ]; then CLAUSES_JSON="$_frag"; else CLAUSES_JSON="$CLAUSES_JSON,$_frag"; fi
    case "$_role:$_res" in
        gate:fail|gate:skip)
            GATE_FAIL=$((GATE_FAIL + 1))
            if [ -z "$FIRST_GATE_FAIL" ] && [ "$_res" = fail ]; then FIRST_GATE_FAIL="$_ev"; fi
            ;;
        classifier:fail) CLASSIFIER_FAIL=$((CLASSIFIER_FAIL + 1)) ;;
    esac
    if [ "$_role" = classifier ] && [ "$_conf" = true ] && [ "$_res" = pass ] && [ "$_prov" = stamp ]; then
        STAMP_CONFERRING_PASS=1
    fi
}

TOTAL=0
READY_N=0
READY_ACK_N=0
HOLD_N=0
BUILDOK_N=0
PENDING_N=0
NOT_READY=0
NOT_STRICT=0
ACKN_VALID=0
ACKN_REJECTED=0
ACKN_APPLIED=0
DEVS_JSON=""

while IFS='|' read -r dev model; do
    [ -n "${dev:-}" ] || continue
    TOTAL=$((TOTAL + 1))
    clause_reset

    # Every device resolves its own <dev>-latest pointer. T-EXCISE-TOKAY-LATEST-REPOINT
    # retired tokay's legacy generic `latest` alias so readiness and the flasher
    # resolve the SAME bundle for tokay as for the other 12 devices.
    link="$REL/$dev-latest"

    stamp="-"
    S=""
    if [ -e "$link" ]; then
        stamp="$(readlink "$link" 2>/dev/null || true)"
        [ -n "$stamp" ] || stamp="$(basename "$link")"
        S="$REL/$stamp"
    fi

    # ---- gate 1: pointer ----------------------------------------------------
    if [ -e "$link" ]; then
        clause_add pointer stamp pass gate false "pointer present: $link -> $stamp"
    else
        clause_add pointer stamp fail gate false "no $(basename "$link") pointer under $REL"
    fi

    # ---- gate 2: stamp directory -------------------------------------------
    if [ -e "$link" ] && [ -n "$S" ] && [ -d "$S" ]; then
        clause_add stamp_dir stamp pass gate false "stamp directory present: $S"
    elif [ -e "$link" ]; then
        clause_add stamp_dir stamp fail gate false "stamp directory missing: $S"
    else
        clause_add stamp_dir stamp skip gate false "not evaluated: no pointer exists"
    fi

    if [ -n "$S" ] && [ -d "$S" ]; then
        # ---- gate 3: SHA256SUMS present AND `sha256sum -c` passes ----------
        if [ ! -f "$S/SHA256SUMS" ]; then
            clause_add sha256sums stamp fail gate false "no SHA256SUMS in stamp $stamp"
        elif ( cd "$S" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ); then
            clause_add sha256sums stamp pass gate false "SHA256SUMS present; 'sha256sum -c' passes over $(wc -l < "$S/SHA256SUMS" | tr -d ' ') entries"
        else
            clause_add sha256sums stamp fail gate false "'sha256sum -c SHA256SUMS' FAILED on stamp $stamp (tampered or truncated bundle)"
        fi

        # ---- gate 4: flash-script required file set ------------------------
        missing=""
        for f in $REQUIRED; do
            [ -f "$S/$f" ] || missing="$missing $f"
        done
        if [ -z "$missing" ]; then
            clause_add required_files stamp pass gate false "all flash-script required files present in $stamp"
        else
            clause_add required_files stamp fail gate false "missing from $stamp:$missing"
        fi

        # ---- gate 5: radio excision from the SHIPPING vendor.img manifest --
        rad="$(debugfs -R 'cat /etc/vintf/manifest.xml' "$S/vendor.img" 2>/dev/null \
               | grep -cE 'hardware\.radio|ril_ext|radioExternal' || true)"
        if [ "${rad:-1}" = "0" ]; then
            clause_add radio_excision stamp pass gate false "vendor.img manifest radio-free (0 radio/ril refs) in $stamp"
        else
            clause_add radio_excision stamp fail gate false "vendor.img manifest still has ${rad:-?} radio ref(s) in $stamp"
        fi

        # ---- classifier: unresolved first-flash risk (a fact in the stamp bytes)
        risk_block=0
        if [ -f "$S/README-FLASH-DESKTOP.md" ]; then
            if grep -qiE 'FIRST-FLASH RISK.*UNRESOLVED' "$S/README-FLASH-DESKTOP.md"; then
                risk_block=1
            fi
        fi
        if [ "$risk_block" = 1 ]; then
            clause_add no_first_flash_risk_block stamp fail classifier false "unresolved FIRST-FLASH RISK block in $stamp/README-FLASH-DESKTOP.md"
        else
            clause_add no_first_flash_risk_block stamp pass classifier false "no unresolved FIRST-FLASH RISK block in $stamp/README-FLASH-DESKTOP.md"
        fi

        # Drift guard: a README that declares a laguna first-flash risk but a
        # codename outside LAGUNA_DEVICES means the canonical list has fallen
        # behind the shipped artifacts. Warn loudly rather than silently mislabel.
        if [ "$risk_block" = 1 ] && ! is_laguna "$dev" \
           && grep -qi 'laguna' "$S/README-FLASH-DESKTOP.md"; then
            printf '[gt-ready-devices] WARNING: %s ships a laguna first-flash risk block but is not in LAGUNA_DEVICES ("%s") — the set and the stamp have drifted\n' \
                "$dev" "$LAGUNA_DEVICES" >&2
        fi
    else
        clause_add sha256sums stamp skip gate false "not evaluated: no stamp directory"
        clause_add required_files stamp skip gate false "not evaluated: no stamp directory"
        clause_add radio_excision stamp skip gate false "not evaluated: no stamp directory"
        clause_add no_first_flash_risk_block stamp skip classifier false "not evaluated: no stamp directory"
    fi

    # ---- classifier: family boot-proven (provenance=family, stamp-INDEPENDENT)
    # This is the ONLY readiness-conferring clause. It is platform-level: it
    # describes the device's *family*, not the stamp that would be flashed.
    if is_laguna "$dev"; then
        clause_add family_boot_proven family fail classifier true \
            "laguna family has NEVER booted on this platform (rango hybrid reached init 0x7f00 only; fullgt is ABL-rejected) — platform-level, stamp-INDEPENDENT"
    else
        clause_add family_boot_proven family pass classifier true \
            "platform-level and stamp-INDEPENDENT (DEC-PORT-GEN8910-WAVE2 §D4 / RULING R5): this device's family has proven on-device boot on this platform; cites NO bytes of $stamp"
    fi

    # ---- host classification (pre-provenance rule, UNCHANGED) --------------
    # Kept explicit so the provenance delta is auditable: the host-clause axis is
    # not reclassified by this change. VERDICT differs only by the provenance rule.
    if [ "$GATE_FAIL" -gt 0 ]; then
        host_classification="PENDING"
    elif [ "$CLASSIFIER_FAIL" -gt 0 ]; then
        host_classification="BUILD-OK"
    else
        host_classification="READY"
    fi

    # ---- operator acknowledgement probe (T-EXCISE-READY-ACK-TIER) ----------
    # Read-only. An ack is APPLIED only to a host-green device
    # (host_classification=READY): it can never rescue PENDING (a host gate
    # failed) or BUILD-OK (the build itself is not boot-verified) — fail-closed.
    ack_probe "$dev" "$stamp" "$S"
    ACK_APPLIES=0
    if [ "$ACK_STATUS" = "valid" ] && [ "$host_classification" = "READY" ]; then
        ACK_APPLIES=1
    fi
    case "$ACK_STATUS" in
        valid)   ACKN_VALID=$((ACKN_VALID + 1)) ;;
        invalid) ACKN_REJECTED=$((ACKN_REJECTED + 1)) ;;
    esac
    [ "$ACK_APPLIES" = 1 ] && ACKN_APPLIED=$((ACKN_APPLIED + 1))
    if [ "$ACK_STATUS" = "valid" ] && [ "$ACK_APPLIES" = 0 ]; then
        clause_add operator_ack ack skip ack false "valid ack present but NOT APPLICABLE: host_classification=$host_classification (an ack applies only to a host-green device; it cannot rescue PENDING/BUILD-OK)"
    elif [ "$ACK_STATUS" = "valid" ]; then
        clause_add operator_ack ack pass ack false "$ACK_EVIDENCE"
    elif [ "$ACK_STATUS" = "invalid" ]; then
        clause_add operator_ack ack fail ack false "ack REJECTED (fail-closed): $ACK_EVIDENCE"
    else
        clause_add operator_ack ack skip ack false "$ACK_EVIDENCE"
    fi

    # ---- verdict ------------------------------------------------------------
    if [ "$host_classification" = "PENDING" ]; then
        verdict="PENDING"
        reason="${FIRST_GATE_FAIL:-a host gate clause failed}"
        remedy="-"
        PENDING_N=$((PENDING_N + 1))
    elif [ "$host_classification" = "BUILD-OK" ]; then
        verdict="BUILD-OK"
        if is_laguna "$dev"; then
            reason="build-ok; laguna hybrid shipped but NEVER flashed on hardware (rango hybrid reached init 0x7f00 only; fullgt is ABL-rejected)"
            remedy="laguna hybrid is the best-available candidate (factory BP4A boot chain + GT logicals, com.android.virt.apex dropped, flags:3 vbmeta, 16384 B padded). Flash with GT_BOOT_CHAIN=hybrid and KEEP THE RESCUE BUNDLE. NOT boot-proven — expect G-logo->bootloader or 0x7f00/0xfc on failure; harvest 'fastboot oem dmesg' immediately."
        else
            reason="build-ok; unresolved FIRST-FLASH RISK block in stamp README (boot UNVERIFIED)"
            remedy="resolve the FIRST-FLASH RISK block in $stamp/README-FLASH-DESKTOP.md before flashing; this stamp is not boot-verified."
        fi
        BUILDOK_N=$((BUILDOK_N + 1))
    elif [ "$STAMP_CONFERRING_PASS" = 1 ]; then
        verdict="READY"
        reason="verified (all clauses pass; readiness conferred by a stamp-provenance clause)"
        remedy="-"
        READY_N=$((READY_N + 1))
    elif [ "$ACK_APPLIES" = 1 ]; then
        verdict="READY-ACK"
        reason="acknowledged NOT-STAMP-VERIFIED: host clauses PASS but readiness is NOT stamp-conferred; a VALID operator acknowledgement ($ACK_ARTIFACT) deliberately accepts the residual for $stamp — ruling $ACK_RULING, operator $ACK_OPERATOR, SHA256SUMS sha256 $ACK_SUMS_SHA. This is NOT a stamp proof and NOT boot evidence (BOOT_VERIFIED=false)."
        remedy="flash ONLY under this recorded acknowledgement (ack artifact: $ACK_ARTIFACT). Residual accepted, not proven: $ACK_RESIDUAL"
        READY_ACK_N=$((READY_ACK_N + 1))
    else
        verdict="HOLD"
        reason="host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of $stamp that would be flashed"
        remedy="do not treat as READY for $stamp; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED"
        if [ "$ACK_STATUS" = "invalid" ]; then
            reason="$reason; operator acknowledgement at $ACK_ARTIFACT was REJECTED (fail-closed): $ACK_EVIDENCE"
            remedy="fix or remove the invalid acknowledgement at $ACK_ARTIFACT; the device stays HOLD until a valid, stamp-bound acknowledgement exists"
        fi
        HOLD_N=$((HOLD_N + 1))
    fi
    case "$verdict" in
        READY)     : ;;                                              # satisfies both strict modes
        READY-ACK) NOT_READY=$((NOT_READY + 1)) ;;                   # NOT plain READY
        *)         NOT_READY=$((NOT_READY + 1)); NOT_STRICT=$((NOT_STRICT + 1)) ;;
    esac

    if [ "$JSON" = 1 ]; then
        # not_stamp_verified is true for HOLD and READY-ACK — neither is certified
        # by a stamp-provenance READY clause. `verdict` stays the authoritative
        # field; `acknowledged` distinguishes the deliberate READY-ACK tier.
        _nsv="false"; case "$verdict" in HOLD|READY-ACK) _nsv="true" ;; esac
        _hcp="false"; [ "$GATE_FAIL" = 0 ] && _hcp="true"
        _ackn="false"; [ "$ACK_APPLIES" = 1 ] && _ackn="true"
        _ackjson="null"
        if [ "$ACK_STATUS" != "none" ]; then
            _ackjson="{\"artifact\":\"$(json_str "$ACK_ARTIFACT")\",\"status\":\"$ACK_STATUS\",\"applies\":$ACK_APPLIES,\"ruling_id\":\"$(json_str "$ACK_RULING")\",\"operator\":\"$(json_str "$ACK_OPERATOR")\",\"stamp\":\"$(json_str "$ACK_STAMP")\",\"sha256sums_sha256\":\"$(json_str "$ACK_SUMS_SHA")\",\"residual\":\"$(json_str "$ACK_RESIDUAL")\",\"evidence\":\"$(json_str "$ACK_EVIDENCE")\"}"
        fi
        _dobj="{\"codename\":\"$(json_str "$dev")\",\"model\":\"$(json_str "$model")\",\"stamp\":\"$(json_str "$stamp")\",\"pointer\":\"$(json_str "$link")\",\"verdict\":\"$verdict\",\"host_classification\":\"$host_classification\",\"not_stamp_verified\":$_nsv,\"acknowledged\":$_ackn,\"ack_artifact\":\"$(json_str "$ACK_ARTIFACT")\",\"host_clauses_pass\":$_hcp,\"stamp_conferring_clauses_passed\":$STAMP_CONFERRING_PASS,\"ack\":$_ackjson,\"reason\":\"$(json_str "$reason")\",\"remedy\":\"$(json_str "$remedy")\",\"clauses\":[$CLAUSES_JSON]}"
        if [ -z "$DEVS_JSON" ]; then DEVS_JSON="$_dobj"; else DEVS_JSON="$DEVS_JSON,$_dobj"; fi
    else
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$dev" "$model" "$stamp" "$verdict" "$reason" "$remedy"
    fi
done <<EOF
$DEVICES
EOF

if [ "$JSON" = 1 ]; then
    printf '{\n'
    printf '  "tool": "gt-ready-devices",\n'
    printf '  "schema_version": 3,\n'
    printf '  "boot_verified": false,\n'
    printf '  "strict": %s,\n' "$([ "$STRICT" = 1 ] && printf true || printf false)"
    printf '  "strict_stamp_only": %s,\n' "$([ "$STRICT_STAMP_ONLY" = 1 ] && printf true || printf false)"
    printf '  "devices_total": %d,\n' "$TOTAL"
    printf '  "ready": %d,\n' "$READY_N"
    printf '  "ready_ack": %d,\n' "$READY_ACK_N"
    printf '  "hold": %d,\n' "$HOLD_N"
    printf '  "build_ok": %d,\n' "$BUILDOK_N"
    printf '  "pending": %d,\n' "$PENDING_N"
    printf '  "acknowledgements": {"valid": %d, "rejected": %d, "applied": %d},\n' "$ACKN_VALID" "$ACKN_REJECTED" "$ACKN_APPLIED"
    printf '  "devices": [\n'
    printf '    %s\n' "$DEVS_JSON"
    printf '  ]\n'
    printf '}\n'
fi

if [ "$STRICT" = 1 ]; then
    if [ "$STRICT_STAMP_ONLY" = 1 ]; then
        if [ "$NOT_READY" -gt 0 ]; then
            printf '[strict-stamp-only] %d of %d devices are not plain READY (acknowledged devices do NOT satisfy this mode); exiting 1\n' \
                "$NOT_READY" "$TOTAL" >&2
            exit 1
        fi
        printf '[strict-stamp-only] all %d devices are plain READY\n' "$TOTAL" >&2
    else
        if [ "$NOT_STRICT" -gt 0 ]; then
            printf '[strict] %d of %d devices are neither READY nor READY-ACK; exiting 1\n' \
                "$NOT_STRICT" "$TOTAL" >&2
            exit 1
        fi
        printf '[strict] all %d devices are READY or READY-ACK (%d acknowledged)\n' \
            "$TOTAL" "$READY_ACK_N" >&2
    fi
fi

exit 0
