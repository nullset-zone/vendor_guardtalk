# Q-RANGO-BOOT-APEX Evidence

**Task:** Q-RANGO-BOOT-APEX  
**QA run:** 2026-08-02T12:42:44Z (build host)  
**Depends on:** T-RANGO-BOOT-APEX ✅ APPROVED (static; on-device HOLD)  
**Preserved Backend report:** `.agent-comm/inbox/TO_ARCHITECT_T-RANGO-BOOT-APEX.md`

## Host stamp verify (`rango-20260802-123756`)

| Check | Result |
|-------|--------|
| Stamp present | YES (`releases/desktop-flash/rango-20260802-123756/`) |
| `debugfs … com.android.virt.apex` | `File not found by ext2_lookup` |
| virt in `/system/apex` listing | none |
| runtime Size `123756` | **8814592** |
| runtime Size `111004` | **5222400** (differs — stock graft) |
| i18n Size `123756` | **37842944** |
| i18n Size `111004` | **20779008** (differs — stock graft) |
| tzdata on `123756` | present (`com.android.tzdata.apex` 962560 — GT kept) |
| SHA256SUMS | **22/22 OK** EXIT=0 |

## `rango-latest` policy

```text
readlink -f releases/desktop-flash/rango-latest
→ .../releases/desktop-flash/rango-20260802-111004
PASS_still_111004
PASS_not_123756
PASS_not_fullgt
```

Bisect stamp is **not** promoted. Flash path for operator must use `REMOTE_BUILD_DIR`.

## `--link-latest` refuse (`MODE=novirtstockapex`)

```text
MODE=novirtstockapex ./vendor/guardtalk/scripts/stage-rango-release.sh --link-latest
[stage:novirtstockapex] ERROR: MODE=novirtstockapex is a bisect stamp — refuse --link-latest (fold into MODE=gtuserspace only after on-device PASS)
exit:1
```

Spot-check also: `MODE=stockbootstrap --link-latest` → exit:1.

## Host E2E (independent)

```text
FASTBOOT=out/host/linux-x86/bin/fastboot bash vendor/guardtalk/docs/qa/e2e_rango_flash_local.sh
RESULT: passes=49  fails=0  warns=2
HOST E2E: PASS
DEVICE BOOT: HOLD
WARN: optional vendor_boot_diag.img absent; no adb/fastboot device
E2E_EXIT=0
```

E2E targets `rango-latest` → `111004` (correct — latest not promoted).  
Raw log: `/tmp/q-rango-boot-apex-e2e.log`.

### Bisect path (not exercised by E2E against latest)

```bash
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-20260802-123756
DEVICE=rango ./flash-from-remote.sh
```

Stamp README documents the same `REMOTE_BUILD_DIR` flow.

## On-device

```text
adb devices → empty (List of devices attached, no serials)
PATH fastboot → not installed (host uses out/host/linux-x86/bin/fastboot for E2E)
~/rango-dmesg-apex.txt → absent (no operator capture for 123756 yet)
```

**HOLD** — build host has no USB device. Do **not** invent PASS.

### Operator flash plan (Mac) — critical path

```bash
fastboot set_active a
cd ~/GuardTalk-flash
unset REMOTE_KEY_DIR
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-20260802-123756
DEVICE=rango ./flash-from-remote.sh
fastboot oem dmesg | tee ~/rango-dmesg-apex.txt
```

### Classification (if fail)

| Signal in `oem dmesg` | Class | Meaning |
|----------------------|-------|---------|
| `Reboot mode: 0xfc` / `reboot bootloader` / `bootstrap-apexd-failed` | apexd-bootstrap residual | Same class as `111004`/`103641` |
| `KP: … exitcode=0x00007f00` | init kill | Historical path |
| adb up + GuardTalk fingerprint | PASS | Live boot proof — **not observed this run** |

## Acceptance checklist (QA)

- [x] Host verify stamp: virt absent; runtime/i18n sizes ≠ `111004`
- [x] `rango-latest` still `111004` (not `123756`, not fullgt)
- [x] `MODE=novirtstockapex --link-latest` refused (exit 1)
- [x] Host E2E 49/0; note latest still 111004; bisect path documented
- [x] On-device HOLD + operator `REMOTE_BUILD_DIR` flash plan
- [x] Evidence note under `vendor/guardtalk/docs/qa/`
- [x] REPLACE `TO_ARCHITECT.md`; status → REVIEW only (never APPROVED)
