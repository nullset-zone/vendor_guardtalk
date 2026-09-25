package com.guardtalk.checkin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-register persisted jobs after boot. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        CheckinScheduler.schedule(context)
    }
}
