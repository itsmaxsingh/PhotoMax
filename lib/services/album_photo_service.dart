import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Manages the relationship between albums and photos
class AlbumPhotoService {
  static const String _mappingKey = 'album_photo_mapping';

  // Map of albumId -> List of assetIds
  static Map<String, List<String>> _mapping = {};

  /// Initialize and load mappings
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final mappingJson = prefs.getString(_mappingKey);

    if (mappingJson != null) {
      final Map<String, dynamic> decoded = json.decode(mappingJson);
      _mapping = decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      );
    }
  }

  /// Save mappings to storage
  static Future<void> _saveMappings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mappingKey, json.encode(_mapping));
  }

  /// Add photo to album
  static Future<void> addPhotoToAlbum(String albumId, String assetId) async {
    if (!_mapping.containsKey(albumId)) {
      _mapping[albumId] = [];
    }

    if (!_mapping[albumId]!.contains(assetId)) {
      _mapping[albumId]!.add(assetId);
      await _saveMappings();
    }
  }

  /// Add multiple photos to album
  static Future<void> addPhotosToAlbum(
      String albumId, List<String> assetIds) async {
    if (!_mapping.containsKey(albumId)) {
      _mapping[albumId] = [];
    }

    for (final assetId in assetIds) {
      if (!_mapping[albumId]!.contains(assetId)) {
        _mapping[albumId]!.add(assetId);
      }
    }
    await _saveMappings();
  }

  /// Remove photo from album
  static Future<void> removePhotoFromAlbum(
      String albumId, String assetId) async {
    if (_mapping.containsKey(albumId)) {
      _mapping[albumId]!.remove(assetId);
      await _saveMappings();
    }
  }

  /// Get all photos in an album
  static List<String> getPhotosInAlbum(String albumId) {
    return _mapping[albumId] ?? [];
  }

  /// Get count of photos in album
  static int getAlbumPhotoCount(String albumId) {
    return _mapping[albumId]?.length ?? 0;
  }

  /// Check if photo is in album
  static bool isPhotoInAlbum(String albumId, String assetId) {
    return _mapping[albumId]?.contains(assetId) ?? false;
  }

  /// Remove all photos from album (when album is deleted)
  static Future<void> clearAlbum(String albumId) async {
    _mapping.remove(albumId);
    await _saveMappings();
  }

  /// Get all albums containing a specific photo
  static List<String> getAlbumsForPhoto(String assetId) {
    final List<String> albumIds = [];
    _mapping.forEach((albumId, assetIds) {
      if (assetIds.contains(assetId)) {
        albumIds.add(albumId);
      }
    });
    return albumIds;
  }
}
