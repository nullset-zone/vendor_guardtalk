# Rango (Pixel 10 Pro Fold) Port Preflight

> **Task:** `T-PORT-RANGO-PREFLIGHT`  
> **Date:** 2026-07-25  
> **Decision:** DEC-PORT-RANGO-001 — Pixel 10 Pro Fold ahead; prior DEFERRED `T-PORT-RANGO` SUPERSEDED  
> **Verdict:** **GO**  
> **Scope:** Prerequisites only. GuardTalk device layer = `T-PORT-RANGO-LAYER`. Flash bundle = `T-PORT-RANGO-FLASH`.  
> **Machine-readable:** `vendor/guardtalk/docs/RANGO_PORT_PREFLIGHT.json`

## 0. Codename confirmation (Pixel 10 Pro Fold ≡ rango / laguna)

| Claim | Evidence (quoted path) |
|-------|------------------------|
| Model string | `vendor/adevtool/vendor-skels/google_devices/rango/rango.mk:21` → `PRODUCT_MODEL := Pixel 10 Pro Fold` (also attestation line 28; live tree matches after generate) |
| Product / device | Same file: `PRODUCT_NAME := rango` / `PRODUCT_DEVICE := rango` |
| Platform SoC | `vendor/adevtool/config/device/rango.yml` includes `common/gen10pixel.yml`; that file sets `device.platform: laguna` |
| BoardConfig → laguna | `vendor/adevtool/config/mk/google_devices/device/rango/BoardConfig-base.mk` → `include …/platform/laguna/BoardConfig-common.mk` |
| Kernel dir (adevtool device.mk) | `vendor/adevtool/config/mk/google_devices/device/rango/device.mk:3` → `TARGET_KERNEL_DIR := device/google/laguna-kernels/6.6/grapheneos/rango` |
| Init / health HAL naming | Skel `rango.mk` packages `android.hardware.health-service.laguna`; platform `PRODUCT_PACKAGES += init.laguna.grapheneos.rc` |

**Sibling Gen10 (not this sprint):** `mustang` = Pixel 10 Pro XL; `muzel` shares `laguna-kernels/6.6/grapheneos/muzel`. Do not conflate with Fold.

## 1. Inventory (verified this task)

| Prerequisite | Status | Path / evidence |
|--------------|--------|-----------------|
| adevtool device config | OK | `vendor/adevtool/config/device/rango.yml` → `common/gen10pixel.yml` → platform **laguna** |
| Fold overlay filters in config | OK | `rango.yml` `overlay_inclusions` include many `rango_unfolded_*` SystemUI resources |
| adevtool device mk/skel | OK | `vendor/adevtool/config/mk/google_devices/device/rango/`, `vendor/adevtool/vendor-skels/google_devices/rango/` |
| Kernel tree (grapheneos channel) | OK | `device/google/laguna-kernels/6.6/grapheneos/rango/` (prebuilts + `init.insmod.rango.cfg` + blocklists) |
| Kernel tree (`trunk_staging` aconfig) | **MISSING** | `build/release/flag_values/trunk_staging/RELEASE_KERNEL_RANGO_DIR.textproto` → `device/google/laguna-kernels/6.6/trunk-14072179/rango` — **directory absent** (same class of gap as akita `trunk-14096387`; LAYER resolves via symlink) |
| Factory image primary | OK (this task) | `vendor/adevtool/dl/rango-bp4a.260205.001-factory-f2b43fde.zip` |
| Factory image backport | OK (this task) | `vendor/adevtool/dl/rango-cp1a.260505.005-factory-18bf79d9.zip` (pulled by `generate-all`) |
| Live vendor module | OK (this task) | `vendor/google_devices/rango/` via `adevtool generate-all -d rango` |
| GuardTalk device layer | ABSENT (expected) | No `vendor/guardtalk/device/rango/` — LAYER task only |

### Factory / SPI used

| Item | Value |
|------|-------|
| Device `BUILD_ID` pin (skel + live `rango.mk`) | `BP4A.260205.001` |
| Backport build_id (`pixel.yml`) | `CP1A.260505.005` |
| Primary SHA-256 | `f2b43fde15fab871529887872d9a11436126be708670db38253f1b45e92ea238` |
| Backport SHA-256 | `18bf79d917dfc411a062ada4494c573cb26ca4bcbca7c3f6ea4576e4fc883b37` |
| Primary URL pattern | `https://dl.google.com/dl/android/aosp/rango-bp4a.260205.001-factory-f2b43fde.zip` |
| Download EXIT | **0** (~334s) |
| Generate-all EXIT | **0** (~498s) — log ends `Generated vendor module at vendor/google_devices/rango` |

