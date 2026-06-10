import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/album.dart';
import '../../services/album_photo_service.dart';
import '../../services/album_service.dart';
import '../../services/deleted_photos_service.dart';
import '../../services/private_folder_service.dart';
import '../../services/file_manager_service.dart';
import '../../utils/app_colors.dart';
import '../photos/photo_viewer_screen.dart';

class DeviceFolderDetailScreen extends StatefulWidget {
  final AssetPathEntity folder;
  final String? titleOverride;

  const DeviceFolderDetailScreen({
    super.key,
    required this.folder,
    this.titleOverride,
  });

  @override
  State<DeviceFolderDetailScreen> createState() =>
      _DeviceFolderDetailScreenState();
}

class _DeviceFolderDetailScreenState extends State<DeviceFolderDetailScreen> {
  List<AssetEntity> _assets = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _loadFolderContents();
  }

  Future<void> _loadFolderContents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final assetsRaw = await widget.folder.getAssetListPaged(
        page: 0,
        size: 1000,
      );

      final assets = assetsRaw.where((asset) {
        if (DeletedPhotosService.isPhotoDeleted(asset.id)) {
          return false;
        }
        if (PrivateFolderService.isPrivate(asset.id)) {
          return false;
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _assets = assets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
    }
  }

  void _showMoveToFolderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _MoveToFolderSheet(
        selectedAssetIds: _selectedAssetIds.toList(),
        currentFolderId: widget.folder.id,
        assets: _assets,
        onMoveComplete: () {
          _exitSelectionMode();
          _loadFolderContents();
        },
      ),
    );
  }

  Future<void> _deleteSelectedPhotos() async {
    final selectedIds = _selectedAssetIds.toList();
    final selectedCount = selectedIds.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items?'),
        content: Text(
            'These $selectedCount item(s) will be moved to Recently Deleted for 30 days.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await DeletedPhotosService.deletePhotos(selectedIds);

    if (!mounted) {
      return;
    }

    _exitSelectionMode();
    await _loadFolderContents();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$selectedCount item(s) moved to Recently Deleted')));
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
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
        bottomNavigationBar: _isSelectionMode ? _buildBottomBar() : null,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black, size: 28),
            onPressed: _exitSelectionMode),
        title: Text(
            '${_selectedAssetIds.length} item${_selectedAssetIds.length != 1 ? 's' : ''} selected',
            style: const TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w400)),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist, color: Colors.black, size: 28),
            onPressed: () {
              if (_selectedAssetIds.length == _assets.length) {
                _deselectAll();
              } else {
                _selectAll();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      title: Text(widget.titleOverride ?? widget.folder.name,
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    );
  }

  Widget _buildContent() {
    if (_assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 80, color: AppColors.iconGray.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Folder is empty',
                style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isSelectionMode)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Text('${_assets.length} items',
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.0),
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
                                assets: _assets, initialIndex: index)));
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
                        child: AssetEntityImage(asset,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize.square(300),
                            fit: BoxFit.cover)),
                    if (_isSelectionMode)
                      Container(
                          color: isSelected
                              ? AppColors.accentBlue.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.2)),
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
                                      width: 2)),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null)),
                    if (asset.type == AssetType.video && !_isSelectionMode)
                      Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam,
                                        color: Colors.white, size: 14)
                                  ]))),
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
      decoration: const BoxDecoration(color: Colors.white),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
                icon: Icons.ios_share,
                label: 'Send',
                onPressed: _shareSelectedPhotos),
            _buildActionButton(
                icon: Icons.drive_file_move_outlined,
                label: 'Move',
                onPressed: _showMoveToFolderSheet),
            _buildActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onPressed: _deleteSelectedPhotos),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed,
      Color? color}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 26, color: color ?? Colors.black87),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: color ?? Colors.black87))
        ]),
      ),
    );
  }
}

class _MoveToFolderSheet extends StatefulWidget {
  final List<String> selectedAssetIds;
  final String currentFolderId;
  final List<AssetEntity> assets;
  final VoidCallback onMoveComplete;

  const _MoveToFolderSheet({
    required this.selectedAssetIds,
    required this.currentFolderId,
    required this.assets,
    required this.onMoveComplete,
  });

  @override
  State<_MoveToFolderSheet> createState() => _MoveToFolderSheetState();
}

class _MoveToFolderSheetState extends State<_MoveToFolderSheet> {
  List<AssetPathEntity> _allFolders = [];
  bool _isLoading = true;
  bool _isMoving = false;

  @override
  void initState() {
    super.initState();
    _loadAllFolders();
  }

