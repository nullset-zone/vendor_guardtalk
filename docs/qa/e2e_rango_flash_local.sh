#!/usr/bin/env bash
# =============================================================================
# E2E local flash readiness rehearsal for rango (Pixel 10 Pro Fold)
#
# Simulates everything flash-from-remote.sh needs BEFORE a device is present:
#   - parse required downloads from the real flash script
#   - verify rango-latest + rescue-boot completeness
#   - local "download" (cp) into a temp work dir (same filenames client uses)
#   - SHA256SUMS check when present
#   - shipped vendor.img sepolicy graft MATCH (debugfs + cmp)
#   - MTE / memtag_heap strip presence
#   - dry-run of the rango flash order (no fastboot flash)
#
# Exit 0 = host-side flash READY (device flash still needs Fold + USB).
# Exit 1 = FAIL (fail-closed).
# Never claims on-device boot PASS.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
FLASH_SCRIPT="${FLASH_SCRIPT:-$ROOT/scripts/flash-from-remote.sh}"
BUNDLE="${BUNDLE:-$ROOT/releases/desktop-flash/rango-latest}"
RESCUE="${RESCUE:-$ROOT/releases/desktop-flash/rango-rescue-boot}"
FASTBOOT="${FASTBOOT:-fastboot}"
WORK="$(mktemp -d /tmp/rango-flash-e2e.XXXXXX)"
PASS=0
FAIL=0
WARN=0

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

log()  { printf '  ✓ %s\n' "$*"; PASS=$((PASS+1)); }
fail() { printf '  ✗ FAIL: %s\n' "$*" >&2; FAIL=$((FAIL+1)); }
warn() { printf '  ! WARN: %s\n' "$*"; WARN=$((WARN+1)); }
step() { printf '\n== %s ==\n' "$*"; }

die_hard() { fail "$*"; printf '\nRESULT: FAIL (%s fails)\n' "$FAIL"; exit 1; }

[[ -f "$FLASH_SCRIPT" ]] || die_hard "flash script missing: $FLASH_SCRIPT"
[[ -d "$BUNDLE" ]] || die_hard "bundle missing: $BUNDLE"
BUNDLE_REAL="$(readlink -f "$BUNDLE")"

step "0  Preconditions"
log "flash script: $FLASH_SCRIPT"
log "bundle: $BUNDLE → $BUNDLE_REAL"
bash -n "$FLASH_SCRIPT" && log "bash -n flash-from-remote.sh OK" || fail "bash -n flash-from-remote.sh"
if command -v "$FASTBOOT" >/dev/null 2>&1; then
  log "fastboot present: $($FASTBOOT --version 2>&1 | head -1)"
else
  fail "fastboot not in PATH (flash client would die at step 0)"
fi
command -v adb >/dev/null 2>&1 && log "adb present: $(adb version 2>&1 | head -1)" || warn "adb missing (insmod push after reboot would fail)"
command -v scp >/dev/null 2>&1 && log "scp present" || fail "scp missing"
command -v ssh >/dev/null 2>&1 && log "ssh present" || fail "ssh missing"

# ---------------------------------------------------------------------------
step "1  Required downloads from flash-from-remote.sh arrays"
# Keep in lockstep with scripts/flash-from-remote.sh array definitions.
FW_IMAGES=(bootloader.img radio.img)
AB_IMAGES=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img)
NOAB_IMAGES=(dtbo.img vbmeta.img vbmeta_system.img vbmeta_vendor.img)
LOGICAL_IMAGES=(system.img system_ext.img product.img vendor.img vendor_dlkm.img system_dlkm.img)
SUPER_IMAGE=(super.img)
EXTRA_FILES=(super_empty.img avb_pkmd.bin)
RANGO_EXTRA_FILES=(init.insmod.rango.cfg vendor_boot_diag.img)
RANGO_RESCUE_IMGS=(boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img dtbo.img vbmeta.img pvmfw.img)
REQUIRED=("${FW_IMAGES[@]}" "${AB_IMAGES[@]}" "${NOAB_IMAGES[@]}" "${LOGICAL_IMAGES[@]}" "${SUPER_IMAGE[@]}" "${EXTRA_FILES[@]}")
OPTIONAL=(super.img vendor_boot_diag.img)
# Drift guard: every required name must appear in the live flash script.
for f in "${REQUIRED[@]}" "${RANGO_EXTRA_FILES[@]}" "${RANGO_RESCUE_IMGS[@]}"; do
  grep -qF "$f" "$FLASH_SCRIPT" || fail "flash script no longer mentions $f (arrays drifted)"
done
log "flash-script name drift check OK"
is_optional() {
  local x="$1"
  for o in "${OPTIONAL[@]}"; do [[ "$x" == "$o" ]] && return 0; done
  return 1
}

MISSING=0
for f in "${REQUIRED[@]}"; do
  if [[ -f "$BUNDLE/$f" ]]; then
    sz=$(stat -c%s "$BUNDLE/$f")
    log "required $f (${sz} bytes)"
  elif is_optional "$f"; then
    warn "optional $f absent in bundle (script allows skip)"
  else
    fail "required missing: $BUNDLE/$f"
    MISSING=$((MISSING+1))
  fi
