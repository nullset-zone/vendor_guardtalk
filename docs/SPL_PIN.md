# Platform security patch pin (GuardTalkOS / komodo)

**Task:** `T-REMEDIATE-B1-USERBUILD` (item 5)  
**Date:** 2026-09-16  
**DEC:** DEC-REMEDIATE-001

## Bulletin pull

Pulled 2026-09-16 from the public Android Security Bulletin:

| Source | URL |
|--------|-----|
| Android Security Bulletin — September 2026 | https://source.android.com/docs/security/bulletin/2026/2026-09-01 |
| Pixel Update Bulletin — September 2026 | https://source.android.com/docs/security/bulletin/pixel/2026/2026-09-01 |

Published 2026-09-08, updated 2026-09-10. Devices at **`2026-09-05`** or later
address all issues in that bulletin (and the Pixel bulletin for Google
devices).

## Pin of record

```
GUARDTALK_SPL_PIN := 2026-09-05
```

Defined in `vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk`.
This is newer than the stale tree value `2026-02-05`.

## Live `PLATFORM_SECURITY_PATCH` (honest)

AOSP/GrapheneOS resolves `PLATFORM_SECURITY_PATCH` from
`RELEASE_PLATFORM_SECURITY_PATCH` in `build/release/flag_values/trunk_staging/RELEASE_PLATFORM_SECURITY_PATCH.textproto`
**before** product makefiles load (`build/make/core/envsetup.mk` includes
`version_util.mk` then later `product_config.mk`). That flag file is
**outside** this card's target paths.

Current tree flag (as of this stamp):

```
string_value: "2026-02-05"
```

`get_build_var PLATFORM_SECURITY_PATCH` will therefore still report
`2026-02-05` until Architect-approved edit of the trunk_staging flag (or a
follow-on card that is allowed to touch `build/release/`). Declaring
`2026-09-05` in `ro.build.version.security_patch` without landing the
bulletin patches would be a PRODUCT-lie — this card does **not** do that.

bp4a tree flag is `2026-05-05` (`build/release/flag_values/bp4a/`) — also
older than the September bulletin.

## Follow-on (not this stamp)

Update `build/release/flag_values/trunk_staging/RELEASE_PLATFORM_SECURITY_PATCH.textproto`
to `2026-09-05` **only** with the matching AOSP/GrapheneOS security patches
merged. Until then: pin documented here; live SPL HOLD vs bulletin.
