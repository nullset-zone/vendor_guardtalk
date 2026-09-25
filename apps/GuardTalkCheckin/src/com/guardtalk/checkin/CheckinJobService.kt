package com.guardtalk.checkin

import android.app.job.JobParameters
import android.app.job.JobService
import android.util.Log
import java.util.concurrent.Executors

/**
 * Periodic / one-shot worker. Fail-closed: skip rather than talk to
 * a public endpoint. Does not log URLs or device_id.
 */
class CheckinJobService : JobService() {

    private val executor = Executors.newSingleThreadExecutor()

    override fun onStartJob(params: JobParameters): Boolean {
        executor.execute {
            val status = runCatching { attempt() }.getOrElse { err ->
                Log.w(TAG, "attempt failed class=${err.javaClass.simpleName}")
                CheckinConstants.STATUS_FAILED
            }
            val now = System.currentTimeMillis() / 1000L
            CheckinStore(applicationContext).record(status, now)
            Log.i(TAG, "check-in status=$status")
            jobFinished(params, false)
        }
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = true

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun attempt(): String {
        val store = CheckinStore(applicationContext)
        val raw = store.endpoint()
        if (raw.isBlank()) return CheckinConstants.STATUS_SKIP_ENDPOINT
        val parsed = try {
            CheckinEndpoint.parse(raw)
        } catch (_: CheckinEndpoint.Rejected) {
            return CheckinConstants.STATUS_REJECTED
        }
        val socksSpec = store.socks()
        val mode = try {
            CheckinEndpoint.transportMode(parsed, socksSpec)
        } catch (_: CheckinEndpoint.Rejected) {
            return CheckinConstants.STATUS_SKIP_TOR
        }
        val socks = if (mode == "socks") {
            CheckinEndpoint.parseSocks(socksSpec)
        } else {
            null
        }
        val now = System.currentTimeMillis() / 1000L
        val body = CheckinPayload.build(
            store.deviceId(),
            now,
            store.nextSeq(),
            CheckinConstants.STATUS_OK
        )
        val ok = CheckinTransport.post(
            parsed.uri.toString(),
            socks,
            body.toByteArray(Charsets.UTF_8)
        )
        return if (ok) CheckinConstants.STATUS_OK else CheckinConstants.STATUS_FAILED
    }

    companion object {
        private const val TAG = "GTCheckin/Job"
    }
}
