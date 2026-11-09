import '../../common/operation_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/services/media_service.dart';
import '../../common/fullscreen_photo_viewer.dart';
import '../../providers/scan_provider.dart';

enum ScreenshotAgeFilter {
  olderThan7Days,
  olderThan30Days,
  olderThan60Days,
  olderThan90Days,
  olderThan1Year,
  allScreenshots,
}

extension ScreenshotAgeFilterLabel on ScreenshotAgeFilter {
  String get label => switch (this) {
    ScreenshotAgeFilter.olderThan7Days => 'Over 7 days',
    ScreenshotAgeFilter.olderThan30Days => 'Over 30 days',
    ScreenshotAgeFilter.olderThan60Days => 'Over 60 days',
    ScreenshotAgeFilter.olderThan90Days => 'Over 90 days',
    ScreenshotAgeFilter.olderThan1Year => 'Over 1 year',
    ScreenshotAgeFilter.allScreenshots => 'All screenshots',
  };
}

class ScreenshotCleanerScreen extends StatefulWidget {
  const ScreenshotCleanerScreen({super.key});

  @override
  State<ScreenshotCleanerScreen> createState() =>
      _ScreenshotCleanerScreenState();
}

class _ScreenshotCleanerScreenState extends State<ScreenshotCleanerScreen> {
  ScreenshotAgeFilter _activeAgeFilter = ScreenshotAgeFilter.olderThan30Days;
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  final String _sortOption = 'date_desc'; // 'date_desc', 'date_asc', 'size'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screenshots = context.read<ScanProvider>().screenshotAssets;
      final now = DateTime.now();
      final hasOld = screenshots.any(
        (a) => now.difference(a.createDateTime).inDays >= 30,
      );
      if (!hasOld && screenshots.isNotEmpty) {
        final hasWeekOld = screenshots.any(
          (a) => now.difference(a.createDateTime).inDays >= 7,
        );
        setState(
          () => _activeAgeFilter = hasWeekOld
              ? ScreenshotAgeFilter.olderThan7Days
              : ScreenshotAgeFilter.allScreenshots,
        );
      }
    });
  }

  List<AssetEntity> _filterScreenshots(
    List<AssetEntity> screenshots,
    Map<String, int> sizes,
  ) {
    final now = DateTime.now();
    List<AssetEntity> filtered = screenshots.where((asset) {
      final age = now.difference(asset.createDateTime);
      return switch (_activeAgeFilter) {
        ScreenshotAgeFilter.olderThan7Days => age.inDays >= 7,
        ScreenshotAgeFilter.olderThan30Days => age.inDays >= 30,
        ScreenshotAgeFilter.olderThan60Days => age.inDays >= 60,
        ScreenshotAgeFilter.olderThan90Days => age.inDays >= 90,
        ScreenshotAgeFilter.olderThan1Year => age.inDays >= 365,
        ScreenshotAgeFilter.allScreenshots => true,
      };
    }).toList();

    if (_sortOption == 'size') {
      filtered.sort((a, b) => (sizes[b.id] ?? 0).compareTo(sizes[a.id] ?? 0));
    } else if (_sortOption == 'date_asc') {
      filtered.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
    } else {
      filtered.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    }

    return filtered;
  }

  void _autoSelectCurrentAgeGroup(List<AssetEntity> currentFiltered) {
    setState(() {
      _selectedIds.clear();
      for (final a in currentFiltered) {
        _selectedIds.add(a.id);
      }
    });
  }

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
                  'Delete Screenshots?',
                  style: AppTypography.heading20(color: textColor),
                ),
              ),
            ],
          ),
          content: Text(
            '${_selectedIds.length} expired screenshot(s) will be ${canTrash ? 'moved to Trash' : 'permanently deleted'}.',
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
            message: 'Removed $count expired screenshots from the gallery.',
          );
          if (!mounted) return;
        }
      }
    } catch (e) {
      debugPrint('[ScreenshotCleaner Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete selected screenshots'),
          ),
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
      subtitle: 'Screenshot Preview',
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final allScreenshots = provider.screenshotAssets;
    final sizes = provider.assetSizes;

    final displayedScreenshots = _filterScreenshots(allScreenshots, sizes);

    int totalOlderThan30DaysCount = 0;
    int totalOlderThan30DaysBytes = 0;
    int totalScreenshotsBytes = 0;
    final now = DateTime.now();

    for (final a in allScreenshots) {
      final s = sizes[a.id] ?? 0;
      totalScreenshotsBytes += s;
      if (now.difference(a.createDateTime).inDays >= 30) {
        totalOlderThan30DaysCount++;
        totalOlderThan30DaysBytes += s;
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

    final displayedIds = displayedScreenshots.map((a) => a.id).toSet();
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
              'Screenshot expiry',
              style: AppTypography.heading20(color: textColor),
            ),
            Text(
              '${allScreenshots.length} screenshots | ${AppUtils.formatBytes(totalScreenshotsBytes)}',
              style: AppTypography.caption11(
                color: mutedColor,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          if (displayedScreenshots.isNotEmpty)
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
      body: CustomScrollView(
        slivers: [
          // Gold Hero Card (Pages 14 & 44)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'EXPIRED',
                            style: AppTypography.caption11(
                              color: AppColors.gold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (totalOlderThan30DaysCount > 0)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              foregroundColor: Colors.white,
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
                                _activeAgeFilter =
                                    ScreenshotAgeFilter.olderThan30Days;
                                _autoSelectCurrentAgeGroup(
                                  allScreenshots
                                      .where(
                                        (a) =>
                                            now
                                                .difference(a.createDateTime)
                                                .inDays >=
                                            30,
                                      )
                                      .toList(),
                                );
                              });
                            },
                            child: Text(
                              'Select expired',
                              style: AppTypography.button15(
                                color: Colors.white,
                              ).copyWith(fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                    const Gap(14),
                    Text(
                      AppUtils.formatBytes(totalOlderThan30DaysBytes),
                      style: AppTypography.display48(color: AppColors.ink),
                    ),
                    const Gap(6),
                    Text(
                      '$totalOlderThan30DaysCount old OTPs, tickets, receipts, and order confirmations',
                      style: AppTypography.body15(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Age Filter Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in ScreenshotAgeFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _activeAgeFilter = filter);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _activeAgeFilter == filter
                                ? AppColors.violet
                                : cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            filter.label,
                            style: AppTypography.meta13(
                              color: _activeAgeFilter == filter
                                  ? Colors.white
                                  : textColor,
                              fontWeight: _activeAgeFilter == filter
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Section Counter Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${displayedScreenshots.length} screenshots found',
                    style: AppTypography.meta13(
                      color: mutedColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _activeAgeFilter.label,
                    style: AppTypography.caption11(
                      color: mutedColor,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Screenshot Grid
          if (displayedScreenshots.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 48,
                          color: AppColors.gold,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        'No Screenshots Found',
                        style: AppTypography.title30(color: textColor),
                      ),
                      const Gap(6),
                      Text(
                        'No screenshots match the selected age range.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body15(color: mutedColor),
                      ),
                      if (allScreenshots.isNotEmpty &&
                          _activeAgeFilter !=
                              ScreenshotAgeFilter.allScreenshots) ...[
                        const Gap(16),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: lilacChip,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _activeAgeFilter =
                                  ScreenshotAgeFilter.allScreenshots,
                            );
                          },
                          child: Text(
                            'View All Screenshots',
                            style: AppTypography.button15(color: lilacChipText),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                120 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate((ctx, index) {
                  final asset = displayedScreenshots[index];
                  final isSelected = _selectedIds.contains(asset.id);
                  final size = sizes[asset.id] ?? 0;
                  final daysOld = now.difference(asset.createDateTime).inDays;
                  final String ageText = daysOld <= 0
                      ? 'Today'
                      : (daysOld == 1 ? '1d ago' : '${daysOld}d ago');
                  final dateStr = DateFormat(
                    'MMM d',
                  ).format(asset.createDateTime);

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
                            borderRadius: BorderRadius.circular(16),
                            child: AssetEntityImage(
                              asset,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(300),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: trashRed, width: 2.5),
                                borderRadius: BorderRadius.circular(16),
                                color: trashRed.withValues(alpha: 0.32),
                              ),
                            ),
                          ),

                        // Top-Left Age Pill
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ageText,
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
                                  : Colors.black.withValues(alpha: 0.55),
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

                        // Bottom Pill (Size & Date)
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
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$dateStr | ${AppUtils.formatBytes(size)}',
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
                }, childCount: displayedScreenshots.length),
              ),
            ),
        ],
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
                          'Reclaim ${AppUtils.formatBytes(selectedBytes)}',
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
