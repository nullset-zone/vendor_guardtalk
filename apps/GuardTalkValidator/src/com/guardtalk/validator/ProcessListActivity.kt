package com.guardtalk.validator

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.view.KeyEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ListView
import android.widget.TextView

/**
 * FR-4 process-list viewer.
 *
 * A minimal, dependency-free screen that lists every running OS process
 * (PID/UID/name/state) in a [ListView] with a Refresh button.
 *
 * Least-privilege / attack-surface notes (Law 4, FR-6):
 * - This activity is declared NON-exported in AndroidManifest.xml. Only the
 *   launcher [ValidatorActivity] (the sole exported component) can start it.
 * - No service, no receiver, no provider, no IPC endpoint. The enumeration is
 *   an in-process call to ActivityManager.getRunningAppProcesses().
 * - No root, no su, no shell exec.
 * - Theme is inherited from the application (Theme.DeviceDefault.Settings),
 *   which is dark under FR-1; no theme work here.
 */
class ProcessListActivity : Activity() {

    private lateinit var summaryView: TextView
    private lateinit var listView: ListView
    private var adapter: ProcessAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_process_list)

        ValidatorChrome.attach(this, /* leaveAppOnBack= */ false)

        val titleView = findViewById<TextView>(R.id.escape_hotspot)
        summaryView = findViewById(R.id.process_summary)
        listView = findViewById(R.id.process_list)
        val refresh = findViewById<Button>(R.id.process_refresh)

        titleView.text = getString(R.string.process_view_title)
        refresh.text = getString(R.string.process_refresh)
        refresh.setOnClickListener { refresh() }

        refresh()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        ValidatorChrome.onScreenBack(this, /* leaveAppOnBack= */ false)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (ValidatorChrome.handleKey(this, keyCode, event)) {
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (ValidatorChrome.handleKey(this, keyCode, event)) {
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    /** Re-enumerate and update the list. */
    private fun refresh() {
        val result = ProcessEnumerator.enumerate(this)
        when (result) {
            is ProcessEnumerator.Result.Error -> {
                summaryView.text = if (result.security)
                    getString(R.string.process_security_error, result.message)
                else result.message
                adapter = ProcessAdapter(this, emptyList())
                listView.adapter = adapter
            }
            is ProcessEnumerator.Result.Success -> {
                summaryView.text =
                    getString(R.string.process_view_summary, result.items.size)
                adapter = ProcessAdapter(this, result.items)
                listView.adapter = adapter
            }
        }
    }

    /** ArrayAdapter that renders one [ProcessEnumerator.ProcessInfo] row. */
    private class ProcessAdapter(
        context: Context,
        items: List<ProcessEnumerator.ProcessInfo>,
    ) : ArrayAdapter<ProcessEnumerator.ProcessInfo>(context, 0, items) {

        private val inflater = LayoutInflater.from(context)
        private val unknownUid = context.getString(R.string.process_unknown_uid)

        override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
            val view = convertView ?: inflater.inflate(R.layout.process_row, parent, false)
            val item = getItem(position)!!
            view.findViewById<TextView>(R.id.proc_pid).text = item.pid.toString()
            view.findViewById<TextView>(R.id.proc_uid).text =
                if (item.uid == 0) "root" else item.uid.toString()
            view.findViewById<TextView>(R.id.proc_name).text =
                item.name.ifBlank { unknownUid }
            view.findViewById<TextView>(R.id.proc_state).text = item.state
            return view
        }
    }
}
