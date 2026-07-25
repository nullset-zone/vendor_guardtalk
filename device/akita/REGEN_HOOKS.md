# Re-apply after `adevtool generate-all -d akita`

> Instance of `vendor/guardtalk/device/REGEN_HOOKS.md` for **akita** (zuma /
> akita-kernels / Goodix FP). Keep in sync with the shared recipe.

## BoardConfig.mk (end of file)

```makefile
# GuardTalkOS akita: strip modem partition after AB_OTA list is defined
include vendor/guardtalk/device/akita/BoardConfig-excised-late.mk
```

## akita.mk (end of file)

```makefile
# Late pass: remove RIL/modem packages and copy-files (must include, not inherit-product)
include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
```

## Per-device notes

- **Blocklist:** `vendor/guardtalk/device/akita/vendor_dlkm.modules.blocklist`
  (akita-kernels baseline + `blocklist nitrous`). Do not reuse the tokay
  caimito file under `feature-excised/`.
- **Kernels (trunk_staging):** `RELEASE_KERNEL_AKITA_DIR` →
  `device/google/akita-kernels/6.1/trunk-14096387`. On this tree that path is
  a symlink to `grapheneos/` (see
  `device/google/akita-kernels/6.1/README.guardtalk-trunk-14096387.md`).
- **Fingerprint:** Goodix — covered by shared `fp-excised.mk` once the late
  radio/feature include fires.
- After filter changes: `rm -f out/soong/soong.akita.variables out/soong/soong.akita.extra.variables`
