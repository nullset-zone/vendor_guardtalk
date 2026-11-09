#!/bin/bash
# =============================================================================
# diag-camera-stallion.sh — STRICTLY READ-ONLY camera capture for STALLION
#
# Card:   T-CAM-STALLION-DIAG   (qa_pair Q-CAM-STALLION-DIAG)
# Device: stallion, serial 67201JEA300680 (default; override with $2)
#
# Purpose
#   Capture the device evidence that discriminates the two candidate causes of
#   the dead camera on the Stallion handset. Both may be true at once, so this
#   script does not argue for either — it records what the device says.
#
#     Cause A (proven in logcat): PCS
#       com.google.android.apps.camera.services crashes at startup because
#       app.grapheneos.gmscompat.lib is absent (deliberate no-GMS excision).
#
#     Cause B (plausible, UNPROVEN on stallion): CameraExtensionsProxy absent
#       from system.img -> ICameraExtensionsProxyService missing -> black
#       preview. Measured on tokay/tangorpro, never on stallion.
#
#   The discriminator is ORDER: does PCS die before any provider-binding
#   attempt, or after the provider fails to bind? Section (I) answers that and
#   states the conclusion explicitly in the output.
#
# Standing rule (T-PORT-TANGORPRO-CAMERA):
#   "No fix may be proposed until that output exists. This wave has already
#    falsified six source-derived theories; the camera fix must follow device
#    evidence."
#
# -----------------------------------------------------------------------------
# STRICTLY READ-ONLY CONTRACT
#
# The complete set of device-touching operations used by this script:
#     adb shell getprop ...
#     adb shell ps -A
#     adb shell lshal
#     adb shell service list
#     adb shell pm list packages ...
#     adb shell pm path ...
#     adb shell dumpsys ...
#     adb shell dmesg ...
#     adb shell ls ...
#     adb logcat -d ...            (-d = dump and exit, never blocks)
#     adb devices / adb version / adb start-server   (host-side only)
#
# Nothing here writes to the device: no push, no install/uninstall, no
# pm enable/disable, no reboot, no fastboot, no wipe, no rm, no su -c, no
# setprop, no settings put. Host-side files written: only $OUT and a temp dir
# that is removed on exit.
# -----------------------------------------------------------------------------
#
# Usage:
#   bash vendor/guardtalk/scripts/diag-camera-stallion.sh [OUTFILE] [SERIAL]
#
# Defaults:
#   OUTFILE = ./camera-diag-stallion.txt
#   SERIAL  = first device in "device" state, preferring 67201JEA300680
#
# Exit codes:
#   0  capture written
#   1  adb unusable on every port tried (host problem)
#   2  no device reachable (nothing captured, nothing invented)
# =============================================================================
set -u

OUT="${1:-camera-diag-stallion.txt}"
WANT_SERIAL="${2:-67201JEA300680}"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---------------------------------------------------------------------------
# Portable timeout wrapper. GNU `timeout` on Linux, `gtimeout` from coreutils
# on macOS (where the tangorpro diag ran), else a pure-bash fallback.
# ---------------------------------------------------------------------------
run_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
    return $?
  fi
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
    return $?
  fi
  local pid wd rc
  "$@" &
  pid=$!
  (
    sleep "$secs"
    kill -TERM "$pid" 2>/dev/null
  ) >/dev/null 2>&1 &
  wd=$!
  wait "$pid"
  rc=$?
  kill -TERM "$wd" 2>/dev/null
  wait "$wd" 2>/dev/null
  return $rc
}

if ! command -v adb >/dev/null 2>&1; then
  cat <<'MSG'

  adb is not on PATH.

  Install platform-tools, or point PATH at an existing install:
      export PATH="/usr/lib/android-sdk/platform-tools:$PATH"

MSG
  exit 1
fi

# ===========================================================================
# PHASE 1 — TRANSPORT (deliberately NOT written to $OUT)
#
# A capture file must contain device output or not exist at all. If the
# transport cannot be established we exit before creating $OUT, so a later
# reader can never mistake an empty file for evidence.
# ===========================================================================
echo "diag-camera-stallion: resolving adb transport..."

# ---------------------------------------------------------------------------
# KNOWN ISSUE (carried over from tangorpro diag-camera.sh, 2026-10-29):
# Cursor's Android integration LISTENS on 127.0.0.1:5037 on the Mac. That is
# not a real adb server, so a client on the default port gets
# "protocol fault (couldn't read status)". So: never assume 5037 works here.
# Probe a list of alternative ports and use the first one that answers.
#
# An operator-supplied ANDROID_ADB_SERVER_PORT is honoured first, so this
# script composes with whatever transport was already arranged.
# ---------------------------------------------------------------------------
ADB_PORT=""

if [ -n "${ANDROID_ADB_SERVER_PORT:-}" ]; then
  if run_timeout 10 adb devices >/dev/null 2>&1; then
    ADB_PORT="${ANDROID_ADB_SERVER_PORT}"
    echo "  honouring preset ANDROID_ADB_SERVER_PORT=$ADB_PORT"
  fi
