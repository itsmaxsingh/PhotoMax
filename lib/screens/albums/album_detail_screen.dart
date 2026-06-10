import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/album.dart';
import '../../services/album_photo_service.dart';
import '../../services/album_service.dart';
import '../../services/deleted_photos_service.dart';
import '../../utils/app_colors.dart';
import '../photos/photo_viewer_screen.dart';

class AlbumDetailScreen extends StatefulWidget {
  final Album album;

  const AlbumDetailScreen({
    super.key,
    required this.album,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _loadAlbumPhotos();
  }

  Future<void> _loadAlbumPhotos() async {
    setState(() {
      _isLoading = true;
    });

    final assetIds = AlbumPhotoService.getPhotosInAlbum(widget.album.id);

    if (assetIds.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

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

    if (mounted) {
      setState(() {
        _assets = loadedAssets;
        _isLoading = false;
      });
    }
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

  void _selectAll() {
    setState(() {
      _selectedAssetIds.addAll(_assets.map((e) => e.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedAssetIds.clear();
    });
  }

  Future<void> _shareSelectedPhotos() async {
    final selectedAssets =
        _assets.where((asset) => _selectedAssetIds.contains(asset.id)).toList();

    if (selectedAssets.isEmpty) {
      return;
    }

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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing photos: $e')),
      );
    }
  }

  Future<void> _removeSelectedPhotos() async {
    final selectedIds = _selectedAssetIds.toList();
    final selectedCount = selectedIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Album?'),
        content: Text(
          'Remove $selectedCount photo(s) from "${widget.album.name}"? Photos will not be deleted from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    for (final assetId in selectedIds) {
      await AlbumPhotoService.removePhotoFromAlbum(widget.album.id, assetId);
    }

    if (!mounted) {
      return;
    }

    _exitSelectionMode();
    await _loadAlbumPhotos();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$selectedCount photo(s) removed from album')),
    );
  }

  void _showAlbumMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename album'),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameAlbum();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete album',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteAlbum();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameAlbum() async {
    final controller = TextEditingController(text: widget.album.name);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Album'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Album Name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != widget.album.name) {
      await AlbumService.renameAlbum(widget.album.id, result);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Album renamed to "$result"')),
      );
    }
  }

  Future<void> _confirmDeleteAlbum() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Album?'),
          content: Text(
            'Are you sure you want to delete "${widget.album.name}"? All photos inside will be moved to Recently Deleted for 30 days.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final photoIds = AlbumPhotoService.getPhotosInAlbum(widget.album.id);
      if (photoIds.isNotEmpty) {
        await DeletedPhotosService.deletePhotos(photoIds);
      }

      await AlbumPhotoService.clearAlbum(widget.album.id);
      await AlbumService.deleteAlbum(widget.album.id);

      if (!mounted) {
        return;
      }

      Navigator.pop(
          context); // This safely pops the AlbumDetailScreen back to AlbumsScreen

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.album.name} and its photos deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
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
                      if (_selectedAssetIds.length == _assets.length) {
                        _deselectAll();
                      } else {
                        _selectAll();
                      }
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
                title: Text(
                  widget.album.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                iconTheme: const IconThemeData(color: AppColors.textPrimary),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: _showAlbumMenu,
                  ),
                ],
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
        bottomNavigationBar: _isSelectionMode ? _buildBottomBar() : null,
      ),
    );
  }

  Widget _buildContent() {
    if (_assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color: AppColors.iconGray.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No photos in this album',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add photos from the Photos tab',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
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
                ),
              ),
              if (_isSelectionMode)
                Container(
                  color: isSelected
                      ? AppColors.accentBlue.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.2),
                ),
              if (_isSelectionMode)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accentBlue : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.accentBlue : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
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
    );
  }

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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
              icon: Icons.remove_circle_outline,
              label: 'Remove',
              color: Colors.red,
              onPressed: _removeSelectedPhotos,
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
            Icon(icon, size: 28, color: color ?? AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
