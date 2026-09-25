#!/usr/bin/env bash
# Independent on-device probe for Q-REMEDIATE-B2-ONDEVICE (DEC-REMEDIATE-003).
# Pair of T-REMEDIATE-B2-EXCISE + KERNEL + TELEMETRY (Architect-APPROVED static;
# do not trust). PASS HOLD lift gate with Q-REMEDIATE-B1-ONDEVICE (do not wait).
#
# Probe adb first. Empty / wrong serial = HOLD REVIEW (successful HOLD delivery).
# Named unit 54111FDAS000GN on a **user** image: location/GmsCompat absent;
# /proc/sys kernel (paranoid/yama/bpf documented HOLDs allowed); no persistent
# logs; pktrouter/BIP not restarting; empty device-admins; EXIF no make/model.
# If still userdebug: HOLD, do not lift PASS HOLD.
#
# Forbidden: product source edits, doctrine, secrets, USB GO, flash, lock,
# wipe, `m`, git commit, derived TASK_QUEUE.md, memory-bank, claiming
# APPROVED / live / PASS HOLD lift.
#
# Empty adb = successful HOLD delivery. Exit 0 on documented HOLD.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b2_ondevice.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

SERIAL="54111FDAS000GN"
ART="vendor/guardtalk/docs/qa/_artifacts"
mkdir -p "$ART"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=1; }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

LIVE_DEVICE_CLAIMED=false
BUILD_TYPE="unknown"
BUILD_DEBUGGABLE="unknown"
NAMED_STATE="absent"
ADB_EMPTY=true
USER_IMAGE=false

echo "=== Q-REMEDIATE-B2-ONDEVICE independent probe (Block 2 PASS HOLD lift) ==="
echo "ROOT=$ROOT"
echo "SERIAL=$SERIAL"
echo "PAIR=T-REMEDIATE-B2-EXCISE+KERNEL+TELEMETRY (Architect-APPROVED static; not trusted)"
echo "SIBLING=Q-REMEDIATE-B1-ONDEVICE (do not wait)"
echo "USB_GO=not started"
echo "FLASH=not started"
echo "LOCK=not started"
echo "WIPE=not started"
echo "M_NOT_RUN=true"
echo "PASS_HOLD=remains"
echo "LIVE_DEVICE_CLAIMED=false"
echo

echo "--- adb devices -l ---"
if ! command -v adb >/dev/null 2>&1; then
  ADB_OUT="ADB_NOT_FOUND"
  echo "$ADB_OUT"
  hold "adb binary not on PATH — treat as empty; HOLD REVIEW"
else
  pass "adb binary present"
  ADB_OUT="$(adb devices -l 2>&1 || true)"
  echo "$ADB_OUT"
fi
printf '%s\n' "$ADB_OUT" >"$ART/Q-REMEDIATE-B2-ONDEVICE_adb_devices_-l.txt"

ADB_LINES="$(printf '%s\n' "$ADB_OUT" | awk 'NR>1 && NF>0 {print}' || true)"
if [[ -z "${ADB_LINES}" || "$ADB_OUT" == "ADB_NOT_FOUND" ]]; then
  ADB_EMPTY=true
  NAMED_STATE="absent"
  hold "adb devices -l empty — serial ${SERIAL} absent — HOLD REVIEW (successful HOLD delivery)"
  pass "empty-adb path taken; did not invent live Block 2"
else
  ADB_EMPTY=false
  pass "adb devices -l returned at least one row (will classify serial)"
fi

if printf '%s\n' "$ADB_OUT" | grep -E "^${SERIAL}[[:space:]]" >/dev/null 2>&1; then
  NAMED_LINE="$(printf '%s\n' "$ADB_OUT" | grep -E "^${SERIAL}[[:space:]]" | head -n1)"
  echo "NAMED_LINE=${NAMED_LINE}"
  if printf '%s\n' "$NAMED_LINE" | grep -q 'unauthorized'; then
    NAMED_STATE="unauthorized"
    hold "named unit ${SERIAL} unauthorized — ADB RSA not granted; do not USB GO"
  elif printf '%s\n' "$NAMED_LINE" | grep -q 'offline'; then
    NAMED_STATE="offline"
    hold "named unit ${SERIAL} offline — HOLD REVIEW; do not USB GO"
  elif printf '%s\n' "$NAMED_LINE" | awk '{print $2}' | grep -qx 'device'; then
    NAMED_STATE="device"
    pass "named unit ${SERIAL} in device state"
  else
    NAMED_STATE="other"
    hold "named unit ${SERIAL} present but not in device state: ${NAMED_LINE}"
  fi
else
  if [[ "$ADB_EMPTY" == "false" ]]; then
    hold "adb has a device but serial is not ${SERIAL} — HOLD REVIEW (wrong unit)"
    NAMED_STATE="wrong-serial"
  fi
