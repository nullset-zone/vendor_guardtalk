package com.guardtalk.messenger

import android.content.Context
import android.util.Log

/**
 * Persists the Jami RING account id returned by Gateway jamid.
 *
 * Does not store message bodies. Account ids are public fingerprints.
 */
class JamiAccountStore(context: Context) {

    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun getAccountId(): String? {
        val raw = try {
            prefs.getString(KEY_ACCOUNT, null)
        } catch (e: Exception) {
            Log.e(TAG, "read account id failed", e)
            null
        }
        return raw?.takeIf { it.isNotBlank() }
    }

    fun setAccountId(accountId: String) {
        val trimmed = accountId.trim()
        if (trimmed.isEmpty()) {
            Log.w(TAG, "refusing empty account id")
            return
        }
        try {
            prefs.edit().putString(KEY_ACCOUNT, trimmed).apply()
        } catch (e: Exception) {
            Log.e(TAG, "write account id failed", e)
        }
    }

    companion object {
        private const val TAG = "GTMsg/Account"
        private const val PREFS = "jami_account"
        private const val KEY_ACCOUNT = "account_id"
    }
}
