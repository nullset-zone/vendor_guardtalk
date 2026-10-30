#!/usr/bin/env bash
# Static verification for Q-DEVICE-ALIGN-VOICE-BRIDGE (P0, QA Panel 4).
#
# Tests the bridge that T-DEVICE-ALIGN-VOICE-BRIDGE added at
#   vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk
# which wires the per-device mic-DSP voice filter overlay
#   vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-audio.mk
# and the face-persona camera extension
#   vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-camera.mk
# into the one late pass every GuardTalkOS product actually runs.
#
# Decisions this gate enforces:
#   DEC-DEVICE-ALIGN-009 — before the bridge, NO phone product reached
#     device/*/guardtalk-audio.mk. Only a never-inherited file
#     (device/tokay/guardtalk-tokay.mk) and the emulator referenced it.
#   DEC-DEVICE-ALIGN-011 — GUARDTALK_FACE_FILTER is deliberately EMPTY on all
#     declaring devices, so camera "included but inert" is CORRECT. This gate
#     therefore never asserts the face filter is ON (that would assert a
#     defect); it asserts reachability only, and emits a HOLD if a camera
#     include ever starts producing a PRODUCT_* delta.
#   DEC-DEVICE-ALIGN-007 — zero-match "passes" are a wave-level defect class.
#     Every grep/loop here asserts a NON-ZERO match count and fails loudly
#     otherwise. Non-vacuity is proven by injection: `--self-test`.
#
# Cases:
#   C01-C12  bridge exists, is parameterised on $(PRODUCT_DEVICE), carries a
#            $(wildcard) guard, includes exactly once, and carries no
#            hardcoded codename path (that was the pre-bridge bug shape)
#   C13-C14  the two stanzas are the exact 5-line assign/guard/include/endif/
#            clear shape, in order
#   C15-C18  reachability == overlay presence for EVERY device on disk,
#            driven by enumeration (no hardcoded device list)
#   C19-C21  NO OVER-GRANT: no device reaches or gains the voice filter
#            without holding the overlay (the direction that matters most)
#   C22-C23  the bridge variable is cleared, so it cannot leak into a sibling
#            makefile scope
#   C24-C27  the known-open set (voice=true, no overlay) is printed as HOLD.
#            Its cardinality is pinned at 0. The nine members that
#            DEC-DEVICE-ALIGN-011 tracked were a REAL DEFECT (voice flag set,
#            no guardtalk-audio.mk), and T-DEVICE-ALIGN-VOICE-FLAG-TRUTH
#            (APPROVED) narrowed them to empty. So 9 -> 0 is a FIX, not a
#            regression: cross-tab is now 0 voice=true/audio=- rows, with the
#            four remaining declarers all holding the overlay. The pin still
#            fails on any re-widening or broken parse, and an empty set is
#            only accepted when the C21/C24 denominators are > 0 — otherwise
#            "0 open" would be indistinguishable from "0 parsed".
#   C28      camera reachable-but-inert posture (DEC-DEVICE-ALIGN-011)
#
# Method: the two stanzas are EXTRACTED VERBATIM from the shipped bridge (not
# paraphrased) and replayed through GNU make with the device's real
# guardtalk-flags.mk pre-loaded, in the same order the live late pass uses.
# Reachability is read back from MAKEFILE_LIST. This is an INCLUDE-GRAPH proof:
# it is not an Android build and says nothing about a built or booted image.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_device_voice_bridge_static.sh
#   bash vendor/guardtalk/docs/qa/verify_device_voice_bridge_static.sh --self-test
#
# rc: 0 = all clauses PASS (HOLD lines do not fail the gate)
#     1 = at least one clause FAILED
#     --self-test: 0 = every injected mutation was detected as designed
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

# --- non-vacuity helpers (DEC-DEVICE-ALIGN-007) -----------------------------
# count_of prints an integer ALWAYS; a zero-match rg (rc=1, empty stdout) must
# not be distinguishable from "the pattern is wrong" by the caller, so every
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
forbid_count() { # <tag> <file> <regex> <expected-zero> <label>
  local tag="$1" file="$2" re="$3" want="$4" label="$5" n
  if [[ ! -f "$file" ]]; then fail "[$tag] $label (file missing: $file)"; return; fi
  n="$(count_of "$file" "$re")"
  if [[ "$n" == "$want" ]]; then
    pass "[$tag] $label (count=$n)"
  else
    fail "[$tag] $label (count=$n, expected $want; pattern '$re')"
  fi
}

BRIDGE="vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
DEVICE_ROOT="vendor/guardtalk/device"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Operative text only: comments mentioning "device/<codename>/guardtalk-audio.mk"
# must not be able to satisfy or violate a structural clause. Make semantics are
# unchanged by stripping trailing comments.
BRIDGE_NC="$TMP/bridge.nocomment.mk"
if [[ -f "$BRIDGE" ]]; then sed 's/#.*$//' "$BRIDGE" > "$BRIDGE_NC"; else : > "$BRIDGE_NC"; fi

# stanza_bounds <file> <var> <overlay> -> "start end" (0 0 when not found)
stanza_bounds() {
  local file="$1" var="$2" ov="$3" start end
  start="$(rg -n --fixed-strings "${var} := vendor/guardtalk/device/\$(PRODUCT_DEVICE)/${ov}.mk" "$file" 2>/dev/null | head -1 | cut -d: -f1)" || true
  if [[ -z "${start:-}" ]]; then printf '0 0\n'; return; fi
  end="$(awk -v s="$start" -v v="$var" 'NR>s && $0 ~ ("^[[:space:]]*" v "[[:space:]]*:=[[:space:]]*$") {print NR; exit}' "$file")" || true
  printf '%s %s\n' "$start" "${end:-0}"
}
extract_stanza() { # <file> <var> <overlay> <out>
  local file="$1" var="$2" ov="$3" out="$4" b s e
  b="$(stanza_bounds "$file" "$var" "$ov")"
  s="${b%% *}"; e="${b##* }"
  if [[ "$s" == "0" || "$e" == "0" || "$e" -le "$s" ]]; then : > "$out"; return; fi
  sed -n "${s},${e}p" "$file" > "$out"
}

echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE case1: bridge shape (parameterised + wildcard) ==="
echo "BRIDGE=$BRIDGE"
echo "DEVICE_ROOT=$DEVICE_ROOT"

# C01 — the bridge itself. A missing bridge must FAIL, not read as "no delta".
if [[ -f "$BRIDGE" && -s "$BRIDGE" ]]; then
  pass "[C01] bridge present and non-empty ($(wc -l < "$BRIDGE" | tr -d ' ') lines)"
else
  fail "[C01] bridge missing or empty: $BRIDGE"
fi
# C02 — the operative view must be non-empty, else every clause below is vacuous.
if [[ -s "$BRIDGE_NC" ]]; then
  pass "[C02] operative text (comments stripped) non-empty ($(wc -l < "$BRIDGE_NC" | tr -d ' ') lines)"
else
  fail "[C02] operative text is EMPTY — structural clauses would be vacuous"
fi

GT_DEV='\$\(PRODUCT_DEVICE\)'
# C03/C04 — exactly one parameterised assignment per overlay. Count>1 would be a
# duplicate include; count=0 is either "bridge gone" or "hardcoded path is back".
require_count C03 "$BRIDGE_NC" "^[[:space:]]*_gt_audio_mk[[:space:]]*:=[[:space:]]*vendor/guardtalk/device/${GT_DEV}/guardtalk-audio\.mk[[:space:]]*\$" 1 \
  "audio overlay resolved from \$(PRODUCT_DEVICE)"
require_count C04 "$BRIDGE_NC" "^[[:space:]]*_gt_camera_mk[[:space:]]*:=[[:space:]]*vendor/guardtalk/device/${GT_DEV}/guardtalk-camera\.mk[[:space:]]*\$" 1 \
  "camera overlay resolved from \$(PRODUCT_DEVICE)"
# C05/C06 — the wildcard guard is what makes a device WITHOUT the file a no-op.
require_count C05 "$BRIDGE_NC" 'ifneq[[:space:]]*\(\$\(wildcard[[:space:]]*\$\(_gt_audio_mk\)\)' 1 \
  "audio include guarded by \$(wildcard \$(_gt_audio_mk))"
require_count C06 "$BRIDGE_NC" 'ifneq[[:space:]]*\(\$\(wildcard[[:space:]]*\$\(_gt_camera_mk\)\)' 1 \
  "camera include guarded by \$(wildcard \$(_gt_camera_mk))"
# C07/C08 — the include consumes the parameterised variable, not a literal path.
# NOTE: end-of-line anchors below are BARE `$`. A `\$` in a single-quoted pattern
# is a LITERAL dollar to ripgrep (not an anchor) — that exact slip made C07-C10
# fail on the first run of this gate, which is the defect class it guards.
require_count C07 "$BRIDGE_NC" '^[[:space:]]*include[[:space:]]*\$\(_gt_audio_mk\)[[:space:]]*$' 1 \
  "audio include consumes \$(_gt_audio_mk)"
require_count C08 "$BRIDGE_NC" '^[[:space:]]*include[[:space:]]*\$\(_gt_camera_mk\)[[:space:]]*$' 1 \
  "camera include consumes \$(_gt_camera_mk)"
# C09/C10 — the clears. Their empirical effect is asserted again at C22/C23.
require_count C09 "$BRIDGE_NC" '^[[:space:]]*_gt_audio_mk[[:space:]]*:=[[:space:]]*$' 1 \
  "_gt_audio_mk cleared after use"
require_count C10 "$BRIDGE_NC" '^[[:space:]]*_gt_camera_mk[[:space:]]*:=[[:space:]]*$' 1 \
  "_gt_camera_mk cleared after use"
# C11/C12 — NEGATIVE: a literal codename in an overlay path is the old bug.
# These are negative checks; their non-vacuity is anchored by the companion
# POSITIVE counts at C03/C04 (same file, same overlay, expected 1).
forbid_count C11 "$BRIDGE_NC" 'vendor/guardtalk/device/[A-Za-z0-9_]+/guardtalk-audio\.mk' 0 \
  "no hardcoded codename in the audio overlay path"
forbid_count C12 "$BRIDGE_NC" 'vendor/guardtalk/device/[A-Za-z0-9_]+/guardtalk-camera\.mk' 0 \
  "no hardcoded codename in the camera overlay path"

# C13/C14 — the exact ordered 5-line shape. This is stronger than "the strings
# exist": a guard that is present but wraps the wrong statement still fails.
shape_check() { # <tag> <var> <overlay> <stanza-file> <label>
  local tag="$1" var="$2" ov="$3" f="$4" label="$5"
  local -a L=()
  local re1 re2 re3 re4 re5
  if [[ ! -s "$f" ]]; then fail "[$tag] $label (stanza not extractable)"; return; fi
  mapfile -t L < "$f"
  if [[ "${#L[@]}" -ne 5 ]]; then
    fail "[$tag] $label (stanza is ${#L[@]} lines, expected 5 assign/guard/include/endif/clear)"
    return
  fi
  re1="^[[:space:]]*${var}[[:space:]]*:=[[:space:]]*vendor/guardtalk/device/\\\$\(PRODUCT_DEVICE\)/${ov}\.mk[[:space:]]*\$"
  re2="^[[:space:]]*ifneq[[:space:]]*\(\\\$\(wildcard[[:space:]]*\\\$\(${var}\)\)[[:space:]]*,[[:space:]]*\)[[:space:]]*\$"
  re3="^[[:space:]]*include[[:space:]]*\\\$\(${var}\)[[:space:]]*\$"
  re4="^[[:space:]]*endif[[:space:]]*\$"
  re5="^[[:space:]]*${var}[[:space:]]*:=[[:space:]]*\$"
  if [[ "${L[0]}" =~ $re1 && "${L[1]}" =~ $re2 && "${L[2]}" =~ $re3 && "${L[3]}" =~ $re4 && "${L[4]}" =~ $re5 ]]; then
    pass "[$tag] $label: assign -> ifneq(wildcard) -> include -> endif -> clear"
  else
    fail "[$tag] $label: ordered shape violated"
    local i
    for i in 0 1 2 3 4; do echo "      line$((i + 1)): ${L[$i]}"; done
  fi
}

