import 'dart:math' as math;
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

enum SwipeFilterScope {
  allPhotos,
  thisMonth,
  lastMonth,
  screenshots,
  social,
  blurry,
}

extension SwipeFilterLabel on SwipeFilterScope {
  String get label => switch (this) {
        SwipeFilterScope.allPhotos => 'All Photos',
        SwipeFilterScope.thisMonth => 'This Month',
        SwipeFilterScope.lastMonth => 'Last Month',
        SwipeFilterScope.screenshots => 'Screenshots',
        SwipeFilterScope.social => 'Social & WhatsApp',
        SwipeFilterScope.blurry => 'Blurry Photos',
      };

  IconData get icon => switch (this) {
        SwipeFilterScope.allPhotos => Icons.photo_library_rounded,
        SwipeFilterScope.thisMonth => Icons.calendar_today_rounded,
        SwipeFilterScope.lastMonth => Icons.history_rounded,
        SwipeFilterScope.screenshots => Icons.screenshot_rounded,
        SwipeFilterScope.social => Icons.chat_rounded,
        SwipeFilterScope.blurry => Icons.blur_on_rounded,
      };
}

enum SwipeAction { trash, keep, skip }

class SwipeCleanerScreen extends StatefulWidget {
  final SwipeFilterScope initialScope;

  const SwipeCleanerScreen({
    super.key,
    this.initialScope = SwipeFilterScope.allPhotos,
  });

  @override
  State<SwipeCleanerScreen> createState() => _SwipeCleanerScreenState();
}

