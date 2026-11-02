import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../common/fullscreen_photo_viewer.dart';
import '../../providers/scan_provider.dart';

enum ScreenshotAgeFilter {
  olderThan30Days,
  olderThan60Days,
  olderThan90Days,
  olderThan1Year,
  allScreenshots,
}

extension ScreenshotAgeFilterLabel on ScreenshotAgeFilter {
  String get label => switch (this) {
        ScreenshotAgeFilter.olderThan30Days => '> 30 Days',
        ScreenshotAgeFilter.olderThan60Days => '> 60 Days',
        ScreenshotAgeFilter.olderThan90Days => '> 90 Days',
        ScreenshotAgeFilter.olderThan1Year => '> 1 Year',
        ScreenshotAgeFilter.allScreenshots => 'All',
      };
}

class ScreenshotCleanerScreen extends StatefulWidget {
  const ScreenshotCleanerScreen({super.key});

  @override
  State<ScreenshotCleanerScreen> createState() => _ScreenshotCleanerScreenState();
}

class _ScreenshotCleanerScreenState extends State<ScreenshotCleanerScreen> {
  ScreenshotAgeFilter _activeAgeFilter = ScreenshotAgeFilter.olderThan30Days;
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  String _sortOption = 'date_desc'; // 'date_desc', 'date_asc', 'size'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final screenshots = context.read<ScanProvider>().categories['Screenshots'] ?? [];
      final now = DateTime.now();
      final hasOld = screenshots.any((a) => now.difference(a.createDateTime).inDays >= 30);
      if (!hasOld && screenshots.isNotEmpty) {
        setState(() => _activeAgeFilter = ScreenshotAgeFilter.allScreenshots);
      }
    });
  }

  List<AssetEntity> _filterScreenshots(List<AssetEntity> screenshots, Map<String, int> sizes) {
    final now = DateTime.now();
    List<AssetEntity> filtered = screenshots.where((asset) {
      final age = now.difference(asset.createDateTime);
      return switch (_activeAgeFilter) {
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

    try {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 24),
              ),
              const Gap(12),
              const Expanded(child: Text('Move Screenshots to Trash?')),
            ],
          ),
          content: Text(
            '${_selectedIds.length} expired screenshot(s) will be sent to Trash.\n\nYou can restore them within 30 days if needed.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
              label: const Text('Move to Trash'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        HapticFeedback.mediumImpact();
        final List<String> idsToDelete = _selectedIds.toList();
        final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);

        if (mounted && result.isNotEmpty) {
          final count = result.length;
          await context.read<ScanProvider>().removeAssets(result);
          if (!mounted) return;

          setState(() {
            _selectedIds.removeWhere((id) => result.contains(id));
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully moved $count expired screenshots to Trash!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ScreenshotCleaner Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete selected screenshots')),
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
    final allScreenshots = provider.categories['Screenshots'] ?? [];
    final sizes = provider.assetSizes;

    final displayedScreenshots = _filterScreenshots(allScreenshots, sizes);

    int totalOlderThan30DaysCount = 0;
    int totalOlderThan30DaysBytes = 0;
    final now = DateTime.now();
    for (final a in allScreenshots) {
      if (now.difference(a.createDateTime).inDays >= 30) {
        totalOlderThan30DaysCount++;
        totalOlderThan30DaysBytes += sizes[a.id] ?? 0;
      }
    }

    int selectedBytes = 0;
    for (final id in _selectedIds) {
      selectedBytes += sizes[id] ?? 0;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screenshot Expiry Cleaner'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort items',
            initialValue: _sortOption,
            onSelected: (val) {
              HapticFeedback.selectionClick();
              setState(() => _sortOption = val);
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'date_desc',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 18),
                    Gap(10),
                    Text('Newest Date First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'date_asc',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    Gap(10),
                    Text('Oldest Date First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'size',
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded, size: 18),
                    Gap(10),
                    Text('Largest Size First'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Storage Overview Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F80ED).withValues(alpha: 0.3),
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
                          child: const Icon(Icons.screenshot_rounded, color: Colors.white, size: 24),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Temporary Screenshot Clutter',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${allScreenshots.length} total screenshots found',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (totalOlderThan30DaysCount > 0) ...[
                      const Gap(16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_bottom_rounded, color: Colors.white, size: 20),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$totalOlderThan30DaysCount Expired Screenshots (${AppUtils.formatBytes(totalOlderThan30DaysBytes)})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'Older than 30 days. Receipts and OTPs you likely do not need.',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF2F80ED),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                setState(() {
                                  _activeAgeFilter = ScreenshotAgeFilter.olderThan30Days;
                                  _autoSelectCurrentAgeGroup(
                                    allScreenshots.where((a) => now.difference(a.createDateTime).inDays >= 30).toList(),
                                  );
                                });
                              },
                              child: const Text('Select Expired', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Age Filter Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in ScreenshotAgeFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: _activeAgeFilter == filter,
                        onSelected: (selected) {
                          if (selected) {
                            HapticFeedback.selectionClick();
                            setState(() => _activeAgeFilter = filter);
                          }
                        },
                        selectedColor: const Color(0xFF2F80ED),
                        labelStyle: TextStyle(
                          color: _activeAgeFilter == filter ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: _activeAgeFilter == filter ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        showCheckmark: false,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Selection Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${displayedScreenshots.length} screenshots found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (displayedScreenshots.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          final currentIds = displayedScreenshots.map((a) => a.id).toSet();
                          final bool allSelected = currentIds.every((id) => _selectedIds.contains(id));
                          if (allSelected) {
                            _selectedIds.removeAll(currentIds);
                          } else {
                            _selectedIds.addAll(currentIds);
                          }
                        });
                      },
                      icon: Icon(
                        displayedScreenshots.map((a) => a.id).toSet().every((id) => _selectedIds.contains(id))
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        displayedScreenshots.map((a) => a.id).toSet().every((id) => _selectedIds.contains(id))
                            ? 'Deselect All'
                            : 'Select All',
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
                      Icon(Icons.check_circle_rounded, size: 56, color: Colors.green.withValues(alpha: 0.6)),
                      const Gap(14),
                      Text(
                        'No Screenshots Found',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Gap(4),
                      Text(
                        'No screenshots match the selected age range.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (allScreenshots.isNotEmpty && _activeAgeFilter != ScreenshotAgeFilter.allScreenshots) ...[
                        const Gap(14),
                        OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _activeAgeFilter = ScreenshotAgeFilter.allScreenshots);
                          },
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('View All Recent Screenshots'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 100 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    final asset = displayedScreenshots[index];
                    final isSelected = _selectedIds.contains(asset.id);
                    final size = sizes[asset.id] ?? 0;
                    final daysOld = now.difference(asset.createDateTime).inDays;
                    final String ageText = daysOld <= 0
                        ? 'Today'
                        : (daysOld == 1 ? '1d ago' : '${daysOld}d ago');
                    final dateStr = DateFormat('MMM d').format(asset.createDateTime);

                    return GestureDetector(
                      onTap: () => _inspectAsset(asset),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
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
                                  border: Border.all(color: AppColors.error, width: 2.5),
                                  borderRadius: BorderRadius.circular(14),
                                  color: AppColors.error.withValues(alpha: 0.32),
                                ),
                              ),
                            ),

                          // Top-Left Age Pill
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: daysOld >= 30
                                    ? Colors.amber.shade900.withValues(alpha: 0.85)
                                    : Colors.black.withValues(alpha: 0.65),
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
                                  color: isSelected ? AppColors.error : Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Icon(
                                  isSelected ? Icons.check_rounded : Icons.circle,
                                  color: isSelected ? Colors.white : Colors.transparent,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),

                          // Bottom Pill (Size & Date)
                          Positioned(
                            bottom: 5,
                            left: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$dateStr   ${AppUtils.formatBytes(size)}',
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
                  childCount: displayedScreenshots.length,
                ),
              ),
            ),
        ],
      ),

      // Bottom Bar
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 18 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_selectedIds.length} Selected',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          'Reclaim ${AppUtils.formatBytes(selectedBytes)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isProcessing ? null : _cleanSelected,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    label: const Text('Move to Trash', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
