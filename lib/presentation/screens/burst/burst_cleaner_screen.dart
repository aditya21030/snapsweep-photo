import '../../common/operation_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/services/media_service.dart';
import '../../common/fullscreen_photo_viewer.dart';
import '../../providers/scan_provider.dart';

class BurstCleanerScreen extends StatefulWidget {
  const BurstCleanerScreen({super.key});

  @override
  State<BurstCleanerScreen> createState() => _BurstCleanerScreenState();
}

class _BurstCleanerScreenState extends State<BurstCleanerScreen> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  bool _hasAutoSelected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoSelectInferiorShots();
    });
  }

  void _autoSelectInferiorShots() {
    final provider = context.read<ScanProvider>();
    final groups = provider.similarGroups;
    if (groups.isEmpty) return;

    setState(() {
      _selectedIds.clear();
      for (final group in groups) {
        if (group.length > 1) {
          // Index 0 is the crowned "Best Shot". Select index 1..n for trashing.
          for (int i = 1; i < group.length; i++) {
            _selectedIds.add(group[i].id);
          }
        }
      }
      _hasAutoSelected = true;
    });
  }

  Future<void> _cleanSelected() async {
    if (_isProcessing ||
        _selectedIds.isEmpty ||
        context.read<ScanProvider>().isLoading) {
      return;
    }
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
                  'Delete Photos?',
                  style: AppTypography.heading20(color: textColor),
                ),
              ),
            ],
          ),
          content: Text(
            '${_selectedIds.length} redundant burst photo(s) will be ${canTrash ? 'moved to Trash' : 'permanently deleted'}.\n\nYour best crowned shots will be kept.',
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
        final List<String> idsToDelete = _selectedIds.toList();
        final List<String> result = await MediaService.removeAssetsWithIds(
          idsToDelete,
        );

        if (mounted && result.isNotEmpty) {
          final count = result.length;
          await context.read<ScanProvider>().removeAssets(result);
          if (!mounted) return;

          setState(() {
            _selectedIds.removeWhere((id) => result.contains(id));
          });

          await showOperationResult(
            context,
            message: 'Removed $count redundant shots from the gallery.',
          );
          if (!mounted) return;
        }
      }
    } catch (e) {
      debugPrint('[BurstCleaner Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete selected photos')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _inspectAsset(AssetEntity asset) async {
    final isSelected = _selectedIds.contains(asset.id);
    final result = await FullscreenPhotoViewer.open(
      context,
      asset: asset,
      isSelected: isSelected,
      subtitle: 'Burst Sequence',
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

  String _getShotDefectTag(
    ScanProvider provider,
    AssetEntity asset,
    AssetEntity bestShot,
  ) {
    final blurType = provider.getAssetBlurType(asset.id);
    if (blurType == 'motion') {
      return 'Motion blur';
    }
    if (blurType == 'out_of_focus') {
      return 'Out of focus';
    }
    final sharpness = provider.getAssetSharpness(asset.id);
    final bestSharpness = provider.getAssetSharpness(bestShot.id);
    if (sharpness < 70.0) {
      return 'Soft focus';
    }
    if (bestSharpness - sharpness > 10.0) {
      return 'Lower clarity';
    }
    return 'Duplicate angle';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final groups = provider.similarGroups;
    final sizes = provider.assetSizes;

    if (!_hasAutoSelected && groups.isNotEmpty && _selectedIds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAutoSelected) {
          _autoSelectInferiorShots();
        }
      });
    }

    int totalRedundantBytes = 0;
    for (final group in groups) {
      if (group.length > 1) {
        for (int i = 1; i < group.length; i++) {
          totalRedundantBytes += sizes[group[i].id] ?? 0;
        }
      }
    }

    int selectedBytes = 0;
    for (final id in _selectedIds) {
      selectedBytes += sizes[id] ?? 0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final cardBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);
    final trashRed = isDark ? AppColors.trashRedDark : AppColors.trashRedLight;
    final lilacChip = isDark ? AppColors.violetDeep : AppColors.lilac;
    final lilacChipText = isDark ? AppColors.lilac : AppColors.ink;

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
              'Burst and best shot',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading20(
                color: textColor,
              ).copyWith(fontSize: 17),
            ),
            if (groups.isNotEmpty)
              Text(
                '${groups.length} clusters | ${AppUtils.formatBytes(totalRedundantBytes)}',
                style: AppTypography.caption11(
                  color: mutedColor,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
        actions: [
          if (groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (_selectedIds.isEmpty) {
                    _autoSelectInferiorShots();
                  } else {
                    setState(() => _selectedIds.clear());
                  }
                },
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
                child: Text(
                  _selectedIds.isEmpty ? 'Select' : 'Clear',
                  style: AppTypography.meta13(
                    color: lilacChipText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: groups.isEmpty
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
                        Icons.workspace_premium_rounded,
                        color: AppColors.gold,
                        size: 52,
                      ),
                    ),
                    const Gap(20),
                    Text(
                      'No Burst Sequences Found',
                      style: AppTypography.title30(color: textColor),
                    ),
                    const Gap(8),
                    Text(
                      provider.scanErrorMessage ??
                          (provider.isLoading
                              ? 'Analysis is still running.'
                              : 'No matching sequences in ${provider.scanScope.label}.'),
                      textAlign: TextAlign.center,
                      style: AppTypography.body15(color: mutedColor),
                    ),
                    if (provider.scanScope != ScanScope.fullGallery)
                      TextButton(
                        onPressed: () =>
                            provider.setScanScope(ScanScope.fullGallery),
                        child: const Text('Show full gallery'),
                      ),
                    if (!provider.isLoading)
                      TextButton(
                        onPressed: provider.recheckMatches,
                        child: const Text('Recheck matches'),
                      ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                120 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const Gap(16),
              itemBuilder: (ctx, clusterIdx) {
                final group = groups[clusterIdx];
                final bestShot = group.first;
                final redundantShots = group.length > 1
                    ? group.sublist(1)
                    : <AssetEntity>[];
                final toTrashCount = group
                    .where((a) => _selectedIds.contains(a.id))
                    .length;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cluster Header Row
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.violet.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.burst_mode_rounded,
                                  size: 16,
                                  color: AppColors.violet,
                                ),
                              ),
                              const Gap(8),
                              Text(
                                'CLUSTER ${clusterIdx + 1} | ${group.length} SHOTS',
                                style: AppTypography.meta13(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: lilacChip,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$toTrashCount TO DELETE',
                              style: AppTypography.caption11(
                                color: lilacChipText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(14),

                      // Featured Best Shot Card
                      GestureDetector(
                        onTap: () => _inspectAsset(bestShot),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isDark ? AppColors.ink : AppColors.lavender,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: AssetEntityImage(
                                      bestShot,
                                      isOriginal: false,
                                      thumbnailSize: const ThumbnailSize.square(
                                        256,
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  // Gold Best Shot Badge
                                  Positioned(
                                    top: 10,
                                    left: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.workspace_premium_rounded,
                                            color: AppColors.ink,
                                            size: 14,
                                          ),
                                          const Gap(4),
                                          Text(
                                            'BEST SHOT',
                                            style: AppTypography.caption11(
                                              color: AppColors.ink,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Safe / Locked Badge
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.lock_rounded,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          const Gap(4),
                                          Text(
                                            'Locked',
                                            style: AppTypography.caption11(
                                              color: Colors.white,
                                              letterSpacing: 0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Builder(
                                            builder: (context) {
                                              final bestSharpness = provider
                                                  .getAssetSharpness(
                                                    bestShot.id,
                                                  )
                                                  .round()
                                                  .clamp(60, 100);
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 4,
                                                    children: [
                                                      Text(
                                                        'Sharpness $bestSharpness%',
                                                        style:
                                                            AppTypography.caption11(
                                                              color: textColor,
                                                              letterSpacing: 0,
                                                            ),
                                                      ),
                                                      const Gap(8),
                                                      Text(
                                                        'Best lighting & sharp focus',
                                                        style:
                                                            AppTypography.caption11(
                                                              color: mutedColor,
                                                              letterSpacing: 0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const Gap(6),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                    child: LinearProgressIndicator(
                                                      value:
                                                          (bestSharpness /
                                                                  100.0)
                                                              .clamp(0.0, 1.0),
                                                      backgroundColor:
                                                          lilacChip,
                                                      valueColor:
                                                          const AlwaysStoppedAnimation<
                                                            Color
                                                          >(AppColors.gold),
                                                      minHeight: 4,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Gap(12),
                                    Text(
                                      AppUtils.formatBytes(
                                        sizes[bestShot.id] ?? 0,
                                      ),
                                      style: AppTypography.caption11(
                                        color: mutedColor,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (redundantShots.isNotEmpty) ...[
                        const Gap(14),
                        Text(
                          'Redundant shots (${redundantShots.length})',
                          style: AppTypography.meta13(color: mutedColor),
                        ),
                        const Gap(8),
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemExtent: 114,
                            itemCount: redundantShots.length,
                            itemBuilder: (context, idx) {
                              final asset = redundantShots[idx];
                              final isSelected = _selectedIds.contains(
                                asset.id,
                              );
                              final defectTag = _getShotDefectTag(
                                provider,
                                asset,
                                bestShot,
                              );

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
                                onLongPress: () => _inspectAsset(asset),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: AssetEntityImage(
                                          asset,
                                          isOriginal: false,
                                          thumbnailSize:
                                              const ThumbnailSize.square(300),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),

                                    // Tint overlay if selected for trash
                                    if (isSelected)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: trashRed,
                                              width: 2.5,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            color: trashRed.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Issue / defect tag
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
                                          defectTag,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Selection Checkbox
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

                                    // Bottom file size
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
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          AppUtils.formatBytes(
                                            sizes[asset.id] ?? 0,
                                          ),
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
                        ),
                      ],
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
                          'Keep best, delete rest',
                          style: AppTypography.subheading17(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_selectedIds.length} shots | ${AppUtils.formatBytes(selectedBytes)}',
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
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isProcessing || provider.isLoading
                        ? null
                        : _cleanSelected,
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      size: 20,
                      color: AppColors.ink,
                    ),
                    label: Text(
                      'Delete',
                      style: AppTypography.button15(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
