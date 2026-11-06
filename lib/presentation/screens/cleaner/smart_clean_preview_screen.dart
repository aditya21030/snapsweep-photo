import '../../common/operation_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../providers/scan_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/services/media_service.dart';
import '../../common/fullscreen_photo_viewer.dart';

enum SmartCleanFilter { all, duplicates, blurry, videos, bursts }

class SmartCleanPreviewScreen extends StatefulWidget {
  const SmartCleanPreviewScreen({super.key});

  @override
  State<SmartCleanPreviewScreen> createState() =>
      _SmartCleanPreviewScreenState();
}

class _SmartCleanPreviewScreenState extends State<SmartCleanPreviewScreen> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  SmartCleanFilter _activeFilter = SmartCleanFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ScanProvider>();
      setState(() {
        // Only byte-for-byte verified extra copies are selected by default.
        // Blurry photos, videos, and visually similar shots require a choice.
        for (final group in provider.duplicateGroups) {
          for (int i = 1; i < group.length; i++) {
            _selectedIds.add(group[i].id);
          }
        }
      });
    });
  }

  String _getItemReason(AssetEntity asset, ScanProvider provider) {
    if (asset.type == AssetType.video) return 'Video';
    if (provider.blurryPhotos.any((b) => b.id == asset.id)) return 'Blurry';
    for (final group in provider.duplicateGroups) {
      if (group.any((d) => d.id == asset.id)) return 'Duplicate';
    }
    for (final group in provider.similarGroups) {
      if (group.any((s) => s.id == asset.id)) return 'Burst';
    }
    return 'Reclaimable';
  }

  Color _getReasonBadgeColor(String reason) {
    switch (reason) {
      case 'Duplicate':
        return AppColors.violet;
      case 'Blurry':
        return AppColors.gold;
      case 'Video':
        return const Color(0xFF2563EB);
      case 'Burst':
        return const Color(0xFFEA580C);
      default:
        return Colors.black.withValues(alpha: 0.7);
    }
  }

  List<AssetEntity> _getFilteredCandidates(ScanProvider provider) {
    final all = provider.smartCleanCandidates;
    switch (_activeFilter) {
      case SmartCleanFilter.all:
        return all;
      case SmartCleanFilter.duplicates:
        final Set<String> dupIds = {};
        for (final g in provider.duplicateGroups) {
          if (g.length > 1) {
            for (int i = 1; i < g.length; i++) {
              dupIds.add(g[i].id);
            }
          }
        }
        return all.where((a) => dupIds.contains(a.id)).toList();
      case SmartCleanFilter.blurry:
        final Set<String> blurIds = provider.blurryPhotos
            .map((b) => b.id)
            .toSet();
        return all.where((a) => blurIds.contains(a.id)).toList();
      case SmartCleanFilter.videos:
        return all.where((a) => a.type == AssetType.video).toList();
      case SmartCleanFilter.bursts:
        final Set<String> burstIds = {};
        for (final g in provider.similarGroups) {
          if (g.length > 1) {
            for (int i = 1; i < g.length; i++) {
              burstIds.add(g[i].id);
            }
          }
        }
        return all.where((a) => burstIds.contains(a.id)).toList();
    }
  }

  Future<void> _cleanSelected() async {
    if (_isProcessing || _selectedIds.isEmpty) return;
    _isProcessing = true;
    try {
      final canTrash = await MediaService.supportsTrash();
      if (!mounted) return;
      final provider = context.read<ScanProvider>();
      int selectedSize = 0;
      for (var id in _selectedIds) {
        selectedSize += provider.assetSizes[id] ?? 0;
      }

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
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
              ),
              const Gap(12),
              const Expanded(child: Text('Delete Selected Items?')),
            ],
          ),
          content: Text(
            canTrash
                ? '${_selectedIds.length} item(s) will be moved to Trash. ${AppUtils.formatBytes(selectedSize)} can be reclaimed after Trash is emptied.'
                : '${_selectedIds.length} item(s) will be permanently deleted to free up ${AppUtils.formatBytes(selectedSize)}.',
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
              icon: const Icon(Icons.delete_forever_rounded, size: 18),
              label: Text(canTrash ? 'Move to Trash' : 'Delete Permanently'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        HapticFeedback.mediumImpact();
        final count = await context.read<ScanProvider>().smartClean(
          specificIds: _selectedIds.toList(),
        );
        if (mounted && count > 0) {
          await showOperationResult(
            context,
            message: 'Removed $count items from the gallery.',
          );
          if (!mounted) return;
          Navigator.pop(context);
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
      subtitle: asset.type == AssetType.video
          ? 'Large Video'
          : 'Reclaimable Item',
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

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScanProvider>(
      builder: (context, provider, child) {
        final allCandidates = provider.smartCleanCandidates;
        final displayedCandidates = _getFilteredCandidates(provider);

        final candidateIds = allCandidates.map((asset) => asset.id).toSet();
        _selectedIds.retainAll(candidateIds);

        int selectedSize = 0;
        for (var id in _selectedIds) {
          selectedSize += provider.assetSizes[id] ?? 0;
        }

        final isFilteredAllSelected =
            displayedCandidates.isNotEmpty &&
            displayedCandidates.every((a) => _selectedIds.contains(a.id));

        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                const Text(
                  'Reclaimable Items Review',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  '${_selectedIds.length} of ${allCandidates.length} selected (${AppUtils.formatBytes(selectedSize)})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isFilteredAllSelected) {
                      for (final a in displayedCandidates) {
                        _selectedIds.remove(a.id);
                      }
                    } else {
                      for (final a in displayedCandidates) {
                        _selectedIds.add(a.id);
                      }
                    }
                  });
                },
                child: Text(
                  isFilteredAllSelected ? 'Deselect Tab' : 'Select Tab',
                ),
              ),
            ],
          ),
          body: allCandidates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 64,
                        color: Colors.green.withValues(alpha: 0.6),
                      ),
                      const Gap(16),
                      const Text(
                        'No reclaimable items found!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Gap(6),
                      const Text(
                        'Your gallery is fully optimized.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Subcategory Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip(
                            'All (${allCandidates.length})',
                            SmartCleanFilter.all,
                          ),
                          const Gap(8),
                          _buildFilterChip(
                            'Duplicates',
                            SmartCleanFilter.duplicates,
                          ),
                          const Gap(8),
                          _buildFilterChip('Blurry', SmartCleanFilter.blurry),
                          const Gap(8),
                          _buildFilterChip('Videos', SmartCleanFilter.videos),
                          const Gap(8),
                          _buildFilterChip('Bursts', SmartCleanFilter.bursts),
                        ],
                      ),
                    ),

                    // Info banner
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cleaning_services_rounded,
                            size: 18,
                            color: AppColors.violet,
                          ),
                          const Gap(10),
                          Expanded(
                            child: Text(
                              'Showing ${displayedCandidates.length} items. Tap any tile to preview full screen and review its selection.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Grid
                    Expanded(
                      child: displayedCandidates.isEmpty
                          ? Center(
                              child: Text(
                                'No items in this section.',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : GridView.builder(
                              cacheExtent: 800,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                MediaQuery.paddingOf(context).bottom + 100,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 0.88,
                                  ),
                              itemCount: displayedCandidates.length,
                              itemBuilder: (context, index) {
                                final asset = displayedCandidates[index];
                                final isSelected = _selectedIds.contains(
                                  asset.id,
                                );
                                final isVideo = asset.type == AssetType.video;
                                final reason = _getItemReason(asset, provider);
                                final badgeColor = _getReasonBadgeColor(reason);

                                return GestureDetector(
                                  onTap: () => _openInspector(asset),
                                  child: Stack(
                                    children: [
                                      // Image Thumbnail with reliable fallback
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: AssetEntityImage(
                                            asset,
                                            isOriginal: false,
                                            thumbnailSize:
                                                const ThumbnailSize.square(300),
                                            thumbnailFormat:
                                                ThumbnailFormat.jpeg,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (context, child, progress) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Center(
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => Container(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  child: Center(
                                                    child: Icon(
                                                      isVideo
                                                          ? Icons
                                                                .videocam_rounded
                                                          : Icons.photo_rounded,
                                                      color: Colors.grey,
                                                      size: 32,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),

                                      // Selected Overlay
                                      if (isSelected)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: AppColors.error,
                                                width: 2.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              color: AppColors.error.withValues(
                                                alpha: 0.28,
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Reason / Category Badge Top-Left
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(
                                              alpha: 0.88,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isVideo) ...[
                                                const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 11,
                                                ),
                                                const Gap(2),
                                              ],
                                              Text(
                                                isVideo
                                                    ? _formatDuration(
                                                        asset.duration,
                                                      )
                                                    : reason,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Selection Checkbox Top-Right
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
                                              color: isSelected
                                                  ? AppColors.error
                                                  : Colors.black.withValues(
                                                      alpha: 0.5,
                                                    ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.check_rounded
                                                  : Icons.circle,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.transparent,
                                              size: 13,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // File Size Badge Bottom-Right
                                      if (provider.assetSizes.containsKey(
                                        asset.id,
                                      ))
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.75,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              provider.getFormattedAssetSize(
                                                asset.id,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.delete_forever_rounded),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _selectedIds.isEmpty
                        ? 'Select Items to Delete'
                        : 'Delete Selected (${_selectedIds.length} items | ${AppUtils.formatBytes(selectedSize)})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, SmartCleanFilter filter) {
    final isSelected = _activeFilter == filter;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: AppColors.violet,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) {
        HapticFeedback.selectionClick();
        setState(() => _activeFilter = filter);
      },
    );
  }
}
