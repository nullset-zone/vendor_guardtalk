# QA Evidence — Q-REMEDIATE-B4-WIFI-GW

**Task:** `Q-REMEDIATE-B4-WIFI-GW` (independent rematch of `T-REMEDIATE-B4-WIFI-GW` item **21**)  
**Date:** 2026-09-16T13:57:00Z  
**Agent:** QA_ENGINEER (Panel 4)  
**Depends:** `T-REMEDIATE-B4-WIFI-GW` Architect-APPROVED static (2026-09-16T13:40:00Z) — **not trusted**  
**DEC:** DEC-REMEDIATE-002  
**Verdict:** **PASS (host static + user lunch)** — empty saved-set association **HOLD**. Vendor SSID file has no in-tree runtime reader **HOLD**. Stale `out/target/product/komodo/vendor/etc/wifi/wpa_supplicant_overlay.conf` still Pixel `hs20=1`/`interworking=1` **HOLD**. On-device associate **HOLD**. **Not device-fixed.** Status → **REVIEW** (never APPROVED).

Independent rematch. Backend completion report and Architect APPROVE were **not trusted**. Product source was not edited. Lunch was re-run on this host. Stale `out/` was **not** treated as PASS or FAIL of this card. No USB GO. No wipe. No `m`. No commit. Open Wi-Fi / extra radios not weakened. Memory-bank **not** written (dispatch).

GIP-0: loaded `.memory-bank/` (activeContext, progress, decisions, projectBrief, systemPatterns) and AGENTS.md + PROTOCOL/ROLES + `.aegis/governance/gates/gate_neg1_guardian_first.yaml`. Gate -1 in-process (24 laws + 11 gates YAML). Guardian MCP/HTTP not called (TOOL UNAVAILABLE / forbidden). Gate 5 HUMAN SKIP.

## Acceptance matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | User lunch `komodo-trunk_staging-user`: GuardTalk wpa overlay + `guardtalk_gateway_ssids` + wifi-gateway.rc in `PRODUCT_COPY_FILES`; Pixel wpa overlay ABSENT; `persist.radio.disabled=1` still set | **PASS** | independent lunch + `get_build_var`; RIL `=0` ABSENT |
| 2 | First-user overlay `no_add_wifi_config` (+ tethering/direct) in GuardTalkFrameworksBaseOverlay | **PASS** | `config_defaultFirstUserRestrictions` items; overlay PRESENT in user `PRODUCT_PACKAGES` |
| 3 | `wpa_supplicant_overlay.conf`: `filter_ssids=1` `hs20=0` | **PASS** | GuardTalk overlay exact keys; Pixel source remains `hs20=1` (filtered at lunch) |
| 4 | `guardtalk_gateway_ssids`: comments only, **zero SSIDs** | **PASS** | `SSID_NONCOMMENT_COUNT=0`; no PSK in komodo wifi dir |
| 4a | Empty saved set does not filter association until an SSID is saved | **HOLD** | wpa `filter_ssids` uses saved networks; documented, not FAIL |
| 4b | Vendor SSID file runtime consumer | **HOLD** | no in-tree Java/Kotlin/C reader of `guardtalk_gateway_ssids` / `ssid_allowlist_path` |
| 5 | `adb devices` empty → on-device associate | **HOLD** | empty adb; not device-fixed |
| 6 | Open Wi-Fi / extra radios remain forbidden | **PASS** | hotspot still hidden; `no_wifi_tethering`/`no_wifi_direct`; HS20 off; wifi-gateway.mk does not restore RIL/BT/NFC; user packages NFC/BT HAL ABSENT |
| 7 | Stale `out/` wpa overlay not FAIL or PASS of this card | **HOLD** | still Pixel `hs20=1`; missing SSID file + wifi-gateway.rc in out/ |
| 8 | Status REVIEW only; never APPROVED; no commit; not device-fixed; PASS HOLD remains | **PASS** | this stamp |

