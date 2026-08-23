# Q-RANGO-BOOT-FINAL Evidence

**Task:** Q-RANGO-BOOT-FINAL  
**QA run:** 2026-08-02T13:13:24Z (build host)  
**Depends on:** T-RANGO-BOOT-FINAL ✅ APPROVED (static; on-device HOLD)  
**Preserved Backend report:** `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-BOOT-FINAL.md`

## Host stamp verify (`rango-latest` → `rango-20260802-130756`)

| Check | Result |
|-------|--------|
| `readlink -f …/rango-latest` | `…/releases/desktop-flash/rango-20260802-130756` |
| latest basename | `rango-20260802-130756` (not fullgt, not `130338`) |
| `debugfs … com.android.virt.apex` | `File not found by ext2_lookup` |
| virt in `/system/apex` listing | none (`PASS_virt_absent_in_ls`) |
| tzdata Size `130756` | **921600** |
| tzdata Size `123756` (GT kept) | **962560** |
| tzdata size assert | `921600 ≠ 962560` → stock graft (`PASS_tzdata_size_diff_stock_graft`) |
| runtime Size `130756` / `123756` | **8814592** / **8814592** (match stock) |
| i18n Size `130756` / `123756` | **37842944** / **37842944** (match stock) |
| SHA256SUMS | **22/22 OK** |
| Stamp README | `README-FLASH-DESKTOP.md` present (documents novirt + stock tzdata/runtime/i18n; HOLD honesty) |

## `rango-latest` policy

```text
readlink -f releases/desktop-flash/rango-latest
→ .../releases/desktop-flash/rango-20260802-130756
PASS_is_130756
PASS_not_fullgt
PASS_name_not_fullgt
```

Superseded `rango-20260802-130338` exists on disk but is **not** linked as latest (do not flash).

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
| `akita-latest` | → `akita-20260725-101434` + SHA256SUMS present |
| tokay stamps | `tokay-20260725-102506`, `tokay-20260724-152717` present + SHA256SUMS |
| `desktop-flash/latest` | → `tokay-20260725-102506` (pre-existing tokay convention; no `tokay-latest` symlink) |
| `flash-tokay.sh` | present |
| QA port evidence docs | `Q-PORT-AKITA_EVIDENCE.md`, `Q-PORT-RANGO_EVIDENCE.md` present |
| Stamp mtimes | tokay/akita dirs unchanged Jul 24–25 (rango stage did not rewrite them) |

## Host E2E (independent)

```text
FASTBOOT=out/host/linux-x86/bin/fastboot bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
RESULT: passes=49  fails=0  warns=2
HOST E2E: PASS
DEVICE BOOT: HOLD
WARN: optional vendor_boot_diag.img absent; no adb/fastboot device
E2E_EXIT=0
```

E2E targets `rango-latest` → `130756` (correct — durable FINAL latest).  
Raw log: `/tmp/q-rango-boot-final-e2e.log`.

## On-device

```text
adb devices → empty (List of devices attached, no serials)
~/rango-dmesg-final.txt → absent
```

**HOLD** — build host has no USB device. Do **not** invent PASS.

### Operator flash plan (Mac) — critical path

```bash
fastboot set_active a
cd ~/GuardTalk-flash
unset REMOTE_BUILD_DIR REMOTE_KEY_DIR
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
DEVICE=rango ./flash-from-remote.sh
fastboot oem dmesg | tee ~/rango-dmesg-final.txt
adb devices
```

Exact stamp: **`rango-20260802-130756`** (`readlink -f …/rango-latest`).  
Do **not** flash `130338` or any `rango-fullgt-*`.

### Classification plan (if fail / no adb)

| Signal in `oem dmesg` / boot | Class | Meaning |
|-----------------------------|-------|---------|
| `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` ~18s | apexd-bootstrap residual | Same class as `123756`/`111004`/`103641` — tzdata graft **insufficient**; next: stock `apexd` / bootstrap re-scan / `user` vs `userdebug` / VNDK |
| `KP: … exitcode=0x00007f00` | init kill | Historical path (not current primary) |
| adb up + GuardTalk fingerprint (`ro.build.fingerprint` / product) | PASS | Live boot proof — **not observed this run** |
| Other / empty dmesg | UNKNOWN | Capture raw `oem dmesg`; do not invent class |

## Acceptance checklist (QA)

- [x] `rango-latest` → `130756`, not fullgt; virt absent; tzdata Size ≠ `123756` (`921600` ≠ `962560`)
- [x] Host E2E 49/0; no new `scripts/flash-*.sh`; tokay/akita stamps+docs OK
- [x] On-device HOLD + `oem dmesg` classification plan (no invent PASS)
- [x] Evidence under `vendor/guardtalk/docs/qa/`
- [x] REPLACE `TO_ARCHITECT.md`; status → REVIEW only (never APPROVED)

## LOW notes (non-blocking)

- Stamp README tee path still says `~/rango-dmesg-deep.txt`; dispatch/operator path is `~/rango-dmesg-final.txt` (doc drift only).
- No `tokay-latest` symlink (pre-existing: `latest` → tokay stamp); not introduced by FINAL.
