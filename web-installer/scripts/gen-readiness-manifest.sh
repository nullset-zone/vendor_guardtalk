#!/usr/bin/env bash
# =============================================================================
# GuardTalkOS — generate the web installer's readiness manifest
#
# The web installer ships fully offline (CSP connect-src 'none'), so it cannot
# call the canonical reporter at runtime. Instead of hand-maintaining a SECOND
# copy of the device tiers — the drift the bash wizard deliberately avoids
# (`gt-flash-wizard.sh` header: "This wizard keeps NO device list of its own")
# — this script derives the browser-side manifest MECHANICALLY from the
# reporter's TSV. The generated module is checked in and must never be edited
# by hand.
#
# Source of truth (owned elsewhere; never edited here):
#   <repo root>/scripts/gt-ready-devices.sh   STATUS column
#
# Usage:
#   bash scripts/gen-readiness-manifest.sh                  # run the reporter
#   bash scripts/gen-readiness-manifest.sh --from-tsv FILE  # deterministic
#   bash scripts/gen-readiness-manifest.sh --check          # regenerate+diff
#
# The reporter reads multi-GB shipping images (sha256sum -c), so the default
# run takes minutes. --from-tsv is the reproducible path: a captured TSV in
# test/fixtures/readiness/ regenerates the manifest byte-for-byte, which is how
# the determinism test proves the manifest is not hand-written.
#
# Read-only with respect to the releases tree. Writes exactly one file.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

REPORTER_REL="../../../scripts/gt-ready-devices.sh"
REPORTER="$(cd "$ROOT" && cd "$(dirname "$REPORTER_REL")" && pwd)/$(basename "$REPORTER_REL")"
DEFAULT_OUT="$ROOT/lib/ui/readiness-manifest.ts"
# Overridable so a test can prove what the generator emits without touching the
# committed file (and without hashing the live reporter).
OUT="${GT_MANIFEST_OUT:-$DEFAULT_OUT}"
FIXTURE_TSV="$ROOT/test/fixtures/readiness/readiness-report.tsv"

# Cleanup: TARGET is always ours. RAW is only ours when we created it — in
# --from-tsv mode RAW IS the caller's file and must never be deleted.
RAW_OWNED=0
cleanup() { rm -f "$TARGET"; [ "$RAW_OWNED" = 1 ] && rm -f "$RAW"; return 0; }

MODE="run"
TSV=""
CHECK=0
while [ $# -gt 0 ]; do
    case "$1" in
        --from-tsv) MODE="tsv"; TSV="${2:-}"; shift 2 ;;
        --check)    CHECK=1; shift ;;
        -h|--help)
            printf '%s\n' \
                "usage: gen-readiness-manifest.sh [--from-tsv FILE] [--check]" \
                "" \
                "  (no args)               run $REPORTER_REL and generate $OUT" \
                "  --from-tsv FILE         generate from a captured TSV (deterministic)" \
                "  --check                 do not write; exit 1 if $OUT would change" \
                "  --from-tsv FILE --check deterministic drift check" \
                "  -h,--help               this text"
            exit 0
            ;;
        *) printf 'gen-readiness-manifest: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

if [ "$MODE" = "tsv" ]; then
    [ -n "$TSV" ] || { printf 'gen-readiness-manifest: --from-tsv needs a path\n' >&2; exit 2; }
    [ -f "$TSV" ] || { printf 'gen-readiness-manifest: no such TSV: %s\n' "$TSV" >&2; exit 2; }
    RAW="$TSV"
    SOURCE_SHA="$(sha256sum "$TSV" | awk '{print $1}')"
    SOURCE_DESC="captured readiness report ($(basename "$TSV"))"
    # Recorded reporter fingerprint (T-EXCISE-WEBINSTALL-ACK-ABSORB). The live
    # reporter is owned by another card; hashing it here coupled this otherwise
    # deterministic path to an out-of-scope file, so ANY upstream reporter edit
    # turned the drift check RED. --from-tsv therefore records the capture-time
    # fingerprint from a sibling sidecar (or an explicit override), never the
    # live reporter. Re-freezing the fingerprint is a deliberate, separate step.
    SIDE_CAR="${TSV%.tsv}.reporter.sha256"
    if [ -n "${GT_REPORTER_SHA:-}" ]; then
        REPORTER_SHA="$GT_REPORTER_SHA"
    elif [ -f "$SIDE_CAR" ]; then
        REPORTER_SHA="$(awk 'NF {print $1; exit}' "$SIDE_CAR")"
    else
        REPORTER_SHA="unrecorded"
    fi
else
    [ -f "$REPORTER" ] || { printf 'gen-readiness-manifest: reporter not found: %s\n' "$REPORTER" >&2; exit 2; }
    RAW="$(mktemp)"
    RAW_OWNED=1
    trap cleanup EXIT
    bash "$REPORTER" > "$RAW"
    SOURCE_SHA="$(sha256sum "$RAW" | awk '{print $1}')"
    SOURCE_DESC="live reporter run"
    REPORTER_SHA="$(sha256sum "$REPORTER" | awk '{print $1}')"
fi

[ -s "$RAW" ] || { printf 'gen-readiness-manifest: readiness report is empty (refusing to emit an empty manifest)\n' >&2; exit 1; }

TARGET="$(mktemp)"
trap cleanup EXIT

# Determinism: the timestamp is the only non-derived byte in the manifest, so it
# is injectable. `--check` takes it from the committed file, which makes the
# drift check a true byte-for-byte comparison of the DERIVED data.
if [ -n "${GT_MANIFEST_TIMESTAMP:-}" ]; then
    GENERATED_AT="$GT_MANIFEST_TIMESTAMP"
