import '../../common/operation_result.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:vidsqueeze/vidsqueeze.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_utils.dart';
import '../../../data/services/media_service.dart';
import '../../providers/scan_provider.dart';

class MediaCompressorScreen extends StatefulWidget {
  final AssetEntity? initialAsset;

  const MediaCompressorScreen({super.key, this.initialAsset});

  @override
  State<MediaCompressorScreen> createState() => _MediaCompressorScreenState();
}

class _MediaCompressorScreenState extends State<MediaCompressorScreen> {
  AssetEntity? _selectedAsset;
  CompressionPreset _selectedPreset = CompressionPreset.balanced;
  bool _replaceOriginal = false;
  int? _resolvedOriginalBytes;

  // Active Compression State
  bool _isPreparingCompression = false;
  bool _isCompressing = false;
  double _compressionProgress = 0.0;
  String? _activeTaskId;
  StreamSubscription<CompressionState>? _stateSub;

  // Completed State
  CompressionResult? _lastResult;
  VideoPlayerController? _previewController;
  final List<String> _previewTempFiles = [];
  bool _isSavingToGallery = false;

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.initialAsset;
    if (_selectedAsset != null) {
      _resolveAssetSize(_selectedAsset!);
    }

    _stateSub = Vidsqueeze.instance.states().listen((state) {
      if (_activeTaskId != null && state.taskId == _activeTaskId) {
        if (mounted) {
          setState(() {
            if (state.progressPercent != null) {
              _compressionProgress = (state.progressPercent! / 100.0).clamp(
                0.0,
                1.0,
              );
            }
          });
        }
      }
    });
  }

  void _resolveAssetSize(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file != null && await file.exists()) {
        final len = await file.length();
        if (mounted && _selectedAsset?.id == asset.id && len > 0) {
          setState(() => _resolvedOriginalBytes = len);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    if (_isCompressing && _activeTaskId != null) {
      Vidsqueeze.instance.cancel(_activeTaskId!);
    }
    unawaited(_disposePreviewAndCleanup());
    super.dispose();
  }

  Future<void> _disposePreviewAndCleanup() async {
    final controller = _previewController;
    _previewController = null;
    final paths = List<String>.of(_previewTempFiles);
    _previewTempFiles.clear();
    await controller?.dispose();
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  double _getProjectedSavingsRatio(CompressionPreset preset) {
    return switch (preset) {
      CompressionPreset.smallSize => 0.80,
      CompressionPreset.balanced => 0.65,
      CompressionPreset.quality => 0.40,
    };
  }

  CompressionResolutionCap _getResolutionCap(CompressionPreset preset) {
    return switch (preset) {
      CompressionPreset.smallSize => CompressionResolutionCap.p720,
      CompressionPreset.balanced => CompressionResolutionCap.p1080,
      CompressionPreset.quality => CompressionResolutionCap.p1440,
    };
  }

  Future<void> _startCompression() async {
    if (_isPreparingCompression || _isCompressing || _isSavingToGallery) return;
    _isPreparingCompression = true;
    try {
      await _prepareAndCompress();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not prepare video: $error')),
        );
      }
    } finally {
      _isPreparingCompression = false;
    }
  }

  Future<void> _prepareAndCompress() async {
    if (_selectedAsset == null || _isCompressing) return;

    HapticFeedback.mediumImpact();
    final asset = _selectedAsset!;
    final file = await asset.file;
    if (file == null || !await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access original video file.'),
          ),
        );
      }
      return;
    }

    final fileLength = await file.length();
    if (fileLength <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected video file is empty or corrupted.'),
          ),
        );
      }
      return;
    }

    final String inputUri =
        file.path.startsWith('content://') || file.path.startsWith('file://')
        ? file.path
        : Uri.file(file.path).toString();

    final tempDir = await getTemporaryDirectory();
    final taskId = 'compress_${DateTime.now().millisecondsSinceEpoch}';
    final outputName = 'snapsweep_$taskId.mp4';
    await _disposePreviewAndCleanup();
    if (!mounted) return;

    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.01;
      _activeTaskId = taskId;
      _lastResult = null;
    });

    try {
      final request = CompressionRequest(
        taskId: taskId,
        inputPath: inputUri,
        outputDirectoryPath: tempDir.path,
        outputFileName: outputName,
        preset: _selectedPreset,
        maxResolutionCap: _getResolutionCap(_selectedPreset),
        allowHevc: true,
        keepAudio: true,
        keepOriginalIfLarger: true,
        progressIntervalMs: 150,
      );

      final result = await Vidsqueeze.instance.compress(request);

      if (!mounted || _activeTaskId != taskId) return;
      if (result.usedOriginalSource ||
          (result.sourceSizeBytes > 0 &&
              result.outputSizeBytes >= result.sourceSizeBytes)) {
        if (!result.usedOriginalSource && result.outputPath.isNotEmpty) {
          final outputFile = File(result.outputPath);
          final tempRoot = '${tempDir.absolute.path}${Platform.pathSeparator}';
          if (outputFile.absolute.path.startsWith(tempRoot)) {
            try {
              await outputFile.delete();
            } catch (_) {}
          }
        }
        if (!mounted) return;
        setState(() {
          _isCompressing = false;
          _activeTaskId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Compression did not reduce this video. The original was kept unchanged.',
            ),
          ),
        );
        return;
      }

      if (result.outputPath.isNotEmpty) {
        HapticFeedback.heavyImpact();

        final outputFile = File(result.outputPath);
        if (await outputFile.exists()) {
          final tempRoot = '${tempDir.absolute.path}${Platform.pathSeparator}';
          if (outputFile.absolute.path.startsWith(tempRoot)) {
            _previewTempFiles.add(outputFile.path);
          }
          VideoPlayerController? controller;
          try {
            controller = VideoPlayerController.file(outputFile);
            await controller.initialize();
            controller.setLooping(true);
          } catch (playerErr) {
            debugPrint('[Preview Player Init Error] $playerErr');
            controller?.dispose();
            controller = null;
          }
          if (!mounted) {
            await controller?.dispose();
            return;
          }

          setState(() {
            _lastResult = result;
            _isCompressing = false;
            _activeTaskId = null;
            _previewController = controller;
          });

          // Finalize and save result to gallery
          await _finalizeAndSave(result, asset);
        } else {
          if (!mounted) return;
          setState(() {
            _isCompressing = false;
            _activeTaskId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compression output could not be found.'),
            ),
          );
        }
      } else {
        setState(() {
          _isCompressing = false;
          _activeTaskId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compression did not produce an output file.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Compressor Error] $e');
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _activeTaskId = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Compression failed: $e')));
      }
    }
  }

  Future<void> _cancelCompression() async {
    final taskId = _activeTaskId;
    if (taskId == null) return;
    HapticFeedback.selectionClick();
    _activeTaskId = null;
    await Vidsqueeze.instance.cancel(taskId);
    if (mounted) {
      setState(() {
        _isCompressing = false;
        _activeTaskId = null;
        _compressionProgress = 0.0;
      });
    }
  }

  Future<void> _finalizeAndSave(
    CompressionResult result,
    AssetEntity original,
  ) async {
    if (_isSavingToGallery) return;
    setState(() => _isSavingToGallery = true);

    try {
      final outputFile = File(result.outputPath);
      if (!await outputFile.exists()) return;

      // 1. Save compressed video to device Gallery
      await PhotoManager.editor.saveVideo(
        outputFile,
        title: 'compressed_${original.title ?? "video.mp4"}',
      );

      if (!mounted) return;

      var message = 'Compressed copy saved to Gallery. Original kept.';
      if (_replaceOriginal &&
          !result.usedOriginalSource &&
          result.outputSizeBytes < result.sourceSizeBytes) {
        final canTrash = await MediaService.supportsTrash();
        if (!mounted) return;
        final deleted = await MediaService.removeAssetsWithIds([original.id]);
        if (deleted.isNotEmpty && mounted) {
          await context.read<ScanProvider>().removeAssets(deleted);
          final savings = AppUtils.formatBytes(
            result.sourceSizeBytes - result.outputSizeBytes,
          );
          message = canTrash
              ? 'Compressed copy saved. Original moved to Trash. $savings can be reclaimed after Trash is emptied.'
              : 'Compressed copy saved. Original deleted. Saved $savings.';
        }
      }
      if (mounted) await showOperationResult(context, message: message);
    } catch (e) {
      debugPrint('[Compressor Save Error] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save compressed video: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingToGallery = false);
    }
  }

  Future<bool> _handleWillPop() async {
    if (_isSavingToGallery) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saving the compressed video. Please wait.'),
        ),
      );
      return false;
    }
    if (_isCompressing) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text('Cancel Compression?'),
          content: const Text(
            'A video is currently being compressed. Exiting will cancel this operation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.trashRedLight,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel & Leave'),
            ),
          ],
        ),
      );
      if (shouldLeave == true) {
        await _cancelCompression();
        return true;
      }
      return false;
    }

    if (widget.initialAsset == null && _selectedAsset != null) {
      setState(() {
        _selectedAsset = null;
        _resolvedOriginalBytes = null;
        _lastResult = null;
        _previewController?.dispose();
        _previewController = null;
      });
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final largeVideos = provider.largeVideos;
    final sizes = provider.assetSizes;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final cardBg = isDark ? AppColors.ink2 : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final mutedColor = isDark
        ? AppColors.lavender.withValues(alpha: 0.7)
        : AppColors.ink.withValues(alpha: 0.6);

    int totalVideoBytes = 0;
    for (final v in largeVideos) {
      totalVideoBytes += sizes[v.id] ?? 0;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final canLeave = await _handleWillPop();
        if (canLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: () async {
              final canLeave = await _handleWillPop();
              if (canLeave && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedAsset == null ? 'Large videos' : 'Compress video',
                style: AppTypography.heading20(color: textColor),
              ),
              if (_selectedAsset == null)
                Text(
                  '${largeVideos.length} videos | ${AppUtils.formatBytes(totalVideoBytes)}',
                  style: AppTypography.caption11(
                    color: mutedColor,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
        ),
        body: _selectedAsset == null
            ? _buildVideoPickerList(
                largeVideos,
                sizes,
                cardBg,
                textColor,
                mutedColor,
                isDark,
              )
            : _buildCompressionWorkflow(
                _selectedAsset!,
                sizes,
                cardBg,
                textColor,
                mutedColor,
                isDark,
              ),
      ),
    );
  }

  Widget _buildVideoPickerList(
    List<AssetEntity> videos,
    Map<String, int> sizes,
    Color cardBg,
    Color textColor,
    Color mutedColor,
    bool isDark,
  ) {
    if (videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.videocam_off_rounded,
                  color: AppColors.gold,
                  size: 52,
                ),
              ),
              const Gap(16),
              Text(
                'No Large Videos Found',
                style: AppTypography.title30(color: textColor),
              ),
              const Gap(6),
              Text(
                'Your gallery does not have heavy videos requiring compression.',
                textAlign: TextAlign.center,
                style: AppTypography.body15(color: mutedColor),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Violet Hero Banner (Pages 15 & 45)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.violet,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lilac,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'SAVE UP TO 80%',
                          style: AppTypography.caption11(
                            color: AppColors.ink,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Gap(10),
                      Text(
                        'Compress & save space',
                        style: AppTypography.heading20(color: Colors.white),
                      ),
                      const Gap(4),
                      Text(
                        'Shrink 4K and 1080p videos with native hardware encoding.',
                        style: AppTypography.body15(color: AppColors.lilac),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // List of candidate videos
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const Gap(10),
            itemBuilder: (ctx, index) {
              final video = videos[index];
              final size = sizes[video.id] ?? 0;
              final duration = Duration(seconds: video.duration);
              final is4k = video.width >= 3840 || video.height >= 2160;

              return Material(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedAsset = video;
                      _resolvedOriginalBytes = size > 0 ? size : null;
                      _lastResult = null;
                      _previewController?.dispose();
                      _previewController = null;
                    });
                    if (size == 0) {
                      _resolveAssetSize(video);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AssetEntityImage(
                                video,
                                isOriginal: false,
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                thumbnailSize: const ThumbnailSize.square(200),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              if (is4k)
                                Positioned(
                                  bottom: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '4K',
                                      style: AppTypography.caption11(
                                        color: AppColors.ink,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Gap(14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                video.title ?? 'Video #${index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.subheading17(
                                  color: textColor,
                                ),
                              ),
                              const Gap(4),
                              Row(
                                children: [
                                  Text(
                                    AppUtils.formatBytes(size),
                                    style: AppTypography.meta13(
                                      color: AppColors.violet,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Gap(8),
                                  Text(
                                    AppUtils.formatDuration(duration),
                                    style: AppTypography.caption11(
                                      color: mutedColor,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: AppColors.ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedAsset = video;
                              _resolvedOriginalBytes = size > 0 ? size : null;
                              _lastResult = null;
                            });
                          },
                          child: Text(
                            'Compress',
                            style: AppTypography.button15(
                              color: AppColors.ink,
                            ).copyWith(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompressionWorkflow(
    AssetEntity asset,
    Map<String, int> sizes,
    Color cardBg,
    Color textColor,
    Color mutedColor,
    bool isDark,
  ) {
    final originalBytes = _resolvedOriginalBytes ?? sizes[asset.id] ?? 0;
    final savingsRatio = _getProjectedSavingsRatio(_selectedPreset);
    final projectedBytes = (originalBytes * (1 - savingsRatio)).toInt();
    final estimatedSavingsBytes = (originalBytes * savingsRatio).toInt();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        36 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // Video Preview Container
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.black,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (_previewController != null &&
                  _previewController!.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _previewController!.value.aspectRatio,
                    child: VideoPlayer(_previewController!),
                  ),
                )
              else
                AssetEntityImage(
                  asset,
                  isOriginal: false,
                  fit: BoxFit.cover,
                  thumbnailSize: const ThumbnailSize.square(800),
                ),
              if (_previewController != null)
                Center(
                  child: IconButton(
                    iconSize: 52,
                    icon: Icon(
                      _previewController!.value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        if (_previewController!.value.isPlaying) {
                          _previewController!.pause();
                        } else {
                          _previewController!.play();
                        }
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
        const Gap(16),

        // Comparison & Savings Card (Pages 18, 20 & 21)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Size',
                        style: AppTypography.caption11(
                          color: mutedColor,
                          letterSpacing: 0,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        AppUtils.formatBytes(originalBytes),
                        style: AppTypography.heading20(color: textColor),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.violet,
                    size: 20,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _lastResult != null ? 'Compressed' : 'Projected Size',
                        style: AppTypography.caption11(
                          color: mutedColor,
                          letterSpacing: 0,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        _lastResult != null
                            ? AppUtils.formatBytes(_lastResult!.outputSizeBytes)
                            : AppUtils.formatBytes(projectedBytes),
                        style: AppTypography.heading20(color: AppColors.violet),
                      ),
                    ],
                  ),
                ],
              ),
              const Gap(14),
              // Gold Savings Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.savings_rounded,
                      color: AppColors.ink,
                      size: 20,
                    ),
                    const Gap(8),
                    Text(
                      _lastResult != null
                          ? (_lastResult!.sourceSizeBytes > 0 &&
                                    _lastResult!.outputSizeBytes <
                                        _lastResult!.sourceSizeBytes
                                ? 'YOU SAVED ${AppUtils.formatBytes(_lastResult!.sourceSizeBytes - _lastResult!.outputSizeBytes)} | ${(100 - (_lastResult!.outputSizeBytes / _lastResult!.sourceSizeBytes * 100)).toInt()}%'
                                : 'Original was already optimal size')
                          : 'YOU SAVE ~${AppUtils.formatBytes(estimatedSavingsBytes)} | ${(savingsRatio * 100).toInt()}%',
                      style: AppTypography.button15(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(16),

        // Quality Presets (Page 18)
        if (_lastResult == null && !_isCompressing) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Select Preset',
              style: AppTypography.meta13(
                color: mutedColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildPresetOption(
            preset: CompressionPreset.balanced,
            title: 'Balanced (Recommended)',
            badge: 'BEST',
            subtitle:
                '1080p Full HD | Great balance of clarity and ~65% size reduction',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            isDark: isDark,
          ),
          const Gap(10),
          _buildPresetOption(
            preset: CompressionPreset.smallSize,
            title: 'Maximum Space Saver',
            badge: null,
            subtitle:
                '720p HD | Perfect for sharing on WhatsApp, saves ~80% space',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            isDark: isDark,
          ),
          const Gap(10),
          _buildPresetOption(
            preset: CompressionPreset.quality,
            title: 'Ultra HD Preserver',
            badge: null,
            subtitle:
                '1440p / 2K | Retains highest detail with optimized HEVC bitrate',
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            isDark: isDark,
          ),
          const Gap(16),

          // Replace original switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Remove original after saving',
                style: AppTypography.subheading17(color: textColor),
              ),
              subtitle: Text(
                'Android 11+: moves to Trash. Older Android: permanently deletes. Trash must be emptied to reclaim space.',
                style: AppTypography.caption11(
                  color: mutedColor,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w400,
                ),
              ),
              value: _replaceOriginal,
              activeThumbColor: AppColors.gold,
              activeTrackColor: AppColors.ink,
              onChanged: (val) => setState(() => _replaceOriginal = val),
            ),
          ),
          const Gap(20),
        ],

        // Compression in progress (Page 19)
        if (_isCompressing) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  '${(_compressionProgress * 100).toInt()}%',
                  style: AppTypography.display48(color: AppColors.violet),
                ),
                const Gap(8),
                Text(
                  'Encoding with hardware acceleration...',
                  style: AppTypography.body15(color: mutedColor),
                ),
                const Gap(16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _compressionProgress,
                    backgroundColor: isDark
                        ? AppColors.ink
                        : AppColors.lavender,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.violet,
                    ),
                    minHeight: 8,
                  ),
                ),
                const Gap(20),
                TextButton(
                  onPressed: _cancelCompression,
                  child: Text(
                    'Cancel',
                    style: AppTypography.button15(
                      color: AppColors.trashRedLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else if (_lastResult == null) ...[
          // Start Compression Button
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _startCompression,
            child: Text(
              'Start compression',
              style: AppTypography.button15(color: Colors.white),
            ),
          ),
        ] else ...[
          // Completed Actions (Pages 20 & 21)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedAsset = null;
                _lastResult = null;
                _previewController?.dispose();
                _previewController = null;
              });
            },
            child: Text(
              'Compress another video',
              style: AppTypography.button15(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPresetOption({
    required CompressionPreset preset,
    required String title,
    required String? badge,
    required String subtitle,
    required Color cardBg,
    required Color textColor,
    required Color mutedColor,
    required bool isDark,
  }) {
    final isSelected = preset == _selectedPreset;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPreset = preset);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.violet : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.violet : mutedColor,
                    width: isSelected ? 6 : 2,
                  ),
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.subheading17(color: textColor),
                        ),
                        if (badge != null) ...[
                          const Gap(8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: AppTypography.caption11(
                                color: AppColors.ink,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(3),
                    Text(
                      subtitle,
                      style: AppTypography.caption11(
                        color: mutedColor,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
