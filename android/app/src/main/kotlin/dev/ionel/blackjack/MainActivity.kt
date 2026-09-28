package dev.ionel.blackjack

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private var pendingSave: PendingSave? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAVE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveAs" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        if (path == null || name == null) {
                            result.error("args", "saveAs needs a path and a name.", null)
                        } else {
                            saveAs(File(path), name, result)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // The system's create-document screen rather than MediaStore: it needs no
    // storage permission on any API level, and the player chooses the folder —
    // Downloads, an SD card or Drive — instead of us guessing.
    private fun saveAs(source: File, name: String, result: MethodChannel.Result) {
        if (pendingSave != null) {
            result.error("busy", "A save dialog is already open.", null)
            return
        }
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Not application/gzip: the storage provider would "fix" the name to
            // end in .gz, and the file would no longer look like a save.
            type = "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, name)
        }
        pendingSave = PendingSave(source, name, result)
        try {
            startActivityForResult(intent, SAVE_REQUEST)
        } catch (e: ActivityNotFoundException) {
            pendingSave = null
            result.error("unavailable", "This device has no file manager to save into.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val pending = pendingSave ?: return
        pendingSave = null

        val target = data?.data
        if (resultCode != Activity.RESULT_OK || target == null) {
            pending.result.success(null)
            return
        }

        // A stream copy off the main thread: the save is already on disk in the
        // cache, so it goes across in fixed-size chunks however long the
        // calendar is.
        thread(name = "save-as") {
            try {
                val out = contentResolver.openOutputStream(target)
                    ?: throw IOException("The chosen location could not be opened.")
                out.use { sink -> pending.source.inputStream().use { it.copyTo(sink) } }
                val shown = displayName(target) ?: pending.name
                runOnUiThread { pending.result.success(shown) }
            } catch (e: Exception) {
                // A half-written file under a save's name is worse than none: it
                // is exactly what a player would reach for after a bad import.
                try {
                    DocumentsContract.deleteDocument(contentResolver, target)
                } catch (ignored: Exception) {
                }
                runOnUiThread { pending.result.error("write", e.message, null) }
            }
        }
    }

    // The provider may have renamed the file — "(1)" on a clash, or the player
    // typed their own — so report what actually landed.
    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (e: Exception) {
        null
    }

    private class PendingSave(val source: File, val name: String, val result: MethodChannel.Result)

    private companion object {
        const val SAVE_CHANNEL = "dev.ionel.blackjack/save"

        // Well clear of the small request codes plugins tend to pick.
        const val SAVE_REQUEST = 0x4A42
    }
}
