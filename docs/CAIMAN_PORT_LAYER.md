# Caiman (Pixel 9 Pro) Port — GuardTalk Device Layer

> **Task:** `T-PORT-CAIMAN` (LAYER phase), program `DEC-PORT-GEN8910-001` /
> operator directive `DEC-PORT-GEN8910-002`, Wave A (`zumapro`).
> **Date:** 2026-09-22
> **Depends on:** `T-PORT-MATRIX-PREFLIGHT` ✅, `T-PORT-EXCISION-MATRIX` ✅,
> `T-PORT-KERNEL-MATRIX` ✅.
> **Status:** LAYER complete. FLASH build in progress — see
> `CAIMAN_PORT_FLASH.md` for the build/stamp record.
> **Not FLASH-approved:** no keys, no signed-user build, no USB flash,
> `FLIVE_FLASH_CLAIMED=false`; on-device/boot is **HOLD** (no hardware).

`caiman` is the **Pixel 9 Pro** — the same `zumapro` / `caimito-kernels 6.1`
variant as `tokay` and `komodo` (`GT_VARIANT = zumapro_caimito`). The working
precedent is `vendor/guardtalk/device/komodo/`; the canonical recipe is
`vendor/guardtalk/device/REGEN_HOOKS.md`.

## Results

| Item | Result |
|------|--------|
| Device layer | `vendor/guardtalk/device/caiman/` (3 wired files) |
| REGEN_HOOKS | Applied to `vendor/google_devices/caiman/{BoardConfig.mk,caiman.mk}` (tail, idempotent) |
| `lunch caiman-trunk_staging-userdebug` | **OK** (`LUNCH_EXIT=0`; `TARGET_PRODUCT=caiman`) |
| Platform | `zumapro` |
| Excision variant | `zumapro_caimito` |
| Blocklist | `vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist` (caimito baseline + `blocklist nitrous`) — **not** the akita/zuma file |
| Fingerprint stack | QFP (`GT_VARIANT_zumapro_caimito_FP_STACK := qfp`) — same shared `fp-excised.mk` as tokay/komodo |
| Insmod | `init.insmod.caiman.cfg` from the symlink-free `caimito-kernels/6.1/grapheneos` |
| Full `m dist` image | FLASH phase — see `CAIMAN_PORT_FLASH.md` |

## Layer files

| File | Role |
|------|------|
| `guardtalk-flags.mk` | Radio/wave2/voice flags; `GUARDTALK_PRODUCT_MODEL := GuardTalk Pixel 9 Pro`; face filter empty; **`GUARDTALK_DEVICE := caiman` pin** (see blocker below) |
| `BoardConfig-excised-late.mk` | Modem OTA filter, `androidboot.radio.disabled=1`, registry-resolved blocklist + drift guard, AVB block |
| `guardtalk-insmod.mk` | Explicit `init.insmod.caiman.cfg` install (GNU `find` does not traverse the `trunk-14096387` symlink) |

`product-common-excised.mk` is intentionally **not** created — it is parity-only
and unhooked for komodo too (`REGEN_HOOKS.md` §5).

## Hooks (idempotent, appended to the END of generated files)

`vendor/google_devices/caiman/BoardConfig.mk` (after `AB_OTA_PARTITIONS`,
currently `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES` is the last line):

```makefile
# GuardTalkOS caiman: strip modem partition after AB_OTA list is defined
include vendor/guardtalk/device/caiman/BoardConfig-excised-late.mk
```

`vendor/google_devices/caiman/caiman.mk` (mirrors komodo exactly):

```makefile
# Late pass: remove RIL/modem packages and copy-files (must include, not inherit-product)
include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk

# GuardTalkOS caiman: install init.insmod.caiman.cfg (symlink TARGET_KERNEL_DIR breaks find-copy)
include vendor/guardtalk/device/caiman/guardtalk-insmod.mk
```

Re-running the apply step is a no-op: both `include` lines are single, verified
with `grep -c` == 1.

## Blocklist resolution — proven caimito, not zuma/akita

`BoardConfig-excised-late.mk` sets `GUARDTALK_DEVICE := caiman`, includes
`feature-excised/excision-variant-select.mk`, then:

