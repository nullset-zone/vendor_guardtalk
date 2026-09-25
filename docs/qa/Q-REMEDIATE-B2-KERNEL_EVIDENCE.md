# QA Evidence — Q-REMEDIATE-B2-KERNEL

**Task:** `Q-REMEDIATE-B2-KERNEL` (independent rematch of `T-REMEDIATE-B2-KERNEL` **item 9**)  
**Date:** 2026-09-16T12:21:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B2-KERNEL` Architect-APPROVED static (2026-09-16T12:01:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-001  
**Verdict:** **PASS (host static)** — YAMA live `Image.lz4` **HOLD**. On-device `/proc/sys` **HOLD**. Stale `out/` **HOLD**. Historical P5 script **HOLD** (not SoT). **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. `verify_sec_p5_static.sh` was **not** used as source of truth (it still asserts paranoid **3**). No USB GO. No kernel `Image.lz4` rewrite. No commit. `Q-REMEDIATE-B2-ONDEVICE` / `Q-REMEDIATE-B2-EXCISE` / `Q-REMEDIATE-B2-TELEMETRY` were **not** started.

GIP-0: loaded `.memory-bank/` (activeContext, progress, decisions, projectBrief, systemPatterns, GUARDIAN_MANDATORY) and AGENTS.md + PROTOCOL/ROLES. Gate -1 in-process. Guardian MCP/HTTP not called (TOOL UNAVAILABLE). Gate 5 HUMAN SKIP.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | Independent rg: `perf_event_paranoid 2` in live init rc; no paranoid `3` in that rc | **PASS** | `init.guardtalk.hardening.rc` lines 29 + 37 write `2`; no `3` |
| 2 | `unprivileged_bpf_disabled 1` on **boot_completed only**; not late-init | **PASS** | stanza parse: bpf write only under `sys.boot_completed=1` (line 39) |
| 3 | `ptrace_scope 1` remains | **PASS** | late-init line 25 + boot_completed line 35 |
| 4 | `modules_disabled=1` must not be set | **PASS** | no `write` of modules_disabled; comment-only "intentionally NOT set" |
| 5 | `CONFIG_SECURITY_YAMA=y` in fragment | **PASS** | `guardtalk-security-yama.config` line 16 |
| 6 | Live `System.map` `__lsm_yama` ABSENT; do not invent rebuilt `Image.lz4` | **HOLD** | LSM set = capability/selinux/safesetid/integrity; Image.lz4 mtime 2026-05-25; fragment mtime 2026-09-16; fragment **not** Makefile-included |
| 7 | Device `/proc/sys` HOLD if adb empty; REVIEW only; never APPROVED | **HOLD / PASS** | `adb devices` header only; Q-ONDEVICE not started |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
bash vendor/guardtalk/docs/qa/verify_remediate_b2_kernel_static.sh
# RESULT: PASS (host static)  PASS_COUNT=28 HOLD_COUNT=8 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# YAMA_LIVE_IMAGE=HOLD
# PROC_SYS=HOLD
# DEVICE=HOLD
# P5_SCRIPT=HOLD (not SoT)
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B2-KERNEL_SUITE.out`

`pytest platform/tests` N/A (AOSP init rc / kernel fragment / System.map, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### Live init rc

File: `vendor/guardtalk/init/init.guardtalk.hardening.rc`

| Trigger | Sysctl write | Result |
|---------|--------------|--------|
| `on late-init` | `yama/ptrace_scope 1` | PASS |
| `on late-init` | `perf_event_paranoid 2` | PASS |
| `on late-init` | `unprivileged_bpf_disabled` | ABSENT (required — NetBpfLoad brick) |
| `on property:…sys.boot_completed=1` | `yama/ptrace_scope 1` | PASS |
| `on property:…sys.boot_completed=1` | `perf_event_paranoid 2` | PASS |
| `on property:…sys.boot_completed=1` | `unprivileged_bpf_disabled 1` | PASS (exactly one write) |

`perf_event_paranoid 3` **ABSENT** from live rc. **FAIL** criterion not triggered.

`write /proc/sys/kernel/modules_disabled` **ABSENT**. Comment documents it as intentionally not set.

Packaging: `vendor/guardtalk/init/Android.bp` `prebuilt_etc` + `guardtalk-feature-excised.mk` `PRODUCT_PACKAGES += init.guardtalk.hardening.rc`.

### YAMA fragment vs live prebuilt

- Fragment `device/google/caimito-kernels/6.1/guardtalk-security-yama.config` has `CONFIG_SECURITY_YAMA=y`.
- No `Android.mk` / `Android.bp` / `Makefile` / `*.mk` under `device/google/caimito-kernels/6.1`. Fragment is **not** Makefile-included.
- Live `grapheneos/System.map` `__lsm_` symbols:

```
ffff80000a328cd0 d __lsm_capability
ffff80000a328d00 d __lsm_selinux
ffff80000a328d30 d __lsm_safesetid_security_init
ffff80000a328d60 d __lsm_integrity
```

`__lsm_yama` **ABSENT** (grapheneos and trunk-14096387 maps).  
`Image.lz4` mtime **2026-05-25 09:26:07**; fragment mtime **2026-09-16 10:48:54**. Not treated as a rebuilt kernel. **HOLD.**

### Residuals (not FAIL of this rematch)

| Residual | Status |
|----------|--------|
| `verify_sec_p5_static.sh` still `require_rg 'perf_event_paranoid 3'` | HOLD — historical P5; **not SoT** |
| `out/target/product/komodo/.../init.guardtalk.hardening.rc` still paranoid **3**, no bpf=1 | HOLD — `m` not run |
| `system/core/rootdir/init-perfetto.rc` can write paranoid -1/1/3 | HOLD — traced/perf_harden; production user should not enable `persist.traced.enable` |
| On-device `/proc/sys` | HOLD — adb empty; Q-ONDEVICE BLOCKED |

### Adversarial negatives refuted

| Claim we refused | Why |
|------------------|-----|
| Live rc still paranoid 3 | Independent rg: writes are 2; no 3 |
| bpf=1 on late-init | Stanza parse: write only after boot_completed |
| `__lsm_yama` in live Image | System.map ABSENT; Image.lz4 not newer than fragment |
| P5 script as rematch SoT | Script still asserts 3; rematch used dedicated suite against 2 |
| `/proc/sys` live PASS | adb empty |
| Q-ONDEVICE / Q-EXCISE / Q-TELEMETRY started | Not started |

## Coverage gaps

- `m` not run; stale `out/` rc still paranoid 3
- Live YAMA compile-time HOLD until next caimito kernel rebuild replaces `Image.lz4` + `System.map`
- On-device `/proc/sys/kernel/{perf_event_paranoid,unprivileged_bpf_disabled,yama/ptrace_scope}` → `Q-REMEDIATE-B2-ONDEVICE` (still BLOCKED)
- Historical P5 suite still asserts 3 (out of this rematch SoT; not edited)

## Bugs found

None that fail host AC for item 9. Expected HOLDs recorded. Live YAMA not invented. Device not claimed fixed.
