package com.guardtalk.checkin

import android.util.Log
import java.net.HttpURLConnection
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.URL

/**
 * HTTP POST of the check-in body. Redirects off. No public C2: caller must
 * pass an already-allowlisted endpoint.
 */
object CheckinTransport {

    private const val TAG = "GTCheckin/Tx"
    private const val TIMEOUT_MS = 30_000

    fun post(url: String, socks: Pair<String, Int>?, body: ByteArray): Boolean {
        val connection = open(url, socks)
        try {
            connection.requestMethod = "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            connection.doOutput = true
            connection.setRequestProperty(
                "Content-Type",
                "application/json; charset=utf-8"
            )
            connection.setRequestProperty("Accept", "application/json")
            connection.outputStream.use { out -> out.write(body) }
            val code = connection.responseCode
            val ok = code in 200..299
            Log.i(TAG, "POST complete code=$code ok=$ok")
            return ok
        } finally {
            connection.disconnect()
        }
    }

    private fun open(url: String, socks: Pair<String, Int>?): HttpURLConnection {
        val target = URL(url)
        if (socks == null) {
            return target.openConnection() as HttpURLConnection
        }
        val proxy = Proxy(
            Proxy.Type.SOCKS,
            InetSocketAddress(socks.first, socks.second)
        )
        return target.openConnection(proxy) as HttpURLConnection
    }
}