fi

if [ -z "$ADB_PORT" ]; then
  for p in 5099 5100 5101 5102 5038 5039; do
    if run_timeout 10 env ANDROID_ADB_SERVER_PORT=$p adb devices >/dev/null 2>&1; then
      ADB_PORT=$p
      break
    fi
  done
fi

if [ -z "$ADB_PORT" ]; then
  echo "  default-port attempt (last resort)..."
  if run_timeout 10 adb devices >/dev/null 2>&1; then
    ADB_PORT="default"
  fi
fi

if [ -z "$ADB_PORT" ]; then
  cat <<'MSG'

  adb is unusable on EVERY port tried (5099 5100 5101 5102 5038 5039, default).

  Check who owns the ports and which binaries exist:
      lsof -nP -iTCP:5037 -sTCP:LISTEN
      which -a adb

  If a process (e.g. Cursor) holds 5037 that is expected — use another port:
      ANDROID_ADB_SERVER_PORT=5099 adb devices

MSG
  exit 1
fi

if [ "$ADB_PORT" = "default" ]; then
  echo "  using: default port"
  run_timeout 15 adb start-server >/dev/null 2>&1
else
  echo "  using port $ADB_PORT"
  export ANDROID_ADB_SERVER_PORT=$ADB_PORT
  run_timeout 15 adb start-server >/dev/null 2>&1
fi
sleep 1

echo "  adb: $(adb version 2>/dev/null | tail -1)"
adb devices -l 2>/dev/null

# --- pick the serial ------------------------------------------------------
SERIAL=""
if adb devices 2>/dev/null | awk '$2=="device"{print $1}' | grep -qx "$WANT_SERIAL"; then
  SERIAL="$WANT_SERIAL"
else
  SERIAL="$(adb devices 2>/dev/null | awk '$2=="device"{print $1; exit}')"
fi

if [ -z "$SERIAL" ]; then
  cat <<'MSG'

  =====================================================================
  BLOCKED — NO DEVICE REACHABLE. NO CAPTURE TAKEN.
  =====================================================================

  No transport is in "device" state. Nothing was captured and nothing in
  this report is device-derived. No file was written.

  Operator action required — ONE of:

  (a) Attach the handset to the build host over USB, unlock it, and accept
      the "Allow USB debugging" prompt for this host key. Then re-run:

          bash vendor/guardtalk/scripts/diag-camera-stallion.sh \
              .agent-comm/evidence/T-CAM-STALLION-DIAG/device-capture.txt

  (b) OR run the script ON the Mac, pointed at the phone over its own USB.
      This is the more reliable path, because fastboot/adb are USB-local to
      the Mac. From the Mac:

          curl -fsSL "http://192.168.2.220:8000/diag-camera-stallion.sh" \
              -o ~/GuardTalk-flash/diag-camera-stallion.sh

      or, if that endpoint is down, fetch it over ssh:

          scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/guardtalk/scripts/diag-camera-stallion.sh \
              ~/GuardTalk-flash/diag-camera-stallion.sh

      then:

          cd ~/GuardTalk-flash
          bash diag-camera-stallion.sh camera-diag.txt

      Send the resulting camera-diag.txt back. That file is the evidence this
      card is blocked on.

  If the device shows "unauthorized": unlock the handset and tap Allow.
  If it shows "offline": adb kill-server, replug, adb devices.

MSG
  exit 2
fi

echo "  serial: $SERIAL"

# ---------------------------------------------------------------------------
# Device command helpers. `shell` is always a single quoted string so the
# device-side shell does the parsing, not this one.
# ---------------------------------------------------------------------------
sh_dev() { run_timeout 60 adb -s "$SERIAL" shell "$1" 2>/dev/null | tr -d '\r'; }
lg_dev() { run_timeout 120 adb -s "$SERIAL" logcat "$@" 2>/dev/null | tr -d '\r'; }

# A quick liveness gate before we start writing the capture.
if [ -z "$(sh_dev 'getprop ro.product.device')" ]; then
  echo
  echo "  Device $SERIAL answered adb but returned no properties."
  echo "  Treating as unreachable. No capture taken."
  exit 2
fi

# ===========================================================================
# PHASE 2 — CAPTURE
# ===========================================================================
mkdir -p "$(dirname "$OUT")" 2>/dev/null
TMPD="$(mktemp -d 2>/dev/null || echo "/tmp/diag-camera-stallion.$$")"
mkdir -p "$TMPD" 2>/dev/null
trap 'rm -rf "$TMPD" 2>/dev/null' EXIT INT TERM

# Pre-pull the two buffers we need to reason about, so the ordering analysis
# reads a stable snapshot instead of re-querying a moving log.
lg_dev -d -v threadtime >"$TMPD/all.txt"
lg_dev -d -b crash -v threadtime >"$TMPD/crash.txt"
lg_dev -d -b kernel -v threadtime >"$TMPD/kernel.txt"

