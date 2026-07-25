package com.guardtalk.config

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.guardtalk.GuardTalkConfigGateManager
import android.guardtalk.GuardTalkConfigMutations
import android.os.Bundle
import android.text.method.ScrollingMovementMethod
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast

/**
 * Main UI for GuardTalkConfig.
 *
 * <p>Browse/UI is ungated. Applying a payload requires a GT Config password
 * session ({@code gt_config_write}) — fail-closed (T-SEC-ACTIVATE).
 *
 * Flow:
 *   1. "Scan Configuration QR" → launches the ZXing scanner (via
 *      [QrScannerFragment]); if no scanner is installed, the UI flips to the
 *      manual-paste path so QA / adb can still drive the flow.
 *   2. "Apply" → confirm device credential if needed → [QrPayloadParser.parse]
 *      (Ed25519 verify) → [ConfigApplier.apply].
 *   3. Result is shown in a scrollable text view; success/failure is also
 *      surfaced as a Toast.
 */
class ConfigActivity : Activity(), QrScannerFragment.Callback {

    private lateinit var statusView: TextView
    private lateinit var scanBtn: Button
    private lateinit var applyBtn: Button
    private lateinit var pasteField: EditText
    private lateinit var scanner: QrScannerFragment

    /** Pending raw payload waiting for credential confirm → session → apply. */
    private var pendingApplyRaw: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_config)

        statusView = findViewById(R.id.status_text)
        statusView.movementMethod = ScrollingMovementMethod.getInstance()
        scanBtn = findViewById(R.id.btn_scan)
        applyBtn = findViewById(R.id.btn_apply)
        pasteField = findViewById(R.id.paste_field)
        pasteField.visibility = View.GONE
        applyBtn.visibility = View.GONE

        scanner = (fragmentManager.findFragmentByTag(TAG_SCANNER) as? QrScannerFragment)
            ?: QrScannerFragment().also {
                fragmentManager.beginTransaction().add(it, TAG_SCANNER).commit()
            }

        scanBtn.setOnClickListener { scanner.startScan() }
        applyBtn.setOnClickListener { onApply(pasteField.text.toString()) }

        refreshBrowseStatus()

        // ACTION_SEND shortcut: drop shared text straight into the apply path.
        val sharedText = intent?.takeIf { it.action == Intent.ACTION_SEND }
            ?.let { it.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() }
        if (!sharedText.isNullOrBlank()) {
            pasteField.setText(sharedText)
            pasteField.visibility = View.VISIBLE
            applyBtn.visibility = View.VISIBLE
            onApply(sharedText)
        }
    }

    override fun onQrScanResult(rawQr: String?) {
        when (rawQr) {
            null, "" -> {
                statusView.text = getString(R.string.scan_failed)
                pasteField.visibility = View.VISIBLE
                applyBtn.visibility = View.VISIBLE
            }
            QrScannerFragment.RESULT_NO_SCANNER -> {
                statusView.text = getString(R.string.no_scanner)
                pasteField.visibility = View.VISIBLE
                applyBtn.visibility = View.VISIBLE
            }
            else -> {
                pasteField.setText(rawQr)
                pasteField.visibility = View.VISIBLE
                applyBtn.visibility = View.VISIBLE
                onApply(rawQr)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Keep post-unlock / session messaging honest without forcing Apply.
        if (pasteField.text.isNullOrBlank() && pendingApplyRaw == null) {
            refreshBrowseStatus()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CONFIRM_FOR_WRITE) {
            val raw = pendingApplyRaw
            pendingApplyRaw = null
            if (resultCode != RESULT_OK || raw.isNullOrBlank()) {
                statusView.text = getString(R.string.write_denied)
                Toast.makeText(this, R.string.write_denied_toast, Toast.LENGTH_LONG).show()
                return
            }
            val opened = GuardTalkConfigGateManager.onDeviceCredentialConfirmed(this)
            if (!opened) {
                statusView.text = getString(R.string.write_denied)
                Toast.makeText(this, R.string.write_denied_toast, Toast.LENGTH_LONG).show()
                return
            }
            applyAuthorized(raw)
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun onApply(raw: String) {
        if (raw.isBlank()) {
            return
        }
        if (isWriteAuthorized()) {
            applyAuthorized(raw)
            return
        }
        // Fail-closed until password session opens.
        val km = getSystemService(KeyguardManager::class.java)
        if (km == null || !km.isDeviceSecure) {
            statusView.text = getString(R.string.write_denied)
            Toast.makeText(this, R.string.write_denied_toast, Toast.LENGTH_LONG).show()
            return
        }
        val confirm = km.createConfirmDeviceCredentialIntent(
            getString(R.string.app_name),
            getString(R.string.write_confirm_details)
        )
        if (confirm == null) {
            statusView.text = getString(R.string.write_denied)
            Toast.makeText(this, R.string.write_denied_toast, Toast.LENGTH_LONG).show()
            return
        }
        pendingApplyRaw = raw
        startActivityForResult(confirm, REQUEST_CONFIRM_FOR_WRITE)
    }

    private fun applyAuthorized(raw: String) {
        val payload = try {
            QrPayloadParser.parse(raw)
        } catch (e: Exception) {
            statusView.text = getString(R.string.parse_failed, e.message ?: "")
            Toast.makeText(this, R.string.parse_failed_toast, Toast.LENGTH_LONG).show()
            return
        }
        val result = ConfigApplier(this).apply(payload)
        statusView.text = buildString {
            appendLine(getString(R.string.secure_level_is, payload.secureLevel))
            appendLine(result.toString())
        }
        Toast.makeText(
            this,
            if (result.allOk) R.string.apply_ok else R.string.apply_partial,
            Toast.LENGTH_LONG
        ).show()
    }

    private fun refreshBrowseStatus() {
        statusView.text = if (isWriteAuthorized()) {
            getString(R.string.browse_ready_authorized)
        } else {
            getString(R.string.browse_ready_locked)
        }
    }

    private fun isWriteAuthorized(): Boolean {
        return GuardTalkConfigGateManager.isMutationAuthorized(
            userId,
            GuardTalkConfigMutations.GT_CONFIG_WRITE
        )
    }

    companion object {
        private const val TAG_SCANNER = "qr_scanner"
        private const val REQUEST_CONFIRM_FOR_WRITE = 7602
    }
}
