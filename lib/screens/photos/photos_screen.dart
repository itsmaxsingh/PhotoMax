import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../models/album.dart';
import '../../services/album_photo_service.dart';
import '../../services/album_service.dart';
import '../../services/deleted_photos_service.dart';
import '../../services/private_folder_service.dart';
import '../../services/file_manager_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/date_helper.dart';
import '../settings/settings_screen.dart';
import 'photo_viewer_screen.dart';
import 'recently_deleted_screen.dart';

final Map<String, Uint8List> _globalVideoThumbnailCache = {};

enum ViewMode {
  allPhotos,
  cameraOnly,
}

class PhotosScreen extends StatefulWidget {
  final Function(bool)? onSelectionModeChanged;

  const PhotosScreen({
    super.key,
    this.onSelectionModeChanged,
  });

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  bool _permissionDenied = false;

  List<AssetEntity> _allAssets = [];
  Map<String, List<AssetEntity>> _groupedAssets = {};
  int _photoCount = 0;
  int _videoCount = 0;

  bool _isSelectionMode = false;
  final Set<String> _selectedAssetIds = {};

  ViewMode _currentViewMode = ViewMode.allPhotos;
  static const String _viewModeKey = 'photo_view_mode';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Wrap initialization in a try-catch to guarantee that even if local
    // data services crash, we still attempt to load the main UI and photos.
    try {
      await _initServices();
    } catch (e) {
      debugPrint('Critical service initialization failure: $e');
    }
    await _loadViewMode();
  }

  Future<void> _initServices() async {
    try {
      await AlbumService.init();
    } catch (e) {
      debugPrint('AlbumService failed to initialize: $e');
    }

    try {
      await AlbumPhotoService.init();
    } catch (e) {
      debugPrint('AlbumPhotoService failed to initialize: $e');
    }

    try {
      await DeletedPhotosService.init();
    } catch (e) {
      debugPrint('DeletedPhotosService failed to initialize: $e');
    }

    try {
      await PrivateFolderService.init();
    } catch (e) {
      debugPrint('PrivateFolderService failed to initialize: $e');
    }
  }

  Future<void> _loadViewMode() async {
    ViewMode loadedMode = ViewMode.allPhotos;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_viewModeKey);
      if (savedMode == 'camera') {
        loadedMode = ViewMode.cameraOnly;
      } else {
        loadedMode = ViewMode.allPhotos;
      }
    } catch (e) {
      debugPrint('Error loading view mode: $e');
    }

    if (mounted) {
      setState(() {
        _currentViewMode = loadedMode;
      });
    } else {
      _currentViewMode = loadedMode;
    }

    // Always fetch photos after view mode is loaded
    await _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _permissionDenied = false;
    });

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.hasAccess) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _permissionDenied = true;
          });
        }
        return;
      }

      // Fast-path: onlyAll: true fetches the root virtual folder instantly
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: _currentViewMode == ViewMode.allPhotos,
        filterOption: FilterOptionGroup(
          orders: [
            const OrderOption(type: OrderOptionType.createDate, asc: false)
          ],
        ),
      );

      if (albums.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _allAssets = [];
          });
        }
        return;
      }

      AssetPathEntity targetAlbum;
      if (_currentViewMode == ViewMode.cameraOnly) {
        targetAlbum = albums.firstWhere(
          (a) =>
              a.name.toLowerCase().contains('camera') ||
              a.name.toLowerCase().contains('dcim'),
          orElse: () => albums.first,
        );
      } else {
        targetAlbum =
            albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
      }

      final assetsRaw =
          await targetAlbum.getAssetListPaged(page: 0, size: 1000);

      // Safe filter with try-catch blocks to prevent helper-service crashes
      // from breaking photo loading.
      final assets = assetsRaw.where((asset) {
        try {
          final isDeleted = DeletedPhotosService.isPhotoDeleted(asset.id);
          final isPrivate = PrivateFolderService.isPrivate(asset.id);
          return !isDeleted && !isPrivate;
        } catch (e) {
          debugPrint('Error filtering individual asset ${asset.id}: $e');
          return true; // Safe fallback: display the item if check crashes
        }
      }).toList();

      final grouped = <String, List<AssetEntity>>{};
      for (final asset in assets) {
        final label = getDateGroup(asset.createDateTime);
        grouped.putIfAbsent(label, () => []).add(asset);
      }

      if (mounted) {
        setState(() {
          _allAssets = assets;
          _groupedAssets = grouped;
          _photoCount = assets.where((a) => a.type == AssetType.image).length;
          _videoCount = assets.where((a) => a.type == AssetType.video).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveViewMode(ViewMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeString = mode == ViewMode.cameraOnly ? 'camera' : 'all';
      await prefs.setString(_viewModeKey, modeString);

      setState(() {
        _currentViewMode = mode;
      });

      _loadPhotos();
    } catch (e) {
      debugPrint('Error saving view mode: $e');
    }
  }

  void _enterSelectionMode(AssetEntity asset) {
    setState(() {
      _isSelectionMode = true;
      _selectedAssetIds.add(asset.id);
    });
    widget.onSelectionModeChanged?.call(true);
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedAssetIds.clear();
    });
    widget.onSelectionModeChanged?.call(false);
  }

  void _toggleAssetSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssetIds.contains(asset.id)) {
        _selectedAssetIds.remove(asset.id);
        if (_selectedAssetIds.isEmpty) {
          _isSelectionMode = false;
          widget.onSelectionModeChanged?.call(false);
        }
      } else {
        _selectedAssetIds.add(asset.id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedAssetIds.addAll(_allAssets.map((e) => e.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedAssetIds.clear();
    });
  }

  void _showAddToAlbumSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddToAlbumSheet(
        selectedAssetIds: _selectedAssetIds.toList(),
        assets: _allAssets,
        onComplete: () {
          _exitSelectionMode();
          _loadPhotos();
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
        title: const Text('Delete Photos?'),
        content: Text(
            'These $selectedCount photo(s) will be moved to Recently Deleted for 30 days.'),
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
    await _loadPhotos();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedCount photo(s) moved to Recently Deleted'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const RecentlyDeletedScreen()))
                .then((_) {
              if (mounted) {
                _loadPhotos();
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _shareSelectedPhotos() async {
    final selectedAssets = _allAssets
        .where((asset) => _selectedAssetIds.contains(asset.id))
        .toList();
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

  void _showMenu() {
    showMenu<dynamic>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem<dynamic>(
          value: ViewMode.allPhotos,
          child: Row(
            children: [
              const Icon(Icons.photo_library_outlined,
                  size: 22, color: Colors.black87),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('All items', style: TextStyle(fontSize: 16))),
              if (_currentViewMode == ViewMode.allPhotos)
                const Icon(Icons.check, color: AppColors.accentBlue, size: 20),
            ],
          ),
        ),
        PopupMenuItem<dynamic>(
          value: ViewMode.cameraOnly,
          child: Row(
            children: [
              const Icon(Icons.camera_alt_outlined,
                  size: 22, color: Colors.blue),
              const SizedBox(width: 12),
              const Expanded(
                  child: Text('Camera album',
                      style: TextStyle(fontSize: 16, color: Colors.blue))),
              if (_currentViewMode == ViewMode.cameraOnly)
                const Icon(Icons.check, color: AppColors.accentBlue, size: 20),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<dynamic>(
          value: 'free',
          child: Text('Free up space', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<dynamic>(
          value: 'deleted',
          child: Text('Recently deleted items', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<dynamic>(
          value: 'settings',
          child: Text('Settings', style: TextStyle(fontSize: 16)),
        ),
      ],
    ).then((value) {
      if (value is ViewMode) {
        _saveViewMode(value);
      } else if (value == 'deleted') {
        if (!mounted) {
          return;
        }
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const RecentlyDeletedScreen())).then((_) {
          if (mounted) {
            _loadPhotos();
          }
        });
      } else if (value == 'settings') {
        if (!mounted) {
          return;
        }
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadPhotos,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isSelectionMode) _buildTopBar(),
                      if (!_isLoading &&
                          !_permissionDenied &&
                          !_isSelectionMode)
                        _buildPromoHeader(),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              bottom: _isSelectionMode ? 0 : -150,
              left: 0,
              right: 0,
              child: _buildSelectionBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget? _buildAppBar() {
    if (!_isSelectionMode) {
      return null;
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black, size: 28),
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        '${_selectedAssetIds.length} item${_selectedAssetIds.length != 1 ? 's' : ''} selected',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w400,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.checklist, color: Colors.black, size: 28),
          onPressed: () {
            if (_selectedAssetIds.length == _allAssets.length) {
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          const Text(
            'Photos',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, size: 28, color: Colors.black),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search coming soon!')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 28, color: Colors.black),
            onPressed: _showMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoHeader() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(
            '$_photoCount photos and $_videoCount videos',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Keep your photos and videos safe ',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            Text(
              'Turn on >',
              style: TextStyle(fontSize: 14, color: AppColors.accentBlue),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionDenied) {
      return _buildPermissionDeniedView();
    }
    if (_allAssets.isEmpty) {
      return _buildEmptyView();
    }
    return _buildPhotoGrid();
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 80, color: AppColors.iconGray.withValues(alpha: 0.5)),
            const SizedBox(height: 24),
            const Text('Photo Access Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('PhotoMax needs access to your photos to display them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPhotos,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_outlined,
              size: 80, color: AppColors.iconGray.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No photos found',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary)),
        ],
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                groupLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.0,
              ),
              itemCount: assetsInGroup.length,
              itemBuilder: (context, index) {
                final asset = assetsInGroup[index];
                final globalIndex = _allAssets.indexOf(asset);
                final isSelected = _selectedAssetIds.contains(asset.id);

                return _buildPhotoTile(asset, globalIndex, isSelected);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhotoTile(AssetEntity asset, int globalIndex, bool isSelected) {
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
                initialIndex: globalIndex,
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
            child: asset.type == AssetType.video
                ? _VideoFrameThumbnail(asset: asset)
                : AssetEntityImage(
                    asset,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(300),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: AppColors.surfaceGray,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
          ),
          if (asset.type == AssetType.video && !_isSelectionMode) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white70,
                size: 32,
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.videocam, color: Colors.white, size: 14),
                ],
              ),
            ),
          ],
          if (_isSelectionMode)
            Positioned(
              bottom: 6,
              right: 6,
              child: isSelected
                  ? Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentBlue,
                      ),
                      child: const Icon(Icons.check,
                          size: 14, color: Colors.white),
                    )
                  : Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.ios_share,
              label: 'Send',
              onPressed: _shareSelectedPhotos,
            ),
            _buildActionButton(
              icon: Icons.auto_awesome_outlined,
              label: 'Creativity',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Creativity features coming soon!')));
              },
            ),
            _buildActionButton(
              icon: Icons.add_box_outlined,
              label: 'Add to album',
              onPressed: _showAddToAlbumSheet,
            ),
            _buildActionButton(
              icon: Icons.delete_outline,
              label: 'Delete',
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color ?? Colors.black87),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: color ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoFrameThumbnail extends StatefulWidget {
  final AssetEntity asset;
  const _VideoFrameThumbnail({required this.asset});

  @override
  State<_VideoFrameThumbnail> createState() => _VideoFrameThumbnailState();
}

class _VideoFrameThumbnailState extends State<_VideoFrameThumbnail> {
  Uint8List? _thumbnailData;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (_globalVideoThumbnailCache.containsKey(widget.asset.id)) {
      if (mounted) {
        setState(() {
          _thumbnailData = _globalVideoThumbnailCache[widget.asset.id];
        });
      }
      return;
    }

    try {
      final file = await widget.asset.originFile ?? await widget.asset.file;

      if (file != null) {
        final uint8list = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 300,
          timeMs: 4000,
          quality: 100,
        );

        if (uint8list != null) {
          _globalVideoThumbnailCache[widget.asset.id] = uint8list;
          if (mounted) {
            setState(() {
              _thumbnailData = uint8list;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Frame extraction failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailData != null) {
      return Image.memory(
        _thumbnailData!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return AssetEntityImage(
      widget.asset,
      isOriginal: false,
      thumbnailSize: const ThumbnailSize.square(300),
      fit: BoxFit.cover,
    );
  }
}

class _AddToAlbumSheet extends StatefulWidget {
  final List<String> selectedAssetIds;
  final List<AssetEntity> assets;
  final VoidCallback onComplete;

  const _AddToAlbumSheet({
    required this.selectedAssetIds,
    required this.assets,
    required this.onComplete,
  });

  @override
  State<_AddToAlbumSheet> createState() => _AddToAlbumSheetState();
}

class _AddToAlbumSheetState extends State<_AddToAlbumSheet> {
  List<AssetPathEntity> _deviceFolders = [];
  Map<String, String> _deviceFolderAliases = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final hiddenIds = prefs.getStringList('hidden_device_folders') ?? [];
    final aliasString = prefs.getString('device_folder_aliases');
    if (aliasString != null) {
      _deviceFolderAliases = Map<String, String>.from(json.decode(aliasString));
    }

    final permission = await PhotoManager.requestPermissionExtend();
    if (permission.hasAccess) {
      final folders = await PhotoManager.getAssetPathList(
          type: RequestType.common, onlyAll: false);
      final filtered = <AssetPathEntity>[];
      for (final folder in folders) {
        if (hiddenIds.contains(folder.id)) {
          continue;
        }
        final count = await folder.assetCountAsync;
        if (count > 0 && !folder.isAll) {
          filtered.add(folder);
        }
      }
      filtered.sort((a, b) => a.name.compareTo(b.name));
      _deviceFolders = filtered;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewAlbumWithPhotos() async {
    Navigator.pop(context);
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Album'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
              labelText: 'Album Name', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await AlbumService.createAlbum(nameController.text.trim(),
          isPrivate: false);
      final newAlbum = AlbumService.getUserAlbums().last;
      await AlbumPhotoService.addPhotosToAlbum(
          newAlbum.id, widget.selectedAssetIds);
      if (widget.selectedAssetIds.isNotEmpty) {
        await AlbumService.updateAlbumCover(
            newAlbum.id, widget.selectedAssetIds.first);
      }
      if (!mounted) {
        return;
      }
      widget.onComplete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.selectedAssetIds.length} photo(s) added to ${newAlbum.name}')));
    }
  }

  Future<void> _addToUserAlbum(Album album) async {
    Navigator.pop(context);
    await AlbumPhotoService.addPhotosToAlbum(album.id, widget.selectedAssetIds);
    if (album.coverAssetId == null && widget.selectedAssetIds.isNotEmpty) {
      await AlbumService.updateAlbumCover(
          album.id, widget.selectedAssetIds.first);
    }
    if (!mounted) {
      return;
    }
    widget.onComplete();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${widget.selectedAssetIds.length} photo(s) added to ${album.name}')));
  }

  Future<void> _copyToDeviceFolder(AssetPathEntity targetFolder) async {
    final hasPermission =
        await FileManagerService.checkAndRequestManageStorage();
    if (!mounted) {
      return;
    }

    if (!hasPermission) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please grant "All files access" in Settings.')));
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Adding ${widget.selectedAssetIds.length} item(s)...'),
        duration: const Duration(seconds: 2)));

    try {
      final assets = <AssetEntity>[];
      for (final id in widget.selectedAssetIds) {
        final asset = await AssetEntity.fromId(id);
        if (asset != null) {
          assets.add(asset);
        }
      }

      String? destPath;
      final targetAssets =
          await targetFolder.getAssetListPaged(page: 0, size: 1);
      if (targetAssets.isNotEmpty) {
        final file = await targetAssets.first.file;
        if (file != null) {
          destPath = file.parent.path;
        }
      }

      destPath ??= await FileManagerService.getFolderPath(targetFolder.name);

      if (destPath == null) {
        throw Exception('Could not locate the destination folder');
      }

      int successCount = 0;
      for (final asset in assets) {
        try {
          final file = await asset.file;
          if (file != null) {
            final copied =
                await FileManagerService.copyFile(file.path, destPath);
            if (copied) {
              successCount++;
            }
          }
        } catch (e) {
          debugPrint('Error copying file: $e');
        }
      }

      if (!mounted) {
        return;
      }
      widget.onComplete();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$successCount item(s) added successfully')));
    } catch (e) {
      debugPrint('Error handling copy: $e');
    }
  }

  Future<void> _moveToPrivate() async {
    Navigator.pop(context);
    await PrivateFolderService.addPhotos(widget.selectedAssetIds);
    if (!mounted) {
      return;
    }
    widget.onComplete();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${widget.selectedAssetIds.length} item(s) moved to Private')));
  }

  @override
  Widget build(BuildContext context) {
    AssetEntity? firstSelectedAsset;
    if (widget.selectedAssetIds.isNotEmpty && widget.assets.isNotEmpty) {
      firstSelectedAsset = widget.assets
          .firstWhere((a) => a.id == widget.selectedAssetIds.first);
    }

    final userAlbums = AlbumService.getUserAlbums();
    final combinedList = <dynamic>[...userAlbums, ..._deviceFolders];

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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (firstSelectedAsset != null)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: AssetEntityImage(firstSelectedAsset,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(100),
                              fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.accentBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${widget.selectedAssetIds.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 12),
                const Text(
                  'Add items',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),
          ),
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
                  onTap: _createNewAlbumWithPhotos,
                ),
                const SizedBox(width: 12),
                _buildHorizontalActionItem(
                  icon: Icons.lock_outline,
                  label: 'Private\nalbum',
                  iconColor: AppColors.accentBlue,
                  onTap: _moveToPrivate,
                ),
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
              child: Text(
                'My albums',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7986CB)),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
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
                            child: FutureBuilder<AssetEntity?>(
                              future: () async {
                                final photoIds =
                                    AlbumPhotoService.getPhotosInAlbum(item.id);
                                if (photoIds.isNotEmpty) {
                                  return await AssetEntity.fromId(
                                      photoIds.first);
                                }
                                return null;
                              }(),
                              builder: (context, snapshot) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGray,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                                color: Colors.grey)),
                                  ),
                                );
                              },
                            ),
                          ),
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
                      onTap: () => _copyToDeviceFolder(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FutureBuilder<AssetEntity?>(
                              future: () async {
                                final assets = await item.getAssetListPaged(
                                    page: 0, size: 1);
                                return assets.isNotEmpty ? assets.first : null;
                              }(),
                              builder: (context, snapshot) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGray,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                                color: Colors.grey)),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          FutureBuilder<int>(
                              future: item.assetCountAsync,
                              builder: (context, snapshot) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        _deviceFolderAliases[item.id] ??
                                            item.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    Text('${snapshot.data ?? 0}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ],
                                );
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
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
