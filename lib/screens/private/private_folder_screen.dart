import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/private_folder_service.dart';
import '../../utils/app_colors.dart';
import '../photos/photo_viewer_screen.dart';

class PrivateFolderScreen extends StatefulWidget {
  const PrivateFolderScreen({super.key});

  @override
  State<PrivateFolderScreen> createState() => _PrivateFolderScreenState();
}

class _PrivateFolderScreenState extends State<PrivateFolderScreen> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;

  // ✅ NEW: Selection mode
  bool _isSelectionMode = false;
  Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _loadPrivatePhotos();
  }

  Future<void> _loadPrivatePhotos() async {
    setState(() => _isLoading = true);

    await PrivateFolderService.init();
    final assetIds = PrivateFolderService.getPrivateAssetIds();

    final List<AssetEntity> loadedAssets = [];
    for (final id in assetIds) {
      try {
        final asset = await AssetEntity.fromId(id);
        if (asset != null) {
          loadedAssets.add(asset);
        }
      } catch (e) {
        debugPrint('Error loading asset $id: $e');
      }
    }

    setState(() {
      _assets = loadedAssets;
      _isLoading = false;
    });
  }

  // ✅ NEW: Enter selection mode
  void _enterSelectionMode(AssetEntity asset) {
    setState(() {
      _isSelectionMode = true;
      _selectedAssetIds.add(asset.id);
    });
  }

  // ✅ NEW: Exit selection mode
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedAssetIds.clear();
    });
  }

  // ✅ NEW: Toggle asset selection
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

  // ✅ NEW: Unhide selected photos
  Future<void> _unhideSelectedPhotos() async {
    final selectedIds = _selectedAssetIds.toList();
    final selectedCount = selectedIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unhide Photos?'),
        content: Text(
          'Move $selectedCount photo(s) back to your main gallery?\n\nThey will be visible to all apps again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unhide'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Remove from private folder
    await PrivateFolderService.removePhotos(selectedIds);

    if (!mounted) return;

    _exitSelectionMode();
    await _loadPrivatePhotos();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedCount photo(s) moved back to gallery'),
      ),
    );
  }

  // ✅ NEW: Share selected photos
  Future<void> _shareSelectedPhotos() async {
    final selectedAssets =
        _assets.where((asset) => _selectedAssetIds.contains(asset.id)).toList();

    if (selectedAssets.isEmpty) return;

    try {
      final files = await Future.wait(
        selectedAssets.map((asset) => asset.file),
      );

      final validFiles = files
          .whereType<dynamic>()
          .where((file) => file != null)
          .map((file) => XFile(file.path))
          .toList();

      if (validFiles.isNotEmpty) {
        await Share.shareXFiles(validFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing photos: $e')),
        );
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
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedAssetIds.length == _assets.length) {
                        _selectedAssetIds.clear();
                      } else {
                        _selectedAssetIds = _assets.map((e) => e.id).toSet();
                      }
                    });
                  },
                  child: Text(
                    _selectedAssetIds.length == _assets.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              title: const Text(
                'Private Folder',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: const IconThemeData(color: AppColors.textPrimary),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      bottomNavigationBar: _isSelectionMode ? _buildBottomBar() : null,
    );
  }

  Widget _buildContent() {
    if (_assets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: AppColors.iconGray.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Private Photos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Long-press photos and select "Move to Private" to hide them here',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info banner
        if (!_isSelectionMode)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.accentBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.accentBlue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'These photos are hidden',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_assets.length} ${_assets.length == 1 ? 'photo' : 'photos'} • Long-press to unhide',
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
            itemCount: _assets.length,
            itemBuilder: (context, index) {
              final asset = _assets[index];
              final isSelected = _selectedAssetIds.contains(asset.id);

              return GestureDetector(
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(asset);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoViewerScreen(
                          assets: _assets,
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
                    Hero(
                      tag: asset.id,
                      child: AssetEntityImage(
                        asset,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize.square(300),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.surfaceGray,
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      ),
                    ),

                    // Selection overlay
                    if (_isSelectionMode)
                      Container(
                        color: isSelected
                            ? AppColors.accentBlue.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.2),
                      ),

                    // Selection checkbox
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

                    // Lock badge (when NOT in selection mode)
                    if (!_isSelectionMode)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.lock,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),

                    // Video indicator
                    if (asset.type == AssetType.video && !_isSelectionMode)
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 14,
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

  // ✅ NEW: Bottom action bar
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              icon: Icons.share_outlined,
              label: 'Share',
              onPressed: _shareSelectedPhotos,
            ),
            _buildActionButton(
              icon: Icons.lock_open_outlined,
              label: 'Unhide',
              color: AppColors.accentBlue,
              onPressed: _unhideSelectedPhotos,
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
