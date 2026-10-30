#!/usr/bin/env bash
# =============================================================================
# Q-DEVICE-ALIGN-ADVERTISE — static gate for the advertised-device card.
#
# Target (READ ONLY — this gate never writes it):
#   vendor/guardtalk/web-installer/lib/ui/offered-devices.ts
#
# SCOPE, STATED HONESTLY. This is a BASH STATIC GATE over SOURCE TEXT ONLY.
# The paired feature F-DEVICE-ALIGN-ADVERTISE claims `npm test 596/595/0/1` and
# `tsc rc=0`. `node` and `npm` are ABSENT on this host (`which node npm` -> no
# output), so those claims CANNOT be reproduced here. The TypeScript half of
# the card is therefore UNVERIFIED ON THIS HOST and must be run on a host with
# node/npm before the feature may be approved. This gate does NOT run, and does
# NOT claim, any npm / tsc / test-runner result.
#
# Clauses (source-text invariants, five required by the card):
#   Clause 1  OFFERED SET IS EXACTLY FOUR: tokay, akita, komodo, rango.
#             C03-C06. Adding or removing an offered device must FAIL.
#   Clause 2  EVERY WITHHELD DEVICE HAS A WRITTEN REASON: WITHHELD_REASONS is
#             exhaustive over FleetCodename minus the offered set. C07-C11.
#             A withheld device with no (or a stub) reason must FAIL.
#   Clause 3  `rango` REMAINS `experimental`. C12-C14. A silent promotion to
#             `supported` must FAIL.
#   Clause 4  `statusJsonChipWord` and `statusChipWord` remain SEPARATE, DISTINCT
#             exports. C15-C18. Merging them must FAIL. The separation is
#             deliberate (DEC-WEBINSTALL-015 marketing status vs the shipped
#             `status.json` facts, which yield "NOT IN status.json" for komodo).
#   Clause 5  `assertOfferedImpliesComplete` is exported EXACTLY ONCE. C19-C20.
#             A duplicate export must FAIL — the concurrent second dispatcher
#             (DEC-DEVICE-ALIGN-010) injected exactly that on 2026-10-29.
#   C21       regression net for the preserved duplicate block: none of its
#             identifiers may be present in the live file.
#
# NON-VACUITY IS MANDATORY (DEC-DEVICE-ALIGN-012). This wave produced the
# vacuous-verification defect three independent times, so a gate that passes
# the live tree without proving it CAN fail is not approvable. `--self-test`
# copies the gate and the target into `mktemp -d` sandboxes, injects six
# mutations (a 5th offered device, a removed withheld reason, rango promoted to
# supported, a duplicate assertOfferedImpliesComplete export, the
# "NOT IN status.json" return invented away, statusJsonChipWord un-exported)
# and requires each to FAIL with the expected clause message, plus a POSITIVE
# CONTROL in which an unmutated sandbox PASSES. The live tree is never written.
#
# Method: source-text extraction with explicit expected counts. Every count is
# asserted; a zero-match grep (rc=1) is treated as count=0 and compared against
# an explicit expectation, never as a silent pass.
#
# Usage (from the GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_webinstall_offered_devices_static.sh
#   bash vendor/guardtalk/docs/qa/verify_webinstall_offered_devices_static.sh --self-test
#
# rc: 0 = all clauses PASS (HOLD lines do not fail the gate)
#     1 = at least one clause FAILED
#     --self-test: 0 = every injected mutation was detected as designed
# =============================================================================
set -euo pipefail
SELF_ABS="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SELF_BASE="$(basename "$0")"
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

# --- non-vacuity helpers (DEC-DEVICE-ALIGN-012) -----------------------------
# count_of ALWAYS prints an integer. A zero-match rg (rc=1, empty stdout) must
# never be distinguishable from "the pattern is wrong" by the caller, so every
# caller compares against an explicit expected count and FAILS on mismatch.
count_of() { # <file> <regex>
  local n rc=0
  n="$(rg -c -- "$2" "$1" 2>/dev/null)" || rc=$?
  if [[ -z "${n:-}" ]]; then n=0; fi
  printf '%s\n' "$n"
}
require_count() { # <tag> <file> <regex> <expected> <label>
  local tag="$1" file="$2" re="$3" want="$4" label="$5" n
  if [[ ! -f "$file" ]]; then fail "[$tag] $label (file missing: $file)"; return; fi
  n="$(count_of "$file" "$re")"
  if [[ "$n" == "$want" ]]; then
    pass "[$tag] $label (count=$n)"
  else
    fail "[$tag] $label (count=$n, expected $want; pattern '$re')"
  fi
}

