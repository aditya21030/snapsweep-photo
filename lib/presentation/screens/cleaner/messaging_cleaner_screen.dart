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
import '../../common/fullscreen_photo_viewer.dart';
import '../../providers/scan_provider.dart';

enum MessagingTabFilter {
  sent,
  videos,
  photos,
  all,
}

extension MessagingTabFilterLabel on MessagingTabFilter {
  String get label => switch (this) {
        MessagingTabFilter.sent => 'Sent copies',
        MessagingTabFilter.videos => 'Videos',
        MessagingTabFilter.photos => 'Photos',
        MessagingTabFilter.all => 'All media',
      };
}

class MessagingCleanerScreen extends StatefulWidget {
  const MessagingCleanerScreen({super.key});

  @override
  State<MessagingCleanerScreen> createState() => _MessagingCleanerScreenState();
}

class _MessagingCleanerScreenState extends State<MessagingCleanerScreen> {
  MessagingTabFilter _currentFilter = MessagingTabFilter.sent;
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  String _sortOption = 'size'; // 'size' or 'date'

  bool _isSentMedia(AssetEntity asset, Map<String, String> albumMap) {
    final album = (albumMap[asset.id] ?? '').toLowerCase();
    final relPath = (asset.relativePath ?? '').toLowerCase();

    // Check direct album name conventions
    if (album == 'sent' ||
        album.endsWith('/sent') ||
        album.endsWith('\\sent') ||
        album.contains('/sent/') ||
        album.contains('\\sent\\') ||
        album.contains('sent images') ||
        album.contains('sent video') ||
        album.contains('sent animated')) {
      return true;
    }

    // Check relative directory path conventions
    if (relPath.contains('/sent/') ||
        relPath.contains('\\sent\\') ||
        relPath.endsWith('/sent') ||
        relPath.endsWith('\\sent') ||
        relPath.startsWith('sent/') ||
        relPath.startsWith('sent\\')) {
      return true;
    }

    // Match discrete folder token "sent"
    final folderPattern = RegExp(r'(^|[\\/_\s])sent([\\/_\s]|$)', caseSensitive: false);
    return folderPattern.hasMatch(album) || folderPattern.hasMatch(relPath);
  }

  List<AssetEntity> _filterAssets(
    List<AssetEntity> allSocial,
    Map<String, String> albumMap,
  ) {
    List<AssetEntity> result = [];
    switch (_currentFilter) {
      case MessagingTabFilter.sent:
        result = allSocial.where((a) => _isSentMedia(a, albumMap)).toList();
        break;
      case MessagingTabFilter.videos:
        result = allSocial.where((a) => a.type == AssetType.video && !_isSentMedia(a, albumMap)).toList();
        break;
      case MessagingTabFilter.photos:
        result = allSocial.where((a) => a.type == AssetType.image && !_isSentMedia(a, albumMap)).toList();
        break;
      case MessagingTabFilter.all:
        result = List.from(allSocial);
        break;
    }

    final sizes = context.read<ScanProvider>().assetSizes;
    if (_sortOption == 'size') {
      result.sort((a, b) => (sizes[b.id] ?? 0).compareTo(sizes[a.id] ?? 0));
    } else {
      result.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
    }
    return result;
  }

  int _calculateBytes(Iterable<AssetEntity> assets, Map<String, int> sizes) {
    int total = 0;
    for (final a in assets) {
      total += sizes[a.id] ?? 0;
    }
    return total;
  }

