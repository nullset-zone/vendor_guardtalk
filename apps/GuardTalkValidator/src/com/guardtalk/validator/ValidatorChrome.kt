package com.guardtalk.validator

import android.app.Activity
import android.os.SystemClock
import android.view.KeyEvent
import android.view.View
import android.widget.Button
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher

/**
 * Shared chrome: Exit on every screen, Menu, back/home leave, escape → menu.
 */
object ValidatorChrome {

    private const val ESCAPE_TAP_WINDOW_MS = 800L
    private const val ESCAPE_TAP_COUNT = 3

    fun attach(activity: Activity, leaveAppOnBack: Boolean) {
        activity.findViewById<Button>(R.id.btn_exit).setOnClickListener { exitApp(activity) }
        activity.findViewById<Button>(R.id.btn_menu).setOnClickListener { EscapeMenu.show(activity) }
        bindEscapeHotspot(activity)
        bindBack(activity, leaveAppOnBack)
    }

    fun exitApp(activity: Activity) {
        activity.finishAndRemoveTask()
    }

    fun onScreenBack(activity: Activity, leaveAppOnBack: Boolean) {
        if (leaveAppOnBack) {
            exitApp(activity)
        } else {
            activity.finish()
        }
    }

    fun handleKey(activity: Activity, keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_BACK && event.isLongPress) {
            EscapeMenu.show(activity)
            return true
        }
        if (event.action != KeyEvent.ACTION_UP) {
            return false
        }
        if (keyCode == KeyEvent.KEYCODE_ESCAPE || keyCode == KeyEvent.KEYCODE_MENU) {
            EscapeMenu.show(activity)
            return true
        }
        return false
    }

    private fun bindBack(activity: Activity, leaveAppOnBack: Boolean) {
        val callback = OnBackInvokedCallback { onScreenBack(activity, leaveAppOnBack) }
        activity.onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_DEFAULT,
            callback,
        )
    }

    private fun bindEscapeHotspot(activity: Activity) {
        val hotspot = activity.findViewById<View>(R.id.escape_hotspot) ?: return
        hotspot.setOnLongClickListener {
            EscapeMenu.show(activity)
            true
        }
        hotspot.setOnClickListener(EscapeTapListener(activity))
    }

    private class EscapeTapListener(private val activity: Activity) : View.OnClickListener {
        private var taps = 0
        private var windowStart = 0L

        override fun onClick(v: View) {
            val now = SystemClock.uptimeMillis()
            if (now - windowStart > ESCAPE_TAP_WINDOW_MS) {
                taps = 0
                windowStart = now
            }
            taps += 1
            if (taps >= ESCAPE_TAP_COUNT) {
                taps = 0
                EscapeMenu.show(activity)
            }
        }
    }
}
