# T-REMEDIATE-B6-FLASH-SOP — Evidence (parity + capture)

- **Task:** `T-REMEDIATE-B6-FLASH-SOP` (merged `…-FLASH-PARITY` + `…-DEBUG-CAPTURE`)
- **Role:** AEGIS Backend Engineer (Panel 2)
- **DEC:** `DEC-REMEDIATE-019`
- **Authority:** owner-root `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md`
- **Repository:** `grapheneos-worktree`
- **Date:** 2026-09-19
- **Device in scope:** Pixel 9 Pro XL **komodo** (`54111FDAS000GN`), unlocked, `ro.boot.verifiedbootstate=orange`
- **USB_GO:** false · **FLASH_READY:** false · **commit:** none
- **Gate -1:** in-process only. Loaded `.aegis/governance/` (24 laws + 11 gates,
  `gate_neg1_guardian_first.yaml`). No `aegis-verifier` / `ask_guardian` /
  `gate_enforcer` MCP. Governance loaded = true, scope confirmed = true,
  authority resolved = true.
- **Status:** REVIEW only (never APPROVED).

## Files touched

| File | Change |
|------|--------|
| `scripts/flash-from-remote.sh` | header docs + opt-in capture (`CAPTURE_LOGS`, `CAPTURE_POST_ADB_SECS`) + post-adb fallback watch |
| `vendor/guardtalk/scripts/flash-from-remote.sh` | byte-identical copy (`cmp -s` IDENTICAL; sha256 equal) |
| `vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` | documents the capture flag |
| `vendor/guardtalk/docs/qa/verify_remediate_b6_flash_sop_host.sh` | new host harness (stubs fastboot/adb/ssh/scp) |
| `vendor/guardtalk/docs/qa/T-REMEDIATE-B6-FLASH-SOP_SUITE.out` | raw harness output |
| `vendor/guardtalk/docs/qa/T-REMEDIATE-B6-FLASH-SOP_EVIDENCE.md` | this file |

No product file outside the listed targets was edited. `doctrine/`,
`governance/laws/`, `governance/gates/`, `releases/desktop-flash/komodo-latest`,
`vendor/guardtalk/sepolicy/`, `vendor/guardtalk/device/` were not touched.

---

## Part 1 — GrapheneOS `flash-all` parity (komodo)

Canonical sources (in-tree, the files that **write** `flash-all.sh` / `flash-all.bat`):

- `device/common/generate-factory-images-common.sh` — the generator ("GOS-gen" below).
- `script/generate-release.sh` — per-device firmware flags ("GOS-rel" below).
- Official docs: https://grapheneos.org/install/cli (minimum fastboot, `flash-all.sh`,
  "do not skip, reorder, or add steps"). Public GrapheneOS process for the
  signed factory image.

Verdicts: `PASS` = matches the SOP (or an intentional, documented GuardTalk delta);
`HOLD` = convergent but unverifiable on this host; `FAIL` = proven regression.

