import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:gap/gap.dart';
import '../../providers/scan_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_utils.dart';
import '../../common/fullscreen_photo_viewer.dart';

class DuplicatePreviewScreen extends StatefulWidget {
  final bool isSimilar;
  const DuplicatePreviewScreen({super.key, this.isSimilar = false});

  @override
  State<DuplicatePreviewScreen> createState() => _DuplicatePreviewScreenState();
}

class _DuplicatePreviewScreenState extends State<DuplicatePreviewScreen> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  late bool _showSimilar;

  @override
  void initState() {
    super.initState();
    _showSimilar = widget.isSimilar;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoSelectCopies();
    });
  }

  void _autoSelectCopies() {
    final provider = context.read<ScanProvider>();
    final groups = _showSimilar ? provider.similarGroups : provider.duplicateGroups;

    _selectedIds.clear();
    for (var group in groups) {
      if (group.length > 1) {
        // Keep first (best), select remaining duplicates
        for (int i = 1; i < group.length; i++) {
          _selectedIds.add(group[i].id);
        }
      }
    }
    setState(() {});
  }

  Future<void> _deleteSelected() async {
    if (_isProcessing || _selectedIds.isEmpty) return;
    _isProcessing = true;

    try {
      final provider = context.read<ScanProvider>();
      int freedBytes = 0;
      for (final id in _selectedIds) {
        freedBytes += provider.assetSizes[id] ?? 0;
      }
      final freedSizeStr = AppUtils.formatBytes(freedBytes);

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogBg = isDark ? AppColors.ink2 : Colors.white;

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF281357) : AppColors.lilac,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.trashRedLight,
                      size: 26,
                    ),
                  ),
                  const Gap(18),
                  Text(
                    "Move ${_selectedIds.length} items to Trash?",
                    textAlign: TextAlign.center,
                    style: AppTypography.heading20(
                      color: isDark ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const Gap(10),
                  Text(
                    "That frees $freedSizeStr. You can restore them from your gallery Trash for 30 days.",
                    textAlign: TextAlign.center,
                    style: AppTypography.body15(
                      color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                      height: 1.4,
                    ),
                  ),
                  const Gap(24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.trashRedLight,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        "Move to Trash",
                        style: AppTypography.button15(color: Colors.white),
                      ),
                    ),
                  ),
                  const Gap(10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "Cancel",
                        style: AppTypography.button15(
                          color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (confirm == true) {
        HapticFeedback.mediumImpact();
        List<String> idsToDelete = _selectedIds.toList();
        try {
          final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);

          if (mounted && result.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.ink,
                content: Text(
                  'Moved ${result.length} photos to Trash ($freedSizeStr freed)',
                  style: AppTypography.body15(color: Colors.white),
                ),
              ),
            );

            await context.read<ScanProvider>().removeAssets(result);
            setState(() {
              _selectedIds.removeWhere((id) => result.contains(id));
            });
          }
        } catch (e) {
          debugPrint("Delete error: $e");
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _selectAll(List<List<AssetEntity>> groups) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIds.clear();
      for (var group in groups) {
        for (var asset in group) {
          _selectedIds.add(asset.id);
        }
      }
    });
  }

  void _deselectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedIds.clear();
    });
  }

  void _openInspector(AssetEntity asset) async {
    final bool isSelected = _selectedIds.contains(asset.id);
    await FullscreenPhotoViewer.open(
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.ink;
    final secondaryTextColor =
        isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A);

    return Consumer<ScanProvider>(
      builder: (context, provider, child) {
        final groups = _showSimilar ? provider.similarGroups : provider.duplicateGroups;
        final totalGroups = groups.length;
        final totalCopies = groups.fold<int>(0, (sum, g) => sum + g.length);

        int totalSelectedBytes = 0;
        for (final id in _selectedIds) {
          totalSelectedBytes += provider.assetSizes[id] ?? 0;
        }
        final selectedSizeStr = AppUtils.formatBytes(totalSelectedBytes);

        final totalReclaimableBytes = _showSimilar ? provider.similarSize : provider.duplicateSize;
        final reclaimableSizeStr = AppUtils.formatBytes(totalReclaimableBytes);

        return Scaffold(
          backgroundColor: isDark ? AppColors.ink : AppColors.lavender,
          appBar: AppBar(
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: primaryTextColor,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _showSimilar ? "Duplicates and similar" : "Exact duplicates",
              style: AppTypography.heading20(color: primaryTextColor),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final allSelected = groups.every((g) => g.every((a) => _selectedIds.contains(a.id)));
                  if (allSelected) {
                    _deselectAll();
                  } else {
                    _selectAll(groups);
                  }
                },
                child: Text(
                  "All",
                  style: AppTypography.button15(color: AppColors.violet),
                ),
              ),
              const Gap(8),
            ],
          ),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  // Segmented Switcher (Exact | Similar)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.ink2 : AppColors.lilac.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (_showSimilar) {
                                setState(() {
                                  _showSimilar = false;
                                  _autoSelectCopies();
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: !_showSimilar ? AppColors.violet : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  "Exact ${provider.duplicateGroups.length}",
                                  style: AppTypography.meta13(
                                    color: !_showSimilar ? Colors.white : secondaryTextColor,
                                    fontWeight: !_showSimilar ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!_showSimilar) {
                                setState(() {
                                  _showSimilar = true;
                                  _autoSelectCopies();
                                });
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _showSimilar ? AppColors.violet : Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Center(
                                child: Text(
                                  "Similar ${provider.similarGroups.length}",
                                  style: AppTypography.meta13(
                                    color: _showSimilar ? Colors.white : secondaryTextColor,
                                    fontWeight: _showSimilar ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Gap(18),

                  // Storage Summary Card (Page 8 / 38)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reclaimableSizeStr,
                            style: AppTypography.display48(color: AppColors.violet),
                          ),
                          const Gap(2),
                          Text(
                            "$totalGroups groups | $totalCopies copies",
                            style: AppTypography.body15(color: secondaryTextColor),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F0426) : AppColors.ink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "SAFE PICK",
                          style: AppTypography.caption11(color: Colors.white),
                        ),
                      ),
                    ],
                  ),

                  const Gap(20),

                  // Groups List
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: Text(
                          "No duplicate copies found in this scan area.",
                          style: AppTypography.body15(color: secondaryTextColor),
                        ),
                      ),
                    )
                  else
                    ...List.generate(groups.length, (groupIndex) {
                      final group = groups[groupIndex];
                      final groupSelectedCount = group.where((a) => _selectedIds.contains(a.id)).length;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.ink2 : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.lilac2.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _showSimilar
                                      ? "GROUP ${groupIndex + 1} | ${group.length} PHOTOS"
                                      : "GROUP ${groupIndex + 1} | ${group.length} COPIES",
                                  style: AppTypography.caption11(
                                    color: secondaryTextColor,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                Text(
                                  "$groupSelectedCount selected",
                                  style: AppTypography.meta13(
                                    color: AppColors.violet,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),

                            const Gap(12),

                            // Photos Row
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: group.length,
                                separatorBuilder: (_, _) => const Gap(10),
                                itemBuilder: (context, photoIndex) {
                                  final asset = group[photoIndex];
                                  final isKeep = photoIndex == 0;
                                  final isSelected = _selectedIds.contains(asset.id);

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
                                    onLongPress: () => _openInspector(asset),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            width: 100,
                                            height: 110,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF281357)
                                                  : AppColors.lilac,
                                            ),
                                            child: AssetEntityImage(
                                              asset,
                                              width: 100,
                                              height: 110,
                                              fit: BoxFit.cover,
                                              thumbnailSize: const ThumbnailSize.square(200),
                                            ),
                                          ),
                                        ),

                                        // Badge: KEEP or Selection Check
                                        Positioned(
                                          top: 8,
                                          left: 8,
                                          child: isKeep
                                              ? Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.gold,
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    "KEEP",
                                                    style: AppTypography.caption11(
                                                      color: AppColors.ink,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? AppColors.violet
                                                        : Colors.black.withValues(alpha: 0.4),
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: isSelected
                                                      ? const Icon(
                                                          Icons.check,
                                                          size: 14,
                                                          color: Colors.white,
                                                        )
                                                      : null,
                                                ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                            const Gap(10),

                            // Group Footer Metadata
                            Text(
                              "${AppUtils.formatBytes(provider.assetSizes[group.first.id] ?? 0)} each | ${group.first.width} x ${group.first.height}",
                              style: AppTypography.meta13(color: secondaryTextColor),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),

              // Sticky Bottom Action Bar (Page 8 / 38)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.ink2 : AppColors.ink,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${_selectedIds.length} selected",
                            style: AppTypography.heading20(color: Colors.white)
                                .copyWith(fontSize: 16),
                          ),
                          const Gap(2),
                          Row(
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                size: 12,
                                color: Color(0xFFA49EBA),
                              ),
                              const Gap(4),
                              Text(
                                "$selectedSizeStr | 30-day Trash",
                                style: AppTypography.meta13(
                                  color: const Color(0xFFA49EBA),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _selectedIds.isEmpty || _isProcessing
                            ? null
                            : _deleteSelected,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.ink,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.ink,
                        ),
                        label: Text(
                          "Trash",
                          style: AppTypography.button15(color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