TS="vendor/guardtalk/web-installer/lib/ui/offered-devices.ts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Operative text: block comments become blank lines (line numbers preserved so
# function/block bounds stay meaningful), comment-only `//` lines are blanked.
# A comment that merely DESCRIBES a required shape must not be able to satisfy
# the clause. The one block-comment shape that could distort a literal is not
# present in this file (no `/*` inside a string literal).
TS_NC="$TMP/offered-devices.nocomment.ts"
if [[ -f "$TS" ]]; then
  perl -0pe 's{/\*.*?\*/}{ my $m = $&; $m =~ s/[^\n]//g; $m }ge' "$TS" \
    | sed -E 's#^[[:space:]]*//.*$##' > "$TS_NC"
else
  : > "$TS_NC"
fi

echo "=== Q-DEVICE-ALIGN-ADVERTISE case1: target present and operative ==="
echo "TARGET=$TS"
if [[ -f "$TS" && -s "$TS" ]]; then
  pass "[C01] target present and non-empty ($(wc -l < "$TS" | tr -d ' ') lines)"
else
  fail "[C01] target missing or empty: $TS"
fi
TS_NC_LINES=0
if [[ -f "$TS_NC" ]]; then TS_NC_LINES="$(wc -l < "$TS_NC" | tr -d ' ')"; fi
EXPORT_N="$(count_of "$TS_NC" '^export ')"
if [[ "$TS_NC_LINES" -ge 100 && "$EXPORT_N" -ge 20 ]]; then
  pass "[C02] operative text substantive after comment stripping (lines=$TS_NC_LINES exports=$EXPORT_N)"
else
  fail "[C02] operative text too small (lines=$TS_NC_LINES exports=$EXPORT_N; need >=100 lines and >=20 exports) — comment stripping or the target is broken"
fi
hold "[C00] TypeScript/npm half UNVERIFIED ON THIS HOST (node/npm absent): this gate asserts source text only; run npm test + tsc elsewhere before approving F-DEVICE-ALIGN-ADVERTISE"

# --- extraction helpers ------------------------------------------------------
# block_bounds_lit <file> <start-regex> <end-trimmed-literal> -> "s e"
block_bounds_lit() {
  local file="$1" sre="$2" endlit="$3" s e
  s="$(rg -n -- "$sre" "$file" 2>/dev/null | head -1 | cut -d: -f1)" || true
  if [[ -z "${s:-}" ]]; then printf '0 0\n'; return; fi
  e="$(awk -v s="$s" -v lit="$endlit" '
    NR > s {
      l = $0
      sub(/^[[:space:]]+/, "", l)
      sub(/[[:space:]]+$/, "", l)
      if (l == lit) { print NR; exit }
    }' "$file")" || true
  printf '%s %s\n' "$s" "${e:-0}"
}
# clip <file> <start> <end> <out> — writes the closed line range, or empty.
clip() {
  local file="$1" s="$2" e="$3" out="$4"
  if [[ "$s" != "0" && "$e" != "0" && "$e" -ge "$s" ]]; then
    sed -n "${s},${e}p" "$file" > "$out"
  else
    : > "$out"
  fi
}
# fn_block <file> <name> <out> — body of `export function <name>(` to the first
# COLUMN-0 closing brace. Exact comparison is deliberate: a trimmed `}` would
# stop at an indented nested brace (the statusJsonChipWord switch) and truncate
# the body, which would make C17/C18 silently vacuous.
fn_block() {
  local file="$1" name="$2" out="$3" s e
  s="$(rg -n -- "^export function ${name}\\(" "$file" 2>/dev/null | head -1 | cut -d: -f1)" || true
  if [[ -z "${s:-}" ]]; then : > "$out"; return; fi
  e="$(awk -v s="$s" 'NR > s && $0 == "}" { print NR; exit }' "$file")" || true
  clip "$file" "$s" "${e:-0}" "$out"
}

OFFERED_EXPECTED=$'akita\nkomodo\nrango\ntokay'

W_BLOCK="$TMP/wizard-devices.block.ts"
W_B="$(block_bounds_lit "$TS_NC" '^export const WIZARD_DEVICES' '];')"
clip "$TS_NC" "${W_B%% *}" "${W_B##* }" "$W_BLOCK"

FLEET_BLOCK="$TMP/fleet-codenames.block.ts"
if [[ -f "$TS_NC" ]]; then
  awk '
    /^export type FleetCodename =/ { on = 1 }
    on { print }
    on && /;[[:space:]]*$/ { exit }
  ' "$TS_NC" > "$FLEET_BLOCK"
else
  : > "$FLEET_BLOCK"
fi

WH_BLOCK="$TMP/withheld-reasons.block.ts"
WH_B="$(block_bounds_lit "$TS_NC" '^export const WITHHELD_REASONS' '};')"
clip "$TS_NC" "${WH_B%% *}" "${WH_B##* }" "$WH_BLOCK"

