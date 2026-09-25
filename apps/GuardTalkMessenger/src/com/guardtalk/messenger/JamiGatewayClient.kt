package com.guardtalk.messenger

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

/**
 * Jami daemon JSON-RPC client bound to the GuardTalk Gateway LAN.
 *
 * Wire: HTTP POST JSON-RPC 2.0 to `http://<rfc1918>:8080/jami/jsonrpc`.
 * Methods match jamid ConfigurationManager (`addAccount`, `getConversations`,
 * `sendTextMessage`). Never logs message bodies (Law 17).
 */
class JamiGatewayClient(
    private val endpointUrl: String,
    private val connectTimeoutMs: Int = 8_000,
    private val readTimeoutMs: Int = 15_000
) {

    data class RpcResult(val ok: Boolean, val value: Any?, val error: String?)

    fun addRingAccount(): RpcResult {
        val params = JSONObject().put("Account.type", "RING")
        return call("addAccount", JSONArray().put(params))
    }

    fun listConversations(accountId: String): RpcResult {
        if (accountId.isBlank()) {
            return RpcResult(false, null, "missing account")
        }
        return call("getConversations", JSONArray().put(accountId))
    }

    fun sendText(accountId: String, peerId: String, body: String): RpcResult {
        if (accountId.isBlank() || peerId.isBlank() || body.isBlank()) {
            return RpcResult(false, null, "missing account, peer, or body")
        }
        val args = JSONArray().put(accountId).put(peerId).put(body)
        return call("sendTextMessage", args)
    }

    fun call(method: String, params: JSONArray): RpcResult {
        val payload = JSONObject()
            .put("jsonrpc", "2.0")
            .put("id", 1)
            .put("method", method)
            .put("params", params)
        return try {
            post(payload)
        } catch (e: Exception) {
            Log.e(TAG, "rpc $method failed: ${e.javaClass.simpleName}")
            RpcResult(false, null, userFacingError(e))
        }
    }

    /** Stable UX tokens. JSON-RPC method names and params are unchanged. */
    private fun userFacingError(e: Exception): String {
        return when (e) {
            is java.net.ConnectException,
            is java.net.NoRouteToHostException,
            is java.net.UnknownHostException,
            is java.net.PortUnreachableException -> ERR_UNREACHABLE
            is java.net.SocketTimeoutException -> ERR_TIMEOUT
            else -> e.javaClass.simpleName
        }
    }

    private fun post(payload: JSONObject): RpcResult {
        val conn = (URL(endpointUrl).openConnection() as HttpURLConnection)
        try {
            conn.connectTimeout = connectTimeoutMs
            conn.readTimeout = readTimeoutMs
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            OutputStreamWriter(conn.outputStream, StandardCharsets.UTF_8).use { it.write(payload.toString()) }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader(StandardCharsets.UTF_8)?.use { it.readText() }.orEmpty()
            return parseRpc(code, text)
        } finally {
            conn.disconnect()
        }
    }

    private fun parseRpc(httpCode: Int, text: String): RpcResult {
        if (httpCode !in 200..299) {
            return RpcResult(false, null, "http $httpCode")
        }
        val json = JSONObject(text)
        if (json.has("error")) {
            val err = json.optJSONObject("error")
            val msg = err?.optString("message").takeUnless { it.isNullOrBlank() } ?: "rpc error"
            return RpcResult(false, null, msg)
        }
        return RpcResult(true, json.opt("result"), null)
    }

    companion object {
        private const val TAG = "GTMsg/JamiRpc"
        const val ERR_UNREACHABLE: String = "unreachable"
        const val ERR_TIMEOUT: String = "timeout"
    }
}
