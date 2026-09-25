# GuardTalkOS Production Hardening Policy

**Task:** `T-SEC-P5-HARDEN` (Backend) → `T-REMEDIATE-B1-USERBUILD` (komodo user)  
**Date:** 2026-07-23 (tokay) / 2026-09-16 (komodo user production)  
**Target:** Pixel 9 Pro XL (`komodo`) production; Pixel 9 (`tokay`) pattern

## Komodo production (T-REMEDIATE-B1-USERBUILD, DEC-REMEDIATE-001)

Device under audit: GuardTalk Pixel 9 Pro XL komodo serial `54111FDAS000GN`.
**PASS HOLD remains** — this document does not claim a live rematch.

| Profile | Lunch | `TARGET_BUILD_VARIANT` | `ro.debuggable` | `ro.adb.secure` | `su` / `overlay_remounter` |
|---------|-------|------------------------|-----------------|-----------------|------------------------------|
| **Production** | `komodo-trunk_staging-user` | `user` | `0` (AOSP mapping; do not PRODUCT-lie) | `1` (AOSP user + GuardTalk PRODUCT on user) | Absent (late filter-out) |
| **Sidecar eng-root** | `komodo-trunk_staging-userdebug` | `userdebug` | `1` | AOSP userdebug (not product truth) | AOSP `PRODUCT_PACKAGES_DEBUG` |

- **release-keys:** user variant sets `PRODUCT_DEFAULT_DEV_CERTIFICATE` to
  `vendor/guardtalk/branding/signing-keys/releasekey`. Private keys (`*.pk8`,
  `*.pem`) stay offline (`branding/signing-keys/RUNBOOK.md`). Unsigned lunch
  reports `BUILD_KEYS=dev-keys` (not `testkey`); post-sign yields
  `release-keys`. AVB user pointer + komodo lock procedure:
  T-REMEDIATE-B1-AVB / RUNBOOK §12. Custom-key color is **yellow**;
  operator-goal **green** is HOLD. Keys never in git.
- **`ro.adb.secure=1`:** product truth on the user image. `debug_ramdisk`
  `adb_debug.prop` may still say `0` — that is not the user product.
