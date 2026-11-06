import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_utils.dart';
import '../../providers/scan_provider.dart';

class _MonthlyBucket {
  final int year;
  final int month;
  final String label;
  final List<AssetEntity> assets;
  final int totalBytes;
  final int tripClusterCount;

  _MonthlyBucket({
    required this.year,
    required this.month,
    required this.label,
    required this.assets,
    required this.totalBytes,
    this.tripClusterCount = 0,
  });
}

class TimelineCleanerScreen extends StatelessWidget {
  const TimelineCleanerScreen({super.key});

  List<_MonthlyBucket> _buildMonthlyBuckets(
    List<AssetEntity> allAssets,
    Map<String, int> sizes,
  ) {
    final Map<String, List<AssetEntity>> grouped = {};
    final Map<String, int> bytesMap = {};

    for (final asset in allAssets) {
      final dt = asset.createDateTime;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(asset);
      bytesMap[key] = (bytesMap[key] ?? 0) + (sizes[asset.id] ?? 0);
    }

    final List<_MonthlyBucket> buckets = [];
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Newest first

    for (final key in sortedKeys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final dt = DateTime(year, month);
      final String label = (year < 2000 || year > DateTime.now().year + 1)
          ? 'Older / Undated Media'
          : DateFormat('MMMM yyyy').format(dt);

      final bucketAssets = grouped[key]!;

      // Event & Trip Clustering: detect photographic density spikes (>= 20 photos in a single day)
      int tripClusterCount = 0;
      final Map<int, int> dayCounts = {};
      for (final a in bucketAssets) {
        dayCounts[a.createDateTime.day] =
            (dayCounts[a.createDateTime.day] ?? 0) + 1;
      }
      for (final count in dayCounts.values) {
        if (count >= 20) {
          tripClusterCount += count;
        }
      }

      buckets.add(
        _MonthlyBucket(
          year: year,
          month: month,
          label: label,
          assets: bucketAssets,
          totalBytes: bytesMap[key] ?? 0,
          tripClusterCount: tripClusterCount,
        ),
      );
    }

    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final allAssets = provider.allScreenshots;
    final sizes = provider.assetSizes;
    final totalGalleryBytes = provider.totalSize;

    final buckets = _buildMonthlyBuckets(allAssets, sizes);
    final maxBytes = buckets.isEmpty
        ? 1
        : buckets.map((b) => b.totalBytes).reduce(max);
    final heaviestBucket = buckets.isEmpty
        ? null
        : (List<_MonthlyBucket>.from(
            buckets,
          )..sort((a, b) => b.totalBytes.compareTo(a.totalBytes))).first;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final cardBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);

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
              'Storage time machine',
              style: AppTypography.heading20(color: textColor),
            ),
            Text(
              '${allAssets.length} items | ${AppUtils.formatBytes(totalGalleryBytes)}',
              style: AppTypography.caption11(
                color: mutedColor,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
      body: buckets.isEmpty
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
                        Icons.timeline_rounded,
                        color: AppColors.gold,
                        size: 48,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'No Media Timeline Available',
                      style: AppTypography.title30(color: textColor),
                    ),
                    const Gap(6),
                    Text(
                      'Scan your gallery to generate an interactive timeline history.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body15(color: mutedColor),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                40 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // Heaviest Month Spotlight Card (Pages 17 & 47)
                if (heaviestBucket != null &&
                    heaviestBucket.totalBytes > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.ink2 : AppColors.ink,
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
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'HEAVIEST MONTH',
                                style: AppTypography.caption11(
                                  color: AppColors.ink,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.ink,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                context.push(
                                  '/category-cleaner',
                                  extra: {
                                    'title': heaviestBucket.label,
                                    'assets': heaviestBucket.assets,
                                  },
                                );
                              },
                              child: Text(
                                'Clean month',
                                style: AppTypography.button15(
                                  color: AppColors.ink,
                                ).copyWith(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const Gap(14),
                        Text(
                          heaviestBucket.label,
                          style: AppTypography.title30(color: Colors.white),
                        ),
                        const Gap(4),
                        Text(
                          '${AppUtils.formatBytes(heaviestBucket.totalBytes)} | ${heaviestBucket.assets.length} items',
                          style: AppTypography.body15(color: AppColors.lilac),
                        ),
                      ],
                    ),
                  ),
                  const Gap(18),
                ],

                // Timeline Section Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly breakdown (${buckets.length} months)',
                        style: AppTypography.meta13(
                          color: mutedColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Total: ${AppUtils.formatBytes(totalGalleryBytes)}',
                        style: AppTypography.caption11(
                          color: mutedColor,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(10),

                // Month Cards
                for (final bucket in buckets) ...[
                  Material(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push(
                          '/category-cleaner',
                          extra: {
                            'title': bucket.label,
                            'assets': bucket.assets,
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.violet.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.calendar_today_rounded,
                                        color: AppColors.violet,
                                        size: 16,
                                      ),
                                    ),
                                    const Gap(10),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bucket.label,
                                          style: AppTypography.subheading17(
                                            color: textColor,
                                          ),
                                        ),
                                        if (bucket.tripClusterCount >= 20) ...[
                                          const Gap(4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.gold.withValues(
                                                alpha: 0.18,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.flight_takeoff_rounded,
                                                  color: AppColors.gold,
                                                  size: 11,
                                                ),
                                                const Gap(4),
                                                Text(
                                                  'Trip / Event (${bucket.tripClusterCount})',
                                                  style:
                                                      AppTypography.caption11(
                                                        color: isDark
                                                            ? AppColors.gold
                                                            : AppColors.ink,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.violetDeep
                                            : AppColors.lilac,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        AppUtils.formatBytes(bucket.totalBytes),
                                        style: AppTypography.meta13(
                                          color: isDark
                                              ? AppColors.lilac
                                              : AppColors.ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Gap(6),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: mutedColor,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Gap(12),

                            // Relative Heat/Capacity Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (bucket.totalBytes / max(1, maxBytes))
                                    .clamp(0.04, 1.0),
                                minHeight: 6,
                                backgroundColor: isDark
                                    ? AppColors.ink
                                    : AppColors.lavender,
                                color: AppColors.violet,
                              ),
                            ),
                            const Gap(12),

                            // Media Thumbnail Previews
                            Row(
                              children: [
                                for (
                                  int i = 0;
                                  i < min(4, bucket.assets.length);
                                  i++
                                )
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AssetEntityImage(
                                        bucket.assets[i],
                                        isOriginal: false,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        thumbnailSize:
                                            const ThumbnailSize.square(150),
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  '${bucket.assets.length} items',
                                  style: AppTypography.caption11(
                                    color: mutedColor,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Gap(12),
                ],
              ],
            ),
    );
  }
}