**Commands run (tree root, Node ≥ 24):**

```bash
export PATH="/home/openstatestack/.local/share/zed/node/node-v24.11.0-linux-x64/bin:$PATH"

vendor/adevtool/bin/run download -d rango -t factory -b BP4A.260205.001
# DOWNLOAD_EXIT=0 → vendor/adevtool/dl/rango-bp4a.260205.001-factory-f2b43fde.zip

ADEVTOOL_SKIP_DEP_BUILD=1 vendor/adevtool/bin/run generate-all -d rango
# GENERATE_EXIT=0 → vendor/google_devices/rango/
# (also downloads/unpacks backport CP1A.260505.005 automatically)
```

`ADEVTOOL_SKIP_DEP_BUILD=1` mirrors the akita preflight workaround for nsjail stderr treated as fatal during dep rebuild.

### Exact commands for LAYER / lunch (when Architect approves GO)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export PATH="/home/openstatestack/.local/share/zed/node/node-v24.11.0-linux-x64/bin:$PATH"

# If regenerating vendor (optional; already done this task):
# ADEVTOOL_SKIP_DEP_BUILD=1 vendor/adevtool/bin/run generate-all -d rango

# LAYER prerequisite — trunk_staging kernel path (akita pattern):
# ln -sfn grapheneos device/google/laguna-kernels/6.6/trunk-14072179
# → resolves RELEASE_KERNEL_RANGO_DIR …/trunk-14072179/rango

