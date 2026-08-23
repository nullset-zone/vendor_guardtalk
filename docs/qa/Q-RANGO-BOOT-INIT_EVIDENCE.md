# Q-RANGO-BOOT-INIT Evidence

**Task:** Q-RANGO-BOOT-INIT  
**QA run:** 2026-08-02T14:19:29Z (build host; shell verify ~14:18–14:20 UTC)  
**Depends on:** T-RANGO-BOOT-INIT ✅ APPROVED (static CONDITIONAL GO; on-device HOLD)  
**Preserved Backend report:** `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-BOOT-INIT.md`

## Host stamp verify (`rango-20260802-141438` / MODE=stockinit)

| Check | Result |
|-------|--------|
| Stamp dir present | `releases/desktop-flash/rango-20260802-141438/` + `system.img` + `SHA256SUMS` + `README-FLASH-DESKTOP.md` |
| `debugfs dump` stamp `/system/bin/init` vs stock | **`init_stock_MATCH`** size **2771368** |
| `debugfs dump` stamp `/system/bin/apexd` vs stock | **`apexd_stock_MATCH`** size **1083368** |
| stamp apexd vs `132759` apexd | **MATCH** (stockapexd composition retained) |
| stamp init vs `132759` / `130756` init | **DIFFERS** (2771368 ≠ 2938144) — `init_vs_prior_DIFFERS_PASS` |
| stamp `/system/etc/init/apexd.rc` vs stock | **`apexd_rc_stock_MATCH`** |
| `debugfs … com.android.virt.apex` on `141438` | `File not found by ext2_lookup` |
| virt in `/system/apex` listing | none (`virt_ABSENT_PASS`) |
| SHA256SUMS `141438` | **22/22 OK** |
| Stamp README | `MODE=stockinit`; documents stock init graft; `REMOTE_BUILD_DIR=…/141438`; HOLD honesty |

## `rango-latest` policy (must stay `130756`)

```text
readlink -f releases/desktop-flash/rango-latest
→ .../releases/desktop-flash/rango-20260802-130756
latest_still_130756_PASS
PASS_not_141438_as_latest
PASS_not_fullgt
```

## `--link-latest` refuse (stockinit)

```text
MODE=stockinit ./vendor/guardtalk/scripts/stage-rango-release.sh --link-latest
→ ERROR: MODE=stockinit is a bisect stamp — refuse --link-latest (...)
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

## tokay / akita non-regress

| Asset | Result |
|-------|--------|
| `akita-latest` | → `akita-20260725-101434` |
| tokay stamp | `tokay-20260725-102506` present |
| `flash-tokay.sh` | present |

## Host E2E (independent — bisect stamp)

```text
BUNDLE=releases/desktop-flash/rango-20260802-141438 \
FASTBOOT=out/host/linux-x86/bin/fastboot \
bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
RESULT: passes=49  fails=0  warns=2
HOST E2E: PASS
DEVICE BOOT: HOLD
WARN: optional vendor_boot_diag.img absent; no adb/fastboot device
E2E_EXIT=0
bundle → rango-20260802-141438
```

Raw log: `/tmp/q-rango-boot-init-e2e.log`.

Also: `bash -n vendor/guardtalk/scripts/stage-rango-release.sh` → PASS.

## On-device

```text
adb devices → empty (List of devices attached, no serials)
fastboot → not usable / no device on this host
~/rango-dmesg-init*.txt → absent on build host
```

**HOLD** — build host has no USB device. Do **not** invent PASS.

### Operator flash plan (Mac) — critical path for this bisect

```bash
fastboot set_active a
cd ~/GuardTalk-flash
unset REMOTE_KEY_DIR
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-20260802-141438
DEVICE=rango ./flash-from-remote.sh
fastboot oem dmesg | tee ~/rango-dmesg-init-141438.txt
adb devices
```

Exact stamp: **`rango-20260802-141438`**.  
Confirm step 0 `build dir` ends with `rango-20260802-141438`.  
Do **not** unset `REMOTE_BUILD_DIR` (that would flash superseded durable `130756` via `rango-latest`).  
Do **not** flash fullgt.  
Do **not** use `rango-latest` for this bisect.

### Classification plan (if fail / no adb)

| Signal in `oem dmesg` / boot | Class | Meaning |
|-----------------------------|-------|---------|
| `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` ~18s | apexd-bootstrap residual | Stock **init** + stock apexd graft **insufficient**; next: `perform_apex_config`, hwasan native deps, SELinux early apex, `user` vs `userdebug` / VNDK |
| `KP: … exitcode=0x00007f00` | init kill | Historical path — note if returns after stock init graft |
| adb up + GuardTalk fingerprint (`ro.build.fingerprint` / product) | PASS | Live boot proof — **not observed this run** |
| Other / empty dmesg | UNKNOWN | Capture raw `oem dmesg`; do not invent class |

### Prior falsified (do not re-open as sole cause)

- `132759` stockapexd → FAIL `0xfc` ~18s
- `130756` novirt+stock named apexes → FAIL `0xfc` ~18s

## Queue drift note (MEDIUM)

Root `TASK_QUEUE.md` operator flash block had `REMOTE_BUILD_DIR=…/rango-STAMP` placeholder while `.agent-comm/TASK_QUEUE.md` correctly pinned `…/141438`. QA syncs root flash block to **`141438`** when updating status → REVIEW (same class as prior APEXD MEDIUM finding).

## Acceptance checklist (QA)

- [x] Stamp `141438` init `cmp` MATCH stock (2771368); apexd MATCH (1083368); init differs from `132759`/`130756` GT init
- [x] virt absent; `rango-latest` still `130756`; `--link-latest` refused for stockinit (exit 1)
- [x] Host E2E 49/0 on `BUNDLE=…/141438`; SHA256SUMS 22/22; no new `scripts/flash-*.sh`
- [x] On-device HOLD + `REMOTE_BUILD_DIR` flash plan (no invent PASS)
- [x] Evidence under `vendor/guardtalk/docs/qa/`
- [x] REPLACE `TO_ARCHITECT.md`; status → REVIEW only (never APPROVED)
- [x] Both queues synced to REVIEW (PROTOCOL Rule 18)
- [x] Gate -1 + Gate 5 executed; no Auditor dispatch; no git commit