class _SwipeCleanerScreenState extends State<SwipeCleanerScreen>
    with SingleTickerProviderStateMixin {
  late SwipeFilterScope _selectedScope;
  int _currentIndex = 0;

  // Swiped collections
  final List<AssetEntity> _trashQueue = [];
  final List<AssetEntity> _keepQueue = [];
  final List<({AssetEntity asset, SwipeAction action})> _history = [];

  // Drag physics & animation
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _animController;
  Animation<Offset>? _flyOffAnimation;

  // Cached filtered assets for current scope
  List<AssetEntity> _activeAssets = [];
  SwipeFilterScope? _lastBuiltScope;
  int _lastAssetsHash = 0;

  bool _isProcessingDelete = false;

  @override
  void initState() {
    super.initState();
    _selectedScope = widget.initialScope;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _animController.addListener(() {
      if (_flyOffAnimation != null) {
        setState(() {
          _dragOffset = _flyOffAnimation!.value;
        });
      }
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _flyOffAnimation != null) {
        _commitCurrentSwipe();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _syncAssets(ScanProvider provider) {
    final assets = provider.allScreenshots;
    final hash = Object.hash(assets.length, _selectedScope);

    if (_lastBuiltScope != _selectedScope || _lastAssetsHash != hash) {
      _lastBuiltScope = _selectedScope;
      _lastAssetsHash = hash;

      final now = DateTime.now();
      final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
      final lastMonthVal = now.month == 1 ? 12 : now.month - 1;

      List<AssetEntity> filtered = [];
      switch (_selectedScope) {
        case SwipeFilterScope.allPhotos:
          filtered = List.from(assets);
          break;
        case SwipeFilterScope.thisMonth:
          filtered = assets.where((a) {
            final dt = a.createDateTime;
            return dt.year == now.year && dt.month == now.month;
          }).toList();
          break;
        case SwipeFilterScope.lastMonth:
          filtered = assets.where((a) {
            final dt = a.createDateTime;
            return dt.year == lastMonthYear && dt.month == lastMonthVal;
          }).toList();
          break;
        case SwipeFilterScope.screenshots:
          filtered = List.from(provider.categories['Screenshots'] ?? []);
          break;
        case SwipeFilterScope.social:
          filtered = List.from(provider.categories['Social & WhatsApp'] ?? []);
          break;
        case SwipeFilterScope.blurry:
          filtered = List.from(provider.blurryPhotos);
          break;
      }

      // Filter out assets already processed in this session
      final Set<String> processedIds = {
        for (final a in _trashQueue) a.id,
        for (final a in _keepQueue) a.id,
      };
      filtered.removeWhere((a) => processedIds.contains(a.id));

      // Smart Deck Ordering: Prioritize junk candidates (duplicate redundant copies,
      // low-clarity blurry shots, screenshots) so the user reclaims maximum storage first.
      final Set<String> duplicateIds = {
        for (final group in provider.duplicateGroups)
          if (group.length > 1)
            for (int i = 1; i < group.length; i++) group[i].id,
      };
      final Set<String> blurryIds = {for (final a in provider.blurryPhotos) a.id};
      final Set<String> screenshotIds = {for (final a in (provider.categories['Screenshots'] ?? [])) a.id};

      filtered.sort((a, b) {
        int scoreA = 0;
        if (duplicateIds.contains(a.id)) scoreA += 100;
        if (blurryIds.contains(a.id)) scoreA += 70;
        if (screenshotIds.contains(a.id)) scoreA += 40;

        int scoreB = 0;
        if (duplicateIds.contains(b.id)) scoreB += 100;
        if (blurryIds.contains(b.id)) scoreB += 70;
        if (screenshotIds.contains(b.id)) scoreB += 40;

        final scoreComp = scoreB.compareTo(scoreA);
        if (scoreComp != 0) return scoreComp;

        return b.createDateTime.compareTo(a.createDateTime);
      });

      _activeAssets = filtered;
      _currentIndex = 0;
      _dragOffset = Offset.zero;
    }
  }

  void _changeScope(SwipeFilterScope newScope) {
    if (_selectedScope == newScope) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedScope = newScope;
      _lastBuiltScope = null; // force sync
    });
  }

  // Swipe gesture handling
  void _onPanStart(DragStartDetails details) {
    if (_animController.isAnimating || _currentIndex >= _activeAssets.length) return;
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset += details.delta;
    });

    // Provide subtle haptic feedback when crossing threshold
    if (_dragOffset.dx.abs() > 100 && (_dragOffset.dx - details.delta.dx).abs() <= 100) {
      HapticFeedback.selectionClick();
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    const threshold = 110.0;
    final velocity = details.velocity.pixelsPerSecond;

    if (_dragOffset.dx < -threshold || velocity.dx < -700) {
      _triggerSwipe(SwipeAction.trash);
    } else if (_dragOffset.dx > threshold || velocity.dx > 700) {
      _triggerSwipe(SwipeAction.keep);
    } else if (_dragOffset.dy < -threshold || velocity.dy < -700) {
      _triggerSwipe(SwipeAction.skip);
    } else {
      // Rebound to center smoothly
      _flyOffAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ));
      _animController.forward(from: 0.0);
    }
  }

  SwipeAction? _pendingAction;

  void _triggerSwipe(SwipeAction action) {
    if (_animController.isAnimating || _currentIndex >= _activeAssets.length) return;
    _pendingAction = action;

    Offset target;
    switch (action) {
      case SwipeAction.trash:
        target = const Offset(-550, 0);
        HapticFeedback.mediumImpact();
        break;
      case SwipeAction.keep:
        target = const Offset(550, 0);
        HapticFeedback.lightImpact();
        break;
      case SwipeAction.skip:
        target = const Offset(0, -650);
        HapticFeedback.selectionClick();
        break;
    }

    _flyOffAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0);
  }

  void _commitCurrentSwipe() {
    if (_pendingAction == null || _currentIndex >= _activeAssets.length) return;
    final currentAsset = _activeAssets[_currentIndex];
    final action = _pendingAction!;

    setState(() {
      if (action == SwipeAction.trash) {
        _trashQueue.add(currentAsset);
      } else if (action == SwipeAction.keep) {
        _keepQueue.add(currentAsset);
      }
      _history.add((asset: currentAsset, action: action));
      _currentIndex++;
      _dragOffset = Offset.zero;
      _pendingAction = null;
      _flyOffAnimation = null;
    });

    _animController.reset();

    // If reached end of deck and items were queued for trash, suggest review
    if (_currentIndex >= _activeAssets.length && _trashQueue.isNotEmpty) {
      _showReviewBottomSheet();
    }
  }

  void _undoLastSwipe() {
    if (_history.isEmpty || _currentIndex <= 0) return;
    HapticFeedback.selectionClick();

    final lastEntry = _history.removeLast();
    setState(() {
      _currentIndex--;
      if (lastEntry.action == SwipeAction.trash) {
        _trashQueue.removeWhere((a) => a.id == lastEntry.asset.id);
      } else if (lastEntry.action == SwipeAction.keep) {
        _keepQueue.removeWhere((a) => a.id == lastEntry.asset.id);
      }
      _dragOffset = Offset.zero;
    });
  }

  int _calculateTrashBytes(ScanProvider provider) {
    int total = 0;
    for (final asset in _trashQueue) {
      total += provider.assetSizes[asset.id] ?? 0;
    }
    return total;
  }

  Future<void> _showReviewBottomSheet() async {
    if (_trashQueue.isEmpty) return;
    HapticFeedback.mediumImpact();

    final provider = context.read<ScanProvider>();
    final Set<String> selectedForDeletion = _trashQueue.map((a) => a.id).toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;

            int selectedBytes = 0;
            for (final id in selectedForDeletion) {
              selectedBytes += provider.assetSizes[id] ?? 0;
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.78,
              decoration: BoxDecoration(
                color: isDark ? AppColors.ink2 : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const Gap(12),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF281357) : AppColors.lilac,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Gap(18),

                    // Header (Page 11: TRASH QUEUE | 12 photos | 38 MB to reclaim)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TRASH QUEUE",
                                style: AppTypography.caption11(
                                  color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                "${selectedForDeletion.length} photos",
                                style: AppTypography.title30(
                                  color: isDark ? Colors.white : AppColors.ink,
                                ).copyWith(fontSize: 24),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppUtils.formatBytes(selectedBytes),
                                style: AppTypography.title30(
                                  color: AppColors.violet,
                                ).copyWith(fontSize: 24),
                              ),
                              const Gap(2),
                              Text(
                                "to reclaim",
                                style: AppTypography.meta13(
                                  color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(18),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lilac2.withValues(alpha: 0.5),
                    ),

                    // 4-Column Grid of Queued Photos (Page 11)
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _trashQueue.length,
                        itemBuilder: (ctx, index) {
                          final asset = _trashQueue[index];
                          final isSelected = selectedForDeletion.contains(asset.id);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: ColorFiltered(
                                  colorFilter: isSelected
                                      ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                      : ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken),
                                  child: AssetEntityImage(
                                    asset,
                                    isOriginal: false,
                                    thumbnailSize: const ThumbnailSize.square(200),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // Remove from Queue 'X' Button on Top Right
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setSheetState(() {
                                      if (isSelected) {
                                        selectedForDeletion.remove(asset.id);
                                      } else {
                                        selectedForDeletion.add(asset.id);
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.ink.withValues(alpha: 0.8)
                                          : Colors.grey.withValues(alpha: 0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected ? Icons.close_rounded : Icons.add_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Bottom Action Buttons (Page 11)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.ink,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: selectedForDeletion.isEmpty
                                  ? null
                                  : () async {
                                      Navigator.pop(ctx);
                                      await _executeTrash(selectedForDeletion.toList());
                                    },
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: AppColors.ink,
                              ),
                              label: Text(
                                "Move ${selectedForDeletion.length} to Trash",
                                style: AppTypography.button15(color: AppColors.ink)
                                    .copyWith(fontSize: 16),
                              ),
                            ),
                          ),
                          const Gap(10),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              "Keep swiping",
                              style: AppTypography.button15(
                                color: AppColors.violet,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeTrash(List<String> idsToDelete) async {
    if (idsToDelete.isEmpty || _isProcessingDelete) return;
    _isProcessingDelete = true;

    try {
      final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);

      if (mounted && result.isNotEmpty) {
        HapticFeedback.mediumImpact();
        await context.read<ScanProvider>().removeAssets(result);
        if (!mounted) return;

        setState(() {
          _trashQueue.removeWhere((a) => result.contains(a.id));
          _activeAssets.removeWhere((a) => result.contains(a.id));
          _history.removeWhere((entry) => result.contains(entry.asset.id));
          if (_currentIndex > _activeAssets.length) {
            _currentIndex = _activeAssets.length;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully moved ${result.length} photos to Trash'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[SwipeCleaner] Deletion error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete selected items')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingDelete = false);
    }
  }

  void _inspectAsset(AssetEntity asset) async {
    final isQueuedTrash = _trashQueue.any((a) => a.id == asset.id);
    final result = await FullscreenPhotoViewer.open(
      context,
      asset: asset,
      isSelected: isQueuedTrash,
      subtitle: _selectedScope.label,
      onSelectionChanged: (val) {
        setState(() {
          if (val) {
            if (!_trashQueue.any((a) => a.id == asset.id)) {
              _trashQueue.add(asset);
            }
          } else {
            _trashQueue.removeWhere((a) => a.id == asset.id);
          }
        });
      },
    );

    if (result != null && mounted) {
      setState(() {
        if (result) {
          if (!_trashQueue.any((a) => a.id == asset.id)) {
            _trashQueue.add(asset);
          }
        } else {
          _trashQueue.removeWhere((a) => a.id == asset.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    _syncAssets(provider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalTrashBytes = _calculateTrashBytes(provider);
    final totalRemaining = _activeAssets.length - _currentIndex;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Navigation & Stats Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.style_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SWIPE TO CLEAN',
                          style: AppTypography.caption11(
                            color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const Gap(2),
                        Text(
                          totalRemaining > 0
                              ? '${_currentIndex + 1} of ${_activeAssets.length}'
                              : 'Deck Completed',
                          style: AppTypography.title30(
                            color: isDark ? Colors.white : AppColors.ink,
                          ).copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                  ),

                  // Trash Queue Gold Pill (Page 10)
                  if (_trashQueue.isNotEmpty)
                    GestureDetector(
                      onTap: _showReviewBottomSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          totalTrashBytes > 0
                              ? 'Review ${_trashQueue.length} | ${AppUtils.formatBytes(totalTrashBytes)}'
                              : 'Review ${_trashQueue.length}',
                          style: AppTypography.button15(color: AppColors.ink)
                              .copyWith(fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Horizontal Scope Selector Pills
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: SwipeFilterScope.values.length,
                separatorBuilder: (_, _) => const Gap(8),
                itemBuilder: (ctx, index) {
                  final scope = SwipeFilterScope.values[index];
                  final isSelected = scope == _selectedScope;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _changeScope(scope);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.violet
                            : (isDark ? AppColors.ink2 : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.violet
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lilac2.withValues(alpha: 0.5)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            scope.icon,
                            size: 15,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.lilac : AppColors.violet),
                          ),
                          const Gap(6),
                          Text(
                            scope.label,
                            style: AppTypography.meta13(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFFA49EBA) : AppColors.ink),
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Gap(10),

            // Main Interactive Card Stack
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: totalRemaining <= 0
                    ? _buildEmptyOrCompletedState(theme, isDark)
                    : _buildCardStack(theme, isDark, provider),
              ),
            ),

            // Bottom Action Control Row (Page 10: Undo, Trash, Skip, Keep)
            if (totalRemaining > 0)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  8,
                  24,
                  92 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Undo Button
                    _buildRoundActionButton(
                      icon: Icons.replay_rounded,
                      bgColor: isDark ? const Color(0xFF281357) : AppColors.lilac,
                      iconColor: isDark ? Colors.white : AppColors.ink,
                      size: 52,
                      iconSize: 22,
                      tooltip: 'Undo last card',
                      onPressed: _history.isEmpty ? null : _undoLastSwipe,
                    ),

                    // 2. Trash Button (Swipe Left)
                    _buildRoundActionButton(
                      icon: Icons.close_rounded,
                      bgColor: AppColors.trashRedLight,
                      iconColor: Colors.white,
                      size: 64,
                      iconSize: 30,
                      tooltip: 'Move to Trash (Swipe Left)',
                      onPressed: () => _triggerSwipe(SwipeAction.trash),
                    ),

                    // 3. Skip Button (Swipe Up)
                    _buildRoundActionButton(
                      icon: Icons.arrow_upward_rounded,
                      bgColor: isDark ? const Color(0xFF281357) : AppColors.lilac,
                      iconColor: isDark ? Colors.white : AppColors.ink,
                      size: 52,
                      iconSize: 22,
                      tooltip: 'Skip (Swipe Up)',
                      onPressed: () => _triggerSwipe(SwipeAction.skip),
                    ),

                    // 4. Keep Button (Swipe Right)
                    _buildRoundActionButton(
                      icon: Icons.check_rounded,
                      bgColor: AppColors.gold,
                      iconColor: AppColors.ink,
                      size: 64,
                      iconSize: 32,
                      tooltip: 'Keep Photo (Swipe Right)',
                      onPressed: () => _triggerSwipe(SwipeAction.keep),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardStack(ThemeData theme, bool isDark, ScanProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final cardHeight = constraints.maxHeight;

        List<Widget> cardStack = [];

        // Render up to 3 cards for buttery 120 FPS
        final maxCardsToRender = math.min(3, _activeAssets.length - _currentIndex);

        for (int i = maxCardsToRender - 1; i >= 0; i--) {
          final assetIndex = _currentIndex + i;
          final asset = _activeAssets[assetIndex];

          if (i == 0) {
            // Interactive Top Card
            cardStack.add(
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: _buildTopCard(
                  asset,
                  cardWidth,
                  cardHeight,
                  theme,
                  isDark,
                  provider,
                ),
              ),
            );
          } else {
            // Background Cards with subtle scale & translation
            final double scale = 1.0 - (i * 0.05);
            final double yOffset = i * 16.0;

            cardStack.add(
              Positioned(
                top: yOffset,
                left: (cardWidth - (cardWidth * scale)) / 2,
                width: cardWidth * scale,
                height: cardHeight - 20,
                child: _buildCardContent(
                  asset,
                  theme,
                  isDark,
                  provider,
                  isBackground: true,
                ),
              ),
            );
          }
        }

        return Stack(
          alignment: Alignment.center,
          children: cardStack,
        );
      },
    );
  }

  Widget _buildTopCard(
    AssetEntity asset,
    double width,
    double height,
    ThemeData theme,
    bool isDark,
    ScanProvider provider,
  ) {
    final double rotation = (_dragOffset.dx / width) * 0.22;
    final double dragX = _dragOffset.dx;
    final double dragY = _dragOffset.dy;

    // Badges visibility
    final double trashProgress = (-dragX / 100.0).clamp(0.0, 1.0);
    final double keepProgress = (dragX / 100.0).clamp(0.0, 1.0);
    final double skipProgress = (-dragY / 100.0).clamp(0.0, 1.0);

    return Transform.translate(
      offset: _dragOffset,
      child: Transform.rotate(
        angle: rotation,
        child: SizedBox(
          width: width,
          height: height - 20,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildCardContent(asset, theme, isDark, provider, isBackground: false),

              // Interactive Action Badges (Page 10: TRASH in Red, KEEP in Gold)
              if (trashProgress > 0.05)
                Positioned(
                  top: 24,
                  right: 24,
                  child: Opacity(
                    opacity: trashProgress,
                    child: _buildActionBadge(
                      label: 'TRASH',
                      bgColor: AppColors.trashRedLight,
                      textColor: Colors.white,
                      icon: Icons.close_rounded,
                      angle: 0.15,
                    ),
                  ),
                ),

              if (keepProgress > 0.05)
                Positioned(
                  top: 24,
                  left: 24,
                  child: Opacity(
                    opacity: keepProgress,
                    child: _buildActionBadge(
                      label: 'KEEP',
                      bgColor: AppColors.gold,
                      textColor: AppColors.ink,
                      icon: Icons.check_rounded,
                      angle: -0.15,
                    ),
                  ),
                ),

              if (skipProgress > 0.1 && trashProgress < 0.2 && keepProgress < 0.2)
                Positioned(
                  bottom: 90,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Opacity(
                      opacity: skipProgress,
                      child: _buildActionBadge(
                        label: 'SKIP',
                        bgColor: isDark ? const Color(0xFF281357) : AppColors.lilac,
                        textColor: isDark ? Colors.white : AppColors.ink,
                        icon: Icons.arrow_upward_rounded,
                        angle: 0.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    AssetEntity asset,
    ThemeData theme,
    bool isDark,
    ScanProvider provider, {
    required bool isBackground,
  }) {
    final folder = provider.assetAlbumMap[asset.id] ?? 'Camera';
    final size = provider.assetSizes[asset.id] ?? 0;
    final dateStr = DateFormat('MMM d, yyyy | h:mm a').format(asset.createDateTime);

    return Material(
      color: Colors.transparent,
      elevation: isBackground ? 3 : 10,
      borderRadius: BorderRadius.circular(26),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Image Thumbnail
            AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(800),
              fit: BoxFit.cover,
            ),

            // Top Quick Inspect Button
            if (!isBackground)
              Positioned(
                top: 14,
                right: 14,
                child: IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.fullscreen_rounded, size: 22),
                  onPressed: () => _inspectAsset(asset),
                  tooltip: 'Inspect Fullscreen',
                ),
              ),

            // Bottom Gradient and Metadata Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            folder,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (size > 0) ...[
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              AppUtils.formatBytes(size),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (asset.type == AssetType.video) ...[
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 14),
                                const Gap(4),
                                Text(
                                  AppUtils.formatDuration(Duration(seconds: asset.duration)),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(8),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
    required double angle,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor, size: 20),
            const Gap(8),
            Text(
              label,
              style: AppTypography.button15(color: textColor).copyWith(
                letterSpacing: 1.2,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundActionButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required double size,
    required double iconSize,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: onPressed == null
            ? Colors.grey.withValues(alpha: 0.2)
            : bgColor,
        shape: const CircleBorder(),
        elevation: onPressed == null ? 0 : 4,
        shadowColor: bgColor.withValues(alpha: 0.35),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: onPressed == null ? Colors.grey : iconColor,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrCompletedState(ThemeData theme, bool isDark) {
    final isLoading = context.watch<ScanProvider>().isLoading;

    if (isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 96 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.violet),
              const Gap(20),
              Text(
                'Scanning Photos...',
                style: AppTypography.heading20(color: isDark ? Colors.white : AppColors.ink),
              ),
              const Gap(6),
              Text(
                'Organizing photos for swipe review',
                style: AppTypography.meta13(color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A)),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 96 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.gold,
                size: 56,
              ),
            ),
            const Gap(20),
            Text(
              'All Caught Up!',
              style: AppTypography.title30(color: isDark ? Colors.white : AppColors.ink),
            ),
            const Gap(8),
            Text(
              _trashQueue.isNotEmpty
                  ? 'You reviewed this batch. Tap below to confirm and move items to Trash.'
                  : 'No photos to review in ${_selectedScope.label}. Choose another album above.',
              textAlign: TextAlign.center,
              style: AppTypography.body15(
                color: isDark ? const Color(0xFFA49EBA) : const Color(0xFF5F567A),
              ),
            ),
            const Gap(24),
            if (_trashQueue.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _showReviewBottomSheet,
                icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.ink),
                label: Text(
                  'Review ${_trashQueue.length} Queued Items',
                  style: AppTypography.button15(color: AppColors.ink),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
