import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/deleted_photos_service.dart';

class PhotoViewerScreen extends StatefulWidget {
  final List<AssetEntity> assets;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.assets,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late int _currentIndex;
  late PageController _pageController;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  Future<void> _shareCurrentAsset() async {
    try {
      final file = await widget.assets[_currentIndex].file;
      if (file != null) {
        await Share.shareXFiles([XFile(file.path)]);
      }
    } catch (e) {
      // ✅ FIXED: Using 'mounted' instead of 'context.mounted' in a State class
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing: $e')),
      );
    }
  }

  Future<void> _deleteCurrentAsset() async {
    final asset = widget.assets[_currentIndex];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This item will be moved to Recently Deleted.'),
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
      ),
    );

    if (confirm == true) {
      await DeletedPhotosService.deletePhotos([asset.id]);

      // ✅ FIXED: Using 'mounted' instead of 'context.mounted'
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Recently Deleted')),
      );

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assets.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child:
                Text('No media found', style: TextStyle(color: Colors.white))),
      );
    }

    final currentAsset = widget.assets[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showUI
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                '${currentAsset.createDateTime.day}/${currentAsset.createDateTime.month}/${currentAsset.createDateTime.year}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(16))),
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Details',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Text('Title: ${currentAsset.title}'),
                            const SizedBox(height: 8),
                            Text(
                                'Resolution: ${currentAsset.width} x ${currentAsset.height}'),
                            const SizedBox(height: 8),
                            Text(
                                'Date: ${currentAsset.createDateTime.toString().split('.')[0]}'),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: _toggleUI,
        child: PhotoViewGallery.builder(
          itemCount: widget.assets.length,
          pageController: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          builder: (ctx, index) {
            final asset = widget.assets[index];

            if (asset.type == AssetType.video) {
              return PhotoViewGalleryPageOptions.customChild(
                child: _VideoAssetPlayerWidget(asset: asset),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                heroAttributes: PhotoViewHeroAttributes(tag: asset.id),
              );
            }

            return PhotoViewGalleryPageOptions(
              imageProvider: AssetEntityImageProvider(
                asset,
                isOriginal: true,
              ),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: PhotoViewHeroAttributes(tag: asset.id),
            );
          },
          loadingBuilder: (ctx, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
      bottomNavigationBar: _showUI
          ? Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.ios_share, color: Colors.white),
                      onPressed: _shareCurrentAsset,
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.auto_fix_high, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Edit features coming soon!')));
                      },
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: _deleteCurrentAsset,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _VideoAssetPlayerWidget extends StatefulWidget {
  final AssetEntity asset;

  const _VideoAssetPlayerWidget({required this.asset});

  @override
  State<_VideoAssetPlayerWidget> createState() =>
      _VideoAssetPlayerWidgetState();
}

class _VideoAssetPlayerWidgetState extends State<_VideoAssetPlayerWidget> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final file = await widget.asset.file;
      if (file != null) {
        _videoPlayerController = VideoPlayerController.file(file);
        await _videoPlayerController!.initialize();

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true,
          looping: true,
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          showControlsOnInitialize: false,
          materialProgressColors: ChewieProgressColors(
            playedColor: Colors.blue,
            handleColor: Colors.blue,
            backgroundColor: Colors.grey,
            bufferedColor: Colors.white30,
          ),
          errorBuilder: (ctx, errorMessage) {
            return Center(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        );

        if (mounted) {
          setState(() {});
        }
      } else {
        if (mounted) {
          setState(() => _isError = true);
        }
      }
    } catch (e) {
      debugPrint('Video Player Error: $e');
      if (mounted) {
        setState(() => _isError = true);
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 48),
            SizedBox(height: 16),
            Text('Error playing video', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return Center(
        child: Chewie(controller: _chewieController!),
      );
    }

    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
}
