import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
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
        MessagingTabFilter.sent => 'Sent Copies',
        MessagingTabFilter.videos => 'Videos',
        MessagingTabFilter.photos => 'Photos',
        MessagingTabFilter.all => 'All Media',
      };

  IconData get icon => switch (this) {
        MessagingTabFilter.sent => Icons.outbox_rounded,
        MessagingTabFilter.videos => Icons.videocam_rounded,
        MessagingTabFilter.photos => Icons.photo_rounded,
        MessagingTabFilter.all => Icons.forum_rounded,
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
    final path = '${asset.relativePath ?? ''} ${albumMap[asset.id] ?? ''} ${asset.title ?? ''}'.toLowerCase();
    return path.contains('sent') || path.contains('/sent/') || path.contains('sent images') || path.contains('sent video');
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
              const Expanded(child: Text('Move to Trash?')),
            ],
          ),
          content: Text(
            '${idsToDelete.length} messaging file(s) will be moved to your device\'s Trash.\n\nYou can restore them within 30 days if needed.',
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
              content: Text('Moved $count messaging files to Trash'),
              behavior: SnackBarBehavior.floating,
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
    final videoAssets = allSocial.where((a) => a.type == AssetType.video && !_isSentMedia(a, albumMap)).toList();
    final photoAssets = allSocial.where((a) => a.type == AssetType.image && !_isSentMedia(a, albumMap)).toList();

    final totalSocialBytes = _calculateBytes(allSocial, sizes);
    final totalSentBytes = _calculateBytes(sentAssets, sizes);

    int selectedBytes = 0;
    for (final id in _selectedIds) {
      selectedBytes += sizes[id] ?? 0;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp & Social Clean'),
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
                value: 'size',
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded, size: 18),
                    Gap(10),
                    Text('Largest Size First'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 18),
                    Gap(10),
                    Text('Newest Date First'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Overview Storage Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F9D58), Color(0xFF00796B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F9D58).withValues(alpha: 0.3),
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
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.forum_rounded, color: Colors.white, size: 24),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Messaging Storage',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                ),
                              ),
                              Text(
                                '${allSocial.length} files | ${AppUtils.formatBytes(totalSocialBytes)} occupied',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Quick Clean Sent Copies Recommendation
                    if (sentAssets.isNotEmpty) ...[
                      const Gap(16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, color: Colors.greenAccent, size: 20),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${sentAssets.length} Sent Copies (${AppUtils.formatBytes(totalSentBytes)})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Text(
                                    'Redundant copies of photos you sent. Safe to clean.',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF00796B),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                _deleteSelected(sentAssets.map((a) => a.id).toList());
                              },
                              child: const Text('Clean Sent', style: TextStyle(fontWeight: FontWeight.bold)),
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

          // 2. Sub-Category Tabs
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _buildScopeChip(
                    tab: MessagingTabFilter.sent,
                    count: sentAssets.length,
                    theme: theme,
                  ),
                  const Gap(8),
                  _buildScopeChip(
                    tab: MessagingTabFilter.videos,
                    count: videoAssets.length,
                    theme: theme,
                  ),
                  const Gap(8),
                  _buildScopeChip(
                    tab: MessagingTabFilter.photos,
                    count: photoAssets.length,
                    theme: theme,
                  ),
                  const Gap(8),
                  _buildScopeChip(
                    tab: MessagingTabFilter.all,
                    count: allSocial.length,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),

          // 3. Selection Actions Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${displayedAssets.length} ${_currentFilter.label.toLowerCase()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (displayedAssets.isNotEmpty)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          final currentIds = displayedAssets.map((a) => a.id).toSet();
                          final bool allSelected = currentIds.every((id) => _selectedIds.contains(id));
                          if (allSelected) {
                            _selectedIds.removeAll(currentIds);
                          } else {
                            _selectedIds.addAll(currentIds);
                          }
                        });
                      },
                      icon: Icon(
                        displayedAssets.map((a) => a.id).toSet().every((id) => _selectedIds.contains(id))
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        displayedAssets.map((a) => a.id).toSet().every((id) => _selectedIds.contains(id))
                            ? 'Deselect All'
                            : 'Select All',
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Grid of Media Assets
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
                          color: Colors.green.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 48,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        'No ${_currentFilter.label} Found',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Gap(6),
                      Text(
                        'Your messaging media in this section is completely clean.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 96 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    final asset = displayedAssets[index];
                    final isSelected = _selectedIds.contains(asset.id);
                    final size = sizes[asset.id] ?? 0;
                    final isSent = _isSentMedia(asset, albumMap);

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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: AssetEntityImage(
                              asset,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(350),
                              fit: BoxFit.cover,
                            ),
                          ),

                          // Selection Highlight Border & Tint
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.error : Colors.transparent,
                                width: 2.5,
                              ),
                              color: isSelected
                                  ? AppColors.error.withValues(alpha: 0.22)
                                  : Colors.transparent,
                            ),
                          ),

                          // Top Badges (Sent badge or Fullscreen button)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: isSent
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade800,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'SENT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black45,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(4),
                                minimumSize: const Size(28, 28),
                              ),
                              icon: const Icon(Icons.fullscreen_rounded, size: 16),
                              onPressed: () => _inspectAsset(asset),
                              tooltip: 'Inspect',
                            ),
                          ),

                          // Bottom Metadata Gradient Bar
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (size > 0)
                                    Text(
                                      AppUtils.formatBytes(size),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  if (asset.type == AssetType.video)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.play_arrow_rounded, color: Colors.amber, size: 12),
                                        Text(
                                          AppUtils.formatDuration(Duration(seconds: asset.duration)),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Selection Checkmark Circle
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.error : Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isSelected ? Icons.check_rounded : Icons.circle_outlined,
                                color: Colors.white,
                                size: 14,
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

      // Bottom Deletion Bar
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isProcessing ? null : () => _deleteSelected(_selectedIds.toList()),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    label: const Text('Move to Trash', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildScopeChip({
    required MessagingTabFilter tab,
    required int count,
    required ThemeData theme,
  }) {
    final isSelected = tab == _currentFilter;

    return ChoiceChip(
      avatar: Icon(
        tab.icon,
        size: 15,
        color: isSelected ? Colors.white : theme.colorScheme.primary,
      ),
      label: Text('${tab.label} ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentFilter = tab;
          });
        }
      },
      selectedColor: const Color(0xFF0F9D58),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      showCheckmark: false,
    );
  }
}
