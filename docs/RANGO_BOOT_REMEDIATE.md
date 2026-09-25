# RANGO Boot Remediating — `T-RANGO-BOOT-REMEDIATE`

| Field | Value |
|-------|--------|
| Task | `T-RANGO-BOOT-REMEDIATE` |
| Date | 2026-09-16T06:28:00Z |
| Status | **REVIEW** (honest STOP; no new stamp; USB HOLD) |
| Device | Pixel 10 Pro Fold (`rango` / `laguna`) |
| Depends on | `T-FLASH-CLI-HARDEN` APPROVED |
| Flash path | `scripts/flash-from-remote.sh` + `DEVICE=rango` only |
| Latest | `rango-latest` → `rango-20260802-130756` (**unchanged**) |

USB HOLD this wave. Operator has not said flash. Do not invent PASS.
Do not advertise rango. Do not GOS-lock. Do not retarget tokay `latest`,
`akita-latest`, or `komodo-latest`.

---

## 0. Verdict

**No new named stamp.** `out/target/product/rango` can mechanically feed
`stage-rango-release.sh` (images + sepolicy hash MATCH + host `lpmake`),
but a new stamp is **not justified**:

1. Named inverted early-boot leftovers on `061630` **MATCH stock**.
2. Factory super still cannot hold this GT `system.img`.
3. Omitting `super.img` to force wipe-super is a **known `0x7f00` path**,
   not a `0xfc` bisect (`flash-from-remote.sh` L996–1001).
4. Durable `gtuserspace` was already restaged as `rango-20260820-113522`
   (not linked). Duplicating it does not move `0xfc`.

**Next bisect (USB, operator GO only):** flash already-staged
`rango-20260803-145117` (`MODE=stockvendor`). Never flashed. RQ4 #1 still
OPEN. `rango-latest` stays `130756`.

---

## 1. Bound facts (this session)

| Pin | Evidence |
|-----|----------|
| `rango-latest` | symlink inode **193110354** → `rango-20260802-130756` (target inode 199431966) |
| tokay `latest` | inode **193110379** → `tokay-20260725-102506` |
| `akita-latest` | inode **193110357** → `akita-20260725-101434` |
| `komodo-latest` | inode **193110380** → `komodo-20260915-063833` |
| `130756` SHA256SUMS | **OK** (re-hashed this session) |
| `061630` SHA256SUMS | **OK** |
| `145117` SHA256SUMS | **OK** |
| `145117` vendor vs stock | **IDENTICAL** sha256 `d8184b2b…` |
| KEEP `flash-from-remote.sh` | `cmp` IDENTICAL; `DEVICE=rango` → `rango-latest`; rescue L876/L958 rango-only; tokay\|akita\|komodo still `erase fips`; rango **no fips**; no `flashing lock` |
| USB | `adb devices` empty; `fastboot` **missing** |
| Web advertise | not touched; DEC-PORT-KOMODO-004 stays tokay+akita+komodo |

### 1.1 OUT (`out/target/product/rango`)

Last rango `m` **2026-08-20** (dir mtime 10:52:29Z). Komodo OUT is newer
(2026-09-15) but **does not overwrite** rango images.

| Artifact | State |
|---------|--------|
| `system.img` | 944,648,192 B, 2026-08-20T10:48:09Z, raw ext4 |
| `system_ext.img` / `product.img` / `vendor.img` | present |
| boot chain + `super_empty.img` + `android-info.txt` | present |
| `super.img` in OUT | **ABSENT** (stamps carry lpmake `super.img`; expected) |
| sepolicy hashes | plat / system_ext / product **MATCH**; plat sha `e7d305f7…` |
| host `lpmake` / `img2simg` / `simg2img` | present (komodo host rebuild 2026-09-15) |

**Mechanical staging: possible.** Justified new MODE: **none**.

Factory donor `system.img` is 919,552,000 B. OUT system is 944,648,192 B.
`061630` system (grown) is 1,364,082,688 B. Factory `system_a` still cannot
hold GT system (FACSUPER HOLD stands).

---

## 2. RCA roll-up (`0xfc` still apexd-bootstrap)

Failure class on every inverted/gtuserspace flash since `103641`:
`Reboot mode: 0xfc` / `reboot bootloader` / `AB 11111111` ~18s =
`apexd-bootstrap` `reboot_on_failure reboot,bootloader,bootstrap-apexd-failed`.
AVB control (`rango-avbcontrol-*`) **PASS**. `fullgt` ABL reject `11311112`.
GuardTalkOS has **never** reached adb on rango (port-day-on, 2026-07-25).

### 2.1 Falsified as sole cause (do not re-litigate)

| Probe | Stamp | Result |
|-------|-------|--------|
| tzdata / runtime / i18n | `130756` | `0xfc` |
| stock apexd | `132759` | `0xfc` |
| stock init | `141438` | KP `0x100` (class change ≠ cure) |
| stock init.rc | `150440` | `0xfc` |
| stock hwasan + GOS flash-parity | `153335` | `0xfc` |
| whole stock sepolicy | `044126` | `0xfc` |
| wholesale stock `/system/apex` | `130329` | `0xfc` |
| inverted grafts through `bflags` | `061630` | `0xfc`; flag-dump series **CLOSED** |
| facsuper metadata fields | (no stamp) | liblp fields **MATCH** factory |

### 2.2 Host leftover re-check (`061630` vs `rango-stock-userspace`)

