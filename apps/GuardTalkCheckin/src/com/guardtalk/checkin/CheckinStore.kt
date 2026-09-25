package com.guardtalk.checkin

import android.content.Context
import android.provider.Settings
import java.security.MessageDigest

/**
 * Reads provisioned Global keys and persists last local result.
 * Does not log device_id or endpoint URLs.
 */
class CheckinStore(private val context: Context) {

    private val prefs = context.getSharedPreferences(
        CheckinConstants.PREFS,
        Context.MODE_PRIVATE
    )

    fun endpoint(): String {
        return Settings.Global.getString(
            context.contentResolver,
            CheckinConstants.GLOBAL_ENDPOINT
        ) ?: ""
    }

    fun socks(): String {
        return Settings.Global.getString(
            context.contentResolver,
            CheckinConstants.GLOBAL_SOCKS
        ) ?: ""
    }

    fun deviceId(): String {
        val provisioned = Settings.Global.getString(
            context.contentResolver,
            CheckinConstants.GLOBAL_DEVICE_ID
        ) ?: ""
        val trimmed = provisioned.trim()
        if (trimmed.matches(Regex("^[a-f0-9]{32,64}$"))) return trimmed
        return deriveFromAndroidId()
    }

    fun nextSeq(): Int {
        val seq = prefs.getInt(CheckinConstants.PREF_SEQ, 0) + 1
        prefs.edit().putInt(CheckinConstants.PREF_SEQ, seq).apply()
        return seq
    }

    fun record(status: String, unix: Long) {
        prefs.edit()
            .putString(CheckinConstants.PREF_LAST_STATUS, status)
            .putLong(CheckinConstants.PREF_LAST_UNIX, unix)
            .apply()
    }

    fun lastStatus(): String {
        return prefs.getString(CheckinConstants.PREF_LAST_STATUS, "") ?: ""
    }

    fun lastUnix(): Long {
        return prefs.getLong(CheckinConstants.PREF_LAST_UNIX, 0L)
    }

    private fun deriveFromAndroidId(): String {
        val androidId = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID
        ) ?: "unknown"
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest("gtcid:$androidId".toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { b -> "%02x".format(b) }
    }
}
