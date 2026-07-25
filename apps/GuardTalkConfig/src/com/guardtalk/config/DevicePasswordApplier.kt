package com.guardtalk.config

import android.app.KeyguardManager
import android.content.Context
import android.os.UserHandle
import android.util.Log
import com.android.internal.widget.LockPatternUtils
import com.android.internal.widget.LockscreenCredential

/**
 * Apply a device unlock **password** from a verified QR payload (parity with
 * SetupWizard2 `DevicePasswordApplier` / T-SUW-LOCK-APPLY).
 *
 * Password-only (`CREDENTIAL_TYPE_PASSWORD`). Never logs plaintext secrets;
 * zeroes [LockscreenCredential] buffers after use.
 */
object DevicePasswordApplier {
    private const val TAG = "GTCfg/DevPwd"

    const val MIN_PASSWORD_LENGTH: Int = LockPatternUtils.MIN_LOCK_PASSWORD_SIZE

    sealed class Result {
        data object Success : Result()
        data class Failure(val reason: String) : Result()
    }

    fun validateQuality(password: CharSequence?): Result {
        if (password == null) {
            return Result.Failure("device_password missing")
        }
        val trimmedLength = password.trim().length
        if (trimmedLength == 0) {
            return Result.Failure("device_password empty")
        }
        if (trimmedLength < MIN_PASSWORD_LENGTH) {
            return Result.Failure(
                "device_password shorter than $MIN_PASSWORD_LENGTH characters"
            )
        }
        return Result.Success
    }

    /**
     * Set unlock password when the device is not yet secure.
     * If already secure, returns Success with a skip semantics (caller logs step).
     */
    @JvmOverloads
    fun applyPasswordIfNeeded(
        context: Context,
        password: CharSequence?,
        userId: Int = UserHandle.myUserId(),
    ): ApplyOutcome {
        when (val quality = validateQuality(password)) {
            is Result.Failure -> return ApplyOutcome.Failed(quality.reason)
            Result.Success -> Unit
        }
        val kg = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (kg != null && kg.isDeviceSecure) {
            Log.i(TAG, "Device already secure; skipping lock apply (userId=$userId)")
            return ApplyOutcome.SkippedAlreadySecure
        }
        val trimmed = password!!.trim().toString()
        var newCredential: LockscreenCredential? = null
        var savedCredential: LockscreenCredential? = null
        return try {
            newCredential = LockscreenCredential.createPassword(trimmed)
            savedCredential = LockscreenCredential.createNone()
            newCredential.validateBasicRequirements()
            val utils = LockPatternUtils(context)
            val ok = utils.setLockCredential(newCredential, savedCredential, userId)
            if (!ok) {
                Log.e(TAG, "setLockCredential returned false (userId=$userId)")
                ApplyOutcome.Failed("setLockCredential failed")
            } else {
                Log.i(TAG, "Device unlock password applied (userId=$userId)")
                ApplyOutcome.Applied
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Device password apply denied: ${e.javaClass.simpleName}")
            ApplyOutcome.Failed("lock apply denied")
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Device password rejected: ${e.javaClass.simpleName}")
            ApplyOutcome.Failed("device_password quality rejected")
        } catch (e: Exception) {
            Log.e(TAG, "Device password apply failed: ${e.javaClass.simpleName}")
            ApplyOutcome.Failed("lock apply failed")
        } finally {
            newCredential?.zeroize()
            savedCredential?.zeroize()
        }
    }

    sealed class ApplyOutcome {
        data object Applied : ApplyOutcome()
        data object SkippedAlreadySecure : ApplyOutcome()
        data class Failed(val reason: String) : ApplyOutcome()
    }
}
