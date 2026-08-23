# Q-RANGO-BOOT-APEXD Evidence

**Task:** Q-RANGO-BOOT-APEXD  
**QA run:** 2026-08-02T13:32:00Z (build host; shell verify ~13:31–13:33 UTC)  
**Depends on:** T-RANGO-BOOT-APEXD ✅ APPROVED (static; on-device HOLD)  
**Preserved Backend report:** `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-BOOT-APEXD.md`

## Host stamp verify (`rango-20260802-132759` / MODE=stockapexd)

| Check | Result |
|-------|--------|
| Stamp dir present | `releases/desktop-flash/rango-20260802-132759/` + `system.img` + `SHA256SUMS` + `README-FLASH-DESKTOP.md` |
| `debugfs dump` stamp `/system/bin/apexd` vs stock | **`apexd_stock_MATCH`** size **1083368** |
| stamp apexd vs `130756` apexd | **DIFFERS** (1083368 ≠ 1030416) — `apexd_vs_130756_DIFFERS_PASS` |
| `debugfs … com.android.virt.apex` on `132759` | `File not found by ext2_lookup` |
| virt in `/system/apex` listing | none (`virt_ABSENT_PASS`) |
| SHA256SUMS `132759` | **22/22 OK** |
| Stamp README | `MODE=stockapexd`; documents stock apexd graft; `REMOTE_BUILD_DIR=…/132759`; HOLD honesty |

## `rango-latest` policy (must stay `130756`)

```text
readlink -f releases/desktop-flash/rango-latest
→ .../releases/desktop-flash/rango-20260802-130756
latest_still_130756_PASS
PASS_not_132759_as_latest
PASS_not_fullgt
```

## `--link-latest` refuse (stockapexd)

```text
MODE=stockapexd ./vendor/guardtalk/scripts/stage-rango-release.sh --link-latest
→ ERROR: MODE=stockapexd is a bisect stamp — refuse --link-latest (...)
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
BUNDLE=releases/desktop-flash/rango-20260802-132759 \
FASTBOOT=out/host/linux-x86/bin/fastboot \
bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
RESULT: passes=49  fails=0  warns=2
HOST E2E: PASS
DEVICE BOOT: HOLD
WARN: optional vendor_boot_diag.img absent; no adb/fastboot device
E2E_EXIT=0
```

Raw log: `/tmp/q-rango-boot-apexd-e2e.log`.

Also: `bash -n vendor/guardtalk/scripts/stage-rango-release.sh` → PASS.

## On-device

```text
adb devices → empty (List of devices attached, no serials)
~/rango-dmesg-apexd.txt → absent on build host
```

**HOLD** — build host has no USB device. Do **not** invent PASS.

### Operator flash plan (Mac) — critical path for this bisect

```bash
fastboot set_active a
cd ~/GuardTalk-flash
unset REMOTE_KEY_DIR
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-20260802-132759
DEVICE=rango ./flash-from-remote.sh
fastboot oem dmesg | tee ~/rango-dmesg-apexd.txt
adb devices
```

Exact stamp: **`rango-20260802-132759`**.  
Do **not** unset `REMOTE_BUILD_DIR` (that would flash superseded durable `130756` via `rango-latest`).  
Do **not** flash fullgt.

### Classification plan (if fail / no adb)

| Signal in `oem dmesg` / boot | Class | Meaning |
|-----------------------------|-------|---------|
| `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` ~18s | apexd-bootstrap residual | Stock apexd graft **insufficient**; next: hwasan native deps / SELinux early apex / `perform_apex_config` / `user` vs `userdebug` / VNDK |
| `KP: … exitcode=0x00007f00` | init kill | Historical path (not current primary) |
| adb up + GuardTalk fingerprint (`ro.build.fingerprint` / product) | PASS | Live boot proof — **not observed this run** |
| Other / empty dmesg | UNKNOWN | Capture raw `oem dmesg`; do not invent class |

## Acceptance checklist (QA)

- [x] Stamp `132759` apexd `cmp` MATCH stock (1083368); differs from `130756` GT apexd (1030416)
- [x] virt absent; `rango-latest` still `130756`; `--link-latest` refused for stockapexd (exit 1)
- [x] Host E2E 49/0 on `BUNDLE=…/132759`; SHA256SUMS 22/22; no new `scripts/flash-*.sh`
- [x] On-device HOLD + `REMOTE_BUILD_DIR` flash plan (no invent PASS)
- [x] Evidence under `vendor/guardtalk/docs/qa/`
- [x] REPLACE `TO_ARCHITECT.md`; status → REVIEW only (never APPROVED)

## LOW notes (non-blocking)

- E2E banner still says “rango-latest” even when `BUNDLE` overrides — cosmetic; bundle path in step 0 log is correct (`132759`).
