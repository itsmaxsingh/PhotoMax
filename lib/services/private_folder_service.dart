import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PrivateFolderService {
  static const String _privateKey = 'private_folder_photos';
  static List<String> _privateAssetIds = [];

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final privateJson = prefs.getString(_privateKey);

    if (privateJson != null) {
      final List<dynamic> decoded = json.decode(privateJson);
      _privateAssetIds = List<String>.from(decoded);
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_privateKey, json.encode(_privateAssetIds));
  }

  static Future<void> addPhotos(List<String> assetIds) async {
    for (final id in assetIds) {
      if (!_privateAssetIds.contains(id)) {
        _privateAssetIds.add(id);
      }
    }
    await _save();
  }

  static Future<void> removePhotos(List<String> assetIds) async {
    _privateAssetIds.removeWhere((id) => assetIds.contains(id));
    await _save();
  }

  static bool isPrivate(String assetId) {
    return _privateAssetIds.contains(assetId);
  }

  static List<String> getPrivateAssetIds() {
    return List.from(_privateAssetIds);
  }

  static int getPrivateCount() {
    return _privateAssetIds.length;
  }
}