done
for f in "${RANGO_EXTRA_FILES[@]}"; do
  if [[ -f "$BUNDLE/$f" ]]; then
    log "rango extra $f present"
  elif is_optional "$f"; then
    warn "rango optional $f absent (vendor_boot_diag — script skip OK)"
  else
    fail "rango extra missing: $f"
  fi
done
[[ $MISSING -eq 0 ]] || fail "bundle incomplete vs flash script required set"

# Non-experimental stamp name
base="$(basename "$BUNDLE_REAL")"
if [[ "$base" =~ ^rango-[0-9]{8}-[0-9]{6}$ ]]; then
  log "non-experimental stamp name: $base"
else
  fail "stamp name not rango-YYYYMMDD-HHMMSS: $base"
fi

# ---------------------------------------------------------------------------
step "2  Rescue boot (rango always flashes before first fastbootd)"
[[ -d "$RESCUE" ]] || fail "rescue dir missing: $RESCUE"
for f in "${RANGO_RESCUE_IMGS[@]}"; do
  if [[ -f "$RESCUE/$f" ]]; then
    log "rescue $f"
  else
    fail "rescue missing: $RESCUE/$f"
  fi
done

# ---------------------------------------------------------------------------
step "3  Local download simulation (cp → work dir, as scp client would)"
mkdir -p "$WORK/client"
for f in "${REQUIRED[@]}" "${RANGO_EXTRA_FILES[@]}"; do
  is_optional "$f" && [[ ! -f "$BUNDLE/$f" ]] && continue
  [[ -f "$BUNDLE/$f" ]] || continue
  cp -a "$BUNDLE/$f" "$WORK/client/$f"
done
# rescue subdir as download_rango_rescue_boot does
mkdir -p "$WORK/client/rango-rescue"
for f in "${RANGO_RESCUE_IMGS[@]}"; do
  cp -a "$RESCUE/$f" "$WORK/client/rango-rescue/$f"
done
# post-download existence check (mirror script verify loop)
for f in "${REQUIRED[@]}"; do
  if is_optional "$f"; then
    [[ -f "$WORK/client/$f" ]] || { warn "optional $f absent in client work dir"; continue; }
  fi
  [[ -f "$WORK/client/$f" ]] || fail "client work missing after local download: $f"
done
for f in "${RANGO_RESCUE_IMGS[@]}"; do
  [[ -f "$WORK/client/rango-rescue/$f" ]] || fail "client rescue missing: $f"
done
log "local download simulation complete → $WORK/client ($(du -sh "$WORK/client" | awk '{print $1}'))"

# ---------------------------------------------------------------------------
step "4  SHA256SUMS (if present)"
if [[ -f "$BUNDLE/SHA256SUMS" ]]; then
  if (cd "$BUNDLE" && sha256sum -c SHA256SUMS --quiet); then
    log "SHA256SUMS: all listed files OK"
  else
    fail "SHA256SUMS verification failed"
  fi
else
  warn "no SHA256SUMS in bundle"
fi

# ---------------------------------------------------------------------------
step "5  AVB artifacts"
VB="$BUNDLE/vbmeta.img"
if [[ -f "$VB" ]]; then
  # Flags at offset 120 (AVBFooter) — Flags:3 expected for GT/dev
  # Use python for reliable little-endian read of AvbVBMetaImageHeader.flags at offset 72? 
  # AvbVBMetaImageHeader: magic@0, ... flags at offset 120 per AVB 2.0
  flags=$(python3 -c 'import struct,sys; f=open(sys.argv[1],"rb"); f.seek(120); print(struct.unpack(">I",f.read(4))[0])' "$VB")
  if [[ "$flags" == "3" ]]; then
    log "vbmeta.img Flags=$flags (HASHTREE_DISABLED|VERIFICATION_DISABLED)"
  else
    warn "vbmeta.img Flags=$flags (expected 3 for GT test-key Flags:3 path)"
  fi
fi
[[ -f "$BUNDLE/avb_pkmd.bin" ]] && log "avb_pkmd.bin present ($(stat -c%s "$BUNDLE/avb_pkmd.bin") bytes)" \
  || fail "avb_pkmd.bin missing (avb_custom_key flash would fail)"

# ---------------------------------------------------------------------------
step "6  Shipped vendor.img sepolicy graft MATCH"
OUT="${OUT:-$ROOT/out/target/product/rango}"
DBG=""
for c in "$ROOT/prebuilts/misc/linux-x86/e2fsprogs/debugfs" \
         "$(command -v debugfs 2>/dev/null || true)"; do
  [[ -n "$c" && -x "$c" ]] && DBG="$c" && break
done
SIMG=""
for c in "$ROOT/out/host/linux-x86/bin/simg2img" \
         "$(command -v simg2img 2>/dev/null || true)"; do
  [[ -n "$c" && -x "$c" ]] && SIMG="$c" && break