  Future<void> _loadAllFolders() async {
    setState(() {
      _isLoading = true;
    });
    final permission = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    if (!permission.hasAccess) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final folders = await PhotoManager.getAssetPathList(
          type: RequestType.common, onlyAll: false);
      final filteredFolders = <AssetPathEntity>[];
      for (final folder in folders) {
        if (folder.id == widget.currentFolderId) continue;
        final count = await folder.assetCountAsync;
        if (count > 0 && !folder.isAll) filteredFolders.add(folder);
      }
      filteredFolders.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        _allFolders = filteredFolders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _moveToDeviceFolder(AssetPathEntity targetFolder) async {
    setState(() {
      _isMoving = true;
    });

    final hasPermission =
        await FileManagerService.checkAndRequestManageStorage();

    if (!mounted) return;
    if (!hasPermission) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please grant "All files access" in Settings.')));
      return;
    }

    try {
      final assets = <AssetEntity>[];
      for (final id in widget.selectedAssetIds) {
        final asset = await AssetEntity.fromId(id);
        if (asset != null) assets.add(asset);
      }

      // Get destination path
      String? destPath;
      final targetAssets =
          await targetFolder.getAssetListPaged(page: 0, size: 1);
      if (targetAssets.isNotEmpty) {
        final file = await targetAssets.first.file;
        if (file != null) destPath = file.parent.path;
      }

      destPath ??= await FileManagerService.getFolderPath(targetFolder.name);

      if (destPath == null || destPath.isEmpty) {
        throw Exception('Could not find destination folder');
      }

      int successCount = 0;
      for (final asset in assets) {
        try {
          final file = await asset.file;
          if (file != null) {
            final moved =
                await FileManagerService.moveFile(file.path, destPath);
            if (moved) successCount++;
          }
        } catch (e) {
          debugPrint('Error moving file: $e');
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onMoveComplete();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$successCount item(s) moved successfully')));
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        setState(() {
          _isMoving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _addToUserAlbum(Album album) async {
    setState(() {
      _isMoving = true;
    });
    await AlbumPhotoService.addPhotosToAlbum(album.id, widget.selectedAssetIds);
    if (album.coverAssetId == null && widget.selectedAssetIds.isNotEmpty) {
      await AlbumService.updateAlbumCover(
          album.id, widget.selectedAssetIds.first);
    }
    if (!mounted) return;
    Navigator.pop(context);
    widget.onMoveComplete();
  }

  Future<void> _moveToPrivate() async {
    setState(() {
      _isMoving = true;
    });
    await PrivateFolderService.addPhotos(widget.selectedAssetIds);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onMoveComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_isMoving) {
      return const SafeArea(
          child: SizedBox(
              height: 200,
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Moving items...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))
              ]))));
    }

    AssetEntity? firstSelectedAsset;
    if (widget.selectedAssetIds.isNotEmpty && widget.assets.isNotEmpty) {
      firstSelectedAsset = widget.assets
          .firstWhere((a) => a.id == widget.selectedAssetIds.first);
    }

    final userAlbums = AlbumService.getUserAlbums();
    final combinedList = <dynamic>[...userAlbums, ..._allFolders];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (firstSelectedAsset != null)
                  Stack(clipBehavior: Clip.none, children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                            width: 30,
                            height: 30,
                            child: AssetEntityImage(firstSelectedAsset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(100),
                                fit: BoxFit.cover))),
                    Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                                color: AppColors.accentBlue,
                                shape: BoxShape.circle),
                            child: Text('${widget.selectedAssetIds.length}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold))))
                  ]),
                const SizedBox(width: 12),
                const Text('Add items',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black))
              ])),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildHorizontalActionItem(
                  icon: Icons.add,
                  label: 'Create an\nalbum',
                  iconColor: AppColors.accentBlue,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Please create an album from the Albums tab first.')));
                  },
                ),
                const SizedBox(width: 12),
                _buildHorizontalActionItem(
                    icon: Icons.lock_outline,
                    label: 'Private\nalbum',
                    iconColor: AppColors.accentBlue,
                    onTap: _moveToPrivate),
              ],
            ),
          ),
          if (_isLoading)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator()))
          else if (combinedList.isNotEmpty) ...[
            const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text('My albums',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7986CB)))),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.8),
                itemCount: combinedList.length,
                itemBuilder: (context, index) {
                  final item = combinedList[index];
                  if (item is Album) {
                    final itemCount =
                        AlbumPhotoService.getAlbumPhotoCount(item.id);
                    return GestureDetector(
                      onTap: () => _addToUserAlbum(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child:
                                  FutureBuilder<AssetEntity?>(future: () async {
                            final photoIds =
                                AlbumPhotoService.getPhotosInAlbum(item.id);
                            if (photoIds.isNotEmpty)
                              return await AssetEntity.fromId(photoIds.first);
                            return null;
                          }(), builder: (context, snapshot) {
                            return Container(
                                decoration: BoxDecoration(
                                    color: AppColors.surfaceGray,
                                    borderRadius: BorderRadius.circular(12)),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: snapshot.data != null
                                        ? AssetEntityImage(snapshot.data!,
                                            isOriginal: false,
                                            thumbnailSize:
                                                const ThumbnailSize.square(200),
                                            fit: BoxFit.cover)
                                        : const Center(
                                            child: Icon(Icons.photo_album,
                                                color: Colors.grey))));
                          })),
                          const SizedBox(height: 6),
                          Text(item.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('$itemCount',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    );
                  } else if (item is AssetPathEntity) {
                    return GestureDetector(
                      onTap: () => _moveToDeviceFolder(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child:
                                  FutureBuilder<AssetEntity?>(future: () async {
                            final assets =
                                await item.getAssetListPaged(page: 0, size: 1);
                            return assets.isNotEmpty ? assets.first : null;
                          }(), builder: (context, snapshot) {
                            return Container(
                                decoration: BoxDecoration(
                                    color: AppColors.surfaceGray,
                                    borderRadius: BorderRadius.circular(12)),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: snapshot.data != null
                                        ? AssetEntityImage(snapshot.data!,
                                            isOriginal: false,
                                            thumbnailSize:
                                                const ThumbnailSize.square(200),
                                            fit: BoxFit.cover)
                                        : const Center(
                                            child: Icon(Icons.folder,
                                                color: Colors.grey))));
                          })),
                          const SizedBox(height: 6),
                          FutureBuilder<int>(
                              future: item.assetCountAsync,
                              builder: (context, snapshot) {
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text('${snapshot.data ?? 0}',
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey))
                                    ]);
                              })
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHorizontalActionItem(
      {required IconData icon,
      required String label,
      required Color iconColor,
      required VoidCallback onTap}) {
    return GestureDetector(
        onTap: onTap,
        child: SizedBox(
            width: 80,
            child: Column(children: [
              Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: iconColor, size: 32)),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 2)
            ])));
  }
}
