# B-EXCISE-BOOT-SAFETY-GATE — Static Boot Safety Harness (G1–G8)

| Field | Value |
|-------|-------|
| **task_id** | `T-EXCISE-BOOT-SAFETY-GATE` |
| **role** | `backend_engineer` (Panel 2) |
| **owner_repository** | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| **programme** | `DEC-EXCISE-AIRGAP-001` |
| **status** | **REVIEW** (never APPROVED) |
| **priority** | **P0** — blocks every BIG-class approval in the remediation programme |
| **qa_pair** | `Q-EXCISE-BOOT-SAFETY-GATE` (now unblocked) |
| **blast_radius** | **BIG** |
| **gate_5** | `HUMAN SKIP` (no self-score invented) |
| **hardware claims** | `LIVE_FLASH_CLAIMED=false` · `FLASH_READY=false` · **`BOOT_VERIFIED=false`** |
| **commit** | none |
| **timestamp** | 2026-09-25T13:04:15Z |

> **HOLD is by construction.** This is a *static, artifact-level* harness. There is no
> hardware on this host, so the runtime claim ("the device boots") is HOLD and is **not**
> asserted anywhere in this report. The harness proves structural coherence of the shipped
> stamps and fails closed on incoherence. It does **not** and cannot prove boot safety.

---

## (b) Single re-run command — for the Architect

```bash
bash .agent-comm/tools/gt-boot-safety-gate.sh --all-devices --json
```

Useful variants:

```bash
# per-device, with stamp SHA256SUMS verification (hashes the full stamp, ~26 s/device)
bash .agent-comm/tools/gt-boot-safety-gate.sh --device blazer --verify-sums --json

# include the G4 APEX/BCP host check (runs verify_remediate_b2_apex_host.sh)
bash .agent-comm/tools/gt-boot-safety-gate.sh --all-devices --json          # G4 is ON by default

# skip G4 for a fast 13-device structural pass (~41 s)
bash .agent-comm/tools/gt-boot-safety-gate.sh --all-devices --skip-g4 --json

# negative controls
bash .agent-comm/tools/gt-boot-safety-gate.sh --fixture blocklisted-boot-critical
bash .agent-comm/tools/gt-boot-safety-gate.sh --fixture unloaded-dependency
bash .agent-comm/tools/gt-boot-safety-gate.sh --fixture hal-without-binary
bash .agent-comm/tools/gt-boot-safety-gate.sh --fixture init-service-without-binary
bash .agent-comm/tools/gt-boot-safety-gate.sh --fixture clean-control
```

Exit code: `0` = all evaluated gates pass on all devices; non-zero = at least one gate failed.
Per-device rows are always printed — never a single blanket line.

---

## Authority & Gate -1 (in-process)

- Authoritative task path: owner-root `TASK_QUEUE.md` (not hand-edited by this card).
- Owner repository: `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`. All target paths are inside it.
- **Gate -1 executed in-process** from owner-local governance
  `.aegis/governance/laws/*.yaml` (**24 laws**) and `.aegis/governance/gates/*.yaml`
  (**11 gates**, incl. `gate_neg1_guardian_first.yaml`, `id: -1`).
  **No** call to `aegis-verifier`, `ask_guardian`, `gate_enforcer`, or any Guardian HTTP endpoint.
- `.agent-comm/inbox/TO_ARCHITECT.md` was **NOT** written (parallel-writer prohibition honoured).

---

## Deliverables

| Path | What it is |
|------|-----------|
| `.agent-comm/tools/gt-boot-safety-gate.sh` | single-command wrapper (the re-run command above) |
| `.agent-comm/tools/gt_boot_safety_gate.py` | the harness engine (G1–G8 + fixtures) |
| `.agent-comm/tools/gt-boot-critical-allowlist.yaml` | **G3** reviewed, versioned boot-critical allowlist (rationale per entry) |
| `.agent-comm/tools/gt-vintf-expected-refs.yaml` | **G5** reviewed, versioned forbidden/backed/APEX-provided HAL rule set |
| `.agent-comm/tools/gt-init-excisions.yaml` | **G6** documented, machine-checked init-service excisions |
| `.agent-comm/tools/gt-boot-chain-baseline.json` | **G7** recorded boot-chain SHA256 baseline (13 devices) |
| `.agent-comm/evidence/T-EXCISE-BOOT-SAFETY-GATE/report_full.json` | machine-readable result of the final 13-device run |
| `.agent-comm/evidence/T-EXCISE-BOOT-SAFETY-GATE/g4_apex_host.out` | raw G4 host-check output (the `E-20` surface) |
| `.agent-comm/evidence/T-EXCISE-BOOT-SAFETY-GATE/cache/<dev>/` | per-device extracted evidence (modules, vintf, init, sepolicy, apex inventory, boot-chain hashes) |

