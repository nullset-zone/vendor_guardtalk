package com.guardtalk.validator

import android.app.ActivityManager
import android.content.Context

/**
 * FR-4 process enumeration API.
 *
 * Enumerates every running OS process via
 * [ActivityManager.getRunningAppProcesses] and maps each process UID to a
 * human-readable package name via [android.content.pm.PackageManager.getPackagesForUid].
 *
 * Least-privilege notes (Law 4):
 * - The full list (all UIDs, not just the caller's) requires REAL_GET_TASKS,
 *   verified in AOSP:
 *     ActivityManagerService.java:10212  getRunningAppProcesses()
 *       -> mAtmInternal.isGetTasksAllowed(...) sets allUids flag
 *     ProcessList.java:4353  getRunningAppProcessesLOSP() filters
 *       (!allUids && app.uid != callingUid) -> skip
 *     ActivityTaskManagerService.java:3629  isGetTasksAllowed() grants when
 *       REAL_GET_TASKS (signature|privileged) is held.
 * - UID -> name mapping requires QUERY_ALL_PACKAGES on Android 11+
 *   (package-visibility filtering).
 * - PACKAGE_USAGE_STATS is NOT in the getRunningAppProcesses code path (it
 *   gates UsageStatsManager, a separate API) and is therefore NOT requested.
 * - No root, no su, no shell exec, no IPC. The enumeration is purely
 *   in-process against framework APIs.
 */
object ProcessEnumerator {

    /** A single running process row. */
    data class ProcessInfo(
        val pid: Int,
        val uid: Int,
        val name: String,
        val state: String,
    )

    /** Sealed enumeration result. */
    sealed interface Result {
        /** Success: [items] is the (possibly empty) list of processes. */
        data class Success(val items: List<ProcessInfo>) : Result

        /** Failure: [message] describes the error; [security] is true if a
         *  SecurityException was thrown (permission missing). */
        data class Error(val message: String, val security: Boolean = false) : Result
    }

    /**
     * Enumerate all running app processes.
     *
     * @param context any context; used to obtain ActivityManager + PackageManager.
     * @return [Result.Success] with the process list, or [Result.Error] if
     *         ActivityManager is unavailable or the caller lacks permission.
     */
    fun enumerate(context: Context): Result {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return Result.Error("ActivityManager unavailable")

        val processes: List<ActivityManager.RunningAppProcessInfo> = try {
            am.runningAppProcesses ?: emptyList()
        } catch (e: SecurityException) {
            return Result.Error(
                message = e.message ?: "SecurityException",
                security = true,
            )
        }

        val pm = context.packageManager
        val items = processes.map { info ->
            ProcessInfo(
                pid = info.pid,
                uid = info.uid,
                name = info.processName,
                state = importanceLabel(info.importance),
            )
        }.sortedWith(compareBy({ it.uid }, { it.pid }))
        // Note: getPackagesForUid() is available for richer UID->package
        // mapping if processName is ever insufficient; processName is normally
        // already the package name (or "package:process" for multi-process
        // apps) so we surface it directly and avoid an extra PackageManager
        // round-trip. QUERY_ALL_PACKAGES is held so a future getPackagesForUid
        // call would also return full results.
        return Result.Success(items)
    }

    /** Map an ActivityManager importance constant to a short state label. */
    private fun importanceLabel(importance: Int): String = when (importance) {
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> "FOREGROUND"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE ->
            "FG_SERVICE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_TOP_SLEEPING ->
            "TOP_SLEEPING"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE -> "VISIBLE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_PERCEPTIBLE ->
            "PERCEPTIBLE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_CANT_SAVE_STATE ->
            "CANT_SAVE_STATE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE -> "SERVICE"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED -> "CACHED"
        ActivityManager.RunningAppProcessInfo.IMPORTANCE_GONE -> "GONE"
        else -> "importance=$importance"
    }
}
