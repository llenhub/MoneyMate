package dev.moneymate.moneymate

import android.app.Activity
import android.content.Intent
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private data class Backup(val data: ByteArray, val result: MethodChannel.Result)
    private var backup: Backup? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.moneymate/platform")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "freeBytes" -> result.success(StatFs(filesDir.path).availableBytes)
                    "saveBackup" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data == null || backup != null) {
                            result.error("BACKUP", "Could not open the backup picker.", null)
                        } else {
                            backup = Backup(data, result)
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                            }
                            try {
                                @Suppress("DEPRECATION")
                                startActivityForResult(intent, SAVE_BACKUP)
                            } catch (_: Exception) {
                                backup = null
                                result.error("PICKER", "Could not open the backup picker.", null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Uses the platform document picker through FlutterActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_BACKUP) return
        val pending = backup ?: return
        backup = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.result.success(false)
            return
        }
        Thread {
            try {
                val output = contentResolver.openOutputStream(uri, "wt")
                    ?: error("Backup destination unavailable")
                output.use { it.write(pending.data) }
                runOnUiThread { pending.result.success(true) }
            } catch (_: Exception) {
                runOnUiThread { pending.result.error("WRITE", "Could not write the backup file.", null) }
            }
        }.start()
    }

    companion object {
        private const val SAVE_BACKUP = 5031
    }
}