echo "=== Q-DEVICE-ALIGN-ADVERTISE clause1: offered set is exactly four ==="

# C03 — the `WizardDevice.id` union must name exactly the four offered codenames.
ID_LINE="$TMP/id-union.txt"
rg -m1 '^[[:space:]]*readonly id: "[a-z0-9_]+"( \| "[a-z0-9_]+")+;' "$TS_NC" > "$ID_LINE" 2>/dev/null || true
if [[ -s "$ID_LINE" ]]; then
  rg -o '"[a-z0-9_]+"' "$ID_LINE" | tr -d '"' | sort > "$TMP/id-union.ids"
  ID_N="$(wc -l < "$TMP/id-union.ids" | tr -d ' ')"
  ID_SET="$(sort -u "$TMP/id-union.ids" | tr '\n' ' ' | sed 's/ $//')"
  if [[ "$ID_N" == "4" && "$(sort "$TMP/id-union.ids" | tr '\n' ' ' | sed 's/ $//')" == "akita komodo rango tokay" ]]; then
    pass "[C03] WizardDevice.id union names exactly 4 codenames ($ID_SET)"
  else
    fail "[C03] WizardDevice.id union is not the four offered codenames (members=$ID_N set='$ID_SET')"
  fi
else
  fail "[C03] WizardDevice.id union line not found — clause 1 cannot be evaluated"
fi

# C04 — exactly four entries inside the WIZARD_DEVICES array literal. Three of
# the entries are single-line `{ id: ... }` objects, so the id is matched
# anywhere after whitespace, not only at line start.
require_count C04 "$W_BLOCK" '[[:space:]]id: "[a-z0-9_]+"' 4 \
  "WIZARD_DEVICES holds exactly 4 device entries"

# C05 — the offered id SET equals the expected four (order-insensitive, so a
# rename or a swap fails while harmless formatting does not).
OFFERED_ACTUAL="$TMP/offered.ids"
if [[ -s "$W_BLOCK" ]]; then
  rg -o 'id: "[a-z0-9_]+"' "$W_BLOCK" | sed -E 's/.*"([a-z0-9_]+)"/\1/' | sort -u > "$OFFERED_ACTUAL"
else
  : > "$OFFERED_ACTUAL"
fi
OFFERED_N="$(wc -l < "$OFFERED_ACTUAL" | tr -d ' ')"
if [[ "$OFFERED_N" == "4" && "$(cat "$OFFERED_ACTUAL")" == "$OFFERED_EXPECTED" ]]; then
  pass "[C05] offered set == {tokay, akita, komodo, rango} (measured: $(tr '\n' ' ' < "$OFFERED_ACTUAL" | sed 's/ $//'))"
else
  fail "[C05] offered set CHANGED — measured $(tr '\n' ' ' < "$OFFERED_ACTUAL" | sed 's/ $//')(n=$OFFERED_N), expected 'tokay akita komodo rango'; adding or removing an offered device is an operator decision (DEC-DEVICE-ALIGN-002)"
fi

# C06 — no duplicate id inside the array, and every offered id is a fleet codename.
RAW_ID_N="$(count_of "$W_BLOCK" '[[:space:]]id: "[a-z0-9_]+"')"
FLEET_MEMBERS="$TMP/fleet.ids"
if [[ -s "$FLEET_BLOCK" ]]; then
  rg -o '"[a-z0-9_]+"' "$FLEET_BLOCK" | tr -d '"' | sort -u > "$FLEET_MEMBERS"
else
  : > "$FLEET_MEMBERS"
fi
FLEET_N="$(wc -l < "$FLEET_MEMBERS" | tr -d ' ')"
ORPHAN_OFFERED=0
while IFS= read -r oid; do
  [[ -z "$oid" ]] && continue
  rg -qxF -- "$oid" "$FLEET_MEMBERS" || { ORPHAN_OFFERED=$((ORPHAN_OFFERED + 1)); echo "      offered-but-not-in-fleet: $oid"; }
done < "$OFFERED_ACTUAL"
if [[ "$RAW_ID_N" -eq "$OFFERED_N" && "$ORPHAN_OFFERED" -eq 0 && "$OFFERED_N" -gt 0 ]]; then
  pass "[C06] offered ids are unique (raw=$RAW_ID_N unique=$OFFERED_N) and all 4 are FleetCodename members (orphans=0)"
else
  fail "[C06] offered ids duplicate or outside the fleet (raw=$RAW_ID_N unique=$OFFERED_N orphans=$ORPHAN_OFFERED)"
fi

echo "=== Q-DEVICE-ALIGN-ADVERTISE clause2: every withheld device has a written reason ==="