## Suite of record

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0=/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/vendor/adevtool
bash vendor/guardtalk/docs/qa/verify_remediate_b4_wifi_gw_host.sh
# RESULT: PASS (host)  bash_PASS=65 bash_HOLD=9 PY_RC=0
# PY_COUNTS PASS_COUNT=24 FAIL_COUNT=0 HOLD_COUNT=1
# COMBINED: PASS_COUNT=89 HOLD_COUNT=10 FAIL=0 EXIT=0
# LIVE_DEVICE_CLAIMED=false
# STALE_OUT_WPA=HOLD (Pixel hs20=1/interworking=1)
# ONDEVICE_ASSOCIATE=HOLD
# EMPTY_SAVED_SET_FILTER=HOLD
# DEVICE=HOLD
# PASS_HOLD=remains
```

Raw output: `vendor/guardtalk/docs/qa/Q-REMEDIATE-B4-WIFI-GW_SUITE.out`

`pytest platform/tests` N/A (AOSP product mk / overlay / vendor init, not AEGIS Python platform).

## Independent rematch (do not trust T / Architect dumps)

### Lunch (user product)

This host, this stamp:

```
lunch komodo-trunk_staging-user
TARGET_PRODUCT=komodo
TARGET_BUILD_VARIANT=user
```

Session-only `GIT_CONFIG` `safe.directory` for `vendor/adevtool`. `set -u` off around envsetup.

User `PRODUCT_COPY_FILES`:

- `vendor/guardtalk/device/komodo/wifi/wpa_supplicant_overlay.conf:vendor/etc/wifi/wpa_supplicant_overlay.conf` **PRESENT**
- Pixel `vendor/google_devices/komodo/proprietary/vendor/etc/wifi/wpa_supplicant_overlay.conf` **ABSENT**
- `guardtalk_gateway_ssids` **PRESENT**
- `init.guardtalk.wifi-gateway.rc` **PRESENT**
- `p2p_supplicant_overlay.conf` **PRESENT** (`no_wifi_direct` is the Direct block)

User `PRODUCT_PROPERTY_OVERRIDES`: `persist.radio.disabled=1`; `ro.guardtalk.wifi.gateway_only=1`; `ro.guardtalk.wifi.fail_closed=1`. Does **not** contain `persist.radio.disabled=0`.

User `PRODUCT_PACKAGES`: `GuardTalkFrameworksBaseOverlay` **PRESENT**; `GuardTalkSettingsOverlay` **PRESENT**; NFC/BT HAL packages **ABSENT**.

### Static source of record

- `GuardTalkFrameworksBaseOverlay` first-user: `no_install_unknown_sources`, `no_add_wifi_config`, `no_wifi_tethering`, `no_wifi_direct`. Does **not** set `no_config_wifi_private/shared` (GMP privileged add path).
- `GuardTalkSettingsOverlay`: `config_show_wifi_settings=true` (gateway path visible); `config_show_wifi_hotspot_settings=false` (not re-opened).
- GuardTalk wpa overlay: `filter_ssids=1` `hs20=0` `interworking=0`. Pixel source still `hs20=1` `interworking=1` (must not ship).
- `guardtalk_gateway_ssids`: comments/blanks only. `SSID_NONCOMMENT_COUNT=0`. No PSK.
- `guardtalk-wifi-gateway.mk` included from `guardtalk-production-hardening.mk`; filter-out Pixel wpa dest; copies GuardTalk overlay + SSID list + vendor init. Does not add `PRODUCT_PACKAGES`. Does not restore RIL/BT/NFC.
- `init.guardtalk.wifi-gateway.rc`: `on post-fs-data` re-asserts `persist.vendor.wifi.guardtalk_gateway_only 1`. Does not start RIL. Does not write `persist.radio.disabled`.
- `guardtalk-radio-excised.mk`: `persist.radio.disabled=1` remains. No `=0` in vendor/guardtalk mk/rc/prop/bp.

### Stale out/ (not product truth)

`out/target/product/komodo/vendor/etc/wifi/wpa_supplicant_overlay.conf` still Pixel `interworking=1` `hs20=1`. SSID list and wifi-gateway.rc **absent** from stale out. **HOLD until rebuild.** Not FAIL. Not PASS.

### Residuals (not FAIL)

- Empty saved-network set does not filter association until an SSID is saved (`wpa_supplicant` `filter_ssids`). Pre-provision Settings add/tap-connect is the first-user restriction layer.
- Vendor SSID allowlist is copied + property-pointed; no in-tree Java/Kotlin/C reader. Not a runtime firewall by itself.
- Default-restrictions apply at user creation only (upgrade users already created **HOLD**).
- Privileged SUW/GuardTalkConfig `applyWifiLockdown` remains the post-QR `WifiSsidPolicy` path (out of this card's product-edit scope).

## Harness note (not a product FAIL)

First suite run FAILed `GuardTalkFrameworksBaseOverlay` ABSENT and HOLD `p2p_supplicant_overlay.conf` absent because `set -o pipefail` + `grep -q` SIGPIPE when the token is early. Tightened to the Q-SENSORS token-filter (no `grep -q`). Re-run EXIT 0: overlay PRESENT; p2p PRESENT. **Not a missing overlay.**