- **SPL:** pin of record `2026-09-05` from
  [Android Security Bulletin—September 2026](https://source.android.com/docs/security/bulletin/2026/2026-09-01)
  (Pixel bulletin: https://source.android.com/docs/security/bulletin/pixel/2026/2026-09-01).
  Live `PLATFORM_SECURITY_PATCH` still follows trunk_staging
  `RELEASE_PLATFORM_SECURITY_PATCH` (`2026-02-05`) until `build/release/` is
  in-scope. See `vendor/guardtalk/docs/SPL_PIN.md`.
- **Sidecar:** `vendor/guardtalk/docs/ENGINEERING_SIDECAR_USERDEBUG.md`. Not
  in the production product mk.
- **Filter:** `vendor/guardtalk/feature-excised/userbuild-excised.mk` (late
  filter-out; do not edit AOSP `base_system.mk`).

```bash
source build/envsetup.sh && lunch komodo-trunk_staging-user
get_build_var TARGET_BUILD_VARIANT TARGET_BUILD_TYPE PRODUCT_DEFAULT_DEV_CERTIFICATE PLATFORM_SECURITY_PATCH
rg -n "\\bsu\\b|overlay_remounter" vendor/guardtalk/device/komodo vendor/guardtalk/feature-excised vendor/guardtalk/radio-excised
rg -n "ro.adb.secure|release-keys|testkey" vendor/guardtalk/device/komodo vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md
```

If lunch fails on adevtool pin: HOLD that command; mk/docs still land.

---

## Komodo AVB (T-REMEDIATE-B1-AVB, DEC-REMEDIATE-001 item 4)

Device: Pixel 9 Pro XL `komodo`. Serial `54111FDAS000GN` is
**production-custody** — do not `fastboot flashing lock` it without
operator confirmation. This host has empty `adb devices`; lock is
**not** executed here.

### Signing config (user image)

| Variable | User lunch (`komodo-trunk_staging-user`) | Notes |
|----------|------------------------------------------|-------|
| `BOARD_AVB_ALGORITHM` | `SHA256_RSA4096` | Set in `vendor/guardtalk/device/komodo/BoardConfig-excised-late.mk` |
| `BOARD_AVB_KEY_PATH` | `vendor/guardtalk/branding/signing-keys/avb.pem` (overrideable) | **Not** `external/avb/test/data/testkey_rsa4096.pem`. File is gitignored and **absent** on this host. |
| `PRODUCT_DEFAULT_DEV_CERTIFICATE` | `vendor/guardtalk/branding/signing-keys/releasekey` | USERBUILD; unsigned lunch `BUILD_KEYS=dev-keys` |
| `BUILD_KEYS` (unsigned lunch) | `dev-keys` | Honest. Post-sign → `release-keys`. Do not invent release-keys. |
| userdebug sidecar AVB | AOSP test-key fallback | Do not lock the sidecar |

Procedure: `vendor/guardtalk/branding/signing-keys/RUNBOOK.md` §12.
Post-sign: `sign-build.sh --device komodo --key-dir <offline>`.
Lock: `fastboot flashing lock` on a **designated test unit** only, after
3 verified encrypted backups of `avb.pem` (permanent brick if lost).

### Verified-boot color — goal vs Pixel truth (do not PRODUCT-lie)

**Goal (operator Gate 0):** `ro.boot.verifiedbootstate=green`.

**Pixel truth:** a **custom** AVB key in `avb_custom_key` + lock reports
**`yellow`**, not green. Green is the **OEM-embedded** Google key in the
Pixel bootloader ROM. Evidence:
`vendor/guardtalk/docs/SECURITY_FASTBOOT_PROT_REPORT.md` §4.1.

**HOLD:** green is a blocker for Architect/operator. This card documents
the lock procedure and the actual color. It does **not** claim green.
Item **7** (USB duress default-on) still requires
`verifiedbootstate=green` in `UsbPortSecurityHooks` and stays **HOLD**.
Do not change that flag or USB code on this stamp.

| After custom-key lock | Expected `getprop` | Status |
|-----------------------|--------------------|--------|
| `ro.boot.verifiedbootstate` | `yellow` (actual) / `green` (goal) | **HOLD green** |
| `ro.boot.vbmeta.device_state` | `locked` | operator lock, not this host |
| `ro.boot.flash.locked` | `1` | operator lock, not this host |

```bash
rg -n "AVB_VBMETA|BOARD_AVB|release-keys|testkey" vendor/guardtalk/device/komodo vendor/google_devices/komodo device/google/komodo 2>/dev/null
test ! -f vendor/guardtalk/branding/signing-keys/avb.pem
find vendor/guardtalk -name "*.pem" -o -name "*pk8" | head
```

**Forbidden:** `*.pem` / `*.pk8` / `avb.pem` in git. USB GO. Item 7
default-on. Live PASS HOLD lift. Lock without operator.

---

## Komodo telemetry (T-REMEDIATE-B2-TELEMETRY, DEC-REMEDIATE-001 items 11, 14)

Production user: no persistent vendor / RIL / silentlog / logpersistd on disk.
Camera EXIF make/model is not revealed. RIL stays excised (do not re-enable).

| Knob | Production value | Where |
|------|------------------|--------|
| `persist.vendor.camera.exif_reveal_make_model` | `false` | `vendor/google_devices/komodo/sysprop/vendor.prop` + vendor init re-assert |
| `persist.vendor.sys.silentlog.tcp` | `Off` | same vendor.prop (Pixel default was `On`) |
| `persist.vendor.sys.modem.logging.enable` | `false` | same (Pixel default was `true`) |
| `persist.vendor.ril.log_mask` | `0` | same (Pixel default was `3`) |
| `logpersist.start` / `logcatd` | absent from user `PRODUCT_PACKAGES` | `guardtalk-telemetry.mk` late filter |
| `logd.logpersistd.enable` | `false` | PRODUCT_PROPERTY_OVERRIDES (not in vendor.prop) |

Do not PRODUCT_PROPERTY_OVERRIDES the vendor.prop keys — `post_process_props.py`
rejects duplicates with different values. Re-apply vendor.prop after adevtool
(`REGEN_HOOKS.md`). On-device EXIF / `/data` log dirs are **HOLD** until
`Q-REMEDIATE-B2-ONDEVICE`.

```bash
rg -n "logpersist|silentlog|exif_reveal_make_model" vendor/guardtalk/device/komodo vendor/google_devices/komodo vendor/guardtalk
```

---

## Purpose (tokay T-SEC-P5-HARDEN, retained)

Define the GuardTalkOS **production hardening** posture: what is **enforceably applied**
in-tree on this branch versus **inherited** from GrapheneOS/Pixel / **deferred**, with a
clear **production debug-off** path (`ro.debuggable=0`) and rollback.

This phase does **not** invent a Messenger APK and does **not** disable Phase 1–4
fail-closed security.

---

## Lunch / build profile

| Profile | Lunch | `ro.debuggable` | `ro.guardtalk.production_profile` | Intended use |
|---------|-------|-----------------|-------------------------------------|--------------|
| **Production** | `tokay-trunk_staging-user` | `0` (AOSP variant) | `1` (GuardTalk mk) | Release images, AVB green + custom key lock |
| **Engineering / staging** | `tokay-trunk_staging-userdebug` | `1` | unset / absent | Daily bring-up; Settings Dev Options still blocked (P1) |

### Staging → user delta (summary)

| Item | `userdebug` | `user` (production) |
|------|-------------|---------------------|
| `ro.debuggable` | `1` | `0` |
| `ro.secure` / `ro.adb.secure` | AOSP userdebug defaults | AOSP user defaults (ADB non-root) |
| SELinux | Enforcing (GrapheneOS) | Enforcing |
| GuardTalk hardening props | Applied (markers + install block + sysctl rc) | Same + `production_profile=1` |
| Release-key / AVB green | Dev keys / yellow possible | Requires offline release signing + lock (see Signing). **Komodo custom-key lock is yellow, not green** (T-REMEDIATE-B1-AVB HOLD). |

**Do not** force `ro.debuggable=0` via `PRODUCT_PROPERTY_OVERRIDES` on userdebug — that
lies about the image and breaks engineering. Production = lunch `user`.

### Exact verification commands

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
# If lunch fails on adevtool pin: temporarily bypass
# vendor/google_devices/tokay/adevtool-version-check.mk, lunch, restore after.
source build/envsetup.sh
lunch tokay-trunk_staging-user
m out/target/product/tokay/vendor/build.prop init.guardtalk.hardening.rc \
  GuardTalkFrameworksBaseOverlay services -j$(nproc)
rg 'ro.guardtalk.files_|ro.guardtalk.production_|ro.guardtalk.block_unknown' \
  out/target/product/tokay/vendor/build.prop
```

Engineering fallback (props still present; `production_profile` absent):

```bash
lunch tokay-trunk_staging-userdebug
m out/target/product/tokay/vendor/build.prop -j$(nproc)
rg 'ro.guardtalk.files_' out/target/product/tokay/vendor/build.prop
```

---

## Applied vs deferred matrix

| Control | Status | Mechanism |
|---------|--------|-----------|
| Production lunch `user` | **DOCUMENTED + VARIANT** | `lunch tokay-trunk_staging-user` → AOSP sets `ro.debuggable=0` |
| `ro.guardtalk.production_profile=1` | **APPLIED** (user only) | `guardtalk-production-hardening.mk` |
| Hardening master + policy markers | **APPLIED** | `ro.guardtalk.production_hardening=1` + related props |
| Unknown APK / sideload block | **APPLIED** | PMS `ComputerEngine` + `config_defaultFirstUserRestrictions` + USB fail-closed (P2) |
| Accessibility top-level hide | **APPLIED** (P4/UI) | Settings overlay `config_show_top_level_accessibility=false` |
| Accessibility service enroll hard-block | **PARTIAL / DEFERRED** | Marker prop `restrict_accessibility_services`; full DPM-style enroll deny deferred |
| Display overlay / SYSTEM_ALERT_WINDOW | **PARTIAL / DEFERRED** | Marker prop; GrapheneOS ECM + restricted settings; full deny deferred |
| Dynamic code / JIT | **INHERITED** | GrapheneOS `hardened_malloc` + ART; marker prop documents posture |
| SELinux Enforcing | **INHERITED** | GrapheneOS/AOSP user(+debug) Enforcing; marker requires Enforcing for prod accept |
| Verified Boot / rollback | **INHERITED + DOCS + KOMODO POINTER** | Pixel AVB + GrapheneOS pipeline. User `BOARD_AVB_KEY_PATH` points at project `avb.pem`. Custom-key lock color = **yellow** (HOLD vs operator-goal green). |
| KeyMint / HW crypto | **INHERITED** | Pixel citadel KeyMint HAL in `tokay.mk` VINTF (`keymint-service.citadel`) |
| Release-key signing | **WIRING/DOCS ONLY** | `branding/signing-keys/RUNBOOK.md` + `SECURITY_SIGNING_REPORT.md` — **no private keys in git** |
| Debug / Dev Options UI | **APPLIED** (P1) | `block_developer_options` + Settings policy (independent of `ro.debuggable`) |
| ADB data when locked | **APPLIED** (P2) | USB protection fail-closed |
| Allocator (hardened_malloc) | **INHERITED** | GrapheneOS |
| MTE | **INHERITED / DEVICE** | Pixel Tensor / GrapheneOS as enabled upstream; no GuardTalk fork |
| ptrace / dmesg / perf / kexec | **APPLIED** (sysctl) | `init.guardtalk.hardening.rc` |
| eBPF JIT harden | **DEFERRED** | Avoid breaking networking; kernel defaults remain |
| `modules_disabled=1` | **DEFERRED (unsafe)** | Would break `vendor_dlkm` late loads on Pixel |
| debugfs unmount | **DEFERRED** | sepolicy already restricts; invasive init unmount not product-safe here |

---

## Enforceably applied (this task)

### Product properties (live)

File: `vendor/guardtalk/device/tokay/guardtalk-production-hardening.mk`  
Included from: `vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk`

| Property | Value | Meaning |
|----------|-------|---------|
| `ro.guardtalk.production_hardening` | `1` | Master switch |
| `ro.guardtalk.production_profile` | `1` | Only when `TARGET_BUILD_VARIANT=user` |
| `ro.guardtalk.block_unknown_sources` | `1` | PMS unknown-source block |
| `ro.guardtalk.restrict_accessibility_services` | `1` | Marker (+ Settings hide) |
| `ro.guardtalk.restrict_display_overlays` | `1` | Marker |
| `ro.guardtalk.restrict_dynamic_code` | `1` | Marker (inherits GOS) |
| `ro.guardtalk.selinux_enforcing_required` | `1` | Prod acceptance marker |
| `ro.guardtalk.verified_boot_required` | `1` | Prod acceptance marker |
| `ro.guardtalk.keymint_required` | `1` | Prod acceptance marker |
| `ro.guardtalk.sysctl_hardening` | `1` | init sysctl script active |

Phase 1–4 props (including `ro.guardtalk.files_*`) remain in
`guardtalk-product-props.mk` and must appear in regenerated `vendor/build.prop`.

### Init sysctls

Module: `init.guardtalk.hardening.rc` → `/system/etc/init/`

| Sysctl | Value |
|--------|-------|
| `kernel.kptr_restrict` | `2` |
| `kernel.dmesg_restrict` | `1` |
| `kernel.yama.ptrace_scope` | `1` |
| `kernel.kexec_load_disabled` | `1` |
| `kernel.perf_event_paranoid` | `2` |
| `kernel.unprivileged_bpf_disabled` | `1` (boot_completed only; not late-init) |

`CONFIG_SECURITY_YAMA=y` fragment: `device/google/caimito-kernels/6.1/guardtalk-security-yama.config`. Live `grapheneos/Image.lz4` is a prebuilt — `__lsm_yama` ABSENT in `System.map` until kernel rebuild. `ptrace_scope` writes stay fail-soft.

### PackageManager unknown-source block

- Runtime: `GuardTalkProductionHardeningPolicy.mustBlockUnknownSources()` in
  `ComputerEngine.isInstallDisabledForPackage` (non-system/root UIDs).
- First-boot SYSTEM user: overlay
  `config_defaultFirstUserRestrictions` → `no_install_unknown_sources`
  (`GuardTalkFrameworksBaseOverlay`).
- Defence-in-depth: Phase-2 USB fail-closed strips ADB/MTP/PTP when locked /
  pre-unlock (APK-over-USB).

### Policy API

`android.guardtalk.GuardTalkProductionHardeningPolicy` — consumed by PMS now;
`T-SEC-P5-STATUS` should read the same props for Security status rows.

---

## Release-key signing (no secrets in-tree)

| Item | Location | Notes |
|------|----------|-------|
| Offline keygen / backup | `vendor/guardtalk/scripts/generate-signing-keys.sh`, `backup-signing-keys.sh` | Air-gapped host |
| Runbook | `vendor/guardtalk/branding/signing-keys/RUNBOOK.md` | Includes brick warning for AVB |
| Research | `vendor/guardtalk/docs/SECURITY_SIGNING_REPORT.md` | GO for custom AVB + lock |
| Sign / flash | `vendor/guardtalk/scripts/sign-build.sh`, `flash-signed.sh` (if present per T-SIGN-PIPELINE) | Keys from secure path only |

**Forbidden:** committing `*.pk8`, `avb.pem`, passphrases, or `.env` key material.

Production signing sequence (operator):

1. `lunch tokay-trunk_staging-user && m dist` (or project release target).
2. Sign target-files with offline keys (`RUNBOOK` / `sign-build.sh`).
3. Flash factory image **without** `--disable-verification`.
4. Lock bootloader with custom `avb_pkmd.bin` only after encrypted key backup verified.

---

## SELinux / Verified Boot / KeyMint

| Layer | Expectation on production device |
|-------|----------------------------------|
| SELinux | `getenforce` → `Enforcing` |
| Verified Boot | Custom-key lock: `ro.boot.verifiedbootstate=yellow` (Pixel truth). Operator goal `green` is **HOLD** (OEM-embedded key only). See T-REMEDIATE-B1-AVB / RUNBOOK §12d. |
| Rollback | AVB rollback indexes via standard Pixel/GrapheneOS vbmeta pipeline |
| KeyMint | Citadel KeyMint HAL present in tokay VINTF; Weaver used by P2 anti-bruteforce |

Device-side acceptance (when hardware available):

```bash
getenforce                          # Enforcing
getprop ro.debuggable               # 0
getprop ro.guardtalk.production_profile  # 1
getprop ro.boot.verifiedbootstate   # yellow after custom-key lock; green is HOLD (OEM key)
getprop ro.guardtalk.files_policy   # 1
```

---

## Carry-forward: `files_*` in vendor/build.prop

`ro.guardtalk.files_policy` / `files_trash` / `files_protect_critical` are already
declared in `guardtalk-product-props.mk`. Stale images omit them until:

```bash
m out/target/product/tokay/vendor/build.prop -j$(nproc)
rg 'ro.guardtalk.files_' out/target/product/tokay/vendor/build.prop
```

---

## Rollback (Law 11)

1. Remove include of `guardtalk-production-hardening.mk` from
   `guardtalk-radio-excised.mk` (or zero the props).
2. Remove `PRODUCT_PACKAGES += init.guardtalk.hardening.rc` from
   `guardtalk-feature-excised.mk` / docs mirror; delete or keep inert `.rc`.
3. Revert `ComputerEngine.isInstallDisabledForPackage` GuardTalk block.
4. Revert `config_defaultFirstUserRestrictions` overlay array (existing users keep
   prior restriction until factory reset / restriction clear — document for ops).
5. Delete `GuardTalkProductionHardeningPolicy.java` if unused.
6. Rebuild:

```bash
m out/target/product/tokay/vendor/build.prop services \
  GuardTalkFrameworksBaseOverlay init.guardtalk.hardening.rc -j$(nproc)
```

No private keys or irreversible crypto ops are performed by this task. AVB
lock remains an **operator** step (RUNBOOK §12 brick warning). Custom-key
lock is **yellow** on Pixel; green is HOLD. Item 7 USB is not this card.

---

## Files touched

| Path | Change |
|------|--------|
| `vendor/guardtalk/device/tokay/guardtalk-production-hardening.mk` | **NEW** live props |
| `vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk` | Include hardening mk |
| `vendor/guardtalk/init/init.guardtalk.hardening.rc` | **NEW** sysctls |
| `vendor/guardtalk/init/Android.bp` | prebuilt_etc for hardening rc |
| `vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk` | PRODUCT_PACKAGES |
| `vendor/guardtalk/device/tokay/guardtalk-tokay.mk` | Docs mirror |
| `frameworks/base/core/java/android/guardtalk/GuardTalkProductionHardeningPolicy.java` | **NEW** policy API |
| `frameworks/base/services/core/java/com/android/server/pm/ComputerEngine.java` | Unknown-source block |
| `vendor/guardtalk/overlays/GuardTalkFrameworksBaseOverlay/res/values/config.xml` | First-user restriction |
| `vendor/guardtalk/docs/PRODUCTION_HARDENING_POLICY.md` | **NEW** this doc |

---

## Phase 1–4 integrity

All prior fail-closed props (`password_only_lock`, `usb_protection_fail_closed`,
`secure_wipe_enabled`, `privacy_tmpfs`, `files_*`, etc.) remain in
`guardtalk-product-props.mk` unchanged. This task only **adds** hardening layers.
