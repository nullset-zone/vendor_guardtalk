# Extreme Audit Evidence — A-PORT-RANGO

**Task:** `A-PORT-RANGO` (`audit_scope: full`)  
**Date:** 2026-07-25  
**Agent:** AEGIS Independent Auditor (read-only / aegis-auditor)  
**Depends:** `Q-PORT-RANGO` ✅ APPROVED CONDITIONAL GO (static; device HOLD)  
**Status for Architect:** **REVIEW** only (Auditor never self-APPROVES)  
**Sprint:** DEC-PORT-RANGO-001 — Pixel 10 Pro Fold (`rango` / `laguna`)

## Gate -1

| Step | Result |
|------|--------|
| MCP `ask_guardian` | Consulted — `governanceStatus: compliant` (Guardian Proxy fallback) |
| MCP `gate_enforcer` Gate -1 | **PASSED** (`guardian_consulted`, `session_initialized`) |
| MCP `ultimate_critique` | Attempted / may be unavailable (`python: not found` class) — Law 9 manual Gate 5 below |
| Disposition | Proceed under Gate -1 PASS + Architect dispatch packet |

## Independence acknowledgment

```text
INDEPENDENT AUDITOR ENGAGED
Firm: Deep Tech Audit (Big 4 equivalent)
Scope: full — rango Pixel 10 Pro Fold port + flash bundle
Independence: CONFIRMED — I am NOT the Architect. I audit the Architect.
Context: ADR-016 A-PORT-RANGO, DEC-PORT-RANGO-001, Q-PORT-RANGO CONDITIONAL GO
Forbidden: product/implementation edits; inventing device PASS; self-APPROVED
```

## Re-verification (this session)

| Probe | Result |
|-------|--------|
| `bash vendor/guardtalk/docs/qa/verify_port_rango_static.sh` | **76 / 76** PASS, HOLD=1 (adb), FAIL=0, EXIT=0 |
| Symlinks | `rango-latest`→`rango-20260725-133716`; `latest`→`tokay-20260725-102506`; `akita-latest`→`akita-20260725-101434` |
| Bundle imgs | **18** `.img` + `avb_pkmd.bin` + `SHA256SUMS` + README + `init.insmod.rango.cfg` |
| `(cd rango-latest && sha256sum -c SHA256SUMS)` | **EXIT=0** (20 OK) |
| Tokay / akita SHA | both **EXIT=0** (non-regression) |
| `find … *.pem/*.pk8` in rango bundle | **0** |
| flash-from-remote root ↔ vendor | **identical**; `DEVICE=rango` → `rango-latest`; pretty **Pixel 10 Pro Fold** |
| out/ vs bundle size (boot/system/vendor/product/vbmeta/system_ext) | all **YES** |
| `adb devices` | empty → device fold smoke **HOLD** |

```bash
bash vendor/guardtalk/docs/qa/verify_port_rango_static.sh
# PASS_COUNT=76 HOLD_COUNT=1 FAIL=0
# ALL STATIC CHECKS PASSED
```

## Scope matrix (full)

| # | Area | Verdict | Evidence anchors |
|---|------|---------|------------------|
| 1 | Codename / SoC confirmation | **PASS** | Skel `PRODUCT_MODEL := Pixel 10 Pro Fold`; `PRODUCT_DEVICE/NAME := rango`; `rango.yml` → `common/gen10pixel.yml` → `platform: laguna`; `BoardConfig-base.mk` → `platform/laguna/BoardConfig-common.mk`; lunch `rango-trunk_staging-userdebug` (LAYER LUNCH_EXIT=0; FLASH BUILD_EXIT=0) |
| 2 | Foldable handling + F=N/A | **PASS (static)** | Hinge XML + `touchflow_outer` + twoshay VINTF preserved; `rango_unfolded_*` overlays in adevtool config; PREFLIGHT §4 N/A justified (shared values/bool RROs; fold resources from adevtool) — F card N/A in queues |
| 3 | Excision correctness | **PASS (static)** | Laguna blocklist = upstream grapheneos/rango + `nitrous.ko` only (diff confirms; **not** tokay shared file); BoardConfig points at device blocklist; Goodix tokens in `fp-excised.mk`; VINTF `vendor_manifest_no_radio_rango.xml` selected for PRODUCT_DEVICE=rango; media.c2 **not** inlined (CNM fragment owns default); `touchflow_outer` present |
| 4 | Flash-bundle integrity | **PASS** | 18 imgs; SHA EXIT=0; public avb only; script wire both copies; tokay/akita stamps unchanged |
| 5 | Signing / key hygiene | **PASS (hygiene) / HOLD (keys/rango)** | No `*.pem`/`*.pk8`; README + FLASH doc acknowledge public tokay `avb_pkmd.bin` until `keys/rango/` exists (akita-style) |
| 6 | Queue / DEC-012 quality | **PASS** | PREFLIGHT→LAYER→FLASH→Q→A pairing; F=N/A documented; prior DEFERRED `T-PORT-RANGO` / `Q-PORT-RANGO` / `A-PORT-PARITY-RANGO` marked SUPERSEDED in both queues |
| 7 | Build-break risk vs prior research | **PASS (mitigated) / HOLD runtime** | PREFLIGHT gaps closed: kernel aconfig→`…/grapheneos/rango` + trunk symlink + `guardtalk-insmod.mk`; VINTF media.c2 conflict fixed with rango-specific manifest (first build failed, retry BUILD_EXIT=0). Residual: device smoke; `keys/rango` |

