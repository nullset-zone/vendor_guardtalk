package com.guardtalk.config

import android.content.Context
import android.net.Ikev2VpnProfile
import android.net.VpnManager
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiSsid
import android.app.admin.DevicePolicyManager
import android.app.admin.WifiSsidPolicy
import android.os.UserManager
import android.provider.Settings
import java.nio.charset.StandardCharsets

/**
 * Applies a verified [QrPayloadParser.ConfigPayload] to the device.
 *
 * Every apply method is best-effort and reports its outcome through [Result]
 * so the activity can show a granular success/failure summary. No apply
 * method throws; a failure on one setting does NOT abort the others (Law 9:
 * Graceful Degradation) except where a hard prerequisite is missing (e.g. VPN
 * provisioning needs a non-empty server/identity/psk).
 *
 * Trust context: the app is platform-signed + privileged (see Android.bp), so
 * the WifiServiceImpl connection path's `isPrivileged || isAdmin || isSystem`
 * check (WifiServiceImpl.java:4587) BYPASSES the user restrictions this very
 * class installs for the Syndicate lockdown, allowing later updates of the GMP
 * SSID while the user cannot add/configure WiFi.
 */
class ConfigApplier(private val context: Context) {

    /** Granular per-setting outcome. */
    data class Step(val name: String, val ok: Boolean, val detail: String) {
        override fun toString() = "${if (ok) "OK" else "FAIL"} $name: $detail"
    }

    data class Result(val steps: List<Step>) {
        val allOk: Boolean get() = steps.all { it.ok }
        override fun toString() =
            (if (allOk) "ALL OK" else "PARTIAL") + steps.joinToString("\n  ", "\n  ")
    }

    private val steps = mutableListOf<Step>()

    /**
     * Apply the full payload. If [QrPayloadParser.ConfigPayload.secureLevel]
     * is "syndicate" the WiFi lockdown (Task 2) is applied LAST so the
     * allowlisted SSID is already provisioned before the user restrictions
     * lock the surface down.
     */
    fun apply(payload: QrPayloadParser.ConfigPayload): Result {
        steps.clear()
        applySecureLevel(payload.secureLevel)
        applyPrivateDns(payload.privateDns)
        applyConnectivityServer(payload.connectivityServer)
        applyWifi(payload.wifiSsid, payload.wifiPassword)
        applyVpn(payload.vpnServer, payload.vpnIdentity, payload.vpnPsk)
        if (payload.secureLevel == QrPayloadParser.SECURE_LEVEL_SYNDICATE) {
            applyWifiLockdown(payload.wifiSsid)
        }
        return Result(steps)
    }

    /** 1. secure level → Settings.Global["guardtalk_secure_level"]. */
    private fun applySecureLevel(level: String) {
        val ok = Settings.Global.putString(
            context.contentResolver, "guardtalk_secure_level", level
        )
        steps += Step(
            "secure_level", ok,
            if (ok) "guardtalk_secure_level=$level" else "putString returned false"
        )
    }

    /**
     * 2. Private DNS → Settings.Global "private_dns_mode" = "hostname" +
     * "private_dns_specifier" = hostname. The Settings.Global.PRIVATE_DNS_MODE
     * / PRIVATE_DNS_SPECIFIER constants are @hide (Settings.java:16778/16784)
     * and therefore absent from the system_current SDK stub; the string
     * literals ("private_dns_mode"/"private_dns_specifier") are stable public
     * identifiers and are used here directly. WRITE_SECURE_SETTINGS
     * (held via privapp whitelist) authorizes the write.
     */
    private fun applyPrivateDns(hostname: String) {
        if (hostname.isEmpty()) {
            steps += Step("private_dns", true, "skipped (empty)")
            return
        }
        val m1 = Settings.Global.putString(
            context.contentResolver, "private_dns_mode", "hostname"
        )
        val m2 = Settings.Global.putString(
            context.contentResolver, "private_dns_specifier", hostname
        )
        steps += Step(
            "private_dns", m1 && m2,
            "mode=hostname specifier=$hostname (writes=$m1/$m2)"
        )
    }