{
  echo "=============================================================="
  echo " STALLION CAMERA DIAGNOSTIC  (STRICTLY READ-ONLY)"
  echo " card:   T-CAM-STALLION-DIAG   qa_pair: Q-CAM-STALLION-DIAG"
  echo " host:   $(hostname)   at $STAMP"
  echo " serial: $SERIAL"
  echo "=============================================================="

  # -------------------------------------------------------------------------
  echo
  echo "=== (a) IDENTITY ==="
  # -------------------------------------------------------------------------
  echo "  ro.product.device          : $(sh_dev 'getprop ro.product.device')"
  echo "  ro.product.model           : $(sh_dev 'getprop ro.product.model')"
  echo "  ro.build.fingerprint       : $(sh_dev 'getprop ro.build.fingerprint')"
  echo "  ro.build.id                : $(sh_dev 'getprop ro.build.id')"
  echo "  ro.build.version.incremental: $(sh_dev 'getprop ro.build.version.incremental')"
  echo "  ro.build.date              : $(sh_dev 'getprop ro.build.date')"
  echo "  ro.guardtalk.*             :"
  sh_dev 'getprop | grep -i guardtalk' | sed 's/^/    /'
  echo "  sys.boot_completed         : $(sh_dev 'getprop sys.boot_completed')"
  echo "  dev.bootcomplete           : $(sh_dev 'getprop dev.bootcomplete')"
  echo "  uptime                     : $(sh_dev 'cat /proc/uptime')"

  # -------------------------------------------------------------------------
  echo
  echo "=== (b) IS THE CAMERA MERELY *DISABLED*? ==="
  # A disabled package would be a third, much cheaper explanation than A or B.
  # A prior check returned empty; confirm on this boot rather than trusting it.
  # -------------------------------------------------------------------------
  echo "  -- pm list packages -d | grep -i camera  (disabled packages) --"
  DIS_DUMP="$(sh_dev 'pm list packages -d')"
  echo "$DIS_DUMP" | grep -i camera | sed 's/^/    /'
  if echo "$DIS_DUMP" | grep -qi camera; then
    echo "    >> a camera package IS in the disabled list"
  else
    echo "    >> (empty) no camera package is disabled"
  fi
  echo "  -- disabled packages overall (count) --"
  echo "    count: $(echo "$DIS_DUMP" | grep -c '^package:' 2>/dev/null)"

  echo "  -- installed + enabled camera packages (for contrast) --"
  sh_dev 'pm list packages -e' | grep -i camera | sed 's/^/    /'

  echo "  -- all camera-ish packages, any state --"
  sh_dev 'pm list packages' | grep -iE 'camera|gcam|pixelcam|pcs' | sed 's/^/    /'

  echo "  -- the two packages at the centre of this card --"
  for pkg in com.google.android.apps.camera.services \
             com.android.cameraextensions \
             app.grapheneos.gmscompat.lib; do
    path="$(sh_dev "pm path $pkg")"
    if [ -n "$path" ]; then
      echo "    PRESENT  $pkg"
      echo "$path" | sed 's/^/             /'
    else
      echo "    ABSENT   $pkg"
    fi
  done

  echo "  -- PCS enablement detail (if resolvable) --"
  sh_dev 'dumpsys package com.google.android.apps.camera.services' \
    | grep -iE 'enabled=|stopped=|not installed|Unable to find|versionName|flags=' \
    | sed 's/^/    /'

  # -------------------------------------------------------------------------
  echo
  echo "=== (c) IS ICameraExtensionsProxyService PRESENT AT ALL? ==="
  # Cause B lives or dies here. The service is registered by
  # CameraExtensionsProxy (com.android.cameraextensions), which this tree's
  # apps-excised.mk drops.
  # -------------------------------------------------------------------------
  echo "  -- service list | grep -i -E 'camera|extension' --"
  SVC_DUMP="$(sh_dev 'service list')"
  echo "$SVC_DUMP" | grep -iE 'camera|extension' | sed 's/^/    /'
  echo "  -- explicit probe of the extension proxy service name --"
  if echo "$SVC_DUMP" | grep -q 'ICameraExtensionsProxyService'; then
    echo "    PRESENT: ICameraExtensionsProxyService is registered with servicemanager"
  else
    echo "    ABSENT : ICameraExtensionsProxyService is NOT registered with servicemanager"
  fi
  echo "  -- any camera service at all? --"
  if echo "$SVC_DUMP" | grep -qi camera; then
    echo "    yes — camera-named services exist (see list above)"
  else
    echo "    no camera-named service registered"
  fi

  # -------------------------------------------------------------------------
  echo
  echo "=== (d) IS vendor.camera-provider-2-7-google RUNNING? ==="
  # -------------------------------------------------------------------------
  echo "  -- ps -A | grep -i camera --"
  PS_CAM="$(sh_dev 'ps -A' | grep -i camera)"
  echo "${PS_CAM:-    (no camera process in ps -A)}" | sed 's/^/    /'
  echo "  -- provider / cameraserver processes specifically --"
  sh_dev 'ps -A' | grep -iE 'camera_provider|provider@2|cameraserver|camera\.provider' | sed 's/^/    /'

  echo "  -- getprop | grep init.svc.*camera --"
  SVC_PROP="$(sh_dev 'getprop' | grep -iE 'init\.svc.*camera')"
  echo "${SVC_PROP:-    (no init.svc.*camera properties)}" | sed 's/^/    /'

  echo "  -- the specific provider service property --"
  for p in init.svc.vendor.camera-provider-2-7-google \
           init.svc.vendor.camera-provider-2-7 \
           init.svc.vendor.camera-provider-2-4 \
           init.svc.cameraserver; do
    v="$(sh_dev "getprop $p")"
    printf '    %-46s = %s\n' "$p" "${v:-<unset>}"
  done

  echo "  -- lshal | grep -i camera --"
  LSHAL_CAM="$(run_timeout 60 adb -s "$SERIAL" shell lshal 2>/dev/null | tr -d '\r' | grep -i camera)"
  echo "${LSHAL_CAM:-    (lshal returned no camera HAL entries, or lshal is unavailable)}" | sed 's/^/    /'

  echo "  -- camera APEX mounted? --"
  sh_dev 'ls -la /apex/ 2>/dev/null' | grep -i camera | sed 's/^/    /'
  sh_dev 'ls -la /vendor/apex/ 2>/dev/null' | grep -i camera | sed 's/^/    /'
  echo "  -- apexd active camera APEXes --"
  sh_dev 'pm list packages --apex-only 2>/dev/null' | grep -i camera | sed 's/^/    /'

  # -------------------------------------------------------------------------
  echo
  echo "=== (e) WHAT DOES THE FRAMEWORK SEE? dumpsys media.camera | head -60 ==="
  # -------------------------------------------------------------------------
  DUMPSYS="$(run_timeout 60 adb -s "$SERIAL" shell dumpsys media.camera 2>/dev/null | tr -d '\r')"
  if [ -z "$DUMPSYS" ]; then
    echo "    (dumpsys media.camera returned nothing — cameraserver may be absent or wedged)"
  else
    echo "$DUMPSYS" | head -60 | sed 's/^/    /'
  fi
  echo
  echo "  -- camera IDs the framework reports --"
  CAM_ID_LINES="$(echo "$DUMPSYS" | grep -iE 'camera id|Device [0-9]|Number of camera|== Camera device' )"
  echo "${CAM_ID_LINES:-    (no camera-id lines)}" | sed 's/^/    /'
  CAM_ID_COUNT="$(echo "$DUMPSYS" | grep -icE 'camera id:|== Camera device')"
  # grep -c on empty input still returns a number, but guard against any
  # non-numeric result so the later `-eq`/`-gt` tests cannot blow up.
  case "$CAM_ID_COUNT" in
    ''|*[!0-9]*) CAM_ID_COUNT=0 ;;
  esac
  echo "  CAMERA_ID_COUNT=$CAM_ID_COUNT"

  echo "  -- cameraserver alive? --"
  echo "    cameraserver pid: $(sh_dev 'pidof cameraserver')"
  echo "    provider@2.7 pid: $(sh_dev 'pidof vendor.camera-provider-2-7-google')"

  # -------------------------------------------------------------------------
  echo
  echo "=== (f) FULL CRASH BUFFER (logcat -d -b crash) ==="
  # -------------------------------------------------------------------------
  if [ -s "$TMPD/crash.txt" ]; then
    cat "$TMPD/crash.txt" | sed 's/^/    /'
  else
    echo "    (crash buffer is EMPTY)"
  fi
  echo
  echo "  -- crash buffer size / line count --"
  echo "    lines: $(wc -l <"$TMPD/crash.txt" | tr -d ' ')"

  # -------------------------------------------------------------------------
  echo
  echo "=== (g) FILTERED LOGCAT ==="
  # -------------------------------------------------------------------------
  FILT_RE='CameraService|camera|provider@2\.7|CameraExtensionsProxy|ICameraExtensionsProxyService|proxy_camera_provider|GmsCompat|createPackageContext|gmscompat'
  echo "  filter: $FILT_RE"
  echo
  # The full filtered stream can be thousands of lines; keep a generous tail but
  # never truncate the head, because the ORDER of the first occurrences is the
  # whole point of this capture.
  FILT_TOTAL="$(grep -icE "$FILT_RE" "$TMPD/all.txt" 2>/dev/null)"
  echo "  matching lines in full buffer: ${FILT_TOTAL:-0}"
  echo
  echo "  -- FIRST 120 matching lines (chronological; where the story starts) --"
  grep -iE "$FILT_RE" "$TMPD/all.txt" 2>/dev/null | head -120 | sed 's/^/    /'
  echo
  echo "  -- LAST 200 matching lines (steady state) --"
  grep -iE "$FILT_RE" "$TMPD/all.txt" 2>/dev/null | tail -200 | sed 's/^/    /'
  echo
  echo "  -- PCS (com.google.android.apps.camera.services) lines only --"
  grep -iE 'camera\.services|pcs_connectivityclient|PCS' "$TMPD/all.txt" 2>/dev/null \
    | head -60 | sed 's/^/    /'
  echo
  echo "  -- gmscompat chain lines --"
  grep -iE 'GmsCompat|gmscompat|createPackageContext|NameNotFoundException' "$TMPD/all.txt" 2>/dev/null \
    | head -60 | sed 's/^/    /'
  echo
  echo "  -- proxy-camera / provider-binding lines --"
  grep -iE 'proxy camera IDs|Not bound to ICameraProvider|ICameraProvider|provider@2\.7|camera_provider|configureStreams' "$TMPD/all.txt" 2>/dev/null \
    | head -80 | sed 's/^/    /'

  # -------------------------------------------------------------------------
  echo
  echo "=== (h) AVC DENIALS NAMING camera OR gmscompat ==="
  # -------------------------------------------------------------------------
  AVC_DMESG="$(sh_dev 'dmesg' | grep -i avc | grep -iE 'camera|gmscompat')"
  echo "  -- dmesg | grep -i avc | grep -iE 'camera|gmscompat' --"
  echo "${AVC_DMESG:-    (none)}" | sed 's/^/    /'

  echo "  -- kernel buffer fallback (dmesg needs root on newer builds) --"
  AVC_KERN="$(grep -i avc "$TMPD/kernel.txt" 2>/dev/null | grep -iE 'camera|gmscompat')"
  echo "${AVC_KERN:-    (none)}" | sed 's/^/    /'

  echo "  -- all AVC denials in last 60 lines of kernel buffer (context) --"
  grep -i avc "$TMPD/kernel.txt" 2>/dev/null | tail -60 | sed 's/^/    /'

  echo "  -- camera-related SELinux booleans --"
  sh_dev 'cat /sys/fs/selinux/booleans 2>/dev/null' | grep -i camera | sed 's/^/    /'

  # -------------------------------------------------------------------------
  echo
  echo "=== (i) THE DISCRIMINATOR — ORDER OF PCS DEATH vs PROVIDER BINDING ==="
  #
  # The question this section must answer explicitly:
  #   does PCS die BEFORE any provider-binding attempt exists in the log,
  #   or does it die AFTER the provider has already failed to bind?
  #
  # Method: one awk pass over a threadtime-stamped snapshot. For each line we
  # compute a monotonic minute-resolution-agnostic key from the
  # "MM-DD HH:MM:SS.mmm" prefix, then keep the earliest key and text per class.
  #
  #   PCS class  — the PCS process dying / the GmsCompatLib init chain
  #   BIND class — an actual attempt to reach the camera provider or its
  #                extension proxy (tight regex: NOT generic "CameraService"
  #                chatter, which would otherwise match cameraserver startup and
  #                falsely "prove" a bind attempt)
  #
  # Classes are disjoint by construction; a line is attributed to PCS only if it
  # does not also look like a bind attempt.
  # -------------------------------------------------------------------------
  cat >"$TMPD/order.awk" <<'AWKPROG'
    BEGIN {
      PCSRE  = "camera\\.services|pcs_connectivityclient|GmsCompatLib|gmscompat\\.lib|createPackageContext|Unable to instantiate application"
      BINDRE = "provider@2\\.7|camera-provider-2-7|camera_provider|ICameraProvider|ICameraExtensionsProxyService|CameraExtensionsProxy|proxy camera IDs|proxy_camera|configureStreams|Not bound to"
      AMPRE  = "CameraService|cameraserver"

      haveP = 0; haveB = 0; haveA = 0
      np = 0; nb = 0; na = 0
    }
    {
      if (NF < 2) next
      ts = $1 " " $2
      if (ts !~ /^[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) next

      # Key = day-index*86400000 + hh*3600000 + mm*60000 + ss*1000 + mmm.
      # IMPORTANT: the fraction starts at offset 15 (the '.'), NOT 16. Reading
      # it at 16 yields "100" for .100 and "000" for .000, which is a
      # 100x-wrong sub-second term and silently inverts the comparison.
      frac = substr(ts, 15, 5)          # ".mmm"
      if (frac !~ /^\.[0-9][0-9][0-9]$/) frac = ".000"
      ms = substr(frac, 2, 3) + 0

      k = (((substr(ts,1,2)+0) * 31 + (substr(ts,4,2)+0)) * 24 * 60 * 60 \
           + (substr(ts,7,2)+0) * 3600 \
           + (substr(ts,10,2)+0) * 60 \
           + (substr(ts,13,2)+0)) * 1000 + ms

      isP = ($0 ~ PCSRE)
      isB = (!isP) && ($0 ~ BINDRE)
      isA = (!isP) && (!isB) && ($0 ~ AMPRE)

      if (isP) {
        np++
        if (!haveP || k < pk) { haveP = 1; pk = k; pt = ts; pl = $0 }
      } else if (isB) {
        nb++
        if (!haveB || k < bk) { haveB = 1; bk = k; bt = ts; bl = $0 }
      } else if (isA) {
        na++
        if (!haveA || k < ak) { haveA = 1; ak = k; at = ts; al = $0 }
      }
    }
    END {
      printf "    CLASS_COUNT_PCS        = %d\n", np
      printf "    CLASS_COUNT_BIND       = %d\n", nb
      printf "    CLASS_COUNT_AMBIENT    = %d\n", na

      if (haveP) {
        printf "    FIRST_PCS_TS           = %s\n", pt
        printf "    FIRST_PCS_LINE         = %s\n", pl
      } else {
        printf "    FIRST_PCS_TS           = (none)\n"
        printf "    FIRST_PCS_LINE         = (no PCS/GmsCompat line found in buffer)\n"
      }

      if (haveB) {
        printf "    FIRST_BIND_TS          = %s\n", bt
        printf "    FIRST_BIND_LINE        = %s\n", bl
      } else {
        printf "    FIRST_BIND_TS          = (none)\n"
        printf "    FIRST_BIND_LINE        = (no provider-binding attempt found in buffer)\n"
      }

      if (haveA) {
        printf "    FIRST_AMBIENT_TS       = %s\n", at
        printf "    FIRST_AMBIENT_LINE     = %s\n", al
      } else {
        printf "    FIRST_AMBIENT_TS       = (none)\n"
      }

      # ---- the actual comparison -------------------------------------------
      printf "    ORDER                  = "
      if (haveP && haveB) {
        if (pk < bk)      printf "PCS_BEFORE_BIND\n"
        else if (bk < pk) printf "BIND_BEFORE_PCS\n"
        else              printf "SAME_MILLISECOND\n"
      } else if (haveP && !haveB) {
        printf "BIND_NEVER_ATTEMPTED\n"
      } else if (!haveP && haveB) {
        printf "PCS_NEVER_LOGGED\n"
      } else {
        printf "NEITHER_PRESENT\n"
      }
    }
AWKPROG

  # Single source of truth: the verbose program above emits ORDER as one of its
  # fields, so the verdict cannot disagree with the printed audit trail.
  ORDER_TABLE="$(awk -f "$TMPD/order.awk" "$TMPD/all.txt" 2>/dev/null | grep -v '^$')"
  echo "$ORDER_TABLE"
  ORDER="$(echo "$ORDER_TABLE" | sed -n 's/^    ORDER *= *//p' | head -1)"
  [ -n "$ORDER" ] || ORDER="UNDETERMINED"

  # -------------------------------------------------------------------------
  echo
  echo "=== DERIVED FACTS (machine-greppable) ==="
  # -------------------------------------------------------------------------
  # ---- provider running? ---------------------------------------------------
  # Three independent witnesses, each with its own strength. The reason string
  # is printed so a reader can audit the inference instead of trusting a bool.
  PROVIDER_RUNNING="unknown"
  PROVIDER_RUNNING_WHY="no witness available"
  PROVIDER_SVC_PROP="$(sh_dev 'getprop init.svc.vendor.camera-provider-2-7-google')"

  if [ "$PROVIDER_SVC_PROP" = "running" ]; then
    PROVIDER_RUNNING="yes"
    PROVIDER_RUNNING_WHY="init.svc.vendor.camera-provider-2-7-google=running (authoritative)"
  elif echo "$PS_CAM" | grep -qE 'camera\.provider|camera_provider|provider@2|cameraserver'; then
    PROVIDER_RUNNING="yes"
    PROVIDER_RUNNING_WHY="provider/cameraserver process visible in ps -A"
  elif echo "$LSHAL_CAM" | grep -qiE 'camera\.provider'; then
    PROVIDER_RUNNING="yes"
    PROVIDER_RUNNING_WHY="lshal lists a camera.provider HAL (registered, implies live passthrough)"
  elif [ -n "$PROVIDER_SVC_PROP" ]; then
    PROVIDER_RUNNING="no"
    PROVIDER_RUNNING_WHY="init.svc.vendor.camera-provider-2-7-google=$PROVIDER_SVC_PROP (not 'running') and no process"
  elif [ -z "$PS_CAM" ] && [ -z "$LSHAL_CAM" ]; then
    PROVIDER_RUNNING="no"
    PROVIDER_RUNNING_WHY="property unset, no camera process in ps -A, and no camera HAL in lshal"
  else
    PROVIDER_RUNNING="unknown"
    PROVIDER_RUNNING_WHY="witnesses disagree; inspect sections (d) and (e) by hand"
  fi
  echo "  PROVIDER_RUNNING=$PROVIDER_RUNNING"
  echo "  PROVIDER_RUNNING_REASON=$PROVIDER_RUNNING_WHY"

  # camera disabled?
  CAM_DISABLED="no"
  if echo "$DIS_DUMP" | grep -qi camera; then CAM_DISABLED="yes"; fi
  echo "  CAMERA_DISABLED=$CAM_DISABLED"

  # PCS present on the image?
  PCS_PRESENT="no"
  if [ -n "$(sh_dev 'pm path com.google.android.apps.camera.services')" ]; then PCS_PRESENT="yes"; fi
  echo "  PCS_PRESENT=$PCS_PRESENT"

  # extension proxy package present?
  EXT_PRESENT="no"
  if [ -n "$(sh_dev 'pm path com.android.cameraextensions')" ]; then EXT_PRESENT="yes"; fi
  echo "  EXT_PROXY_PACKAGE_PRESENT=$EXT_PRESENT"

  # gmscompat lib present?
  GMSC_LIB="no"
  if [ -n "$(sh_dev 'pm path app.grapheneos.gmscompat.lib')" ]; then GMSC_LIB="yes"; fi
  echo "  GMSCCOMPAT_LIB_PRESENT=$GMSC_LIB"

  echo "  CAMERA_ID_COUNT=$CAM_ID_COUNT"
  echo "  ORDER=$ORDER"

  # -------------------------------------------------------------------------
  echo
  echo "=============================================================="
  echo " VERDICT"
  echo "=============================================================="

  # --- cause A --------------------------------------------------------------
  if [ "$ORDER" = "PCS_NEVER_LOGGED" ] && [ "$PCS_PRESENT" = "yes" ]; then
    echo "  CAUSE A (PCS -> GmsCompatLib NameNotFoundException):"
    echo "    NOT OBSERVED in this log window, though PCS is installed."
    echo "    Either PCS has not started since boot, or the crash buffer has"
    echo "    aged out. A live stream would be needed. Do not claim A is cleared."
  elif [ "$PCS_PRESENT" = "no" ]; then
    echo "  CAUSE A (PCS -> GmsCompatLib NameNotFoundException):"
    echo "    PCS is not installed on this image at all (pm path found nothing)."
    echo "    Cause A cannot be the blocker as described. Recorded as ABSENT,"
    echo "    not as disproven — verify against the crash buffer above."
  else
    echo "  CAUSE A (PCS -> GmsCompatLib NameNotFoundException):"
    echo "    CONSISTENT with the capture: PCS is installed, the GmsCompatLib"
    echo "    chain appears in section (g)/(f), and GMSCCOMPAT_LIB_PRESENT=$GMSC_LIB."
    echo "    See FIRST_PCS_TS above for when it happened."
  fi
  echo

  # --- cause B --------------------------------------------------------------
  echo "  CAUSE B (CameraExtensionsProxy absent -> no ICameraExtensionsProxyService"
  echo "           -> black preview):"
  echo "    extension proxy package present : $EXT_PRESENT"
  if echo "$SVC_DUMP" | grep -q 'ICameraExtensionsProxyService'; then
    echo "    ICameraExtensionsProxyService  : REGISTERED"
  else
    echo "    ICameraExtensionsProxyService  : NOT REGISTERED"
  fi
  echo "    camera provider running        : $PROVIDER_RUNNING"
  echo "    camera IDs seen by framework   : $CAM_ID_COUNT"
  if [ "$PROVIDER_RUNNING" = "yes" ] && [ "$CAM_ID_COUNT" -gt 0 ]; then
    echo "    >> the provider IS running AND the framework enumerates camera IDs."
    echo "       Cause B's stated mechanism (no provider -> black preview) does not"
    echo "       hold at this instant. B may still cause an extension-only failure,"
    echo "       but it is not 'no provider at all'."
  elif [ "$PROVIDER_RUNNING" = "no" ]; then
    echo "    >> the provider is NOT running on this boot, so cause B's premise is"
    echo "       LIVE here (it was only hypothetical for stallion)."
  elif [ "$PROVIDER_RUNNING" = "yes" ] && [ "$CAM_ID_COUNT" -eq 0 ]; then
    echo "    >> MIXED: the provider process is running but the framework enumerates"
    echo "       ZERO camera IDs. That is not a clean pass for B — a running provider"
    echo "       that exposes no devices is itself a fault. Do not score B as clear."
  else
    echo "    >> insufficient evidence to score B ($PROVIDER_RUNNING / $CAM_ID_COUNT)."
    echo "       Say so; do not guess."
  fi
  echo

  # --- ordering -------------------------------------------------------------
  echo "  ORDERING (the discriminator the card asked for):"
  case "$ORDER" in
    PCS_BEFORE_BIND)
      echo "    PCS dies BEFORE any provider-binding attempt appears in the log."
      echo "    => A precedes B in this boot. A is the first blocker."
      ;;
    BIND_BEFORE_PCS)
      echo "    A provider-binding attempt FAILS BEFORE PCS dies."
      echo "    => B precedes A in this boot. B is the first blocker, and A is a"
      echo "       second, independent failure stacked on top of it."
      ;;
    BIND_NEVER_ATTEMPTED)
      echo "    PCS dies and NO provider-binding attempt exists anywhere in the"
      echo "    buffer. The camera was never exercised, so B's symptom chain"
      echo "    could not have run. This capture CANNOT distinguish A from"
      echo "    'A plus a latent B' — it only shows A is active."
      echo "    Reason: nothing tried to bind the provider while logging was on."
      ;;
    PCS_NEVER_LOGGED)
      echo "    A provider-binding attempt exists but NO PCS/GmsCompat line does."
      echo "    => A is not evidenced in this window; B is."
      ;;
    SAME_MILLISECOND)
      echo "    Both first occur in the same millisecond — ordering is not"
      echo "    resolvable from this capture. Treat as cannot-distinguish."
      ;;
    NEITHER_PRESENT)
      echo "    Neither a PCS line nor a provider-binding attempt is present."
      echo "    The capture is VACUOUS for this question. Do not conclude"
      echo "    anything from it — extend the log window or reproduce."
      ;;
    *)
      echo "    ORDER could not be computed ($ORDER)."
      ;;
  esac
  echo
  # --- explicit A / B / BOTH verdict ----------------------------------------
  # Cause A is evidenced only by its literal signal: the GmsCompatLib lookup
  # failing inside PCS. Cause B is evidenced only by a real bind-failure line —
  # NOT merely by "the provider looks unhealthy", since an unhealthy provider
  # could be a downstream effect of A and would otherwise be double-counted.
  A_EVIDENCED="no"; B_EVIDENCED="no"

  if grep -qiE 'gmscompat\.lib not found|NameNotFoundException.*gmscompat|camera\.services.*Unable to instantiate' "$TMPD/all.txt" "$TMPD/crash.txt" 2>/dev/null; then
    A_EVIDENCED="yes"
  elif [ "$PCS_PRESENT" = "yes" ] && [ "$ORDER" = "PCS_BEFORE_BIND" ]; then
    A_EVIDENCED="yes"
  fi

  if grep -qiE 'Not bound to ICameraProvider|Unable to get proxy camera IDs|proxy_camera_provider.*(fail|error)|configureStreams.*(timeout|fail)|ICameraExtensionsProxyService.*(not found|unable)' "$TMPD/all.txt" 2>/dev/null; then
    B_EVIDENCED="yes"
  fi

  echo "  ---- A / B / BOTH ----"
  case "${A_EVIDENCED}:${B_EVIDENCED}" in
    yes:yes) VERDICT_AB="BOTH" ;;
    yes:no)  VERDICT_AB="A" ;;
    no:yes)  VERDICT_AB="B" ;;
    *)       VERDICT_AB="CANNOT_DISTINGUISH" ;;
  esac
  echo "  VERDICT_AB=$VERDICT_AB"
  echo "    A_EVIDENCED=$A_EVIDENCED (PCS dies on absent app.grapheneos.gmscompat.lib)"
  echo "    B_EVIDENCED=$B_EVIDENCED (a provider/extension-proxy bind failure was logged)"
  echo "    B_LATENT_PREMISE=$([ "$EXT_PRESENT" = "no" ] && echo 'yes (CameraExtensionsProxy absent)' || echo 'no (proxy package present)')"
  echo
  case "${A_EVIDENCED}:${B_EVIDENCED}" in
    yes:yes)
      if [ "$ORDER" = "BIND_BEFORE_PCS" ]; then
        echo "    VERDICT: BOTH — and B fires FIRST."
        echo "      The provider/extension bind fails before PCS dies, so fixing"
        echo "      only the GmsCompatLib crash would leave the camera broken."
      elif [ "$ORDER" = "PCS_BEFORE_BIND" ]; then
        echo "    VERDICT: BOTH — and A fires FIRST."
        echo "      Two independent blockers are live on this boot. Fixing A alone"
        echo "      is necessary but very likely not sufficient."
      else
        echo "    VERDICT: BOTH (ordering unresolved — $ORDER)."
      fi
      ;;
    yes:no)
      echo "    VERDICT: A."
      echo "      The GmsCompatLib/PCS failure is demonstrated; no provider bind"
      echo "      failure appears. B is at most a latent premise, not a measured"
      echo "      blocker on this boot."
      ;;
    no:yes)
      echo "    VERDICT: B."
      echo "      A provider/extension bind failure is demonstrated; the"
      echo "      GmsCompatLib/PCS failure is not in this window."
      ;;
    *)
      echo "    VERDICT: CANNOT DISTINGUISH YET."
      echo "      Neither cause's literal signal is present in this capture"
      echo "      (ORDER=$ORDER). Reasonable readings include: the camera was"
      echo "      never exercised since boot; or the ring buffer aged out."
      echo "      Do NOT infer a cause. Re-capture with a live stream while"
      echo "      launching the camera app, or extend the buffer."
      ;;
  esac
  echo
  echo "  What this capture does NOT show:"
  echo "    - It is a post-hoc dump, not a live stream. Lines older than the"
  echo "      buffer's ring capacity are gone; absence of a line is not proof."
  echo "    - No camera app was launched by this script (read-only contract)."
  echo "      B's user-visible symptom (black preview) therefore cannot appear."
  echo "    - dmesg may be root-gated; see the kernel-buffer fallback in (h)."

  echo
  echo "=============================================================="
  echo " capture complete at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo " saved to: $OUT"
  echo "=============================================================="
} 2>&1 | tee "$OUT"