  Future<void> _deleteSelected(List<String> idsToDelete) async {
    if (idsToDelete.isEmpty || _isProcessing) return;
    _isProcessing = true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark ? AppColors.lavender.withValues(alpha: 0.7) : AppColors.ink.withValues(alpha: 0.6);

    try {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.trashRedDark : AppColors.trashRedLight).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_sweep_rounded,
                  color: isDark ? AppColors.trashRedDark : AppColors.trashRedLight,
                  size: 24,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Text(
                  'Move to Trash?',
                  style: AppTypography.heading20(color: textColor),
                ),
              ),
            ],
          ),
          content: Text(
            '${idsToDelete.length} messaging file(s) will be moved to device Trash.\n\nYou can restore them within 30 days if needed.',
            style: AppTypography.body15(color: mutedColor),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppTypography.meta13(color: mutedColor)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? AppColors.trashRedDark : AppColors.trashRedLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.white),
              label: Text('Move to Trash', style: AppTypography.button15(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        HapticFeedback.mediumImpact();
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
              backgroundColor: AppColors.ink,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              content: Text(
                'Moved $count messaging files to Trash',
                style: AppTypography.body15(color: Colors.white),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[MessagingCleaner] Deletion error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete selected items')),
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
      subtitle: _currentFilter.label,
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
    final allSocial = provider.categories['Social & WhatsApp'] ?? [];
    final albumMap = provider.assetAlbumMap;
    final sizes = provider.assetSizes;

    final displayedAssets = _filterAssets(allSocial, albumMap);
    final sentAssets = allSocial.where((a) => _isSentMedia(a, albumMap)).toList();

    final totalSocialBytes = _calculateBytes(allSocial, sizes);
    final totalSentBytes = _calculateBytes(sentAssets, sizes);

    int selectedBytes = 0;
    for (final id in _selectedIds) {
      selectedBytes += sizes[id] ?? 0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final cardBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark ? AppColors.lavender.withValues(alpha: 0.7) : AppColors.ink.withValues(alpha: 0.6);
    final trashRed = isDark ? AppColors.trashRedDark : AppColors.trashRedLight;
    final lilacChip = isDark ? AppColors.violetDeep : AppColors.lilac;
    final lilacChipText = isDark ? AppColors.lilac : AppColors.ink;

    final displayedIds = displayedAssets.map((a) => a.id).toSet();
    final bool allCurrentSelected = displayedIds.isNotEmpty && displayedIds.every((id) => _selectedIds.contains(id));

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
              'WhatsApp and social',
              style: AppTypography.heading20(color: textColor),
            ),
            Text(
              '${allSocial.length} items | ${AppUtils.formatBytes(totalSocialBytes)}',
              style: AppTypography.caption11(color: mutedColor, letterSpacing: 0),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: textColor),
            tooltip: 'Sort items',
            color: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            initialValue: _sortOption,
            onSelected: (val) {
              HapticFeedback.selectionClick();
              setState(() => _sortOption = val);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'size',
                child: Text('Largest size first', style: AppTypography.meta13(color: textColor)),
              ),
              PopupMenuItem(
                value: 'date',
                child: Text('Newest date first', style: AppTypography.meta13(color: textColor)),
              ),
            ],
          ),
          if (displayedAssets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: lilacChip,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  style: AppTypography.meta13(color: lilacChipText, fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Violet Hero Card (Pages 16 & 46)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.violet,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.lilac,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'QUICK CLEAN',
                            style: AppTypography.caption11(color: AppColors.ink, letterSpacing: 0.8),
                          ),
                        ),
                        if (sentAssets.isNotEmpty)
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _currentFilter = MessagingTabFilter.sent;
                                _selectedIds.clear();
                                for (final a in sentAssets) {
                                  _selectedIds.add(a.id);
                                }
                              });
                            },
                            child: Text(
                              'Clean sent copies',
                              style: AppTypography.button15(color: AppColors.ink).copyWith(fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                    const Gap(14),
                    Text(
                      AppUtils.formatBytes(totalSentBytes),
                      style: AppTypography.display48(color: Colors.white),
                    ),
                    const Gap(6),
                    Text(
                      '${sentAssets.length} hidden sent copies from chats you already delivered',
                      style: AppTypography.body15(color: AppColors.lilac, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filter Tabs (Sent copies, Videos, Photos, All media)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final tab in MessagingTabFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _currentFilter = tab);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _currentFilter == tab
                                ? AppColors.violet
                                : cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            tab.label,
                            style: AppTypography.meta13(
                              color: _currentFilter == tab
                                  ? Colors.white
                                  : textColor,
                              fontWeight: _currentFilter == tab ? FontWeight.w700 : FontWeight.w500,
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
                    '${displayedAssets.length} ${_currentFilter.label.toLowerCase()} found',
                    style: AppTypography.meta13(color: mutedColor, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    AppUtils.formatBytes(_calculateBytes(displayedAssets, sizes)),
                    style: AppTypography.caption11(color: mutedColor, letterSpacing: 0),
                  ),
                ],
              ),
            ),
          ),

          // Media Grid
          if (displayedAssets.isEmpty)
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
                        child: const Icon(Icons.forum_outlined, size: 48, color: AppColors.gold),
                      ),
                      const Gap(16),
                      Text(
                        'No Items in ${_currentFilter.label}',
                        style: AppTypography.title30(color: textColor),
                      ),
                      const Gap(6),
                      Text(
                        'No messaging media matched this category filter.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body15(color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 120 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    final asset = displayedAssets[index];
                    final isSelected = _selectedIds.contains(asset.id);
                    final size = sizes[asset.id] ?? 0;
                    final isSent = _isSentMedia(asset, albumMap);
                    final isVideo = asset.type == AssetType.video;
                    final dateStr = DateFormat('MMM d').format(asset.createDateTime);

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

                          // Top-Left Sent / Video Pill
                          if (isSent || isVideo)
                            Positioned(
                              top: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isSent ? 'Sent' : (isVideo ? 'Video' : ''),
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
                                color: isSelected ? trashRed : Colors.black.withValues(alpha: 0.55),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Icon(
                                isSelected ? Icons.delete_outline_rounded : Icons.circle,
                                color: isSelected ? Colors.white : Colors.transparent,
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
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                  },
                  childCount: displayedAssets.length,
                ),
              ),
            ),
        ],
      ),

      // Sticky Bottom Reclaim Bar
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + MediaQuery.paddingOf(context).bottom),
              decoration: BoxDecoration(
                color: isDark ? AppColors.ink2 : AppColors.ink,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                          style: AppTypography.subheading17(color: Colors.white),
                        ),
                        Text(
                          'Reclaim ${AppUtils.formatBytes(selectedBytes)}',
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
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isProcessing ? null : () => _deleteSelected(_selectedIds.toList()),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20, color: AppColors.ink),
                    label: Text(
                      'Move to Trash',
                      style: AppTypography.button15(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
