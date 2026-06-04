import 'package:flutter/material.dart';
import '../models/album.dart';
import '../utils/app_colors.dart';

/// Reusable album card for grid and list views
class AlbumCard extends StatelessWidget {
  final Album album;
  final int itemCount;
  final VoidCallback? onTap;
  final bool showPrivateBadge;

  const AlbumCard({
    super.key,
    required this.album,
    required this.itemCount,
    this.onTap,
    this.showPrivateBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                  // Cover image
                  if (album.coverAssetId != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.asset(
                        'assets/placeholder.jpg', // Replace with real cover
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image_outlined),
                          );
                        },
                      ),
                    )
                  else
                    // Default icon based on album type
                    Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          _getAlbumIcon(album.id),
                          size: 32,
                          color: AppColors.iconGray,
                        ),
                      ),
                    ),

                  // Private badge
                  if (showPrivateBadge)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
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
                    album.name,
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
                    '$itemCount items',
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
