# GuardTalk boot animation assets

## F-REMEDIATE-B5-BRANDING (item 22)

`logo_1008x2244.png` is the **komodo** (Pixel 9 Pro XL) boot-logo source:
exactly **1008×2244** (75% of the 1344×2992 panel). The GuardTalk chevron
(“G”) is composed **inside a safe zone** (12% left/right, 14% top, 12%
bottom) so the mark is not cropped — unlike full-bleed `mark_signal.svg`
(paths run to x=0 and x=1024) or a cover-scale of 1080×2400 onto this
canvas.

| File | Role |
|------|------|
| `logo_1008x2244.png` | Komodo boot-logo PNG (this directory; layout unchanged) |
| `bootanimation.zip` | AOSP zip **1008×2244** (`desc.txt` first line `1008 2244 24`) |
| `bootanimation-dark.zip` | Not PRODUCT_COPY wired; theme.mk strips dark zip entries |

Brand-kit copies:
`vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/logo_1008x2244.png`
`vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/bootanimation.zip`
`vendor/guardtalk/branding/GuardTalkOS_Brand_Assets/01_boot_animation/desc.txt`

This PNG is **not** the pre-kernel ABL splash (`bootloader-logo/` — no
auto-wire on Pixel). `guardtalk-theme.mk` copies `bootanimation.zip` when
present. F-REMEDIATE-B5-BOOTZIP packs the existing safe-zone PNG as STORED
frames (`part0/000.png`, `part1/000.png`). Do not crop the G.

Regenerate PNG: `python3 vendor/guardtalk/branding/scripts/render_f_remediate_b5_branding.py`

## F-REMEDIATE-B5-BOOTZIP (item 22 residual)

Pack zip (does not rewrite the PNG):
`python3 vendor/guardtalk/branding/scripts/pack_f_remediate_b5_bootzip.py`