| # | GuardTalk step (script line) | GrapheneOS `flash-all` step (source line) | Verdict | Basis |
|---|------------------------------|--------------------------------------------|---------|-------|
| 1 | fastboot ≥ 35.0.1 gate — `require_fastboot_min_version` (L144) | `MIN_FASTBOOT_VERSION_STR="35.0.1"` + version check (GOS-gen L98–99, L150–158) | **PASS** | Same minimum; script parses major/minor/patch and `die`s below it. |
| 2 | product/target fail-closed — `detect_product_fastboot` + `FB_NORM != FLASH_DEVICE` check (L564–580) | `fastboot getvar product` must equal `$DEVICE` (GOS-gen L162–169) | **PASS** | Script normalizes and `die`s on mismatch (stricter). |
| 3 | dual-slot bootloader `--slot=other` dance — `flash_bootloader_ab_both_slots` (L351–370) | `flash --slot=other` → `--set-active=other` → reboot → repeat (GOS-gen L193–198) | **PASS** | Two passes, `--slot=other` + `set-active=other` each, reboot between. |
| 4 | reboot-bootloader after bootloader pass 2 (L371–375) | `reboot-bootloader` + `sleep` (GOS-gen L207–208) | **PASS** | `wait_for_fastboot` (poll) replaces `sleep 5` — stricter, not a skip. |
| 5 | radio + `reboot-bootloader` (L723–728) | `flash radio` + `reboot-bootloader` (GOS-gen L213–215) | **PASS** | Single radio, no `radio-cdma` (komodo has none). |
| 6 | `erase avb_custom_key` → `flash avb_custom_key avb_pkmd.bin` (L734–753) | `erase avb_custom_key` → `flash avb_custom_key avb_pkmd.bin` (GOS-gen L229–230) | **PASS** | Same order: after radio, before OS images. `avb_pkmd.bin` bundled (GOS-gen L92–94). |
| 7 | `oem uart disable` (L394) | `oem uart disable` (GOS-gen L236; enabled by GOS-rel L64) | **PASS** | komodo is in the `DISABLE_UART=true` branch (GOS-rel L61–66). |
| 8 | `erase fips` (L396) | `erase fips` (GOS-gen L256; enabled by GOS-rel L65) | **PASS** | komodo is in the `DISABLE_FIPS=true` branch (GOS-rel L61–66). |
| 9 | `erase dpm_a` + `erase dpm_b` (L398–401) | `erase dpm_a` + `erase dpm_b` (GOS-gen L262–263; enabled by GOS-rel L66) | **PASS** | komodo is in the `DISABLE_DPM=true` branch. |
| 10 | (absent) | `erase apdp_a/b`, `erase msadp_a/b` (GOS-gen L239–251) | **PASS** | `ERASE_APDP` / `ERASE_MSADP` are **not** set for komodo in GOS-rel → correctly omitted. |
| 11 | wipe — `erase userdata` (L763–765) (+ `erase metadata` L766) | `fastboot -w --skip-reboot update …` — `-w` wipes userdata (GOS-gen L267) | **PASS** | `erase userdata` matches `-w`. Explicit `erase metadata` is an intentional GuardTalk first-boot extra (documented, additive). |
| 12 | fastbootd logical flash — `reboot fastboot` → `is-userspace=yes` → `flash super` **or** `wipe-super` + 6 logicals (L779–1170) | `update image.zip` internally reboots to fastbootd and writes logical partitions (GOS-gen L267) | **PASS** | **Intentional divergence:** no factory zip is shipped, so the fastbootd step is explicit. Same mechanism, same slot. |
| 13 | boot chain — `boot/init_boot/vendor_boot/vendor_kernel_boot/pvmfw` + `dtbo` to target slot (L1173–1185) | `update image.zip` writes the same physical images (GOS-gen L267) | **PASS** | **Intentional divergence:** explicit per-image flash (no zip). |
| 14 | single vbmeta pass with `--disable-verity --disable-verification` (L1188–1201) | `update` writes vbmeta once with the image set (GOS-gen L267) — **without** disable flags | **PASS** | **Intentional divergence:** `userdebug` + `test-keys` → disable-verity/verification required. Exactly one pass for komodo (no mid-sequence duplicates). |
| 15 | final `reboot` to Android then boot watch (L1208–1217) | `reboot-bootloader` + `sleep` (GOS-gen L268–269) | **PASS** | **Intentional divergence:** script reboots to Android to verify the boot. |
| 16 | boot verification gap (L1217+) — **patched this task** | `flash-all` ends at reboot; no boot verification | **PASS (intentional + patched)** | The watch used to stop at first adb (~30s) and print "flash complete", missing the later → fastboot fallback. Now opt-in `CAPTURE_LOGS=1` keeps watching and records it. Default path unchanged. |
| 17 | no bootloader re-lock | Public process requires `fastboot flashing lock` after `flash-all` | **PASS (intentional)** | GuardTalk debug sidecar is unlocked/`userdebug`. Documented GuardTalk delta (prior audit HIGH-1). Not a factory install; never presented as one. |

### Required-coverage checklist

- [x] dual-slot bootloader `--slot=other` dance → row 3
- [x] radio + `reboot-bootloader` → row 5
- [x] `erase avb_custom_key` → `flash avb_custom_key avb_pkmd.bin` → row 6
- [x] `oem uart disable` → row 7
- [x] `erase fips` / `erase dpm_a` / `erase dpm_b` (komodo family) → rows 8–9
- [x] wipe → row 11
- [x] fastbootd logical flash → row 12
- [x] boot chain → row 13
- [x] single vbmeta pass with `--disable-verity --disable-verification` → row 14

### Divergences: patched vs. left intentional

**Patched (proven):**

1. **Premature success / missed fallback (rows 15–16).** The boot watch
   `break`s at the first adb `device` and reports `flash complete`, so a later
   G-logo → fastboot fallback (**the observed failure**) is invisible. Fixed by
   the opt-in capture path: under `CAPTURE_LOGS=1` the watch keeps running for
   `CAPTURE_POST_ADB_SECS` after adb first appears, records the fallback, and
   exits with the boot-failure code. **Default path is unchanged.**

**Left intentional (labelled, not `FAIL`):**

- No factory zip / no `super.img` dependency → explicit fastbootd + logical path (rows 12–13).
- `--disable-verity --disable-verification` on the single vbmeta pass (row 14) — required for `userdebug`/`test-keys`.
- Explicit `erase metadata` (row 11) — first-boot defaults (launcher overlay / SUW).
- No bootloader re-lock (row 17) — GuardTalk debug sidecar.
- rango-only stock rescue boot + `auto_harvest_on_failure` (rango path; not exercised for komodo).
- `init.insmod.<device>.cfg` adb insurance push (akita/komodo/rango) — **GrapheneOS never adb-pushes this**; it is baked into `vendor_dlkm.img`. Non-fatal, post-boot only.