```makefile
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE := $(GT_EXCISION_BLOCKLIST_FILE)
$(call gt-excision-validate-device-blocklist)
```

caiman has **no** `GT_DEVICE_BLOCKLIST_caiman` pin, so `GT_EXCISION_BLOCKLIST_FILE`
falls through to the variant's canonical file
`vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist` — the
`caimito-kernels` grapheneos baseline (`bcmdhd4390`, `syna_touch`, `sec_touch`) +
`blocklist nitrous`. The akita/zuma file
(`vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist` — `bcmdhd4383` /
`goodix_brl_touch`) is **not** selected. Confirmed at lunch:

```text
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE = vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
GT_VARIANT                                 = zumapro_caimito
```

`gt-excision-validate-device-blocklist` re-derives the blocklist tokens and
`$(error)`s on any drift — no silent no-op.

## Lunch verification (captured 2026-09-22 ~08:41 UTC)

```bash
source build/envsetup.sh && lunch caiman-trunk_staging-userdebug
```

```text
LUNCH_EXIT=0
TARGET_PRODUCT=caiman
TARGET_BOARD_PLATFORM=zumapro
GUARDTALK_RADIO_EXCISED=true
GUARDTALK_FEATURE_EXCISED_WAVE2=true
GUARDTALK_VOICE_FILTER=true
GUARDTALK_PRODUCT_MODEL=GuardTalk Pixel 9 Pro
PRODUCT_MODEL=GuardTalk Pixel 9 Pro
BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE=vendor/guardtalk/feature-excised/vendor_dlkm.modules.blocklist
GT_VARIANT=zumapro_caimito
RELEASE_KERNEL_CAIMAN_DIR=device/google/caimito-kernels/6.1/trunk-14096387
```

Host printed `Build sandboxing disabled due to nsjail error.` (pre-existing; not a lunch FAIL).

## ⚠ Shared-core blocker found (P0 — belongs to `T-PORT-EXCISION-MATRIX`)

`lunch` was **hard-broken for every GuardTalk product** before this card's
device-local pin. The regression is a **Sep 21 uncommitted working-tree change**
by `T-PORT-EXCISION-MATRIX` that added

```makefile
include vendor/guardtalk/feature-excised/excision-variant-select.mk
```

to `vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk`. That file is
re-entered from `radio-excised/product-config-late.mk` (included at
`build/make/core/product_config.mk:269`), where `PRODUCT_DEVICE` and
`TARGET_DEVICE` are empty and the board `GUARDTALK_DEVICE` has not been
evaluated yet. The resolver's

```makefile
GT_EXCISION_DEVICE := $(strip $(or $(GUARDTALK_DEVICE),$(PRODUCT_DEVICE),$(TARGET_DEVICE)))
ifeq ($(GT_EXCISION_DEVICE),)
$(error T-PORT-EXCISION-MATRIX: cannot resolve an excision variant — no known device identity ...)
```

therefore fires unconditionally. The resolver's own header documents an intended
"no-op when already resolved with the same device" re-include guard; **that guard
is not implemented** in `excision-variant-select.mk`, so the second include
errors.

**Evidence (reproduced):**

- `lunch komodo-trunk_staging-userdebug` (the APPROVED working precedent) fails
  with the **identical** error — `excision-variant-select.mk:35`.
- `out/soong/soong.komodo.variables` mtime `2026-09-20 17:45` — komodo's last
  successful soong config **predates** the Sep 21 change
  (`guardtalk-radio-excised.mk` mtime `2026-09-21 15:13`,
  `excision-variant-select.mk` mtime `2026-09-21 15:24`).
- The `T-PORT-EXCISION-MATRIX` verification (`verify_port_excision_matrix_static.sh`)
  is a **static** harness; it never ran `lunch`, so the regression passed the
  card's acceptance.

