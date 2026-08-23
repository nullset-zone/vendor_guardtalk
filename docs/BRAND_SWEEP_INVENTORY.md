# T-BRAND-SWEEP Inventory — GrapheneOS → GuardTalkOS

**Date:** 2026-07-25  
**Scope:** user-facing product image surfaces under allowed paths  
**Status:** Backend complete → Architect REVIEW

## BEFORE (grep hit counts)

| Path | Files | Hits | Notes |
|------|------:|-----:|-------|
| `vendor/guardtalk/branding` | 8 | 44 | Mostly README/RUNBOOK lineage + gap docs |
| `vendor/guardtalk/overlays` | 12 | 28 | Resource *names* + targetPackage ids; values already GuardTalkOS |
| `vendor/guardtalk/device` | 7 | 18 | Theme comments + kernel path `.../grapheneos` |
| `packages/apps/SetupWizard2/res` | 2 | 4 | Resource names `welcome_to_grapheneos` / `grapheneos_desc` (values GuardTalkOS) |
| **Bootanimation asset** | — | — | `bootanimation.zip` already GuardTalk wordmark (md5 `7ba676c5…`) |
| **Theme include** | — | — | **BUG:** Wave2 bridge hardcoded `device/tokay/guardtalk-theme.mk` |

## AFTER

| Path | Files | Hits | Delta |
|------|------:|-----:|-------|
| `vendor/guardtalk/branding` | 8 | 44 | Shared `guardtalk-theme.mk` added (no new user-facing GrapheneOS) |
| `vendor/guardtalk/overlays` | 12 | 30 | +2 name attrs for SUW defence-in-depth overrides (values GuardTalkOS) |
| `vendor/guardtalk/device` | 6 | 10 | Theme wrappers thinned; tokay theme no longer embeds GrapheneOS comments |
| `packages/apps/SetupWizard2/res` | 2 | 4 | Unchanged (values already GuardTalkOS) |
| **Theme include** | — | — | **FIXED:** `device/$(PRODUCT_DEVICE)/guardtalk-theme.mk` + branding fallback |

### User-visible string VALUES containing “GrapheneOS”

**ZERO** in `vendor/guardtalk/overlays/**/strings*.xml` and `packages/apps/SetupWizard2/res/**/strings*.xml`.

## Replaced vs residual

### Replaced / wired (this task)

| Surface | Action |
|---------|--------|
| Boot animation product path | Confirmed GuardTalk zip; shared `branding/guardtalk-theme.mk` copies to `product/media/bootanimation.zip` |
| tokay + akita theme include | PRODUCT_DEVICE wiring (closes HOLD L1 class gap for akita) |
| SUW welcome/desc overlay | Defence-in-depth `welcome_to_grapheneos` / `grapheneos_desc` → GuardTalkOS values |
| Dark bootanimation leak | Late filter in theme.mk strips `bootanimation-dark.zip` from PRODUCT_COPY_FILES |
| Product model props | Already GuardTalk via `GUARDTALK_PRODUCT_MODEL` (tokay/akita flags) — verified present |

### Residual (justified — do not rewrite)

| Residual | Count class | Justification |
|----------|-------------|---------------|
| AOSP/GOS Java package ids (`app.grapheneos.*`) | High | Forbidden package rename; breaks runtime resolution |
| Resource *names* (`*_grapheneos*`) | ~10 overlay + SUW | Immutable R.java / java-symbol contracts; **values** are GuardTalkOS |
| Kernel tree path `device/google/*-kernels/*/grapheneos` | Few | Real filesystem path for insmod/blocklist; not UI |
| Bootloader ABL splash | 1 gap | Embedded in signed ABL; no BoardConfig hook (documented in bootloader-logo/) |
| Docs/README lineage mentions | Docs | Correctly describe GrapheneOS lineage / diagnostics — keep |
| Settings UI string polish | F-BRAND-UI | Owned by frontend task; backend overlays already GuardTalkOS values |
| `bootanimation-dark.zip` on disk under branding/ | File present | Not PRODUCT_COPY wired; filter strips any dark zip entries |

