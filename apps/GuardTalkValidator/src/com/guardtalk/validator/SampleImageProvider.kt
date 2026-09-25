package com.guardtalk.validator

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.io.FileNotFoundException

/**
 * Grant-only sample PNG for HTMLViewer ACTION_VIEW. Not exported; not a gallery.
 */
class SampleImageProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String = MIME_PNG

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (uri.path != SAMPLE_PATH) {
            throw FileNotFoundException(uri.toString())
        }
        val ctx = context ?: throw FileNotFoundException("no context")
        val file = File(ctx.cacheDir, "sample_image.png")
        try {
            if (!file.exists() || file.length() == 0L) {
                ctx.resources.openRawResource(R.raw.sample_image).use { input ->
                    file.outputStream().use { output -> input.copyTo(output) }
                }
            }
            return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        } catch (e: java.io.IOException) {
            throw FileNotFoundException(e.message)
        }
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0

    companion object {
        const val AUTHORITY = "com.guardtalk.validator.sampleimage"
        const val MIME_PNG = "image/png"
        const val SAMPLE_PATH = "/sample.png"
        val SAMPLE_URI: Uri = Uri.parse("content://$AUTHORITY$SAMPLE_PATH")
    }
}