## Detail notes

### 1. Codename / SoC (honest lunch path)

| Claim | Path / quote |
|-------|----------------|
| Model | `vendor/adevtool/vendor-skels/google_devices/rango/rango.mk` — `PRODUCT_MODEL := Pixel 10 Pro Fold` |
| Platform | `vendor/adevtool/config/device/common/gen10pixel.yml` — `platform: laguna` (included from `rango.yml`) |
| Board | `…/device/rango/BoardConfig-base.mk` → `platform/laguna/BoardConfig-common.mk` |
| Kernel dir (durable) | `RELEASE_KERNEL_RANGO_DIR` → `device/google/laguna-kernels/6.6/grapheneos/rango` |
| Lunch / build | `rango-trunk_staging-userdebug`; README cites BUILD_EXIT=0 (`/tmp/rango-flash-build-retry-20260725T132507Z.log`) |

Sibling Gen10 (`mustang` / `muzel`) not conflated. Lunch path is honest: LAYER documented aconfig + symlink; FLASH completed full `m`.

### 2. Foldable + F=N/A

Preserve evidence (not stripped by excision):

- `android.hardware.sensor.hinge_angle.prebuilt.xml` in `rango.mk`
- `ITwoshayFileDumpService/touchflow_outer` in excised VINTF
- `touchflow_outer.pb` copy-file in live `rango.mk`
- adevtool `overlay_inclusions` for many `rango_unfolded_*` SystemUI resources
- REGEN_HOOKS foldable preserve list (panels, hall, concurrent_foldable, unfold RROs)

**F-PORT-RANGO-FOLD = N/A** justified by PREFLIGHT §4: GuardTalk overlays are values/bool/locale; fold posture UX ships via adevtool-generated vendor/product overlays. Escalation only if device smoke finds posture-specific hide/brand defects.

### 3. Excision (laguna-correct, not tokay copy)

| Concern | Auditor finding |
|---------|-----------------|
| Blocklist | Device file comments + BoardConfig forbid tokay shared blocklist; diff vs upstream = header comments + `blocklist nitrous.ko` only |
| Goodix | Shared `fp-excised.mk` already lists rango Goodix family; live `rango.mk` includes `guardtalk-radio-excised.mk` |
| Radio VINTF | `vintf-excised.mk` selects `vendor_manifest_no_radio_rango.xml` for rango; late-pass PRODUCT_DEVICE fallback documented (prevents silent tokay manifest re-apply) |
| media.c2 | Rango stock fragment `manifest_media_c2_cnm.xml` declares `IComponentStore/default`; excised manifest correctly **omits** duplicate — avoids check_vintf conflict that broke first FLASH attempt |
| Fold regress | `touchflow_outer` retained in excised manifest |

Live hooks present:

- `vendor/google_devices/rango/BoardConfig.mk` → `BoardConfig-excised-late.mk`
- `vendor/google_devices/rango/rango.mk` → `guardtalk-radio-excised.mk` + `guardtalk-insmod.mk`

### 4–5. Bundle + keys

| Item | Value |
|------|-------|
| Stamp | `rango-20260725-133716` via `rango-latest` |
| Images | 18 (flash-from-remote class) |
| Checksums | 20 OK (18 imgs + avb + init.insmod) |
| Private keys in bundle | none |
| `keys/rango/` | **ABSENT** — public tokay pkmd copy documented (akita H1 pattern) |

