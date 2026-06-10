import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DeletedItem {
  final String assetId;
  final int deletionTimestamp;

  DeletedItem({required this.assetId, required this.deletionTimestamp});

  // Automatically calculates the 30-day countdown timer
  int get daysRemaining {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - deletionTimestamp;
    final daysPassed = diff ~/ (1000 * 60 * 60 * 24);
    return (30 - daysPassed).clamp(0, 30);
  }

  Map<String, dynamic> toJson() => {
        'assetId': assetId,
        'deletionTimestamp': deletionTimestamp,
      };

  factory DeletedItem.fromJson(Map<String, dynamic> json) => DeletedItem(
        assetId: json['assetId'],
        deletionTimestamp: json['deletionTimestamp'],
      );
}

class DeletedPhotosService {
  static const String _key = 'deleted_photos';
  static final Set<String> _deletedIdsCache = {};

  static Future<void> init() async {
    await _loadCache();
  }

  static Future<void> _loadCache() async {
    final items = await getDeletedItems();
    _deletedIdsCache.clear();
    for (final item in items) {
      _deletedIdsCache.add(item.assetId);
    }
  }

  static Future<List<DeletedItem>> getDeletedItems() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> itemsJson = prefs.getStringList(_key) ?? [];
    return itemsJson.map((e) => DeletedItem.fromJson(json.decode(e))).toList();
  }

  static Future<void> deletePhotos(List<String> assetIds) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getDeletedItems();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final id in assetIds) {
      if (!items.any((item) => item.assetId == id)) {
        items.add(DeletedItem(assetId: id, deletionTimestamp: now));
        _deletedIdsCache.add(id);
      }
    }

    await prefs.setStringList(
        _key, items.map((e) => json.encode(e.toJson())).toList());
  }

  static Future<void> restorePhotos(List<String> assetIds) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await getDeletedItems();

    items.removeWhere((item) => assetIds.contains(item.assetId));
    for (final id in assetIds) {
      _deletedIdsCache.remove(id);
    }

    await prefs.setStringList(
        _key, items.map((e) => json.encode(e.toJson())).toList());
  }

  static bool isPhotoDeleted(String assetId) {
    return _deletedIdsCache.contains(assetId);
  }
}
