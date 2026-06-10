/// Represents a photo album
class Album {
  final String id;
  final String name;
  String? coverAssetId;
  final DateTime createdAt;
  final bool isPrivate;
  final bool isPinned; // ✅ NEW
  final bool isHidden; // ✅ NEW

  Album({
    required this.id,
    required this.name,
    this.coverAssetId,
    DateTime? createdAt,
    this.isPrivate = false,
    this.isPinned = false, // ✅ NEW
    this.isHidden = false, // ✅ NEW
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coverAssetId': coverAssetId,
      'createdAt': createdAt.toIso8601String(),
      'isPrivate': isPrivate,
      'isPinned': isPinned, // ✅ NEW
      'isHidden': isHidden, // ✅ NEW
    };
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      name: json['name'] as String,
      coverAssetId: json['coverAssetId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isPrivate: json['isPrivate'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false, // ✅ NEW
      isHidden: json['isHidden'] as bool? ?? false, // ✅ NEW
    );
  }

  // ✅ NEW: Copy with method for updates
  Album copyWith({
    String? name,
    String? coverAssetId,
    bool? isPinned,
    bool? isHidden,
  }) {
    return Album(
      id: id,
      name: name ?? this.name,
      coverAssetId: coverAssetId ?? this.coverAssetId,
      createdAt: createdAt,
      isPrivate: isPrivate,
      isPinned: isPinned ?? this.isPinned,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  static final List<Album> systemAlbums = [
    Album(
      id: 'camera',
      name: 'Camera',
      coverAssetId: null,
      isPrivate: false,
    ),
    Album(
      id: 'screenshots',
      name: 'Screenshots',
      coverAssetId: null,
      isPrivate: false,
    ),
    Album(
      id: 'all_photos',
      name: 'All Photos',
      coverAssetId: null,
      isPrivate: false,
    ),
    Album(
      id: 'videos',
      name: 'Videos',
      coverAssetId: null,
      isPrivate: false,
    ),
  ];
}
