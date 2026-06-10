import 'dart:convert';
import 'package:flutter/material.dart';
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
        assetId: json['assetId'] as String,
        deletionTimestamp: json['deletionTimestamp'] as int,
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawValue = prefs.get(_key);

      if (rawValue == null) {
        return [];
      }

      // If stored correctly as a List<String>
      if (rawValue is List) {
        final List<String> itemsJson = List<String>.from(rawValue);
        return itemsJson
            .map((e) =>
                DeletedItem.fromJson(json.decode(e) as Map<String, dynamic>))
            .toList();
      }

      // If corrupted or stored as a raw JSON String, parse defensively
      if (rawValue is String) {
        final decoded = json.decode(rawValue);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map<String, dynamic>) {
              return DeletedItem.fromJson(e);
            } else if (e is String) {
              return DeletedItem.fromJson(
                  json.decode(e) as Map<String, dynamic>);
            }
            throw Exception('Unknown element inside saved trash list');
          }).toList();
        }
      }

      // Fallback: If type is completely mismatched, remove key to prevent endless loop crash
      await prefs.remove(_key);
      return [];
    } catch (e) {
      debugPrint('Error decoding deleted items database: $e');
      // Hard reset the key to recover app execution
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
      } catch (_) {}
      return [];
    }
  }

  static Future<void> deletePhotos(List<String> assetIds) async {
    try {
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
    } catch (e) {
      debugPrint('Error writing deleted photos to database: $e');
    }
  }

  static Future<void> restorePhotos(List<String> assetIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = await getDeletedItems();

      items.removeWhere((item) => assetIds.contains(item.assetId));
      for (final id in assetIds) {
        _deletedIdsCache.remove(id);
      }

      await prefs.setStringList(
          _key, items.map((e) => json.encode(e.toJson())).toList());
    } catch (e) {
      debugPrint('Error restoring photos from database: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      _deletedIdsCache.clear();
    } catch (e) {
      debugPrint('Error clearing deleted database: $e');
    }
  }

  static bool isPhotoDeleted(String assetId) {
    return _deletedIdsCache.contains(assetId);
  }
}