debugfs dump + `cmp` this session. Named early-boot surfaces:

| Path | Result |
|------|--------|
| `/bin/init` | MATCH 2,771,368 |
| `/bin/apexd` | MATCH 1,083,368 |
| `/bin/ueventd` | symlink both sides (to `init`) |
| `/etc/ueventd.rc` | MATCH 3,785 |
| `/etc/init/hw/init.rc` | MATCH 57,115 |
| zygote/usb hw rc | MATCH |
| `/etc/apexd/empty_erofs.img` | MATCH 4,096 |
| `/etc/task_profiles.json` | MATCH 15,365 |
| `/etc/build_flags.json` | MATCH 124,580 |
| `/etc/aconfig_flags.pb` | MATCH 696,328 |
| plat file_contexts / sepolicy.cil / property_contexts | MATCH |
| `/etc/linker.config.pb` | MATCH 1,159 |
| `super_empty.img` vs stock | MATCH 5,184 |

Remaining delta is **zygote-late `/system` bulk** + **lpmake `system_a` size**,
not a named init/apexd/ueventd leftover. No new `/system/etc` graft MODE.

### 2.3 Still OPEN

| Candidate | Why still open | Next |
|-----------|----------------|------|
| **RQ4 #1 vendor/loop/ueventd environment** | `145117` staged; vendor **byte-identical** to stock; **never flashed** | USB: `REMOTE_BUILD_DIR=…/rango-20260803-145117` |
| **RQ1 flash-path / host-side `update-super`** | All FAIL stamps flash lpmake monolithic `super.img` via fastbootd. Official `fastboot update` builds super on the host from `super_empty` (no fastbootd). Untested. | Later T card. **Not** wipe-super fallback. **Not** GOS `flashing lock`. Pixel 9 path unchanged. |
| userdebug vs user | LOW | only after 145117 bind |

**Do not** stage a stamp without `super.img`. Script comment L996–1001:
wipe-super + per-logical metadata made factory first-stage fail
`execv(/system/bin/init)` → `0x7f00`. That is a regression class, not a
`0xfc` probe.

---

## 3. Next bisect (USB HOLD until operator says flash)

### 3.1 This wave — do not flash

No USB. `fastboot` missing on this host. `adb` empty.

### 3.2 First operator flash (existing stamp; no `rango-latest`)

```bash
fastboot set_active a
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_TREE=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-20260803-145117
export REMOTE_KEY_DIR=$REMOTE_BUILD_DIR
DEVICE=rango bash scripts/flash-from-remote.sh
# on fail immediately:
fastboot oem dmesg | tee ~/rango-dmesg-145117.txt
```

Discriminators:

| Outcome | Meaning | Follow-up |
|---------|---------|----------|
| adb | vendor environment was the `0xfc` trigger | Architect may fold vendor into durable; still no `--link-latest` until PASS |
| `0xfc` ~18s `AB 11111111` | RQ4 #1 **FALSIFIED** as sole cause | next T: rango-gated official `fastboot update` (host-side super from `super_empty`); KEEP script change, Pixel 9 firmware profile **untouched** |
| FAST `0x7f00` / KP | documented sepolicy incoherence (stock vendor precompiled ≠ GT plat) | **not** a loop/ueventd result; do not promote |
| `0x100` / `0xbaba` | class change | stop; Architect re-bind |

Do **not** re-flash `061630`. Do **not** flash `113522` as a fix (same
durable class as `130756`). Do **not** flash `fullgt`.

### 3.3 After 145117, if still `0xfc` — flash-path T card (not this card)

Scope sketch only (Architect dispatches):

- Keep `flash-from-remote.sh` + `DEVICE=rango`.
- Rango-only: assemble `image-rango-$STAMP.zip` from stamp logicals +
  `fastboot-info.txt` / `android-info.txt` / `super_empty.img` and use
  `fastboot -w --skip-reboot update` for the OS step (RQ1).
- Do **not** apply `flashing lock`.
- Do **not** change tokay/akita/komodo firmware-cleanup (uart+fips+dpm).
- Do **not** omit `super.img` into the current wipe-super fallback.
- Rebuild rango OUT first if a smaller `system.img` is required; current
  OUT 944,648,192 B still exceeds factory `system_a`.

---

## 4. What this card did not do

- No new `releases/desktop-flash/rango-*` directory
- No `rango-latest` retarget
- No Pixel 9 stamp/inode change
- No `flash-from-remote.sh` edit
- No new `scripts/flash-*.sh`
- No web-installer / `ALLOWED_PRODUCTS` rango
- No doctrine / secrets / PIXELFIX
- No USB flash

---

## 5. Host checks (this session)

```
readlink releases/desktop-flash/rango-latest
→ rango-20260802-130756
stat inodes: latest=193110379 akita-latest=193110357 komodo-latest=193110380
(cd releases/desktop-flash/rango-20260802-130756 && sha256sum -c SHA256SUMS --quiet)  # OK
(cd releases/desktop-flash/rango-20260803-145117 && sha256sum -c SHA256SUMS --quiet)  # OK
cmp -s releases/desktop-flash/rango-20260803-145117/vendor.img \
       releases/desktop-flash/rango-stock-userspace/vendor.img          # IDENTICAL
OUT sepolicy plat/system_ext/product MATCH
adb devices  # empty
command -v fastboot  # missing
```

pytest N/A (docs + stamp RCA; not Python).
