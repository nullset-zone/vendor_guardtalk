package com.guardtalk.config

import android.app.Activity
import android.content.Intent
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
 * Flow:
 *   1. "Scan Configuration QR" → launches the ZXing scanner (via
 *      [QrScannerFragment]); if no scanner is installed, the UI flips to the
 *      manual-paste path so QA / adb can still drive the flow.
 *   2. "Apply" → [QrPayloadParser.parse] (Ed25519 verify) → [ConfigApplier.apply].
 *   3. Result is shown in a scrollable text view; success/failure is also
 *      surfaced as a Toast.
 *
 * The activity is also a [android.content.Intent.ACTION_SEND] receiver for
 * `text/plain`, so an operator can share a QR string (or `adb shell am
 * start -a android.intent.action.SEND -t text/plain --es android.intent.extra.TEXT '<qr>' -n com.guardtalk.config/.ConfigActivity`)
 * and have it dropped straight into the apply path.
 */
class ConfigActivity : Activity(), QrScannerFragment.Callback {

    private lateinit var statusView: TextView
    private lateinit var scanBtn: Button
    private lateinit var applyBtn: Button
    private lateinit var pasteField: EditText
    private lateinit var scanner: QrScannerFragment

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

        // ACTION_SEND shortcut: drop shared text straight into the apply path.
        val sharedText = intent?.takeIf { it.action == Intent.ACTION_SEND }
            ?.let { it.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() }
        if (!sharedText.isNullOrBlank()) {
            pasteField.setText(sharedText)
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

    private fun onApply(raw: String) {
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

    companion object {
        private const val TAG_SCANNER = "qr_scanner"
    }
}
