import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages recently deleted photos (30-day trash bin)
class DeletedPhotosService {
  static const String _deletedKey = 'deleted_photos';

  // assetId -> deleted timestamp
  static Map<String, int> _deletedPhotos = {};

  /// Initialize and load deleted photos
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final deletedJson = prefs.getString(_deletedKey);

    if (deletedJson != null) {
      final Map<String, dynamic> decoded = json.decode(deletedJson);
      _deletedPhotos = decoded.map(
        (key, value) => MapEntry(key, value as int),
      );
      await _cleanExpiredPhotos();
    }
  }

  /// Save deleted photos
  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deletedKey, json.encode(_deletedPhotos));
  }

  /// Move one photo to trash
  static Future<void> deletePhoto(String assetId) async {
    _deletedPhotos[assetId] = DateTime.now().millisecondsSinceEpoch;
    await _save();
  }

  /// Move multiple photos to trash
  static Future<void> deletePhotos(List<String> assetIds) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (final id in assetIds) {
      _deletedPhotos[id] = timestamp;
    }
    await _save();
  }

  /// Restore one photo
  static Future<void> restorePhoto(String assetId) async {
    _deletedPhotos.remove(assetId);
    await _save();
  }

  /// Restore multiple photos
  static Future<void> restorePhotos(List<String> assetIds) async {
    for (final id in assetIds) {
      _deletedPhotos.remove(id);
    }
    await _save();
  }

  /// Permanently remove from trash
  static Future<void> permanentlyDeletePhoto(String assetId) async {
    _deletedPhotos.remove(assetId);
    await _save();
  }

  /// Empty trash
  static Future<void> emptyTrash() async {
    _deletedPhotos.clear();
    await _save();
  }

  /// Get all deleted photos
  static Map<String, int> getAllDeletedPhotos() {
    return Map.from(_deletedPhotos);
  }

  /// Check if photo is deleted
  static bool isPhotoDeleted(String assetId) {
    return _deletedPhotos.containsKey(assetId);
  }

  /// Days remaining before auto removal
  static int getDaysRemaining(String assetId) {
    if (!_deletedPhotos.containsKey(assetId)) return 0;

    final deletedTime =
        DateTime.fromMillisecondsSinceEpoch(_deletedPhotos[assetId]!);
    final now = DateTime.now();
    final difference = now.difference(deletedTime).inDays;

    return 30 - difference;
  }

  /// Remove expired items older than 30 days
  static Future<void> _cleanExpiredPhotos() async {
    final now = DateTime.now();
    final expiredIds = <String>[];

    _deletedPhotos.forEach((assetId, timestamp) {
      final deletedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final daysPassed = now.difference(deletedTime).inDays;
      if (daysPassed >= 30) {
        expiredIds.add(assetId);
      }
    });

    for (final id in expiredIds) {
      _deletedPhotos.remove(id);
    }

    if (expiredIds.isNotEmpty) {
      await _save();
    }
  }

  static int getDeletedCount() {
    return _deletedPhotos.length;
  }
}