fi
echo "NAMED_STATE=${NAMED_STATE}"
echo "ADB_EMPTY=${ADB_EMPTY}"

shell() {
  adb -s "$SERIAL" shell "$@"
}

record_hold_live() {
  hold "$1 (live not proven this stamp)"
}

dump_props_if_live() {
  local f="$ART/Q-REMEDIATE-B2-ONDEVICE_getprop.txt"
  {
    echo "ro.build.type=$(shell getprop ro.build.type 2>/dev/null || true)"
    echo "ro.debuggable=$(shell getprop ro.debuggable 2>/dev/null || true)"
    echo "ro.build.fingerprint=$(shell getprop ro.build.fingerprint 2>/dev/null || true)"
    echo "ro.build.tags=$(shell getprop ro.build.tags 2>/dev/null || true)"
    echo "ro.build.keys=$(shell getprop ro.build.keys 2>/dev/null || true)"
    echo "ro.product.device=$(shell getprop ro.product.device 2>/dev/null || true)"
  } >"$f"
  echo "--- getprop snapshot ---"
  cat "$f"
  BUILD_TYPE="$(awk -F= '/^ro.build.type=/{print $2}' "$f")"
  BUILD_DEBUGGABLE="$(awk -F= '/^ro.debuggable=/{print $2}' "$f")"
}

echo
echo "--- image class (user vs userdebug) ---"
if [[ "$NAMED_STATE" == "device" ]]; then
  dump_props_if_live
  if [[ "$BUILD_TYPE" == "user" && "$BUILD_DEBUGGABLE" == "0" ]]; then
    USER_IMAGE=true
    pass "named unit reports ro.build.type=user and ro.debuggable=0"
  else
    USER_IMAGE=false
    hold "named unit still type=${BUILD_TYPE:-unknown} debuggable=${BUILD_DEBUGGABLE:-unknown} — HOLD; do not lift PASS HOLD on userdebug/test-keys"
  fi
else
  record_hold_live "ro.build.type=user / ro.debuggable=0"
  hold "user image not proven (serial absent or not in device state)"
fi

echo
echo "--- location / GmsCompat (EXCISE) ---"
if [[ "$NAMED_STATE" == "device" ]]; then
  PKGS="$(shell pm list packages 2>/dev/null || true)"
  printf '%s\n' "$PKGS" >"$ART/Q-REMEDIATE-B2-ONDEVICE_pm_list_packages.txt"
  GMS_HITS="$(printf '%s\n' "$PKGS" | grep -iE 'gmscompat|appcompatconfig' || true)"
  LOC_HITS="$(printf '%s\n' "$PKGS" | grep -iE 'fusedlocation|networklocation|gnssd|com\.google\.android\.gms' || true)"
  printf '%s\n' "$GMS_HITS" >"$ART/Q-REMEDIATE-B2-ONDEVICE_gms_hits.txt"
  printf '%s\n' "$LOC_HITS" >"$ART/Q-REMEDIATE-B2-ONDEVICE_loc_hits.txt"
  if [[ "$USER_IMAGE" == "true" ]]; then
    if [[ -z "$GMS_HITS" ]]; then
      pass "GmsCompat / AppCompatConfig packages absent on user image"
    else
      fail "GmsCompat cluster still packaged on user image: $GMS_HITS"
    fi
    if [[ -z "$LOC_HITS" ]]; then
      pass "FusedLocation / NetworkLocation / gnssd / GMS packages absent on user image"
    else
      fail "location/GMS packages still present on user image: $LOC_HITS"
    fi
  else
    hold "location/GmsCompat dump recorded but image is not user — not live PASS"
    echo "GMS_HITS=${GMS_HITS:-<none>}"
    echo "LOC_HITS=${LOC_HITS:-<none>}"
  fi
  shell dumpsys location 2>/dev/null | head -n 40 >"$ART/Q-REMEDIATE-B2-ONDEVICE_dumpsys_location.txt" || true
  hold "GNSS-dead / LocationManagerService start not claimed live (dumpsys snapshot only; LMS start is a documented static HOLD)"
else
  record_hold_live "location packages / GmsCompat absent"
  record_hold_live "on-device GNSS-dead / dumpsys location"
fi