STANZA_A="$TMP/stanza-audio.mk"
STANZA_C="$TMP/stanza-camera.mk"
extract_stanza "$BRIDGE_NC" _gt_audio_mk guardtalk-audio "$STANZA_A"
extract_stanza "$BRIDGE_NC" _gt_camera_mk guardtalk-camera "$STANZA_C"
shape_check C13 _gt_audio_mk guardtalk-audio "$STANZA_A" "audio stanza shape"
shape_check C14 _gt_camera_mk guardtalk-camera "$STANZA_C" "camera stanza shape"

echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE case1b: bridge is in the LIVE product chain ==="
# A structurally perfect bridge that NOTHING includes is the DEC-DEVICE-ALIGN-009
# defect one level up, and every clause below would then be a false green. So
# assert the chain that actually reaches this file on a real build.
PC_LATE="vendor/guardtalk/radio-excised/product-config-late.mk"
PC_CORE="build/make/core/product_config.mk"
PC_LATE_NC="$TMP/pc-late.nocomment.mk"
PC_CORE_NC="$TMP/pc-core.nocomment.mk"
if [[ -f "$PC_LATE" ]]; then sed 's/#.*$//' "$PC_LATE" > "$PC_LATE_NC"; else : > "$PC_LATE_NC"; fi
if [[ -f "$PC_CORE" ]]; then sed 's/#.*$//' "$PC_CORE" > "$PC_CORE_NC"; else : > "$PC_CORE_NC"; fi
require_count C29 "$PC_LATE_NC" '^[[:space:]]*include[[:space:]]*vendor/guardtalk/feature-excised/guardtalk-feature-excised\.mk[[:space:]]*$' 1 \
  "product-config-late.mk includes the bridge"
require_count C30 "$PC_CORE_NC" '^-include[[:space:]]*vendor/guardtalk/radio-excised/product-config-late\.mk[[:space:]]*$' 1 \
  "build/make/core/product_config.mk pulls product-config-late.mk in"
# C31 — the bridge include sits under the device-driven GUARDTALK_RADIO_EXCISED
# gate, so it cannot fire for a product that never opted in (order asserted).
gate_line="$(rg -n --fixed-strings 'ifneq ($(GUARDTALK_RADIO_EXCISED),)' "$PC_LATE_NC" 2>/dev/null | head -1 | cut -d: -f1)" || true
inc_line="$(rg -n --fixed-strings 'include vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk' "$PC_LATE_NC" 2>/dev/null | head -1 | cut -d: -f1)" || true
if [[ -n "${gate_line:-}" && -n "${inc_line:-}" && "$gate_line" -lt "$inc_line" ]]; then
  pass "[C31] bridge include is under the GUARDTALK_RADIO_EXCISED gate (gate line $gate_line < include line $inc_line)"
else
  fail "[C31] bridge include NOT under the GUARDTALK_RADIO_EXCISED gate (gate='${gate_line:-none}' include='${inc_line:-none}')"
fi

echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE case2: reachability == overlay presence (all devices) ==="

