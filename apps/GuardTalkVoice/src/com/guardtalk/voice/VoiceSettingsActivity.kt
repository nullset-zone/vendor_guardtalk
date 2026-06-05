package com.guardtalk.voice

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView
import android.app.Activity
import android.os.SystemProperties

class VoiceSettingsActivity : Activity() {
    companion object {
        private const val PROP_ENABLED = "persist.vendor.guardtalk.voice.enabled"
        private const val PROP_PRESET = "persist.vendor.guardtalk.voice.preset"
    }

    private val presetLabels by lazy {
        listOf(
            getString(R.string.preset_natural),
            getString(R.string.preset_deep),
            getString(R.string.preset_bright),
            getString(R.string.preset_masked),
            getString(R.string.preset_robot),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_voice_settings)

        val statusText = findViewById<TextView>(R.id.status_text)
        val enabledSwitch = findViewById<Switch>(R.id.enabled_switch)
        val presetSpinner = findViewById<Spinner>(R.id.preset_spinner)

        presetSpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            presetLabels,
        )

        enabledSwitch.isChecked = SystemProperties.getBoolean(PROP_ENABLED, true)
        val preset = SystemProperties.getInt(PROP_PRESET, 0).coerceIn(0, presetLabels.lastIndex)
        presetSpinner.setSelection(preset)
        updateStatus(statusText, enabledSwitch.isChecked, preset)

        enabledSwitch.setOnCheckedChangeListener { _, isChecked ->
            setProperty(PROP_ENABLED, if (isChecked) "1" else "0")
            updateStatus(statusText, isChecked, presetSpinner.selectedItemPosition)
        }

        presetSpinner.setOnItemSelectedListener(object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: android.widget.AdapterView<*>?,
                view: android.view.View?,
                position: Int,
                id: Long,
            ) {
                setProperty(PROP_PRESET, position.toString())
                updateStatus(statusText, enabledSwitch.isChecked, position)
            }

            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
        })
    }

    private fun setProperty(key: String, value: String) {
        Runtime.getRuntime().exec(arrayOf("setprop", key, value)).waitFor()
    }

    private fun updateStatus(statusText: TextView, enabled: Boolean, presetIndex: Int) {
        val enabledLabel = if (enabled) "yes" else "no"
        val presetLabel = presetLabels.getOrElse(presetIndex) { presetLabels[0] }
        statusText.text = getString(R.string.status_template, enabledLabel, presetLabel)
    }
}