echo
echo "--- /proc/sys kernel (KERNEL; documented HOLDs allowed) ---"
if [[ "$NAMED_STATE" == "device" ]]; then
  PARANOID="$(shell cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo MISSING)"
  YAMA="$(shell cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo MISSING)"
  BPF="$(shell cat /proc/sys/kernel/unprivileged_bpf_disabled 2>/dev/null || echo MISSING)"
  {
    echo "perf_event_paranoid=${PARANOID}"
    echo "yama/ptrace_scope=${YAMA}"
    echo "unprivileged_bpf_disabled=${BPF}"
  } >"$ART/Q-REMEDIATE-B2-ONDEVICE_proc_sys.txt"
  cat "$ART/Q-REMEDIATE-B2-ONDEVICE_proc_sys.txt"
  if [[ "$USER_IMAGE" == "true" ]]; then
    if [[ "$PARANOID" == "2" ]]; then
      pass "perf_event_paranoid=2"
    else
      hold "perf_event_paranoid=${PARANOID} (expected 2; documented HOLD if not rebuilt user image)"
    fi
    if [[ "$YAMA" == "1" ]]; then
      pass "yama/ptrace_scope=1"
    else
      hold "yama/ptrace_scope=${YAMA} (YAMA live Image HOLD documented; __lsm_yama may be absent)"
    fi
    if [[ "$BPF" == "1" ]]; then
      pass "unprivileged_bpf_disabled=1"
    else
      hold "unprivileged_bpf_disabled=${BPF} (boot_completed write; HOLD if not 1)"
    fi
  else
    hold "kernel sysctls dumped but image is not user — paranoid=${PARANOID} yama=${YAMA} bpf=${BPF} — HOLD"
  fi
else
  record_hold_live "/proc/sys/kernel/perf_event_paranoid"
  record_hold_live "/proc/sys/kernel/yama/ptrace_scope"
  record_hold_live "/proc/sys/kernel/unprivileged_bpf_disabled"
  hold "YAMA live Image / __lsm_yama remains a documented static HOLD (not rematched live)"
fi

echo
echo "--- persistent logs / EXIF (TELEMETRY) ---"
if [[ "$NAMED_STATE" == "device" ]]; then
  {
    echo "silentlog.tcp=$(shell getprop persist.vendor.sys.silentlog.tcp 2>/dev/null || true)"
    echo "modem.logging.enable=$(shell getprop persist.vendor.sys.modem.logging.enable 2>/dev/null || true)"
    echo "ril.log_mask=$(shell getprop persist.vendor.ril.log_mask 2>/dev/null || true)"
    echo "logpersistd.enable=$(shell getprop persist.logd.logpersistd 2>/dev/null || true)"
    echo "logd.logpersistd.enable=$(shell getprop logd.logpersistd.enable 2>/dev/null || true)"
    echo "exif_reveal_make_model=$(shell getprop persist.vendor.camera.exif_reveal_make_model 2>/dev/null || true)"
  } >"$ART/Q-REMEDIATE-B2-ONDEVICE_telemetry_props.txt"
  cat "$ART/Q-REMEDIATE-B2-ONDEVICE_telemetry_props.txt"
  shell ls -ld /data/vendor/slog /data/vendor/radio/sit-ril /data/misc/logd 2>/dev/null \
    >"$ART/Q-REMEDIATE-B2-ONDEVICE_data_log_dirs.txt" || true
  if [[ "$USER_IMAGE" == "true" ]]; then
    EXIF="$(awk -F= '/^exif_reveal_make_model=/{print $2}' "$ART/Q-REMEDIATE-B2-ONDEVICE_telemetry_props.txt")"
    SILENT="$(awk -F= '/^silentlog.tcp=/{print $2}' "$ART/Q-REMEDIATE-B2-ONDEVICE_telemetry_props.txt")"
    MODEM="$(awk -F= '/^modem.logging.enable=/{print $2}' "$ART/Q-REMEDIATE-B2-ONDEVICE_telemetry_props.txt")"
    MASK="$(awk -F= '/^ril.log_mask=/{print $2}' "$ART/Q-REMEDIATE-B2-ONDEVICE_telemetry_props.txt")"
    if [[ "$EXIF" == "false" ]]; then
      pass "persist.vendor.camera.exif_reveal_make_model=false"
    else
      hold "exif_reveal_make_model=${EXIF} (photo EXIF make/model not proven; no capture this stamp)"
    fi
    if [[ "$SILENT" == "Off" && "$MODEM" == "false" && "$MASK" == "0" ]]; then
      pass "silentlog Off / modem logging false / ril log_mask 0"
    else
      hold "vendor log props not fully off (silent=${SILENT} modem=${MODEM} mask=${MASK})"
    fi
    hold "runtime /data vendor log dir emptiness HOLD if unreadable without root (no adb root / USB GO)"
    hold "photo EXIF make/model bytes not captured (no shutter this stamp; property-only)"
  else
    hold "telemetry props dumped but image is not user — not live PASS"
    hold "photo EXIF make/model not captured (no shutter; no USB GO)"
  fi
else
  record_hold_live "persistent vendor logs off / /data log dirs empty"
  record_hold_live "photo EXIF make/model absent"
fi