**Artifact-level evidence, not makefile-level.** The harness reads the shipped images
directly with `debugfs` (ext4 `cat`/`ls`/`stat`) and `unpack_bootimg` + `lz4` (vendor
ramdisk CPIO). It never trusts a makefile claim where an artifact claim is possible.

---

## (d) 13-device result table (final run, G4 on)

Legend: `G2 unloaded/inv/miss` = dependency-closure defects; `G3 miss/blk/notload/uncovered` =
boot-critical allowlist defects; `G5 forb/unback/undecl` = runtime-merged VINTF defects;
`G6 orph/wf/req/lab` = init/sepolicy defects; `G7` = boot-chain diff vs baseline.

| device | G2 unloaded/inv/miss | G3 miss/blk/notload/uncovered | G5 forb/unback/undecl | G6 orph/wf/req/lab | G7 |
|--------|----------------------|-------------------------------|-----------------------|--------------------|----|
| shiba | 0/0/0 | 0/**1**/0/0 | 7/1/0 | 3/0/0/2 | unchanged |
| husky | 0/0/0 | 0/**1**/0/0 | 7/1/0 | 3/0/0/2 | unchanged |
| akita | 0/0/0 | 0/0/0/0 | 7/1/0 | 3/0/0/2 | unchanged |
| tokay | 0/0/0 | 0/0/0/0 | 7/1/0 | 3/0/0/2 | unchanged |
| caiman | 0/0/0 | 0/0/0/0 | 7/1/0 | 2/0/0/2 | unchanged |
| komodo | 0/0/0 | 0/0/0/0 | 7/1/0 | 3/0/0/2 | unchanged |
| comet | 0/0/0 | 0/0/0/0 | 7/**2**/0 | 3/0/0/2 | unchanged |
| tegu | 0/0/0 | 0/0/0/0 | 7/1/0 | 2/0/0/2 | unchanged |
| stallion | 0/0/0 | 0/0/0/0 | 7/1/0 | 2/0/0/2 | unchanged |
| frankel | 0/0/0 | 0/0/0/0 | 7/1/0 | 2/0/0/2 | unchanged |
| blazer | 0/0/0 | 0/0/0/0 | 7/1/0 | 2/0/0/2 | unchanged |
| mustang | 0/0/0 | 0/0/0/0 | 7/1/0 | 2/0/0/2 | unchanged |
| rango | 0/0/0 | 0/0/0/0 | 7/1/0 | 4/0/0/2 | unchanged |

**Totals:** devices=13, gate-fail=13 (G5 and G6 fail on all 13; G3 fails on 2).
`G2` and `G7` pass on 13/13.

---

## Gate-by-gate findings

### G1 — Build / stamp presence & verification
Stamp + `SHA256SUMS` present on 13/13. `--verify-sums` executed on **blazer**:
`sha256sum -c SHA256SUMS` → **ok** (22 entries, 26.5 s). The full 13-device hash
(~6.1 GB/device, ~80 GB) was **not** run — see "Could not verify".

### G2 — Module dependency closure — **PASS 13/13**
Set algebra over `modules.dep` × `modules.load` × `modules.blocklist` across
`system_dlkm`, `vendor_dlkm`, `vendor_kernel_boot` ramdisk; two-phase
`init.insmod.<dev>.cfg` modelled. Result: **0 unloaded deps, 0 load-order
inversions, 0 missing deps** on every device. The `bcmdhd4390` two-phase ordering
is handled (phase-2 modules are counted as loaded, not as inversions).

### G3 — Boot-critical allowlist — **FAIL 2/13**
`gt-boot-critical-allowlist.yaml` (v2, reviewed) pins storage/zram, UFS, display,
regulator/PMIC, pinctrl, PCIe and sched/thermal modules, family-scoped because the
two SoC generations ship *different* UFS/PCIe drivers as modules (zuma/zumapro:
`ufs-exynos-gs`, `ufs-pixel-fips140`, `pcie-exynos-gs`…; laguna: `ufs`, `google-pcie`,
`virtio_blk`). A subsystem **coverage assertion** prevents a whole subsystem from
silently dropping out of the allowlist.

**Finding (shiba, husky):** `rt6160-regulator` is listed in
`vendor_dlkm.modules.load` **and** in `vendor_dlkm.modules.blocklist`, with no
phase-2 override. Artifact-confirmed:

