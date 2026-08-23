# Q-RANGO-BOOT-DEEP Evidence

**Task:** Q-RANGO-BOOT-DEEP  
**QA run:** 2026-08-02 (build host)  
**Depends on:** T-RANGO-BOOT-DEEP ✅ APPROVED (static; on-device HOLD)

## Host E2E (independent)

```text
FASTBOOT=out/host/linux-x86/bin/fastboot bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
RESULT: passes=49  fails=0  warns=2
HOST E2E: PASS
DEVICE BOOT: HOLD
WARN: optional vendor_boot_diag.img absent; no adb/fastboot device
E2E_EXIT=0
```

Raw log: `/tmp/q-rango-boot-deep-e2e.log` (session artifact).

## Stamp / virt.apex

| Check | Result |
|-------|--------|
| `readlink -f releases/desktop-flash/rango-latest` | `.../rango-20260802-111004` |
| fullgt linked as latest | **NO** (`PASS_not_fullgt`) |
| `debugfs … com.android.virt.apex` | `File not found by ext2_lookup` |
| virt in `/system/apex` listing | none |

## Negative matrix

| Check | Result |
|-------|--------|
| `scripts/flash-*.sh` | only `scripts/flash-from-remote.sh` |
| Experimental flash-* sprawl | absent (hybrid/diag/solution/final/etc.) |
| `rango-avbcontrol-20260801-072014` | present (`avbcontrol_ok`) |
| `rango-fullgt-20260801-072051` | exists as diagnostic; **not** `rango-latest` |

## On-device

```text
adb devices → empty (List of devices attached, no serials)
fastboot devices → empty
```

**HOLD** — build host has no USB device. Do **not** invent PASS.

### Operator capture plan (Mac)

```bash
fastboot set_active a
cd ~/GuardTalk-flash
unset REMOTE_BUILD_DIR REMOTE_KEY_DIR
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
DEVICE=rango ./flash-from-remote.sh
# On fail IMMEDIATELY:
fastboot oem dmesg | tee ~/rango-dmesg-deep.txt
```

### Classification (0x7f00 vs 0xfc)

| Signal in `oem dmesg` | Class | Meaning |
|----------------------|-------|---------|
| `KP: … exitcode=0x00007f00` | init kill | Historical / pre-apexd path |
| `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` | apexd-bootstrap | Named RC for DEEP sprint |
| adb up + GuardTalk fingerprint | PASS | Live boot proof |

Flash scripts already warn to classify both (`scripts/flash-from-remote.sh` ~863–871; vendor copy ~807–815). Stamp README: `README-FLASH-DESKTOP.md` on `111004`.
