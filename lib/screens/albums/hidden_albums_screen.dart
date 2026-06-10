import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/album.dart';
import '../../services/album_photo_service.dart';
import '../../services/album_service.dart';
import 'album_detail_screen.dart';
import 'device_folder_detail_screen.dart';

class HiddenAlbumsScreen extends StatefulWidget {
  const HiddenAlbumsScreen({super.key});

  @override
  State<HiddenAlbumsScreen> createState() => _HiddenAlbumsScreenState();
}

class _HiddenAlbumsScreenState extends State<HiddenAlbumsScreen> {
  List<Album> _hiddenUserAlbums = [];
  List<AssetPathEntity> _hiddenDeviceFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHiddenData();
  }

  Future<void> _loadHiddenData() async {
    setState(() => _isLoading = true);

    _hiddenUserAlbums = AlbumService.getHiddenAlbums();

    final prefs = await SharedPreferences.getInstance();
    final hiddenIds = prefs.getStringList('hidden_device_folders') ?? [];

    final permission = await PhotoManager.requestPermissionExtend();
    if (permission.hasAccess) {
      final folders = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: false,
      );
      _hiddenDeviceFolders =
          folders.where((f) => hiddenIds.contains(f.id)).toList();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unhideUserAlbum(Album album) async {
    await AlbumService.toggleHide(album.id);
    await _loadHiddenData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${album.name} is now visible')));
    }
  }

  Future<void> _unhideDeviceFolder(AssetPathEntity folder) async {
    final prefs = await SharedPreferences.getInstance();
    final hiddenIds = prefs.getStringList('hidden_device_folders') ?? [];
    hiddenIds.remove(folder.id);
    await prefs.setStringList('hidden_device_folders', hiddenIds);

    await _loadHiddenData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${folder.name} is now visible')));
    }
  }

  Future<AssetEntity?> _getFirstAssetFromFolder(AssetPathEntity folder) async {
    try {
      final assets = await folder.getAssetListPaged(page: 0, size: 1);
      return assets.isNotEmpty ? assets.first : null;
    } catch (e) {
      return null;
    }
  }

  // ✅ REDESIGNED TO MATCH SCREENSHOT 10 (List View instead of Grid View)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Hidden albums',
            style: TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontWeight: FontWeight.w400)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_hiddenUserAlbums.isEmpty && _hiddenDeviceFolders.isEmpty)
              ? _buildEmptyState()
              : _buildCombinedList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('No Hidden Albums',
          style: TextStyle(fontSize: 18, color: Colors.grey)),
    );
  }

  Widget _buildCombinedList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _hiddenUserAlbums.length + _hiddenDeviceFolders.length,
      itemBuilder: (context, index) {
        // Render User Albums
        if (index < _hiddenUserAlbums.length) {
          final album = _hiddenUserAlbums[index];
          final itemCount = AlbumPhotoService.getAlbumPhotoCount(album.id);

          return _buildListItem(
            title: album.name,
            count: itemCount,
            onUnhide: () => _unhideUserAlbum(album),
            onTap: () {
              Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AlbumDetailScreen(album: album)))
                  .then((_) => _loadHiddenData());
            },
          );
        }

        // Render Device Folders
        else {
          final folder = _hiddenDeviceFolders[index - _hiddenUserAlbums.length];

          return FutureBuilder<int>(
            future: folder.assetCountAsync,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return FutureBuilder<AssetEntity?>(
                future: _getFirstAssetFromFolder(folder),
                builder: (context, assetSnapshot) {
                  final coverAsset = assetSnapshot.data;

                  return _buildListItem(
                    title: folder.name,
                    count: count,
                    coverAsset: coverAsset,
                    onUnhide: () => _unhideDeviceFolder(folder),
                    onTap: () {
                      Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      DeviceFolderDetailScreen(folder: folder)))
                          .then((_) => _loadHiddenData());
                    },
                  );
                },
              );
            },
          );
        }
      },
    );
  }

  // ✅ NEW WIDGET: Recreates the exact list tile from 10.jpg
  Widget _buildListItem(
      {required String title,
      required int count,
      AssetEntity? coverAsset,
      required VoidCallback onUnhide,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Left Square Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 70,
                child: coverAsset != null
                    ? AssetEntityImage(coverAsset,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize.square(200),
                        fit: BoxFit.cover)
                    : Container(color: const Color(0xFFF0F0F0)),
              ),
            ),
            const SizedBox(width: 16),

            // Middle Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('$count items',
                      style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),

            // Right Unhide Pill Button
            ElevatedButton(
              onPressed: onUnhide,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEEEEE), // Light grey
                foregroundColor: Colors.black87,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              ),
              child: const Text('Unhide',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}
