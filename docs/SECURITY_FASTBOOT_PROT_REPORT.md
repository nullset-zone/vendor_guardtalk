# A-FASTBOOT-PROT-RESEARCH — Fastboot / Bootloader-Mode Filesystem Protection (#3)

**Status:** READ-ONLY research. No files edited, no commits.
**Gate -1 (Guardian First):** Acknowledged. This is a read-only audit task — no build files modified, no git operations, no access to `doctrine/` or `governance/laws|gates/`.
**Date:** 2026-07-02
**Scope:** `system/core/fastboot/device/`, `system/vold/`, `vendor/guardtalk/device/tokay/`
**Verdict:** **GO** — fastboot-mode filesystem protection is sound and is a direct consequence of #1 (locked bootloader + custom AVB key + FBE). It is largely a *verification* task on top of #1, not a separate implementation.

---

## 0. Executive Summary

The filesystem (userdata) is protected in fastboot/bootloader mode by **three independent, layered controls**, all of which are confirmed in-tree:

1. **Locked-bootloader command gating** — the in-tree `fastbootd` source (`system/core/fastboot/device/commands.cpp`) explicitly rejects `flash`, `erase`, `download`, `set_active`, `create/update/delete-partition`, `update-super`, and `fetch` when `GetDeviceLockStatus()` is true. The bootloader itself (proprietary Pixel blob, not in-tree) additionally rejects `fastboot boot` of unsigned images and the `flash`/`erase`/`-w` paths at the bootloader level.
2. **FBE ciphertext-at-rest** — userdata is File-Based-Encrypted with AES-256-XTS (contents) / AES-256-CTS (filenames); the master key is wrapped by KeyMint in the TEE (`system/vold/Keystore.cpp`, `system/vold/KeyStorage.cpp`). The raw userdata partition therefore yields only ciphertext.
3. **`fastboot fetch` allow-list** — even on debuggable builds where `fetch` is compiled in, the in-tree allow-list (`commands.cpp:897`) restricts fetch to `vendor_boot`, `vendor_boot_a`, `vendor_boot_b` **only**. `userdata` is not fetchable, and fetch is additionally blocked on locked devices (`commands.cpp:757`).

This protection is **inseparable from #1**: without a locked bootloader, `fastbootd`'s lock checks pass and the bootloader allows flash/erase. The only verifications beyond #1 are: (a) confirm `fetch` is closed (confirmed in-tree), (b) confirm FBE keys are TEE-bound (confirmed in-tree), (c) confirm fastbootd does not expose extra surface on locked devices (confirmed in-tree).

---

## 1. Locked-bootloader fastboot restrictions

### 1.1 In-tree fastbootd lock gating (`system/core/fastboot/device/`)

The userspace fastboot daemon (`fastbootd`, runs in userspace-reboot/recovery-ish mode for dynamic partitions) gates every mutating command on `GetDeviceLockStatus()`. The lock-status predicate:

```183:185:system/core/fastboot/device/utility.cpp
bool GetDeviceLockStatus() {
    return android::base::GetProperty("ro.boot.verifiedbootstate", "") != "orange";
}
```

**Critical interpretation:** `GetDeviceLockStatus()` returns `true` for *any* `verifiedbootstate` that is not `"orange"`. The AVB verified-boot states are:

| `ro.boot.verifiedbootstate` | Meaning | `GetDeviceLockStatus()` |
|---|---|---|
| `green` | LOCKED, AVB-verified with the embedded/OS key | `true` (locked) |
| `yellow` | LOCKED, AVB-verified with the user's custom key | `true` (locked) |
| `orange` | UNLOCKED | `false` (unlocked) |
| `red` | LOCKED, verification FAILED | `true` (locked) |

So a device locked to GuardTalkOS's **custom AVB key** (yellow state — the intended production state for a custom-AVB build) is treated as **locked** by every fastbootd command. This is the key dependency on #1.

### 1.2 Commands rejected on locked devices (in-tree evidence)

All evidence from `system/core/fastboot/device/commands.cpp`:

