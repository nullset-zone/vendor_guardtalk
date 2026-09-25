package com.guardtalk.checkin

import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.util.Log

/** Registers the 12 h periodic job and a first-boot one-shot. */
object CheckinScheduler {

    private const val TAG = "GTCheckin/Sched"

    fun schedule(context: Context) {
        val scheduler = context.getSystemService(JobScheduler::class.java)
        if (scheduler == null) {
            Log.e(TAG, "JobScheduler missing")
            return
        }
        val component = ComponentName(context, CheckinJobService::class.java)
        scheduler.schedule(periodic(component))
        scheduler.schedule(oneshot(component))
        Log.i(TAG, "scheduled periodic=${CheckinConstants.INTERVAL_MS}ms")
    }

    fun runNow(context: Context) {
        val scheduler = context.getSystemService(JobScheduler::class.java) ?: return
        val component = ComponentName(context, CheckinJobService::class.java)
        scheduler.schedule(oneshot(component))
    }

    private fun periodic(component: ComponentName): JobInfo {
        return JobInfo.Builder(CheckinConstants.JOB_PERIODIC, component)
            .setPeriodic(CheckinConstants.INTERVAL_MS)
            .setPersisted(true)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .build()
    }

    private fun oneshot(component: ComponentName): JobInfo {
        return JobInfo.Builder(CheckinConstants.JOB_ONESHOT, component)
            .setOverrideDeadline(CheckinConstants.ONESHOT_DEADLINE_MS)
            .setPersisted(true)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .build()
    }
}
