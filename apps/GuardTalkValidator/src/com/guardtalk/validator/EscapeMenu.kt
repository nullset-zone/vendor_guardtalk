package com.guardtalk.validator

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.provider.Settings
import android.view.LayoutInflater
import android.widget.Button
import android.widget.Toast

/**
 * Escape/menu surface: Settings, camera/mic, device status.
 *
 * Camera/mic switches use [SensorToggleHelper] (F-REMEDIATE-B3-SENSORS
 * polarity). Do not invert. Do not register QS tiles here.
 */
object EscapeMenu {

    fun show(activity: Activity) {
        val view = LayoutInflater.from(activity).inflate(R.layout.escape_menu, null, false)
        bindSettings(activity, view.findViewById(R.id.menu_open_settings))
        SensorToggleViews.bind(activity, view)
        view.findViewById<Button>(R.id.menu_device_status).setOnClickListener {
            showStatus(activity)
        }
        AlertDialog.Builder(activity)
            .setTitle(R.string.menu_title)
            .setView(view)
            .setNegativeButton(R.string.menu_close, null)
            .show()
    }

    private fun bindSettings(activity: Activity, button: Button) {
        button.setOnClickListener {
            val intent = Intent(Settings.ACTION_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                activity.startActivity(intent)
                ValidatorChrome.exitApp(activity)
            } catch (t: RuntimeException) {
                Toast.makeText(activity, R.string.menu_settings_failed, Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun showStatus(activity: Activity) {
        AlertDialog.Builder(activity)
            .setTitle(R.string.status_title)
            .setMessage(DeviceStatusReporter.format(activity))
            .setPositiveButton(R.string.menu_close, null)
            .show()
    }
}
