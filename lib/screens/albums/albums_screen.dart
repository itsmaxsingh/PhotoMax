import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/album.dart';
import '../../services/album_photo_service.dart';
import '../../services/album_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/album_card.dart';
import '../photos/recently_deleted_screen.dart';
import '../private/private_folder_screen.dart';
import '../private/pattern_setup_screen.dart';
import '../private/pattern_unlock_screen.dart';
import 'album_detail_screen.dart';

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});
  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);
    await AlbumService.init();
    await AlbumPhotoService.init();
    setState(() => _isLoading = false);
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
      if (!mounted) return;
      await _loadAlbums();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Album "${nameController.text.trim()}" created!')));
    }
  }

  Future<void> _handlePrivateAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPattern = prefs.containsKey('pattern');
    if (!hasPattern) {
      final result = await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const PatternSetupScreen()));
      if (result == true && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pattern set!')));
        _openPrivateFolder();
      }
    } else {
      _openPrivateFolder();
    }
  }

  Future<void> _openPrivateFolder() async {
    final unlocked = await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const PatternUnlockScreen()));
    if (unlocked == true && mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PrivateFolderScreen()) // ❌ REMOVE const
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildAlbumsContent(),
      ),
    );
  }

  Widget _buildAlbumsContent() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildPinnedSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(child: _buildAlbumsSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(child: _buildMoreSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildPinnedSection() {
    final pinnedAlbums = Album.systemAlbums;
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary))),
              IconButton(
                  icon: const Icon(Icons.chevron_right, size: 28),
                  onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: pinnedAlbums.length,
              itemBuilder: (context, index) {
                final album = pinnedAlbums[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  child: AlbumCard(
                    album: album,
                    itemCount: 42,
                    onTap: () {},
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumsSection() {
    final userAlbums = AlbumService.getUserAlbums();
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
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary))),
              IconButton(
                  icon: const Icon(Icons.chevron_right, size: 28),
                  onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showCreateAlbumDialog,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Create Album'),
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: const BorderSide(color: AppColors.accentBlue),
                foregroundColor: AppColors.accentBlue),
          ),
          const SizedBox(height: 16),
          if (userAlbums.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.75),
              itemCount: userAlbums.length,
              itemBuilder: (context, index) {
                final album = userAlbums[index];
                final itemCount =
                    AlbumPhotoService.getAlbumPhotoCount(album.id);
                return AlbumCard(
                  album: album,
                  itemCount: itemCount,
                  onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(album: album)))
                      .then((_) => _loadAlbums()),
                );
              },
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                  child: Text('No albums yet',
                      style: TextStyle(color: AppColors.textSecondary))),
            ),
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline, size: 24),
                  title: const Text('Recently deleted'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RecentlyDeletedScreen())),
                ),
                const Divider(height: 1, indent: 60),
                ListTile(
                  leading: const Icon(Icons.lock_outline, size: 24),
                  title: const Text('Private Album'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _handlePrivateAccess,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