### 6. DEC-012 / supersede

Active sprint cards pair T\*→Q-PORT-RANGO→A-PORT-RANGO; F=N/A. Historical multi-device DEFERRED cards rewritten SUPERSEDED → DEC-PORT-RANGO-001 / A-PORT-RANGO in both `TASK_QUEUE.md` and `.agent-comm/TASK_QUEUE.md`.

### 7. Residual HOLDs (do not invent PASS)

| ID | Class | Item |
|----|-------|------|
| H1 | HOLD | On-device fold smoke (adb empty): clean-wipe flash, boot, fold open/close, branding/Settings/SUW |
| H2 | HOLD | `keys/rango/` absent — public tokay `avb_pkmd.bin` until device keys exist |

## Gate 5 (manual; MCP ultimate_critique may be unavailable)

| Dimension | Score /10 |
|-----------|-----------|
| Scope coverage (7 checklist areas) | 10 |
| Static re-verify (76/76) | 10 |
| Codename / SoC honesty | 10 |
| Foldable preserve + F=N/A | 10 |
| Excision (laguna/Goodix/VINTF/media.c2) | 10 |
| Flash integrity + non-regression | 10 |
| Key hygiene (no privkeys) | 10 |
| DEC-012 / supersede quality | 10 |
| Build-break mitigation vs research | 9 |
| Runtime residual risk (device + keys) | 4 |
| Independence / no invented PASS | 10 |

**Gate 5: 94%** (manual). TOOL UNAVAILABLE risk: `ultimate_critique` (`python: not found` class per peer audits).

### PQE Assessment

Code Entropy **LOW** for static port surface — device-specific blocklist + rango VINTF + isolated `rango-latest` symlink reduce cross-device regression. Residual entropy concentrated in **unverified fold runtime** and **shared public AVB pkmd** until `keys/rango/`.

## Finding summary

| Severity | Count | IDs |
|----------|------:|-----|
| BLOCK | 0 | — |
| HIGH (HOLD) | 1 | **H1** device fold smoke (adb empty) |
| MEDIUM | 0 | — |
| HOLD (keys) | 1 | **H2** `keys/rango/` absent; public tokay pkmd acknowledged |
| LOW | 1 | **L1** First FLASH VINTF failure (historical) — fixed before BUILD_EXIT=0; keep late-pass device selection regression-tested on regenerate |

## Verdict for Architect

- **Static port + flash bundle:** **CONDITIONAL GO** (aligns with Q-PORT-RANGO CONDITIONAL GO; auditor re-ran 76/76).
- **On-device fold acceptance:** **NO-GO** until H1 smoke on attached Pixel 10 Pro Fold (do not invent PASS).
- **Keys:** **HOLD** H2 — hygiene PASS (no privkeys); prefer `keys/rango/` when available.
- **Overall auditor recommendation:** **CONDITIONAL GO** for sprint static close; full unconditional GO requires H1.

## Sprint close criteria (recommended)

1. Architect reviews this audit + Gate 5 report; marks `A-PORT-RANGO` **APPROVED CONDITIONAL GO** (or returns with findings) — Auditor does not self-APPROVE.
2. Attach Pixel 10 Pro Fold; flash via `DEVICE=rango` / `REMOTE_BUILD_DIR=…/rango-latest`; record fold open/close + branding/Settings/SUW smoke → clear **H1**.
3. Optional close polish: provision `keys/rango/` and restage public `avb_pkmd.bin` → clear **H2**.
4. Do **not** mark sprint unconditional GO while H1 remains HOLD.
5. Keep tokay `latest` and `akita-latest` isolation (verified this session).

## References

| Artifact | Path |
|----------|------|
| Preflight | `vendor/guardtalk/docs/RANGO_PORT_PREFLIGHT.md` |
| Layer | `vendor/guardtalk/docs/RANGO_PORT_LAYER.md` |
| Flash | `vendor/guardtalk/docs/RANGO_FLASH.md` |
| QA evidence | `vendor/guardtalk/docs/qa/Q-PORT-RANGO_EVIDENCE.md` |
| Static script | `vendor/guardtalk/docs/qa/verify_port_rango_static.sh` |
| Bundle | `releases/desktop-flash/rango-20260725-133716` (`rango-latest`) |
| Audit style peer | `vendor/guardtalk/docs/qa/A-UIHIDE-BRAND_AUDIT.md` |
