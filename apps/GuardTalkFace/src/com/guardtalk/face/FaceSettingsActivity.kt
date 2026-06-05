package com.guardtalk.face

import android.app.Activity
import android.os.Bundle
import android.os.SystemProperties
import android.widget.ArrayAdapter
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView

class FaceSettingsActivity : Activity() {
    companion object {
        private const val PROP_ENABLED = "persist.vendor.guardtalk.face.enabled"
        private const val PROP_PERSONA = "persist.vendor.guardtalk.face.persona"
        private const val PROP_QUALITY = "persist.vendor.guardtalk.face.quality"
    }

    private val personaLabels by lazy {
        listOf(
            getString(R.string.persona_neutral),
            getString(R.string.persona_soft),
            getString(R.string.persona_bold),
            getString(R.string.persona_cool),
            getString(R.string.persona_warm),
        )
    }

    private val qualityLabels by lazy {
        listOf(
            getString(R.string.quality_lite),
            getString(R.string.quality_balanced),
            getString(R.string.quality_max),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_face_settings)

        val statusText = findViewById<TextView>(R.id.status_text)
        val enabledSwitch = findViewById<Switch>(R.id.enabled_switch)
        val personaSpinner = findViewById<Spinner>(R.id.persona_spinner)
        val qualitySpinner = findViewById<Spinner>(R.id.quality_spinner)

        personaSpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            personaLabels,
        )
        qualitySpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            qualityLabels,
        )

        enabledSwitch.isChecked = SystemProperties.getBoolean(PROP_ENABLED, false)
        personaSpinner.setSelection(SystemProperties.getInt(PROP_PERSONA, 0).coerceIn(0, 4))
        qualitySpinner.setSelection(SystemProperties.getInt(PROP_QUALITY, 1).coerceIn(0, 2))
        refreshStatus(statusText, enabledSwitch.isChecked, personaSpinner, qualitySpinner)

        enabledSwitch.setOnCheckedChangeListener { _, isChecked ->
            setProperty(PROP_ENABLED, if (isChecked) "1" else "0")
            refreshStatus(statusText, isChecked, personaSpinner, qualitySpinner)
        }

        val listener = object : android.widget.AdapterView.OnItemSelectedListener {
            override fun onItemSelected(
                parent: android.widget.AdapterView<*>?,
                view: android.view.View?,
                position: Int,
                id: Long,
            ) {
                when (parent?.id) {
                    R.id.persona_spinner -> setProperty(PROP_PERSONA, position.toString())
                    R.id.quality_spinner -> setProperty(PROP_QUALITY, position.toString())
                }
                refreshStatus(statusText, enabledSwitch.isChecked, personaSpinner, qualitySpinner)
            }

            override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
        }
        personaSpinner.onItemSelectedListener = listener
        qualitySpinner.onItemSelectedListener = listener
    }

    private fun setProperty(key: String, value: String) {
        Runtime.getRuntime().exec(arrayOf("setprop", key, value)).waitFor()
    }

    private fun refreshStatus(
        statusText: TextView,
        enabled: Boolean,
        personaSpinner: Spinner,
        qualitySpinner: Spinner,
    ) {
        val enabledLabel = if (enabled) "yes" else "no"
        val persona = personaLabels[personaSpinner.selectedItemPosition]
        val quality = qualityLabels[qualitySpinner.selectedItemPosition]
        statusText.text = getString(R.string.status_template, enabledLabel, persona, quality)
    }
}
