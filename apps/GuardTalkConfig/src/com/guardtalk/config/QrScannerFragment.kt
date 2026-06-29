package com.guardtalk.config

import android.app.Activity
import android.app.Fragment
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * Headless "fragment" that drives QR acquisition.
 *
 * Strategy (per dispatch packet T-GTCONFIG-APP — "Use `Intent(
 * "com.google.zxing.client.android.SCAN")` or implement a basic ZXing
 * integration. If ZXing isn't available, use the CameraX API directly"):
 *
 *   1. Primary: launch the Barcode Scanner (ZXing) SCAN intent. This is the
 *      lightest-weight option — zero new dependencies in the privileged
 *      system_ext app (Law 22: Dependency Hygiene) — and works on any device
 *      that ships a ZXing-compatible scanner (GrapheneOS ships the
 *      `android.grapheneos.camera` app which can scan QR codes).
 *
 *   2. Fallback: if no SCAN-handling activity exists (ActivityNotFoundException),
 *      the fragment returns [RESULT_NO_SCANNER] to the host activity. The
 *      host then shows the manual-paste path (see ConfigActivity), which is
 *      also reachable via `adb shell am broadcast` / ACTION_SEND for QA.
 *
 * This class is implemented as a headless retained Fragment (no UI) so the
 * Activity can survive the orientation change that the SCAN intent round-trip
 * may cause on some scanner apps.
 */
class QrScannerFragment : Fragment() {

    companion object {
        const val REQUEST_SCAN = 0x5144 // 'QD'
        const val RESULT_NO_SCANNER = "no_scanner"
        const val TAG = "GTCfg/QrScanner"
    }

    interface Callback {
        fun onQrScanResult(rawQr: String?)
    }

    private var callback: Callback? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        retainInstance = true
    }

    override fun onAttach(activity: Activity) {
        super.onAttach(activity)
        callback = activity as? Callback
    }

    override fun onDetach() {
        super.onDetach()
        callback = null
    }

    /** Launch the ZXing SCAN intent. Returns false if no scanner is installed. */
    fun startScan(): Boolean {
        val intent = Intent("com.google.zxing.client.android.SCAN").apply {
            putExtra("SCAN_MODE", "QR_CODE_MODE")
            putExtra("BEEP_ENABLED", true)
        }
        return try {
            startActivityForResult(intent, REQUEST_SCAN)
            true
        } catch (e: android.content.ActivityNotFoundException) {
            Log.w(TAG, "No ZXing-compatible scanner installed; falling back to paste")
            // Emit the fallback sentinel so the activity flips to the paste view.
            callback?.onQrScanResult(RESULT_NO_SCANNER)
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_SCAN) return
        val raw = if (resultCode == Activity.RESULT_OK) {
            data?.getStringExtra("SCAN_RESULT")
        } else {
            null
        }
        callback?.onQrScanResult(raw)
    }
}
