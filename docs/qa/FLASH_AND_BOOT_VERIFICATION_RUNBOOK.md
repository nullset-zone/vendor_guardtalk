# GuardTalkOS — Flash & Boot-Verification Runbook (13 devices)

**Task:** `T-EXCISE-BOOT-RUNBOOK`
**Owner:** AEGIS Backend Engineer (Panel 2)
**Authority:** Operator ruling `BOOT VERIFICATION = plan` (2026-09-26, `DEC-PORT-GEN8910-WAVE4-OPERATOR`)
**Applies to:** v1.0.0 `T-EXCISE-BOOT-SAFETY-GATE`, all 13 GuardTalk devices (Pixel Gen 8/9/10)

---

## 0. Honesty block — READ FIRST

> **This document is a PLAN. Nothing in it has been executed.**
> No device has been flashed. No device has been booted. No `fastboot` command in
> this file has been run against hardware by the author of this document.

```
BOOT_VERIFIED      = false   (no device)
LIVE_FLASH_CLAIMED = false   (no flash performed)
RESTAMP_PERFORMED  = false   (this card does not rebuild or re-stamp)
FLASH_READY        = false   (gate currently RED — see §2.3)
```

`BOOT_VERIFIED` only flips to `true` for a device when **that** device satisfies §6
end-to-end on real hardware, and the operator records the evidence. Reading this
runbook is not a boot result.

A green *host* gate (G1–G8) is a **static** result — it does not prove the kernel
will not panic (`gt-boot-safety-gate.sh` header, line 11–13). Never treat
`adb devices` == `device` as a boot signal: `adbd` comes up before the framework
and its early arrival has hidden real boot defects
(`vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md`, superseding status note).

---

## 1. Scope and device inventory

This runbook covers exactly the 13 devices in `scripts/gt-ready-devices.sh`
(`DEVICES` block, lines 74–86) and `scripts/flash-from-remote.sh`
(`normalize_device`, lines 277–319).

| # | Device | Model | Bundle alias (`releases/desktop-flash/`) | Platform family | Boot chain | Firmware cleanup |
|---|--------|-------|------------------------------------------|-----------------|------------|------------------|
| 1 | `shiba` | Pixel 8 | `shiba-latest` | standard | `GT_BOOT_CHAIN=gt` | uart + **fips** + dpm |
| 2 | `husky` | Pixel 8 Pro | `husky-latest` | standard | `gt` | uart + **fips** + dpm |
| 3 | `akita` | Pixel 8a | `akita-latest` | standard | `gt` | uart + **fips** + dpm |
| 4 | `tokay` | Pixel 9 | `latest` | standard | `gt` | uart + **fips** + dpm |
| 5 | `caiman` | Pixel 9 Pro | `caiman-latest` | standard | `gt` | uart + **fips** + dpm |
| 6 | `komodo` | Pixel 9 Pro XL | `komodo-latest` | standard | `gt` | uart + **fips** + dpm |
| 7 | `tegu` | Pixel 9a | `tegu-latest` | standard | `gt` | uart + **fips** + dpm |
| 8 | `comet` | Pixel 9 Pro Fold | `comet-latest` | standard | `gt` | uart + **fips** + dpm |
| 9 | `stallion` | Pixel 10a | `stallion-latest` | standard | `gt` | uart + **fips** + dpm |
| 10 | `frankel` | Pixel 10 | `frankel-latest` | **laguna** | `GT_BOOT_CHAIN=hybrid` | uart + dpm (**no fips**) |
| 11 | `blazer` | Pixel 10 Pro | `blazer-latest` | **laguna** | `GT_BOOT_CHAIN=hybrid` | uart + dpm (**no fips**) |
| 12 | `mustang` | Pixel 10 Pro XL | `mustang-latest` | **laguna** | `GT_BOOT_CHAIN=hybrid` | uart + dpm (**no fips**) |
| 13 | `rango` | Pixel 10 Pro Fold | `rango-latest` | **laguna** | `GT_BOOT_CHAIN=hybrid` | uart + dpm (**no fips**) |

**Laguna family** is defined once in `scripts/flash-from-remote.sh:215-220`
(`is_laguna_device` = `rango|frankel|blazer|mustang`) and once in
`scripts/gt-ready-devices.sh:108` (`LAGUNA_DEVICES`). The four laguna devices are
the only ones that (a) may use `GT_BOOT_CHAIN=hybrid`, and (b) auto-resolve a
`<dev>-rescue-boot/` stock factory chain.

**Product base / documented lunch (build-time only).** This runbook flashes
**pre-built bundles**; it does **not** rebuild. The product base is the codename
itself (`TARGET_PRODUCT=<codename>`; `AndroidProducts.mk` +
`vendor/google_devices/<codename>/<codename>.mk` → `PRODUCT_NAME := <codename>`).
The documented build lunch (recorded in the shipped `README-FLASH-DESKTOP.md`
`Variant:` line, or for laguna in `DEC-PORT-GEN8910-WAVE3-OPERATOR.md:40`) is:

| Device | Documented lunch |
|--------|------------------|
| shiba, husky, akita, caiman, komodo, tegu, comet, stallion | `<codename>-trunk_staging-userdebug` |
| frankel, blazer, mustang, rango | `<codename>-trunk_staging-userdebug` |
| tokay | `tokay-trunk_staging-userdebug` (stamp record) — also documented as `tokay-cur-user` in `vendor/guardtalk/README.md` and `vendor/guardtalk/docs/FLASH.md` |

