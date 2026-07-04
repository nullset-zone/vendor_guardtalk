# ABL splash extract / patch / re-sign RUNBOOK (T-BOOT-LOGO-002)

> **STATUS: BLOCKED — DOCUMENTATION ONLY. NO EXECUTION.**
> This runbook documents the manual procedure an operator would follow to
> replace the bootloader splash embedded in the signed ABL partition on
> Pixel 9 (`tokay`). It is **blocked** on (a) operator delivery of a
> byte-compatible `logo.img` and (b) explicit **Law 0 (Human Authority)**
> sign-off on a custom-ABL flash procedure. Until both are granted, this
> runbook MUST NOT be executed. A botched ABL flash can **permanently
> hard-brick** the device.

This runbook is the companion to `README.md`, which documents *why* the
splash is not build-wireable. This file documents *how* an operator would
manually patch the ABL if/when the block is lifted.

## 0. ABL partition overview

### What the ABL is

On Pixel 9 (`tokay`, Tensor G4), **ABL** (Android Bootloader — the
`abl` partition) is the Android-specific bootloader stage that runs after
the early ROM-bootloader chain (`bl1` → `bl2` → `bl31` → `tzsw` →
`pbl` → `ldfw`). It is the stage responsible for:

- Displaying the **pre-`BootAnimation` splash screen** (the first image
  seen on a cold boot).
- Fastboot mode UI.
- Selecting the boot slot (A/B) and verifying `boot`/`init_boot` via AVB.
- Handing off to the Linux kernel.

The ABL is shipped as a signed **ELF** binary inside the `abl` partition.
It is listed in `AB_OTA_PARTITIONS` in
`vendor/google_devices/tokay/BoardConfig.mk` (line 44):

```text
AB_OTA_PARTITIONS += \
    abl \
    bl1 \
    bl2 \
    bl31 \
    ...
```

### Why the splash is embedded in the ABL

The splash bitmap is **baked into the ABL ELF** as a data blob (raw
framebuffer pixels, conventionally 32-bit BGRA). There is no separate
`logo` partition, no `BOARD_BOOTLOADER_LOGO` / `BOARD_LOGO_IMAGE` /
`logo.img` AOSP build variable, and no source-tree asset path that the
AOSP build consumes to override it. This is confirmed by:

- `AB_OTA_PARTITIONS` contains `abl` but **no** `logo` partition.
- `grep -rin "logo"` across
  `vendor/adevtool/config/mk/google_devices/device/tokay/`,
  `vendor/google_devices/tokay/BoardConfig.mk`, and
  `vendor/google_devices/tokay/tokay.mk` returns **zero** bootloader-logo
  references (only unrelated regulatory-text "logo" strings in localized
  HTML overlays).
