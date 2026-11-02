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
              const Expanded(child: Text('Move Inferior Shots to Trash?')),
            ],
          ),
          content: Text(
            '${_selectedIds.length} redundant burst photo(s) will be moved to Trash.\n\nYour best crowned shots will be safely kept. You can restore deleted photos within 30 days if needed.',
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
              content: Text('Successfully moved $count redundant shots to Trash!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
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

    int totalInferiorCount = 0;
    int totalRedundantBytes = 0;
    for (final group in groups) {
      if (group.length > 1) {
        for (int i = 1; i < group.length; i++) {
          totalInferiorCount++;
          totalRedundantBytes += sizes[group[i].id] ?? 0;
        }
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
        title: const Text('Burst & Best Photo Selector'),
        actions: [
          if (groups.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                if (_selectedIds.isEmpty) {
                  _autoSelectInferiorShots();
                } else {
                  setState(() => _selectedIds.clear());
                }
              },
              icon: Icon(
                _selectedIds.isEmpty ? Icons.auto_fix_high_rounded : Icons.deselect_rounded,
                size: 18,
              ),
              label: Text(_selectedIds.isEmpty ? 'Select All Inferior' : 'Clear Selection'),
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.amber, size: 48),
                    ),
                    const Gap(16),
                    Text(
                      'No Burst Sequences Found',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Gap(6),
                    Text(
                      'All your photos have distinct compositions or no rapid duplicates.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Header Recommendation Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF2994A).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 26),
                        ),
                        const Gap(14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${groups.length} Burst Clusters Found',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Gap(2),
                              Text(
                                '$totalInferiorCount redundant shots occupying ${AppUtils.formatBytes(totalRedundantBytes)}. Keep the crowned best shot and clean the rest.',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Clusters List
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 100 + MediaQuery.paddingOf(context).bottom),
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const Gap(16),
                    itemBuilder: (ctx, clusterIdx) {
                      final group = groups[clusterIdx];
                      final bestShot = group.first;
                      final dateFormatted = DateFormat('MMM d, yyyy   h:mm a').format(bestShot.createDateTime);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cluster Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.burst_mode_rounded, size: 18, color: Color(0xFFF2994A)),
                                    const Gap(8),
                                    Text(
                                      'Cluster #${clusterIdx + 1} (${group.length} shots)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Text(
                                  dateFormatted,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const Gap(12),

                            // Grid of shots in cluster
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: group.length,
                              itemBuilder: (context, photoIdx) {
                                final asset = group[photoIdx];
                                final isBestShot = photoIdx == 0;
                                final isSelected = _selectedIds.contains(asset.id);
                                final size = sizes[asset.id] ?? 0;

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

                                      // Red tint if marked for trash
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

                                      // Best Shot Golden Crown Badge
                                      if (isBestShot)
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.35),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.workspace_premium_rounded, color: Colors.black87, size: 12),
                                                Gap(2),
                                                Text(
                                                  'BEST',
                                                  style: TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Selection Checkbox
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
                                                  : Colors.black.withValues(alpha: 0.55),
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

                                      // Bottom Resolution / Size Pill
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
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

      // Bottom Reclaim Bar
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
                          '${_selectedIds.length} Inferior Selected',
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
                    onPressed: _isProcessing ? null : _cleanSelected,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                    label: const Text('Trash Inferior', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
    );
  }
}
