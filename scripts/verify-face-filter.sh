#!/usr/bin/env bash
# GuardTalkOS face persona acceptance (host-side, DEC-GT-004)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT="${OUT_DIR:-$ROOT/out/target/product/tokay}"
FAILURES=0

fail() { echo "FAIL: $*"; FAILURES=$((FAILURES + 1)); }
pass() { echo "PASS: $*"; }

require_path() {
    if [[ ! -e "$1" ]]; then fail "missing $1"; return 1; fi
    pass "found $1"
}

require_grep() {
    if ! grep -q "$2" "$1" 2>/dev/null; then
        fail "$1 does not contain: $2"
        return 1
    fi
    pass "$1 contains $2"
}

require_missing() {
    if [[ -e "$1" ]]; then fail "unexpected $1 (should be replaced)"; return 1; fi
    pass "absent $1"
}

echo "=== GuardTalk face filter verification ==="
echo "OUT=$OUT"

require_path "$OUT/vendor/lib64/libguardtalkface_jni.so"
require_path "$OUT/vendor/framework/androidx.camera.extensions.impl.guardtalk.jar"
require_path "$OUT/vendor/etc/permissions/guardtalk_camera_extensions.xml"
require_path "$OUT/system/priv-app/GuardTalkFace/GuardTalkFace.apk"

require_grep "$OUT/vendor/etc/permissions/guardtalk_camera_extensions.xml" "androidx.camera.extensions.impl.guardtalk.jar"
require_grep "$OUT/vendor/etc/permissions/guardtalk_camera_extensions.xml" "androidx.camera.extensions.impl"

if [[ -f "$OUT/vendor/build.prop" ]]; then
    require_grep "$OUT/vendor/build.prop" "ro.guardtalk.face.filter=1"
    require_grep "$OUT/vendor/build.prop" "persist.vendor.guardtalk.face.enabled=0"
else
    fail "missing $OUT/vendor/build.prop"
fi

if [[ -f "$OUT/vendor/etc/permissions/advancedSample_camera_extensions.xml" ]]; then
    fail "advancedSample_camera_extensions.xml still installed"
else
    pass "advanced sample permissions removed"
fi

TEST_BIN="$ROOT/out/host/linux-x86/nativetest64/guardtalk_face_pipeline_test/guardtalk_face_pipeline_test"
if [[ -x "$TEST_BIN" ]]; then
    "$TEST_BIN" && pass "host unit test" || fail "host unit test"
else
    echo "SKIP: host unit test binary not built"
fi

echo "=== Summary: $FAILURES failure(s) ==="
exit "$FAILURES"
