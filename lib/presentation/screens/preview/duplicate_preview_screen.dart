import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:gap/gap.dart';
import '../../providers/scan_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../common/fullscreen_photo_viewer.dart';

enum SortOption { size, date }

class DuplicatePreviewScreen extends StatefulWidget {
  final bool isSimilar;
  const DuplicatePreviewScreen({super.key, this.isSimilar = false});

  @override
  State<DuplicatePreviewScreen> createState() => _DuplicatePreviewScreenState();
}

class _DuplicatePreviewScreenState extends State<DuplicatePreviewScreen> {
  // Set of selected asset IDs to delete
  final Set<String> _selectedIds = {};
  
  @override
  void initState() {
    super.initState();
    // Auto-select logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScanProvider>();
      final groups = widget.isSimilar ? provider.similarGroups : provider.duplicateGroups;
      
      for (var group in groups) {
        if (!widget.isSimilar && group.isNotEmpty) {
          // Select all except the first one (Keep the best one)
          for (int i = 1; i < group.length; i++) {
            _selectedIds.add(group[i].id);
          }
        }
      }
      setState(() {});
    });
  }
  
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    
    // Show reassurance dialog
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
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            ),
            const Gap(12),
            const Expanded(child: Text('Move to Trash?')),
          ],
        ),
        content: Text(
          '${_selectedIds.length} item(s) will be sent to your device\'s Trash / Recently Deleted folder.\n\nYou can easily restore them within 30 days if needed.',
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
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      HapticFeedback.mediumImpact();
      List<String> idsToDelete = _selectedIds.toList();
      try {
        final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);
        
        if (mounted) {
          if (result.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Moved ${result.length} photos to Trash')),
            );
            
            // Update Provider Locally (Instant UX)
            await context.read<ScanProvider>().removeAssets(result);
            
            setState(() {
              _selectedIds.clear();
            });
          }
        }
      } catch (e) {
        debugPrint("Delete error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete selected items')),
          );
        }
      }
    }
  }

  SortOption _sortOption = SortOption.size;

  void _toggleSelectAll(List<List<AssetEntity>> groups) {
    if (widget.isSimilar) return;
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedIds.isNotEmpty) {
        _selectedIds.clear();
      } else {
        for (var group in groups) {
          if (group.isNotEmpty) {
            for (int i = 1; i < group.length; i++) {
              _selectedIds.add(group[i].id);
            }
          }
        }
      }
    });
  }

  List<List<AssetEntity>> _sortGroups(List<List<AssetEntity>> original, Map<String, int> assetSizes) {
    List<List<AssetEntity>> processed = List.from(original);
    if (_sortOption == SortOption.size) {
      processed.sort((a, b) {
        final sizeA = a.fold<int>(0, (sum, asset) => sum + (assetSizes[asset.id] ?? 0));
        final sizeB = b.fold<int>(0, (sum, asset) => sum + (assetSizes[asset.id] ?? 0));
        return sizeB.compareTo(sizeA);
      });
    } else {
      processed.sort((a, b) {
        if (a.isEmpty || b.isEmpty) return 0;
        return b.first.createDateTime.compareTo(a.first.createDateTime);
      });
    }
    return processed;
  }

  void _openInspector(AssetEntity asset) async {
    final bool isSelected = _selectedIds.contains(asset.id);
    final result = await FullscreenPhotoViewer.open(
      context,
      asset: asset,
      isSelected: isSelected,
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
    return Consumer<ScanProvider>(
      builder: (context, provider, child) {
        final rawGroups = widget.isSimilar ? provider.similarGroups : provider.duplicateGroups;
        final groups = _sortGroups(rawGroups, provider.assetSizes);
        
        final title = widget.isSimilar ? 'Similar Photos' : 'Exact Duplicates';
        
        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                Text(
                  '${_selectedIds.length} selected for clean', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // --- Filter / Action Bar ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Sort Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<SortOption>(
                        value: _sortOption,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.sort_rounded, size: 18),
                        items: const [
                          DropdownMenuItem(value: SortOption.size, child: Text("Sort by Size")),
                          DropdownMenuItem(value: SortOption.date, child: Text("Sort by Date")),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _sortOption = val);
                        },
                      ),
                    ),
                    const Spacer(),
                    if (!widget.isSimilar)
                      TextButton.icon(
                        icon: Icon(_selectedIds.isEmpty ? Icons.check_circle_outline_rounded : Icons.close_rounded, size: 18),
                        label: Text(_selectedIds.isEmpty ? "Select copies" : "Deselect all"),
                        onPressed: () => _toggleSelectAll(groups),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (widget.isSimilar)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
                      const Gap(10),
                      const Expanded(
                        child: Text(
                          'Tap any photo to zoom and inspect smiles/sharpness. Similar photos are never deleted automatically.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // --- Content ---
              Expanded(
                child: groups.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 64, color: Colors.green.withValues(alpha: 0.6)),
                          const Gap(16),
                          Text(
                            "No ${widget.isSimilar ? 'similar photos' : 'duplicates'} found!",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Gap(6),
                          const Text("Your gallery in this area is clean.", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 100),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Text(
                                    'Group ${index + 1}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Gap(8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${group.length} items',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: group.length,
                              itemBuilder: (context, imgIndex) {
                                final asset = group[imgIndex];
                                final isSelected = _selectedIds.contains(asset.id);
                                final isBest = !isSelected && imgIndex == 0;
                                
                                return GestureDetector(
                                  onTap: () => _openInspector(asset),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: AssetEntityImage(
                                            asset,
                                            isOriginal: false,
                                            thumbnailSize: const ThumbnailSize.square(250),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),

                                      // Selection Border / Overlay
                                      if (isSelected)
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: AppColors.error, width: 3),
                                            ),
                                          ),
                                        ),

                                      // Suggested Keep Badge
                                      if (isBest)
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.75),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                                                Gap(3),
                                                Text(
                                                  'Keep',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Top-Right Checkbox Button
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
                                                  : Colors.black.withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 1.5),
                                            ),
                                            child: Icon(
                                              isSelected ? Icons.check_rounded : Icons.circle,
                                              color: isSelected ? Colors.white : Colors.transparent,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Size label bottom right
                                      Positioned(
                                        bottom: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            provider.getFormattedAssetSize(asset.id), 
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Gap(16),
                          ],
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
                onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text(
                  _selectedIds.isEmpty
                      ? 'Select Photos to Clean'
                      : 'Move ${_selectedIds.length} to Trash (${AppUtils.formatBytes(
                          _selectedIds.fold(0, (sum, id) => sum + (provider.assetSizes[id] ?? 0))
                        )})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
