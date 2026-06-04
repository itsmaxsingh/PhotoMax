/// Represents a photo album
class Album {
  final String id;
  final String name;
  String? coverAssetId;
  final DateTime createdAt;
  final bool isPrivate;

  Album({
    required this.id,
    required this.name,
    this.coverAssetId,
    DateTime? createdAt,
    this.isPrivate = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coverAssetId': coverAssetId,
      'createdAt': createdAt.toIso8601String(),
      'isPrivate': isPrivate,
    };
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      name: json['name'] as String,
      coverAssetId: json['coverAssetId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isPrivate: json['isPrivate'] as bool? ?? false,
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
