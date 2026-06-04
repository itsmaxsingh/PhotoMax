import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/album_photo_service.dart';
import '../../services/album_service.dart';
import '../../services/deleted_photos_service.dart';
import '../../services/private_folder_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/date_helper.dart';
import '../settings/settings_screen.dart';
import '../private/private_folder_screen.dart';
import '../private/pattern_unlock_screen.dart';
import '../private/pattern_setup_screen.dart';
import 'photo_viewer_screen.dart';
import 'recently_deleted_screen.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  bool _isLoading = true;
  bool _permissionDenied = false;
  List<AssetEntity> _allAssets = [];
  Map<String, List<AssetEntity>> _groupedAssets = {};
  int _photoCount = 0;
  int _videoCount = 0;
  bool _isSelectionMode = false;
  Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadPhotos();
  }

  Future<void> _initServices() async {
    await AlbumService.init();
    await AlbumPhotoService.init();
    await DeletedPhotosService.init();
    await PrivateFolderService.init();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false)
        ],
      ),
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
        _allAssets = [];
        _groupedAssets = {};
      });
      return;
    }

    final assetsRaw = await albums.first.getAssetListPaged(page: 0, size: 500);

    final assets = assetsRaw.where((asset) {
      if (DeletedPhotosService.isPhotoDeleted(asset.id)) return false;
      if (PrivateFolderService.isPrivate(asset.id)) return false;
      return true;
    }).toList();

    _photoCount = assets.where((e) => e.type == AssetType.image).length;
    _videoCount = assets.where((e) => e.type == AssetType.video).length;

    final grouped = <String, List<AssetEntity>>{};
    for (final asset in assets) {
      final label = getDateGroup(asset.createDateTime);
      grouped.putIfAbsent(label, () => []).add(asset);
    }

    setState(() {
      _allAssets = assets;
      _groupedAssets = grouped;
      _isLoading = false;
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

  void _toggleAssetSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssetIds.contains(asset.id)) {
        _selectedAssetIds.remove(asset.id);
        if (_selectedAssetIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedAssetIds.add(asset.id);
      }
    });
  }

  void _showAddToAlbumSheet() {
    final albums = AlbumService.getUserAlbums();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Add to Album',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Text('${_selectedAssetIds.length} selected',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: AppColors.accentBlue),
              ),
              title: const Text('Create New Album',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                final nameController = TextEditingController();
                final result = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Create Album'),
                    content: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Album Name',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                );

                if (result == true && nameController.text.trim().isNotEmpty) {
                  await AlbumService.createAlbum(nameController.text.trim(),
                      isPrivate: false);
                  final newAlbum = AlbumService.getUserAlbums().last;
                  await AlbumPhotoService.addPhotosToAlbum(
                    newAlbum.id,
                    _selectedAssetIds.toList(),
                  );
                  _exitSelectionMode();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${_selectedAssetIds.length} photo(s) added to ${newAlbum.name}'),
                    ));
                  }
                }
              },
            ),
            const Divider(height: 1),
            if (albums.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('No albums yet',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.textSecondary)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: albums.length,
                itemBuilder: (context, index) {
                  final album = albums[index];
                  final itemCount =
                      AlbumPhotoService.getAlbumPhotoCount(album.id);
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGray,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.folder_outlined,
                          color: AppColors.iconGray),
                    ),
                    title: Text(album.name),
                    subtitle: Text('$itemCount items'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await AlbumPhotoService.addPhotosToAlbum(
                        album.id,
                        _selectedAssetIds.toList(),
                      );
                      Navigator.pop(context);
                      _exitSelectionMode();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              '${_selectedAssetIds.length} photo(s) added to ${album.name}'),
                        ));
                      }
                    },
                  );
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _moveToPrivateFolder() async {
    final selectedIds = _selectedAssetIds.toList();
    final selectedCount = selectedIds.length;
    await PrivateFolderService.addPhotos(selectedIds);
    _exitSelectionMode();
    await _loadPhotos();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$selectedCount photo(s) moved to Private Folder')),
      );
    }
  }

  Future<void> _deleteSelectedPhotos() async {
    final selectedIds = _selectedAssetIds.toList();
    final selectedCount = selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photos?'),
        content: Text(
          'These $selectedCount photo(s) will be moved to Recently Deleted for 30 days.',
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

    if (confirm != true) return;
    await DeletedPhotosService.deletePhotos(selectedIds);
    _exitSelectionMode();
    await _loadPhotos();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$selectedCount photo(s) moved to Recently Deleted'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecentlyDeletedScreen()),
              ).then((_) => _loadPhotos());
            },
          ),
        ),
      );
    }
  }

  Future<void> _shareSelectedPhotos() async {
    final selectedAssets = _allAssets
        .where((asset) => _selectedAssetIds.contains(asset.id))
        .toList();
    if (selectedAssets.isEmpty) return;

    try {
      final files =
          await Future.wait(selectedAssets.map((asset) => asset.file));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    }
  }

  Future<void> _handlePrivateAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPattern = prefs.containsKey('pattern');
    if (!hasPattern) {
      final result = await Navigator.push(context,
          MaterialPageRoute(builder: (context) => const PatternSetupScreen()));
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pattern set! Now you can view private photos.')));
        _openPrivateFolder();
      }
    } else {
      _openPrivateFolder();
    }
  }

  Future<void> _openPrivateFolder() async {
    final unlocked = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const PatternUnlockScreen()));
    if (unlocked == true && mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PrivateFolderScreen()) // ✅ NO const here
          ).then((_) => _loadPhotos());
    }
  }

  void _showMenu() {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: const [
        PopupMenuItem(
          value: 'deleted',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Recently deleted'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == 'deleted') {
        Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RecentlyDeletedScreen()))
            .then((_) => _loadPhotos());
      } else if (value == 'settings') {
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
    });
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
              title: Text('${_selectedAssetIds.length} selected',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedAssetIds.length == _allAssets.length) {
                        _selectedAssetIds.clear();
                      } else {
                        _selectedAssetIds = _allAssets.map((e) => e.id).toSet();
                      }
                    });
                  },
                  child: Text(
                    _selectedAssetIds.length == _allAssets.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _handlePrivateAccess();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isSelectionMode) _buildTopBar(),
              if (!_isLoading && !_permissionDenied && !_isSelectionMode)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('$_photoCount photos and $_videoCount videos',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar() : null,
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          const Expanded(
              child: Text('Photos',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary))),
          IconButton(
            icon: const Icon(Icons.search, size: 26),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search coming soon!')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 26),
            onPressed: _showMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBottomBar() {
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
              icon: Icons.add_photo_alternate_outlined,
              label: 'Add to Album',
              onPressed: _showAddToAlbumSheet,
            ),
            _buildActionButton(
              icon: Icons.lock_outline,
              label: 'Move to Private',
              onPressed: _moveToPrivateFolder,
            ),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
              color: Colors.red,
              onPressed: _deleteSelectedPhotos,
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
            Icon(icon, size: 24, color: color ?? AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color ?? AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined,
                  size: 80, color: AppColors.iconGray.withOpacity(0.5)),
              const SizedBox(height: 24),
              const Text('Photo Access Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                  'PhotoMax needs access to your photos to display them.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadPhotos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }
    if (_allAssets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined,
                size: 80, color: AppColors.iconGray.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No photos found',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return _buildPhotoGrid();
  }

  Widget _buildPhotoGrid() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _groupedAssets.keys.length,
      itemBuilder: (context, groupIndex) {
        final groupLabel = _groupedAssets.keys.elementAt(groupIndex);
        final assetsInGroup = _groupedAssets[groupLabel]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(groupLabel,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.0,
              ),
              itemCount: assetsInGroup.length,
              itemBuilder: (context, index) {
                final asset = assetsInGroup[index];
                final globalIndex = _allAssets.indexOf(asset);
                final isSelected = _selectedAssetIds.contains(asset.id);
                return GestureDetector(
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleAssetSelection(asset);
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PhotoViewerScreen(
                                  assets: _allAssets,
                                  initialIndex: globalIndex)));
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) _enterSelectionMode(asset);
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: asset.id,
                        child: AssetEntityImage(asset,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize.square(300),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                    color: AppColors.surfaceGray,
                                    child: const Icon(Icons.broken_image))),
                      ),
                      if (_isSelectionMode)
                        Container(
                            color: isSelected
                                ? AppColors.accentBlue.withOpacity(0.3)
                                : Colors.black.withOpacity(0.2)),
                      if (_isSelectionMode)
                        Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.accentBlue
                                      : Colors.white,
                                  border: Border.all(
                                      color: isSelected
                                          ? AppColors.accentBlue
                                          : Colors.grey.shade400,
                                      width: 2)),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            )),
                      if (asset.type == AssetType.video && !_isSelectionMode)
                        Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.videocam,
                                    color: Colors.white, size: 14))),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