# C07 — the fleet union is the denominator; a broken parse here would make an
# exhaustiveness claim vacuous, so pin it and require it to contain the offered 4.
MISSING_IN_FLEET=0
while IFS= read -r oid; do
  [[ -z "$oid" ]] && continue
  rg -qxF -- "$oid" "$FLEET_MEMBERS" || MISSING_IN_FLEET=$((MISSING_IN_FLEET + 1))
done < "$OFFERED_ACTUAL"
if [[ "$FLEET_N" -eq 14 && "$MISSING_IN_FLEET" -eq 0 ]]; then
  pass "[C07] FleetCodename union parsed with 14 members and contains all 4 offered ids"
else
  fail "[C07] FleetCodename union unusable (members=$FLEET_N, expected 14; offered ids missing from fleet=$MISSING_IN_FLEET)"
fi

# C08 — reason cardinality == withheld cardinality (fleet - offered), computed,
# not hardcoded twice, so the two sides cannot drift apart silently.
REASON_KEYS="$TMP/reason.ids"
if [[ -s "$WH_BLOCK" ]]; then
  rg -o '^  [a-z0-9_]+:$' "$WH_BLOCK" | sed -E 's/[: ]//g' | sort -u > "$REASON_KEYS"
else
  : > "$REASON_KEYS"
fi
REASON_N="$(wc -l < "$REASON_KEYS" | tr -d ' ')"
EXPECT_WITHHELD=$((FLEET_N - OFFERED_N))
if [[ "$EXPECT_WITHHELD" -gt 0 && "$REASON_N" -eq "$EXPECT_WITHHELD" ]]; then
  pass "[C08] WITHHELD_REASONS has $REASON_N reasons == fleet($FLEET_N) - offered($OFFERED_N)"
else
  fail "[C08] WITHHELD_REASONS has $REASON_N reasons, expected $EXPECT_WITHHELD (fleet=$FLEET_N offered=$OFFERED_N) — a withheld device is unexplained or a reason is orphaned"
fi

# C09 — exact set equality: reason keys == fleet minus offered.
WITHHELD_SET="$TMP/withheld.ids"
comm -23 "$FLEET_MEMBERS" "$OFFERED_ACTUAL" > "$WITHHELD_SET"
MISSING_REASON=0
ORPHAN_REASON=0
while IFS= read -r wid; do
  [[ -z "$wid" ]] && continue
  rg -qxF -- "$wid" "$REASON_KEYS" || { MISSING_REASON=$((MISSING_REASON + 1)); echo "      withheld with NO reason: $wid"; }
done < "$WITHHELD_SET"
while IFS= read -r rid; do
  [[ -z "$rid" ]] && continue
  rg -qxF -- "$rid" "$WITHHELD_SET" || { ORPHAN_REASON=$((ORPHAN_REASON + 1)); echo "      reason for a non-withheld/unknown id: $rid"; }
done < "$REASON_KEYS"
WITHHELD_N="$(wc -l < "$WITHHELD_SET" | tr -d ' ')"
if [[ "$WITHHELD_N" -gt 0 && "$MISSING_REASON" -eq 0 && "$ORPHAN_REASON" -eq 0 ]]; then
  pass "[C09] reason keys are EXACTLY the withheld set ($WITHHELD_N devices; missing=0 orphaned=0)"
else
  fail "[C09] reason keys != withheld set (withheld=$WITHHELD_N missing_reason=$MISSING_REASON orphaned_reason=$ORPHAN_REASON)"
fi

