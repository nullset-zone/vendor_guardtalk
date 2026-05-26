# GuardTalkSettingsOverlay (F-GT-RADIO-005)

RRO on `com.android.settings`. Backend scaffold only — Frontend owns completion.

## Done (scaffold)

- `config_show_sim_info=false`

## TODO (Frontend)

- Hide **Mobile network** / provider dashboard prefs (`network_provider_*.xml` controllers)
- Hide **Satellite** (`satellite_setting.xml`)
- Hide **Emergency / wireless broadcast** (cell broadcast) entries
- Enable in product: add to `telephony-features.mk` or `guardtalk-tokay.mk`:

```makefile
PRODUCT_PACKAGES += GuardTalkSettingsOverlay
PRODUCT_SOONG_NAMESPACES += vendor/guardtalk/overlays/GuardTalkSettingsOverlay
DEVICE_PACKAGE_OVERLAYS += vendor/guardtalk/overlays/GuardTalkSettingsOverlay
```