elif [ "$CHECK" = 1 ] && [ -f "$OUT" ]; then
    GENERATED_AT="$(sed -n 's/^  generatedAt: "\(.*\)",$/\1/p' "$OUT" | head -1)"
    [ -n "$GENERATED_AT" ] || GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
else
    GENERATED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

{
    printf '%s\n' \
        "/**" \
        " * GENERATED FILE — DO NOT EDIT BY HAND." \
        " *" \
        " * Regenerate with: bash scripts/gen-readiness-manifest.sh" \
        " * Deterministic from a captured report: bash scripts/gen-readiness-manifest.sh --from-tsv <file>" \
        " *" \
        " * Source of truth: scripts/gt-ready-devices.sh (STATUS column). That reporter is owned by" \
        " * another card and is never edited here. This module exists so the offline browser surface" \
        " * carries the host's tiers by derivation, not by a hand-maintained second copy." \
        " *" \
        " * Honesty: BOOT_VERIFIED=false programme-wide. READY is the reporter's stamp-conferred word;" \
        " * READY-ACK is an operator-acknowledged residual (NOT stamp-proven, NOT boot evidence);" \
        " * BUILD-OK means boot UNVERIFIED; HOLD means host clauses pass but the stamp is" \
        " * NOT-STAMP-VERIFIED. Nothing in this file proves that any build boots. The tier model is" \
        " * closed: an unknown STATUS makes the generator REFUSE rather than guess." \
        " */" \
        "" \
        "export type ReadinessStatus = \"READY\" | \"READY-ACK\" | \"BUILD-OK\" | \"HOLD\" | \"PENDING\";" \
        "" \
        "export interface ReadinessManifestEntry {" \
        "  readonly codename: string;" \
        "  readonly model: string;" \
        "  readonly stamp: string;" \
        "  readonly status: ReadinessStatus;" \
        "  readonly reason: string;" \
        "  readonly remedy: string;" \
        "}" \
        "" \
        "export interface ReadinessManifestProvenance {" \
        "  readonly sourceScript: string;" \
        "  readonly sourceScriptSha256: string;" \
        "  readonly sourceDescription: string;" \
        "  readonly sourceSha256: string;" \
        "  readonly generatedAt: string;" \
        "}"
} > "$TARGET"

printf '\n%s\n' "export const READINESS_MANIFEST_PROVENANCE: ReadinessManifestProvenance = {" >> "$TARGET"
printf '  sourceScript: %s,\n' "\"scripts/gt-ready-devices.sh\"" >> "$TARGET"
printf '  sourceScriptSha256: %s,\n' "\"$REPORTER_SHA\"" >> "$TARGET"
printf '  sourceDescription: %s,\n' "\"$SOURCE_DESC\"" >> "$TARGET"
printf '  sourceSha256: %s,\n' "\"$SOURCE_SHA\"" >> "$TARGET"
printf '  generatedAt: %s,\n' "\"$GENERATED_AT\"" >> "$TARGET"
printf '%s\n' "};" "" "export const READINESS_MANIFEST: readonly ReadinessManifestEntry[] = [" >> "$TARGET"

ROWS=0
# Columns: codename <TAB> model <TAB> stamp <TAB> STATUS <TAB> reason <TAB> remedy
while IFS="$(printf '\t')" read -r dev model stamp status reason remedy; do
    [ -n "${dev:-}" ] || continue
    case "${status:-}" in
        READY|READY-ACK|BUILD-OK|HOLD|PENDING) ;;
        *)
            printf 'gen-readiness-manifest: unknown STATUS "%s" for %s — refusing to guess a tier\n' \
                "${status:-}" "$dev" >&2
            exit 1
            ;;
    esac
    esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
    printf '  {\n' >> "$TARGET"
    printf '    codename: "%s",\n' "$(esc "$dev")" >> "$TARGET"
    printf '    model: "%s",\n' "$(esc "$model")" >> "$TARGET"
    printf '    stamp: "%s",\n' "$(esc "$stamp")" >> "$TARGET"
    printf '    status: "%s",\n' "$status" >> "$TARGET"
    printf '    reason: "%s",\n' "$(esc "$reason")" >> "$TARGET"
    printf '    remedy: "%s",\n' "$(esc "$remedy")" >> "$TARGET"
    printf '  },\n' >> "$TARGET"
    ROWS=$((ROWS + 1))
done < "$RAW"

printf '%s\n' "];" >> "$TARGET"

[ "$ROWS" -gt 0 ] || { printf 'gen-readiness-manifest: parsed 0 rows — refusing to emit a vacuous manifest\n' >&2; exit 1; }

if [ "$CHECK" = 1 ]; then
    if diff -q "$TARGET" "$OUT" >/dev/null 2>&1; then
        printf '[gen-readiness-manifest] %s is up to date (%s rows)\n' "$OUT" "$ROWS"
        exit 0
    fi
    printf '[gen-readiness-manifest] DRIFT: %s does not match the readiness report\n' "$OUT" >&2
    diff "$OUT" "$TARGET" >&2 || true
    exit 1
fi

cp "$TARGET" "$OUT"
printf '[gen-readiness-manifest] wrote %s (%s rows, statuses from %s)\n' "$OUT" "$ROWS" "$SOURCE_DESC"
printf '[gen-readiness-manifest] source sha256 %s\n' "$SOURCE_SHA"