    /**
     * 3. Connectivity server — the GrapheneOS connectivity check is enforced
     * by Settings.Global["connectivity_check_url"] when set, falling back to
     * the default captive-portal probe URL. Setting the GrapheneOS connectivity
     * URL here makes NetworkMonitor probe the GuardTalk server instead of the
     * Google default. This is the documented GrapheneOS mechanism (see
     * packages/modules/NetworkStack/src/com/android/server/connectivity/NetworkMonitor.java).
     */
    private fun applyConnectivityServer(host: String) {
        if (host.isEmpty()) {
            steps += Step("connectivity_server", true, "skipped (empty)")
            return
        }
        val url = "http://$host/generate_204"
        val ok = Settings.Global.putString(
            context.contentResolver, "connectivity_check_url", url
        )
        steps += Step(
            "connectivity_server", ok,
            "connectivity_check_url=$url (write=$ok)"
        )
    }

    /**
     * 4. WiFi SSID + password.
     *
     * Uses WifiManager.addOrUpdateNetwork(WifiConfiguration). The legacy
     * addNetwork/updateNetwork path returns -1 for non-system apps targeting
     * Q+ (WifiManager.java:3070-3072 deprecation note) but is exempted for
     * system apps — this app is platform-signed and runs with system
     * privileges, so the call succeeds. The dispatch packet's Phase-1 audit
     * confirms platform-signed privileged apps bypass the user-restriction
     * gates on this path.
     */
    private fun applyWifi(ssid: String, password: String) {
        if (ssid.isEmpty()) {
            steps += Step("wifi", true, "skipped (empty ssid)")
            return
        }
        val wm = context.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wm == null) {
            steps += Step("wifi", false, "WifiManager unavailable")
            return
        }
        val config = WifiConfiguration().apply {
            SSID = "\"$ssid\""
            preSharedKey = "\"$password\""
            allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA2_PSK)
            // Allow WPA3 transition mode (SAE) for APs that advertise it.
            allowedKeyManagement.set(WifiConfiguration.KeyMgmt.SAE)
        }
        val netId = try {
            // addOrUpdateNetwork is the internal entry that both addNetwork
            // and updateNetwork delegate to. It is restricted to system apps;
            // our platform signature satisfies it.
            val method = wm.javaClass.getDeclaredMethod(
                "addOrUpdateNetwork", WifiConfiguration::class.java
            )
            method.isAccessible = true
            method.invoke(wm, config) as Int
        } catch (e: Exception) {
            -999
        }
        if (netId >= 0) {
            wm.enableNetwork(netId, false)
            steps += Step("wifi", true, "ssid=$ssid netId=$netId enabled")
        } else {
            steps += Step("wifi", false, "addOrUpdateNetwork returned $netId")
        }
    }

    /**
     * 5. VPN — IKEv2/IPsec with PSK auth.
     *
     * VpnManager.provisionVpnProfile(Ikev2VpnProfile) returns null (silent,
     * no consent dialog) when the caller holds CONTROL_VPN (signature|
     * privileged) AND is platform-signed — see Vpn.java:4142-4174
     * isVpnProfilePreConsented(). startProvisionedVpnProfileSession() then
     * brings the tunnel up. setAlwaysOnVpnPackageForUser(lockdown=true)
     * blocks all traffic that bypasses the VPN.
     */
    private fun applyVpn(server: String, identity: String, psk: String) {
        if (server.isEmpty() || identity.isEmpty() || psk.isEmpty()) {
            steps += Step("vpn", true, "skipped (missing field)")
            return
        }
        val vpnMgr = context.getSystemService(Context.VPN_MANAGEMENT_SERVICE) as? VpnManager
        if (vpnMgr == null) {
            steps += Step("vpn", false, "VpnManager unavailable")
            return
        }
        try {
            val profile = Ikev2VpnProfile.Builder(server, identity)
                .setAuthPsk(psk.toByteArray(StandardCharsets.UTF_8))
                .setBypassable(false)
                .setMetered(false)
                .setRequiresInternetValidation(true)
                .build()
            val consentIntent = vpnMgr.provisionVpnProfile(profile)
            val provisionedOk = consentIntent == null
            steps += Step(
                "vpn_provision", provisionedOk,
                if (provisionedOk) "profile provisioned (silent consent granted)"
                else "provision returned consent intent — CONTROL_VPN not effective?"
            )
            if (provisionedOk) {
                // Lock down: all traffic must traverse the VPN.
                // setAlwaysOnVpnPackageForUser is @hide (VpnManager.java:588);
                // reflection reaches it from the platform-signed caller.
                // Requires CONTROL_ALWAYS_ON_VPN (signature|privileged) — added
                // to the privapp whitelist below.
                try {
                    val setAlwaysOn = VpnManager::class.java
                        .getDeclaredMethod(
                            "setAlwaysOnVpnPackageForUser",
                            Int::class.javaPrimitiveType,
                            String::class.java,
                            java.lang.Boolean.TYPE,
                            java.util.List::class.java
                        )
                    setAlwaysOn.isAccessible = true
                    val userHandle = android.os.Process.myUserHandle()
                    val userId = userHandle.hashCode()
                    val lockdownOk = setAlwaysOn.invoke(
                        vpnMgr,
                        userId,
                        context.packageName,
                        true,
                        null
                    ) as Boolean
                    steps += Step(
                        "vpn_always_on", lockdownOk,
                        "always-on+lockdown pkg=${context.packageName} user=$userId (ok=$lockdownOk)"
                    )
                } catch (e: Exception) {
                    steps += Step(
                        "vpn_always_on", false,
                        "setAlwaysOnVpnPackageForUser unavailable: ${e.message}"
                    )
                }
                val sessionKey = vpnMgr.startProvisionedVpnProfileSession()
                steps += Step("vpn_start", true, "sessionKey=$sessionKey")
            }
        } catch (e: Exception) {
            steps += Step("vpn", false, "exception: ${e.javaClass.simpleName}: ${e.message}")
        }
    }

    /**
     * 6. WiFi lockdown for Syndicate members (Task 2 — T-WIFI-LOCK-SYNDICATE).
     *
     * Two enforcement layers, as documented in the dispatch packet:
     *
     *   (a) WifiSsidPolicy allowlist = {gmpSsid}. Enforcement lives in
     *       packages/modules/Wifi/service/.../WifiPermissionsUtil.java:1318-1376
     *       — it blocks CONNECTION to non-allowlisted SSIDs (but does not
     *       prevent adding configs, which is why (b) is also needed).
     *   (b) User restrictions DISALLOW_ADD_WIFI_CONFIG,
     *       DISALLOW_CONFIG_WIFI_SHARED, DISALLOW_CONFIG_WIFI_PRIVATE — these
     *       block the user from adding new configs or modifying existing ones.
     *
     * Device Owner vs. platform-signed caller (dispatch packet decision):
     *   The Config app is NOT provisioned as Device Owner (that requires a
     *   `dpm set-device-owner` step at provisioning time and a wiped device,
     *   which is too invasive for this task). Two alternative write paths are
     *   used here, in priority order:
     *
     *     (1) DevicePolicyManager.setWifiSsidPolicy() — attempted first. It
     *         requires `MANAGE_DEVICE_POLICY_WIFI` (held) and a Device Owner
     *         OR Profile Owner admin component (NOT held). On a non-DO device
     *         it throws SecurityException; we catch and fall back.
     *     (2) WifiManager hidden setWifiSsidPolicy() — the same service-side
     *         allowlist, reachable from a platform-signed caller via the
     *         hidden API. Used as the actual enforcement path.
     *
     *   For the user restrictions we use UserManager.setUserRestriction()
     *         from the platform-signed context (MANAGE_USERS held). This is
     *         the dispatch packet's documented "Alternative" path.
     */
    private fun applyWifiLockdown(gmpSsid: String) {
        var ssidPolicyOk = false
        var ssidPolicyDetail = ""

        // Path (1): DevicePolicyManager (works on DO/PO; fallback otherwise).
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE)
                as? DevicePolicyManager
            if (dpm != null) {
                val ssidSet = setOf(wifiSsidFromUtf8(gmpSsid))
                val policy = WifiSsidPolicy(
                    WifiSsidPolicy.WIFI_SSID_POLICY_TYPE_ALLOWLIST, ssidSet
                )
                dpm.setWifiSsidPolicy(policy)
                ssidPolicyOk = true
                ssidPolicyDetail = "DPM allowlist={$gmpSsid}"
            }
        } catch (e: SecurityException) {
            ssidPolicyDetail = "DPM not DO/PO (${e.message}); trying hidden path"
        } catch (e: Exception) {
            ssidPolicyDetail = "DPM path error: ${e.javaClass.simpleName}: ${e.message}"
        }

        // Path (2): WifiManager hidden setWifiSsidPolicy — platform-signed path.
        if (!ssidPolicyOk) {
            try {
                val wm = context.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                if (wm != null) {
                    val m = WifiManager::class.java.getDeclaredMethod(
                        "setWifiSsidPolicy",
                        WifiSsidPolicy::class.java
                    )
                    m.isAccessible = true
                    val ssidSet = setOf(wifiSsidFromUtf8(gmpSsid))
                    val policy = WifiSsidPolicy(
                        WifiSsidPolicy.WIFI_SSID_POLICY_TYPE_ALLOWLIST, ssidSet
                    )
                    m.invoke(wm, policy)
                    ssidPolicyOk = true
                    ssidPolicyDetail = "WifiManager#setWifiSsidPolicy allowlist={$gmpSsid}"
                }
            } catch (e: Exception) {
                ssidPolicyDetail += "; hidden path failed: ${e.javaClass.simpleName}"
            }
        }
        steps += Step("wifi_lockdown_ssid_policy", ssidPolicyOk, ssidPolicyDetail)

        // User restrictions — platform-signed caller + MANAGE_USERS.
        // UserManager.setUserRestriction(String, boolean) is deprecated but
        // part of the public API and routed through IUserManager; the
        // MANAGE_USERS permission (held via privapp whitelist) authorizes it.
        val um = context.getSystemService(Context.USER_SERVICE) as? UserManager
        if (um == null) {
            steps += Step("wifi_lockdown_user_restrictions", false, "UserManager unavailable")
            return
        }
        val restrictions = listOf(
            // UserManager.DISALLOW_ADD_WIFI_CONFIG is @SystemApi (present in the
            // system_current stub). DISALLOW_CONFIG_WIFI_SHARED and
            // DISALLOW_CONFIG_WIFI_PRIVATE are @hide (UserManager.java:395/373),
            // so the stable string literals are used directly. All three are
            // routed through IUserManager.setUserRestriction by the (deprecated
            // but public) UserManager.setUserRestriction(String, boolean) call.
            UserManager.DISALLOW_ADD_WIFI_CONFIG,
            "no_config_wifi_shared",
            "no_config_wifi_private",
        )
        val sb = StringBuilder()
        var allOk = true
        for (r in restrictions) {
            val ok = try {
                um.setUserRestriction(r, true)
                true
            } catch (e: Exception) {
                allOk = false
                false
            }
            sb.append(r).append('=').append(if (ok) "on" else "FAIL").append(' ')
        }
        steps += Step(
            "wifi_lockdown_user_restrictions", allOk,
            sb.toString().trim().ifEmpty { "none applied" }
        )
    }

    /**
     * Build a [WifiSsid] from a UTF-8 string via the @hide
     * `WifiSsid.fromUtf8Text(CharSequence)` API. Reflection is used because the
     * method is `@hide` and therefore absent from the `system_current` SDK
     * stub the app compiles against.
     */
    private fun wifiSsidFromUtf8(ssid: String): WifiSsid {
        val m = WifiSsid::class.java.getDeclaredMethod(
            "fromUtf8Text", CharSequence::class.java
        )
        m.isAccessible = true
        return m.invoke(null, ssid) as WifiSsid
    }
}