**No SOP-prefix divergence was proven** (rows 3–10, the firmware/bootloader/key
prefix) → **no command-order patch was applied.** Editing a matching sequence
would violate minimal-footprint (Law 6).

---

## Part 2 — Opt-in post-flash debug capture

**Flag:** `CAPTURE_LOGS` — **default `0` (off)**, canonical name
`CAPTURE_LOGS=1` to enable. Tuning: `CAPTURE_POST_ADB_SECS` (default `120`),
only honoured when `CAPTURE_LOGS=1`.

**Guarantees**

- Default (`CAPTURE_LOGS` unset/0): identical command order, identical exit
  codes. Proven by the harness "default run" assertions (no capture dir, no
  fallback record, exit 0, `flash complete`).
- Every capture step is best-effort: `capture_run` redirects and returns 0;
  a failure logs `WARNING` and never `die`s (Law 3 / Law 9). Proven by the
  "dead adb" run (exit 3, zero `FATAL`).
- Writes a timestamped evidence dir and prints it:
  `<LOCAL_WORK_DIR>/flash-capture-<device>-<YYYYmmdd-HHMMSS>/`.
- Keeps watching **after** adb first appears so the real failure mode
  (adb → fastboot fallback) is recorded.

**Coverage**

| Transport | Captured |
|-----------|----------|
| fastboot/bootloader | `oem dmesg`; `oem bcd read {command,status,recovery,stage}`; `getvar slot-retry-count:a` / `slot-unbootable:a` (and `:b`); `getvar all`; `fastboot devices` |
| adb/Android | `logcat -d` (full + `*:E` errors-only); `getprop` key subset + full; `dumpsys activity exit-info` / `lastanr` / `dumpsys -l`; `/sys/fs/pstore/*` (`ls` + `console-ramoops-0`, `dmesg-ramoops-0`, `pmsg-ramoops-0`) where reachable |

logcat is captured **before** any adbd reset so the interesting window is not
lost; pstore is attempted after (best-effort, no `adb root` side effects during
the watch).

---

## Verification results

```
bash -n scripts/flash-from-remote.sh                              → OK
bash -n vendor/guardtalk/scripts/flash-from-remote.sh             → OK
cmp -s scripts/... vendor/...                                     → IDENTICAL
sha256(scripts)  = 2749e61f15a15f6ab81e667abdb2feca591f487cb388c1cced3af80c67b88439
sha256(vendor)   = 2749e61f15a15f6ab81e667abdb2feca591f487cb388c1cced3af80c67b88439
bash -u -c 'set -euo pipefail; f(){ echo "$#"; }; f'              → 0 (no unbound-array abort)
harness verify_remediate_b6_flash_sop_host.sh                     → PASS=16 FAIL=0, exit 0
```

Harness coverage (raw output: `T-REMEDIATE-B6-FLASH-SOP_SUITE.out`):

- empty-array / `extra[@]` regression guard (macOS bash 3.2 + `set -u`)
- default run: `flash complete`, no capture dir, no fallback record
- `CAPTURE_LOGS=1`: post-adb fallback recorded; timestamped dir; fastboot + adb files present
- flag is opt-in (`CAPTURE_LOGS` defaults to `0`)
- dead-adb capture run: no `FATAL`

## Residual HOLDs / notes (not patched)

- **No on-device run** (no USB from this host). The capture is statically and
  stubbily proven; on-device confirmation is for the operator / `Q-*` pair.
- `KOMODO_DEBUG_FLASH.md` shows `komodo-debug-latest → komodo-debug-20260918-180338`
  while the DEC-019 tick-0 rematch recorded `→ komodo-debug-20260919-080101`.
  Out of this task's scope; not edited here. Flagged for Architect.
- Pre-existing: if `LOCAL_WORK_DIR` does not exist, the Step-0b `find | wc`
  pipeline fails under `pipefail` and aborts with exit 1 (no `FATAL` line).
  Unrelated to parity; defaults to `.` and is not a SOP divergence. Observation
  only — not patched (Law 6).
- Stale comment at `scripts/flash-from-remote.sh` (vbmeta force re-download)
  claims the root vbmeta is used for all three partitions, but
  `flash_vbmeta_partition` maps to per-partition files (correct behaviour).
  Documentation nit only; not patched.

## Gate 5 (Ultimate Critique) — self-score

**Score: 94%.** AC met (parity table with per-step citations; only the one
proven divergence patched; opt-in flag default off; dual-transport capture;
timestamped dir printed; post-adb fallback recorded; docs in header + note;
bash 3.2 safe; `cmp`/`bash -n` pass). Scope held; no USB; no commit; no
invented `FLASH_READY`/USB GO. Deductions: no on-device confirmation
(host-only), and the two residual documentation nits above.
