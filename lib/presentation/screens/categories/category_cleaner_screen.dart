import '../../common/operation_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/services/media_service.dart';
import '../../providers/scan_provider.dart';
import '../../common/fullscreen_photo_viewer.dart';



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
  bool _isProcessing = false;

  Future<void> _cleanSelected() async {
    if (_isProcessing || _selectedIds.isEmpty) return;
    _isProcessing = true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);

    try {
      final canTrash = await MediaService.supportsTrash();
      if (!mounted) return;
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? AppColors.trashRedDark
                              : AppColors.trashRedLight)
                          .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_sweep_rounded,
                  color: isDark
                      ? AppColors.trashRedDark
                      : AppColors.trashRedLight,
                  size: 24,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  'Delete Items?',
                  style: AppTypography.heading20(color: textColor),
                ),
              ),
            ],
          ),
          content: Text(
            '${_selectedIds.length} item(s) from ${widget.title} will be ${canTrash ? 'moved to Trash' : 'permanently deleted'}.',
            style: AppTypography.body15(color: mutedColor),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: AppTypography.meta13(color: mutedColor),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.trashRedDark
                    : AppColors.trashRedLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(
                Icons.delete_sweep_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                canTrash ? 'Move to Trash' : 'Delete Permanently',
                style: AppTypography.button15(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        HapticFeedback.mediumImpact();
        final provider = context.read<ScanProvider>();
        final count = await provider.smartClean(
          specificIds: _selectedIds.toList(),
        );
        if (mounted && count > 0) {
          setState(() {
            _selectedIds.retainWhere(
              (id) => provider.allScreenshots.any((a) => a.id == id),
            );
          });
          await showOperationResult(
            context,
            message: 'Removed $count items from ${widget.title}.',
          );
          if (!mounted) return;

          final liveIds = provider.allScreenshots
              .map((asset) => asset.id)
              .toSet();
          final remaining = widget.title == 'Large Videos'
              ? provider.largeVideos.length
              : (widget.title == 'Blurry Photos'
                    ? provider.blurryPhotos.length
                    : (provider.categories[widget.title]?.length ??
                          widget.assets
                              .where((asset) => liveIds.contains(asset.id))
                              .length));
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

  List<AssetEntity> _sortAssets(
    List<AssetEntity> rawAssets,
    Map<String, int> assetSizes,
  ) {
    final list = List<AssetEntity>.from(rawAssets);
    list.sort((a, b) {
      final sizeA = assetSizes[a.id] ?? 0;
      final sizeB = assetSizes[b.id] ?? 0;
      return sizeB.compareTo(sizeA);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final liveIds = provider.allScreenshots.map((asset) => asset.id).toSet();
    final currentAssets = widget.title == 'Large Videos'
        ? provider.largeVideos
        : widget.title == 'Blurry Photos'
        ? provider.blurryPhotos
        : provider.categories[widget.title] ??
              widget.assets
                  .where((asset) => liveIds.contains(asset.id))
                  .toList();
    final currentIds = currentAssets.map((asset) => asset.id).toSet();
    _selectedIds.retainAll(currentIds);

    final displayAssets = _sortAssets(currentAssets, provider.assetSizes);

    int selectedSize = 0;
    for (var id in _selectedIds) {
      selectedSize += provider.assetSizes[id] ?? 0;
    }


    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);
    final trashRed = isDark ? AppColors.trashRedDark : AppColors.trashRedLight;
    final lilacChip = isDark ? AppColors.violetDeep : AppColors.lilac;
    final lilacChipText = isDark ? AppColors.lilac : AppColors.ink;

    final displayedIds = displayAssets.map((a) => a.id).toSet();
    final bool allCurrentSelected =
        displayedIds.isNotEmpty &&
        displayedIds.every((id) => _selectedIds.contains(id));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppTypography.heading20(color: textColor),
            ),
            Text(
              '${_selectedIds.length} of ${displayAssets.length} selected',
              style: AppTypography.caption11(
                color: mutedColor,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          if (displayAssets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: lilacChip,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (allCurrentSelected) {
                      _selectedIds.removeAll(displayedIds);
                    } else {
                      _selectedIds.addAll(displayedIds);
                    }
                  });
                },
                child: Text(
                  allCurrentSelected ? 'Deselect' : 'Select all',
                  style: AppTypography.meta13(
                    color: lilacChipText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: currentAssets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 52,
                        color: AppColors.gold,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'Category Clean!',
                      style: AppTypography.title30(color: textColor),
                    ),
                    const Gap(6),
                    Text(
                      'No media remaining in this category.',
                      style: AppTypography.body15(color: mutedColor),
                    ),
                  ],
                ),
              ),
            )
          : displayAssets.isEmpty
              ? Center(
                  child: Text(
                    'No items in this category',
                    style: AppTypography.body15(color: mutedColor),
                  ),
                )
              : GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            110 + MediaQuery.paddingOf(context).bottom,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.8,
                              ),
                          itemCount: displayAssets.length,
                          itemBuilder: (ctx, index) {
                            final asset = displayAssets[index];
                            final isSelected = _selectedIds.contains(asset.id);
                            final size = provider.assetSizes[asset.id] ?? 0;
                            final isVideo = asset.type == AssetType.video;

                            return GestureDetector(
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
                              onLongPress: () => _openInspector(asset),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: AssetEntityImage(
                                        asset,
                                        isOriginal: false,
                                        thumbnailSize:
                                            const ThumbnailSize.square(300),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),

                                  if (isSelected)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: trashRed,
                                            width: 2.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          color: trashRed.withValues(
                                            alpha: 0.32,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Video Badge Top-Left
                                  if (isVideo)
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.7,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          AppUtils.formatDuration(
                                            Duration(seconds: asset.duration),
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Checkbox Top-Right
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? trashRed
                                            : Colors.black.withValues(
                                                alpha: 0.55,
                                              ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.delete_outline_rounded
                                            : Icons.circle,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        size: 12,
                                      ),
                                    ),
                                  ),

                                  // Bottom Size Pill
                                  Positioned(
                                    bottom: 5,
                                    left: 5,
                                    right: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.65,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        AppUtils.formatBytes(size),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
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

      // Sticky Bottom Reclaim Bar
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.ink2 : AppColors.ink,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedIds.length} selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.subheading17(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Reclaim ${AppUtils.formatBytes(selectedSize)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.meta13(color: AppColors.lilac),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.ink,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isProcessing ? null : _cleanSelected,
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      size: 20,
                      color: AppColors.ink,
                    ),
                    label: Text(
                      'Delete Selected',
                      style: AppTypography.button15(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

}