| Command | Locked-device rejection | Line |
|---|---|---|
| `fastboot erase <part>` | `"Erase is not allowed on locked devices"` | `commands.cpp:230-231` |
| `fastboot flash <part>` (via `download`) | `"Download is not allowed on locked devices"` | `commands.cpp:289-291` |
| `fastboot set_active <slot>` | `"set_active command is not allowed on locked devices"` | `commands.cpp:325-327` |
| `fastboot create-partition` | `"Command not available on locked devices"` | `commands.cpp:494-495` |
| `fastboot delete-partition` | `"Command not available on locked devices"` | `commands.cpp:532-533` |
| `fastboot resize-partition` | `"Command not available on locked devices"` | `commands.cpp:554-555` |
| `fastboot flash <part>` (FlashHandler) | `"Flashing is not allowed on locked devices"` | `commands.cpp:606-608` |
| `fastboot update-super` | `"Command not available on locked devices"` | `commands.cpp:637-638` |
| `fastboot fetch <part>` | `"Fetch is not allowed on locked devices"` | `commands.cpp:757-758` |

Representative block (the `FlashHandler`):

```601:609:system/core/fastboot/device/commands.cpp
bool FlashHandler(FastbootDevice* device, const std::vector<std::string>& args) {
    if (args.size() < 2) {
        return device->WriteStatus(FastbootResult::FAIL, "Invalid arguments");
    }

    if (GetDeviceLockStatus()) {
        return device->WriteStatus(FastbootResult::FAIL,
                                   "Flashing is not allowed on locked devices");
    }
```

And `EraseHandler`:

```225:232:system/core/fastboot/device/commands.cpp
bool EraseHandler(FastbootDevice* device, const std::vector<std::string>& args) {
    if (args.size() < 2) {
        return device->WriteStatus(FastbootResult::FAIL, "Invalid arguments");
    }

    if (GetDeviceLockStatus()) {
        return device->WriteStatus(FastbootResult::FAIL, "Erase is not allowed on locked devices");
    }
```

### 1.3 `fastboot -w` (wipe userdata)

`fastboot -w` is implemented host-side as `erase userdata` + `erase cache`. Since `EraseHandler` rejects on locked devices (`commands.cpp:230`), `fastboot -w` **fails on a locked device**.

### 1.4 `fastboot boot <unsigned.img>` (boot unsigned)

`fastboot boot` is a **bootloader-level** command, not handled by fastbootd. The Pixel bootloader is a proprietary binary blob and is **not in-tree** (`device/google/zumapro/` contains only config, not bootloader source). Per AOSP fastboot protocol semantics and GrapheneOS documentation, a locked bootloader rejects `fastboot boot` of any image not signed by the configured AVB key. This cannot be cited from in-tree source; it is a hardware-enforced guarantee of the Pixel bootloader and is verified empirically in the follow-on `Q-SIGN`/`Q-FASTBOOT` task.

### 1.5 `fastboot oem`

OEM commands are passed through to the bootloader/vendor fastboot HAL (`commands.cpp:262-282`, `OemCmdHandler` → `fastboot_hal->doOemCommand`). fastbootd does **not** itself gate `oem` on lock state; the gating is delegated to the vendor HAL/bootloader. On Pixel, locked-bootloader OEM commands are restricted to a harmless allow-list. **Residual risk:** this is vendor-HAL-defined behavior, not verifiable from in-tree source. (See §6.)

### 1.6 Unlock flow (`fastboot flashing unlock` / `unlock_critical`)

The unlock flow is bootloader-enforced (not in fastbootd source). On tokay (Pixel 9), per AOSP/GrapheneOS docs:

