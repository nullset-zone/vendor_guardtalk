package com.guardtalk.validator

import android.app.Activity
import android.app.AlertDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.util.Log

/**
 * Validator / main-path jpeg/png/webp VIEW via HTMLViewer. Not a gallery.
 * Do not add this to [EscapeMenu] (F-REMEDIATE-B3-VALIDATOR owns that surface).
 */
object HtmlViewerLaunch {

    const val HTMLVIEWER_PACKAGE = "com.android.htmlviewer"
    const val HTMLVIEWER_ACTIVITY = "com.android.htmlviewer.HTMLViewerActivity"
    private const val TAG = "HtmlViewerLaunch"

    fun isStillImageMime(mime: String?): Boolean {
        return mime == "image/jpeg" || mime == "image/png" || mime == "image/webp"
    }

    fun createViewIntent(uri: Uri, mime: String): Intent {
        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(uri, mime)
        intent.setClassName(HTMLVIEWER_PACKAGE, HTMLVIEWER_ACTIVITY)
        intent.addCategory(Intent.CATEGORY_DEFAULT)
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return intent
    }

    fun open(activity: Activity, uri: Uri, mime: String): Boolean {
        if (!isStillImageMime(mime)) {
            return false
        }
        val intent = createViewIntent(uri, mime)
        if (intent.resolveActivity(activity.packageManager) == null) {
            return false
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "HTMLViewer VIEW missing for $uri", e)
            false
        } catch (e: SecurityException) {
            Log.w(TAG, "HTMLViewer VIEW denied for $uri", e)
            false
        }
    }

    fun openSampleOrExplain(activity: Activity) {
        val opened = open(
            activity,
            SampleImageProvider.SAMPLE_URI,
            SampleImageProvider.MIME_PNG,
        )
        if (opened) {
            return
        }
        AlertDialog.Builder(activity)
            .setTitle(R.string.sample_image_failed_title)
            .setMessage(R.string.sample_image_failed_message)
            .setPositiveButton(android.R.string.ok, null)
            .show()
    }
}
