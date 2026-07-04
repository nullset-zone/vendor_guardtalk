GUARDTALKOS — SYSTEM ICON THEME  ·  Android asset pack  ·  v1.1
==============================================================

Themes the stock app tray to match the GuardTalk apps. Two tiers, one shell:

  TIER 1 · SYSTEM UTILITIES  — soft-white monoline glyph + one Signal-Green accent
    camera/  clock/  contacts/  files/  gallery/  pdfviewer/  settings/
  TIER 2 · GUARDTALK APPS    — Signal-Green glyph, shield DNA
    gtconfig/   (GuardTalk controls — sliders + chevron stamp)
    gtinfo/     (the stacked-shield mark)

Every icon sits on the shared GuardTalkOS ground: obsidian + quiet HUD grid +
a single corner glow. Green stays an accent on utilities so the GuardTalk apps
remain the ones that glow.

PER-APP FILES
-------------
  <app>_adaptive_foreground_432.png   Foreground glyph (transparent), 108dp@4x
  <app>_adaptive_background_432.png   Obsidian background layer, 108dp@4x
  <app>_adaptive_full_432.png         Composed, unmasked preview
  <app>_circle_512.png                Masked — circle  (this device's mask; default)
  <app>_squircle_512.png              Masked — squircle (Pixel)
  <app>_rounded_512.png               Masked — rounded square
  <app>_launcher_{192,144,96,72,48}.png   Pre-masked (circle) legacy mipmaps
  <app>_playstore_512.png             512px hero (circle)

INSTALL — adaptive icon (recommended)
-------------------------------------
  mipmap-anydpi-v26/<app>.xml:
    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
      <background android:drawable="@mipmap/<app>_background"/>
      <foreground android:drawable="@mipmap/<app>_foreground"/>
    </adaptive-icon>
  Put the two 432px layers in mipmap-xxxhdpi (downscale for other buckets).

INSTALL — legacy
----------------
  Drop <app>_launcher_<size>.png into the matching mipmap-<density> bucket
  (48=mdpi · 72=hdpi · 96=xhdpi · 144=xxhdpi · 192=xxxhdpi).

PALETTE
-------
  Signal Green  #C3FF61   accents (utilities) + heroes (GT apps)
  Obsidian      #0A0B0C   the ground
  System White  #E2E6EA   utility glyphs
  Steel Line    #23272E   HUD grid

Spec deck: GuardTalkOS_System_Theme.html   ·   Preview: drawer_mock.png
