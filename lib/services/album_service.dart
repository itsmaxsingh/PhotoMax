import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/album.dart';

/// Manages album operations using SharedPreferences
class AlbumService {
  static const String _albumsKey = 'user_albums';
  static List<Album> _userAlbums = [];

  /// Initialize and load albums from storage
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final albumsJson = prefs.getString(_albumsKey);

    if (albumsJson != null) {
      final List<dynamic> decoded = json.decode(albumsJson);
      _userAlbums = decoded
          .map((e) => Album.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  /// Save albums to storage
  static Future<void> _saveAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final albumsJson = json.encode(_userAlbums.map((e) => e.toJson()).toList());
    await prefs.setString(_albumsKey, albumsJson);
  }

  /// Get all albums (system + user)
  static List<Album> getAllAlbums() {
    return [...Album.systemAlbums, ..._userAlbums];
  }

  /// Get user-created albums only
  static List<Album> getUserAlbums() {
    return _userAlbums;
  }

  /// Get album by ID
  static Album? getAlbumById(String id) {
    // Check system albums first
    try {
      return Album.systemAlbums.firstWhere((a) => a.id == id);
    } catch (e) {
      // Not found in system albums, check user albums
      try {
        return _userAlbums.firstWhere((a) => a.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  /// Create new album
  static Future<void> createAlbum(String name, {bool isPrivate = false}) async {
    final newAlbum = Album(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isPrivate: isPrivate,
    );
    _userAlbums.add(newAlbum);
    await _saveAlbums();
  }

  /// Delete album (only user albums, not system albums)
  static Future<void> deleteAlbum(String id) async {
    _userAlbums.removeWhere((album) => album.id == id);
    await _saveAlbums();
  }

  /// Update album cover image
  static Future<void> updateAlbumCover(String albumId, String assetId) async {
    final index = _userAlbums.indexWhere((a) => a.id == albumId);
    if (index != -1) {
      _userAlbums[index].coverAssetId = assetId;
      await _saveAlbums();
    }
  }

  /// Rename album
  static Future<void> renameAlbum(String albumId, String newName) async {
    final index = _userAlbums.indexWhere((a) => a.id == albumId);
    if (index != -1) {
      _userAlbums[index] = Album(
        id: _userAlbums[index].id,
        name: newName,
        coverAssetId: _userAlbums[index].coverAssetId,
        createdAt: _userAlbums[index].createdAt,
        isPrivate: _userAlbums[index].isPrivate,
      );
      await _saveAlbums();
    }
  }
}
