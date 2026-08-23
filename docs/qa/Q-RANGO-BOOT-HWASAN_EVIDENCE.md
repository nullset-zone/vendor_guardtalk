# Q-RANGO-BOOT-HWASAN Evidence

**Task:** Q-RANGO-BOOT-HWASAN  
**QA run:** 2026-08-02T15:49:45Z (build host; shell verify ~15:47–15:49 UTC)  
**Depends on:** T-RANGO-BOOT-HWASAN ✅ APPROVED (static CONDITIONAL GO; on-device HOLD)  
**Preserved Backend report:** `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-BOOT-HWASAN.md`

## Host stamp verify (`rango-20260802-153335` / MODE=stockhwasan)

| Check | Result |
|-------|--------|
| Stamp dir present | `releases/desktop-flash/rango-20260802-153335/` + `system.img` + `SHA256SUMS` + `README-FLASH-DESKTOP.md` |
| `debugfs dump` stamp `/system/lib64/bootstrap/hwasan/libc.so` vs stock | **`hwasan_libc_stock_MATCH`** size **1674080** |
| stamp hwasan libc vs `150440` | **DIFFERS** (1674080 ≠ 1706096) — `hwasan_vs_150440_DIFFERS_PASS` (GT copy replaced) |
| stamp `/system/lib64/bootstrap/libclang_rt.hwasan-aarch64-android.so` vs stock | **`hwasan_rt_stock_MATCH`** size **1248776** |
| `debugfs dump` stamp `/system/bin/init` vs `150440` | **`init_vs_150440_MATCH_GT_RETAINED`** size **2938144** |
| stamp init vs stock | **DIFFERS** (2938144 ≠ 2771368) — `init_vs_stock_DIFFERS_PASS` |
| `debugfs dump` stamp `/system/bin/apexd` vs stock | **`apexd_stock_MATCH`** size **1083368** |
| `debugfs dump` stamp `/system/etc/init/hw/init.rc` vs stock | **`initrc_stock_MATCH`** size **57115** |
| stamp init.rc vs `150440` | **MATCH** (stockapexcfg composition retained) |
| `debugfs … com.android.virt.apex` on `153335` | `File not found by ext2_lookup` |
| virt in `/system/apex` listing | none (`virt_ABSENT_PASS`) |
| SHA256SUMS `153335` | **22/22 OK** |
| Stamp README | `MODE=stockhwasan`; GT init retained; stock hwasan libc; `REMOTE_BUILD_DIR=…/153335`; HOLD honesty; fail-class table |

Raw verify log: `/tmp/q-rango-boot-hwasan-verify.log`.

## `rango-latest` policy (must stay `130756`)

```text
readlink -f releases/desktop-flash/rango-latest
→ .../releases/desktop-flash/rango-20260802-130756
latest_still_130756_PASS
PASS_not_153335_as_latest
PASS_not_fullgt
```

## `--link-latest` refuse (stockhwasan)

```text
MODE=stockhwasan ./vendor/guardtalk/scripts/stage-rango-release.sh --link-latest
→ ERROR: MODE=stockhwasan is a bisect stamp — refuse --link-latest (...)
exit:1
link_latest_refuse_PASS
```

## Flash sprawl

```text
scripts/flash-*.sh + vendor/guardtalk/scripts/flash-*.sh → 5 files
KEEP only:
  scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote.sh
  vendor/guardtalk/scripts/flash-from-remote-signed.sh
  vendor/guardtalk/scripts/flash-signed.sh
  vendor/guardtalk/scripts/flash-tokay.sh
NEW_OR_UNEXPECTED: none
```

Flash fail messaging present: `0x00007f00` vs `0x00000100` vs `0xfc` vs `0xbaba`/mode `0x0`; `fastboot set_active a` reminder.

## tokay / akita non-regress

| Asset | Result |
|-------|--------|
| `akita-latest` | → `akita-20260725-101434` |
| tokay stamp | `tokay-20260725-102506` present |
| `flash-tokay.sh` | present |

## Host E2E (independent — bisect stamp)

