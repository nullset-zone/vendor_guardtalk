package com.guardtalk.checkin

import android.net.InetAddresses
import android.net.Uri
import java.net.InetAddress

/**
 * Fail-closed endpoint allowlist. Port of checkin_contract.py.
 * Public DNS names and public IPs are never accepted.
 */
object CheckinEndpoint {

    data class Parsed(
        val kind: String,
        val uri: Uri,
    )

    class Rejected(message: String) : Exception(message)

    fun parse(url: String): Parsed {
        val text = url.trim()
        if (text.isEmpty()) throw Rejected("empty endpoint")
        if (text.length > CheckinConstants.MAX_URL_LEN) {
            throw Rejected("endpoint too long")
        }
        val uri = Uri.parse(text)
        val scheme = uri.scheme?.lowercase() ?: ""
        if (scheme != "http" && scheme != "https") {
            throw Rejected("scheme must be http or https")
        }
        if (!uri.userInfo.isNullOrEmpty()) throw Rejected("userinfo rejected")
        val host = uri.host?.trim()?.lowercase() ?: throw Rejected("missing host")
        val kind = classifyHost(host)
        return Parsed(kind, uri)
    }

    fun classifyHost(host: String): String {
        val raw = stripBrackets(host)
        if (isOnionV3(raw)) return CheckinConstants.KIND_ONION
        if (raw == "localhost") return CheckinConstants.KIND_LAN
        val addr = parseNumeric(raw) ?: throw Rejected(
            "non-onion hostname rejected (no public DNS C2)"
        )
        if (isGatewayLan(addr)) return CheckinConstants.KIND_LAN
        throw Rejected("public IP rejected (no public-internet C2)")
    }

    fun parseSocks(spec: String): Pair<String, Int> {
        val text = spec.trim()
        val colon = text.lastIndexOf(':')
        if (colon <= 0 || colon == text.lastIndex) {
            throw Rejected("socks must be host:port")
        }
        val host = text.substring(0, colon)
        val port = text.substring(colon + 1).toIntOrNull()
            ?: throw Rejected("socks port out of range")
        if (port < 1 || port > 65535) throw Rejected("socks port out of range")
        if (classifyHost(host) != CheckinConstants.KIND_LAN) {
            throw Rejected("socks host must be loopback or RFC1918/ULA")
        }
        return host to port
    }

    fun transportMode(parsed: Parsed, socksSpec: String): String {
        if (parsed.kind == CheckinConstants.KIND_ONION) {
            if (socksSpec.trim().isEmpty()) {
                throw Rejected("onion requires SOCKS (no clearnet fallback)")
            }
            parseSocks(socksSpec)
            return "socks"
        }
        return "direct"
    }

    private fun stripBrackets(host: String): String {
        return if (host.startsWith("[") && host.endsWith("]")) {
            host.substring(1, host.length - 1)
        } else {
            host
        }
    }

    private fun isOnionV3(host: String): Boolean {
        if (!host.endsWith(".onion")) return false
        val label = host.removeSuffix(".onion")
        if (label.length != 56) return false
        return label.all { it in 'a'..'z' || it in '2'..'7' }
    }

    /** Literal IP only — never DNS (no leak, no rebinding). */
    private fun parseNumeric(host: String): InetAddress? {
        if (!InetAddresses.isNumericAddress(host)) return null
        return try {
            InetAddresses.parseNumericAddress(host)
        } catch (_: Exception) {
            null
        }
    }

    private fun isGatewayLan(addr: InetAddress): Boolean {
        return addr.isLoopbackAddress ||
            addr.isLinkLocalAddress ||
            addr.isSiteLocalAddress ||
            isUla(addr)
    }

    private fun isUla(addr: InetAddress): Boolean {
        val b = addr.address
        return b.size == 16 && (b[0].toInt() and 0xfe) == 0xfc
    }
}
