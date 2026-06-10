import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/album.dart';

class AlbumService {
  static const String _albumsKey = 'user_albums';
  static List<Album> _userAlbums = [];

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

  static Future<void> _saveAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final albumsJson = json.encode(_userAlbums.map((e) => e.toJson()).toList());
    await prefs.setString(_albumsKey, albumsJson);
  }

  // ─────────────────────────────────────────
  // GET METHODS
  // ─────────────────────────────────────────

  static List<Album> getAllAlbums() {
    return [...Album.systemAlbums, ..._userAlbums];
  }

  static List<Album> getUserAlbums() {
    return List.from(_userAlbums);
  }

  // ✅ NEW: Returns only visible (not hidden) user albums
  static List<Album> getVisibleUserAlbums() {
    return _userAlbums
        .where((album) => !album.isHidden && !album.isPrivate)
        .toList();
  }

  // ✅ NEW: Returns only hidden albums
  static List<Album> getHiddenAlbums() {
    return _userAlbums.where((album) => album.isHidden).toList();
  }

  // ✅ NEW: Returns pinned user albums
  static List<Album> getPinnedAlbums() {
    return _userAlbums.where((album) => album.isPinned).toList();
  }

  static Album? getAlbumById(String id) {
    try {
      return Album.systemAlbums.firstWhere((a) => a.id == id);
    } catch (_) {
      try {
        return _userAlbums.firstWhere((a) => a.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  // ─────────────────────────────────────────
  // CREATE / DELETE
  // ─────────────────────────────────────────

  static Future<void> createAlbum(
    String name, {
    bool isPrivate = false,
  }) async {
    final newAlbum = Album(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      isPrivate: isPrivate,
    );
    _userAlbums.add(newAlbum);
    await _saveAlbums();
  }

  static Future<void> deleteAlbum(String id) async {
    _userAlbums.removeWhere((album) => album.id == id);
    await _saveAlbums();
  }

  // ─────────────────────────────────────────
  // UPDATE METHODS
  // ─────────────────────────────────────────

  static Future<void> updateAlbumCover(
    String albumId,
    String assetId,
  ) async {
    final index = _userAlbums.indexWhere((a) => a.id == albumId);
    if (index != -1) {
      _userAlbums[index] = _userAlbums[index].copyWith(
        coverAssetId: assetId,
      );
      await _saveAlbums();
    }
  }

  // ✅ NEW: Generic update method
  static Future<void> updateAlbum(
    String albumId, {
    String? name,
    String? coverAssetId,
    bool? isPinned,
    bool? isHidden,
  }) async {
    final index = _userAlbums.indexWhere((a) => a.id == albumId);
    if (index != -1) {
      _userAlbums[index] = _userAlbums[index].copyWith(
        name: name,
        coverAssetId: coverAssetId,
        isPinned: isPinned,
        isHidden: isHidden,
      );
      await _saveAlbums();
    }
  }

  // ✅ NEW: Rename album
  static Future<void> renameAlbum(String albumId, String newName) async {
    await updateAlbum(albumId, name: newName);
  }

  // ✅ NEW: Toggle pin status
  static Future<void> togglePin(String albumId) async {
    final index = _userAlbums.indexWhere((a) => a.id == albumId);
    if (index != -1) {
      final currentPinned = _userAlbums[index].isPinned;
      _userAlbums[index] = _userAlbums[index].copyWith(
        isPinned: !currentPinned,
      );
      await _saveAlbums();
    }
  }

  // ✅ NEW: Toggle hide status
  static Future<void> toggleHide(String albumId) async {
    final index = _userAlbums.indexWhere((a) => a.id == albumId);
    if (index != -1) {
      final currentHidden = _userAlbums[index].isHidden;
      _userAlbums[index] = _userAlbums[index].copyWith(
        isHidden: !currentHidden,
      );
      await _saveAlbums();
    }
  }
}
