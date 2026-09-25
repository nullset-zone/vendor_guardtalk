# GuardTalk Messenger — Gateway Jami provision

**Task:** `T-REMEDIATE-B4-MESSENGER` (item 19)  
**Date:** 2026-09-16  
**Device:** GuardTalk Pixel 9 Pro XL **komodo** (user image)

## Why bake, not sideload

Production hardening **blocks unknown APKs** (PMS `ComputerEngine` +
`config_defaultFirstUserRestrictions` + USB fail-closed). The device has no
browser, no Play Store, and no GMS. A Gateway “download and `pm install`”
procedure cannot install Messenger on this product.

**Install mechanism:** Soong module `GuardTalkMessenger` in user
`PRODUCT_PACKAGES` → `/product/app/GuardTalkMessenger/` package
`com.guardtalk.messenger`.

Gateway provision below is the **Jami daemon / rendezvous** path, not an
alternate APK installer.

## Device client (baked)

| Field | Value |
|-------|--------|
| Package | `com.guardtalk.messenger` |
| Module | `GuardTalkMessenger` |
| Source | `vendor/guardtalk/apps/GuardTalkMessenger/` |
| Protocol | Jami RING via JSON-RPC 2.0 |
| Peer | Wi-Fi DHCP default-route host (RFC1918 only) |
| URL | `http://<gateway-ip>:8080/jami/jsonrpc` |
| Fail-closed | Missing DHCP, non-RFC1918, HTTP/RPC error → no send |

The client does **not** join the public Jami DHT. All traffic stays on the
Gateway LAN (pairs with gateway-only Wi-Fi, item 21).

## Gateway host (operator)

On the GuardTalk Gateway (the DHCP router / default route for the provisioned
SSID), run jamid and expose JSON-RPC on the LAN address only:

1. Install Jami daemon (`jamid`) from Savoir-faire Linux packages or a
   pinned in-house build. Do not point the phone at `dl.jami.net`.
2. Bind an HTTP JSON-RPC adapter to `0.0.0.0:8080` path `/jami/jsonrpc`
   **or** to the Gateway LAN address only (preferred). Do not publish 8080
   on WAN.
3. Implement (or proxy to jamid D-Bus) these methods:

| Method | Params | Result |
|--------|--------|--------|
| `addAccount` | `[{"Account.type":"RING"}]` | RING account id (string) |
| `getConversations` | `[accountId]` | conversation list |
| `sendTextMessage` | `[accountId, peerId, body]` | jamid send result |

4. Confirm the phone’s DHCP router IP equals that bind address
   (`ip route` / Gateway DHCP pool).
5. First launch on device: **Register Jami account**, then send to a 40-hex
   peer id.

No Play Store, no F-Droid, no browser, no USB `pm install`, no GMS.

## Rollback (Law 11)

1. Remove `PRODUCT_PACKAGES += GuardTalkMessenger` from
   `vendor/guardtalk/radio-excised/product-config-late.mk`.
2. Remove the include of `guardtalk-messenger.mk` from
   `vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk`.
3. Delete `vendor/guardtalk/apps/GuardTalkMessenger/` if retiring the app.
4. Keep `default-permissions-com.guardtalk.messenger.xml` unless also
   reverting T-SEC-P4-PERMS (grants no-op without the package).

## Verification (host)

```bash
rg -n "guardtalk.messenger|jami|Jami" vendor/guardtalk --glob '!out/**'
source build/envsetup.sh && lunch komodo-trunk_staging-user
get_build_var PRODUCT_PACKAGES | tr ' ' '\n' | grep -x GuardTalkMessenger
```

On-device launch and Gateway jamid e2e are **HOLD** (PASS HOLD / adb empty).
