package com.guardtalk.validator

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ListView
import android.widget.TextView

/**
 * GuardTalkValidator main activity.
 *
 * Reports GROUND TRUTH about each excised feature by querying the live Android
 * framework (PackageManager.hasSystemFeature / ConnectivityManager /
 * ActivityManager). No result is hard-coded: if a feature is still present the
 * check reports FAIL — that is the intended signal that an excision .mk is not
 * yet wired.
 *
 * Each [CheckResult] is one of:
 *   - PASS    : feature is absent (excision succeeded) — green
 *   - FAIL    : feature is still present (excision incomplete) — red
 *   - READOUT : informational only (no pass/fail semantics) — blue
 *
 * FR-4: a button at the bottom opens [ProcessListActivity], a least-privilege
 * process viewer that enumerates every running OS process (PID/UID/name/state)
 * via ActivityManager.getRunningAppProcesses(). The viewer is a separate
 * non-exported activity — it is reachable ONLY from this launcher activity and
 * from no other app (no exported service, no IPC).
 */
class ValidatorActivity : Activity() {

    /** Result kind for a single check. */
    enum class Kind { PASS, FAIL, READOUT }

    /** A single check result rendered as one row. */
    data class CheckResult(
        val name: String,
        val kind: Kind,
        val detail: String,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_validator)

        val header = findViewById<TextView>(R.id.header_title)
        val summary = findViewById<TextView>(R.id.summary_text)
        val list = findViewById<ListView>(R.id.checks_list)
        val openProcesses = findViewById<Button>(R.id.btn_open_processes)

        header.text = getString(R.string.header_title)

        val results = runChecks()
        val passCount = results.count { it.kind == Kind.PASS }
        val failCount = results.count { it.kind == Kind.FAIL }
        val readoutCount = results.count { it.kind == Kind.READOUT }
        summary.text = getString(R.string.summary_template, passCount, failCount, readoutCount)

        list.adapter = CheckAdapter(this, results)

        // FR-4: launch the (non-exported) process viewer. Only this launcher
        // activity can reach it; no other app can invoke the enumeration.
        openProcesses.setOnClickListener {
            startActivity(
                android.content.Intent(this, ProcessListActivity::class.java)
            )
        }
    }

    /** Run all 7 checks against the live framework and return the row data. */
    private fun runChecks(): List<CheckResult> {
        val pm = packageManager
        val results = mutableListOf<CheckResult>()

        // 1. GPS absent
        val gpsPresent = pm.hasSystemFeature(PackageManager.FEATURE_LOCATION_GPS)
        results += CheckResult(
            name = "GPS absent",
            kind = if (!gpsPresent) Kind.PASS else Kind.FAIL,
            detail = if (gpsPresent) "FEATURE_LOCATION_GPS present" else "FEATURE_LOCATION_GPS absent",
        )

        // 2. Modem/Telephony absent
        val telephonyPresent = pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
        results += CheckResult(
            name = "Modem/Telephony absent",
            kind = if (!telephonyPresent) Kind.PASS else Kind.FAIL,
            detail = if (telephonyPresent) "FEATURE_TELEPHONY present" else "FEATURE_TELEPHONY absent",
        )

        // 3. Bluetooth absent
        val btPresent = pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH)
        results += CheckResult(
            name = "Bluetooth absent",
            kind = if (!btPresent) Kind.PASS else Kind.FAIL,
            detail = if (btPresent) "FEATURE_BLUETOOTH present" else "FEATURE_BLUETOOTH absent",
        )

        // 4. Location absent
        val locationPresent = pm.hasSystemFeature(PackageManager.FEATURE_LOCATION)
        results += CheckResult(
            name = "Location absent",
            kind = if (!locationPresent) Kind.PASS else Kind.FAIL,
            detail = if (locationPresent) "FEATURE_LOCATION present" else "FEATURE_LOCATION absent",
        )

        // 5. NFC absent
        val nfcPresent = pm.hasSystemFeature(PackageManager.FEATURE_NFC)
        results += CheckResult(
            name = "NFC absent",
            kind = if (!nfcPresent) Kind.PASS else Kind.FAIL,
            detail = if (nfcPresent) "FEATURE_NFC present" else "FEATURE_NFC absent",
        )

        // 6. Connectivity status (READOUT)
        results += connectivityReadout()

        // 7. Running process list (READOUT)
        results += runningProcessesReadout()

        return results
    }

    /** Check 6: report the active network transport and internet reachability. */
    private fun connectivityReadout(): CheckResult {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        if (cm == null) {
            return CheckResult(
                name = "Connectivity status",
                kind = Kind.READOUT,
                detail = "ConnectivityService unavailable",
            )
        }
        val network = cm.activeNetwork
        val caps = network?.let { cm.getNetworkCapabilities(it) }
        if (caps == null) {
            return CheckResult(
                name = "Connectivity status",
                kind = Kind.READOUT,
                detail = "No active network",
            )
        }
        val transports = mutableListOf<String>()
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) transports += "WiFi"
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) transports += "Cellular"
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) transports += "Ethernet"
        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) transports += "VPN"
        val hasInternet = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val validated = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        val transportLabel = if (transports.isEmpty()) "none" else transports.joinToString(", ")
        val cellularAbsent = !caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        val detail = "transport: $transportLabel · internet: $hasInternet · " +
            "validated: $validated · cellular absent: $cellularAbsent"
        return CheckResult(
            name = "Connectivity status",
            kind = Kind.READOUT,
            detail = detail,
        )
    }

    /** Check 7: enumerate running app processes (READOUT). */
    private fun runningProcessesReadout(): CheckResult {
        val result = ProcessEnumerator.enumerate(this)
        val detail = when (result) {
            is ProcessEnumerator.Result.Error ->
                if (result.security)
                    getString(R.string.process_security_error, result.message)
                else result.message
            is ProcessEnumerator.Result.Success ->
                if (result.items.isEmpty()) "count: 0"
                else {
                    val count = result.items.size
                    val sample = result.items.take(8).joinToString(", ") { it.name }
                    "count: $count · sample: $sample"
                }
        }
        return CheckResult(
            name = "Running process list",
            kind = Kind.READOUT,
            detail = detail,
        )
    }

    /** ArrayAdapter that renders [CheckResult] rows with colored badges. */
    private class CheckAdapter(
        context: Context,
        items: List<CheckResult>,
    ) : ArrayAdapter<CheckResult>(context, 0, items) {

        private val inflater = LayoutInflater.from(context)

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val view = convertView ?: inflater.inflate(R.layout.check_row, parent, false)
            val item = getItem(position)!!
            val nameView = view.findViewById<TextView>(R.id.check_name)
            val detailView = view.findViewById<TextView>(R.id.check_detail)
            val badgeView = view.findViewById<TextView>(R.id.check_badge)

            nameView.text = item.name
            detailView.text = item.detail

            val (label, color) = when (item.kind) {
                Kind.PASS -> "PASS" to Color.rgb(0x2E, 0x7D, 0x32)
                Kind.FAIL -> "FAIL" to Color.rgb(0xC6, 0x28, 0x28)
                Kind.READOUT -> "READOUT" to Color.rgb(0x15, 0x65, 0xC0)
            }
            badgeView.text = label
            badgeView.setTextColor(Color.WHITE)
            badgeView.setBackgroundColor(color)

            return view
        }
    }
}
