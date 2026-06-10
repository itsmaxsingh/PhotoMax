package com.example.photomax

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.photomax.app/file_manager"
    private val REQUEST_MANAGE_STORAGE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestManageStorage" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        if (Environment.isExternalStorageManager()) {
                            result.success(true)
                        } else {
                            // Store the result to return later
                            pendingResult = result
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                                intent.data = Uri.parse("package:$packageName")
                                startActivityForResult(intent, REQUEST_MANAGE_STORAGE)
                            } catch (e: Exception) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivityForResult(intent, REQUEST_MANAGE_STORAGE)
                            }
                        }
                    } else {
                        // For Android versions below 11, permission is granted by default
                        result.success(true)
                    }
                }
                "moveFile" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val destPath = call.argument<String>("destinationPath")
                    
                    if (sourcePath == null || destPath == null) {
                        result.error("INVALID_ARGS", "Source or destination path is null", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val srcFile = File(sourcePath)
                        val destDir = File(destPath)
                        
                        if (!srcFile.exists()) {
                            result.error("FILE_NOT_FOUND", "Source file does not exist: $sourcePath", null)
                            return@setMethodCallHandler
                        }
                        
                        if (!destDir.exists()) {
                            val created = destDir.mkdirs()
                            if (!created) {
                                result.error("CREATE_DIR_FAILED", "Could not create directory: $destPath", null)
                                return@setMethodCallHandler
                            }
                        }
                        
                        val destFile = File(destDir, srcFile.name)
                        val success = srcFile.renameTo(destFile)
                        
                        if (success) {
                            // Notify media scanner
                            val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                            mediaScanIntent.data = Uri.fromFile(destFile)
                            sendBroadcast(mediaScanIntent)
                            
                            // Also scan the source directory
                            val sourceParent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                            sourceParent.data = Uri.fromFile(srcFile.parentFile)
                            sendBroadcast(sourceParent)
                            
                            result.success(true)
                        } else {
                            result.error("MOVE_FAILED", "File.renameTo() returned false", null)
                        }
                    } catch (e: Exception) {
                        result.error("MOVE_ERROR", e.message, null)
                    }
                }
                "copyFile" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val destPath = call.argument<String>("destinationPath")
                    
                    if (sourcePath == null || destPath == null) {
                        result.error("INVALID_ARGS", "Source or destination path is null", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val srcFile = File(sourcePath)
                        val destDir = File(destPath)
                        
                        if (!destDir.exists()) {
                            destDir.mkdirs()
                        }
                        
                        val destFile = File(destDir, srcFile.name)
                        srcFile.copyTo(destFile, overwrite = true)
                        
                        val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                        mediaScanIntent.data = Uri.fromFile(destFile)
                        sendBroadcast(mediaScanIntent)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("COPY_ERROR", e.message, null)
                    }
                }
                "getFolderPath" -> {
                    val folderName = call.argument<String>("folderName") ?: ""
                    val dcim = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
                    val pictures = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                    
                    var targetDir = File(dcim, folderName)
                    if (!targetDir.exists()) {
                        targetDir = File(pictures, folderName)
                    }
                    
                    if (targetDir.exists()) {
                        result.success(targetDir.absolutePath)
                    } else {
                        val newDir = File(dcim, folderName)
                        newDir.mkdirs()
                        result.success(newDir.absolutePath)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == REQUEST_MANAGE_STORAGE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val granted = Environment.isExternalStorageManager()
                pendingResult?.success(granted)
                pendingResult = null
            }
        }
    }
}