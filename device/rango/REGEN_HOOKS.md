# Re-apply after `adevtool generate-all -d rango`

> Instance of `vendor/guardtalk/device/REGEN_HOOKS.md` for **rango**
> (laguna / laguna-kernels 6.6 / Goodix FP / foldable). Keep in sync with
> the shared recipe. **rango is laguna — not zumapro.**

## BoardConfig.mk (end of file)

```makefile
# GuardTalkOS rango: strip modem partition after AB_OTA list is defined
include vendor/guardtalk/device/rango/BoardConfig-excised-late.mk
```

## rango.mk (end of file)

```makefile
# Late pass: remove RIL/modem packages and copy-files (must include, not inherit-product)
include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk

# GuardTalkOS rango: install init.insmod.rango.cfg (symlink TARGET_KERNEL_DIR breaks find-copy)
include vendor/guardtalk/device/rango/guardtalk-insmod.mk

# Kill memtag-common.mk async path defaults (bpfloader/netd/ip) — see guardtalk-memtag.mk
include vendor/guardtalk/device/rango/guardtalk-memtag.mk
```

## Per-device notes

- **SoC:** laguna (Pixel 10 Pro Fold). Not zumapro (tokay) or zuma (akita).
- **Blocklist:** `vendor/guardtalk/device/rango/vendor_dlkm.modules.blocklist`
  (laguna-kernels grapheneos/rango baseline + `blocklist nitrous.ko`). Do not
  reuse the tokay caimito file under `feature-excised/`.
- **Kernels (trunk_staging):** durable aconfig
  `RELEASE_KERNEL_RANGO_DIR` → `device/google/laguna-kernels/6.6/grapheneos/rango`.
  Symlink `trunk-14072179` → `grapheneos/` remains for any tooling that still
  looks up the old trunk path (see
  `device/google/laguna-kernels/6.6/README.guardtalk-trunk-14072179.md`).
- **Fingerprint:** Goodix (gf3626 / goodixfingerprint / fingerprint-goodix.rc)
  — covered by shared `fp-excised.mk` once the late radio/feature include fires.
- **Foldable preserve:** hinge_angle, device_state_configuration, display_port_0/1,
  rgea/rgeb panels, hall_sensor, twoshay, concurrent_foldable_dual_front,
  framework unfold RROs — not excision targets.
- After filter changes: `rm -f out/soong/soong.rango.variables out/soong/soong.rango.extra.variables`