Both release configs exist in-tree (`build/release/release_configs/{cur,trunk_staging,user,userdebug}.textproto`);
`lunch` is defined in `build/envsetup.sh`. **Rebuild is a different card**
(`T-EXCISE-REBUILD-RESTAMP-13`, operator-gated) — do not rebuild here.

---

## 2. PRE-FLIGHT (run before touching a device)

Run all of §2.1–§2.5 on the **build host** (`/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`)
and on the **operator host** (the Mac with `fastboot`/`adb`). Every command below
was existence-checked; raw output is in
`.agent-comm/evidence/T-EXCISE-BOOT-RUNBOOK/existence_checks.out`.

### 2.1 Host tools

```bash
fastboot --version      # MUST be >= 35.0.1 (flash-from-remote.sh:224 require_fastboot_min_version)
adb version
ssh -V ; scp -h 2>&1 | head -1
command -v debugfs python3 sha256sum
```

`flash-from-remote.sh` itself fails closed if `fastboot` is older than 35.0.1, or if
`fastboot`/`ssh`/`scp` are absent (`step "0/8"`, lines 842–844).

### 2.2 Bundle readiness (per device)

```bash
bash scripts/gt-ready-devices.sh
```

Expected: one TSV line per device, `STATUS` ∈ {`READY`, `BUILD-OK`, `PENDING`}.
Observed 2026-09-27 (`.agent-comm/evidence/T-EXCISE-BOOT-RUNBOOK/gt-ready-devices.tsv`,
exit `0`): the 9 standard devices `READY`; the 4 laguna devices **`BUILD-OK`**
(never `READY` — not boot-proven). `BUILD-OK` is *intact on the host*; it is not a
boot guarantee.

### 2.3 Boot-safety gate must be green FOR THAT DEVICE

```bash
bash .agent-comm/tools/gt-boot-safety-gate.sh --device <codename> --verify-sums --json
# all 13 at once:
bash .agent-comm/tools/gt-boot-safety-gate.sh --all-devices --verify-sums --json
```

**Do not flash a device whose gate is not green.** Observed 2026-09-27
(`.agent-comm/evidence/T-EXCISE-BOOT-RUNBOOK/gate-all-devices.json`, exit `1`):
`devices=13 gate-fail=13` — **G1/G2/G3/G6/G7 PASS on all 13, but G5 FAILS on all 13**
with `forbidden=7` (the known `T-EXCISE-G5-BUNDLE-SKEW` finding). This is a
**pre-rebuild** state; the gate is expected to reach `gate-fail=0` only after
`T-EXCISE-REBUILD-RESTAMP-13` produces re-stamped bundles. **Gate-RED today ⇒ the
runbook must not be executed yet.** The gate's own honesty header prints
`LIVE_FLASH_CLAIMED=false  FLASH_READY=false  BOOT_VERIFIED=false`.

### 2.4 Artifact existence + hash match

```bash
for d in shiba husky akita tokay caiman komodo tegu comet frankel blazer mustang stallion rango; do
  if [ "$d" = tokay ]; then b=releases/desktop-flash/latest; else b=releases/desktop-flash/$d-latest; fi
  echo "== $d ($b) =="
  ( cd "$b" && sha256sum -c SHA256SUMS ) || echo "SHA MISMATCH: $d"
done
```

Expected: every file `OK`. Observed 2026-09-27: all 13 pointers resolve, all 13
carry `SHA256SUMS` (9 bundles with 18 `.img`, the 4 laguna bundles with 20 `.img`
incl. `super.img`). Evidence: `existence_checks.out`.

Also confirm the **flash-script required file set** exists in each bundle
(`scripts/gt-ready-devices.sh:88-92` `REQUIRED`): `bootloader.img radio.img
boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img dtbo.img
vbmeta.img vbmeta_system.img vbmeta_vendor.img system.img system_ext.img
product.img vendor.img vendor_dlkm.img system_dlkm.img super_empty.img`.

### 2.5 Dry-run the flash flow (no hardware)

```bash
bash vendor/guardtalk/docs/qa/verify_remediate_b6_flash_sop_host.sh
```

This stubs `fastboot`/`adb`/`ssh`/`scp` and runs the real `flash-from-remote.sh`
end-to-end (default path, `CAPTURE_LOGS=1` fallback capture, and a dead-adb
tolerance case). Observed 2026-09-27: `PASS=16 FAIL=0`, exit `0`
(`.agent-comm/evidence/T-EXCISE-BOOT-RUNBOOK/b6_flash_sop.out`).

### 2.6 Device preparation (per device, on the bench)

- Battery ≥ 50 %; known-good USB-C data cable (not charge-only); only **one**
  device plugged in (the script fails closed if `fastboot product` ≠ `DEVICE`, lines 876–880).
- Bootloader unlocked (`fastboot getvar unlocked` → `yes`; script fails closed
  otherwise, lines 923–930). Unlock wipes the phone:
  `adb reboot bootloader && fastboot flashing unlock`.
- Keep the matching **stock factory image** and the `<dev>-rescue-boot/` chain
  available for rollback (§9).
- The laguna bundles carry a diagnostic fetch channel probe (§7.4); run it
  **before** the flash cycle (read-only, harmless).

### 2.7 Sync the flash helper to the operator host

