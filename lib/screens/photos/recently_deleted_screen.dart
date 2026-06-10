import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../services/deleted_photos_service.dart';
import '../../utils/app_colors.dart';
import 'photo_viewer_screen.dart';

class RecentlyDeletedScreen extends StatefulWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  List<DeletedItem> _deletedItems = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDeletedItems();
  }

  Future<void> _loadDeletedItems() async {
    setState(() {
      _isLoading = true;
    });

    final items = await DeletedPhotosService.getDeletedItems();

    if (mounted) {
      setState(() {
        _deletedItems = items;
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_deletedItems.map((e) => e.assetId));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  Future<void> _restoreSelected() async {
    final selectedIdsList = _selectedIds.toList();
    final count = selectedIdsList.length;

    await DeletedPhotosService.restorePhotos(selectedIdsList);

    if (!mounted) return;
    _exitSelectionMode();
    await _loadDeletedItems();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Restored $count photo(s)')));
  }

  void _showEmptyBinBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_forever, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Empty Recycle Bin?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Permanently delete all items from device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.black, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _emptyEntireBin();
                      },
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _emptyEntireBin() async {
    setState(() {
      _isLoading = true;
    });

    for (final item in _deletedItems) {
      try {
        final asset = await AssetEntity.fromId(item.assetId);
        if (asset != null) {
          final file = await asset.file;
          if (file != null && await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }

    final allIds = _deletedItems.map((e) => e.assetId).toList();
    await DeletedPhotosService.restorePhotos(allIds);

    if (!mounted) return;
    await _loadDeletedItems();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Recycle bin emptied')));
  }

  Future<void> _permanentlyDeleteSelected() async {
    final selectedIdsList = _selectedIds.toList();
    final count = selectedIdsList.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently Delete?'),
        content: Text(
            'These $count photo(s) will be permanently deleted from your device. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    final selectedItems =
        _deletedItems.where((i) => _selectedIds.contains(i.assetId)).toList();

    for (final item in selectedItems) {
      try {
        final asset = await AssetEntity.fromId(item.assetId);
        if (asset != null) {
          final file = await asset.file;
          if (file != null && await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
    }

    await DeletedPhotosService.restorePhotos(selectedIdsList);

    if (!mounted) return;
    _exitSelectionMode();
    await _loadDeletedItems();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permanently deleted $count photo(s)')));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: AppColors.accentBlue,
                elevation: 0,
                leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _exitSelectionMode),
                title: Text('${_selectedIds.length} selected',
                    style: const TextStyle(color: Colors.white)),
                actions: [
                  TextButton(
                      onPressed: () {
                        if (_selectedIds.length == _deletedItems.length) {
                          _deselectAll();
                        } else {
                          _selectAll();
                        }
                      },
                      child: Text(
                          _selectedIds.length == _deletedItems.length
                              ? 'Deselect All'
                              : 'Select All',
                          style: const TextStyle(color: Colors.white)))
                ],
              )
            : AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                title: const Text('Recently Deleted',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                iconTheme: const IconThemeData(color: AppColors.textPrimary),
                actions: [
                  // ✅ FIX 2: Solid Red Bin Icon forced onto the AppBar (Always visible)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon:
                          const Icon(Icons.delete, color: Colors.red, size: 28),
                      onPressed: _showEmptyBinBottomSheet,
                    ),
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
    if (_deletedItems.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.delete_outline,
            size: 80, color: AppColors.iconGray.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text('No recently deleted items',
            style: TextStyle(fontSize: 18, color: AppColors.textSecondary))
      ]));
    }

    return Column(
      children: [
        if (!_isSelectionMode)
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Items will be permanently deleted after 30 days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.8)))),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.0),
            itemCount: _deletedItems.length,
            itemBuilder: (context, index) {
              final item = _deletedItems[index];
              final isSelected = _selectedIds.contains(item.assetId);

              return FutureBuilder<AssetEntity?>(
                future: AssetEntity.fromId(item.assetId),
                builder: (context, snapshot) {
                  final asset = snapshot.data;
                  if (asset == null)
                    return Container(
                        color: AppColors.surfaceGray,
                        child: const Center(
                            child:
                                Icon(Icons.broken_image, color: Colors.grey)));

                  return GestureDetector(
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelection(asset.id);
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PhotoViewerScreen(
                                    assets: [asset], initialIndex: 0)));
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) _enterSelectionMode(asset.id);
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AssetEntityImage(asset,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize.square(300),
                            fit: BoxFit.cover),
                        Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 6),
                                decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                      Colors.black.withValues(alpha: 0.7),
                                      Colors.transparent
                                    ])),
                                child: Text('${item.daysRemaining} days',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)))),
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
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2))
      ]),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: SafeArea(
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildActionButton(
            icon: Icons.restore,
            label: 'Restore',
            color: AppColors.accentBlue,
            onPressed: _restoreSelected),
        _buildActionButton(
            icon: Icons.delete_forever,
            label: 'Delete',
            color: Colors.red,
            onPressed: _permanentlyDeleteSelected)
      ])),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required VoidCallback onPressed,
      required Color color}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color))
          ])),
    );
  }
}