```text
BUNDLE=releases/desktop-flash/rango-20260802-153335 \
FASTBOOT=out/host/linux-x86/bin/fastboot \
bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
RESULT: passes=49  fails=0  warns=2
HOST E2E: PASS
DEVICE BOOT: HOLD
WARN: optional vendor_boot_diag.img absent; no adb/fastboot device
E2E_EXIT=0
bundle → rango-20260802-153335
```

Raw log: `/tmp/q-rango-boot-hwasan-e2e.log`.

Also: `bash -n vendor/guardtalk/scripts/stage-rango-release.sh` + both `flash-from-remote.sh` → PASS.

## On-device

```text
adb devices → empty (List of devices attached, no serials)
fastboot → host binary present but unused (no USB device)
~/rango-dmesg-hwasan*.txt → absent on build host
```

**HOLD** — build host has no USB device. Do **not** invent PASS.

### Operator flash plan (Mac) — critical path for this bisect

```bash
fastboot set_active a
cd ~/GuardTalk-flash
scp openstatestack@192.168.1.4:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/scripts/flash-from-remote.sh \
  ~/GuardTalk-flash/flash-from-remote.sh && chmod +x ~/GuardTalk-flash/flash-from-remote.sh
unset REMOTE_KEY_DIR
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-20260802-153335
DEVICE=rango ./flash-from-remote.sh
fastboot oem dmesg | tee ~/rango-dmesg-hwasan-153335.txt
adb devices
```

Exact stamp: **`rango-20260802-153335`**.  
Confirm step 0 `build dir` AND `key dir` both end with `rango-20260802-153335`.  
Do **not** unset `REMOTE_BUILD_DIR` (that would flash durable `130756` via `rango-latest`).  
Do **not** flash fullgt.  
Do **not** use `rango-latest` for this bisect.  
Slot A may be drained — **`fastboot set_active a` first**.

### Classification plan (if fail / no adb)

| Signal in `oem dmesg` / boot | Class | Meaning |
|-----------------------------|-------|---------|
| `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` ~18s | apexd-bootstrap residual | Stock **hwasan libc** graft (on stockapexcfg base) **insufficient**; next residual probes |
| `KP: … exitcode=0x00000100` / `0xbaba` / mode `0x0` ~61s | init exit status 1 | Same class as `141438` stockinit |
| `KP: … exitcode=0x00007f00` | init/exec kill (status 127) | Historical path — note if returns |
| adb up + GuardTalk fingerprint (`ro.build.fingerprint` / product) | PASS | Live boot proof — **not observed this run** |
| Other / empty dmesg | UNKNOWN | Capture raw `oem dmesg`; do not invent class |

### Prior falsified (do not re-open as sole cause)

- `130756` novirt+stock named apexes → FAIL `0xfc` ~18s
- `132759` stockapexd → FAIL `0xfc` ~18s
- `141438` stockinit → FAIL KP `0x00000100` ~61s — **stock-init-sole FALSIFIED**
- `150440` stockapexcfg → FAIL `0xfc` ~18s — **stock-init.rc-sole / stockapexcfg-sole FALSIFIED**

## Acceptance checklist (QA)

- [x] Stamp `153335` hwasan libc stock MATCH (1674080); DIFFERS `150440` GT (1706096); GT init retained (2938144); init.rc stock MATCH (57115); apexd stock MATCH (1083368)
- [x] virt absent; `rango-latest` still `130756`; `--link-latest` refused for stockhwasan (exit 1)
- [x] Host E2E 49/0 on `BUNDLE=…/153335`; SHA256SUMS 22/22; no new `scripts/flash-*.sh`
- [x] On-device HOLD + Mac flash plan with `set_active a` + `REMOTE_BUILD_DIR=…/153335` + classify `0xfc` vs `0x00000100` vs `0x7f00` (no invent PASS)
- [x] Evidence under `vendor/guardtalk/docs/qa/`
- [x] REPLACE `TO_ARCHITECT.md`; status → REVIEW only (never APPROVED)
- [x] Both queues synced to REVIEW (PROTOCOL Rule 18)
- [x] Gate -1 + Gate 5 executed; no Auditor dispatch; no git commit
