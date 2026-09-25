package com.guardtalk.messenger

import android.net.wifi.WifiManager
import java.net.InetAddress

/**
 * Resolves the GuardTalk Gateway as the Wi-Fi DHCP default-route host.
 *
 * T-REMEDIATE-B4-MESSENGER: Jami JSON-RPC is served on the Gateway LAN, not
 * the public DHT. Non-RFC1918 destinations are rejected (fail-closed).
 */
object GatewayEndpoint {

    const val JSONRPC_PORT: Int = 8080
    const val JSONRPC_PATH: String = "/jami/jsonrpc"

    data class Target(val host: InetAddress, val url: String)

    /**
     * @return Gateway JSON-RPC URL, or null when Wi-Fi DHCP is missing or not private.
     */
    fun resolve(wifi: WifiManager?): Target? {
        if (wifi == null) {
            return null
        }
        val gatewayInt = try {
            wifi.dhcpInfo?.gateway ?: 0
        } catch (e: Exception) {
            0
        }
        if (gatewayInt == 0) {
            return null
        }
        val addr = inetFromDhcp(gatewayInt) ?: return null
        if (!isRfc1918(addr)) {
            return null
        }
        val url = "http://${addr.hostAddress}:$JSONRPC_PORT$JSONRPC_PATH"
        return Target(addr, url)
    }

    fun isRfc1918(addr: InetAddress): Boolean {
        val b = addr.address
        if (b == null || b.size != 4) {
            return false
        }
        val a0 = b[0].toInt() and 0xff
        val a1 = b[1].toInt() and 0xff
        return when {
            a0 == 10 -> true
            a0 == 192 && a1 == 168 -> true
            a0 == 172 && a1 in 16..31 -> true
            else -> false
        }
    }

    /** DHCP ints are little-endian on Android. */
    fun inetFromDhcp(gatewayInt: Int): InetAddress? {
        val bytes = byteArrayOf(
            (gatewayInt and 0xff).toByte(),
            (gatewayInt shr 8 and 0xff).toByte(),
            (gatewayInt shr 16 and 0xff).toByte(),
            (gatewayInt shr 24 and 0xff).toByte()
        )
        return try {
            InetAddress.getByAddress(bytes)
        } catch (e: Exception) {
            null
        }
    }
}
