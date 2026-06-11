package com.example.photomax

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.photomax.app/file_manager"
    private val REQUEST_MANAGE_STORAGE = 1001
    private val REQUEST_MEDIA_PERMISSIONS = 1002
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestManageStorage" -> {
                    requestStoragePermissions(result)
                }
                "checkPermission" -> {
                    result.success(hasStoragePermission())
                }
                "openSettings" -> {
                    openAppSettings()
                    result.success(null)
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
                            val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                            mediaScanIntent.data = Uri.fromFile(destFile)
                            sendBroadcast(mediaScanIntent)
                            
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

    private fun hasStoragePermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStoragePermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30+) - Use MANAGE_EXTERNAL_STORAGE
            if (Environment.isExternalStorageManager()) {
                result.success(true)
            } else {
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
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33+) - Use READ_MEDIA_IMAGES
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED) {
                result.success(true)
            } else {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.READ_MEDIA_IMAGES,
                        Manifest.permission.READ_MEDIA_VIDEO
                    ),
                    REQUEST_MEDIA_PERMISSIONS
                )
            }
        } else {
            // Android 12 and below - Use READ_EXTERNAL_STORAGE
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
                result.success(true)
            } else {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.READ_EXTERNAL_STORAGE,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                    ),
                    REQUEST_MEDIA_PERMISSIONS
                )
            }
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = Uri.parse("package:$packageName")
        startActivity(intent)
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

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == REQUEST_MEDIA_PERMISSIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            pendingResult = null
        }
    }
}