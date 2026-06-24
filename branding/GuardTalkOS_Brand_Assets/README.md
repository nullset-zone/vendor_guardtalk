# GuardTalkOS — OS Brand Asset Pack

**Purpose:** everything your engineering team needs to replace the stock GrapheneOS / AOSP graphics with GuardTalk branding.
**Source of truth:** the GuardTalk Brand Book. All assets are generated from the canonical mark geometry and the verified palette — no off-brand colour, no re-typeset wordmark.

---

## What's in here

| # | Folder | Replaces in GrapheneOS/AOSP | Format |
|---|--------|------------------------------|--------|
| 00 | `00_brand_reference/` | — (reference) | SVG sources, `colors.xml`, Material-You accent overlay |
| 01 | `01_boot_animation/` | the boot animation | `bootanimation.zip` (ready to flash) + frames preview |
| 02 | `02_wallpapers/` | the default wallpaper | PNG at every Pixel 8/9 resolution + `nodpi` |
| 03 | `03_launcher_icon/` | the system / launcher icon | adaptive VectorDrawables (fg/bg/**monochrome**) + legacy mipmap PNGs |
| 04 | `04_app_icons/` | GuardTalk Messenger & Admin app icons | adaptive icon sets per app |
| 05 | `05_notification_status/` | status-bar / notification small icon | white VectorDrawable + density PNGs |
| 06 | `06_settings_about/` | Settings → About phone branding | banner SVG/PNG + logo vector |
| 07 | `07_setup_wizard/` | first-boot welcome illustration | PNG + SVG |
| 08 | `08_themed_icon/` | Material You themed-icon layer | monochrome VectorDrawable |

> Read **`INTEGRATION_GUIDE.md`** next — it maps each file to its exact path in the AOSP/GrapheneOS source tree, with build flags and honest caveats.

---

## The brand, in one paragraph

The mark is **three stacked chevrons** forming a hexagonal shield — layers of defence, signal rising. The single charged accent is **Signal Green `#C3FF61`** on **Obsidian `#0A0B0C`** / true black. Type is Space Grotesk (display), Inter (UI), JetBrains Mono (technical). The wordmark `guardtalk` is bespoke locked artwork and is shipped here as **vector paths — never re-typeset it**. Tagline, where used: *Privacy locked, spies blocked.*

## Colours (authoritative)

| Token | Hex | Use |
|---|---|---|
| Signal | `#C3FF61` | accent / "secure / your action" — the one charged colour, rationed |
| Signal deep | `#A6E83C` | pressed / hover |
| Obsidian | `#0A0B0C` | primary dark ground |
| True black | `#000000` | OLED / boot |
| Carbon | `#121417` | raised surface |
| Paper | `#F6F7F5` | primary text on dark |
| Tripwire | `#FF5247` | **reserved** — a detected/blocked threat only |
| Caution | `#FFB020` | **reserved** — warning/degraded |
| Anon | `#5BC8FF` | **reserved** — Tor/anonymised/info |

Functional colours (tripwire/caution/anon) are **never decorative** — only their semantic state.

## Non-negotiables (from the brand book)
1. Never recolour the mark off-palette; never add gradients/shadows/glow to the mark itself (the wallpaper glow is a background, not on the mark).
2. Never re-typeset the wordmark — use the supplied vector.
3. Signal green is the action/secure colour; tripwire red means a threat, never a button.
4. Keep it calm — no alarm aesthetics, no "hacker" clichés.

*Generated as ready-to-integrate Android resources. Vector-first; PNG densities provided for legacy paths.*
