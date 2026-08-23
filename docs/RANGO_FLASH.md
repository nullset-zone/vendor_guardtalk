# GuardTalkOS rango — desktop flash path

**Device:** Pixel 10 Pro Fold (`rango`, Tensor / `laguna`)  
**Lunch:** `rango-trunk_staging-userdebug`  
**Bundle symlink:** `releases/desktop-flash/rango-latest`  
**Script:** `scripts/flash-from-remote.sh` (KEEP; also KEEP `vendor/guardtalk/scripts/flash-from-remote.sh` — line-count drift: scripts/ 913 vs vendor 857; do not delete either)

## Distinct from tokay / akita

| Codename | Pretty name | Bundle symlink |
|----------|-------------|----------------|
| tokay | Pixel 9 | `releases/desktop-flash/latest` |
| akita | Pixel 8a | `releases/desktop-flash/akita-latest` |
| rango | Pixel 10 Pro Fold | `releases/desktop-flash/rango-latest` |

Do **not** point `latest` or `akita-latest` at rango stamps.

## Build + stage (build host)

```bash
source build/envsetup.sh
lunch rango-trunk_staging-userdebug
m -j96   # or -j$(nproc)
# On BUILD_EXIT=0, stage releases/desktop-flash/rango-<UTCSTAMP>/ and
# relink rango-latest via the staging helper (hard sepolicy cmp gate +
# MTE/memtag_heap regression gate; see RANGO_BOOT_FIX.md for details):
MODE=hybrid vendor/guardtalk/scripts/stage-rango-release.sh --link-latest
```

`rango-latest` must always resolve to a non-experimental stamp name
(`rango-YYYYMMDD-HHMMSS` — never `rango-hybrid-*` / `rango-memtagfix*`).
Diagnostic-only stamps (`rango-avbcontrol-*`, `rango-fullgt-*`) are produced
by the same script with `MODE=avbcontrol` / `MODE=fullgt` and are never
linked from `rango-latest` — see `vendor/guardtalk/docs/RANGO_BOOT_FIX.md`.

## Desktop flash

```bash
export REMOTE_HOST=openstatestack@192.168.1.4
export REMOTE_BUILD_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-latest
export REMOTE_KEY_DIR=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/rango-latest
# Or: DEVICE=rango  (auto-maps product `rango` → rango-latest)
bash /path/to/scripts/flash-from-remote.sh
```

## Post-flash insmod

`init.insmod.rango.cfg` is installed into `vendor_dlkm` at build time
(`vendor/guardtalk/device/rango/guardtalk-insmod.mk`). The flash script also
downloads the cfg from the bundle and pushes it after reboot (akita-parity
insurance for foldable touch / Wi‑Fi / haptics second-stage modules).

## AVB

Bundle ships **public** `avb_pkmd.bin` only. Prefer `keys/rango/avb_pkmd.bin`
when present; otherwise use the same public-key pattern as akita (tokay public
`avb_pkmd.bin` copy). Never place `*.pem` / `*.pk8` in desktop-flash bundles.
