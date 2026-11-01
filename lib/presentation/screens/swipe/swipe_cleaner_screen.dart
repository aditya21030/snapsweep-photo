import 'dart:math' as math;
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
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Handle Bar
                    const Gap(12),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Gap(16),

                    // Title & Reclaim Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_sweep_rounded,
                              color: AppColors.error,
                              size: 24,
                            ),
                          ),
                          const Gap(14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Review Queued Trash',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${selectedForDeletion.length} items | Reclaim ${AppUtils.formatBytes(selectedBytes)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                if (selectedForDeletion.length == _trashQueue.length) {
                                  selectedForDeletion.clear();
                                } else {
                                  selectedForDeletion.addAll(_trashQueue.map((a) => a.id));
                                }
                              });
                            },
                            child: Text(
                              selectedForDeletion.length == _trashQueue.length
                                  ? 'Deselect All'
                                  : 'Select All',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    const Divider(height: 1),

                    // Grid of Trash Candidates
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _trashQueue.length,
                        itemBuilder: (ctx, index) {
                          final asset = _trashQueue[index];
                          final isSelected = selectedForDeletion.contains(asset.id);

                          return GestureDetector(
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
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AssetEntityImage(
                                    asset,
                                    isOriginal: false,
                                    thumbnailSize: const ThumbnailSize.square(300),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppColors.error : Colors.transparent,
                                      width: 2.5,
                                    ),
                                    color: isSelected
                                        ? AppColors.error.withValues(alpha: 0.2)
                                        : Colors.black.withValues(alpha: 0.35),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.error : Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_rounded
                                          : Icons.close_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Bottom Action Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Keep Swiping'),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: selectedForDeletion.isEmpty || _isProcessingDelete
                                  ? null
                                  : () async {
                                      Navigator.pop(ctx);
                                      await _executeTrash(selectedForDeletion.toList());
                                    },
                              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                              label: Text(
                                'Move ${selectedForDeletion.length} to Trash',
                                style: const TextStyle(fontWeight: FontWeight.bold),
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
                          'Swipe to Clean',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          totalRemaining > 0
                              ? 'Card ${_currentIndex + 1} of ${_activeAssets.length}'
                              : 'Deck Completed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Trash Queue Pill / Button
                  if (_trashQueue.isNotEmpty)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.12),
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: _showReviewBottomSheet,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: Text(
                        '${_trashQueue.length} (${AppUtils.formatBytes(totalTrashBytes)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

                  return ChoiceChip(
                    avatar: Icon(
                      scope.icon,
                      size: 15,
                      color: isSelected ? Colors.white : theme.colorScheme.primary,
                    ),
                    label: Text(scope.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) _changeScope(scope);
                    },
                    selectedColor: AppColors.primary,
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

            // Bottom Action Control Row
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
                    // Trash / Swipe Left Button
                    _buildRoundActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 60,
                      iconSize: 28,
                      tooltip: 'Move to Trash (Swipe Left)',
                      onPressed: () => _triggerSwipe(SwipeAction.trash),
                    ),

                    // Undo Button
                    _buildRoundActionButton(
                      icon: Icons.undo_rounded,
                      color: Colors.amber.shade700,
                      size: 48,
                      iconSize: 22,
                      tooltip: 'Undo last card',
                      onPressed: _history.isEmpty ? null : _undoLastSwipe,
                    ),

                    // Skip / Swipe Up Button
                    _buildRoundActionButton(
                      icon: Icons.arrow_upward_rounded,
                      color: Colors.blue.shade600,
                      size: 48,
                      iconSize: 22,
                      tooltip: 'Skip (Swipe Up)',
                      onPressed: () => _triggerSwipe(SwipeAction.skip),
                    ),

                    // Keep / Swipe Right Button
                    _buildRoundActionButton(
                      icon: Icons.check_rounded,
                      color: Colors.green.shade600,
                      size: 60,
                      iconSize: 30,
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

              // Interactive Action Badges
              if (trashProgress > 0.05)
                Positioned(
                  top: 24,
                  right: 24,
                  child: Opacity(
                    opacity: trashProgress,
                    child: _buildActionBadge(
                      label: 'TRASH',
                      color: AppColors.error,
                      icon: Icons.delete_outline_rounded,
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
                      color: Colors.green.shade600,
                      icon: Icons.check_circle_outline_rounded,
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
                        color: Colors.blue.shade600,
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
    required Color color,
    required IconData icon,
    required double angle,
  }) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const Gap(8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundActionButton({
    required IconData icon,
    required Color color,
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
            : color.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Icon(
              icon,
              color: onPressed == null ? Colors.grey : color,
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
              const CircularProgressIndicator(color: AppColors.primary),
              const Gap(20),
              Text(
                'Scanning Photos...',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Gap(6),
              Text(
                'Organizing photos for swipe review',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                color: Colors.green.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 56,
              ),
            ),
            const Gap(20),
            Text(
              'All Caught Up!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(8),
            Text(
              _trashQueue.isNotEmpty
                  ? 'You reviewed this batch. Tap below to confirm and move items to Trash.'
                  : 'No photos to review in ${_selectedScope.label}. Choose another album above.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            if (_trashQueue.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _showReviewBottomSheet,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text('Review ${_trashQueue.length} Queued Items'),
              ),
          ],
        ),
      ),
    );
  }
}
