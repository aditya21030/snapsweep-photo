import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../providers/scan_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../common/fullscreen_photo_viewer.dart';

class SmartCleanPreviewScreen extends StatefulWidget {
  const SmartCleanPreviewScreen({super.key});

  @override
  State<SmartCleanPreviewScreen> createState() => _SmartCleanPreviewScreenState();
}

class _SmartCleanPreviewScreenState extends State<SmartCleanPreviewScreen> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScanProvider>();
      setState(() {
        for (var asset in provider.smartCleanCandidates) {
          _selectedIds.add(asset.id);
        }
      });
    });
  }

  Future<void> _cleanSelected() async {
    if (_selectedIds.isEmpty) return;

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
              child: const Icon(Icons.delete_sweep_rounded, color: AppColors.error, size: 24),
            ),
            const Gap(12),
            const Expanded(child: Text('Move Copies to Trash?')),
          ],
        ),
        content: Text(
          '${_selectedIds.length} exact copy photo(s) will be moved to your device\'s Trash / Recently Deleted folder.\n\nThe original photo will be safely kept. You can restore deleted copies within 30 days.',
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

    if (confirm == true && mounted) {
      HapticFeedback.mediumImpact();
      final count = await context.read<ScanProvider>().smartClean(specificIds: _selectedIds.toList());
      if (mounted) {
        Navigator.pop(context); // Return to Cleaner Tab
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved $count duplicate copies to Trash!')),
        );
      }
    }
  }

  void _openInspector(AssetEntity asset) async {
    final bool isSelected = _selectedIds.contains(asset.id);
    final result = await FullscreenPhotoViewer.open(
      context,
      asset: asset,
      isSelected: isSelected,
      subtitle: 'Exact Duplicate Copy',
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
        final candidates = provider.smartCleanCandidates;
        int selectedSize = 0;
        for (var id in _selectedIds) {
          selectedSize += provider.assetSizes[id] ?? 0;
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              children: [
                const Text('Exact Copies Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                Text(
                  '${_selectedIds.length} of ${candidates.length} selected',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (_selectedIds.length == candidates.length) {
                      _selectedIds.clear();
                    } else {
                      for (var a in candidates) {
                        _selectedIds.add(a.id);
                      }
                    }
                  });
                },
                child: Text(
                  _selectedIds.length == candidates.length ? 'Deselect All' : 'Select All',
                ),
              ),
            ],
          ),
          body: candidates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 64, color: Colors.green.withValues(alpha: 0.6)),
                      const Gap(16),
                      const Text('No duplicate copies found!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Gap(6),
                      const Text('Your gallery has no redundant exact files.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 20, color: Colors.green),
                          Gap(10),
                          Expanded(
                            child: Text(
                              'These are 100% byte-for-byte exact copies. Only extra copies are marked; originals will stay safe.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 100),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.9,
                        ),
                        itemCount: candidates.length,
                        itemBuilder: (context, index) {
                          final asset = candidates[index];
                          final isSelected = _selectedIds.contains(asset.id);

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
                                if (isSelected)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.error, width: 3),
                                        borderRadius: BorderRadius.circular(14),
                                        color: AppColors.error.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ),

                                // Corner Checkbox
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
                                        color: isSelected ? AppColors.error : Colors.black.withValues(alpha: 0.5),
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

                                // Size label
                                if (provider.assetSizes.containsKey(asset.id))
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
                onPressed: _selectedIds.isEmpty ? null : _cleanSelected,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text(
                  _selectedIds.isEmpty
                      ? 'Select Copies to Clean'
                      : 'Move ${_selectedIds.length} Copies to Trash (${AppUtils.formatBytes(selectedSize)})',
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