- `fastboot flashing get_unlock_ability` → returns `0` (default; unlocking disabled) or `1` (unlocking enabled after the user toggles "OEM unlocking" in Developer Options).
- `fastboot flashing unlock` → requires `get_unlock_ability=1`, requires physical confirmation, and **triggers a factory reset that wipes userdata** (and the metadata partition). This wipe is enforced by the bootloader before transitioning to the unlocked state.
- `fastboot flashing unlock_critical` → unlocks the bootloader-critical partitions (similar wipe).
- `fastboot flashing lock` → re-locks the bootloader, this time verifying images against the configured AVB key. For GuardTalkOS this means the **custom AVB key** from #1; a device re-locked after flashing GuardTalkOS will only boot images signed by the GuardTalk AVB key.

The userdata wipe on unlock is not implemented in `fastbootd` source — it is a bootloader guarantee. The `PostWipeData()` hook in fastbootd (`commands.cpp:161-167`) only runs *after* an erase that fastbootd itself performed (i.e., on an already-unlocked device), not as part of the unlock flow.

---

## 2. FBE ciphertext-at-rest guarantee

### 2.1 Encryption algorithms (in-tree evidence)

Metadata encryption (the userdata block device) uses AES-256-XTS:

```77:77:system/vold/MetadataCrypt.cpp
        CryptoType().set_config_name("aes-256-xts").set_kernel_name("AES-256-XTS").set_keysize(64);
```

File-Based Encryption (per-file) options default to XTS for contents and CTS for filenames:

```355:365:system/vold/FsCrypt.cpp
static bool get_volume_file_encryption_options(EncryptionOptions* options) {
    // If we give the empty string, libfscrypt will use the default (currently XTS)
    auto contents_mode = android::base::GetProperty("ro.crypto.volume.contents_mode", "");
    // HEH as default was always a mistake. Use the libfscrypt default (CTS)
    auto filenames_mode =
            android::base::GetProperty("ro.crypto.volume.filenames_mode",
```

