package com.example.insta_save

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

class MainActivity : FlutterActivity() {

    private val MEDIA_CHANNEL = "media_store"
    private val INSTA_CHANNEL = "insta_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 🔹 Save video into MediaStore
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "saveVideo") {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                    return@setMethodCallHandler
                }

                val file = File(path)
                if (!file.exists()) {
                    result.error("FILE_NOT_FOUND", "File does not exist at $path", null)
                    return@setMethodCallHandler
                }

                val values = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, file.name)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/InstaSave")
                }

                val uri: Uri? = contentResolver.insert(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    values
                )

                if (uri == null) {
                    result.error("MEDIA_ERROR", "Insert failed", null)
                    return@setMethodCallHandler
                }

                try {
                    // .use {} ensures streams are closed automatically even if an error occurs
                    contentResolver.openOutputStream(uri)?.use { outputStream ->
                        FileInputStream(file).use { inputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    result.success(uri.toString())
                } catch (e: Exception) {
                    result.error("WRITE_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 🔹 Open Instagram with MediaStore URI
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTA_CHANNEL
        ).setMethodCallHandler { call, result ->

            // ✅ Changed name to match Flutter's call: 'repostToInstagram'
            if (call.method == "repostToInstagram") {
                val uriString = call.argument<String>("uri")
                if (uriString == null) {
                    result.error("INVALID_ARGUMENT", "URI is null", null)
                    return@setMethodCallHandler
                }

                val uri = Uri.parse(uriString)

                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "video/*"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    setPackage("com.instagram.android")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    // Ensure the activity is started in a new task if necessary
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                try {
                    startActivity(intent)
                    result.success(null) // ✅ Stops the Flutter loader
                } catch (e: Exception) {
                    result.error("INSTA_ERROR", "Instagram not installed or could not be opened", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}