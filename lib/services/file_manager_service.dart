import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class FileManagerService {
  static const platform = MethodChannel('com.photomax.app/file_manager');

  /// Check and request Manage External Storage permission
  static Future<bool> checkAndRequestManageStorage() async {
    try {
      debugPrint('🔐 Requesting storage permission...');
      final bool result = await platform.invokeMethod('requestManageStorage');
      debugPrint('🔐 Permission result: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('❌ Permission error: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unknown permission error: $e');
      return false;
    }
  }

  /// Move file to another folder using native Android code
  static Future<bool> moveFile(
      String sourcePath, String destinationFolderPath) async {
    try {
      // Validate paths before sending to native code
      if (sourcePath.isEmpty || destinationFolderPath.isEmpty) {
        debugPrint(
            '❌ Invalid paths: source=$sourcePath, dest=$destinationFolderPath');
        return false;
      }

      debugPrint('📂 Moving file from: $sourcePath');
      debugPrint('📂 Moving file to: $destinationFolderPath');

      final bool? result = await platform.invokeMethod('moveFile', {
        'sourcePath': sourcePath,
        'destinationPath': destinationFolderPath,
      });

      if (result == true) {
        debugPrint('✅ File moved successfully');
      } else {
        debugPrint('❌ File move failed');
      }

      return result == true;
    } on PlatformException catch (e) {
      debugPrint('❌ Platform error moving file: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unknown error moving file: $e');
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
      debugPrint('❌ Error copying file: ${e.message}');
      return false;
    }
  }

  /// Get folder path from folder name
  static Future<String?> getFolderPath(String folderName) async {
    try {
      debugPrint('🔍 Getting path for folder: $folderName');
      final String? result = await platform.invokeMethod('getFolderPath', {
        'folderName': folderName,
      });
      debugPrint('📂 Resolved path: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('❌ Error getting folder path: ${e.message}');
      return null;
    }
  }
}
