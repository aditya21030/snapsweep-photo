import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:gap/gap.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';

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

class _FullscreenPhotoViewerState extends State<FullscreenPhotoViewer> with WidgetsBindingObserver {
  late bool _selected;
  bool _showOverlay = true;

  // Video playback
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _videoError = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selected = widget.isSelected;

    if (widget.asset.type == AssetType.video) {
      _initVideoPlayer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_videoController != null && _videoController!.value.isPlaying) {
        _videoController!.pause();
      }
    }
  }

  Future<void> _initVideoPlayer() async {
    try {
      if (mounted) setState(() => _videoError = false);
      File? file = await widget.asset.file;
      file ??= await widget.asset.originFile;
      if (file == null || !mounted) {
        if (mounted) setState(() => _videoError = true);
        return;
      }

      final controller = VideoPlayerController.file(file);
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_videoListener);
      setState(() {
        _videoController = controller;
        _isVideoInitialized = true;
        _videoDuration = controller.value.duration;
        _isPlaying = true;
      });
      await controller.play();
    } catch (e) {
      debugPrint('[Video Player Error] $e');
      if (mounted) {
        setState(() => _videoError = true);
      }
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null) return;
    final value = _videoController!.value;
    setState(() {
      _videoPosition = value.position;
      _videoDuration = value.duration;
      _isPlaying = value.isPlaying;
    });
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;
    HapticFeedback.selectionClick();
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      if (_videoPosition >= _videoDuration) {
        _videoController!.seekTo(Duration.zero);
      }
      _videoController!.play();
    }
  }

  void _toggleMute() {
    if (_videoController == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _seekBy(int seconds) {
    if (_videoController == null || !_isVideoInitialized) return;
    HapticFeedback.selectionClick();
    final newPos = _videoPosition + Duration(seconds: seconds);
    final clamped = newPos < Duration.zero
        ? Duration.zero
        : (newPos > _videoDuration ? _videoDuration : newPos);
    _videoController!.seekTo(clamped);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
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
    final isVideo = asset.type == AssetType.video;
    final dateStr = asset.createDateTime.toLocal().toString().split('.').first;
    final resolutionStr = '${asset.width} × ${asset.height}';
    final mediaTypeBadge = isVideo ? 'Video' : 'Photo';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Media Viewer Body
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _showOverlay = !_showOverlay;
              });
            },
            child: Center(
              child: isVideo ? _buildVideoContent() : _buildImageContent(),
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
                      Colors.black.withValues(alpha: 0.8),
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
                            asset.title ?? (isVideo ? 'Video Preview' : 'Photo Preview'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$mediaTypeBadge | $resolutionStr | $dateStr',
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

          // Bottom Action & Video Controls Overlay
          if (_showOverlay)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.paddingOf(context).bottom + 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isVideo && _isVideoInitialized) ...[
                      // Video Timeline Slider & Time
                      Row(
                        children: [
                          Text(
                            AppUtils.formatDuration(_videoPosition),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: _videoPosition.inMilliseconds
                                    .toDouble()
                                    .clamp(0.0, _videoDuration.inMilliseconds.toDouble() > 0
                                        ? _videoDuration.inMilliseconds.toDouble()
                                        : 1.0),
                                min: 0.0,
                                max: _videoDuration.inMilliseconds.toDouble() > 0
                                    ? _videoDuration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChanged: (val) {
                                  _videoController?.seekTo(Duration(milliseconds: val.toInt()));
                                },
                              ),
                            ),
                          ),
                          Text(
                            AppUtils.formatDuration(_videoDuration),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const Gap(4),

                      // Video Control Bar (Skip -10s, Play/Pause, Skip +10s, Mute)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28),
                            onPressed: () => _seekBy(-10),
                          ),
                          const Gap(16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                          ),
                          const Gap(16),
                          IconButton(
                            icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28),
                            onPressed: () => _seekBy(10),
                          ),
                          const Gap(16),
                          IconButton(
                            icon: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: _toggleMute,
                          ),
                        ],
                      ),
                      const Gap(12),
                    ],

                    // Action buttons
                    Row(
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 5.0,
      child: AssetEntityImage(
        widget.asset,
        isOriginal: true,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              AssetEntityImage(
                widget.asset,
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
    );
  }

  Widget _buildVideoContent() {
    if (_videoController != null && _isVideoInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio > 0
                  ? _videoController!.value.aspectRatio
                  : (widget.asset.width > 0 && widget.asset.height > 0
                      ? widget.asset.width / widget.asset.height
                      : 16 / 9),
              child: VideoPlayer(_videoController!),
            ),
          ),
          if (!_isPlaying && _showOverlay)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 54,
              ),
            ),
        ],
      );
    }

    if (_videoError) {
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          AssetEntityImage(
            widget.asset,
            isOriginal: false,
            fit: BoxFit.contain,
            thumbnailSize: const ThumbnailSize.square(400),
          ),
          Container(color: Colors.black.withValues(alpha: 0.65)),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
                  const Gap(12),
                  const Text(
                    'Cannot Preview Video',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Gap(4),
                  const Text(
                    'Codec or resolution may not be supported by preview player.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(16),
                  FilledButton.tonalIcon(
                    onPressed: _initVideoPlayer,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Video Loading Placeholder
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        AssetEntityImage(
          widget.asset,
          isOriginal: false,
          fit: BoxFit.contain,
          thumbnailSize: const ThumbnailSize.square(400),
        ),
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              Gap(12),
              Text(
                'Loading Video...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
