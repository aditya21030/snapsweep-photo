import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:gap/gap.dart';
import '../../core/constants/app_colors.dart';

class FullscreenPhotoViewer extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final ValueChanged<bool>? onSelectionChanged;
  final String? subtitle;

  const FullscreenPhotoViewer({
    super.key,
    required this.asset,
    this.isSelected = false,
    this.onSelectionChanged,
    this.subtitle,
  });

  static Future<bool?> open(
    BuildContext context, {
    required AssetEntity asset,
    bool isSelected = false,
    ValueChanged<bool>? onSelectionChanged,
    String? subtitle,
  }) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        pageBuilder: (context, _, _) => FullscreenPhotoViewer(
          asset: asset,
          isSelected: isSelected,
          onSelectionChanged: onSelectionChanged,
          subtitle: subtitle,
        ),
        transitionsBuilder: (context, anim, _, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  @override
  State<FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<FullscreenPhotoViewer> {
  late bool _selected;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.isSelected;
  }

  void _toggleSelection() {
    HapticFeedback.selectionClick();
    setState(() {
      _selected = !_selected;
    });
    widget.onSelectionChanged?.call(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final dateStr = asset.createDateTime.toLocal().toString().split('.').first;
    final resolutionStr = '${asset.width} × ${asset.height}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Pinch-to-zoom interactive viewer
          GestureDetector(
            onTap: () {
              setState(() {
                _showOverlay = !_showOverlay;
              });
            },
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: AssetEntityImage(
                  asset,
                  isOriginal: true,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    // While full-res loads, show thumbnail placeholder
                    return Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        AssetEntityImage(
                          asset,
                          isOriginal: false,
                          fit: BoxFit.contain,
                          thumbnailSize: const ThumbnailSize.square(400),
                        ),
                        const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Top App Bar Overlay
          if (_showOverlay)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + 8,
                  16,
                  16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context, _selected),
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            asset.title ?? 'Photo Preview',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$resolutionStr • $dateStr',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Action Bar Overlay
          if (_showOverlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  MediaQuery.paddingOf(context).bottom + 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.subtitle != null) ...[
                      Expanded(
                        child: Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Gap(16),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _selected
                              ? AppColors.error
                              : Colors.white.withValues(alpha: 0.25),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _toggleSelection,
                        icon: Icon(
                          _selected
                              ? Icons.delete_sweep_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                        label: Text(
                          _selected ? 'Selected for Trash' : 'Select to Clean',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