```
vendor_dlkm.modules.load:13:      rt6160-regulator.ko
vendor_dlkm.modules.blocklist:25: blocklist rt6160_regulator
```

A module that is requested to load and simultaneously blocklisted will be skipped by
the loader — the RT6160 regulator driver never binds on these two devices. This is
the contradiction class G3 exists to catch, found on real stamps.

### G4 — APEX / BCP — **FAIL (exit=1)** · `E-20` **UNRESOLVED** (surface, not suppress)
Delegated to `vendor/guardtalk/docs/qa/verify_remediate_b2_apex_host.sh`.
Observed: `RESULT: FAIL (host)  bash_PASS=29 bash_HOLD=5 PY_RC=1`, `G4_EXIT=1`.
Failing host checks include:
- `FAIL: devicelock-apex-excised.mk active code touches SSR/BCP system-server jars (do not strip)`
- `FAIL: APEX mk active code strips BCP/SSR (Zygote boot-loop class)`
- `FAIL: PRODUCT_APEX_BOOT_JARS missing com.android.devicelock:framework-devicelock (BCP stripped — Zygote risk)`
- `FAIL: PRODUCT_APEX_STANDALONE_SYSTEM_SERVER_JARS missing com.android.devicelock:service-devicelock (SSR stripped — Zygote risk)`

**`E-20` = `devicelock-apex-excised.mk` strips SSR/BCP system-server jars (Zygote
boot-loop class).** It must be resolved or explicitly waived before any card touching
APEX/BCP is approved. The harness propagates this as a hard G4 failure and never
suppresses it. Raw output: `.agent-comm/evidence/T-EXCISE-BOOT-SAFETY-GATE/g4_apex_host.out`.

### G5 — VINTF coherence (runtime-merged) — **FAIL 13/13**
Models the runtime merge (`/vendor/etc/vintf/manifest.xml` + every
`/vendor/etc/vintf/manifest/*.xml` fragment, `VintfObject.cpp:282-328`).

**7 forbidden declarations on every device** (`gt-vintf-expected-refs.yaml`):
`vendor.samsung_slsi.telephony.hardware.oemservice` (the `dmd.xml` fragment that
defeats `vendor_manifest_no_radio*.xml`), `android.hardware.bluetooth`,
`android.hardware.bluetooth.audio`, `android.hardware.bluetooth.finder`,
`android.hardware.bluetooth.ranging`, `vendor.google.bluetooth_ext`
(BT fragment not unwired).

**1 unbacked declaration on 12 devices, 2 on comet:** `vendor.google.bluetooth_ext`
(no shipping binary), plus on **comet** `android.hardware.biometrics.fingerprint`
declared by fragment `fingerprint-fpc42_fw49.xml` with **no shipping binary**.
`undeclared=0` on all devices (every shipping HAL service has a declaration).

### G6 — Init / sepolicy coherence — **FAIL 13/13**
Real services parsed from the shipped rc set; execs resolved against the shipped
images; `requires`/`wait_for` resolved against the shipped service set; `seclabel`
domains matched against the shipped CIL.

**Genuine unexcised orphans (triage required):**
- `charonservice` — all 13: `/system/vendor/bin/charon` absent (strongSwan VPN residual).
- `abox` — all 13: `/vendor/bin/main_abox` absent.
- `gnss_service` — **shiba, husky**: `class hal`, `/vendor/bin/hw/android.hardware.gnss@2.1-service-brcm` absent. *(This is the exact finding the brief predicted.)*
- `pktrouter` — akita, tokay, komodo, rango: `/system/vendor/bin/wfc-pkt-router` absent (Wi-Fi-calling residual).
- `fps_hal` — comet: `/vendor/bin/hw/android.hardware.biometrics.fingerprint-service.fpc42_fw49` absent.
- `init_thermal_config` — rango: `/vendor/bin/rango_init_thermal_config` absent.

**Missing sepolicy labels — 2 per device:** `u:r:abox:s0` and `u:r:charonservice:s0`
are referenced by `.rc` seclabels but **no such types exist in the shipped CIL**
(rc survived the policy excision). 0 broken `wait_for`, 0 broken `requires`.

**Documented excisions (machine-checked, not silent):** `gt-init-excisions.yaml` v2 covers
only inert execs, each validated:
- `boringssl_self_test32_vendor`, `boringssl_self_test32`, `zygote_secondary` — 32-bit
  artifacts on these **64-bit-only** devices (`ro.zygote=zygote64`,
  `ro.vendor.product.cpu.abilist32=` empty), guarded by ABI properties; the 32-bit
  branch of the ABI-selected import is never reached.