source build/envsetup.sh
lunch rango-trunk_staging-userdebug
# Then FLASH task: m -j$(nproc)  (NOT this preflight)
```

## 2. SoC delta sheet — laguna (rango) vs zumapro (tokay) vs zuma (akita)

Reference: tokay = **zumapro** / caimito-kernels 6.1; akita = **zuma** / akita-kernels 6.1; rango = **laguna** / laguna-kernels 6.6.

### 2.1 Platform (adevtool)

| Item | laguna (rango) | zumapro (tokay) | zuma (akita) |
|------|----------------|-----------------|--------------|
| `TARGET_BOARD_PLATFORM` | `laguna` | `zumapro` | `zuma` |
| Init RC package | `init.laguna.grapheneos.rc` | `init.zumapro.grapheneos.rc` | `init.zuma.grapheneos.rc` |
| Health HAL | `android.hardware.health-service.laguna` | (zumapro variant) | (zuma variant) |
| Kernel major | **6.6** (`laguna-kernels`) | 6.1 (`caimito-kernels`) | 6.1 (`akita-kernels`) |
| SEAPP / DEV type checks | set (like zumapro) | set | not set on zuma `device.mk` |
| Common include | `device-common-gs201-plus.mk` | same family | same family |

Paths: `vendor/adevtool/config/mk/google_devices/platform/{laguna,zumapro,zuma}/`.

> **Doc debt:** `vendor/guardtalk/device/REGEN_HOOKS.md` still claims tokay/caiman/**rango** are `zumapro`. That is **wrong for rango** — rango is **laguna**. LAYER must not copy the zumapro note blindly; fix the REGEN_HOOKS note when creating the rango layer.

### 2.2 Fingerprint HAL (critical for excision)

| Device | HAL family | Key packages / files |
|--------|------------|----------------------|
| **rango (laguna)** | **Goodix** (sfps / gf3626) | `android.hardware.biometrics.fingerprint-service.goodix`, `goodixfingerprint`, `goodix_sfps_suez`, `goodixbinderservice-aidl-V1-ndk`, `fingerprint-goodix.rc`, VINTF `fingerprint-goodix.xml`; kernel `goodixfp.ko` |
| **akita (zuma)** | **Goodix** | Same service family; akita firmware / `goodix_brl_touch` touch path differs |
| **tokay (zumapro)** | **QFP** | `qfp-daemon`, `libqfp-service`, `qfp-daemon.rc`, VINTF `qfp-daemon.xml` |

Shared filter `vendor/guardtalk/feature-excised/fp-excised.mk` **already names rango Goodix tokens** (packages + VINTF + `fingerprint-goodix.rc`). LAYER must wire the late include so the filter runs — not reinvent Goodix filters.

### 2.3 Wi‑Fi / BT kernel modules (blocklist + BT excision)

| Item | rango (laguna) | tokay (zumapro) | akita (zuma) |
|------|----------------|-----------------|--------------|
| Wi‑Fi driver (insmod) | `bcmdhd4390.ko` (`init.insmod.rango.cfg`) | `bcmdhd4390.ko` | `bcmdhd4383.ko` |
| Upstream blocklist Wi‑Fi | **both** `bcmdhd4383.ko` + `bcmdhd4390.ko` | `bcmdhd4390` | `bcmdhd4383` |
| Touch blocklist | `syna_touch.ko`, `focal_touch.ko` | `sec_touch` / `syna_touch` | `goodix_brl_touch` |
| BT power/rfkill | `nitrous.ko` in `vendor_dlkm.modules.load` | same | same |
| Device-specific insmod extras | `cs40l26-i2c`, `fst2`, `snd-soc-cs40l26`, `syna_touch` | tokay set | akita set |

Upstream rango blocklist baseline:

`device/google/laguna-kernels/6.6/grapheneos/rango/vendor_dlkm.modules.blocklist`

GuardTalk shared BT override today (`vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist`) is **caimito/tokay-oriented + `blocklist nitrous`**. It is **not** a drop-in for rango:

- Rango upstream uses `.ko` suffixes and lists **both** Wi‑Fi chips plus laguna-specific entries (`fst2`, `focal_touch`, `ebu-google`, etc.).
- Omitting those while pointing at the tokay file risks re-enabling modules that upstream intentionally blocklists.

**LAYER action:** laguna/rango-specific GuardTalk blocklist mirrored from
`device/google/laguna-kernels/6.6/grapheneos/rango/vendor_dlkm.modules.blocklist` **plus** `blocklist nitrous` (or `nitrous.ko` to match upstream style). Do **not** point rango at the tokay shared file without reconciling. Preserve Wi‑Fi two-phase load (`blocklist bcmdhd4390` + `modprobe|bcmdhd4390.ko` in `init.insmod.rango.cfg`).

### 2.4 Radio / modem / NFC / location / audio / camera

| Subsystem | rango observation | GuardTalk implication |
|-----------|-------------------|------------------------|
| Radio / modem | `shared_modem_platform`, Shannon/modem partitions, IMS overlays | Preserve shared `vendor/guardtalk/radio-excised/` once LAYER hooks `rango.mk` — no SoC rename for package filter names |
| GNSS / location | `android.hardware.gnss@lassen`, `gnssd`, `location`, GPS prebuilt XML | Shared `loc-excised.mk` path (wire late include) |
| NFC | ST stack: `android.hardware.nfc-service.st`, `nfc_nci.st21nfc.default` | Shared `nfc-excised.mk` (wire late include) |
| BT userspace | `android.hardware.bluetooth-service.bcmbtlinux` + nitrous kernel | Shared `bt-excised.mk` + nitrous blocklist |
| Audio | `android.hardware.audio.service-aidl.aoc` | Device audio mk pattern from tokay/akita (`guardtalk-audio.mk`) — adapt paths only |
| Camera | `android.hardware.camera.provider@2.7-service-google-apex` + foldable concurrent dual-front feature XML | Preserve camera excision pattern; do not strip foldable camera feature XML unless product policy says so |

### 2.5 Foldable — what LAYER must preserve vs adapt

| Area | Evidence | LAYER / product guidance |
|------|----------|---------------------------|
| Hinge angle sensor | `android.hardware.sensor.hinge_angle.prebuilt.xml` in `rango.mk` | **Preserve** — not an excision target |
| Unfold transitions | framework RRO: `config_unfoldTransitionEnabled` / `config_unfoldTransitionHingeAngle` = true; `config_foldedDeviceStates` | **Preserve** vendor/product RROs from adevtool |
| Dual / inner display | panels `panel-gs-rgea.ko` / `panel-gs-rgeb.ko`; `config_fillSecondaryBuiltInDisplayCutout`; SystemUI `rango_unfolded_*` overlays | **Preserve** — do not replace with phone-only overlays |
| Foldable touch / hall | `hall_sensor.ko`; twoshay foldable VINTF fragment; `syna_touch` insmod | **Preserve** hardware path; excision stays radio/BT/NFC/fp/loc |
| Concurrent foldable camera | `com.google.pixel.camera.concurrent_foldable_dual_front.xml` | **Preserve** unless camera policy explicitly drops it |
| Fold-lock / large-screen shade | adevtool overlay inclusions for unfolded QS / keyguard / biometric auth sizing | **Preserve** — comes from generated vendor overlays |
| GuardTalk UI hides / brand | Shared `vendor/guardtalk/overlays/*` (values/bool/locale; no fold layout variants) | **Adapt only if** smoke shows posture-specific breakage (see §4) |

## 3. Go / no-go

### Verdict: **GO**

| Criterion | Result |
|-----------|--------|
| Codename / SoC identity confirmed | PASS |
| Factory + backport obtainable | PASS (EXIT 0; zips on disk) |
| Live `vendor/google_devices/rango/` generated | PASS (EXIT 0; `AndroidProducts.mk` present) |
| Lunch path realistic | PASS **with LAYER kernel symlink** (documented; same pattern as akita) |
| Fail-closed (no invented vendor tree) | PASS — adevtool produced the tree from factory images |

### Residual blockers for LAYER (not preflight NO-GO)

1. Create `device/google/laguna-kernels/6.6/trunk-14072179` → `grapheneos` symlink (or equivalent) so `lunch rango-trunk_staging-userdebug` resolves `RELEASE_KERNEL_RANGO_DIR`.
2. Create `vendor/guardtalk/device/rango/` + REGEN_HOOKS (laguna/Goodix/fold-correct blocklist) — **next task**.
3. Optional: correct REGEN_HOOKS.md zumapro/rango mis-statement.

### Explicit non-claims

- Port is **not** complete.
- GuardTalk rango device layer **not** applied (`test ! -d vendor/guardtalk/device/rango`).
- Full `m` / desktop-flash bundle **not** in scope.
- Dry `lunch` not run this task (would fail until trunk symlink; avoids touching shared `out/` during flash-ready wave).
- tokay / akita vendor trees **not** regenerated.

## 4. Frontend recommendation — `F-PORT-RANGO-FOLD`

**Recommendation: N/A** (do not dispatch)

Rationale:

- GuardTalk overlays for Settings hides, SUW locks, and branding are **values / bool / locale / icon** RROs — not phone-chassis layout XML keyed to a single display.
- Fold-specific SystemUI unfolded resources (`rango_unfolded_*`) and framework hinge/fold state configs already ship via **adevtool-generated** vendor/product overlays; GuardTalk must not clobber them.
- Inner/outer dual-display behavior is a **preserve** concern for LAYER (vendor RROs + camera/hinge packages), not a new Frontend overlay set for v1 hide/brand parity.

**Escalation path:** If QA fold-posture smoke finds SUW/Settings/SystemUI hide or brand defects unique to outer or inner display, Architect may reopen `F-PORT-RANGO-FOLD` with concrete resource paths. Until then mark **N/A**.

## 5. Verification commands (post-task)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree

test -f vendor/guardtalk/docs/RANGO_PORT_PREFLIGHT.md && echo DOC_OK
rg -n 'Pixel 10 Pro Fold|GO|NO-GO|laguna|Goodix|fold' vendor/guardtalk/docs/RANGO_PORT_PREFLIGHT.md
test ! -d vendor/guardtalk/device/rango && echo NO_LAYER_OK
test -d vendor/google_devices/rango && ls vendor/google_devices/rango/AndroidProducts.mk
ls vendor/adevtool/dl/*rango*
```

## 6. Acceptance checklist

- [x] `RANGO_PORT_PREFLIGHT.md` with **GO** + evidence
- [x] Delta sheet laguna/Goodix/foldable vs tokay/akita
- [x] F-PORT recommendation (**N/A**)
- [x] Exact commands for generate-all + lunch when GO
- [x] Optional download + generate-all executed and documented (EXIT 0)
- [x] Gate 5 ≥90% in `TO_ARCHITECT.md` (completion report; self_critique **97/100**)
- [x] Both `TASK_QUEUE.md` → `T-PORT-RANGO-PREFLIGHT` **REVIEW**
