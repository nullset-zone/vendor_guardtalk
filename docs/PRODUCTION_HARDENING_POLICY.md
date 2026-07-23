# GuardTalkOS Production Hardening Policy

**Task:** `T-SEC-P5-HARDEN` (Backend)  
**Date:** 2026-07-23  
**Target:** Pixel 9 (`tokay`)

## Purpose

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
| Release-key / AVB green | Dev keys / yellow possible | Requires offline release signing + lock (see Signing) |

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
| Verified Boot / rollback | **INHERITED + DOCS** | Pixel AVB + GrapheneOS pipeline; production green needs custom AVB key + lock |
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
| `kernel.perf_event_paranoid` | `3` |

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
| Verified Boot | `ro.boot.verifiedbootstate=green` after custom-key lock + `user` image |
| Rollback | AVB rollback indexes via standard Pixel/GrapheneOS vbmeta pipeline |
| KeyMint | Citadel KeyMint HAL present in tokay VINTF; Weaver used by P2 anti-bruteforce |

Device-side acceptance (when hardware available):

```bash
getenforce                          # Enforcing
getprop ro.debuggable               # 0
getprop ro.guardtalk.production_profile  # 1
getprop ro.boot.verifiedbootstate   # green (after signed+locked)
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

No private keys or irreversible crypto ops are performed by this task. AVB lock
remains an **operator** step outside this change set (see RUNBOOK brick warning).

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