- `adbd` — APEX-provided; **honoured only because `com.android.adbd.apex` is present in
  the shipped images** (artifact proof, per device).
- `traced_relay` — `disabled`, started only at `persist.traced.enable=2` (relay mode).

The excision mechanism is fail-closed: an excused service whose observed
`start`/`exec_start` reference count exceeds the reviewer-declared count is **rejected**
and re-reported as an orphan.

### G7 — Boot-chain diff — **PASS 13/13 (`unchanged`)**
`bootloader.img`, `radio.img`, `vbmeta*.img`, `pvmfw.img`, `dtbo.img` SHA256 compared
against the recorded baseline (`gt-boot-chain-baseline.json`). All 13 devices
**unchanged**. Any change flips the row to `CHANGED(flagged)` (the ABL-reject class).

### G8 — Honesty flags
`BOOT_VERIFIED=false`, `FLASH_READY=false`, `LIVE_FLASH_CLAIMED=false` are printed in
the header of every run and embedded in every JSON report.

---

## (c) Negative fixtures — proof the harness can fail

Each fixture synthesizes a defective dataset (`--fixture <name>`) and asserts that the
**specific expected gate** catches it.

| fixture | expected gate | exit code | observed |
|---------|---------------|-----------|----------|
| `blocklisted-boot-critical` | G3 | **1** | `NEGATIVE FIXTURE DEFECT DETECTED (G3 failed) — blocklisted=1` |
| `unloaded-dependency` | G2 | **1** | `NEGATIVE FIXTURE DEFECT DETECTED (G2 failed) — unloaded_deps=1` |
| `hal-without-binary` | G5 | **1** | `NEGATIVE FIXTURE DEFECT DETECTED (G5 failed) — unbacked=1` |
| `init-service-without-binary` | G6 | **1** | `NEGATIVE FIXTURE DEFECT DETECTED (G6 failed) — orphan=1` |
| `clean-control` | (none) | **0** | `CLEAN-CONTROL: PASS (exit 0)` |

The fixtures use real allowlist module names and the `laguna_muzel` family so the
negative path exercises the same code as the real devices. A fixture that fails for the
*wrong* gate returns exit `4` (harness guarded against coincidental detection).

---

## (a) Status

**REVIEW.** Nothing is APPROVED. No commit, no push. No `TASK_QUEUE.md` or
`TO_ARCHITECT.md` edit. `Q-EXCISE-BOOT-SAFETY-GATE` is unblocked to proceed.

## (f) Could not verify (and why)

1. **Runtime boot behaviour — HOLD by construction.** No hardware attached;
   `BOOT_VERIFIED=false`. No claim of boot safety is made or implied.
2. **Full 13-device `SHA256SUMS` verification.** G1 `--verify-sums` was run on **blazer
   only** (26.5 s, all 22 entries OK). A full sweep hashes ~80 GB; not run to respect the
   card's "no rebuild / no long-hash" intent. G1 presence was checked on all 13.
3. **APEX payload internals.** `adbd` is excused on the *presence* of
   `com.android.adbd.apex`, not by opening the APEX payload. `E-20`/G4 remains a host
   (source-structural) failure — not resolved here.
4. **G6 rc coverage boundary.** G6 scans `/vendor/etc/init/**` and `/system/etc/init/**`
   (recursively, deduped by content). Init files reached *only* via `import` from
   `/vendor/etc/*.rc` (e.g. `/vendor/etc/boringssl_self_test.*.rc`) are **outside** that
   scan; this is why `boringssl_self_test32_vendor` shows `expected_start_references: 0`.
   `/odm/etc/init` is unverifiable (no `odm` image in the stamps).
5. **`rt6160-regulator` blocklist intent.** The harness reports the load/blocklist
   contradiction; whether the *correct* fix is to drop it from `modules.load` or from the
   blocklist on shiba/husky is a design decision for the owning engineer — not asserted here.
6. **`charonservice`/`abox`/`init_thermal_config` ownership.** Reported as artifact-level
   orphans + missing labels; the harness does not decide whether each is an intentional
   excision that should have removed the `.rc`, or a genuinely missing binary.
7. **`bootloader`/`radio`/`pvmfw` trust.** G7 proves the bytes are *unchanged vs the
   recorded baseline*. It does not prove the baseline itself is signed/trusted.

---

*T-EXCISE-BOOT-SAFETY-GATE · REVIEW · static artifact-level harness · no hardware
attached · no boot-safety claim · no commit.*
