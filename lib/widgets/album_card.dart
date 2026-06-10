import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../models/album.dart';
import '../utils/app_colors.dart';

/// Reusable album card for grid and list views
class AlbumCard extends StatefulWidget {
  final Album album;
  final int itemCount;
  final VoidCallback? onTap;
  final bool showPrivateBadge;
  final AssetEntity? coverAsset; // ✅ NEW: Optional cover asset

  const AlbumCard({
    super.key,
    required this.album,
    required this.itemCount,
    this.onTap,
    this.showPrivateBadge = false,
    this.coverAsset, // ✅ NEW
  });

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  AssetEntity? _loadedCoverAsset;
  bool _isLoadingCover = false;

  @override
  void initState() {
    super.initState();
    // ✅ NEW: Load cover image if coverAssetId exists
    if (widget.coverAsset != null) {
      _loadedCoverAsset = widget.coverAsset;
    } else if (widget.album.coverAssetId != null) {
      _loadCoverAsset();
    }
  }

  // ✅ NEW: Load cover asset from ID
  Future<void> _loadCoverAsset() async {
    if (widget.album.coverAssetId == null) return;

    setState(() => _isLoadingCover = true);

    try {
      final asset = await AssetEntity.fromId(widget.album.coverAssetId!);
      if (mounted) {
        setState(() {
          _loadedCoverAsset = asset;
          _isLoadingCover = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading cover asset: $e');
      if (mounted) {
        setState(() => _isLoadingCover = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Cover image or icon
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ✅ UPDATED: Show real cover image or icon
                  _buildCoverImage(),

                  // Private badge
                  if (widget.showPrivateBadge)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.visibility_off,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Album info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.album.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.itemCount} items',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Build cover image widget
  Widget _buildCoverImage() {
    // Show loaded cover asset
    if (_loadedCoverAsset != null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16),
        ),
        child: AssetEntityImage(
          _loadedCoverAsset!,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize.square(200),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultIcon();
          },
        ),
      );
    }

    // Show loading indicator
    if (_isLoadingCover) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Default icon fallback
    return _buildDefaultIcon();
  }

  // ✅ NEW: Default icon when no cover image
  Widget _buildDefaultIcon() {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          _getAlbumIcon(widget.album.id),
          size: 32,
          color: AppColors.iconGray,
        ),
      ),
    );
  }

  /// Get appropriate icon for album type
  IconData _getAlbumIcon(String albumId) {
    switch (albumId) {
      case 'camera':
        return Icons.camera_alt_outlined;
      case 'screenshots':
        return Icons.screenshot_monitor_outlined;
      case 'all_photos':
        return Icons.photo_library_outlined;
      case 'videos':
        return Icons.videocam_outlined;
      default:
        return Icons.folder_outlined;
    }
  }
}
