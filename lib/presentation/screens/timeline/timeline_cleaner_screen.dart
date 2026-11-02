import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/app_utils.dart';
import '../../providers/scan_provider.dart';

class _MonthlyBucket {
  final int year;
  final int month;
  final String label;
  final List<AssetEntity> assets;
  int totalBytes;

  _MonthlyBucket({
    required this.year,
    required this.month,
    required this.label,
    required this.assets,
    required this.totalBytes,
  });
}

class TimelineCleanerScreen extends StatelessWidget {
  const TimelineCleanerScreen({super.key});

  List<_MonthlyBucket> _buildMonthlyBuckets(List<AssetEntity> allAssets, Map<String, int> sizes) {
    final Map<String, List<AssetEntity>> grouped = {};
    final Map<String, int> bytesMap = {};

    for (final asset in allAssets) {
      final dt = asset.createDateTime;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(asset);
      bytesMap[key] = (bytesMap[key] ?? 0) + (sizes[asset.id] ?? 0);
    }

    final List<_MonthlyBucket> buckets = [];
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // Newest first

    for (final key in sortedKeys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final dt = DateTime(year, month);
      final String label = (year < 2000 || year > DateTime.now().year + 1)
          ? 'Older / Undated Media'
          : DateFormat('MMMM yyyy').format(dt);

      buckets.add(_MonthlyBucket(
        year: year,
        month: month,
        label: label,
        assets: grouped[key]!,
        totalBytes: bytesMap[key] ?? 0,
      ));
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
    final maxBytes = buckets.isEmpty ? 1 : buckets.map((b) => b.totalBytes).reduce(max);
    final heaviestBucket = buckets.isEmpty
        ? null
        : (List<_MonthlyBucket>.from(buckets)..sort((a, b) => b.totalBytes.compareTo(a.totalBytes))).first;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Time Machine'),
      ),
      body: buckets.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timeline_rounded, color: Colors.deepPurple, size: 48),
                    ),
                    const Gap(16),
                    Text(
                      'No Media Timeline Available',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Gap(6),
                    Text(
                      'Scan your gallery to generate an interactive timeline history.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 40 + MediaQuery.paddingOf(context).bottom),
              children: [
                // Heaviest Month Spotlight Card
                if (heaviestBucket != null && heaviestBucket.totalBytes > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF654EA3).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_toggle_off_rounded, color: Colors.white, size: 24),
                            ),
                            const Gap(12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Heaviest Month Spotlight',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Peak storage consumption identified',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    heaviestBucket.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Gap(2),
                                  Text(
                                    '${heaviestBucket.assets.length} items   ${AppUtils.formatBytes(heaviestBucket.totalBytes)}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                              FilledButton.tonal(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF654EA3),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  visualDensity: VisualDensity.compact,
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
                                child: const Text('Clean Month', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(18),
                ],

                // Timeline Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly Timeline (${buckets.length} months)',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Total: ${AppUtils.formatBytes(totalGalleryBytes)}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Gap(12),

                // Month Cards
                for (final bucket in buckets) ...[
                  Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
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
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          ),
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
                                        color: const Color(0xFF654EA3).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.calendar_today_rounded,
                                        color: Color(0xFF654EA3),
                                        size: 16,
                                      ),
                                    ),
                                    const Gap(10),
                                    Text(
                                      bucket.label,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF654EA3).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        AppUtils.formatBytes(bucket.totalBytes),
                                        style: const TextStyle(
                                          color: Color(0xFF654EA3),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Gap(6),
                                    const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                                  ],
                                ),
                              ],
                            ),
                            const Gap(10),

                            // Relative Heat/Capacity Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (bucket.totalBytes / max(1, maxBytes)).clamp(0.04, 1.0),
                                minHeight: 6,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                color: const Color(0xFF654EA3),
                              ),
                            ),
                            const Gap(12),

                            // Media Thumbnail Previews
                            Row(
                              children: [
                                for (int i = 0; i < min(4, bucket.assets.length); i++)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: AssetEntityImage(
                                        bucket.assets[i],
                                        isOriginal: false,
                                        width: 54,
                                        height: 54,
                                        fit: BoxFit.cover,
                                        thumbnailSize: const ThumbnailSize.square(150),
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  '${bucket.assets.length} items',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
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
