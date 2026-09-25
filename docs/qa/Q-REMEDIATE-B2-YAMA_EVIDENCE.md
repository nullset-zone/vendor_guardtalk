# QA Evidence — Q-REMEDIATE-B2-YAMA

**Task:** `Q-REMEDIATE-B2-YAMA` (independent rematch of `T-REMEDIATE-B2-YAMA` item 9 residual)  
**Date:** 2026-09-16T15:24:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B2-YAMA` Architect-APPROVED static (2026-09-16T15:17:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-005  
**Verdict:** **PASS (host static)** — YAMA live `Image.lz4` **HOLD**. On-device `/proc/sys` **HOLD**. **PASS HOLD remains.** Makefile-include **not required** (REJECTED path). **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion and Architect APPROVE were **not trusted**. Product source was not edited. No USB GO. No kernel `Image.lz4` rewrite. No `m`. No commit. `Q-ONDEVICE` not restarted. `Q-LMS` / `Q-APEX` / `Q-BOOTZIP` not started. Kernel suite script **not overwritten**.

GIP-0: Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Memory-bank **not** read/written (packet FORBIDDEN). Guardian MCP/HTTP not called. Gate 5 HUMAN SKIP.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `test ! -f device/google/caimito-kernels/6.1/Makefile` | **PASS** | ABSENT; also `test ! -e` |
| 2 | No Makefile / Android.mk / Android.bp / `*.mk` under that dir (maxdepth 3, ignore `.git`) | **PASS** | `find` print empty (`.git` symlink pruned) |
| 3 | `guardtalk-security-yama.config` still has `CONFIG_SECURITY_YAMA=y` | **PASS** | fragment line 20 |
| 4 | `REGEN_HOOKS.md` documents passing fragment to `scripts/kconfig/merge_config.sh` for **out-of-tree** rebuild | **PASS** | `vendor/guardtalk/device/komodo/REGEN_HOOKS.md` lines 61–89; forbids in-tree Makefile |
| 5 | Re-run `verify_remediate_b2_kernel_static.sh` EXIT 0 with YAMA live Image HOLD | **PASS** | 28 PASS / 8 HOLD / 0 FAIL EXIT=0; `YAMA_LIVE_IMAGE=HOLD` |
| 6 | Live `grapheneos/System.map` `__lsm_yama` ABSENT is **HOLD** not FAIL; do not invent PRESENT | **HOLD** | LSM = capability/selinux/safesetid/integrity; Image.lz4 mtime 2026-05-25 |
| 7 | adb empty HOLD; do not lift PASS HOLD; REVIEW only | **HOLD** | `adb devices` header only |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b2_yama_host.sh
# RESULT: PASS (host static)  PASS_COUNT=19 HOLD_COUNT=4 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# YAMA_LIVE_IMAGE=HOLD
# PROC_SYS=HOLD
# DEVICE=HOLD
# PASS_HOLD=remains
# MAKEFILE_INCLUDE_REQUIRED=false

bash vendor/guardtalk/docs/qa/verify_remediate_b2_kernel_static.sh
# RESULT: PASS (host static)  PASS_COUNT=28 HOLD_COUNT=8 FAIL=0 EXIT=0
# YAMA_LIVE_IMAGE=HOLD
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-YAMA_SUITE.out`  
Kernel nested log: `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B2-YAMA_KERNEL_SUITE.out`

`pytest platform/tests` N/A (AOSP prebuilt kernel dir / kconfig fragment / SOP, not Python platform).

## Independent rematch (do not trust T / Architect dumps)

### Makefile absent

```
test ! -f device/google/caimito-kernels/6.1/Makefile  # exit 0
test ! -e device/google/caimito-kernels/6.1/Makefile  # exit 0
```

`ls` of `device/google/caimito-kernels/6.1/`: `.git` (symlink, ignored), `grapheneos/`, `guardtalk-security-yama.config`, `README.guardtalk-trunk-14096387.md`, `trunk-14096387` → `grapheneos`. **No Makefile.**

`find` maxdepth 3, prune `.git`: empty. **PASS.**

### Fragment + SOP (not Makefile-include)

- Fragment still: `CONFIG_SECURITY_YAMA=y`
- `REGEN_HOOKS.md` § Out-of-tree kernel YAMA: pass fragment to `scripts/kconfig/merge_config.sh` **last**; kernel source is out-of-tree of this AOSP tree; do **not** add Makefile/Android.mk/Android.bp under `caimito-kernels/6.1/`
- Fragment refs: README, REGEN_HOOKS, PRODUCTION_HARDENING_POLICY — **no** Android.mk / Android.bp / Makefile include

### Live prebuilt Image HOLD

```
ffff80000a328cd0 d __lsm_capability
ffff80000a328d00 d __lsm_selinux
ffff80000a328d30 d __lsm_safesetid_security_init
ffff80000a328d60 d __lsm_integrity
```

`__lsm_yama` **ABSENT**. `Image.lz4` mtime **2026-05-25 09:26:07**; fragment mtime **2026-09-16 15:14:55**. Not treated as rebuilt. **HOLD.** Not invented PRESENT.

### Device

`adb devices`: empty list → **HOLD**. `LIVE_DEVICE_CLAIMED=false`. PASS HOLD **not** lifted. `Q-ONDEVICE` not started.

## Residuals (not FAIL of this rematch)

- Live YAMA compile-time until out-of-tree kernel rebuild replaces `Image.lz4` + `System.map`
- `m` not run; stale `out/komodo` init rc (KERNEL suite HOLD)
- Historical `verify_sec_p5_static.sh` paranoid 3 (not SoT)
- On-device `/proc/sys` → `Q-REMEDIATE-B2-ONDEVICE` (not restarted)

## Files created (QA only)

- `vendor/guardtalk/docs/qa/verify_remediate_b2_yama_host.sh`
- `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-YAMA_EVIDENCE.md`
- `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-YAMA_SUITE.out`
- `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B2-YAMA_KERNEL_SUITE.out`

`verify_remediate_b2_kernel_static.sh` **not** overwritten.
