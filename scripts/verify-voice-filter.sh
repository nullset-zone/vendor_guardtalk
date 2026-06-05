#!/usr/bin/env bash
# GuardTalkOS mic voice filter acceptance (host-side, DEC-GT-003)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT="${OUT_DIR:-$ROOT/out/target/product/tokay}"
FAILURES=0

fail() {
    echo "FAIL: $*"
    FAILURES=$((FAILURES + 1))
}

pass() {
    echo "PASS: $*"
}

require_path() {
    if [[ ! -e "$1" ]]; then
        fail "missing $1"
        return 1
    fi
    pass "found $1"
    return 0
}

require_grep() {
    if ! grep -q "$2" "$1" 2>/dev/null; then
        fail "$1 does not contain pattern: $2"
        return 1
    fi
    pass "$1 contains $2"
    return 0
}

echo "=== GuardTalk voice filter verification ==="
echo "OUT=$OUT"

require_path "$OUT/vendor/lib64/soundfx/libguardtalkvoicesw.so"
require_path "$OUT/vendor/etc/audio_effects_config.xml"
require_path "$OUT/system/priv-app/GuardTalkVoice/GuardTalkVoice.apk" || \
    require_path "$OUT/product/priv-app/GuardTalkVoice/GuardTalkVoice.apk" || \
    require_path "$OUT/system_ext/priv-app/GuardTalkVoice/GuardTalkVoice.apk"

require_grep "$OUT/vendor/etc/audio_effects_config.xml" "guardtalk_voice_filter"
require_grep "$OUT/vendor/etc/audio_effects_config.xml" "libguardtalkvoicesw.so"

if [[ -f "$OUT/vendor/build.prop" ]]; then
    require_grep "$OUT/vendor/build.prop" "ro.guardtalk.voice.filter=1"
    require_grep "$OUT/vendor/build.prop" "persist.vendor.guardtalk.voice.enabled=1"
else
    fail "missing $OUT/vendor/build.prop"
fi

if command -v "$ROOT/out/host/linux-x86/nativetest64/guardtalk_voice_pitch_shifter_test/guardtalk_voice_pitch_shifter_test" \
    >/dev/null 2>&1; then
    "$ROOT/out/host/linux-x86/nativetest64/guardtalk_voice_pitch_shifter_test/guardtalk_voice_pitch_shifter_test" \
        && pass "host unit test" || fail "host unit test"
else
    echo "SKIP: host unit test binary not built yet"
fi

echo "=== Summary: $FAILURES failure(s) ==="
exit "$FAILURES"
