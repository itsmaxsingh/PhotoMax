package com.example.photomax

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.media.MediaScannerConnection
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.photomax.gallery/file_manager"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                // ✅ NEW: Checks and asks for All Files Access permission
                "requestManageStorage" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        if (!Environment.isExternalStorageManager()) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                                val uri = Uri.fromParts("package", packageName, null)
                                intent.data = uri
                                startActivity(intent)
                            } catch (e: Exception) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                            }
                            result.success(false) // Permission wasn't granted yet, just opened settings
                        } else {
                            result.success(true) // Already granted
                        }
                    } else {
                        result.success(true) // Not needed below Android 11
                    }
                }

                "moveFile" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val destinationPath = call.argument<String>("destinationPath")

                    if (sourcePath != null && destinationPath != null) {
                        val success = moveFile(sourcePath, destinationPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is null", null)
                    }
                }

                "copyFile" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val destinationPath = call.argument<String>("destinationPath")

                    if (sourcePath != null && destinationPath != null) {
                        val success = copyFile(sourcePath, destinationPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is null", null)
                    }
                }

                "getFolderPath" -> {
                    val folderName = call.argument<String>("folderName")
                    if (folderName != null) {
                        val path = getFolderPath(folderName)
                        result.success(path)
                    } else {
                        result.error("INVALID_ARGUMENT", "Folder name is null", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun moveFile(sourcePath: String, destinationFolderPath: String): Boolean {
        return try {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists()) return false

            val destFolder = File(destinationFolderPath)
            if (!destFolder.exists()) {
                destFolder.mkdirs()
            }

            val destFile = File(destFolder, sourceFile.name)

            FileInputStream(sourceFile).use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            val deleted = sourceFile.delete()

            if (deleted) {
                scanFileModern(destFile.absolutePath)
            }

            deleted
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun copyFile(sourcePath: String, destinationFolderPath: String): Boolean {
        return try {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists()) return false

            val destFolder = File(destinationFolderPath)
            if (!destFolder.exists()) {
                destFolder.mkdirs()
            }

            val destFile = File(destFolder, sourceFile.name)

            FileInputStream(sourceFile).use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }

            scanFileModern(destFile.absolutePath)

            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun getFolderPath(folderName: String): String {
        val externalStorage = Environment.getExternalStorageDirectory()
        return when (folderName.lowercase()) {
            "download", "downloads" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath
            "dcim", "camera" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM).absolutePath
            "pictures" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).absolutePath
            "movies", "videos" -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES).absolutePath
            else -> File(externalStorage, folderName).absolutePath
        }
    }

    private fun scanFileModern(path: String) {
        MediaScannerConnection.scanFile(this, arrayOf(path), null) { _, _ -> }
    }
}