- Public reverse-engineering work (`0xAbby/pixel_loader`, XDA "Pixel
  BootLogo + Bootloader" threads) confirms modern Pixel boot logos are
  baked into the ABL ELF with no supported source-tree override.

**Conclusion:** the splash can only be changed by extracting, patching,
and re-signing the ABL partition image — which is device-bricking
territory and out of scope for GuardTalk as a normal engineering task.

## 1. Extract procedure (current ABL from device)

> **Precondition:** device is unlocked, bootloader accessible, `adb` +
> `fastboot` host tools installed, device connected over USB with
> `adb` authorized.

### 1.1 Identify the active slot

```bash
fastboot getvar all 2>&1 | grep -i "current-slot"
```

Record the active slot (`a` or `b`). The ABL is slotted
(`abl_a` / `abl_b`). To avoid touching the running slot, prefer
extracting from the **inactive** slot, or extract from the active slot
and keep a pristine backup before any patch is flashed.

### 1.2 Dump the ABL partition to the device

```bash
# Confirm the by-name symlink exists
adb shell su -c "ls -l /dev/block/by-name/abl_a"

# Dump the active-slot ABL (replace _a with _b if slot b is active)
adb shell su -c "dd if=/dev/block/by-name/abl_a of=/sdcard/abl_a.img bs=1M"

# Verify size and SHA-256 before pulling — RECORD THIS HASH
adb shell su -c "sha256sum /sdcard/abl_a.img"
adb shell su -c "wc -c /sdcard/abl_a.img"
```

### 1.3 Pull to host and re-verify

```bash
adb pull /sdcard/abl_a.img ./abl_a.img
sha256sum ./abl_a.img     # MUST match the on-device hash
```

**Store `abl_a.img` in at least two places** (host disk + off-device
backup). This is the **only recovery path** if a patched ABL fails to
boot — you will fastboot-flash this stock image back.

### 1.4 (Optional) Pull the inactive-slot ABL as a reference

```bash
adb shell su -c "dd if=/dev/block/by-name/abl_b of=/sdcard/abl_b.img bs=1M"
adb pull /sdcard/abl_b.img ./abl_b.img
```

Keeping both slots' images gives a fallback if one slot's ABL is
corrupted.

## 2. Patch procedure (locate + replace the splash bitmap)

> **This step requires reverse-engineering the ABL ELF.** The exact
> splash offset and container format are **not publicly documented** for
> the Tensor G4 ABL. The procedure below is the general approach; the
> operator must confirm offsets against the actual extracted image.

### 2.1 Inspect the ABL ELF

```bash
file ./abl_a.img
readelf -h ./abl_a.img        # if it is a plain ELF
readelf -S ./abl_a.img        # list sections — look for a large .rodata
```

The ABL is an ELF executable. The splash bitmap is typically stored as a
raw pixel blob inside a section such as `.rodata` or a custom section
named for the splash/framebuffer.

### 2.2 Locate the splash bitmap

The splash on modern Pixels is a **raw BGRA framebuffer dump** at the
panel's native resolution. For tokay that is **1080×2400**, 32-bit BGRA,
so the blob size is:

```text
1080 × 2400 × 4 = 10,368,000 bytes  (~9.88 MiB)
```

Search the ABL for a contiguous region of this size that looks like a
decoded image (not all-zeros, not all-0xFF):

```bash
# Rough heuristic: find a .rodata-sized section and dump it for inspection
objcopy -O binary --only-section=.rodata ./abl_a.img ./abl_rodata.bin
ls -l ./abl_rodata.bin

# Open in a hex editor (e.g. hexyl, bless, ImjTool) and scan for the bitmap
hexyl ./abl_rodata.bin | less
```

Alternatively, use `0xAbby/pixel_loader` or the ImjTool suite
(`newandroidbook.com/tools/imjtool.html`) which have helpers for locating
and extracting the splash from Pixel ABL images.

### 2.3 Bitmap format required

| Field        | Value                                              |
|--------------|----------------------------------------------------|
| Dimensions   | **1080 × 2400** (tokay panel native, portrait)     |
| Pixel format | **32-bit BGRA** (Android framebuffer convention)   |
| Stride       | `1080 × 4 = 4320` bytes (no padding)               |
| Total size   | `1080 × 2400 × 4 = 10,368,000` bytes               |
| Container    | **raw blob inside the ABL ELF** (NOT a `.bmp` file — the BMP header is wrapped by, or absent from, the ABL splash container) |
| Orientation  | Portrait, top-left origin                          |

> The exact on-disk container header (if any) around the raw pixel blob
> is **not publicly documented for the Tensor G4 ABL**. The operator must
> extract the stock splash from a factory `abl.img` first and produce a
> **byte-compatible** replacement — i.e. same header bytes, same offset,
> only the pixel payload swapped.

### 2.4 Produce the patched ABL

1. Extract the stock splash region from `abl_a.img` to a file:
   ```bash
   dd if=./abl_a.img of=./splash_stock.bin bs=1 skip=<OFFSET> count=10368000
   ```
2. Convert the operator-delivered `logo.img` (see §5) into the same raw
   BGRA blob with the same dimensions/stride. If `logo.img` is already a
   raw BGRA blob, no conversion is needed; if it is a PNG/BMP, convert:
   ```bash
   # Example: PNG → raw BGRA via ffmpeg
   ffmpeg -i logo.png -vf "scale=1080:2400,format=bgra" -f rawvideo ./splash_new.bin
   # Verify size
   wc -c ./splash_new.bin   # MUST be 10368000
   ```
3. Overwrite the splash region in a **copy** of the ABL (never the
   pristine backup):
   ```bash
   cp ./abl_a.img ./abl_patched.img
   dd if=./splash_new.bin of=./abl_patched.img bs=1 seek=<OFFSET> conv=notrunc
   ```
4. Diff the patched vs. stock image — the only differences must be inside
   the splash region:
   ```bash
   cmp -l ./abl_a.img ./abl_patched.img | wc -l   # should be ≤ 10368000
   ```

### 2.5 Tools required

- `adb` + `fastboot` (platform-tools).
- `readelf` / `objcopy` (binutils) — to inspect/section-dump the ELF.
- A hex editor (`hexyl`, `bless`, `hxtools`, or ImjTool's hex view).
- `ffmpeg` or ImageMagick — for BGRA conversion if the operator asset is
  not already raw.
- `dd` — for offset-accurate binary patching.
- Optional: `0xAbby/pixel_loader` or ImjTool — community helpers for
  Pixel ABL splash extraction (cite, don't vendor without review).

## 3. Re-sign requirement + brick risk

### 3.1 The ABL is signed

The stock ABL is signed as part of the AVB (Android Verified Boot)
chain. The bootloader chain verifies each stage:

```text
ROM (BML) → bl1 → bl2 → bl31 → tzsw → ... → abl → boot/init_boot
```

Patching the splash bitmap inside the ABL ELF **invalidates the ABL
signature**. The device will refuse to boot the patched ABL unless the
bootloader is unlocked and signature verification is disabled for the ABL
slot.

### 3.2 Bootloader unlock + AVB implications

- The device **must be unlocked** (`fastboot flashing unlock`) to boot an
  unsigned / modified ABL. Unlocking wipes userdata.
- With an unlocked bootloader, the **AVB warning screen** ("orange
  state") will display on every boot — this is expected and unavoidable.
- Locking the bootloader again (`fastboot flashing lock`) with a patched
  ABL flashed will **brick the device** unless the patched ABL is signed
  with the correct AVB key (which GuardTalk does not possess and will not
  handle — see §6).
- Even unlocked, a malformed ABL that crashes before fastboot is
  reachable can **hard-brick** the device (no USB, no fastboot, no
  recovery). The only recovery is an **EDL / USB-Loader** rescue, which
  for Pixel 9 requires a signed Samsung-authorized USB-Loader that is
  not publicly available.

### 3.3 Brick risk — explicit (Law 19)

> **⚠️ THIS PROCEDURE CAN PERMANENTLY HARD-BRICK THE DEVICE.**
>
> - A corrupted ABL that fails before fastboot is reachable leaves the
>   device with **no user-accessible recovery path**.
> - The ABL is the stage that *provides* fastboot. If you break it, you
>   lose the tool you would use to fix it.
> - Pixel 9 EDL rescue requires a signed Samsung USB-Loader not
>   publicly available — i.e. an unrecoverable brick is a realistic
>   outcome, not a theoretical one.
> - **Do not attempt this on a device you cannot afford to lose.**
> - **Do not attempt this as a normal engineering task.** It is operator-
>   approved, off-build, off-OTA, one-off manual work.

### 3.4 Mitigations before flashing

1. Keep **pristine stock ABL images** for **both slots** on the host and
   on off-device backup.
2. Patch the **inactive slot only** first (e.g. if `current-slot=a`,
   flash the patched ABL to `abl_b` and boot to slot b). This leaves the
   active slot's stock ABL intact as a fallback.
3. After flashing to the inactive slot, boot once to confirm the splash
   renders and the device reaches fastboot/recovery before considering
   the slot "good".
4. Never lock the bootloader with a patched ABL flashed.

## 4. Flash procedure (patched ABL)

> **Precondition:** §1–§3 complete, bootloader unlocked, pristine stock
> ABL backed up for both slots, patched ABL verified to differ only in
> the splash region.

### 4.1 Flash to the inactive slot

```bash
# Identify slots
fastboot getvar current-slot
fastboot getvar slot-count

# If current-slot=a, flash patched ABL to slot b (the INACTIVE slot)
fastboot flash abl_b ./abl_patched.img

# Set the inactive slot as active ONLY after verifying boot
# (Do NOT do this yet — boot to it first via fastboot --set-active or
# by rebooting and letting the B slot take over once.)
```

### 4.2 Boot to the patched slot and verify

```bash
# Temporarily boot from the patched slot WITHOUT setting it active
# (Pixel fastboot supports --slot overrides in some tooling versions;
#  otherwise set active, reboot, and be ready to fastboot back.)
fastboot --set-active=b
fastboot reboot

# Watch the boot:
#   - AVB orange-state warning appears (expected, unlocked)
#   - GuardTalk splash renders at the expected offset (the win condition)
#   - Device reaches BootAnimation / system (hand-off succeeded)
```

### 4.3 If anything is wrong — IMMEDIATE rollback

If the device hangs, shows a black screen, or fails to reach fastboot on
reboot:

1. Force-restart into fastboot (hold volume-down + power on cold boot).
   **If fastboot is unreachable, the device is hard-bricked** — see §3.3.
2. From fastboot, re-flash the stock ABL to the bricked slot:
   ```bash
   fastboot flash abl_b ./abl_a.img   # pristine stock backup
   fastboot --set-active=a
   fastboot reboot
   ```
3. If slot b is unrecoverable, keep slot a (stock) as the permanent boot
   slot and abandon the patch.

### 4.4 If verification succeeds

Only after a successful boot-to-system on the patched slot:

```bash
fastboot --set-active=b   # make the patched slot permanent (optional)
```

Keep the stock ABL backups indefinitely — they are the rollback path for
the life of the device.

## 5. Operator deliverable spec (`logo.img`)

The operator must deliver a byte-compatible splash asset to
`vendor/guardtalk/branding/bootloader-logo/logo.img` before this runbook
can be executed. Spec:

| Field               | Value                                                        |
|---------------------|--------------------------------------------------------------|
| Path                | `vendor/guardtalk/branding/bootloader-logo/logo.img`         |
| Dimensions          | **1080 × 2400** (Pixel 9 `tokay` portrait, panel native)     |
| Pixel format        | **32-bit BGRA**                                              |
| Stride              | `1080 × 4 = 4320` bytes (no row padding)                     |
| Total pixel size    | `1080 × 2400 × 4 = 10,368,000` bytes                         |
| Container           | **raw blob** (the ABL splash container format — operator must match the stock splash's container header exactly, extracted from a factory `abl.img`) |
| Content             | GuardTalk logo + wordmark **only**                           |
| Forbidden content   | **No** Google / Pixel / GrapheneOS branding (Law 13 — trademark hygiene) |
| Orientation         | Portrait, top-left origin                                    |
| Verification        | Operator must include the SHA-256 of the stock splash region they extracted the container format from, so the patch step can be reproducibly verified |

The operator is responsible for:

1. Extracting a stock `abl.img` from a factory image for `tokay`.
2. Locating the splash region (§2.2) and recording the offset + container
   header bytes.
3. Producing `logo.img` such that `dd`-ing it into the splash region at
   the recorded offset yields a byte-compatible ABL (only the pixel
   payload differs from stock).
4. Delivering `logo.img` + a short note documenting the offset, the
   stock-splash SHA-256, and the ABL build/fingerprint it was extracted
   from.

Until `logo.img` lands at that path, the placeholder no-op hook in
`vendor/guardtalk/device/tokay/BoardConfig-excised.mk` stays inert and
the build uses the stock Pixel bootloader splash. **No GrapheneOS or
Google splash is introduced or modified by GuardTalk.**

## 6. Risk acknowledgement (Law 19 — document honestly)

By executing any step of this runbook the operator acknowledges **all**
of the following:

1. **PERMANENT HARD-BRICK RISK.** A corrupted ABL can leave the device
   with no user-accessible recovery path. Pixel 9 EDL rescue requires a
   signed Samsung USB-Loader that is not publicly available. An
   unrecoverable brick is a realistic outcome, not a theoretical one.
2. **Unlocked bootloader required.** The device must be
   `fastboot flashing unlock`-ed, which wipes userdata and causes an AVB
   orange-state warning on every boot. Re-locking with a patched ABL
   flashed will brick the device.
3. **AVB chain broken.** A patched ABL is unsigned. The AVB chain is
   intentionally broken at the ABL stage. This is a security posture
   change and must be approved by the operator under **Law 0 (Human
   Authority)** before any flashing.
4. **BLOCKED on operator + Law 0 approval.** This runbook is **BLOCKED**
   until:
   - (a) the operator delivers a byte-compatible `logo.img` (§5), AND
   - (b) the operator grants explicit **Law 0 (Human Authority)** sign-off
     on the custom-ABL flash procedure.
   Until both are granted, **no step of this runbook may be executed**.
5. **NOT a normal engineering task.** This is off-build, off-OTA, one-off
   manual work. It is explicitly **out of scope** for GuardTalk
   engineering as a routine task. Engineers MUST NOT attempt ABL
   patch/re-sign on their own initiative.
6. **No signing keys.** GuardTalk does not possess and will not handle
   AVB signing keys. The patched ABL will boot only on an unlocked
   device. GuardTalk will not request, store, or transmit any AVB key
   material.
7. **No warranty.** The device may brick. The operator accepts full
   responsibility for the outcome.

## 7. Acceptance for this runbook (T-BOOT-LOGO-002-RUNBOOK)

This deliverable is **REVIEW** (not APPROVED) because:

1. It is documentation only — no ABL was extracted, patched, signed, or
   flashed. Law 6 (minimal footprint) satisfied.
2. It documents the extract, patch, re-sign, and flash procedures to the
   extent publicly knowable, and explicitly flags the unknowable parts
   (Tensor G4 ABL splash container header / offset) as operator-action
   items. Law 19 (document honestly) satisfied.
3. It explicitly states the brick risk, the unlock/AVB implications, and
   the BLOCKED-on-operator + Law 0 status.
4. It does **not** modify `doctrine/`, `governance/`, or
   `vendor/google_devices/tokay/BoardConfig.mk`.
5. It does **not** handle, request, or store any signing keys.
6. It is **not committed** — the Backend Engineer does not commit;
   Architect marks APPROVED in `TASK_QUEUE.md` first (per the 4-agent
   protocol).

The runbook lifts to FINAL when (a) the operator delivers the
byte-compatible `logo.img`, (b) the operator grants Law 0 sign-off on
the flash procedure, and (c) the Architect signs off on the runbook
itself.

## Diagnostic: "second boot GrapheneOS logo" symptom (T-ICON-BOOTLOGO)

> **STATUS: INVESTIGATED — RESOLVED (bootanimation ruled out; symptom is the
> stock bootloader splash).**

### Symptom

User reported seeing a "GrapheneOS boot logo" on the **second boot** of a
GuardTalkOS tokay (Pixel 9) device, despite the GuardTalk bootanimation
being correctly wired at `/product/media/bootanimation.zip`.

### Investigation (read-only)

**Step 1 — Frame extraction + `desc.txt`:**

```text
$ unzip -o -q vendor/guardtalk/branding/bootanimation/bootanimation.zip -d /tmp/bootanim_inspect
$ cat /tmp/bootanim_inspect/desc.txt
1080 2400 24
p 1 0 part0
p 0 0 part1
```

- `part0`: 42 frames (`000.png` … `041.png`) — intro, played once (`p 1`).
- `part1`: 24 frames (`000.png` … `023.png`) — loop, played until boot
  completes (`p 0`).
- All frames are 1080×2400, 8-bit RGB PNG.

**Step 2 — Visual / programmatic frame inspection:**

Because pixel-level visual verification by a human was not available, the
frames were analyzed programmatically with a pure-Python PNG decoder
(no PIL/ImageMagick in the inspect environment). Each key frame was sampled
for (a) the GuardTalk Signal Green accent `#C3FF61`, (b) obsidian black
background, (c) white pixels, and (d) GrapheneOS-brand-blue pixels.

| Frame                       | Obsidian % | Signal Green % | White % | GrapheneOS-blue % |
|-----------------------------|-----------:|---------------:|--------:|------------------:|
| `part0/000.png` (intro 1st) |     100.0% |           0.0% |    0.0% |              0.0% |
| `part0/020.png` (intro mid) |      97.6% |           2.3% |    0.0% |              0.0% |
| `part0/041.png` (intro last)|      96.9% |           3.0% |    0.0% |              0.0% |
| `part1/000.png` (loop 1st)  |      96.9% |           3.0% |    0.0% |              0.0% |
| `part1/012.png` (loop mid)  |      96.9% |           3.0% |    0.0% |              0.0% |
| `part1/023.png` (loop last) |      97.0% |           3.0% |    0.0% |              0.0% |

The green-pixel bounding box in `part1/000.png` was rendered to ASCII. The
rendered shape is unambiguously the **GuardTalk shield mark** (top) above the
**`GuardTalk` wordmark** (bottom — the letters G-U-A-R-D-T-A-L-K are
readable in the ASCII rendering). The only non-black color present in any
frame is Signal Green `#C3FF61` (bucketed to `#c0f060` at 16-level
precision). **Zero white pixels and zero GrapheneOS-blue pixels exist in any
sampled frame.**

**Conclusion: the bootanimation is clean.** No GrapheneOS logo, wordmark, or
brand color appears in any frame of `bootanimation.zip`. The bootanimation
cannot be the source of the reported "GrapheneOS logo".

**Step 3 — Residual / built-image bootanimation check:**

```text
$ find out/target/product/tokay -name 'bootanimation*.zip' 2>/dev/null
out/target/product/tokay/product/media/bootanimation.zip
out/target/product/tokay/obj/PACKAGING/target_files_intermediates/tokay-target_files/PRODUCT/media/bootanimation.zip

$ md5sum vendor/guardtalk/branding/bootanimation/bootanimation.zip \
        out/target/product/tokay/product/media/bootanimation.zip
7ba676c5704c6e6ab962fb34cc6590ef  vendor/guardtalk/branding/bootanimation/bootanimation.zip
7ba676c5704c6e6ab962fb34cc6590ef  out/target/product/tokay/product/media/bootanimation.zip
```

The built product image's `bootanimation.zip` is byte-identical (same md5) to
the canonical source asset. The dark variant is correctly filtered out. No
stale or residual GrapheneOS `bootanimation.zip` exists in the build tree.

**Step 4 — Bootloader splash situation (see §0 above):**

As documented in `README.md` and §0 of this runbook, the pre-`BootAnimation`
splash on tokay is **embedded inside the signed ABL partition**. There is no
`logo` partition, no `BOARD_BOOTLOADER_LOGO` build variable, and no
source-tree override path. GuardTalk does **not** modify the ABL. The splash
shown by the bootloader is therefore whatever shipped on the device's stock
ABL.

**Critical clarification (Law 19 — document honestly):** the stock Pixel
bootloader splash is a **Google / Pixel logo**, **NOT** a GrapheneOS logo.
GrapheneOS itself does not modify the bootloader — it ships the stock Pixel
ABL splash unchanged. So if the user is seeing a logo *before* the GuardTalk
bootanimation begins, that logo is the **stock Pixel/Google bootloader
splash**, not a "GrapheneOS logo". The user's identification of it as
"GrapheneOS" is a misattribution: GrapheneOS, like GuardTalk, does not
replace the ABL splash, so the splash visible on a GrapheneOS device and on
a GuardTalk device is the *same* stock Pixel/Google splash.

### Resolution

The reported "second boot GrapheneOS logo" is the **stock bootloader splash
(ABL)**, not a bootanimation frame issue. Specifically:

1. The GuardTalk bootanimation is correctly wired, byte-identical to the
   source asset, and contains zero GrapheneOS branding in any of its 66
   frames (42 intro + 24 loop). **Ruled out.**
2. The logo the user sees *before* `BootAnimation.cpp` runs is emitted by
   the **bootloader (ABL)**, which on tokay is the **stock Pixel/Google
   splash**. This splash appears on **every** boot (cold boot, reboot, A/B
   slot switch), not specifically the "second" boot — the user may simply
   have noticed it more on the second boot because the first boot may have
   spent longer in the bootanimation or been a setup-flow boot.
3. Neither GrapheneOS nor GuardTalk modifies this splash. The user's label
   "GrapheneOS logo" is a misattribution of the stock Pixel/Google ABL
   splash that GrapheneOS (and therefore GuardTalk, which inherits the
   stock ABL) leaves untouched.
4. Replacing this splash requires the blocked, operator-only, Law-0-gated
   ABL extract/patch/re-sign procedure documented in §1–§6 of this
   runbook. It is **not** fixable from the GuardTalk source tree.

### Action

- **No bootanimation change.** The bootanimation is correct and clean.
- **No source-tree change.** The bootloader splash is not source-wireable
  (§0 of `README.md`).
- If the operator wants the pre-bootanimation splash replaced with a
  GuardTalk mark, that is **T-BOOT-LOGO-002** (this runbook), which remains
  BLOCKED on operator delivery of `logo.img` + Law 0 sign-off (§6).
- User-facing communication: the visible pre-bootanimation logo is the
  stock Pixel/Google bootloader splash, identical to what GrapheneOS ships.
  It is expected behavior on every boot, not a regression and not a
  GrapheneOS-specific artifact.

### Evidence retained

- Extracted frames: `/tmp/bootanim_inspect/part0/` (42) and
  `/tmp/bootanim_inspect/part1/` (24) — ephemeral, not committed.
- Analyzer scripts: `/tmp/png_analyze.py`, `/tmp/png_crop.py` — ephemeral.
- md5 of source == md5 of built image ==
  `7ba676c5704c6e6ab962fb34cc6590ef`.

---

## References

- `vendor/guardtalk/branding/bootloader-logo/README.md` — gap analysis +
  spec (companion to this runbook).
- `vendor/google_devices/tokay/BoardConfig.mk` — `AB_OTA_PARTITIONS`
  (confirms `abl` is slotted, no `logo` partition).
- `0xAbby/pixel_loader` — community Pixel ABL reverse-engineering.
- XDA: "Pixel BootLogo + Bootloader" threads — community splash-patching
  discussion.
- ImjTool — `newandroidbook.com/tools/imjtool.html` — binary extraction
  helpers.
- AOSP AVB documentation — verified-boot chain background.
- GuardTalk doctrine: Law 0 (Human Authority), Law 6 (Minimal Footprint),
  Law 13 (Ethical Boundaries / trademark hygiene), Law 19 (Documentation
  Completeness).
