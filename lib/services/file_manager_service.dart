import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // ✅ Required for debugPrint

class FileManagerService {
  static const platform = MethodChannel('com.photomax.app/file_manager');

  /// Check and request Manage External Storage permission
  static Future<bool> checkAndRequestManageStorage() async {
    try {
      final bool result = await platform.invokeMethod('requestManageStorage');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Permission error: ${e.message}');
      return false;
    }
  }

  /// Move file to another folder using native Android code
  static Future<bool> moveFile(
      String sourcePath, String destinationFolderPath) async {
    try {
      final bool? result = await platform.invokeMethod('moveFile', {
        'sourcePath': sourcePath,
        'destinationPath': destinationFolderPath,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Error moving file: ${e.message}');
      return false;
    }
  }

  /// Copy file to another folder
  static Future<bool> copyFile(
      String sourcePath, String destinationFolderPath) async {
    try {
      final bool? result = await platform.invokeMethod('copyFile', {
        'sourcePath': sourcePath,
        'destinationPath': destinationFolderPath,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Error copying file: ${e.message}');
      return false;
    }
  }

  /// Get folder path from folder name
  static Future<String?> getFolderPath(String folderName) async {
    try {
      final String? result = await platform.invokeMethod('getFolderPath', {
        'folderName': folderName,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error getting folder path: ${e.message}');
      return null;
    }
  }
}