## Verification

```text
STATIC MK CHECK: PASS (no tokay-hardcoded theme include)
bootanimation.zip: OK (3172137 bytes) md5 7ba676c5704c6e6ab962fb34cc6590ef
preview_frame_assembled.png: GuardTalk wordmark (not GrapheneOS)
VALUE-side GrapheneOS in overlay/SUW strings: ZERO
```

Full `lunch` + `m` not re-run in this pass (static include + asset presence verified).

---

# F-BRAND-UI Inventory — Settings / SUW / SystemUI / Launcher polish

**Date:** 2026-07-25  
**Depends on:** T-BRAND-SWEEP APPROVED  
**Status:** Frontend complete → Architect REVIEW (not APPROVED)

## BEFORE → AFTER string inventory deltas (surfaces touched)

| Surface | Resource / asset | BEFORE (user-visible) | AFTER |
|---------|------------------|-----------------------|-------|
| Settings About summary | `about_settings_summary` | `View legal info, status, software version` | `View GuardTalkOS version, status, and device details` |
| Settings About mark | `ic_guardtalk_logo` | Missing (no brand mark in Settings) | Brand-kit chevron vector in Settings + Settings overlay |
| Settings About header icon | `MyDeviceInfoFragment.initHeader` | User avatar drawable | `R.drawable.ic_guardtalk_logo` |
| Launcher3 home app icon | `ic_launcher_home` | AOSP adaptive (`ic_launcher_home_foreground`) | GuardTalk adaptive via `GuardTalkLauncherOverlay` |
| SUW orphan GOS atom | `grapheneos_icon.xml` | Unused GrapheneOS atom vector shipped in SUW APK | **Deleted** |
| SUW QR missing-scanner copy | `no_qr_scanner` (overlay) | Base already GuardTalkOS; overlay gap | Overlay defence-in-depth GuardTalkOS value |
| Bootanimation UI reference | `guardtalk-theme.mk` → `product/media/bootanimation.zip` | Already GuardTalk (T-BRAND-SWEEP) | **Verified** md5 `7ba676c5704c6e6ab962fb34cc6590ef` — theme.mk untouched |

### VALUE-side GrapheneOS after F-BRAND-UI

**ZERO** in:
- `vendor/guardtalk/overlays/**/strings*.xml`
- `packages/apps/SetupWizard2/res/**/strings*.xml`
- `packages/apps/Settings/res/values/strings*.xml` / `strings_ext.xml` (values)

Verification:

```bash
rg -n '>GrapheneOS<|>grapheneos<' vendor/guardtalk/overlays packages/apps/SetupWizard2/res --glob '**/strings*.xml' || true
rg -n 'GrapheneOS' vendor/guardtalk/overlays --glob '**/strings*.xml' | head -40
```

### Residual count (F-BRAND-UI scope, post-pass)

| Class | Count | Notes |
|-------|------:|-------|
| VALUE-side user-visible `GrapheneOS` (in-scope strings) | **0** | Acceptance met |
| Resource *names* `*_grapheneos*` (values GuardTalkOS) | ~10 | Justified R.java contracts — keep |
| Package ids `app.grapheneos.*` | High | Forbidden rename — keep |
| About PNG banner densities (`ic_guardtalk_about_banner.png`) | Kit gap | SVG sources only in brand kit; vector logo wired instead |
| Default wallpaper drawable in FrameworkBrandOverlay | Kit gap | `branding/wallpapers/` has README only; theme.mk gated — not broken |
| SettingsIconOverlay PNG layers | Already present | No change (XML duplicates avoided) |

### Theme / bootanimation non-regression

- `vendor/guardtalk/branding/guardtalk-theme.mk` **not modified**
- `bootanimation.zip` present; dark zip still filtered by existing late rule