```bash
mkdir -p ~/GuardTalk-flash
scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/scripts/flash-from-remote.sh \
    ~/GuardTalk-flash/flash-from-remote.sh
chmod +x ~/GuardTalk-flash/flash-from-remote.sh
```

The canonical remote defaults are `REMOTE_HOST=oss-c1@192.168.2.220` and
`REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`
(`flash-from-remote.sh:120-121`). Some **older** bundle READMEs still print
`openstatestack@192.168.1.4` — that host is wrong; use the script default or set
`REMOTE_HOST` explicitly.

---

## 3. Common flash procedure (what the script does)

For every device, `flash-from-remote.sh` runs the same 8 steps. The **only**
per-device variation is `DEVICE`, `GT_BOOT_CHAIN` (laguna), the firmware-cleanup
profile, and which bundle the pointer resolves.

| Step | Action | Key artifacts |
|------|--------|---------------|
| 0/8 | Sanity + device detect + fail-closed gates (`fastboot ≥ 35.0.1`, unlocked, product match, laguna BT blocklist) | — |
| 1/8 | `scp` images from `REMOTE_BUILD_DIR` to `LOCAL_WORK_DIR` | all images below |
| 2/8 | Bootloader dual-slot (`--set-active=other` dance) + `radio` + `avb_custom_key` + GrapheneOS cleanup | `bootloader.img`, `radio.img`, `avb_pkmd.bin` |
| 3/8 | Wipe `userdata` + `metadata` | — |
| 4/8 | Enter fastbootd (`fastboot reboot fastboot`); laguna first flashes the stock rescue chain | `<dev>-rescue-boot/*` (laguna) |
| 5/8 | Flash logicals: **`super.img`** where present, else `wipe-super` + per-partition | `super.img` **or** `super_empty.img` + `system/system_ext/product/vendor/vendor_dlkm/system_dlkm.img` |
| 6/8 | GuardTalk boot chain (skipped when `GT_BOOT_CHAIN=hybrid`) + dtbo | `boot.img init_boot.img vendor_boot.img vendor_kernel_boot.img pvmfw.img` (slot), `dtbo.img` |
| 7/8 | Single vbmeta pass (`--disable-verity --disable-verification`) + `--set-active` | `vbmeta.img vbmeta_system.img vbmeta_vendor.img` |
| 8/8 | `fastboot reboot`; watch ≤ `BOOT_WATCH_SECS` (default 120 s); push `init.insmod.<dev>.cfg` via adb (all but tokay) | `init.insmod.<dev>.cfg` |

**Slot / AVB expectations:** the script flashes the **current** slot and then
`--set-active=<slot>` to reset `slot-retry-count` (lines 1546–1550). vbmeta is
always Flags:3 (disable-verity + disable-verification) and `avb_custom_key` is
programmed with `avb_pkmd.bin` (AOSP **public test** AVB blob). Slot `_b` is not
used as the boot slot; for laguna the diagnostic `fetch` channel targets
`vendor_boot_b` precisely because it is not the boot slot.

### 3.1 Optional operator flags (never auto-selected)

| Flag | Effect | When |
|------|--------|------|
| `GT_BOOT_CHAIN=hybrid` | Keeps the step-4 stock factory rescue boot chain; **skips** step-6 GuardTalk boot flash; step-7 vbmeta still runs | **laguna only** (frankel/blazer/mustang/rango) |
| `RADIO_MODE=erase` | Do **not** flash `radio.img`; `fastboot erase radio` instead | operator opt-in (baseband-free flash; Tier-B residual) |
| `CAPTURE_LOGS=1` | Best-effort post-flash debug capture dir (fastboot + adb) | when you want extra artifacts |
| `SKIP_BT_BLOCKLIST_GUARD=1` | **UNSAFE** bypass of the laguna `nitrous.ko` fail-closed guard | emergency only |
| `ALLOW_AVB_KEY_FAIL=1` | Continue if `avb_custom_key` flash fails | emergency only |
| `AUTO_HARVEST=0` / `AUTO_RECOVERY_HARVEST=1` | Disable / force the failure-harvest recovery pstore pull | triage |

### 3.2 Flash command template

```bash
cd ~/GuardTalk-flash
export REMOTE_HOST=oss-c1@192.168.2.220
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
unset REMOTE_BUILD_DIR REMOTE_KEY_DIR          # let DEVICE auto-resolve <dev>-latest
DEVICE=<codename> bash ./flash-from-remote.sh
```

- **laguna** devices must add `GT_BOOT_CHAIN=hybrid`:
  `DEVICE=blazer GT_BOOT_CHAIN=hybrid bash ./flash-from-remote.sh`
- On a **bisect** stamp, set `REMOTE_BUILD_DIR` to the explicit stamp path; the
  script then keeps `avb_pkmd.bin` with that stamp (`apply_remote_paths`, 406–419).
- The script **refuses** `GT_BOOT_CHAIN=hybrid` on a non-laguna device (lines 887–889).

Script exit codes: `0` = adb reached (or adb-unauthorized); `2` = boot fell back
to fastboot (failure, auto-harvest ran); `3` = neither adb nor fastboot within
`BOOT_WATCH_SECS`. Exit `2`/`3` is **not** a boot result — go to §7.

---

## 4. Per-device flash + boot-verification sections

> Each section is copy-pasteable. Run §2 first. `BOOT_VERIFIED=false` for **every**
> device until §6 passes on hardware **for that device**.

### 4.1 `shiba` — Pixel 8