# C10/C11 — parse each reason literal: length (stub guard) and self-naming
# (a copy-pasted reason for the wrong device must not pass).
REASONS_TSV="$TMP/reasons.tsv"
if [[ -s "$WH_BLOCK" ]]; then
  awk '
    /^[[:space:]]*[a-z0-9_]+:[[:space:]]*$/ {
      k = $0; gsub(/[[:space:]:]/, "", k); next
    }
    k != "" && /^[[:space:]]*"/ {
      s = $0
      sub(/^[[:space:]]*"/, "", s)
      sub(/",?[[:space:]]*$/, "", s)
      self = (index(s, "device/" k) > 0) ? 1 : 0
      printf "%s\t%d\t%d\n", k, length(s), self
      k = ""
    }
  ' "$WH_BLOCK" > "$REASONS_TSV"
else
  : > "$REASONS_TSV"
fi
PARSED_N="$(wc -l < "$REASONS_TSV" | tr -d ' ')"
SHORT_N="$(awk -F'\t' '$2 < 40' "$REASONS_TSV" | wc -l | tr -d ' ')"
if [[ "$PARSED_N" -eq "$REASON_N" && "$REASON_N" -gt 0 && "$SHORT_N" -eq 0 ]]; then
  pass "[C10] every reason parsed ($PARSED_N/$REASON_N) and is substantive (>=40 chars; stubs=0)"
else
  fail "[C10] reason literals unusable or stubbed (parsed=$PARSED_N/$REASON_N short=$SHORT_N)"
fi
UNSELF_N="$(awk -F'\t' '$3 != 1' "$REASONS_TSV" | wc -l | tr -d ' ')"
if [[ "$PARSED_N" -gt 0 && "$UNSELF_N" -eq 0 ]]; then
  pass "[C11] every reason names its own device path (device/<codename>; mismatches=0)"
else
  fail "[C11] $UNSELF_N reason(s) do not name their own device path — a copied reason cannot be trusted"
fi

echo "=== Q-DEVICE-ALIGN-ADVERTISE clause3: rango stays experimental ==="

# C12 — the status vocabulary must still admit "experimental"; deleting it would
# make clause 3 unexpressible.
require_count C12 "$TS_NC" '^export type OfferedDeviceStatus = "supported" \| "experimental";$' 1 \
  "OfferedDeviceStatus retains the experimental member"

# C13 — the rango entry inside WIZARD_DEVICES carries status "experimental".
RANGO_BLOCK="$TMP/rango.block.ts"
R_B="$(block_bounds_lit "$W_BLOCK" '^[[:space:]]*id: "rango",$' '},')"
clip "$W_BLOCK" "${R_B%% *}" "${R_B##* }" "$RANGO_BLOCK"
if [[ -s "$RANGO_BLOCK" ]]; then
  R_EXP="$(count_of "$RANGO_BLOCK" '^[[:space:]]*status: "experimental",$')"
  R_SUP="$(count_of "$RANGO_BLOCK" '^[[:space:]]*status: "supported",$')"
else
  R_EXP=0; R_SUP=0
fi
if [[ "$R_EXP" == "1" && "$R_SUP" == "0" ]]; then
  pass "[C13] rango entry status == experimental (experimental=1 supported=0)"
else
  fail "[C13] rango entry is NOT experimental (experimental=$R_EXP supported=$R_SUP) — a silent promotion to supported is forbidden"
fi

# C14 — exactly one experimental entry in the whole picker, and it is rango.
EXP_TOTAL="$(count_of "$W_BLOCK" '^[[:space:]]*status: "experimental",$')"
if [[ "$EXP_TOTAL" == "1" && "$R_EXP" == "1" ]]; then
  pass "[C14] exactly one experimental picker entry and it is rango (experimental_entries=$EXP_TOTAL)"
else
  fail "[C14] experimental entry count=$EXP_TOTAL with rango experimental=$R_EXP — expected exactly one, rango's"
fi

echo "=== Q-DEVICE-ALIGN-ADVERTISE clause4: the two chip words stay separate ==="

# C15/C16 — each is its own export; together they are exactly two exports. A
# merge (one function, one alias) drops a count and fails.
require_count C15 "$TS_NC" '^export function statusJsonChipWord\(' 1 \
  "statusJsonChipWord is exported exactly once"
require_count C16 "$TS_NC" '^export function statusChipWord\(' 1 \
  "statusChipWord is exported exactly once"
CHIP_EXPORTS="$(count_of "$TS_NC" '^export (function|const) status(Json)?ChipWord[<(=]')"
if [[ "$CHIP_EXPORTS" == "2" ]]; then
  pass "[C16b] exactly two distinct chip-word exports exist ($CHIP_EXPORTS); merging them would fail this count"
else
  fail "[C16b] chip-word export count=$CHIP_EXPORTS, expected 2 (statusJsonChipWord + statusChipWord) — the two facts must not be conflated"
fi

# C17 — statusJsonChipWord must still derive from the status.json facts and
# still say "NOT IN status.json" for the komodo case. This is the honesty the
# card requires to survive.
SJC_BLOCK="$TMP/statusJsonChipWord.block.ts"
fn_block "$TS_NC" statusJsonChipWord "$SJC_BLOCK"
SJC_FACT="$(count_of "$SJC_BLOCK" 'switch \(statusJsonFact\(product\)\)')"
SJC_ABSENT="$(count_of "$SJC_BLOCK" 'return "NOT IN status\.json";')"
if [[ "$SJC_FACT" == "1" && "$SJC_ABSENT" == "1" ]]; then
  pass "[C17] statusJsonChipWord derives from statusJsonFact and yields \"NOT IN status.json\" (case present)"
else
  fail "[C17] statusJsonChipWord honesty lost (statusJsonFact dispatch=$SJC_FACT, NOT-IN-status.json return=$SJC_ABSENT)"
fi

# C18 — neither function may be an alias of the other: the separation is the point.
SJC_CROSS="$(count_of "$SJC_BLOCK" 'statusChipWord')"
SC_BLOCK="$TMP/statusChipWord.block.ts"
fn_block "$TS_NC" statusChipWord "$SC_BLOCK"
SC_CROSS="$(count_of "$SC_BLOCK" 'statusJsonChipWord')"
SC_BLOCK_SZ="$(wc -l < "$SC_BLOCK" | tr -d ' ')"
if [[ "$SJC_CROSS" == "0" && "$SC_CROSS" == "0" && "$SC_BLOCK_SZ" -gt 0 ]]; then
  pass "[C18] statusJsonChipWord and statusChipWord do not reference each other (cross=0/0; independent functions)"
else
  fail "[C18] chip-word functions are coupled (json->marketing=$SJC_CROSS, marketing->json=$SC_CROSS, statusChipWord_block_lines=$SC_BLOCK_SZ) — they must stay distinct facts"
fi

echo "=== Q-DEVICE-ALIGN-ADVERTISE clause5: assertOfferedImpliesComplete exported once ==="

# C19 — exactly one export declaration, no non-exported duplicate, and exactly
# one occurrence of the identifier in operative text. The last count is the
# duplicate net for a `const` re-export form the first two patterns would miss.
require_count C19 "$TS_NC" '^export function assertOfferedImpliesComplete\(' 1 \
  "assertOfferedImpliesComplete has exactly one export declaration"
DUP_DECL="$(count_of "$TS_NC" '^function assertOfferedImpliesComplete\(')"
TOTAL_OCC="$(count_of "$TS_NC" 'assertOfferedImpliesComplete')"
if [[ "$DUP_DECL" == "0" && "$TOTAL_OCC" == "1" ]]; then
  pass "[C19b] no duplicate/alias declaration (non-exported decls=$DUP_DECL, total occurrences=$TOTAL_OCC)"
else
  fail "[C19b] duplicate identifier present (non-exported declarations=$DUP_DECL, total occurrences=$TOTAL_OCC, expected 0 and 1)"
fi

# C20 — the single export is the injectable predicate the card describes, not a
# same-named stub that would keep every count green while doing nothing.
AO_BLOCK="$TMP/assertOfferedImpliesComplete.block.ts"
fn_block "$TS_NC" assertOfferedImpliesComplete "$AO_BLOCK"
AO_P1="$(count_of "$AO_BLOCK" 'offeredIds: readonly string\[\] = offeredProductIds\(\)')"
AO_P2="$(count_of "$AO_BLOCK" 'fleet: readonly DeviceCapabilityRow\[\] = DEVICE_FLEET')"
AO_THROW="$(count_of "$AO_BLOCK" 'throw new OfferedCapabilityError\(violations\)')"
if [[ "$AO_P1" == "1" && "$AO_P2" == "1" && "$AO_THROW" == "1" ]]; then
  pass "[C20] assertOfferedImpliesComplete keeps both injectable parameters and still throws on violations"
else
  fail "[C20] assertOfferedImpliesComplete shape changed (offeredIds param=$AO_P1, fleet param=$AO_P2, throw=$AO_THROW) — a same-named stub must not pass clause 5"
fi

echo "=== Q-DEVICE-ALIGN-ADVERTISE case2: concurrent-duplicate regression net ==="
# C21 — the second dispatcher's block (DEC-DEVICE-ALIGN-010) defined these
# identifiers. None may return to the live file; if they do, re-read the
# preserved copy at .agent-comm/evidence/F-DEVICE-ALIGN-ADVERTISE/ before acting.
for sym in DEVICE_LAYER_FACTS WITHHELD_DEVICES OfferedDeviceIncompleteError 'device-capability\.test'; do
  n="$(count_of "$TS_NC" "$sym")"
  if [[ "$n" != "0" ]]; then
    fail "[C21] foreign identifier '$sym' present ($n occurrence(s)) — the concurrent duplicate block may have been re-injected; STOP and preserve evidence (DEC-DEVICE-ALIGN-010)"
  fi
done
C21_FOREIGN="$(count_of "$TS_NC" 'DEVICE_LAYER_FACTS|WITHHELD_DEVICES|OfferedDeviceIncompleteError|device-capability\.test')"
if [[ "$C21_FOREIGN" == "0" ]]; then
  pass "[C21] no identifier from the preserved concurrent duplicate block is present (foreign=0)"
fi

# --- self-test: non-vacuity proven by injection (DEC-DEVICE-ALIGN-012) -------
self_test() {
  local base sb name rc st_fail=0 st_pass=0
  local -a ST_NAMES=()
  base="$(mktemp -d)"

  # Sandbox = a copy of this gate + a copy of the target, at the same relative
  # paths, so ROOT resolution inside the sandbox finds the mutated copy and
  # nothing else. The live tree is only ever READ.
  build_sandbox() { # <dir>
    local dir="$1"
    mkdir -p "$dir/vendor/guardtalk/docs/qa" "$dir/vendor/guardtalk/web-installer/lib/ui"
    cp "$SELF_ABS" "$dir/vendor/guardtalk/docs/qa/$SELF_BASE"
    if [[ -f "$TS" ]]; then
      cp "$TS" "$dir/vendor/guardtalk/web-installer/lib/ui/offered-devices.ts"
    fi
  }
  run_case() { # <name> <dir> <expected-rc> <expected-regex|""> <label>
    local nm="$1" dir="$2" want_rc="$3" want_re="$4" label="$5"
    local out r=0
    out="$(bash "$dir/vendor/guardtalk/docs/qa/$SELF_BASE" 2>&1)" || r=$?
    ST_NAMES+=("$nm")
    if [[ "$r" != "$want_rc" ]]; then
      fail "[ST] $nm: rc=$r expected $want_rc — $label"
      printf '%s\n' "$out" | tail -8
      st_fail=$((st_fail + 1)); return
    fi
    # Vacuity guard for the injection itself: the sandboxed gate must have run
    # to completion (summary exactly once), not died before its clauses.
    local nsum
    nsum="$(printf '%s\n' "$out" | rg -c '^CHECKIN_RESULT: STATIC' || true)"
    if [[ "${nsum:-0}" != "1" ]]; then
      fail "[ST] $nm: sandboxed gate produced ${nsum:-0} summary line(s) — injection result unusable"
      printf '%s\n' "$out" | tail -8
      st_fail=$((st_fail + 1)); return
    fi
    if [[ -n "$want_re" ]]; then
      if ! printf '%s\n' "$out" | rg -q -- "$want_re"; then
        fail "[ST] $nm: rc was $r as designed but expected message /$want_re/ is absent — the gate may have failed for the wrong reason"
        printf '%s\n' "$out" | rg -m3 '^FAIL: ' || true
        st_fail=$((st_fail + 1)); return
      fi
    fi
    pass "[ST] $nm: rc=$r as designed — $label"
    # Record WHAT the injected gate actually said, verbatim, so this log is its
    # own evidence and a future reader need not re-derive the failure.
    local obs obs_summary
    obs="$(printf '%s\n' "$out" | rg -m1 '^FAIL: ' || true)"
    obs_summary="$(printf '%s\n' "$out" | rg -m1 '^CHECKIN_RESULT: STATIC' || true)"
    if [[ -n "$obs" ]]; then echo "      observed: $obs"; fi
    if [[ -n "$obs_summary" ]]; then echo "      measured: $obs_summary"; fi
    st_pass=$((st_pass + 1))
  }
  mutated_ok() { # <tag> <pre-file> <mutated-file> <label>
    if [[ -f "$2" && -f "$3" ]] && ! cmp -s "$2" "$3"; then
      pass "[$1] mutation applied: $4"
    else
      fail "[$1] mutation did NOT change the file — injection would be vacuous ($4)"
      return 1
    fi
  }
  sandbox_ts() { printf '%s/vendor/guardtalk/web-installer/lib/ui/offered-devices.ts\n' "$1"; }

  echo ""
  echo "=== Q-DEVICE-ALIGN-ADVERTISE --self-test: injections (expect FAIL where marked) ==="

  # ST-1 — CLAUSE 1: a FIFTH device appended to the offered list.
  sb="$base/inj1"; build_sandbox "$sb"
  F="$(sandbox_ts "$sb")"; cp "$F" "$base/inj1.pre"
  wb="$(block_bounds_lit "$F" '^export const WIZARD_DEVICES' '];')"
  we="${wb##* }"
  if [[ "$we" != "0" ]]; then
    awk -v at="$we" 'NR==at { print "  { id: \"tegu\", deviceName: \"Pixel 9a\", label: \"Pixel 9a (tegu)\", status: \"supported\" }," } { print }' \
      "$F" > "$F.new" && mv "$F.new" "$F"
  fi
  if mutated_ok ST-1 "$base/inj1.pre" "$F" "5th offered device (tegu) added"; then
    run_case inject-fifth-offered-device "$sb" 1 'FAIL: \[C0[45]\] ' \
      "clause 1 rejects a widened offered set"
  fi

  # ST-2 — CLAUSE 2: one withheld device's written reason deleted.
  sb="$base/inj2"; build_sandbox "$sb"
  F="$(sandbox_ts "$sb")"; cp "$F" "$base/inj2.pre"
  awk '/^  tegu:$/ { skip = 1; next } skip == 1 { skip = 0; next } { print }' "$F" > "$F.new" && mv "$F.new" "$F"
  if mutated_ok ST-2 "$base/inj2.pre" "$F" "tegu withholding reason removed"; then
    run_case inject-withheld-reason-removed "$sb" 1 'FAIL: \[C0[89]\] ' \
      "clause 2 rejects an unexplained withheld device"
  fi

  # ST-3 — CLAUSE 3: rango silently promoted to supported.
  sb="$base/inj3"; build_sandbox "$sb"
  F="$(sandbox_ts "$sb")"; cp "$F" "$base/inj3.pre"
  sed -i 's/status: "experimental",/status: "supported",/' "$F"
  if mutated_ok ST-3 "$base/inj3.pre" "$F" "rango status flipped experimental -> supported"; then
    run_case inject-rango-promoted "$sb" 1 'FAIL: \[C1[34]\] ' \
      "clause 3 rejects a silent promotion of rango"
  fi

  # ST-4 — CLAUSE 5: a SECOND export of assertOfferedImpliesComplete (the exact
  # shape the concurrent dispatcher injected on 2026-10-29).
  sb="$base/inj4"; build_sandbox "$sb"
  F="$(sandbox_ts "$sb")"; cp "$F" "$base/inj4.pre"
  cat >> "$F" <<'EOF'

export function assertOfferedImpliesComplete(offeredIds: readonly string[] = []): void {
  void offeredIds;
}
EOF
  if mutated_ok ST-4 "$base/inj4.pre" "$F" "assertOfferedImpliesComplete exported a second time"; then
    run_case inject-duplicate-assert-export "$sb" 1 'FAIL: \[C19b?\] ' \
      "clause 5 rejects a duplicate export"
  fi

  # ST-5 — CLAUSE 4: the status.json honesty invented away ("NOT IN status.json"
  # replaced by a marketing word) while both exports still exist.
  sb="$base/inj5"; build_sandbox "$sb"
  F="$(sandbox_ts "$sb")"; cp "$F" "$base/inj5.pre"
  sed -i 's/return "NOT IN status\.json";/return "EXPERIMENTAL";/' "$F"
  if mutated_ok ST-5 "$base/inj5.pre" "$F" "absent status.json fact relabelled as EXPERIMENTAL"; then
    run_case inject-status-json-honesty-removed "$sb" 1 'FAIL: \[C17\] ' \
      "clause 4 keeps the komodo 'NOT IN status.json' fact"
  fi

  # ST-6 — CLAUSE 4: the two chip words MERGED (statusJsonChipWord de-exported,
  # i.e. only one public chip-word fact remains).
  sb="$base/inj6"; build_sandbox "$sb"
  F="$(sandbox_ts "$sb")"; cp "$F" "$base/inj6.pre"
  sed -i 's/^export function statusJsonChipWord(/function statusJsonChipWord(/' "$F"
  if mutated_ok ST-6 "$base/inj6.pre" "$F" "statusJsonChipWord merged away (no longer exported)"; then
    run_case inject-chip-words-merged "$sb" 1 'FAIL: \[C1[56]b?\] ' \
      "clause 4 rejects conflating the two chip-word exports"
  fi

  # ST-PC — POSITIVE CONTROL: an UNMUTATED sandbox must PASS. Without this, an
  # always-red gate would satisfy every injection above and prove nothing.
  sb="$base/injpc"; build_sandbox "$sb"
  if [[ -f "$(sandbox_ts "$sb")" ]]; then
    pass "[ST-PC] mutation applied: none (clean sandbox copy)"
    run_case positive-control-clean-sandbox "$sb" 0 'PASS: \[C05\] offered set == ' \
      "clean sandbox PASSES (gate is not merely always-red)"
  else
    fail "[ST-PC] could not build the clean sandbox"
  fi

  echo ""
  echo "SELFTEST: $st_pass/${#ST_NAMES[@]} injections behaved as designed (6 mutations + 1 positive control expected)"
  if [[ "$st_fail" -ne 0 || "${#ST_NAMES[@]}" -lt 7 ]]; then
    fail "[ST] self-test incomplete or mis-behaving (ran ${#ST_NAMES[@]} of 7 cases)"
  fi
  rm -rf "$base"
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  echo ""
  echo "=== Q-DEVICE-ALIGN-ADVERTISE self-test summary ==="
  echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
  echo "CHECKIN_RESULT: SELFTEST"
  echo "NOTE: the TypeScript/npm half remains UNVERIFIED ON THIS HOST (node/npm absent)."
  if [[ "$FAIL" -ne 0 ]]; then echo "SELF-TEST FAILED"; exit 1; fi
  echo "SELF-TEST PASSED"
  exit 0
fi

echo ""
echo "=== Q-DEVICE-ALIGN-ADVERTISE static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
echo "CHECKIN_RESULT: STATIC target=$TS clauses=21 offered=$OFFERED_N withheld=$WITHHELD_N reasons=$REASON_N fleet=$FLEET_N ts_half=UNVERIFIED_THIS_HOST"
echo "NOTE: source-text assertions only — no npm, tsc, test runner, build or boot was executed."
echo "NOTE: run with --self-test to prove these clauses are non-vacuous by injection."
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
