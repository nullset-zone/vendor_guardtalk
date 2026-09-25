package com.guardtalk.checkin

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import java.text.DateFormat
import java.util.Date

/**
 * Status-only UI. Shows endpoint *class*, never the onion URL
 * (Law 4: seizer-visible display).
 */
class CheckinStatusActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_checkin)
        CheckinScheduler.schedule(this)
        findViewById<Button>(R.id.btn_run_now).setOnClickListener {
            CheckinScheduler.runNow(this)
            refresh()
        }
        refresh()
    }

    override fun onResume() {
        super.onResume()
        refresh()
    }

    private fun refresh() {
        val store = CheckinStore(this)
        findViewById<TextView>(R.id.endpoint_text).text = endpointLabel(store)
        val status = store.lastStatus().ifEmpty { getString(R.string.never) }
        findViewById<TextView>(R.id.status_text).text =
            getString(R.string.last_status, status)
        findViewById<TextView>(R.id.time_text).text =
            getString(R.string.last_time, formatTime(store.lastUnix()))
    }

    private fun endpointLabel(store: CheckinStore): String {
        val raw = store.endpoint()
        if (raw.isBlank()) return getString(R.string.endpoint_none)
        return try {
            when (CheckinEndpoint.parse(raw).kind) {
                CheckinConstants.KIND_ONION -> getString(R.string.endpoint_onion)
                CheckinConstants.KIND_LAN -> getString(R.string.endpoint_lan)
                else -> getString(R.string.endpoint_rejected)
            }
        } catch (_: CheckinEndpoint.Rejected) {
            getString(R.string.endpoint_rejected)
        }
    }

    private fun formatTime(unix: Long): String {
        if (unix <= 0L) return getString(R.string.never)
        return DateFormat.getDateTimeInstance().format(Date(unix * 1000L))
    }
}
