package com.guardtalk.validator

import android.content.Context
import android.view.View
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast

/**
 * Binds [R.layout.sensor_privacy_toggles] using [SensorToggleHelper].
 *
 * F-REMEDIATE-B3-SENSORS owns polarity in the helper. This class only wires
 * view ids. Do not invert checked state here.
 */
object SensorToggleViews {

    fun bind(context: Context, root: View) {
        wire(
            context,
            root.findViewById(R.id.switch_camera_access),
            root.findViewById(R.id.camera_access_summary),
            SensorToggleHelper.CAMERA,
        )
        wire(
            context,
            root.findViewById(R.id.switch_microphone_access),
            root.findViewById(R.id.microphone_access_summary),
            SensorToggleHelper.MICROPHONE,
        )
    }

    fun refresh(context: Context, root: View) {
        refreshRow(
            context,
            root.findViewById(R.id.switch_camera_access),
            root.findViewById(R.id.camera_access_summary),
            SensorToggleHelper.CAMERA,
        )
        refreshRow(
            context,
            root.findViewById(R.id.switch_microphone_access),
            root.findViewById(R.id.microphone_access_summary),
            SensorToggleHelper.MICROPHONE,
        )
    }

    private fun wire(context: Context, toggle: Switch?, summary: TextView?, sensor: Int) {
        if (toggle == null || summary == null) {
            return
        }
        val state = RowState()
        toggle.tag = state
        toggle.setOnCheckedChangeListener { _, isChecked ->
            if (state.updating) {
                return@setOnCheckedChangeListener
            }
            if (!SensorToggleHelper.setAccessOn(context, sensor, isChecked)) {
                Toast.makeText(
                    context,
                    SensorToggleHelper.blockedMessageRes(context),
                    Toast.LENGTH_SHORT,
                ).show()
            }
            applyState(context, toggle, summary, sensor, state)
        }
        applyState(context, toggle, summary, sensor, state)
    }

    private fun refreshRow(context: Context, toggle: Switch?, summary: TextView?, sensor: Int) {
        if (toggle == null || summary == null) {
            return
        }
        val state = toggle.tag as? RowState ?: RowState().also { toggle.tag = it }
        applyState(context, toggle, summary, sensor, state)
    }

    private fun applyState(
        context: Context,
        toggle: Switch,
        summary: TextView,
        sensor: Int,
        state: RowState,
    ) {
        val accessOn = SensorToggleHelper.isAccessOn(context, sensor)
        val available = SensorToggleHelper.isToggleAvailable(context, sensor)
        val blocked = SensorToggleHelper.isEnableBlocked(context)
        state.updating = true
        toggle.isChecked = accessOn
        when {
            !available -> {
                toggle.isEnabled = false
                summary.setText(R.string.sensor_access_unsupported)
            }
            blocked && !accessOn -> {
                toggle.isEnabled = false
                summary.setText(SensorToggleHelper.blockedMessageRes(context))
            }
            else -> {
                toggle.isEnabled = true
                summary.setText(R.string.sensor_access_summary)
            }
        }
        state.updating = false
    }

    private class RowState {
        var updating: Boolean = false
    }
}