- **Product base:** `shiba`. **Documented lunch:** `shiba-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/shiba-latest` → `shiba-20260923-094055` (18 `.img`; no `super.img`).
- **Group:** standard — `GT_BOOT_CHAIN=gt`; firmware cleanup uart + **fips** + dpm.
- **Extra:** `init.insmod.shiba.cfg` (pushed post-boot).

```bash
cd ~/GuardTalk-flash
DEVICE=shiba bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; then §6 all green on `shiba`.
**Caveat:** G3 allowlist historically asserted `rt6160-regulator` on shiba/husky
(false positive, now family-scoped — `B-EXCISE-G3-RT6160_REPORT.md`); G3 is green
13/13 as of this run.

### 4.2 `husky` — Pixel 8 Pro

- **Product base:** `husky`. **Documented lunch:** `husky-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/husky-latest` → `husky-20260923-095309` (18 `.img`).
- **Group:** standard — `gt`; uart + **fips** + dpm. **Extra:** `init.insmod.husky.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=husky bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `husky`.
**Caveat:** same `rt6160-regulator` G3 history as shiba (resolved).

### 4.3 `akita` — Pixel 8a

- **Product base:** `akita`. **Documented lunch:** `akita-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/akita-latest` → `akita-20260725-101434` (18 `.img`).
- **Group:** standard — `gt`; uart + **fips** + dpm. **Extra:** `init.insmod.akita.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=akita bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `akita`.
**Caveat:** akita is one of two devices with a pstore-harvest arm
(`flash-from-remote.sh:1245`) — automatic recovery harvest is available.

### 4.4 `tokay` — Pixel 9

- **Product base:** `tokay`. **Documented lunch:** `tokay-trunk_staging-userdebug`
  (stamp) / `tokay-cur-user` (`FLASH.md`, `vendor/guardtalk/README.md`).
- **Bundle:** `releases/desktop-flash/latest` → `tokay-20260725-102506` (18 `.img`). **Note the legacy alias `latest`, not `tokay-latest`.**
- **Group:** standard — `gt`; uart + **fips** + dpm. **No** `init.insmod` (tokay is the only device without one).

```bash
cd ~/GuardTalk-flash
DEVICE=tokay bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `tokay`.
**Caveat:** tokay keeps its legacy `latest` pointer by decree
(`flash-from-remote.sh:22`, `apply_remote_paths:346-350`). Do not repoint it.

### 4.5 `caiman` — Pixel 9 Pro

- **Product base:** `caiman`. **Documented lunch:** `caiman-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/caiman-latest` → `caiman-20260922-090535` (18 `.img`).
- **Group:** standard — `gt`; uart + **fips** + dpm. **Extra:** `init.insmod.caiman.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=caiman bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `caiman`.

### 4.6 `komodo` — Pixel 9 Pro XL

- **Product base:** `komodo`. **Documented lunch:** `komodo-trunk_staging-userdebug`
  (also `komodo-trunk_staging-user` in the remediation docs).
- **Bundle:** `releases/desktop-flash/komodo-latest` → `komodo-20260915-063833` (18 `.img`).
- **Group:** standard — `gt`; uart + **fips** + dpm. **Extra:** `init.insmod.komodo.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=komodo bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `komodo`.
**Caveat:** komodo is the **rich-debug** device — `komodo-debug-latest`
(`komodo-debug-20260921-041838`) is a separate engineering sidecar, **not** the
production stamp, and its `DEBUG_FLASH_READY=false`. History: two debug stamps
failed on a `LocationManager`-null NPE class
(`vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md`). Verifying a boot here requires the
§6 `sys.boot_completed=1` + stability checks, not `adb devices`.

### 4.7 `tegu` — Pixel 9a

- **Product base:** `tegu`. **Documented lunch:** `tegu-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/tegu-latest` → `tegu-20260922-164700` (18 `.img`).
- **Group:** standard — `gt`; uart + **fips** + dpm. **Extra:** `init.insmod.tegu.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=tegu bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `tegu`.

### 4.8 `comet` — Pixel 9 Pro Fold

- **Product base:** `comet`. **Documented lunch:** `comet-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/comet-latest` → `comet-20260922-160129` (18 `.img`).
- **Group:** standard — `gt`; uart + **fips** + dpm. **Extra:** `init.insmod.comet.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=comet bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `comet`.
**Caveat:** comet shows `unbacked=2` in G5 (one more than the other 12); this is a
*static-coherence* count, not a boot result, but it must not regress.

### 4.9 `stallion` — Pixel 10a

- **Product base:** `stallion`. **Documented lunch:** `stallion-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/stallion-latest` → `stallion-20260923-100618` (18 `.img`).
- **Group:** standard (not laguna) — `gt`; uart + **fips** + dpm. **Extra:** `init.insmod.stallion.cfg`.
- **Caveat:** stallion is the newest port and is **not** in the laguna set, so it
  does **not** get the hybrid boot chain nor a rescue bundle. See
  `vendor/guardtalk/docs/STALLION_PORT_RESOLUTION.md`.

