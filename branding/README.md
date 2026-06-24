# GuardTalk brand kit — gap register (T-W2-I6-THEME)

> **STATUS: PLACEHOLDER.** No GuardTalk brand kit (logos, boot animation frames,
> wallpapers, final color palette) has been delivered by the operator yet. This
> directory defines the **structure** that receives the assets and the
> **placeholder theme** that all GuardTalk overlays currently consume. Every
> placeholder value is tagged `PLACEHOLDER` so it can be grepped and replaced
> verbatim when the real kit lands.

This directory was empty at the start of T-W2-I6-THEME (the previous README was
removed in the stashed change set and was intentionally not restored — see
`.agent-comm/inbox/TO_ARCHITECT.md` for T-W2-I5-LOC). It is now repopulated as
the canonical GuardTalk brand source for the vendor layer.

## Layout

```text
branding/
├── README.md                This gap register
├── theme/
│   ├── README.md            Placeholder theme contract (colors, strings, voice)
│   ├── colors.xml           GuardTalk brand color palette (PLACEHOLDER)
│   └── strings.xml          GuardTalk brand strings (PLACEHOLDER)
├── bootanimation/
│   └── README.md            bootanimation.zip gap + frame spec
└── wallpapers/
    └── README.md            default wallpaper gap + asset spec
```

The XML under `theme/` is **not** built directly. It is the single source of
truth that the runtime-resource overlays under
`vendor/guardtalk/overlays/GuardTalk*/res/values/` mirror. When the brand kit
lands, update `theme/colors.xml` + `theme/strings.xml` here first, then
propagate the same values into each overlay's `res/values/` files. The mirrors
exist (rather than a single shared include) because each RRO targets a
different `targetPackage` and must ship its own resource table.

## What the operator must deliver

The following assets are required to lift T-W2-I6-THEME from PLACEHOLDER to
FINAL. Each row maps to an acceptance criterion of the task.

| Asset                              | Format / spec                                    | Delivers to                                    | Criterion |
|------------------------------------|--------------------------------------------------|------------------------------------------------|-----------|
| GuardTalk logo (filled tile)       | PNG, transparent, 512×512 (xxxhdpi), `ic_guardtalk_logo.png` | `branding/theme/` → overlays + SetupWizard2 (I7-WIZ) | logos |
| GuardTalk wordmark                 | PNG, transparent, 1024×256, `ic_guardtalk_wordmark.png` | Settings about-phone header, SetupWizard2 Welcome | logos |
| GuardTalk logo (transparent-black) | PNG, transparent, 512×512, `ic_guardtalk_logo_black.png` | SetupWizard2 Welcome (ties to T-W2-I7-WIZ)     | logos |
| Boot animation frames              | PNG sequence 1080×2400, ≤30 fps, ≤8 s; or finished `bootanimation.zip` per AOSP `system/core/libbootanimation/` format | `branding/bootanimation/bootanimation.zip`     | boot anim |
| Default wallpaper (light)          | JPEG/PNG, 1080×2400+, `wallpaper_guardtalk_default.png` | `branding/wallpapers/`                          | wallpapers |
| Default wallpaper (dark)           | JPEG/PNG, 1080×2400+, `wallpaper_guardtalk_dark.png` | `branding/wallpapers/`                          | wallpapers |
| Final color palette                | Material You system palette mapping (primary, accent, neutral1/2 ramps) | `branding/theme/colors.xml`                    | colors |
| Final OS/device strings            | OS name, device display name, manufacturer display string | `branding/theme/strings.xml`                   | strings |

Until these land, the overlays build and install with the placeholder values
defined in `theme/`. The build is green; the on-device result is a coherent
dark-teal GuardTalk-styled image (not GrapheneOS-branded) that is visually
distinct from upstream.

## GuardTalk placeholder theme at a glance

| Token                          | PLACEHOLDER value | Notes                                  |
|--------------------------------|-------------------|----------------------------------------|
| `guardtalk_primary`            | `#0B6E99`         | Teal-blue (trust + comms)              |
| `guardtalk_accent`             | `#18C2D2`         | Cyan (clarity / voice)                 |
| `guardtalk_background_dark`    | `#0E1419`         | Privacy dark background                |
| `guardtalk_surface_dark`       | `#1A232C`         | Card / surface on dark                 |
| `guardtalk_on_primary`         | `#FFFFFF`         | Text on primary                        |
| `guardtalk_error`              | `#FF5454`         | Error / destructive                    |
| `guardtalk_success`            | `#2DD4A7`         | Success / verified                     |
| `guardtalk_os_name`            | `GuardTalkOS`     | OS display name                        |
| `guardtalk_device_name`        | `GuardTalk`       | Device display name                    |
| `guardtalk_manufacturer`       | `GuardTalk`       | Manufacturer display string            |

## Governance

- Source-only: no build is run in this increment (per dispatch constraints).
- Do NOT edit `vendor/google_devices/tokay/tokay.mk` or `BoardConfig.mk` —
  branding flows exclusively through `vendor/guardtalk/` overlays + the
  `device/tokay/guardtalk-theme.mk` hook (included from `guardtalk-tokay.mk`).
- No GrapheneOS-branded user-facing assets are introduced here; the only
  residual "GrapheneOS" string in `vendor/guardtalk/` is the legitimate
  upstream-lineage reference in `device/tokay/REGEN_HOOKS.md` (see verification
  section of the completion report).
