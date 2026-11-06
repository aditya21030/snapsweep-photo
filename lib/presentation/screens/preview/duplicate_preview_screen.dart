import '../../common/operation_result.dart';
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
import '../../../data/services/media_service.dart';
import '../../common/fullscreen_photo_viewer.dart';

enum _MatchFilter { all, exact, similar }

typedef _ReviewGroup = ({bool exact, List<AssetEntity> assets});

class DuplicatePreviewScreen extends StatefulWidget {
  final bool isSimilar;
  const DuplicatePreviewScreen({super.key, this.isSimilar = false});

  @override
  State<DuplicatePreviewScreen> createState() => _DuplicatePreviewScreenState();
}

class _DuplicatePreviewScreenState extends State<DuplicatePreviewScreen> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;
  late _MatchFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.isSimilar ? _MatchFilter.similar : _MatchFilter.all;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoSelectCopies();
    });
  }

  List<_ReviewGroup> _reviewGroups(ScanProvider provider) => [
    if (_filter != _MatchFilter.similar)
      for (final assets in provider.duplicateGroups)
        (exact: true, assets: assets),
    if (_filter != _MatchFilter.exact)
      for (final assets in provider.similarGroups)
        (exact: false, assets: assets),
  ];

  void _autoSelectCopies() {
    final provider = context.read<ScanProvider>();
    _selectedIds.clear();
    for (final group in _reviewGroups(provider).where((group) => group.exact)) {
      _selectedIds.addAll(group.assets.skip(1).map((asset) => asset.id));
    }
    setState(() {});
  }

  void _setFilter(_MatchFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    _autoSelectCopies();
  }

  Future<void> _deleteSelected() async {
    if (_isProcessing ||
        _selectedIds.isEmpty ||
        context.read<ScanProvider>().isLoading) {
      return;
    }
    _isProcessing = true;

    try {
      final provider = context.read<ScanProvider>();
      int freedBytes = 0;
      for (final id in _selectedIds) {
        freedBytes += provider.assetSizes[id] ?? 0;
      }
      final freedSizeStr = AppUtils.formatBytes(freedBytes);
      final canTrash = await MediaService.supportsTrash();
      if (!mounted) return;

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogBg = isDark ? AppColors.ink2 : Colors.white;

          return Dialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
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
                    "Delete ${_selectedIds.length} items?",
                    textAlign: TextAlign.center,
                    style: AppTypography.heading20(
                      color: isDark ? Colors.white : AppColors.ink,
                    ),
                  ),
                  const Gap(10),
                  Text(
                    canTrash
                        ? 'Selected items will be moved to Trash. $freedSizeStr can be reclaimed after Trash is emptied.'
                        : 'Selected items will be permanently deleted, freeing $freedSizeStr.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body15(
                      color: isDark
                          ? const Color(0xFFA49EBA)
                          : const Color(0xFF5F567A),
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
                        canTrash ? 'Move to Trash' : 'Delete Permanently',
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
                          color: isDark
                              ? const Color(0xFFA49EBA)
                              : const Color(0xFF5F567A),
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
          final List<String> result = await MediaService.removeAssetsWithIds(
            idsToDelete,
          );

          if (result.isNotEmpty) {
            await provider.removeAssets(result);
            if (!mounted) return;
            setState(() {
              _selectedIds.removeWhere((id) => result.contains(id));
            });
            await showOperationResult(
              context,
              message: 'Removed ${result.length} photos from the gallery.',
            );
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
        for (var asset in group.skip(1)) {
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
    final secondaryTextColor = isDark
        ? const Color(0xFFA49EBA)
        : const Color(0xFF5F567A);

    return Consumer<ScanProvider>(
      builder: (context, provider, child) {
        final entries = _reviewGroups(provider);
        final groups = entries.map((group) => group.assets).toList();
        final visibleIds = groups
            .expand((group) => group)
            .map((asset) => asset.id)
            .toSet();
        _selectedIds.retainAll(visibleIds);
        final totalGroups = groups.length;
        final totalCopies = groups.fold<int>(0, (sum, g) => sum + g.length);

        int totalSelectedBytes = 0;
        for (final id in _selectedIds) {
          totalSelectedBytes += provider.assetSizes[id] ?? 0;
        }
        final selectedSizeStr = AppUtils.formatBytes(totalSelectedBytes);

        final reclaimableIds = groups
            .expand((group) => group.skip(1))
            .map((asset) => asset.id)
            .toSet();
        final totalReclaimableBytes = reclaimableIds.fold<int>(
          0,
          (total, id) => total + (provider.assetSizes[id] ?? 0),
        );
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
              "Duplicates & similar",
              style: AppTypography.heading20(color: primaryTextColor),
            ),
            actions: [
              TextButton(
                onPressed: groups.isEmpty || provider.isLoading
                    ? null
                    : () {
                        final allSelected = groups.every(
                          (g) => g
                              .skip(1)
                              .every((a) => _selectedIds.contains(a.id)),
                        );
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
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                cacheExtent: 350,
                itemCount: groups.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text('All ${provider.reviewGroupCount}'),
                              selected: _filter == _MatchFilter.all,
                              onSelected: (_) => _setFilter(_MatchFilter.all),
                            ),
                            ChoiceChip(
                              label: Text(
                                'Exact ${provider.duplicateGroups.length}',
                              ),
                              selected: _filter == _MatchFilter.exact,
                              onSelected: (_) => _setFilter(_MatchFilter.exact),
                            ),
                            ChoiceChip(
                              label: Text(
                                'Similar ${provider.similarGroups.length}',
                              ),
                              selected: _filter == _MatchFilter.similar,
                              onSelected: (_) =>
                                  _setFilter(_MatchFilter.similar),
                            ),
                          ],
                        ),
                        if (provider.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Column(
                              children: [
                                LinearProgressIndicator(),
                                SizedBox(height: 8),
                                Text(
                                  'Updating matches. Saved groups stay visible until the new results are ready.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                        const Gap(18),

                        // Storage Summary Card (Page 8 / 38)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reclaimableSizeStr,
                                  style: AppTypography.display48(
                                    color: AppColors.violet,
                                  ),
                                ),
                                const Gap(2),
                                Text(
                                  "$totalGroups groups | $totalCopies photos",
                                  style: AppTypography.body15(
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F0426)
                                    : AppColors.ink,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _filter == _MatchFilter.exact
                                    ? "EXACT COPIES"
                                    : "REVIEW MATCHES",
                                style: AppTypography.caption11(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Gap(20),

                        // Groups List
                        if (groups.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  provider.scanErrorMessage ??
                                      (provider.isLoading
                                          ? 'Analysis is still running.'
                                          : _filter == _MatchFilter.all
                                          ? 'No matching copies in ${provider.scanScope.label}.'
                                          : _filter == _MatchFilter.exact
                                          ? 'No exact duplicates in this view.'
                                          : 'No similar photos in this view.'),
                                  style: AppTypography.body15(
                                    color: secondaryTextColor,
                                  ),
                                ),
                                if (_filter != _MatchFilter.all &&
                                    provider.reviewGroupCount > 0)
                                  TextButton(
                                    onPressed: () =>
                                        _setFilter(_MatchFilter.all),
                                    child: const Text('Show all matches'),
                                  ),
                                if (provider.scanScope != ScanScope.fullGallery)
                                  TextButton(
                                    onPressed: () => provider.setScanScope(
                                      ScanScope.fullGallery,
                                    ),
                                    child: const Text('Show full gallery'),
                                  ),
                                if (!provider.isLoading &&
                                    provider.reviewGroupCount == 0)
                                  TextButton(
                                    onPressed: provider.recheckMatches,
                                    child: const Text('Recheck matches'),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                  final groupIndex = index - 1;

                  final group = groups[groupIndex];
                  final isExactGroup = entries[groupIndex].exact;
                  final groupSelectedCount = group
                      .where((a) => _selectedIds.contains(a.id))
                      .length;

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
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Text(
                              isExactGroup
                                  ? "EXACT GROUP ${groupIndex + 1} | ${group.length} COPIES"
                                  : "SIMILAR GROUP ${groupIndex + 1} | ${group.length} PHOTOS",
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
                              final isSelected = _selectedIds.contains(
                                asset.id,
                              );

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
                                          isOriginal: false,
                                          width: 100,
                                          height: 110,
                                          fit: BoxFit.cover,
                                          thumbnailSize:
                                              const ThumbnailSize.square(200),
                                        ),
                                      ),
                                    ),

                                    // Badge: KEEP or Selection Check
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: isKeep
                                          ? Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.gold,
                                                borderRadius:
                                                    BorderRadius.circular(8),
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
                                                    : Colors.black.withValues(
                                                        alpha: 0.4,
                                                      ),
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
                          style: AppTypography.meta13(
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${_selectedIds.length} selected",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.heading20(
                                color: Colors.white,
                              ).copyWith(fontSize: 16),
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
                                Expanded(
                                  child: Text(
                                    '$selectedSizeStr selected for review',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.meta13(
                                      color: const Color(0xFFA49EBA),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Gap(10),
                      ElevatedButton.icon(
                        onPressed:
                            _selectedIds.isEmpty ||
                                _isProcessing ||
                                provider.isLoading
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
