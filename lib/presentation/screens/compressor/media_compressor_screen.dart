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
import '../../../core/utils/app_utils.dart';
import '../../providers/scan_provider.dart';

class MediaCompressorScreen extends StatefulWidget {
  final AssetEntity? initialAsset;

  const MediaCompressorScreen({
    super.key,
    this.initialAsset,
  });

  @override
  State<MediaCompressorScreen> createState() => _MediaCompressorScreenState();
}

class _MediaCompressorScreenState extends State<MediaCompressorScreen> {
  AssetEntity? _selectedAsset;
  CompressionPreset _selectedPreset = CompressionPreset.balanced;
  bool _replaceOriginal = true;

  // Active Compression State
  bool _isCompressing = false;
  double _compressionProgress = 0.0;
  String? _activeTaskId;
  StreamSubscription<CompressionState>? _stateSub;

  // Completed State
  CompressionResult? _lastResult;
  VideoPlayerController? _previewController;
  bool _isSavingToGallery = false;

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.initialAsset;

    _stateSub = Vidsqueeze.instance.states().listen((state) {
      if (_activeTaskId != null && state.taskId == _activeTaskId) {
        if (mounted) {
          setState(() {
            if (state.progressPercent != null) {
              _compressionProgress = (state.progressPercent! / 100.0).clamp(0.0, 1.0);
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _previewController?.dispose();
    super.dispose();
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
    if (_selectedAsset == null || _isCompressing) return;

    HapticFeedback.mediumImpact();
    final asset = _selectedAsset!;
    final file = await asset.file;
    if (file == null || !await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access original video file.')),
        );
      }
      return;
    }

    final String inputUri = file.path.startsWith('content://') || file.path.startsWith('file://')
        ? file.path
        : Uri.file(file.path).toString();

    final tempDir = await getTemporaryDirectory();
    final taskId = 'compress_${DateTime.now().millisecondsSinceEpoch}';
    final outputName = 'snapsweep_$taskId.mp4';

    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.01;
      _activeTaskId = taskId;
      _lastResult = null;
      _previewController?.dispose();
      _previewController = null;
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

      if (!mounted) return;

      if (result.outputPath.isNotEmpty) {
        HapticFeedback.heavyImpact();

        final outputFile = File(result.outputPath);
        if (await outputFile.exists()) {
          final controller = VideoPlayerController.file(outputFile);
          await controller.initialize();
          controller.setLooping(true);

          setState(() {
            _lastResult = result;
            _isCompressing = false;
            _previewController = controller;
          });

          // Auto-replace original if chosen
          if (_replaceOriginal) {
            await _finalizeAndSave(result, asset);
          }
        }
      } else {
        setState(() {
          _isCompressing = false;
          _activeTaskId = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compression did not produce an output file.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Compression failed: $e')),
        );
      }
    }
  }

  Future<void> _cancelCompression() async {
    final taskId = _activeTaskId;
    if (taskId == null) return;
    HapticFeedback.selectionClick();
    await Vidsqueeze.instance.cancel(taskId);
    if (mounted) {
      setState(() {
        _isCompressing = false;
        _activeTaskId = null;
        _compressionProgress = 0.0;
      });
    }
  }

  Future<void> _finalizeAndSave(CompressionResult result, AssetEntity original) async {
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

      if (mounted) {
        // 2. Safely move original large video to Trash
        final List<String> deleted = await PhotoManager.editor.deleteWithIds([original.id]);
        if (deleted.isNotEmpty && mounted) {
          await context.read<ScanProvider>().removeAssets(deleted);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Original moved to Trash! Saved ${AppUtils.formatBytes(result.sourceSizeBytes - result.outputSizeBytes)}',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Compressor Save Error] $e');
    } finally {
      if (mounted) setState(() => _isSavingToGallery = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScanProvider>();
    final largeVideos = provider.largeVideos;
    final sizes = provider.assetSizes;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress & Save'),
      ),
      body: _selectedAsset == null
          ? _buildVideoPickerList(largeVideos, sizes, theme, isDark)
          : _buildCompressionWorkflow(_selectedAsset!, sizes, theme, isDark),
    );
  }

  Widget _buildVideoPickerList(
    List<AssetEntity> videos,
    Map<String, int> sizes,
    ThemeData theme,
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E2DE2).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.compress_rounded, color: Color(0xFF8E2DE2), size: 48),
              ),
              const Gap(16),
              Text(
                'No Large Videos Found',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Gap(6),
              Text(
                'Your gallery does not have heavy videos requiring compression.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8E2DE2).withValues(alpha: 0.35),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 24),
                ),
                const Gap(14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save up to 80% Space',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Shrink 4K and 1080p videos using native hardware encoding without deleting memories.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
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
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const Gap(10),
            itemBuilder: (ctx, index) {
              final video = videos[index];
              final size = sizes[video.id] ?? 0;
              final duration = Duration(seconds: video.duration);

              return Material(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedAsset = video;
                      _lastResult = null;
                      _previewController?.dispose();
                      _previewController = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AssetEntityImage(
                                video,
                                isOriginal: false,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                thumbnailSize: const ThumbnailSize.square(200),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const Gap(4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8E2DE2).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      AppUtils.formatBytes(size),
                                      style: const TextStyle(
                                        color: Color(0xFF8E2DE2),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const Gap(8),
                                  Text(
                                    AppUtils.formatDuration(duration),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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
    ThemeData theme,
    bool isDark,
  ) {
    final originalBytes = sizes[asset.id] ?? 0;
    final savingsRatio = _getProjectedSavingsRatio(_selectedPreset);
    final projectedBytes = (originalBytes * (1 - savingsRatio)).toInt();
    final estimatedSavingsBytes = (originalBytes * savingsRatio).toInt();

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 36 + MediaQuery.paddingOf(context).bottom),
      children: [
        // Video Preview Card
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.black,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (_previewController != null && _previewController!.value.isInitialized)
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
              if (_lastResult != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                        Gap(6),
                        Text(
                          'Compressed Preview',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_previewController != null)
                Center(
                  child: IconButton(
                    iconSize: 48,
                    icon: Icon(
                      _previewController!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: Colors.white70,
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

        // Size & Savings Projection Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Original Size', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      const Gap(2),
                      Text(
                        AppUtils.formatBytes(originalBytes),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.grey, size: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _lastResult != null ? 'Compressed Size' : 'Projected Size',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      const Gap(2),
                      Text(
                        _lastResult != null
                            ? AppUtils.formatBytes(_lastResult!.outputSizeBytes)
                            : AppUtils.formatBytes(projectedBytes),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF8E2DE2)),
                      ),
                    ],
                  ),
                ],
              ),
              const Gap(12),
              const Divider(height: 1),
              const Gap(12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.eco_rounded, color: Colors.green, size: 18),
                    const Gap(8),
                    Text(
                      _lastResult != null
                          ? 'Saved ${AppUtils.formatBytes(_lastResult!.sourceSizeBytes - _lastResult!.outputSizeBytes)} (${(100 - (_lastResult!.outputSizeBytes / _lastResult!.sourceSizeBytes * 100)).toInt()}%)'
                          : 'Save ~${AppUtils.formatBytes(estimatedSavingsBytes)} (${(savingsRatio * 100).toInt()}% reduction)',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Gap(18),

        // Quality Preset Selector
        if (_lastResult == null && !_isCompressing) ...[
          Text('Compression Preset', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Gap(10),
          _buildPresetOption(
            preset: CompressionPreset.balanced,
            title: 'Balanced (Recommended)',
            subtitle: '1080p Full HD | Great balance of clarity and ~65% size reduction',
            theme: theme,
          ),
          const Gap(8),
          _buildPresetOption(
            preset: CompressionPreset.smallSize,
            title: 'Maximum Space Saver',
            subtitle: '720p HD | Perfect for sharing on WhatsApp, saves ~80% space',
            theme: theme,
          ),
          const Gap(8),
          _buildPresetOption(
            preset: CompressionPreset.quality,
            title: 'Ultra HD Preserver',
            subtitle: '1440p / 4K | Retains highest detail with optimized HEVC bitrate',
            theme: theme,
          ),
          const Gap(16),

          // Replace original switch
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Move Original to Trash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text(
              'Safely frees storage immediately while keeping the compressed copy.',
              style: TextStyle(fontSize: 12),
            ),
            value: _replaceOriginal,
            activeThumbColor: const Color(0xFF8E2DE2),
            onChanged: (val) => setState(() => _replaceOriginal = val),
          ),
          const Gap(20),
        ],

        // Compression In Progress Bar
        if (_isCompressing) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF8E2DE2).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Hardware Encoding...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      '${(_compressionProgress * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8E2DE2), fontSize: 15),
                    ),
                  ],
                ),
                const Gap(12),
                LinearProgressIndicator(
                  value: _compressionProgress,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: const Color(0xFF8E2DE2),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(6),
                ),
                const Gap(16),
                OutlinedButton.icon(
                  onPressed: _cancelCompression,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel Compression'),
                ),
              ],
            ),
          ),
        ] else if (_lastResult == null) ...[
          // Start Compression Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8E2DE2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _startCompression,
            icon: const Icon(Icons.compress_rounded, size: 22),
            label: const Text(
              'Start Fast Compression',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ] else ...[
          // Completed Actions
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            icon: const Icon(Icons.check_rounded, size: 22),
            label: const Text('Compress Another Video', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _buildPresetOption({
    required CompressionPreset preset,
    required String title,
    required String subtitle,
    required ThemeData theme,
  }) {
    final isSelected = preset == _selectedPreset;

    return Material(
      color: isSelected
          ? const Color(0xFF8E2DE2).withValues(alpha: 0.1)
          : theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPreset = preset);
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF8E2DE2) : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              width: isSelected ? 1.8 : 1,
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
                    color: isSelected ? const Color(0xFF8E2DE2) : Colors.grey,
                    width: isSelected ? 6 : 2,
                  ),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Gap(2),
                    Text(
                      subtitle,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
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