```bash
cd ~/GuardTalk-flash
DEVICE=stallion bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `stallion`.

### 4.10 `frankel` — Pixel 10 (laguna)

- **Product base:** `frankel`. **Documented lunch:** `frankel-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/frankel-latest` → `frankel-20260923-094457` (20 `.img`, incl. `super.img`).
- **Group:** **laguna** — `GT_BOOT_CHAIN=hybrid`; uart + dpm (**no fips**).
- **Rescue chain:** `releases/desktop-flash/frankel-rescue-boot/` (7 `.img`).
- **Extra:** `init.insmod.frankel.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=frankel GT_BOOT_CHAIN=hybrid bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `frankel`.
**Caveat:** **unresolved first-flash risk** — see §5 (laguna/blazer apexd class).
`frankel` has **never** been flashed on hardware; only `rango` hybrid has any
on-device evidence, and `fullgt` is ABL-rejected (`AB 11311112`).

### 4.11 `blazer` — Pixel 10 Pro (laguna) — **primary apexd caveat**

- **Product base:** `blazer`. **Documented lunch:** `blazer-trunk_staging-userdebug`
  (`DEC-PORT-GEN8910-WAVE3-OPERATOR.md:40`).
- **Bundle:** `releases/desktop-flash/blazer-latest` → `blazer-20260923-090842` (20 `.img`, incl. `super.img`).
- **Group:** **laguna** — `GT_BOOT_CHAIN=hybrid`; uart + dpm (**no fips**).
- **Rescue chain:** `releases/desktop-flash/blazer-rescue-boot/` (7 `.img`).
- **Extra:** `init.insmod.blazer.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=blazer GT_BOOT_CHAIN=hybrid bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `blazer`.
**Caveat (BLOCKING, unresolved):** blazer is the device that surfaced the
**`apexd-bootstrap`** failure — boot dies ~17–18 s with reboot mode `0xfc` and
returns to the bootloader. Root cause is **still unknown**
(`B-LAGUNA-FETCH-CHANNEL.md` §6). Do **not** flash `fullgt` on blazer (ABL rejects
it). Always harvest immediately (§7). The diagnostic klog bundle
`blazer-20260924-141223-klog` exists but its `metadata` fetch target is **not
fetch-whitelisted** — use the corrected `vendor_boot_b` channel (§7.4).

### 4.12 `mustang` — Pixel 10 Pro XL (laguna)

- **Product base:** `mustang`. **Documented lunch:** `mustang-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/mustang-latest` → `mustang-20260923-094541` (20 `.img`, incl. `super.img`).
- **Group:** **laguna** — `GT_BOOT_CHAIN=hybrid`; uart + dpm (**no fips**).
- **Rescue chain:** `releases/desktop-flash/mustang-rescue-boot/` (7 `.img`).
- **Extra:** `init.insmod.mustang.cfg`.

```bash
cd ~/GuardTalk-flash
DEVICE=mustang GT_BOOT_CHAIN=hybrid bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `mustang`.
**Caveat:** `mustang-latest` ownership/`nitrous.ko` blocklist is guarded
fail-closed (`verify_bt_blocklist_guard`; defect `E-10`). Do not set
`SKIP_BT_BLOCKLIST_GUARD=1` unless the operator explicitly accepts the BT
power/rfkill risk. Same apexd caveat as blazer (§5).

### 4.13 `rango` — Pixel 10 Pro Fold (laguna)

- **Product base:** `rango`. **Documented lunch:** `rango-trunk_staging-userdebug`.
- **Bundle:** `releases/desktop-flash/rango-latest` → `rango-20260802-130756` (20 `.img`, incl. `super.img`).
  **Note:** this stamp ships `nitrous=0` until the re-stamp lands (operator ruling).
- **Group:** **laguna** — `GT_BOOT_CHAIN=hybrid`; uart + dpm (**no fips**).
- **Rescue chain:** `releases/desktop-flash/rango-rescue-boot/` (7 `.img`).
- **Extra:** `init.insmod.rango.cfg` and (bundle extra) `vendor_boot_diag.img` (diagnostic; not flashed by the script).

```bash
cd ~/GuardTalk-flash
DEVICE=rango GT_BOOT_CHAIN=hybrid bash ./flash-from-remote.sh
```

**Pass criteria:** script exits `0`; §6 all green on `rango`.
**Caveat:** rango is the **only** laguna device with any on-device boot evidence,
and that evidence is a **failure**: boot reaches `apexd-bootstrap` then
`reboot,bootloader,bootstrap-apexd-failed` → `Reboot mode: 0xfc` (~18 s).
Operator stamps `103641`/`111004`/`123756` all failed at `0xfc`
(`releases/desktop-flash/rango-latest/README-FLASH-DESKTOP.md`). rango is therefore
**not** boot-proven; `BOOT_VERIFIED=false`.

---

## 5. Device-specific caveat — laguna / blazer `apexd-bootstrap`

**Scope:** `rango`, `frankel`, `blazer`, `mustang` (the laguna family).

1. **`fullgt` is ABL-rejected on-device** (`AB 11311112`). Never flash the full
   GuardTalk laguna boot chain. Use `GT_BOOT_CHAIN=hybrid` only.
2. **Hybrid composition** (what `GT_BOOT_CHAIN=hybrid` keeps): factory
   `BP4A.260205.001` boot chain + `vendor_dlkm`/`system_dlkm`, GuardTalkOS
   `system/system_ext/product/vendor` logicals, flags:3 vbmeta (16384 B),
   `com.android.virt.apex` **dropped**, apexd bootstrap set **stock**
   `runtime`+`i18n`+`tzdata`.
