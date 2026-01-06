package com.video.downloader.saver.manager.free.allvideodownloader

import io.flutter.plugins.GeneratedPluginRegistrant;
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
    private val WIDGET_CHANNEL = "com.video.downloader.saver.manager.free.allvideodownloader/widget_actions"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Explicitly register all plugins (helps with R8 optimization issues)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // Handle Widget Actions Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
             // Initial check if opened from widget
             if (call.method == "checkWidgetAction") {
                 val action = intent.action
                 if (action == "ACTION_WIDGET_OPEN_INSTA" || action == "ACTION_WIDGET_OPEN_GALLERY") {
                     result.success(action)
                     intent.action = null // Clear action so it doesn't trigger again on reload
                 } else {
                     result.success(null)
                 }
             } else {
                 result.notImplemented()
             }
        }

        // 🔹 Save video into MediaStore
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "saveMedia") {
                val path = call.argument<String>("path")
                val mediaType = call.argument<String>("mediaType") ?: "video"
                
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "Path is null", null)
                    return@setMethodCallHandler
                }

                val file = File(path)
                if (!file.exists()) {
                    result.error("FILE_NOT_FOUND", "File does not exist at $path", null)
                    return@setMethodCallHandler
                }

                val isImage = mediaType == "image"
                val contentUri = if (isImage) {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                } else {
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                }

                val values = ContentValues().apply {
                    if (isImage) {
                        put(MediaStore.Images.Media.DISPLAY_NAME, file.name)
                        put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
                        put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/InstaSave")
                    } else {
                        put(MediaStore.Video.Media.DISPLAY_NAME, file.name)
                        put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                        put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/InstaSave")
                    }
                }

                val uri: Uri? = contentResolver.insert(contentUri, values)

                if (uri == null) {
                    result.error("MEDIA_ERROR", "Insert failed", null)
                    return@setMethodCallHandler
                }

                try {
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
                val mediaType = call.argument<String>("mediaType") ?: "video"
                
                if (uriString == null) {
                    result.error("INVALID_ARGUMENT", "URI is null", null)
                    return@setMethodCallHandler
                }

                val uri = Uri.parse(uriString)
                val mimeType = if (mediaType == "image") "image/*" else "video/*"

                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    setPackage("com.instagram.android")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
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

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Notify Flutter about the new intent
        val action = intent.action
        if (action == "ACTION_WIDGET_OPEN_INSTA" || action == "ACTION_WIDGET_OPEN_GALLERY") {
            // We need a way to notify Flutter. Since we set up a passive check in configureFlutterEngine,
            // we might want to also actively INVOKE a method IF the engine is already running.
            // But 'checkWidgetAction' pattern is safer for startup. 
            // For running apps, we can try to invokeMethod, but getting the engine reference here is cleaner via the cached engine if possible.
            // Simplified: The plugin architecture will handle this if we just update the intent, 
            // BUT Flutter won't know unless IT asks or WE tell it. 
            // For now, let's rely on Flutter polling 'checkWidgetAction' on Resume, or we can use EventChannel or invokeMethod.
            
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                 MethodChannel(messenger, WIDGET_CHANNEL).invokeMethod("onWidgetAction", action)
            }
        }
    }
}