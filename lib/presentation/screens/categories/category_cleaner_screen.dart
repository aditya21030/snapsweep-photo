import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../providers/scan_provider.dart';
import '../../common/fullscreen_photo_viewer.dart';

enum CategoryFilter { all, olderThan30Days, videosOnly, photosOnly }
enum CategorySort { largestFirst, newestFirst, oldestFirst }

class CategoryCleanerScreen extends StatefulWidget {
  final String title;
  final List<AssetEntity> assets;

  const CategoryCleanerScreen({
    super.key,
    required this.title,
    required this.assets,
  });

  @override
  State<CategoryCleanerScreen> createState() => _CategoryCleanerScreenState();
}

class _CategoryCleanerScreenState extends State<CategoryCleanerScreen> {
  final Set<String> _selectedIds = {};
  CategoryFilter _activeFilter = CategoryFilter.all;
  CategorySort _activeSort = CategorySort.largestFirst;
  bool _isProcessing = false;

  List<AssetEntity>? _cachedDisplayAssets;
  List<AssetEntity>? _lastRawAssets;
  CategoryFilter? _lastFilter;
  CategorySort? _lastSort;

  Future<void> _cleanSelected() async {
    if (_isProcessing || _selectedIds.isEmpty) return;
    _isProcessing = true;
    try {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
              ),
              const Gap(12),
              const Expanded(child: Text('Move to Trash?')),
            ],
          ),
          content: Text(
            '${_selectedIds.length} item(s) will be moved to your device\'s Trash / Recently Deleted folder.\n\nYou can restore them from the Trash within 30 days.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text('Move to Trash'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        HapticFeedback.mediumImpact();
        final provider = context.read<ScanProvider>();
        final count = await provider.smartClean(specificIds: _selectedIds.toList());
        if (mounted && count > 0) {
          setState(() {
            _selectedIds.retainWhere((id) => provider.allScreenshots.any((a) => a.id == id));
            _cachedDisplayAssets = null;
            _lastRawAssets = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Moved $count items from ${widget.title} to Trash')),
          );

          final remaining = widget.title == 'Large Videos'
              ? provider.largeVideos.length
              : (widget.title == 'Blurry Photos'
                  ? provider.blurryPhotos.length
                  : (provider.categories[widget.title]?.length ?? 0));
          if (remaining == 0) {
            Navigator.pop(context);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openInspector(AssetEntity asset) async {
    final bool isSelected = _selectedIds.contains(asset.id);
    final result = await FullscreenPhotoViewer.open(
      context,
      asset: asset,
      isSelected: isSelected,
      subtitle: widget.title,
      onSelectionChanged: (val) {
        setState(() {
          if (val) {
            _selectedIds.add(asset.id);
          } else {
            _selectedIds.remove(asset.id);
          }
        });
      },
    );

    if (result != null && mounted) {
      setState(() {
        if (result) {
          _selectedIds.add(asset.id);
        } else {
          _selectedIds.remove(asset.id);
        }
      });
    }
  }

  List<AssetEntity> _filterAndSort(List<AssetEntity> rawAssets, Map<String, int> assetSizes) {
    if (_cachedDisplayAssets != null &&
        identical(_lastRawAssets, rawAssets) &&
        _lastFilter == _activeFilter &&
        _lastSort == _activeSort) {
      return _cachedDisplayAssets!;
    }

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Filter
    List<AssetEntity> filtered = rawAssets.where((asset) {
      switch (_activeFilter) {
        case CategoryFilter.all:
          return true;
        case CategoryFilter.olderThan30Days:
          return asset.createDateTime.isBefore(thirtyDaysAgo);
        case CategoryFilter.videosOnly:
          return asset.type == AssetType.video;
        case CategoryFilter.photosOnly:
          return asset.type == AssetType.image;
      }
    }).toList();

    // Sort
    switch (_activeSort) {
      case CategorySort.largestFirst:
        filtered.sort((a, b) {
          final sizeA = assetSizes[a.id] ?? 0;
          final sizeB = assetSizes[b.id] ?? 0;
          return sizeB.compareTo(sizeA);
        });
        break;
      case CategorySort.newestFirst:
        filtered.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        break;
      case CategorySort.oldestFirst:
        filtered.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        break;
    }

    _lastRawAssets = rawAssets;
    _lastFilter = _activeFilter;
    _lastSort = _activeSort;
    _cachedDisplayAssets = filtered;
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScanProvider>();
    final currentAssets = context.select<ScanProvider, List<AssetEntity>>((p) {
      if (widget.title == 'Large Videos') return p.largeVideos;
      if (widget.title == 'Blurry Photos') return p.blurryPhotos;
      return p.categories[widget.title] ?? widget.assets;
    });

    final displayAssets = _filterAndSort(currentAssets, provider.assetSizes);

    int selectedSize = 0;
    for (var id in _selectedIds) {
      selectedSize += provider.assetSizes[id] ?? 0;
    }

    final hasVideos = currentAssets.any((a) => a.type == AssetType.video);
    final hasPhotos = currentAssets.any((a) => a.type == AssetType.image);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text(
              '${_selectedIds.length} of ${displayAssets.length} selected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (_selectedIds.length >= displayAssets.length && displayAssets.isNotEmpty) {
                  _selectedIds.clear();
                } else {
                  _selectedIds.clear();
                  for (var a in displayAssets) {
                    _selectedIds.add(a.id);
                  }
                }
              });
            },
            child: Text(
              _selectedIds.length >= displayAssets.length && displayAssets.isNotEmpty
                  ? 'Deselect All'
                  : 'Select All',
            ),
          ),
        ],
      ),
      body: currentAssets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 64, color: Colors.green.withValues(alpha: 0.6)),
                  const Gap(16),
                  Text(
                    'No items in ${widget.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Gap(6),
                  const Text('All items have been reviewed or cleaned.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                // Filter & Sort Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      // Sort Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<CategorySort>(
                          value: _activeSort,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.sort_rounded, size: 18),
                          items: const [
                            DropdownMenuItem(value: CategorySort.largestFirst, child: Text('Largest first', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: CategorySort.newestFirst, child: Text('Newest first', style: TextStyle(fontSize: 13))),
                            DropdownMenuItem(value: CategorySort.oldestFirst, child: Text('Oldest first', style: TextStyle(fontSize: 13))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _activeSort = val);
                          },
                        ),
                      ),
                      const Gap(8),
                      // Filter Chips
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All', CategoryFilter.all),
                              const Gap(6),
                              _buildFilterChip('>30 Days Old', CategoryFilter.olderThan30Days),
                              if (hasVideos && hasPhotos) ...[
                                const Gap(6),
                                _buildFilterChip('Videos', CategoryFilter.videosOnly),
                                const Gap(6),
                                _buildFilterChip('Photos', CategoryFilter.photosOnly),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Helper Subtitle
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primary),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          'Tap item to view / play   Tap checkbox to select for trash',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Grid View
                Expanded(
                  child: displayAssets.isEmpty
                      ? Center(
                          child: Text(
                            'No items match the selected filter.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        )
                      : GridView.builder(
                          cacheExtent: 600,
                          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 100),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: displayAssets.length,
                          itemBuilder: (context, index) {
                            final asset = displayAssets[index];
                            final isSelected = _selectedIds.contains(asset.id);
                            final isVideo = asset.type == AssetType.video;

                            return GestureDetector(
                              onTap: () => _openInspector(asset),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: AssetEntityImage(
                                        asset,
                                        isOriginal: false,
                                        thumbnailSize: const ThumbnailSize.square(250),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: AppColors.error, width: 3),
                                          borderRadius: BorderRadius.circular(14),
                                          color: AppColors.error.withValues(alpha: 0.3),
                                        ),
                                      ),
                                    ),

                                  // Corner Checkbox
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() {
                                          if (isSelected) {
                                            _selectedIds.remove(asset.id);
                                          } else {
                                            _selectedIds.add(asset.id);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.error : Colors.black.withValues(alpha: 0.5),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: Icon(
                                          isSelected ? Icons.check_rounded : Icons.circle,
                                          color: isSelected ? Colors.white : Colors.transparent,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Video Duration Pill (Top-Left)
                                  if (isVideo)
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                                            const Gap(2),
                                            Text(
                                              AppUtils.formatDuration(Duration(seconds: asset.duration)),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // Size label
                                  if (provider.assetSizes.containsKey(asset.id))
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          provider.getFormattedAssetSize(asset.id),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
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
            ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: _selectedIds.isEmpty ? null : _cleanSelected,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.delete_sweep_rounded),
            label: Text(
              _selectedIds.isEmpty
                  ? 'Select Items to Clean'
                  : 'Move ${_selectedIds.length} Items to Trash (${AppUtils.formatBytes(selectedSize)})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, CategoryFilter filter) {
    final isSelected = _activeFilter == filter;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _activeFilter = filter);
      },
    );
  }
}
