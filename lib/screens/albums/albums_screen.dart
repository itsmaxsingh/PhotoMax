import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:convert';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/album.dart';
import '../../services/album_photo_service.dart';
import '../../services/album_service.dart';
import '../../services/deleted_photos_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/album_card.dart';
import '../photos/recently_deleted_screen.dart';
import '../private/private_folder_screen.dart';
import '../private/pattern_setup_screen.dart';
import '../private/pattern_unlock_screen.dart';
import '../settings/settings_screen.dart';
import 'album_detail_screen.dart';
import 'device_folder_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isLoading = true;
  Map<String, int> _systemAlbumCounts = {};
  List<AssetPathEntity> _allDeviceFolders = [];
  List<String> _pinnedDeviceFolderIds = [];

  Map<String, String> _deviceFolderAliases = {};

  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _isLoading = true;
    });

    await AlbumService.init();
    await AlbumPhotoService.init();

    final prefs = await SharedPreferences.getInstance();
    _pinnedDeviceFolderIds = prefs.getStringList('pinned_device_folders') ?? [];

    final aliasString = prefs.getString('device_folder_aliases');
    if (aliasString != null) {
      _deviceFolderAliases = Map<String, String>.from(json.decode(aliasString));
    }

    await _loadSystemAlbumCounts();
    await _loadAllDeviceFolders();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSystemAlbumCounts() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      return;
    }

    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );

      final counts = <String, int>{};

      for (final album in albums) {
        final albumName = album.name.toLowerCase();
        final assetCount = await album.assetCountAsync;

        if (albumName.contains('camera') || albumName.contains('dcim')) {
          counts['camera'] = assetCount;
        } else if (albumName.contains('screenshot')) {
          counts['screenshots'] = assetCount;
        } else if (albumName.contains('video')) {
          counts['videos'] = assetCount;
        }
      }

      if (albums.isNotEmpty) {
        final allAlbum = albums.firstWhere(
          (a) => a.isAll,
          orElse: () => albums.first,
        );
        counts['all_photos'] = await allAlbum.assetCountAsync;
      }

      if (mounted) {
        setState(() {
          _systemAlbumCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _loadAllDeviceFolders() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      return;
    }

    try {
      final folders = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: false,
      );

      final prefs = await SharedPreferences.getInstance();
      final hiddenDeviceFolderIds =
          prefs.getStringList('hidden_device_folders') ?? [];

      final filteredFolders = <AssetPathEntity>[];

      for (final folder in folders) {
        if (hiddenDeviceFolderIds.contains(folder.id)) {
          continue;
        }

        final count = await folder.assetCountAsync;
        if (count == 0) {
          continue;
        }
        if (folder.isAll) {
          continue;
        }

        final folderName = folder.name.toLowerCase();
        if (folderName.contains('camera') ||
            folderName.contains('dcim') ||
            folderName.contains('screenshot') ||
            folderName.contains('video')) {
          continue;
        }

        filteredFolders.add(folder);
      }

      filteredFolders.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _allDeviceFolders = filteredFolders;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<AssetEntity?> _getFirstAssetFromFolder(AssetPathEntity folder) async {
    try {
      final assets = await folder.getAssetListPaged(page: 0, size: 1);
      if (assets.isNotEmpty) {
        return assets.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _openDeviceFolder(AssetPathEntity folder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceFolderDetailScreen(
          folder: folder,
          titleOverride: _deviceFolderAliases[folder.id] ?? folder.name,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    _loadAlbums();
  }

  Future<void> _showCreateAlbumDialog() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Album'),
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
      if (!mounted) {
        return;
      }
      await _loadAlbums();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Album "${nameController.text.trim()}" created!')),
      );
    }
  }

  Future<void> _handlePrivateAccess() async {
    final prefs =
        await SharedPreferences.getInstance(); // <-- This is the async gap!

    if (!prefs.containsKey('pattern')) {
      // ✅ FIXED: Check if we are still mounted BEFORE pushing the new screen
      if (!mounted) {
        return;
      }

      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PatternSetupScreen()),
      );

      if (!mounted) {
        return;
      }

      if (result == true) {
        _openPrivateFolder();
      }
    } else {
      _openPrivateFolder();
    }
  }

  Future<void> _openPrivateFolder() async {
    final unlocked = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PatternUnlockScreen()),
    );
    if (!mounted) {
      return;
    }
    if (unlocked == true) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivateFolderScreen()),
      );
      if (!mounted) {
        return;
      }
      _loadAlbums();
    }
  }

  Future<void> _openSystemAlbum(Album album) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.hasAccess) {
      return;
    }

    try {
      late List<AssetPathEntity> folders;
      AssetPathEntity? targetFolder;

      if (album.id == 'all_photos') {
        folders = await PhotoManager.getAssetPathList(
            type: RequestType.common, onlyAll: true);
        if (folders.isNotEmpty) {
          targetFolder = folders.first;
        }
      } else if (album.id == 'videos') {
        folders = await PhotoManager.getAssetPathList(
            type: RequestType.video, onlyAll: true);
        if (folders.isNotEmpty) {
          targetFolder = folders.first;
        }
      } else {
        folders = await PhotoManager.getAssetPathList(
            type: RequestType.common, onlyAll: false);
        for (final folder in folders) {
          final name = folder.name.toLowerCase();
          if (album.id == 'camera' &&
              (name.contains('camera') || name.contains('dcim'))) {
            targetFolder = folder;
            break;
          }
          if (album.id == 'screenshots' && name.contains('screenshot')) {
            targetFolder = folder;
            break;
          }
        }
      }

      if (targetFolder != null) {
        if (!mounted) {
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeviceFolderDetailScreen(
                folder: targetFolder!, titleOverride: album.name),
          ),
        );
        if (!mounted) {
          return;
        }
        _loadAlbums();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _showAlbumContextMenu(Album album, Offset position) async {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          child: Text(album.isPinned ? 'Unpin' : 'Pin',
              style: const TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<String>(
          value: 'rename',
          child: Text('Edit album name', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<String>(
          value: 'hide',
          child: Text('Hide', style: TextStyle(fontSize: 16)),
        ),
      ],
    );

    if (!mounted) {
      return;
    }

    if (value == 'pin') {
      _togglePin(album);
    } else if (value == 'rename') {
      _renameAlbum(album);
    } else if (value == 'hide') {
      _hideAlbum(album);
    } else if (value == 'delete') {
      _deleteAlbum(album);
    }
  }

  Future<void> _showDeviceFolderContextMenu(
      AssetPathEntity folder, Offset position) async {
    final isPinned = _pinnedDeviceFolderIds.contains(folder.id);
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          child: Text(isPinned ? 'Unpin' : 'Pin',
              style: const TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<String>(
          value: 'rename',
          child: Text('Edit folder name', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(fontSize: 16)),
        ),
        const PopupMenuItem<String>(
          value: 'hide',
          child: Text('Hide', style: TextStyle(fontSize: 16)),
        ),
      ],
    );

    if (!mounted) {
      return;
    }

    if (value == 'hide') {
      _hideDeviceFolder(folder);
    } else if (value == 'pin') {
      _toggleDeviceFolderPin(folder);
    } else if (value == 'rename') {
      _renameDeviceFolder(folder);
    } else if (value == 'delete') {
      _deleteDeviceFolder(folder);
    }
  }

  Future<void> _toggleDeviceFolderPin(AssetPathEntity folder) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pinnedIds = prefs.getStringList('pinned_device_folders') ?? [];
    if (pinnedIds.contains(folder.id)) {
      pinnedIds.remove(folder.id);
    } else {
      pinnedIds.add(folder.id);
    }
    await prefs.setStringList('pinned_device_folders', pinnedIds);
    if (mounted) {
      await _loadAlbums();
    }
  }

  Future<void> _togglePin(Album album) async {
    await AlbumService.togglePin(album.id);
    if (mounted) {
      await _loadAlbums();
    }
  }

  Future<void> _renameAlbum(Album album) async {
    final controller = TextEditingController(text: album.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Album'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'Album Name', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != album.name) {
      await AlbumService.updateAlbum(album.id, name: result);
      if (mounted) {
        await _loadAlbums();
      }
    }
  }

  Future<void> _renameDeviceFolder(AssetPathEntity folder) async {
    final currentName = _deviceFolderAliases[folder.id] ?? folder.name;
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'Folder Name', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentName) {
      final prefs = await SharedPreferences.getInstance();
      _deviceFolderAliases[folder.id] = result;
      await prefs.setString(
          'device_folder_aliases', json.encode(_deviceFolderAliases));
      if (mounted) {
        await _loadAlbums();
      }
    }
  }

  Future<void> _hideAlbum(Album album) async {
    await AlbumService.toggleHide(album.id);
    if (mounted) {
      await _loadAlbums();
    }
  }

  Future<void> _hideDeviceFolder(AssetPathEntity folder) async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenDeviceFolderIds =
        prefs.getStringList('hidden_device_folders') ?? [];
    if (!hiddenDeviceFolderIds.contains(folder.id)) {
      hiddenDeviceFolderIds.add(folder.id);
      await prefs.setStringList('hidden_device_folders', hiddenDeviceFolderIds);
    }
    if (mounted) {
      await _loadAlbums();
    }
  }

  Future<void> _deleteAlbum(Album album) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Album?'),
        content: Text(
            'Delete "${album.name}"? All photos inside will be moved to Recently Deleted for 30 days.'),
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

    if (confirm == true) {
      final photoIds = AlbumPhotoService.getPhotosInAlbum(album.id);
      if (photoIds.isNotEmpty) {
        await DeletedPhotosService.deletePhotos(photoIds);
      }
      await AlbumPhotoService.clearAlbum(album.id);
      await AlbumService.deleteAlbum(album.id);
      if (!mounted) {
        return;
      }
      await _loadAlbums();
    }
  }

  Future<void> _deleteDeviceFolder(AssetPathEntity folder) async {
    final folderName = _deviceFolderAliases[folder.id] ?? folder.name;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Folder?'),
        content: Text(
            'Remove "$folderName" from your albums?\n\n(Photos will NOT be deleted from your device)'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove')),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final hiddenDeviceFolderIds =
          prefs.getStringList('hidden_device_folders') ?? [];
      if (!hiddenDeviceFolderIds.contains(folder.id)) {
        hiddenDeviceFolderIds.add(folder.id);
        await prefs.setStringList(
            'hidden_device_folders', hiddenDeviceFolderIds);
      }
      if (_pinnedDeviceFolderIds.contains(folder.id)) {
        _pinnedDeviceFolderIds.remove(folder.id);
        await prefs.setStringList(
            'pinned_device_folders', _pinnedDeviceFolderIds);
      }
      if (!mounted) {
        return;
      }
      await _loadAlbums();
    }
  }

  Future<void> _showGlobalMenu() async {
    final value = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: const [
        PopupMenuItem<String>(
          value: 'deleted',
          child: Text('Recently deleted items', style: TextStyle(fontSize: 16)),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Text('Settings', style: TextStyle(fontSize: 16)),
        ),
      ],
    );

    if (!mounted) {
      return;
    }

    if (value == 'deleted') {
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RecentlyDeletedScreen()));
      if (!mounted) {
        return;
      }
      _loadAlbums();
    } else if (value == 'settings') {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      if (!mounted) {
        return;
      }
      _loadAlbums();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final double triggerDepth = 180.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildAlbumsContent(triggerDepth),
      ),
    );
  }

  Widget _buildAlbumsContent(double triggerDepth) {
    return CustomScrollView(
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: triggerDepth,
          refreshIndicatorExtent: triggerDepth,
          onRefresh: () async {
            _handlePrivateAccess();
            await Future.delayed(const Duration(milliseconds: 100));
          },
          builder: (context, refreshState, pulledExtent,
              refreshTriggerPullDistance, refreshIndicatorExtent) {
            final double percentage =
                (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
            final bool isArmed = refreshState == RefreshIndicatorMode.armed ||
                refreshState == RefreshIndicatorMode.refresh;

            return Container(
              height: pulledExtent,
              alignment: Alignment.bottomCenter,
              padding: const EdgeInsets.only(bottom: 40),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Opacity(
                  opacity: percentage,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isArmed
                            ? Icons.lock_open_rounded
                            : Icons.lock_outline_rounded,
                        color: AppColors.accentBlue,
                        size: 32 + (8 * percentage),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isArmed
                            ? 'Release to open private folder'
                            : 'Pull down to open',
                        style: const TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(child: _buildTopBar()),
        SliverToBoxAdapter(child: _buildPinnedSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(child: _buildCombinedAlbumsSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(child: _buildMoreSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
              icon: const Icon(Icons.search, size: 28, color: Colors.black87),
              onPressed: () {}),
          IconButton(
              icon:
                  const Icon(Icons.more_vert, size: 28, color: Colors.black87),
              onPressed: _showGlobalMenu),
        ],
      ),
    );
  }

  Widget _buildPinnedSection() {
    final systemAlbums = Album.systemAlbums;
    final pinnedUserAlbums = AlbumService.getPinnedAlbums();
    final allPinned = [...systemAlbums, ...pinnedUserAlbums];
    final pinnedDeviceFoldersList = _allDeviceFolders
        .where((f) => _pinnedDeviceFolderIds.contains(f.id))
        .toList();
    final totalPinned = allPinned.length + pinnedDeviceFoldersList.length;

    if (totalPinned == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Pinned',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black))),
              Icon(Icons.chevron_right, size: 24, color: Colors.grey[600]),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
            ),
            itemCount: totalPinned,
            itemBuilder: (context, index) {
              if (index < allPinned.length) {
                final album = allPinned[index];
                final isSystem = systemAlbums.contains(album);
                final itemCount = isSystem
                    ? (_systemAlbumCounts[album.id] ?? 0)
                    : AlbumPhotoService.getAlbumPhotoCount(album.id);

                return GestureDetector(
                  onTapDown: (details) => _tapPosition = details.globalPosition,
                  onLongPress: isSystem
                      ? null
                      : () => _showAlbumContextMenu(album, _tapPosition),
                  onTap: isSystem
                      ? () => _openSystemAlbum(album)
                      : () async {
                          await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      AlbumDetailScreen(album: album)));
                          if (!mounted) {
                            return;
                          }
                          _loadAlbums();
                        },
                  child: _buildHorizontalCard(
                    title: album.name,
                    count: itemCount,
                    albumId: album.id,
                  ),
                );
              } else {
                final folder =
                    pinnedDeviceFoldersList[index - allPinned.length];
                return GestureDetector(
                  onTapDown: (details) => _tapPosition = details.globalPosition,
                  onLongPress: () =>
                      _showDeviceFolderContextMenu(folder, _tapPosition),
                  onTap: () => _openDeviceFolder(folder),
                  child: _buildHorizontalCard(
                    title: _deviceFolderAliases[folder.id] ?? folder.name,
                    isDeviceFolder: true,
                    folder: folder,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCard(
      {required String title,
      int? count,
      String? albumId,
      bool isDeviceFolder = false,
      AssetPathEntity? folder}) {
    IconData iconData = Icons.folder_outlined;
    if (albumId == 'camera') {
      iconData = Icons.camera_alt;
    }
    if (albumId == 'screenshots') {
      iconData = Icons.screenshot;
    }
    if (albumId == 'videos') {
      iconData = Icons.videocam;
    }
    if (albumId == 'all_photos') {
      iconData = Icons.photo_library;
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: SizedBox(
              width: 64,
              height: double.infinity,
              child: isDeviceFolder
                  ? FutureBuilder<AssetEntity?>(
                      future: _getFirstAssetFromFolder(folder!),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          return AssetEntityImage(snapshot.data!,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(150),
                              fit: BoxFit.cover);
                        }
                        return Container(
                            color: Colors.grey[300],
                            child:
                                const Icon(Icons.folder, color: Colors.grey));
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: Icon(iconData, color: Colors.grey[600]),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  if (count != null)
                    Row(
                      children: [
                        Icon(iconData, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('$count',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    )
                  else if (isDeviceFolder)
                    FutureBuilder<int>(
                        future: folder!.assetCountAsync,
                        builder: (context, snapshot) {
                          return Row(
                            children: [
                              Icon(Icons.folder,
                                  size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('${snapshot.data ?? 0}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600])),
                            ],
                          );
                        }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedAlbumsSection() {
    final unpinnedAlbums =
        AlbumService.getVisibleUserAlbums().where((a) => !a.isPinned).toList();
    final unpinnedFolders = _allDeviceFolders
        .where((f) => !_pinnedDeviceFolderIds.contains(f.id))
        .toList();

    final combinedList = [...unpinnedAlbums, ...unpinnedFolders];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Albums',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black))),
              Icon(Icons.chevron_right, size: 24, color: Colors.grey[600]),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showCreateAlbumDialog,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Create Album'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: const BorderSide(color: AppColors.accentBlue),
              foregroundColor: AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 16),
          if (combinedList.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: combinedList.length,
              itemBuilder: (context, index) {
                final item = combinedList[index];

                if (item is Album) {
                  final itemCount =
                      AlbumPhotoService.getAlbumPhotoCount(item.id);
                  return GestureDetector(
                      onTapDown: (details) =>
                          _tapPosition = details.globalPosition,
                      onLongPress: () {
                        _showAlbumContextMenu(item, _tapPosition);
                      },
                      child: FutureBuilder<AssetEntity?>(future: () async {
                        final photoIds =
                            AlbumPhotoService.getPhotosInAlbum(item.id);
                        if (photoIds.isNotEmpty) {
                          return await AssetEntity.fromId(photoIds.first);
                        }
                        return null;
                      }(), builder: (context, snapshot) {
                        return AlbumCard(
                          album: item,
                          itemCount: itemCount,
                          coverAsset: snapshot.data,
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        AlbumDetailScreen(album: item)));
                            if (!mounted) {
                              return;
                            }
                            _loadAlbums();
                          },
                        );
                      }));
                } else if (item is AssetPathEntity) {
                  return GestureDetector(
                      onTapDown: (details) =>
                          _tapPosition = details.globalPosition,
                      onLongPress: () {
                        _showDeviceFolderContextMenu(item, _tapPosition);
                      },
                      child: FutureBuilder<int>(
                        future: item.assetCountAsync,
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          return FutureBuilder<AssetEntity?>(
                            future: _getFirstAssetFromFolder(item),
                            builder: (context, assetSnapshot) {
                              final coverAsset = assetSnapshot.data;
                              return InkWell(
                                onTap: () => _openDeviceFolder(item),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                  top: Radius.circular(16)),
                                          child: coverAsset != null
                                              ? AssetEntityImage(coverAsset,
                                                  isOriginal: false,
                                                  thumbnailSize:
                                                      const ThumbnailSize
                                                          .square(200),
                                                  fit: BoxFit.cover)
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Center(
                                                      child: Icon(
                                                          Icons.folder_outlined,
                                                          size: 40,
                                                          color: AppColors
                                                              .iconGray))),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                _deviceFolderAliases[item.id] ??
                                                    item.name,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text('$count items',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600])),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ));
                }
                return const SizedBox.shrink();
              },
            )
          else
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                    child: Text('No albums yet',
                        style: TextStyle(color: AppColors.textSecondary)))),
        ],
      ),
    );
  }

  Widget _buildMoreSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('More',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: const Color(0xFFFDFDFD),
                borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.delete_outline,
                  size: 24, color: Colors.black87),
              title: const Text('Recently deleted',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RecentlyDeletedScreen()));
                if (!mounted) {
                  return;
                }
                _loadAlbums();
              },
            ),
          ),
        ],
      ),
    );
  }
}
