import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../services/deleted_photos_service.dart';
import '../../utils/app_colors.dart';
import 'photo_viewer_screen.dart';

/// Recently deleted photos screen (30-day trash bin)
class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  List<AssetEntity> _deletedAssets = [];
  Map<String, int> _deletionTimestamps = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _loadDeletedPhotos();
  }

  Future<void> _loadDeletedPhotos() async {
    setState(() => _isLoading = true);

    await DeletedPhotosService.init();
    final deletedMap = DeletedPhotosService.getAllDeletedPhotos();

    final List<AssetEntity> assets = [];
    for (final assetId in deletedMap.keys) {
      try {
        final asset = await AssetEntity.fromId(assetId);
        if (asset != null) {
          assets.add(asset);
        }
      } catch (e) {
        print('Error loading deleted asset $assetId: $e');
      }
    }

    setState(() {
      _deletedAssets = assets;
      _deletionTimestamps = deletedMap;
      _isLoading = false;
    });
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssetIds.contains(asset.id)) {
        _selectedAssetIds.remove(asset.id);
        if (_selectedAssetIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedAssetIds.add(asset.id);
      }
    });
  }

  void _enterSelectionMode(AssetEntity asset) {
    setState(() {
      _isSelectionMode = true;
      _selectedAssetIds.add(asset.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedAssetIds.clear();
    });
  }

  Future<void> _restoreSelected() async {
    await DeletedPhotosService.restorePhotos(_selectedAssetIds.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_selectedAssetIds.length} photo(s) restored')),
      );
      _exitSelectionMode();
      _loadDeletedPhotos();
    }
  }

  Future<void> _deleteSelectedPermanently() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text(
          'These ${_selectedAssetIds.length} photo(s) will be permanently deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final assetId in _selectedAssetIds) {
        await DeletedPhotosService.permanentlyDeletePhoto(assetId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photos permanently deleted')),
        );
        _exitSelectionMode();
        _loadDeletedPhotos();
      }
    }
  }

  Future<void> _emptyTrash() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text(
          'All photos in Recently Deleted will be permanently removed and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Empty Trash'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DeletedPhotosService.emptyTrash();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trash emptied')),
        );
        _loadDeletedPhotos();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: AppColors.accentBlue,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                '${_selectedAssetIds.length} selected',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              title: const Text(
                'Recently Deleted',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              iconTheme: const IconThemeData(color: AppColors.textPrimary),
              actions: [
                if (_deletedAssets.isNotEmpty)
                  TextButton(
                    onPressed: _emptyTrash,
                    child: const Text(
                      'Empty',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
      body: _buildBody(),
      bottomNavigationBar: _isSelectionMode ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_deletedAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              size: 80,
              color: AppColors.iconGray.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Recently Deleted Items',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Photos you delete will appear here for 30 days',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surfaceGray,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Photos will be permanently deleted after 30 days',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1.0,
            ),
            itemCount: _deletedAssets.length,
            itemBuilder: (context, index) {
              final asset = _deletedAssets[index];
              final isSelected = _selectedAssetIds.contains(asset.id);
              final daysRemaining =
                  DeletedPhotosService.getDaysRemaining(asset.id);

              return GestureDetector(
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(asset);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoViewerScreen(
                          assets: _deletedAssets,
                          initialIndex: index,
                        ),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  if (!_isSelectionMode) {
                    _enterSelectionMode(asset);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AssetEntityImage(
                      asset,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(300),
                      fit: BoxFit.cover,
                    ),

                    if (_isSelectionMode)
                      Container(
                        color: isSelected
                            ? AppColors.accentBlue.withOpacity(0.3)
                            : Colors.black.withOpacity(0.2),
                      ),

                    if (_isSelectionMode)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentBlue
                                : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentBlue
                                  : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.white)
                              : null,
                        ),
                      ),

                    // Days remaining badge
                    if (!_isSelectionMode)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$daysRemaining days',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.restore,
              label: 'Restore',
              onPressed: _restoreSelected,
            ),
            _buildActionButton(
              icon: Icons.delete_forever,
              label: 'Delete',
              color: Colors.red,
              onPressed: _deleteSelectedPermanently,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color ?? AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
