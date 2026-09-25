package com.guardtalk.messenger

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast

/**
 * GuardTalk Messenger launcher UX (F-REMEDIATE-B4-MESSENGER).
 *
 * First-user path: join Gateway Wi-Fi, register RING, send text.
 * Fail-closed off-LAN. Never silent: status + toast on every error.
 * Network I/O is off the main thread. Message bodies are never logged.
 */
class MessengerActivity : Activity() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var store: JamiAccountStore
    private lateinit var statusView: TextView
    private lateinit var logView: TextView
    private lateinit var peerField: EditText
    private lateinit var bodyField: EditText
    private lateinit var retryButton: Button
    private lateinit var registerButton: Button
    private lateinit var refreshButton: Button
    private lateinit var sendButton: Button
    private var client: JamiGatewayClient? = null
    private var gatewayLabel: String = ""
    private var bindState: BindState = BindState.NO_WIFI
    private var busy: Boolean = false
    private var logHasList: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_messenger)
        store = JamiAccountStore(this)
        statusView = findViewById(R.id.status_text)
        logView = findViewById(R.id.log_text)
        peerField = findViewById(R.id.peer_field)
        bodyField = findViewById(R.id.body_field)
        retryButton = findViewById(R.id.btn_retry)
        registerButton = findViewById(R.id.btn_register)
        refreshButton = findViewById(R.id.btn_refresh)
        sendButton = findViewById(R.id.btn_send)
        retryButton.setOnClickListener { retryGateway() }
        registerButton.setOnClickListener { registerAccount() }
        refreshButton.setOnClickListener { refreshConversations() }
        sendButton.setOnClickListener { sendMessage() }
        applyShareIntent(intent)
        bindGateway()
    }

    override fun onResume() {
        super.onResume()
        if (!busy) {
            bindGateway()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyShareIntent(intent)
    }

    private fun applyShareIntent(intent: Intent?) {
        if (intent == null || Intent.ACTION_SEND != intent.action) {
            return
        }
        val shared = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        if (shared.isNotEmpty()) {
            bodyField.setText(shared)
        }
    }

    private fun retryGateway() {
        bindGateway()
        if (client != null) {
            toast(getString(R.string.retry_ok))
        } else {
            toast(bindFailureCopy())
        }
    }

    private fun bindGateway() {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        val target = try {
            GatewayEndpoint.resolve(wifi)
        } catch (e: Exception) {
            Log.e(TAG, "gateway resolve failed", e)
            null
        }
        if (target == null) {
            client = null
            gatewayLabel = ""
            val dhcp = try {
                wifi?.dhcpInfo
            } catch (e: Exception) {
                null
            }
            bindState = if (dhcp == null || dhcp.gateway == 0) {
                BindState.NO_WIFI
            } else {
                BindState.NOT_PRIVATE
            }
            paintStatus()
            return
        }
        client = JamiGatewayClient(target.url)
        gatewayLabel = target.host.hostAddress ?: ""
        bindState = BindState.READY
        paintStatus()
    }

    private fun paintStatus() {
        when (bindState) {
            BindState.NO_WIFI -> statusView.setText(R.string.status_no_wifi)
            BindState.NOT_PRIVATE -> statusView.setText(R.string.status_not_private)
            BindState.READY -> {
                val id = store.getAccountId()
                if (id.isNullOrBlank()) {
                    statusView.text = getString(R.string.status_unregistered, gatewayLabel)
                } else {
                    statusView.text = getString(R.string.status_ok, gatewayLabel, id)
                }
            }
        }
        paintEmptyLog()
    }

    private fun paintEmptyLog() {
        if (logHasList) {
            return
        }
        val empty = when {
            bindState != BindState.READY -> R.string.log_need_gateway
            store.getAccountId().isNullOrBlank() -> R.string.log_need_register
            else -> R.string.log_empty
        }
        logView.setText(empty)
    }

    private fun bindFailureCopy(): String {
        return when (bindState) {
            BindState.NOT_PRIVATE -> getString(R.string.status_not_private)
            else -> getString(R.string.status_no_wifi)
        }
    }

    private fun requireGateway(): JamiGatewayClient? {
        if (client == null) {
            bindGateway()
        }
        val rpc = client
        if (rpc == null) {
            toast(bindFailureCopy())
            paintStatus()
            return null
        }
        return rpc
    }

    private fun registerAccount() {
        val rpc = requireGateway() ?: return
        setBusy(true)
        statusView.setText(R.string.status_registering)
        Thread {
            val result = rpc.addRingAccount()
            mainHandler.post { onRegistered(result) }
        }.start()
    }

    private fun onRegistered(result: JamiGatewayClient.RpcResult) {
        setBusy(false)
        if (!result.ok) {
            val detail = mapRpcError(result.error)
            statusView.text = getString(R.string.err_register, detail)
            toast(getString(R.string.err_register, detail))
            return
        }
        val id = result.value?.toString()?.trim().orEmpty()
        if (id.isEmpty()) {
            toast(getString(R.string.err_register, "empty account"))
            paintStatus()
            return
        }
        store.setAccountId(id)
        paintStatus()
        toast(getString(R.string.register_ok))
    }

    private fun refreshConversations() {
        val rpc = requireGateway() ?: return
        val id = store.getAccountId()
        if (id.isNullOrBlank()) {
            toast(getString(R.string.status_unregistered, gatewayLabel))
            paintStatus()
            return
        }
        setBusy(true)
        statusView.setText(R.string.status_refreshing)
        Thread {
            val result = rpc.listConversations(id)
            mainHandler.post { onConversations(result) }
        }.start()
    }

    private fun onConversations(result: JamiGatewayClient.RpcResult) {
        setBusy(false)
        if (!result.ok) {
            val detail = mapRpcError(result.error)
            statusView.text = getString(R.string.err_refresh, detail)
            toast(getString(R.string.err_refresh, detail))
            return
        }
        val text = result.value?.toString()?.trim().orEmpty()
        if (text.isEmpty()) {
            logHasList = false
            paintStatus()
            return
        }
        logHasList = true
        logView.text = text
        paintStatus()
    }

    private fun sendMessage() {
        val rpc = requireGateway() ?: return
        val id = store.getAccountId()
        if (id.isNullOrBlank()) {
            toast(getString(R.string.status_unregistered, gatewayLabel))
            paintStatus()
            return
        }
        val peer = peerField.text?.toString()?.trim().orEmpty()
        val body = bodyField.text?.toString()?.trim().orEmpty()
        if (peer.isEmpty()) {
            toast(getString(R.string.err_peer_required))
            return
        }
        if (!PEER_ID.matches(peer)) {
            toast(getString(R.string.err_peer_format))
            return
        }
        if (body.isEmpty()) {
            toast(getString(R.string.err_body_required))
            return
        }
        setBusy(true)
        statusView.setText(R.string.status_sending)
        Thread {
            val result = rpc.sendText(id, peer, body)
            mainHandler.post { onSent(result) }
        }.start()
    }

    private fun onSent(result: JamiGatewayClient.RpcResult) {
        setBusy(false)
        if (result.ok) {
            toast(getString(R.string.send_ok))
            bodyField.text.clear()
            paintStatus()
            return
        }
        val detail = mapRpcError(result.error)
        statusView.text = getString(R.string.err_send, detail)
        toast(getString(R.string.err_send, detail))
    }

    private fun mapRpcError(raw: String?): String {
        val token = raw?.trim().orEmpty()
        if (token.isEmpty() || token == "unknown") {
            return getString(R.string.err_gateway_unreachable, gatewayLabel)
        }
        return when {
            token == JamiGatewayClient.ERR_UNREACHABLE ->
                getString(R.string.err_gateway_unreachable, gatewayLabel)
            token == JamiGatewayClient.ERR_TIMEOUT ->
                getString(R.string.err_gateway_timeout, gatewayLabel)
            token.startsWith("http ") ->
                getString(R.string.err_gateway_http, token.removePrefix("http "))
            else -> token
        }
    }

    private fun setBusy(value: Boolean) {
        busy = value
        retryButton.isEnabled = !value
        registerButton.isEnabled = !value
        refreshButton.isEnabled = !value
        sendButton.isEnabled = !value
    }

    private fun toast(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
    }

    private enum class BindState { NO_WIFI, NOT_PRIVATE, READY }

    companion object {
        private const val TAG = "GTMsg/Activity"
        private val PEER_ID = Regex("^[0-9a-fA-F]{40}$")
    }
}