3. **Failure signature:** Google G logo → bootloader in ~17–20 s (AVB/verity), or
   init exit `0x7f00`, or reboot mode `0xfc` (the `apexd-bootstrap`
   `reboot_on_failure`). `0x7f00` = init/exec kill (status 127); `0x00000100` =
   init exit status 1; `0xbaba`/mode `0x0` = kernel panic.
4. **Root cause: unknown** (`B-LAGUNA-FETCH-CHANNEL.md` §6: "laguna GT root cause
   is still unknown"). The apexd point is an **inference from the reboot reason**,
   not an observation of the kernel log. Multiple sole-cause hypotheses were
   **falsified** on-device (stockhwasan-sole, flash-parity-sole, stockselinux-sole,
   bootstrap-set APEX-content-sole, stock-init-sole). Do not restate any as a fix.
5. **Consequence for this runbook:** a laguna device that reaches the bootloader is
   a *known possible outcome*, not an operator error. Harvest immediately (§7) and
   record `BOOT_VERIFIED=false`.
6. **Bootloader-generation deviation (recorded, not asserted as cause):** the
   GuardTalk blazer/frankel/mustang builds ship bootloader `deepspace-17.1-15016913`,
   while factory BP4A.260205.001 ships `deepspace-16.4-14451019`
   (`blazer-rescue-boot/README.md`). Recorded because it is real and sits exactly
   on the looping devices.

---

## 6. Post-boot verification checklist (shared)

Run on the **operator host** after the flash script reports success. **A device is
only `BOOT_VERIFIED=true` when all of §6.1–§6.6 pass on that device**, and the
operator records the outputs.

### 6.1 Boot completed (not just adbd)

```bash
adb wait-for-device
adb shell getprop sys.boot_completed        # PASS: 1
adb shell getprop ro.boot.slot_suffix       # record
adb shell getprop ro.product.model          # record (rebrand check, e.g. "GuardTalk Pixel 9")
```

`adb devices` == `device` is **not** sufficient (see §0). PASS = `sys.boot_completed=1`.

### 6.2 Stability — no Zygote / system_server death-loop

```bash
adb shell cat /proc/uptime                  # PASS: > 120 s uptime
adb shell dumpsys activity exit-info        # PASS: no repeated system_server crash
adb shell logcat -b all -d | grep -nE \
  'FATAL EXCEPTION|\*\*\* FATAL EXCEPTION IN SYSTEM PROCESS|RuntimeInit|Shutting down VM|NoClassDefFoundError|ClassNotFoundException|System server died' \
  && echo "REVIEW" || echo "no crash patterns"
```

PASS = device stays up past 120 s and the grep returns no crash patterns
(baseline: `T-REMEDIATE-B6-FASTBOOT-RC_EVIDENCE.md`, `KOMODO_DEBUG_FLASH.md`).

### 6.3 Radio-eXcision status

```bash
adb shell getprop ro.guardtalk.radio.excised      # PASS: 1
adb shell getprop androidboot.radio.disabled      # record
adb shell service list | grep -ciE 'radio|ril'    # PASS: 0 / informational
```

PASS = `ro.guardtalk.radio.excised=1` and no radio/ril services listed.
(Baseline: `verify-on-device.sh` §7; `verify-radio-excision.sh`.)

### 6.4 Feature exclusions live (HCH grace layer)

```bash
adb shell pm has-system-feature android.hardware.bluetooth        # PASS: false
adb shell pm has-system-feature android.hardware.bluetooth_le     # PASS: false
adb shell pm has-system-feature android.hardware.location         # PASS: false
adb shell pm has-system-feature android.hardware.location.network # PASS: false
adb shell pm has-system-feature android.hardware.nfc              # PASS: false
adb shell pm has-system-feature android.hardware.fingerprint      # PASS: false
adb shell lsmod | grep -ci nitrous                                # PASS: 0
```

(Baseline: `vendor/guardtalk/scripts/verify-on-device.sh` §3–6, §9c.)

### 6.5 apexd healthy

Note: `apexd` and `apexd-bootstrap` are `oneshot`/`disabled` services
(`system/apex/apexd/apexd.rc`), so `init.svc.apexd` is **not** reliably `running`
after boot — do not use it as the pass signal. Use mount + boot state:

```bash
adb shell getprop sys.boot_completed        # PASS: 1
adb shell getprop ro.apex.updatable         # record
adb shell ls /apex | grep -c '\.apex'       # PASS: > 0 (apex mounts present)
adb shell ls /apex | grep -c 'com.android.runtime'
```

PASS = boot completed, `/apex` carries the mounted APEXes, and the earlier
`fastboot oem dmesg` showed **no** `bootstrap-apexd-failed` (the laguna failure
point is `apexd-bootstrap`, so this is the **decisive** check for the laguna
family).

### 6.6 On-device acceptance matrix + host re-gate

```bash
# on the operator host (device attached): full product acceptance matrix
bash vendor/guardtalk/scripts/verify-on-device.sh

# on the build host: re-run the boot-safety gate for this device, post-flash
bash .agent-comm/tools/gt-boot-safety-gate.sh --device <codename> --verify-sums --json
```

PASS = `verify-on-device.sh` `FAIL=0`, and the gate reports the device green
(post `T-EXCISE-REBUILD-RESTAMP-13`).

**Also run (build host), per AGENTS.md:**

```bash
bash vendor/guardtalk/checkin/host/verify_host.sh                    # PASS=21 FAIL=0 HOLD=2
python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v
```

### 6.7 Record the result

```bash
cat > .agent-comm/evidence/T-EXCISE-BOOT-RUNBOOK/<codename>-boot-$(date -u +%Y%m%dT%H%M%SZ).txt <<'EOF'
device=<codename>
BOOT_VERIFIED=<true|false>
LIVE_FLASH_CLAIMED=<true|false>
sys.boot_completed=<value>
ro.guardtalk.radio.excised=<value>
apexd=<value>
uptime_s=<value>
notes=
EOF
```

Until that file exists with `BOOT_VERIFIED=true`, the device stays `false`.

---

## 7. FAILURE TRIAGE (device did not boot)

### 7.1 What the flash script already captures

On a `fastboot` fallback (exit `2`) the script **automatically**:
- resets retries (`fastboot --set-active=a`, line 1643), and
- runs `auto_harvest_on_failure` (lines 1196–1332), which writes a timestamped
  `harvest-<device>-<ts>/` dir containing `oem-dmesg.txt`, `oem-ramdump-klog.txt`,
  `bcd-{command,status,recovery,stage}.txt`, and (where reachable) `console-ramoops-0.txt`,
  `dmesg-ramoops-0.txt`, `pmsg-ramoops-0.txt`, `metadata-apex.txt`, plus
  `oem-discriminator.txt` and `discriminator.txt`.
- best-effort uploads the harvest to `<REMOTE_TREE>/runtime/harvests/` (lines 1229–1237).

`CAPTURE_LOGS=1` additionally produces `flash-capture-<device>-<ts>/` (fastboot +
adb snapshots; the post-adb fallback window is covered).

### 7.2 Read the bootloader-resident signal first

```bash
fastboot oem dmesg | tee ~/<codename>-dmesg.txt
fastboot oem dmesg | grep -E 'Reboot mode|AB Decisions|exitcode|0xbaba|0xfc|0x7f00|0x00000100|Attempted to kill'
fastboot oem bcd read command ; fastboot oem bcd read status
fastboot oem bcd read recovery ; fastboot oem bcd read stage
fastboot getvar slot-retry-count:a ; fastboot getvar slot-unbootable:a
fastboot getvar slot-retry-count:b ; fastboot getvar slot-unbootable:b
```

### 7.3 Classification table (do not invent PASS)

| Observation | Class | Meaning |
|-------------|-------|---------|
| `Reboot mode: 0xfc` (~17–20 s, → bootloader) | `apexd-bootstrap` `reboot_on_failure` | laguna apexd class (§5) |
| `exitcode=0x00007f00` | init/exec kill (status 127) | `/system`/first-stage mount, init exec |
| `exitcode=0x00000100` | init exit status 1 | init failure (KP class; `141438` stockinit failed) |
| `0xbaba` / mode `0x0` | kernel PANIC | kernel/driver |
| G logo → bootloader, no code | AVB/verity | boot-chain mismatch (laguna) |
| `adb` up but `sys.boot_completed` never `1` | userspace crash/hang | system_server NPE / service hang (komodo class) |

### 7.4 Kernel-log capture — the CORRECTED channel (laguna)

**Facts (source of truth: `system/core/fastboot/device/commands.cpp:896-901`):**

```cpp
static constexpr std::array<const char*, 3> kAllowedPartitions{
        "vendor_boot",
        "vendor_boot_a",
        "vendor_boot_b",
};
```

`fastboot fetch` **only** accepts `vendor_boot[_a|_b]`. It is also build-gated on
`FB_ENABLE_FETCH` (debuggable builds only; `system/core/fastboot/Android.bp:147`,
`device/variables.cpp:526-535`). Therefore:

- the shipped diagnostic bundle `blazer-20260924-141223-klog` writes to the
  `metadata` partition and its README advertises `fastboot fetch metadata …` —
  **that fetch is refused by design.** The earlier `[STOP]` conclusion was a
  **false negative** (`B-LAGUNA-FETCH-CHANNEL.md` §3).
- The usable channel is **`vendor_boot_b`**: the device boots slot `_a`
  (`ro.boot.slot_suffix=_a`), so slot `b`'s `vendor_boot` is not used at boot, and
  under `GT_BOOT_CHAIN=hybrid` the GuardTalk boot chain is not flashed at all.
- Using it requires **re-targeting the injected dumper from `metadata` to
  `vendor_boot_b` and rebuilding** the diag bundle (one-path change; see
  `TO_BACKEND_T-LAGUNA-KLOG-DUMP.md`). That rebuild is **not** part of this runbook.

**Pre-flight probe (read-only, harmless — run before the flash cycle):**

```bash
fastboot getvar max-fetch-size       # a value ⇒ fetch supported (var is #ifdef-gated)
fastboot getvar dmesg                # may state the last reboot reason directly
fastboot fetch vendor_boot_b /tmp/vbb-probe.img; echo "rc=$?"; ls -la /tmp/vbb-probe.img
```

**Never redirect `stderr`** — the message is the point:

- `max-fetch-size` returns a value → `fetch` supported.
- `fetch vendor_boot_b` returns a file → channel confirmed (diag rebuild needed).
- `Fetch is only allowed on [...]` → fetch exists, whitelist differs; read the list.
- `unknown command` → bootloader genuinely lacks `fetch`; the approach must be redesigned.

**After a corrected (re-targeted) diagnostic build boots and fails:**

```bash
fastboot fetch vendor_boot_b gt-klog.img
strings gt-klog.img | sed -n '/GT-KLOG iter=/,/GT-KLOG-END/p' | tail -n 200
```

Read the **last** `=== GT-KLOG iter=<N> … / === GT-KLOG-END iter=<N> ===` pair.
(The currently shipped bundle uses `metadata`; if the operator chooses to try it
anyway, expect the whitelist refusal above — record it, do not treat it as a
device fault.)

### 7.5 Recovery / slot steps

```bash
# 1. Restore the boot slot + retries (script already does this; do it manually if needed)
fastboot set_active a
fastboot --set-active=a
fastboot getvar current-slot

# 2. Re-enter the bootloader, keep the rescue chain available for laguna
fastboot reboot-bootloader

# 3. If the device is looping before fastbootd, re-flash the stock rescue chain
cd ~/GuardTalk-flash
# laguna: the script flashes <dev>-rescue-boot/ automatically before fastbootd (step 4)
```

For laguna, `AUTO_RECOVERY_HARVEST=1` forces the recovery pstore pull; by default
it is **skipped** for laguna because `oem bcd write` is not honored there
(`flash-from-remote.sh:1251-1258`) and would park the phone on "No command".

Manual pstore pull (device in recovery, `adb` reachable):

```bash
adb root
adb shell 'cat /sys/fs/pstore/console-ramoops-0' > console-ramoops-0.txt
adb shell 'cat /sys/fs/pstore/dmesg-ramoops-0'   > dmesg-ramoops-0.txt
```

If `console-ramoops-0` is empty, ramoops did not survive the ABL handoff: the next
path is UART (`fastboot oem uart enable` + USB-serial 115200 8N1).

---

## 8. Rollback path

1. **Soft rollback (recommended):** `fastboot set_active a` (or `b`) to return to the
   previous slot, then reboot. The previous slot's boot chain is intact unless the
   bootloader/radio step re-flashed both slots (it does — so this only helps if a
   prior good system still exists on that slot).
2. **Rescue rollback (laguna):** flash
   `releases/desktop-flash/<codename>-rescue-boot/*.img` (stock factory
   `BP4A.260205.001` boot chain) — the script does this automatically at step 4.
3. **Factory rollback (all devices):** flash the matching Google factory image
   (`vendor/adevtool/dl/<codename>-<build>-factory-*.zip`) via
   `flash-all.sh`, or use the web installer. Keep the factory zip on hand before
   the flash cycle.
4. **Do not** attempt to "fix" a failed boot by flashing `fullgt` on laguna
   (ABL-rejected).

---

## 9. Status ledger (PLAN — all false)

| Device | BOOT_VERIFIED | LIVE_FLASH_CLAIMED | Note |
|--------|---------------|--------------------|------|
| shiba | false | false | §4.1 |
| husky | false | false | §4.2 |
| akita | false | false | §4.3 |
| tokay | false | false | §4.4 (legacy `latest` alias) |
| caiman | false | false | §4.5 |
| komodo | false | false | §4.6 (debug sidecar separate) |
| tegu | false | false | §4.7 |
| comet | false | false | §4.8 |
| stallion | false | false | §4.9 |
| frankel | false | false | §4.10 (laguna apexd caveat) |
| blazer | false | false | §4.11 (laguna apexd — primary) |
| mustang | false | false | §4.12 (laguna apexd) |
| rango | false | false | §4.13 (only laguna with on-device evidence; it failed) |

`RESTAMP_PERFORMED=false`. This document does not rebuild or re-stamp anything.

---

## 10. Traceability (every command → a real artifact)

| Command / file | Exists / validated |
|----------------|--------------------|
| `scripts/flash-from-remote.sh` | `bash -n` OK; runs via stub harness (16/16 PASS) |
| `scripts/gt-ready-devices.sh` | `bash -n` OK; exit 0, 13 TSV rows |
| `.agent-comm/tools/gt-boot-safety-gate.sh` + `gt_boot_safety_gate.py` | `bash -n` OK / compiles |
| `vendor/guardtalk/checkin/host/verify_host.sh` | exit 0, `PASS=21 FAIL=0 HOLD=2` |
| `vendor/guardtalk/docs/qa/verify_remediate_b6_flash_sop_host.sh` | exit 0, `PASS=16 FAIL=0` |
| `vendor/guardtalk/scripts/verify-on-device.sh` | present |
| `vendor/guardtalk/docs/qa/verify_*.sh` (64) | `bash -n` OK on all 64 |
| 13 `-latest` bundles + `SHA256SUMS` | present (§2.4) |
| 4 `<dev>-rescue-boot/` chains | present, 7 `.img` each |
| `fastboot fetch` whitelist `vendor_boot[_a|_b]` | `system/core/fastboot/device/commands.cpp:896-901` |
| `build/release/release_configs/{cur,trunk_staging,user,userdebug}.textproto` | present |
| host tools `fastboot adb ssh scp debugfs python3 sha256sum` | present (build host) |

Raw outputs: `.agent-comm/evidence/T-EXCISE-BOOT-RUNBOOK/`
(`existence_checks.out`, `bashn.out`, `verify_host.out`, `b6_flash_sop.out`,
`gt-ready-devices.tsv`, `gate-all-devices.json`).

---

*PLAN ONLY. `BOOT_VERIFIED=false` for all 13 until executed on hardware under §6.
Task `T-EXCISE-BOOT-RUNBOOK` — AEGIS Backend Engineer (Panel 2).*