**Recommended root-cause fix (shared core, NOT in this card's scope):** make the
resolver genuinely idempotent, e.g. wrap the body in an
`ifeq ($(GT_EXCISION_DEVICE),)`-free guard keyed on an already-resolved marker,
or do not `include` the resolver from the `product-config-late` re-entry path
when device identity is unavailable. **This is the Architect's call** — this card
is forbidden from editing `vendor/guardtalk/{feature-excised,radio-excised}/`.

**Device-local unblock used here (reversible, Law 11):**
`guardtalk-flags.mk` pins `GUARDTALK_DEVICE := caiman`. That file is `-include`d
by `guardtalk-radio-excised.mk` while `PRODUCT_DEVICE` is still set, so the pin
survives as a plain make variable into the `product-config-late` re-entry and the
resolver resolves deterministically in both contexts. It is additive,
caiman-only, and does not touch the shared core. If the Architect lands the real
guard, this pin becomes redundant (harmless) and can be removed.

## Non-regression

`vendor/guardtalk/device/{tokay,akita,komodo,rango}/` and
`vendor/google_devices/{tokay,akita,komodo,rango}/` were not touched by this
card. The four `releases/desktop-flash/*-latest` symlinks are asserted unchanged
in `CAIMAN_PORT_FLASH.md`. No `*-latest` for another device was created or moved.

## Reusable recipe for the 7 remaining devices

Per device `<dev>` in the Wave A/B/C matrix, with its variant `GT_VARIANT_<dev>`
read from `feature-excised/excision-variants.mk`:

1. `adevtool generate-all -d <dev>` (operator-side; **never concurrent**), then
   create `vendor/guardtalk/device/<dev>/`:
   - `guardtalk-flags.mk` — copy caiman's; set `GUARDTALK_PRODUCT_MODEL` to
     `GuardTalk <PRODUCT_MODEL>` from `vendor/google_devices/<dev>/<dev>.mk`;
     keep `GUARDTALK_RADIO_EXCISED/FEATURE_EXCISED_WAVE2/VOICE_FILTER := true`,
     `GUARDTALK_FACE_FILTER :=`, and (until the shared-core guard lands)
     `GUARDTALK_DEVICE := <dev>`.
   - `BoardConfig-excised-late.mk` — copy caiman's; only `GUARDTALK_DEVICE :=
     <dev>` changes. The blocklist/AB_OTA/cmdline/AVB blocks are device-agnostic
     because the registry resolves the variant.
   - `guardtalk-insmod.mk` — copy caiman's; replace `caiman` → `<dev>` in the
     variable name, the two `init.insmod.<dev>.cfg` paths, and the
     `LOCAL_PATH_GT_<DEV>_INSMOD` value. **Verify the kernel family path**:
     `device/google/<family>-kernels/<ver>/grapheneos/init.insmod.<dev>.cfg`
     must exist (fail-closed `$(error)` keeps this honest).
2. Append the two hooks (tail, idempotent) to
   `vendor/google_devices/<dev>/{BoardConfig.mk,<dev>.mk}`.
3. `rm -f out/soong/soong.<dev>.variables out/soong/soong.<dev>.extra.variables`.
4. `lunch <dev>-trunk_staging-userdebug` → expect `TARGET_PRODUCT=<dev>`,
   `TARGET_BOARD_PLATFORM=<soc>`, `GUARDTALK_RADIO_EXCISED=true`,
   `PRODUCT_MODEL=GuardTalk <model>`, and a blocklist that resolves to the
   variant's canonical file (not a sibling variant's).
5. `m dist -j"$(nproc)"`; then run the FLASH smoke-test + stamp recipe in
   `CAIMAN_PORT_FLASH.md`.

**Divergences a future device must adjust** (everything else is data-driven):
the kernel family/version in `guardtalk-insmod.mk`; the SoC in the
`BoardConfig-excised-late.mk` comment only; the `*-kernels` release flag
(`RELEASE_KERNEL_<DEV>_DIR`) resolution; and `proprietary/`-specific copy-file
paths which adevtool regenerates.

## Reverse / Rollback

- Remove the two `include` lines → shared core stops firing for caiman.
- `rm -rf vendor/guardtalk/device/caiman/` → device layer gone.
- `GUARDTALK_DEVICE` pin removal is a one-line delete once the shared-core guard lands.
- `adevtool generate-all -d caiman` regenerates the stock generated files; the
  two tail hooks are the only manual re-application needed.