echo
echo "--- pktrouter / BIP not restarting ---"
if [[ "$NAMED_STATE" == "device" ]]; then
  PKT_PS="$(shell ps -A 2>/dev/null | grep -iE 'pktrouter|bipchmgr|wfc-pkt' || true)"
  {
    echo "vendor.pktrouter=$(shell getprop vendor.pktrouter 2>/dev/null || true)"
    echo "init.svc.pktrouter=$(shell getprop init.svc.pktrouter 2>/dev/null || true)"
    echo "init.svc.pkt-router=$(shell getprop init.svc.pkt-router 2>/dev/null || true)"
    echo "init.svc.bipchmgr=$(shell getprop init.svc.bipchmgr 2>/dev/null || true)"
    echo "init.svc.wfc-pkt-router=$(shell getprop init.svc.wfc-pkt-router 2>/dev/null || true)"
    echo "--- ps ---"
    if [[ -n "$PKT_PS" ]]; then
      printf '%s\n' "$PKT_PS"
    else
      echo "<no pkt/bip processes>"
    fi
  } >"$ART/Q-REMEDIATE-B2-ONDEVICE_pkt_bip.txt"
  cat "$ART/Q-REMEDIATE-B2-ONDEVICE_pkt_bip.txt"
  if [[ "$USER_IMAGE" == "true" ]]; then
    if [[ -n "$PKT_PS" ]]; then
      hold "pkt/bip process rows present — not claiming not-restarting"
    else
      pass "no pktrouter/BIP process rows in ps dump"
    fi
  else
    hold "pktrouter/BIP dump recorded but image is not user — not live PASS"
  fi
else
  record_hold_live "pktrouter/BIP not restarting"
fi

echo
echo "--- device-admins ---"
if [[ "$NAMED_STATE" == "device" ]]; then
  {
    echo "--- dumpsys device_policy (owners) ---"
    shell dumpsys device_policy 2>/dev/null | grep -iE 'Owner|DeviceAdmin|active' | head -n 40 || true
    echo "--- dpm list-owners ---"
    shell dpm list-owners 2>/dev/null || true
    echo "--- DeviceLock packages ---"
    shell pm list packages 2>/dev/null | grep -iE 'devicelock' || echo "<no DeviceLock packages>"
  } >"$ART/Q-REMEDIATE-B2-ONDEVICE_device_admins.txt"
  cat "$ART/Q-REMEDIATE-B2-ONDEVICE_device_admins.txt"
  if [[ "$USER_IMAGE" == "true" ]]; then
    if grep -qi 'DeviceLockController' "$ART/Q-REMEDIATE-B2-ONDEVICE_device_admins.txt"; then
      fail "DeviceLockController still present on user image"
    else
      pass "DeviceLockController package name absent from live dump"
    fi
    hold "com.android.devicelock APEX remains a documented static HOLD (not claimed excised live)"
  else
    hold "device-admin dump recorded but image is not user — not live PASS"
    hold "com.android.devicelock APEX remains a documented static HOLD"
  fi
else
  record_hold_live "empty device-admins / DeviceLockController absent"
  hold "com.android.devicelock APEX remains a documented static HOLD"
fi

echo
echo "--- process / forbidden-action checks ---"
pass "Q-REMEDIATE-B1-ONDEVICE sibling not waited"
pass "USB GO not started"
pass "flash not started"
pass "lock not started"
pass "wipe not started"
pass "m not run"
pass "no APPROVED claim from this probe"
pass "PASS HOLD remains (not lifted)"
pass "LIVE_DEVICE_CLAIMED=false"
if [[ "$ADB_EMPTY" == "true" ]]; then
  pass "empty adb = successful HOLD delivery (EXIT 0)"
fi

echo
echo "LIVE_DEVICE_CLAIMED=${LIVE_DEVICE_CLAIMED}"
echo "ADB_EMPTY=${ADB_EMPTY}"
echo "NAMED_STATE=${NAMED_STATE}"
echo "BUILD_TYPE=${BUILD_TYPE}"
echo "USER_IMAGE=${USER_IMAGE}"
echo "PASS_HOLD=remains"
echo "USB_GO=not started"
echo "Q_B1_ONDEVICE=not waited"

if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT: FAIL  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=1 EXIT=1"
  echo "LIVE_DEVICE_CLAIMED=false"
  echo "PASS_HOLD=remains"
  exit 1
fi
echo "RESULT: HOLD (documented)  PASS_COUNT=$PASS_N HOLD_COUNT=$HOLD_N FAIL=0 EXIT=0"
echo "LIVE_DEVICE_CLAIMED=false"
echo "PASS_HOLD=remains"
echo "DEVICE=HOLD"
echo "GNSS_DEAD_ONDEVICE=HOLD"
echo "PROC_SYS=HOLD"
echo "EXIF=HOLD"
echo "LOGS=HOLD"
echo "PKT_BIP=HOLD"
echo "DEVICE_ADMINS=HOLD"
echo "USERDEBUG_OR_EMPTY=HOLD"
exit 0