(The `""` defaults resolve to libfscrypt's `aes-256-xts` for contents and `aes-256-cts` for filenames — the CDD-mandated defaults for devices launching with Android 11+.)

### 2.2 Key storage — hardware-bound in the TEE

FBE keys are wrapped by KeyMint in the **TRUSTED_ENVIRONMENT (TEE)**, not stored in plaintext on userdata:

```116:124:system/vold/Keystore.cpp
     * There are only two options available to vold for the SecurityLevel: TRUSTED_ENVIRONMENT (TEE)
     * and STRONGBOX. We don't use STRONGBOX because if a TEE is present it will have Weaver, which
     * already strengthens CE, so there's no additional benefit from using StrongBox.
     *
     * The picture is slightly more complicated because Keystore2 reports a SOFTWARE instance as
     * a TEE instance when there isn't a TEE instance available, but in that case, a STRONGBOX
     * instance won't be available either, so we'll still be doing the best we can.
     */
    auto rc = keystore2Service->getSecurityLevel(km::SecurityLevel::TRUSTED_ENVIRONMENT,
```

The wrapped key blob is stored as `keymaster_key_blob` in the key directory (on the `metadata` partition, not userdata):

```62:63:system/vold/KeyStorage.cpp
static const char* kFn_keymaster_key_blob = "keymaster_key_blob";
static const char* kFn_keymaster_key_blob_upgraded = "keymaster_key_blob_upgraded";
```

### 2.3 What an attacker gets from a raw userdata read

If an attacker desolders the userdata NAND or otherwise reads the raw `userdata` partition off-device, they obtain:

- **File contents:** AES-256-XTS ciphertext (indistinguishable from random without the per-file keys).
- **Filenames:** AES-256-CTS ciphertext (directory entries are encrypted).
- **No keys.** The FBE master key is a KeyMint-wrapped blob (`keymaster_key_blob`) stored on the **`metadata`** partition, not userdata, and the blob is unwrappable only inside the TEE — the TEE's private key never leaves the SoC.

### 2.4 Can the FBE key be extracted from a locked device?

**No** — under the standard Pixel threat model. The KeyMint/TEE private key is hardware-bound to the SoC (Tensor G4 on tokay/Pixel 9) and is not extractable even with a kernel compromise or full physical access. Extracting the raw `userdata` ciphertext does not yield the keys; the `metadata` partition holds only the *wrapped* blob, which is useless without the TEE.

### 2.5 The `metadata` partition

The `metadata` partition is itself metadata-encrypted and holds the key-wrapping material (`metadata_key_dir/key`). It is listed as a protected partition during snapshot merges:

```81:88:system/core/fastboot/device/commands.cpp
static bool IsProtectedPartitionDuringMerge(FastbootDevice* device, const std::string& name) {
    static const std::unordered_set<std::string> ProtectedPartitionsDuringMerge = {
            "userdata", "metadata", "misc"};
```

And `metadata` cannot be flashed/erased via fastbootd on a locked device (all such commands are gated by `GetDeviceLockStatus()`).

---

## 3. fastbootd exposure (userspace fastboot)

### 3.1 In-tree location

fastbootd lives in `system/core/fastboot/device/` (NOT `bootable/recovery/`). The binary is built from `system/core/fastboot/Android.bp`:

```139:149:system/core/fastboot/Android.bp
cc_binary {
    name: "fastbootd",
    defaults: ["fastboot_defaults"],

    recovery: true,

    product_variables: {
        debuggable: {
            cppflags: ["-DFB_ENABLE_FETCH"],
        },
    },
```

`fastbootd` is a `recovery: true` binary — it runs in the recovery-ish userspace that hosts the userspace fastboot daemon for dynamic (super) partition operations during `fastbootd` mode (entered via `fastboot reboot fastboot` or `adb reboot fastboot`).

### 3.2 Is fastbootd accessible when the bootloader is locked?

fastbootd reads `ro.boot.verifiedbootstate` to determine lock state (`utility.cpp:184`). Entering fastbootd mode requires the bootloader to have already booted the device. On a locked device, the bootloader only boots images signed by the configured AVB key (the GuardTalk custom key for #1). So:

- fastbootd **can run** on a locked device (it is part of the signed boot image).
- But **every mutating fastbootd command is gated** by `GetDeviceLockStatus()` (§1.2), so on a locked device fastbootd is reduced to read-only `getvar` queries.

This is consistent: the in-tree fastbootd does **not** trust the bootloader to filter commands — it independently re-checks lock state on every command. So even if a flaw let an attacker reach fastbootd on a locked device, the commands still fail.

### 3.3 fastbootd attack surface on a locked device

On a locked device, fastbootd exposes:

- `getvar` (read-only metadata: versions, slot info, partition sizes, etc.) — **safe**.
- `reboot` variants — **safe**.
- All flashing/erasing/partition-mgmt/fetch — **rejected** (§1.2).

The remaining surface is the `oem` passthrough to the vendor fastboot HAL (`OemCmdHandler`, `commands.cpp:262`), which is **not** lock-gated in fastbootd. This is a vendor-defined surface; on Pixel it is restricted by the vendor HAL. (See §6, residual risk.)

### 3.4 Does GuardTalkOS close fastbootd?

`vendor/guardtalk/device/tokay/` was grepped for `fastboot|fastbootd|FB_ENABLE|fetch|ro.fastboot` — **no matches**. GuardTalkOS does **not** add any fastbootd-specific config on top of the AOSP defaults. This is acceptable because:

1. fastbootd's lock gating is upstream-correct (§1.2).
2. `FB_ENABLE_FETCH` is **only** defined for `debuggable` builds (`Android.bp:145-148`). GuardTalkOS production builds must be `user` (non-debuggable) — under that build, `kEnableFetch=false` and `fetch` is **always** rejected with `"Fetch is not allowed on user build"` (`commands.cpp:753-754`), regardless of lock state.

**Verification requirement for the Q-SIGN/Q-FASTBOOT task:** confirm GuardTalkOS ships a `user` build variant (not `userdebug`). The in-tree `vendor/guardtalk/device/tokay/*.mk` files contain no `TARGET_BUILD_VARIANT` override, so this is controlled by the lunch target, not the device config.

---

## 4. Verification commands (for Q-SIGN / Q-FASTBOOT)

| Check | Command | Expected (locked + custom-AVB) |
|---|---|---|
| Unlock ability | `fastboot flashing get_unlock_ability` | `0` (default; `1` only if user enabled OEM unlocking) |
| Lock state | `fastboot getvar unlocked` | `no` |
| Lock state (alt) | `fastboot oem lock-state-info` | vendor-specific; typically `Locked` |
| Verified boot state | `fastboot getvar verifiedbootstate` | `yellow` (locked + custom key) — **not** `green`, because `green` requires the OS-embedded key. GuardTalkOS uses a custom AVB key, so `yellow` is the correct production state. |
| Userspace prop | `adb shell getprop ro.boot.verifiedbootstate` | `yellow` |
| Flash while locked | `fastboot flash system unsigned.img` | `FAILED ... Flashing is not allowed on locked devices` (fastbootd) or bootloader-level rejection |
| Erase while locked | `fastboot erase userdata` | `FAILED ... Erase is not allowed on locked devices` |
| Wipe while locked | `fastboot -w` | `FAILED ... Erase is not allowed on locked devices` |
| Fetch userdata while locked | `fastboot fetch userdata` | `FAILED ... Fetch is not allowed on locked devices` (and on `user` builds: `"Fetch is not allowed on user build"`) |
| Boot unsigned while locked | `fastboot boot unsigned.img` | Bootloader rejects (cannot boot unsigned image on locked device) |
| Raw userdata dump (off-device) | `dd if=/dev/block/by-name/userdata` | High-entropy ciphertext; no plaintext filenames, no recognizable file magic |

### 4.1 `verifiedbootstate` color semantics (important for #1)

- `green` = LOCKED, verified against the **OS-embedded** key (i.e., the OEM key baked into the bootloader). A custom-AVB build like GuardTalkOS will **not** be `green` unless the AVB key is the OEM key.
- `yellow` = LOCKED, verified against a **user-configured** key (the custom AVB key flashed via `fastboot flash avb_custom_key` + `fastboot flashing lock`). **This is GuardTalkOS's intended production state.**
- `orange` = UNLOCKED.
- `red` = LOCKED, verification FAILED (device refuses to boot the OS; drops to recovery/fastboot with a warning).

GuardTalkOS devices in production should report `yellow`. fastbootd's `GetDeviceLockStatus()` correctly treats `yellow` as locked (`utility.cpp:184`: anything ≠ `orange` is locked).

---

## 5. Dependency on #1 (signing + lock)

**Confirmed: fastboot-mode filesystem protection is INSEPARABLE from #1.** The evidence chain:

1. **Lock state is derived from AVB.** `GetDeviceLockStatus()` reads `ro.boot.verifiedbootstate` (`utility.cpp:184`), which is set by the bootloader based on AVB verification. Without a locked bootloader (verified against the GuardTalk custom AVB key), the state is `orange` and **every** fastbootd lock check passes → full filesystem access.

2. **The bootloader itself is not in-tree.** The Pixel bootloader is a proprietary blob; its locked-state enforcement (rejecting `fastboot boot` of unsigned images, enforcing the unlock-wipe, etc.) is a hardware/firmware guarantee that cannot be patched from AOSP source. #1's custom-AVB-key + lock step is what activates this guarantee for GuardTalkOS.

3. **FBE key wrapping depends on the TEE, which is independent of lock state** — but FBE alone is *not sufficient*: on an **unlocked** device, an attacker can `fastboot flash` a modified boot/system that exfiltrates the FBE keys from the TEE at runtime (via keymint access from a compromised OS). The lock is what prevents the attacker from booting such an image. So FBE's at-rest guarantee is only meaningful *combined* with #1.

### 5.1 What is genuinely *additional* beyond #1

The brief asks what protections exist *beyond* #1. Three verifications, all confirmed in-tree:

- **(a) `fastboot fetch` is closed.** Confirmed: `fetch` is (i) compiled out on `user` builds (`Android.bp:145-148`), (ii) gated on `!GetDeviceLockStatus()` (`commands.cpp:757`), and (iii) allow-listed to `vendor_boot*` only (`commands.cpp:897-901`). Userdata is **never** fetchable. ✓
- **(b) `fastboot fetch` of userdata specifically.** Even if `fetch` were enabled (debuggable build, unlocked device), `userdata` is not in `kAllowedPartitions`:
  ```897:901:system/core/fastboot/device/commands.cpp
      static constexpr std::array<const char*, 3> kAllowedPartitions{
              "vendor_boot",
              "vendor_boot_a",
              "vendor_boot_b",
      };
  ```
  So `fastboot fetch userdata` fails with `"Fetch is only allowed on [vendor_boot, ...]"` (`commands.cpp:784`). ✓
- **(c) FBE key is hardware-bound.** Confirmed via KeyMint/TEE wrapping (`Keystore.cpp:116-124`, `KeyStorage.cpp:62-63`). ✓

### 5.2 Go / No-Go

**GO.** This is a verification task on top of #1, not a separate implementation. No new code is required; the protections are upstream-correct and depend only on (i) shipping a `user` build, (ii) locking the bootloader with the custom AVB key from #1, and (iii) leaving `get_unlock_ability=0` in production.

---

## 6. Gaps / residual risks

### 6.1 `fastboot fetch` on locked devices (the brief's stated concern)

The brief asks whether `fastboot fetch` of userdata is allowed on locked devices "for debugging." **Verified: NO.** Three independent gates block it:

1. Build gate: `FB_ENABLE_FETCH` is defined **only** for `debuggable` builds (`Android.bp:145-148`). On a `user` build, `kEnableFetch=false` and `fetch` fails with `"Fetch is not allowed on user build"` (`commands.cpp:753-754`) **regardless of lock state**.
2. Lock gate: even on a debuggable build, `fetch` is rejected on locked devices (`commands.cpp:757-758`).
3. Allow-list gate: even on a debuggable + unlocked device, `fetch` only accepts `vendor_boot*` (`commands.cpp:897-901`); `userdata` is not in the list.

**No gap.** Userdata is not exfiltratable via `fastboot fetch` under any combination of build/lock state. (The ciphertext-at-rest guarantee of §2 means even a hypothetical fetch would yield only ciphertext, but the allow-list makes this moot.)

**Recommendation:** confirm GuardTalkOS ships `user` builds in production (not `userdebug`). This is the single most effective fastboot-hardening lever and is controlled by the lunch target, not the device `.mk`.

### 6.2 `fastboot oem` passthrough is not lock-gated in fastbootd

`OemCmdHandler` (`commands.cpp:262-282`) forwards OEM commands to the vendor fastboot HAL **without** a `GetDeviceLockStatus()` check. fastbootd relies on the vendor HAL to restrict OEM commands. This is vendor-defined behavior, not verifiable from in-tree source.

**Residual risk:** LOW on Pixel — the vendor HAL allow-lists OEM commands on locked devices. But this is a trust boundary that GuardTalkOS inherits from the Pixel vendor blob and cannot audit from source. **Action for Q-FASTBOOT:** empirically probe `fastboot oem <unknown>` on a locked device and confirm it is rejected.

### 6.3 Bootloader is not in-tree (cannot source-audit)

The Pixel bootloader (which enforces `fastboot boot` rejection, the unlock-wipe, and the `flash`/`erase` path at the bootloader level) is a proprietary binary blob. `device/google/zumapro/` contains only configs, not bootloader source. The bootloader-level guarantees in this report (§1.4, §1.6) are based on AOSP protocol semantics + GrapheneOS documentation and **must be empirically verified** in the Q-FASTBOOT task.

### 6.4 Cold-boot / RAM extraction (out of scope)

Cold-boot attacks (freezing RAM and dumping keys) are a hardware-attack class out of scope for fastboot-mode protection. Noted for completeness. Mitigations (if required) are at the SoC/firmware level, not AOSP-configurable.

### 6.5 Evil maid with AVB key leak

If the GuardTalk custom AVB key (from #1) leaks, an attacker can sign a malicious boot/system image and `fastboot flashing lock` a device to it. This is a **#1 key-custody problem**, not a fastboot-protection deficiency. The fastboot layer behaves correctly regardless of *which* key the device is locked to — the deficiency would be in key handling upstream. Mitigation: HSM-backed key storage, documented in the #1 report (`vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md`).

### 6.6 `verifiedbootstate=red` (verification failed) edge

A device in `red` state (locked but verification failed) still has `GetDeviceLockStatus() == true` (since `red != orange`). So fastbootd correctly keeps all mutating commands locked. The bootloader drops the device to recovery/fastboot with a warning and refuses to boot the OS. **No gap.**

---

## 7. Summary table — protection layers

| Threat | Protection layer | In-tree evidence |
|---|---|---|
| `fastboot flash` of malicious system/boot | Locked bootloader rejects; fastbootd rejects | `commands.cpp:606-608` (fastbootd); bootloader is vendor blob |
| `fastboot erase userdata` | fastbootd rejects on locked device | `commands.cpp:230-231` |
| `fastboot -w` (wipe) | `EraseHandler` rejects → `-w` fails | `commands.cpp:230-231` |
| `fastboot boot unsigned.img` | Bootloader rejects unsigned image | vendor blob (not in-tree); AOSP protocol semantics |
| `fastboot fetch userdata` | (1) not in allow-list, (2) locked-gated, (3) compiled out on user builds | `commands.cpp:753-754, 757-758, 897-901`; `Android.bp:145-148` |
| Raw userdata read (desolder) | AES-256-XTS ciphertext; keys in TEE, not on partition | `MetadataCrypt.cpp:77`; `Keystore.cpp:116-124`; `KeyStorage.cpp:62-63` |
| Raw metadata read (desolder) | metadata-encrypted; only wrapped key blob present | `KeyStorage.cpp:62-63` |
| FBE key extraction (runtime, unlocked) | Prevented by lock (cannot boot modified OS) | dependency on #1 (§5) |
| FBE key extraction (TEE hardware attack) | Hardware-bound key, not extractable | `Keystore.cpp:116-124` (TEE/StrongBox) |
| fastbootd entry on locked device | Allowed, but all mutating cmds gated | `commands.cpp:230-758` (every handler) |
| `fastboot oem` on locked device | Not gated by fastbootd; deferred to vendor HAL | `commands.cpp:262-282` (residual risk §6.2) |
| Unlock without wipe | Bootloader enforces wipe on unlock | vendor blob; `PostWipeData` (`commands.cpp:161`) is post-erase only |

---

## 8. Action items for Q-SIGN / Q-FASTBOOT (verification, not implementation)

1. **Build variant check:** confirm `lunch` selects a `user` build (not `userdebug`) for production GuardTalkOS images. This activates the `kEnableFetch=false` path.
2. **Empirical lock-state verification:** `fastboot getvar verifiedbootstate` → expect `yellow` on a GuardTalk-AVB-key-locked device.
3. **Empirical command rejection:** on a locked device, run `fastboot flash system test.img`, `fastboot erase userdata`, `fastboot -w`, `fastboot fetch userdata`, `fastboot boot test.img` — all must FAIL.
4. **Empirical `oem` probe:** `fastboot oem <random>` on a locked device — confirm vendor HAL rejects.
5. **Empirical ciphertext check:** if a spare unlocked device is available, dump userdata via `dd` and confirm high entropy (no plaintext filenames). On a locked device, `fastboot fetch userdata` must fail (so this check is off-device-only).
6. **Unlock-wipe check:** on a test device, `fastboot flashing unlock` (after enabling OEM unlocking) must trigger a full userdata wipe before transitioning to `orange`.
7. **Re-lock check:** `fastboot flashing lock` after flashing GuardTalkOS must re-lock to the custom AVB key → state returns to `yellow`, and unsigned images are rejected.

---

*Generated by AEGIS Auditor (read-only research). All source citations are `file:line` from the in-tree AOSP/GrapheneOS worktree at `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/`. No files were edited outside this report; no git operations were performed.*