# C15 — enumerate the fleet FROM DISK. No device list is hardcoded anywhere.
DEVICES=()
if [[ -d "$DEVICE_ROOT" ]]; then
  while IFS= read -r d; do DEVICES+=("$d"); done \
    < <(find "$DEVICE_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
fi
N_DEV="${#DEVICES[@]}"
N_PRESENT=0
N_ABSENT=0
for d in ${DEVICES[@]+"${DEVICES[@]}"}; do
  if [[ -f "$DEVICE_ROOT/$d/guardtalk-audio.mk" ]]; then N_PRESENT=$((N_PRESENT + 1)); else N_ABSENT=$((N_ABSENT + 1)); fi
done
echo "device_dirs=$N_DEV audio_overlay_present=$N_PRESENT absent=$N_ABSENT"
# A floor of 5 is a vacuity floor (the measured fleet is 15 with 4 holders), NOT
# a pin on the fleet size: adding a device must not fail this gate.
if [[ "$N_DEV" -ge 5 && "$N_PRESENT" -ge 1 && "$N_ABSENT" -ge 1 ]]; then
  pass "[C15] device scan non-vacuous (scanned=$N_DEV present=$N_PRESENT absent=$N_ABSENT; both directions exercised)"
else
  fail "[C15] device scan not usable: scanned=$N_DEV present=$N_PRESENT absent=$N_ABSENT (need >=5 and both buckets non-empty)"
fi

# The replay harness: the device's REAL flags file is loaded first (mirroring
# guardtalk-radio-excised.mk:15), then the two stanzas verbatim INSIDE the same
# GUARDTALK_RADIO_EXCISED gate that product-config-late.mk wraps around the
# bridge. Modelling that outer gate matters: without it a device holding an
# overlay but never opting in would read as "reachable" while the live image
# would include nothing — a false PASS.
PROBE="$TMP/probe.mk"
cat > "$PROBE" <<'EOF'
PRODUCT_DEVICE := $(DEV)
PRODUCT_PACKAGES :=
PRODUCT_PACKAGES_REMOVE :=
PRODUCT_SOONG_NAMESPACES :=
PRODUCT_PROPERTY_OVERRIDES :=
-include vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-flags.mk
ifneq ($(GUARDTALK_RADIO_EXCISED),)
include $(GT_STANZA_A)
include $(GT_STANZA_C)
endif
$(info GT_AUDIO|$(filter %guardtalk-audio.mk,$(MAKEFILE_LIST)))
$(info GT_CAMERA|$(filter %guardtalk-camera.mk,$(MAKEFILE_LIST)))
$(info GT_CLEAR_A|$(_gt_audio_mk))
$(info GT_CLEAR_C|$(_gt_camera_mk))
$(info GT_VOICE|$(filter GuardTalkVoice,$(PRODUCT_PACKAGES)))
$(info GT_FACE|$(filter GuardTalkFace,$(PRODUCT_PACKAGES)))
all: ; @:
EOF
MARKERS='^GT_(AUDIO|CAMERA|CLEAR_A|CLEAR_C|VOICE|FACE)\|'
marker() { printf '%s\n' "$1" | sed -n "s/^GT_$2|//p" | head -1; }

flag_value() { # <device> -> VOICE flag value (empty when unset/absent)
  local f="$DEVICE_ROOT/$1/guardtalk-flags.mk"
  [[ -f "$f" ]] || { printf '\n'; return; }
  sed -n 's/^[[:space:]]*GUARDTALK_VOICE_FILTER[[:space:]]*:=[[:space:]]*//p' "$f" | tail -1 | sed 's/[[:space:]]*$//'
}

REACH_OK=0
MISMATCH=0
OVERGRANT=0
WRONGPATH=0
LEAK_A=0
LEAK_C=0
GAIN_NO_OVERLAY=0
GAIN_NO_FLAG=0
GAIN_EXPECT_MISS=0
# EXPECT_POP = devices that hold the audio overlay AND declare the flag. This is
# the denominator that makes C21's "no misses" claim non-vacuous; it must be > 0.
EXPECT_POP=0
PROBED=0
FACE_GAIN=0
declare -a OPEN_SET=()
declare -a DECLARING=()

for d in ${DEVICES[@]+"${DEVICES[@]}"}; do
  out=""; rc=0
  out="$(make -s -f "$PROBE" DEV="$d" GT_STANZA_A="$STANZA_A" GT_STANZA_C="$STANZA_C" 2>&1)" || rc=$?
  # Loop non-vacuity: every device must yield all six markers, or the harness
  # (not the bridge) is broken and a "no include" reading would be a lie.
  nmark="$(printf '%s\n' "$out" | rg -c -- "$MARKERS" || true)"
  if [[ "$rc" -ne 0 || "${nmark:-0}" != "6" ]]; then
    fail "[C16] $d: replay harness produced ${nmark:-0}/6 markers (make rc=$rc) — result unusable"
    printf '%s\n' "$out" | tail -3
    MISMATCH=$((MISMATCH + 1))
    continue
  fi
  PROBED=$((PROBED + 1))

  a_reached="$(marker "$out" AUDIO)"
  c_reached="$(marker "$out" CAMERA)"
  a_clear="$(marker "$out" CLEAR_A)"
  c_clear="$(marker "$out" CLEAR_C)"
  voice_pkg="$(marker "$out" VOICE)"
  face_pkg="$(marker "$out" FACE)"
  vf="$(flag_value "$d")"

  present_a=0; [[ -f "$DEVICE_ROOT/$d/guardtalk-audio.mk" ]] && present_a=1
  present_c=0; [[ -f "$DEVICE_ROOT/$d/guardtalk-camera.mk" ]] && present_c=1
  [[ -n "$vf" ]] && DECLARING+=("$d")

  dev_ok=1
  # --- audio direction ---
  if [[ "$present_a" -eq 1 ]]; then
    if [[ "$a_reached" == "$DEVICE_ROOT/$d/guardtalk-audio.mk" ]]; then
      REACH_OK=$((REACH_OK + 1))
    elif [[ -z "$a_reached" ]]; then
      fail "[C16] $d: holds guardtalk-audio.mk but the bridge did NOT include it (UNREACHABLE)"
      MISMATCH=$((MISMATCH + 1)); dev_ok=0
    else
      fail "[C16] $d: reached '$a_reached' — NOT its own overlay (hardcoded-path leak)"
      WRONGPATH=$((WRONGPATH + 1)); MISMATCH=$((MISMATCH + 1)); dev_ok=0
    fi
  else
    if [[ -z "$a_reached" ]]; then
      REACH_OK=$((REACH_OK + 1))
    else
      fail "[C19] $d: OVER-GRANT — no guardtalk-audio.mk on disk yet bridge reached '$a_reached'"
      OVERGRANT=$((OVERGRANT + 1)); MISMATCH=$((MISMATCH + 1)); dev_ok=0
    fi
  fi
  # --- camera direction (reachability only; DEC-DEVICE-ALIGN-011) ---
  if [[ "$present_c" -eq 1 ]]; then
    if [[ "$c_reached" != "$DEVICE_ROOT/$d/guardtalk-camera.mk" ]]; then
      fail "[C16] $d: holds guardtalk-camera.mk but camera reach != its own overlay (got '$c_reached')"
      MISMATCH=$((MISMATCH + 1)); dev_ok=0
    fi
  else
    if [[ -n "$c_reached" ]]; then
      fail "[C19] $d: OVER-GRANT — no guardtalk-camera.mk on disk yet camera reached '$c_reached'"
      OVERGRANT=$((OVERGRANT + 1)); MISMATCH=$((MISMATCH + 1)); dev_ok=0
    fi
  fi
  # --- C22/C23: the bridge variable must not survive the stanza ---
  if [[ -n "$a_clear" ]]; then
    fail "[C22] $d: _gt_audio_mk leaked out of the stanza as '$a_clear'"
    LEAK_A=$((LEAK_A + 1)); dev_ok=0
  fi
  if [[ -n "$c_clear" ]]; then
    fail "[C23] $d: _gt_camera_mk leaked out of the stanza as '$c_clear'"
    LEAK_C=$((LEAK_C + 1)); dev_ok=0
  fi
  # --- C20/C21: effect level. The overlay self-gates on the flag, so
  #     gained == present && flag-non-empty is the documented fleet contract.
  gained=0; [[ -n "$voice_pkg" ]] && gained=1
  if [[ "$gained" -eq 1 && "$present_a" -eq 0 ]]; then
    fail "[C20] $d: GAINED GuardTalkVoice without holding guardtalk-audio.mk (effect-level over-grant)"
    GAIN_NO_OVERLAY=$((GAIN_NO_OVERLAY + 1)); dev_ok=0
  fi
  if [[ "$gained" -eq 1 && -z "$vf" ]]; then
    fail "[C20] $d: GAINED GuardTalkVoice while GUARDTALK_VOICE_FILTER is unset (over-grant vs declaration)"
    GAIN_NO_FLAG=$((GAIN_NO_FLAG + 1)); dev_ok=0
  fi
  if [[ "$present_a" -eq 1 && -n "$vf" ]]; then
    EXPECT_POP=$((EXPECT_POP + 1))
    if [[ "$gained" -eq 0 ]]; then
      fail "[C21] $d: holds overlay + declares filter but gained NO GuardTalkVoice package (inert bridge)"
      GAIN_EXPECT_MISS=$((GAIN_EXPECT_MISS + 1)); dev_ok=0
    fi
  fi
  if [[ -n "$face_pkg" ]]; then
    hold "[C28] $d: camera include produced GuardTalkFace — face filter is no longer inert; re-read DEC-DEVICE-ALIGN-011"
    FACE_GAIN=$((FACE_GAIN + 1))
  fi
  # --- open set (printed, not failed) ---
  if [[ -n "$vf" && "$present_a" -eq 0 ]]; then
    OPEN_SET+=("$d")
    hold "[C25] $d declares GUARDTALK_VOICE_FILTER=$vf but holds no guardtalk-audio.mk (pending OPERATOR ruling, DEC-DEVICE-ALIGN-011)"
  fi
  if [[ "$dev_ok" -eq 1 ]]; then
    pass "[C16] $d: audio=$( [[ $present_a -eq 1 ]] && echo Y || echo - ) reached=$( [[ $a_reached == *"$d/guardtalk-audio.mk" ]] && echo Y || echo - ) camera_reached=$( [[ $c_reached == *"$d/guardtalk-camera.mk" ]] && echo Y || echo - ) voice=$([[ -n $voice_pkg ]] && echo Y || echo -) flag=${vf:-UNSET}"
  fi
done

# C17 — aggregate: reachability must equal presence with no residue.
if [[ "$MISMATCH" -eq 0 && "$REACH_OK" -eq "$N_DEV" ]]; then
  pass "[C17] reachability == overlay presence for all $N_DEV devices (audio+camera, mismatch=0)"
else
  fail "[C17] reachability != overlay presence (mismatch=$MISMATCH, matched=$REACH_OK/$N_DEV, wrong_path=$WRONGPATH, over_grant=$OVERGRANT)"
fi
# C18 — the loop really ran every device (a `continue` or empty array would
# otherwise let C17 pass on a smaller sample).
if [[ "$PROBED" -eq "$N_DEV" && "$N_DEV" -gt 0 ]]; then
  pass "[C18] replay harness probed every scanned device ($PROBED/$N_DEV)"
else
  fail "[C18] replay harness probed $PROBED/$N_DEV devices — the per-device loop is not covering the fleet"
fi

echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE case3: no over-grant ==="
# C19 — include-level over-grant (reached without presence) is counted in the
# loop; assert it is exactly zero here so the report carries the number.
if [[ "$OVERGRANT" -eq 0 ]]; then
  pass "[C19] include-level over-grant: 0/$N_DEV devices reach an overlay they do not hold"
else
  fail "[C19] include-level over-grant: $OVERGRANT device(s) reach an overlay they do not hold"
fi
# C20 — effect-level over-grant (gains the product without the file, or without
# the declaration).
if [[ "$GAIN_NO_OVERLAY" -eq 0 && "$GAIN_NO_FLAG" -eq 0 ]]; then
  pass "[C20] effect-level over-grant: 0 devices gain GuardTalkVoice without overlay+declaration"
else
  fail "[C20] effect-level over-grant: no_overlay=$GAIN_NO_OVERLAY no_declaration=$GAIN_NO_FLAG"
fi
# C21 — positive direction of the same assertion: every device that holds the
# overlay AND declares the filter must actually gain the product. The population
# itself is asserted > 0, so "no misses" cannot pass on an empty denominator.
if [[ "$EXPECT_POP" -lt 1 ]]; then
  fail "[C21] overlay-holding declaring population is EMPTY (population=$EXPECT_POP) — the positive direction would be vacuous (need > 0)"
elif [[ "$GAIN_EXPECT_MISS" -ne 0 ]]; then
  fail "[C21] $GAIN_EXPECT_MISS of $EXPECT_POP overlay-holding declaring device(s) gained nothing (inert include)"
else
  pass "[C21] all $EXPECT_POP overlay-holding declaring device(s) gain GuardTalkVoice (misses=0, population>0)"
fi

echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE case4: bridge variable cleared (no scope leak) ==="
if [[ "$LEAK_A" -eq 0 && "$PROBED" -eq "$N_DEV" && "$N_DEV" -gt 0 ]]; then
  pass "[C22] _gt_audio_mk empty after every include (0/$PROBED leaks)"
else
  fail "[C22] _gt_audio_mk survived the stanza on $LEAK_A device(s) (probed=$PROBED/$N_DEV)"
fi
if [[ "$LEAK_C" -eq 0 && "$PROBED" -eq "$N_DEV" && "$N_DEV" -gt 0 ]]; then
  pass "[C23] _gt_camera_mk empty after every include (0/$PROBED leaks)"
else
  fail "[C23] _gt_camera_mk survived the stanza on $LEAK_C device(s) (probed=$PROBED/$N_DEV)"
fi

echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE case5: known-open set printed, cardinality pinned at 0 (9 -> 0 by T-DEVICE-ALIGN-VOICE-FLAG-TRUTH) ==="
# C24 — the flag parse must actually read declarations, else the open set is
# computed from an empty set and would "pass" at 0.
if [[ "${#DECLARING[@]}" -ge 1 ]]; then
  pass "[C24] GUARDTALK_VOICE_FILTER parse non-vacuous (${#DECLARING[@]} declaring device(s): $(printf '%s ' ${DECLARING[@]+"${DECLARING[@]}"} | sed 's/ $//'))"
else
  fail "[C24] no device parses as declaring GUARDTALK_VOICE_FILTER — the parse is broken, not the fleet"
fi
# C25 — non-vacuity of the open-set computation. The set is LEGITIMATELY EMPTY on
# the post-fix fleet (9 -> 0, see the C26 pin), so emptiness alone is no longer a
# failure. What must never pass is an empty set computed from EMPTY DENOMINATORS:
# then "0 open" is indistinguishable from "0 parsed" (DEC-DEVICE-ALIGN-012).
# Declaring devices (C24) and overlay holders (C15) are the two real denominators.
if [[ "${#DECLARING[@]}" -ge 1 && "$N_PRESENT" -ge 1 ]]; then
  pass "[C25] open-set computation non-vacuous (declaring=${#DECLARING[@]}, overlay_holders=$N_PRESENT; open=${#OPEN_SET[@]})"
else
  fail "[C25] open-set computation VACUOUS — declaring=${#DECLARING[@]} overlay_holders=$N_PRESENT, both must be > 0 before open=${#OPEN_SET[@]} can be read"
fi
# C26 — THE PIN. 9 -> 0 is a FIX, not a regression: T-DEVICE-ALIGN-VOICE-FLAG-TRUTH
# (APPROVED) narrowed the nine defect devices to empty, so the cross-tab is now
# 0 voice=true/audio=- rows; the four remaining declarers all hold the overlay.
# The pin records that new steady state under DEC-DEVICE-ALIGN-011 so a future
# re-widening still fails, and so does a broken parse (C24/C25/C21 gate the noise).
OPEN_EXPECTED=0
if [[ "${#OPEN_SET[@]}" -eq "$OPEN_EXPECTED" ]]; then
  pass "[C26] open-set cardinality == $OPEN_EXPECTED (pinned: 9 -> 0 by T-DEVICE-ALIGN-VOICE-FLAG-TRUTH; a size change fails so a regression cannot hide)"
else
  fail "[C26] open-set cardinality CHANGED: expected $OPEN_EXPECTED, got ${#OPEN_SET[@]} ($(printf '%s ' ${OPEN_SET[@]+"${OPEN_SET[@]}"} | sed 's/ $//')) — re-issue the DEC-DEVICE-ALIGN-011 operator ruling"
fi
# C27 — self-consistency: every open-set member must really declare a non-empty
# flag. With an empty set this check has nothing to refute, so the empty branch is
# accepted ONLY when the same denominators C24/C25 proved are real — never as a
# silent default that would let a broken parse read as "clean".
OPEN_BAD=0
for d in ${OPEN_SET[@]+"${OPEN_SET[@]}"}; do
  [[ -n "$(flag_value "$d")" ]] || OPEN_BAD=$((OPEN_BAD + 1))
done
if [[ "$OPEN_BAD" -eq 0 && "${#OPEN_SET[@]}" -ge 1 ]]; then
  pass "[C27] every open-set member declares a non-empty flag (members=${#OPEN_SET[@]}, inconsistent=0)"
elif [[ "$OPEN_BAD" -eq 0 && "${#OPEN_SET[@]}" -eq 0 && "${#DECLARING[@]}" -ge 1 && "$N_PRESENT" -ge 1 ]]; then
  pass "[C27] open set empty (0 members) and denominators real (declaring=${#DECLARING[@]}, overlay_holders=$N_PRESENT) — consistency holds trivially, not vacuously"
else
  fail "[C27] inconsistent=$OPEN_BAD, or the denominators are empty (open=${#OPEN_SET[@]} declaring=${#DECLARING[@]} overlay_holders=$N_PRESENT)"
fi

echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE case6: face posture (DEC-DEVICE-ALIGN-011) ==="
# C28 — camera being reachable but inert is CORRECT because GUARDTALK_FACE_FILTER
# is deliberately empty fleet-wide. This clause NEVER asserts the face filter is
# on; it only reports a HOLD if a camera include ever starts having an effect.
if [[ "$FACE_GAIN" -eq 0 ]]; then
  pass "[C28] camera reachable-but-inert on every device (face filter deliberately OFF, DEC-DEVICE-ALIGN-011)"
else
  hold "[C28] $FACE_GAIN device(s) show a camera PRODUCT_* delta — face posture changed, re-read DEC-DEVICE-ALIGN-011"
fi

# --- self-test: non-vacuity proven by injection (DEC-DEVICE-ALIGN-007) -------
self_test() {
  local base sb name rc st_fail=0 st_pass=0
  local -a ST_NAMES=()
  base="$(mktemp -d)"
  # Sandbox = a copy of this script, a copy of the bridge, and copies of the
  # device overlays/flags. The gate is hermetic (it never includes the whole
  # bridge), so this is enough to replay the real clauses against a mutated world.
  build_sandbox() { # <dir>
    local dir="$1" d f
    mkdir -p "$dir/vendor/guardtalk/docs/qa" "$dir/vendor/guardtalk/feature-excised" \
      "$dir/vendor/guardtalk/radio-excised" "$dir/build/make/core"
    cp "$SELF_ABS" "$dir/vendor/guardtalk/docs/qa/$SELF_BASE"
    cp "$BRIDGE" "$dir/vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
    # The two files that prove the bridge is not orphaned (C29-C31) must be real
    # copies, so the only thing a mutation changes is the mutation itself.
    cp "$PC_LATE" "$dir/vendor/guardtalk/radio-excised/product-config-late.mk"
    cp "$PC_CORE" "$dir/build/make/core/product_config.mk"
    for d in ${DEVICES[@]+"${DEVICES[@]}"}; do
      mkdir -p "$dir/vendor/guardtalk/device/$d"
      for f in guardtalk-flags.mk guardtalk-audio.mk guardtalk-camera.mk; do
        [[ -f "$DEVICE_ROOT/$d/$f" ]] && cp "$DEVICE_ROOT/$d/$f" "$dir/vendor/guardtalk/device/$d/$f"
      done
    done
  }
  run_case() { # <name> <dir> <expected-rc> <expected-regex|""> <label>
    local nm="$1" dir="$2" want_rc="$3" want_re="$4" label="$5"
    local out r=0
    out="$(bash "$dir/vendor/guardtalk/docs/qa/$SELF_BASE" 2>&1)" || r=$?
    ST_NAMES+=("$nm")
    if [[ "$r" != "$want_rc" ]]; then
      fail "[ST] $nm: rc=$r expected $want_rc — $label"
      printf '%s\n' "$out" | tail -6
      st_fail=$((st_fail + 1)); return
    fi
    # Vacuity guard for the injection itself: the sandboxed gate must have run
    # to completion (summary present exactly once), not died before its clauses.
    local nsum
    nsum="$(printf '%s\n' "$out" | rg -c '^CHECKIN_RESULT:' || true)"
    if [[ "${nsum:-0}" != "1" ]]; then
      fail "[ST] $nm: sandboxed gate produced ${nsum:-0} summary line(s) — injection result unusable"
      st_fail=$((st_fail + 1)); return
    fi
    if [[ -n "$want_re" ]]; then
      if ! printf '%s\n' "$out" | rg -q -- "$want_re"; then
        fail "[ST] $nm: rc was $r as designed but the expected message /$want_re/ is absent — the gate may have failed for the wrong reason"
        st_fail=$((st_fail + 1)); return
      fi
    fi
    pass "[ST] $nm: rc=$r as designed — $label"
    # Record WHAT the injected gate actually said, so the log is its own
    # evidence and a future reader does not have to re-derive the failure.
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

  echo ""
  echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE --self-test: injections (expect FAIL where marked) ==="

  # ST-1: audio stanza deleted from the bridge -> the 4 overlay holders become
  # unreachable. This is the pre-bridge defect returning.
  sb="$base/inj1"; build_sandbox "$sb"
  BB="$sb/vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
  cp "$BB" "$base/inj1.pre"
  b="$(stanza_bounds "$BB" _gt_audio_mk guardtalk-audio)"; s="${b%% *}"; e="${b##* }"
  if [[ "$s" != "0" && "$e" != "0" ]]; then sed -i "${s},${e}d" "$BB"; fi
  if mutated_ok ST-1 "$base/inj1.pre" "$BB" "audio stanza deleted"; then
    run_case inject-bridge-audio-stanza-removed "$sb" 1 'FAIL: \[C16\] .*holds guardtalk-audio\.mk but the bridge did NOT include it' \
      "fake device world: overlay holders unreachable"
    rm -f "$base/inj1.pre"
  fi

  # ST-2: the old bug shape — a hardcoded codename instead of $(PRODUCT_DEVICE).
  sb="$base/inj2"; build_sandbox "$sb"
  BB="$sb/vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
  cp "$BB" "$base/inj2.pre"
  sed -i 's#_gt_audio_mk := vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-audio.mk#_gt_audio_mk := vendor/guardtalk/device/tokay/guardtalk-audio.mk#' "$BB"
  if mutated_ok ST-2 "$base/inj2.pre" "$BB" "audio path hardcoded to tokay"; then
    run_case inject-bridge-hardcoded-tokay "$sb" 1 'FAIL: \[C(03|11)\] ' \
      "hardcoded path regression detected"
    rm -f "$base/inj2.pre"
  fi

  # ST-3: the clear removed -> the variable leaks into the sibling scope.
  sb="$base/inj3"; build_sandbox "$sb"
  BB="$sb/vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
  cp "$BB" "$base/inj3.pre"
  b="$(stanza_bounds "$BB" _gt_audio_mk guardtalk-audio)"; e="${b##* }"
  if [[ "$e" != "0" ]]; then sed -i "${e}d" "$BB"; fi
  if mutated_ok ST-3 "$base/inj3.pre" "$BB" "audio clear removed"; then
    run_case inject-bridge-clear-removed "$sb" 1 'FAIL: \[C(09|22)\] ' \
      "scope leak detected"
    rm -f "$base/inj3.pre"
  fi

  # ST-4: POSITIVE CONTROL — a NEW device dir with a fake audio overlay AND a
  # real opt-in flags file must be auto-covered, proving this gate holds no
  # hardcoded device list.
  sb="$base/inj4"; build_sandbox "$sb"
  mkdir -p "$sb/vendor/guardtalk/device/zzz_synth"
  cp "$DEVICE_ROOT/tokay/guardtalk-audio.mk" "$sb/vendor/guardtalk/device/zzz_synth/guardtalk-audio.mk"
  cp "$DEVICE_ROOT/tokay/guardtalk-camera.mk" "$sb/vendor/guardtalk/device/zzz_synth/guardtalk-camera.mk"
  printf 'GUARDTALK_RADIO_EXCISED := true\nGUARDTALK_VOICE_FILTER := true\n' \
    > "$sb/vendor/guardtalk/device/zzz_synth/guardtalk-flags.mk"
  if [[ -f "$sb/vendor/guardtalk/device/zzz_synth/guardtalk-audio.mk" ]]; then
    pass "[ST-4] mutation applied: temp device dir zzz_synth with a fake audio overlay + opt-in flags"
    run_case inject-temp-device-with-audio-overlay "$sb" 0 'PASS: \[C16\] zzz_synth:' \
      "new device auto-covered from disk (positive control, gate stays green)"
  else
    fail "[ST-4] could not create the fake device overlay"
  fi

  # ST-8: NEGATIVE — the same fake device holding the overlay but NEVER opting
  # in. The live chain gates the whole late pass on GUARDTALK_RADIO_EXCISED, so
  # this overlay is dead on a real build; a gate that ignored the outer gate
  # would report a false PASS here. (This injection is why ST-4 needs flags.)
  sb="$base/inj8"; build_sandbox "$sb"
  mkdir -p "$sb/vendor/guardtalk/device/zzz_optout"
  cp "$DEVICE_ROOT/tokay/guardtalk-audio.mk" "$sb/vendor/guardtalk/device/zzz_optout/guardtalk-audio.mk"
  if [[ -f "$sb/vendor/guardtalk/device/zzz_optout/guardtalk-audio.mk" ]]; then
    pass "[ST-8] mutation applied: temp device dir zzz_optout with an overlay but NO opt-in flags"
    run_case inject-overlay-without-optin "$sb" 1 'FAIL: \[C16\] zzz_optout: holds guardtalk-audio\.mk but the bridge did NOT include it' \
      "overlay without GUARDTALK_RADIO_EXCISED opt-in is correctly dead"
  else
    fail "[ST-8] could not create the opt-out fake device overlay"
  fi

  # ST-5: the SAME fake device (audio overlay) but a bridge that does not route
  # it — the literal "temp device dir with a fake audio overlay" injection that
  # must FAIL. Proves the per-device clause is not a 4-name allowlist.
  sb="$base/inj5"; build_sandbox "$sb"
  mkdir -p "$sb/vendor/guardtalk/device/zzz_synth"
  cp "$DEVICE_ROOT/tokay/guardtalk-audio.mk" "$sb/vendor/guardtalk/device/zzz_synth/guardtalk-audio.mk"
  BB="$sb/vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk"
  cp "$BB" "$base/inj5.pre"
  b="$(stanza_bounds "$BB" _gt_audio_mk guardtalk-audio)"; s="${b%% *}"; e="${b##* }"
  if [[ "$s" != "0" && "$e" != "0" ]]; then sed -i "${s},${e}d" "$BB"; fi
  if mutated_ok ST-5 "$base/inj5.pre" "$BB" "audio stanza deleted, fake device present"; then
    run_case inject-fake-device-not-routed "$sb" 1 'FAIL: \[C16\] zzz_synth: holds guardtalk-audio\.mk but the bridge did NOT include it' \
      "fake device with overlay caught when the bridge misses it"
    rm -f "$base/inj5.pre"
  fi

  # ST-6: a fake device that declares the flag with no overlay widens the open
  # set from 0 to 1 -> the pinned cardinality must FAIL. This is the can-it-still-
  # fail proof for the re-pin (DEC-DEVICE-ALIGN-012): if the open-set logic were
  # deleted instead of re-pinned, this injection would pass and the gate would be
  # a false green.
  sb="$base/inj6"; build_sandbox "$sb"
  mkdir -p "$sb/vendor/guardtalk/device/zzz_flagonly"
  printf 'GUARDTALK_VOICE_FILTER := true\n' > "$sb/vendor/guardtalk/device/zzz_flagonly/guardtalk-flags.mk"
  if [[ -f "$sb/vendor/guardtalk/device/zzz_flagonly/guardtalk-flags.mk" ]]; then
    pass "[ST-6] mutation applied: temp flag-only device zzz_flagonly"
    run_case inject-open-set-widened "$sb" 1 'FAIL: \[C26\] open-set cardinality CHANGED: expected 0, got 1' \
      "operator-ruling set cannot be silently widened"
  else
    fail "[ST-6] could not create the flag-only fake device"
  fi

  # ST-7: the bridge is ORPHANED — the live chain stops including it. Without
  # this clause the whole gate could be a false green on a dead file.
  sb="$base/inj7"; build_sandbox "$sb"
  PL="$sb/vendor/guardtalk/radio-excised/product-config-late.mk"
  cp "$PL" "$base/inj7.pre"
  ln="$(rg -n --fixed-strings 'include vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk' "$PL" 2>/dev/null | head -1 | cut -d: -f1)" || true
  if [[ -n "${ln:-}" ]]; then sed -i "${ln}d" "$PL"; fi
  if mutated_ok ST-7 "$base/inj7.pre" "$PL" "bridge include removed from the live chain"; then
    run_case inject-bridge-orphaned "$sb" 1 'FAIL: \[C29\] ' \
      "orphaned bridge detected (would otherwise be a false green)"
    rm -f "$base/inj7.pre"
  fi

  echo ""
  echo "SELFTEST: $st_pass/$((${#ST_NAMES[@]})) injections behaved as designed"
  if [[ "$st_fail" -ne 0 || "${#ST_NAMES[@]}" -lt 8 ]]; then
    fail "[ST] self-test incomplete or mis-behaving (ran ${#ST_NAMES[@]} of 8 injections)"
  fi
  rm -rf "$base"
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  echo ""
  echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE self-test summary ==="
  echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
  echo "CHECKIN_RESULT: SELFTEST"
  if [[ "$FAIL" -ne 0 ]]; then echo "SELF-TEST FAILED"; exit 1; fi
  echo "SELF-TEST PASSED"
  exit 0
fi

echo ""
echo "=== Q-DEVICE-ALIGN-VOICE-BRIDGE static summary ==="
echo "PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=$FAIL"
echo "CHECKIN_RESULT: STATIC bridge=$BRIDGE devices=$N_DEV present=$N_PRESENT open_set=${#OPEN_SET[@]} over_grant=$OVERGRANT mismatches=$MISMATCH"
echo "NOTE: reachability is an INCLUDE-GRAPH claim only — no Android build was run (no image, no boot)."
echo "NOTE: run with --self-test to prove these clauses are non-vacuous by injection."
if [[ "$FAIL" -ne 0 ]]; then
  echo "ALL STATIC CHECKS FAILED"
  exit 1
fi
echo "ALL STATIC CHECKS PASSED"
exit 0