done
if [[ -z "$DBG" || -z "$SIMG" ]]; then
  warn "debugfs/simg2img unavailable — skip shipped vendor sepolicy re-cmp"
elif [[ ! -f "$OUT/system/etc/selinux/plat_sepolicy_and_mapping.sha256" ]]; then
  warn "OUT tree incomplete — skip shipped vendor sepolicy re-cmp"
else
  if file "$BUNDLE/vendor.img" | grep -qi sparse; then
    "$SIMG" "$BUNDLE/vendor.img" "$WORK/vendor.raw" >/dev/null
  else
    cp -f "$BUNDLE/vendor.img" "$WORK/vendor.raw"
  fi
  for pair in \
    "precompiled_sepolicy.plat_sepolicy_and_mapping.sha256:$OUT/system/etc/selinux/plat_sepolicy_and_mapping.sha256" \
    "precompiled_sepolicy.system_ext_sepolicy_and_mapping.sha256:$OUT/system_ext/etc/selinux/system_ext_sepolicy_and_mapping.sha256" \
    "precompiled_sepolicy.product_sepolicy_and_mapping.sha256:$OUT/product/etc/selinux/product_sepolicy_and_mapping.sha256"
  do
    vf="${pair%%:*}"; ref="${pair#*:}"
    "$DBG" -R "dump etc/selinux/$vf $WORK/$vf" "$WORK/vendor.raw" >/dev/null 2>&1 \
      || { fail "debugfs dump failed: $vf"; continue; }
    if cmp -s "$WORK/$vf" "$ref"; then
      log "shipped vendor $vf MATCH vs OUT"
    else
      fail "shipped vendor $vf MISMATCH vs OUT (would force secilc → 0x7f00 risk)"
    fi
  done
fi

# ---------------------------------------------------------------------------
step "7  MTE / memtag_heap strips (device layer)"
BC="$ROOT/vendor/guardtalk/device/rango/BoardConfig-excised-late.mk"
INIT_BP="$ROOT/system/core/init/Android.bp"
[[ -f "$BC" ]] || fail "missing $BC"
grep -q 'MTE_FORCE_ON' "$BC" && log "BoardConfig strips MTE_FORCE_ON" || fail "MTE_FORCE_ON strip missing"
grep -q 'memtag_heap' "$BC" && log "BoardConfig strips memtag_heap" || fail "memtag_heap strip missing"
grep -q 'memtag_heap: false' "$INIT_BP" && log "init Android.bp memtag_heap: false" || fail "init memtag_heap: false missing"

# ---------------------------------------------------------------------------
step "8  Dry-run flash order (rango path — no device I/O)"
cat <<'EOF'
  [plan] 2/9  fastboot flash bootloader + radio → reboot-bootloader
  [plan] 3/9  fastboot -w (userdata wipe)
  [plan] 4/9  rango: flash STOCK rescue boot chain (boot/init_boot/vendor_boot/…)
  [plan] 5/9  fastboot reboot fastboot → wait is-userspace=yes
  [plan] 6/9  flash super OR wipe-super + logical (system/system_ext/product/vendor/…)
  [plan] 7/9  reboot bootloader → flash GuardTalk boot chain + dtbo + pvmfw
  [plan] 8/9  flash vbmeta* (+ avb_custom_key from avb_pkmd.bin)
  [plan] 9/9  reboot → wait adb → push init.insmod.rango.cfg
EOF
# Confirm script still contains rango rescue-first branch
grep -q 'flash_rango_rescue_boot_chain' "$FLASH_SCRIPT" \
  && log "script contains rango rescue-before-fastbootd path" \
  || fail "rango rescue path missing from flash script"
grep -q 'FLASH_DEVICE.*rango' "$FLASH_SCRIPT" \
  && log "script has rango device branch" \
  || fail "rango device branch missing"

# ---------------------------------------------------------------------------
step "9  Device presence (honest — not invented)"
ADB_OUT="$(adb devices 2>/dev/null | awk 'NR>1 && $2!=""{print}' || true)"
FB_OUT="$("$FASTBOOT" devices 2>/dev/null || true)"
if [[ -n "$ADB_OUT" || -n "$FB_OUT" ]]; then
  log "device visible — full live flash possible this session"
  printf '%s\n' "$ADB_OUT" "$FB_OUT"
else
  warn "no adb/fastboot device — host rehearsal only; live flash NOT executed"
fi

# ---------------------------------------------------------------------------
step "RESULT"
printf '  passes=%s  fails=%s  warns=%s\n' "$PASS" "$FAIL" "$WARN"
if [[ "$FAIL" -gt 0 ]]; then
  printf '\nHOST E2E: FAIL — flash client would likely die before/during flash\n'
  exit 1
fi
printf '\nHOST E2E: PASS — flash-from-remote.sh has every host-side input for rango-latest\n'
printf 'DEVICE BOOT: HOLD — plug Pixel 10 Pro Fold, then:\n'
printf '  export PATH=%s:$PATH\n' "$(dirname "$(command -v "$FASTBOOT")")"
printf '  DEVICE=rango bash %s\n' "$FLASH_SCRIPT"
exit 0
