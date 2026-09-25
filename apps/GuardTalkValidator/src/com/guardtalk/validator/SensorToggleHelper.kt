package com.guardtalk.validator

import android.app.KeyguardManager
import android.content.Context
import android.guardtalk.GuardTalkSensorPrivacyPolicy
import android.hardware.SensorPrivacyManager
import android.hardware.SensorPrivacyManager.Sensors
import android.os.UserManager
import android.util.Log
import com.android.internal.widget.LockPatternUtils

/**
 * In-app camera/mic access toggles for GT Info (F-REMEDIATE-B3-SENSORS).
 *
 * Polarity matches Settings [SensorToggleController] / QS tiles:
 * `accessOn == !isSensorPrivacyEnabled`. Privacy-ON (access off) is always
 * attempted. Privacy-OFF is rejected while 4-arg
 * [GuardTalkSensorPrivacyPolicy.mustDenySensors] is true so lockdown-when-locked
 * stays fail-closed. F-VALIDATOR [EscapeMenu] calls this; do not invert; do not
 * call SensorPrivacyService.
 */
object SensorToggleHelper {

    private const val TAG = "GtSensorToggle"

    const val CAMERA: Int = Sensors.CAMERA
    const val MICROPHONE: Int = Sensors.MICROPHONE

    fun isAccessOn(context: Context, sensor: Int): Boolean {
        val spm = sensorManager(context) ?: return false
        return try {
            !spm.isSensorPrivacyEnabled(sensor)
        } catch (t: RuntimeException) {
            Log.w(TAG, "read sensor $sensor failed", t)
            false
        }
    }

    /**
     * Persist camera/mic access. Access ON → privacy OFF.
     *
     * @return true if the framework accepted the request
     */
    fun setAccessOn(context: Context, sensor: Int, accessOn: Boolean): Boolean {
        if (accessOn && isEnableBlocked(context)) {
            return false
        }
        val spm = sensorManager(context) ?: return false
        return try {
            spm.setSensorPrivacy(SensorPrivacyManager.Sources.OTHER, sensor, !accessOn)
            true
        } catch (t: RuntimeException) {
            Log.w(TAG, "set sensor $sensor failed", t)
            false
        }
    }

    /**
     * True when turning access ON would be rejected (lockdown / keyguard /
     * pre-unlock). Same 4-arg mustDeny as Settings helper and QS tiles.
     */
    fun isEnableBlocked(context: Context): Boolean {
        if (!GuardTalkSensorPrivacyPolicy.isSensorPrivacyWhenLockedEnabled() &&
            !GuardTalkSensorPrivacyPolicy.isLockdownFailClosedEnabled()
        ) {
            return false
        }
        val userId = context.userId
        val km = context.getSystemService(KeyguardManager::class.java)
        val um = context.getSystemService(UserManager::class.java)
        val keyguardShowing = km != null && km.isKeyguardLocked
        val deviceLocked = km != null && km.isDeviceLocked(userId)
        val userUnlocked = um != null && um.isUserUnlocked(userId)
        val strongAuth = LockPatternUtils(context).getStrongAuthForUser(userId)
        return GuardTalkSensorPrivacyPolicy.mustDenySensors(
            keyguardShowing,
            deviceLocked,
            userUnlocked,
            strongAuth,
        )
    }

    /** False when the software toggle is missing or user-restricted. */
    fun isToggleAvailable(context: Context, sensor: Int): Boolean {
        val spm = sensorManager(context) ?: return false
        if (!spm.supportsSensorToggle(sensor)) {
            return false
        }
        val restriction = if (sensor == CAMERA) {
            UserManager.DISALLOW_CAMERA_TOGGLE
        } else {
            UserManager.DISALLOW_MICROPHONE_TOGGLE
        }
        val um = context.getSystemService(UserManager::class.java)
        return um?.hasUserRestriction(restriction) != true
    }

    /** Toast / summary while access cannot be turned ON. */
    fun blockedMessageRes(context: Context): Int {
        val flags = LockPatternUtils(context).getStrongAuthForUser(context.userId)
        return if (GuardTalkSensorPrivacyPolicy.isLockdownActive(flags)) {
            R.string.menu_toggle_blocked_lockdown
        } else {
            R.string.menu_toggle_blocked
        }
    }

    private fun sensorManager(context: Context): SensorPrivacyManager? {
        return context.getSystemService(SensorPrivacyManager::class.java)
    }
}
