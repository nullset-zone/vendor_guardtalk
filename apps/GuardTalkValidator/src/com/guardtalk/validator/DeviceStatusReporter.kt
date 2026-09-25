package com.guardtalk.validator

import android.content.Context
import android.guardtalk.GuardTalkSecurityStatus
import android.os.Build

/**
 * Minimal device-status text for the escape menu. Never includes Duress.
 */
object DeviceStatusReporter {

    fun format(context: Context): String {
        if (!GuardTalkSecurityStatus.isPostUnlockStatusAllowed(context)) {
            return context.getString(R.string.status_locked)
        }
        val snap = GuardTalkSecurityStatus.collectPolicyMarkers()
        val cam = accessLabel(context, SensorToggleHelper.CAMERA)
        val mic = accessLabel(context, SensorToggleHelper.MICROPHONE)
        val denied = SensorToggleHelper.isEnableBlocked(context)
        return context.getString(
            R.string.status_body,
            Build.MODEL,
            onOff(context, snap.sensorPrivacyPolicy),
            onOff(context, denied),
            cam,
            mic,
            onOff(context, snap.usbProtectionPolicy),
            onOff(context, snap.productionHardening),
        )
    }

    private fun accessLabel(context: Context, sensor: Int): String {
        return if (SensorToggleHelper.isAccessOn(context, sensor)) {
            context.getString(R.string.toggle_access_on)
        } else {
            context.getString(R.string.toggle_access_off)
        }
    }

    private fun onOff(context: Context, value: Boolean): String {
        return if (value) {
            context.getString(R.string.toggle_access_on)
        } else {
            context.getString(R.string.toggle_access_off)
        }
    }
}
