import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../common/dashboard_card.dart';
import '../../../providers/scan_provider.dart';
import '../../../../data/services/media_service.dart';

class CleanerTab extends StatelessWidget {
  const CleanerTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 90 + MediaQuery.paddingOf(context).bottom),
        children: const [
           Gap(16),
           _HeaderSection(),
           Gap(16),
           _ProgressSection(),
           _SmartCleanSection(),
           _DashboardSection(),
           _DebugLogSection(),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.cleanerTitle,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Selector<ScanProvider, bool>(
              selector: (_, p) => p.isLoading,
              builder: (context, isLoading, _) {
                return IconButton.filledTonal(
                  icon: Icon(
                    isLoading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                    size: 20,
                  ),
                  onPressed: isLoading ? null : () => context.read<ScanProvider>().scan(force: true),
                  tooltip: 'Rescan Gallery',
                );
              },
            ),
          ],
        ),
        const Gap(6),
        Selector<ScanProvider, ({bool isLoading, int count, String size, ScanScope scope})>(
          selector: (_, p) => (
            isLoading: p.isLoading, 
            count: p.allScreenshots.length, 
            size: p.formattedTotalSize, 
            scope: p.scanScope
          ),
          builder: (context, data, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.isLoading
                      ? 'Scanning ${data.scope.label.toLowerCase()}...'
                      : '${data.count} items found | ${data.size}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(12),
                // Modern Interactive Scan Scope Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ScanScope.values.length,
                    separatorBuilder: (_, _) => const Gap(8),
                    itemBuilder: (context, index) {
                      final scope = ScanScope.values[index];
                      final isSelected = scope == data.scope;
                      return ChoiceChip(
                        avatar: Icon(
                          scope.icon,
                          size: 16,
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(scope.label),
                        selected: isSelected,
                        onSelected: data.isLoading ? null : (selected) {
                          if (selected) {
                            HapticFeedback.selectionClick();
                            context.read<ScanProvider>().setScanScope(scope);
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        showCheckmark: false,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    return Selector<ScanProvider, ({bool isLoading, double progress, List<AssetEntity> recent, bool isFirstScan, String timer, String statusMessage})>(
      selector: (_, p) => (
         isLoading: p.isLoading, 
         progress: p.progress, 
         recent: List.of(p.recentScanned),
         isFirstScan: p.isFirstScan,
         timer: p.formattedScanDuration,
         statusMessage: p.scanStatusMessage,
      ),
      builder: (context, data, child) {
         if (!data.isLoading) return const SizedBox.shrink();
         return Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(
                             data.isFirstScan ? "Fast Scanning Gallery..." : "Scanning...", 
                             style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)
                           ),
                           if (data.statusMessage.isNotEmpty)
                             Text(
                               data.statusMessage,
                               style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                             ),
                         ],
                       ),
                     ),
                     Text(
                       "${(data.progress * 100).toInt()}%", 
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                         fontWeight: FontWeight.bold, 
                         color: AppColors.primary
                       )
                     ),
                  ],
                ),
                const Gap(10),
                AnimatedScannerBar(progress: data.progress),
                const Gap(12),
                
                if (data.recent.isNotEmpty)
                  SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: data.recent.map((asset) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AssetEntityImage(
                              asset,
                              width: 36, height: 36,
                              fit: BoxFit.cover,
                              thumbnailSize: const ThumbnailSize.square(80),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
      },
    );
  }
}

class AnimatedScannerBar extends StatefulWidget {
  final double progress;
  const AnimatedScannerBar({super.key, required this.progress});

  @override
  State<AnimatedScannerBar> createState() => _AnimatedScannerBarState();
}

class _AnimatedScannerBarState extends State<AnimatedScannerBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this,
       duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     return Container(
        height: 18,
        width: double.infinity,
        decoration: BoxDecoration(
           color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
           borderRadius: BorderRadius.circular(12),
           border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), 
              width: 1
           ),
        ),
        clipBehavior: Clip.hardEdge,
        child: CustomPaint(
           painter: _WaveProgressPainter(
              progress: widget.progress,
              animationValue: _controller,
              color: AppColors.primary,
           ),
        ),
     );
  }
}

class _WaveProgressPainter extends CustomPainter {
  final double progress;
  final Animation<double> animationValue;
  final Color color;

  _WaveProgressPainter({
    required this.progress,
    required this.animationValue,
    required this.color,
  }) : super(repaint: animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final Paint paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final double width = size.width * progress;
    final double waveHeight = 3.0; 
    final double waveFrequency = 2.0; 

    final Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(width, 0);

    for (double y = 0; y <= size.height; y++) {
       double waveOffset = 0;
       if (progress > 0.02 && progress < 0.98) {
          waveOffset = math.sin((y / size.height * waveFrequency * math.pi * 2) + (animationValue.value * math.pi * 2)) * waveHeight;
       }
       path.lineTo(width + waveOffset, y);
    }

    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WaveProgressPainter oldDelegate) {
     return oldDelegate.progress != progress || oldDelegate.animationValue != animationValue;
  }
}

class _SmartCleanSection extends StatelessWidget {
  const _SmartCleanSection();

  @override
  Widget build(BuildContext context) {
    return Selector<ScanProvider, ({bool isLoading, int size, String formattedSize, List<AssetEntity> previews})>(
      selector: (_, p) => (
        isLoading: p.isLoading, 
        size: p.smartCleanSize, 
        formattedSize: p.formattedSmartCleanSize,
        previews: p.smartCleanPreviews
      ),
      builder: (context, data, child) {
         if (data.isLoading && data.size <= 0) return const SizedBox.shrink();

         if (data.size <= 0) {
             return Container(
               margin: const EdgeInsets.only(bottom: 16),
               padding: const EdgeInsets.all(18),
               decoration: BoxDecoration(
                 color: Theme.of(context).cardColor,
                 borderRadius: BorderRadius.circular(20),
                 border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
               ),
               child: Row(
                 children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                    ),
                    const Gap(14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Gallery Clean & Healthy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text("No byte-for-byte exact duplicate copies found.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                 ],
               ),
             );
         }

         return Container(
           margin: const EdgeInsets.only(bottom: 16), 
           padding: const EdgeInsets.all(20),
           decoration: BoxDecoration(
             gradient: const LinearGradient(
               colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
             ),
             borderRadius: BorderRadius.circular(24),
             boxShadow: [
               BoxShadow(
                 color: const Color(0xFF6A11CB).withValues(alpha: 0.35),
                 blurRadius: 12,
                 offset: const Offset(0, 6),
               ),
             ],
           ),
           child: Column(
             children: [
               Row(
                 children: [
                   SizedBox(
                     width: 70,
                     height: 50,
                     child: Stack(
                       children: [
                         if (data.previews.isEmpty)
                            Container(
                               padding: const EdgeInsets.all(10),
                               decoration: BoxDecoration(
                                 color: Colors.white.withValues(alpha: 0.2),
                                 shape: BoxShape.circle,
                               ),
                               child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 24),
                            )
                         else 
                           ...List.generate(data.previews.length, (index) {
                             return Positioned(
                               left: index * 12.0,
                               child: Container(
                                 decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(color: Colors.white, width: 2),
                                 ),
                                 clipBehavior: Clip.antiAlias,
                                 child: AssetEntityImage(
                                     data.previews[index],
                                     width: 40, height: 40,
                                     fit: BoxFit.cover,
                                     thumbnailSize: const ThumbnailSize.square(100),
                                 ),
                               ),
                             );
                           }).reversed, 
                       ],
                     ),
                   ),
                   const Gap(12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Row(
                           children: [
                             const Text(
                               "Exact Copies Clean",
                               style: TextStyle(
                                 color: Colors.white,
                                 fontWeight: FontWeight.bold,
                                 fontSize: 17,
                               ),
                             ),
                             const Gap(8),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.greenAccent.withValues(alpha: 0.25),
                                 borderRadius: BorderRadius.circular(6),
                               ),
                               child: const Text(
                                 "SAFE",
                                 style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                               ),
                             )
                           ],
                         ),
                         const Gap(4),
                         Text(
                           "Free up ${data.formattedSize} of exact clones",
                           style: TextStyle(
                             color: Colors.white.withValues(alpha: 0.9),
                             fontSize: 13,
                           ),
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
               const Gap(16),
               SizedBox(
                 width: double.infinity,
                 child: FilledButton(
                   onPressed: () {
                     context.push('/smart-clean');
                   },
                   style: FilledButton.styleFrom(
                     backgroundColor: Colors.white,
                     foregroundColor: const Color(0xFF6A11CB),
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                   ),
                   child: Text(
                     "Review & Clean (${data.formattedSize})", 
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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

class _DashboardSection extends StatelessWidget {
  const _DashboardSection();

  @override
  Widget build(BuildContext context) {
    return Selector<ScanProvider, ({
      bool isLoading,
      int dupCount,
      String dupSize,
      int simCount,
      String simSize,
      int vidCount,
      String vidSize,
      int blurCount,
      String blurSize,
    })>(
      selector: (_, p) => (
        isLoading: p.isLoading,
        dupCount: p.totalDuplicateCount,
        dupSize: p.formattedDuplicateSize,
        simCount: p.totalSimilarCount,
        simSize: p.formattedSimilarSize,
        vidCount: p.largeVideos.length,
        vidSize: p.formattedLargeVideosSize,
        blurCount: p.blurryPhotos.length,
        blurSize: p.formattedBlurrySize,
      ),
      builder: (context, data, child) {
        final provider = context.read<ScanProvider>();
         final duplicatePreviews = provider.duplicateGroups
             .take(4)
             .map((group) => group.isNotEmpty ? group.first : null)
             .whereType<AssetEntity>()
             .toList();
             
         final similarPreviews = provider.similarGroups
             .take(4)
             .map((group) => group.isNotEmpty ? group.first : null)
             .whereType<AssetEntity>()
             .toList();
             
        return Column(
          children: [
            DashboardCard(
              title: AppStrings.cardDuplicate,
              count: provider.isLoading ? 'Scanning...' : '${provider.totalDuplicateCount} duplicates',
              size: provider.isLoading ? '-' : '${provider.formattedDuplicateSize} recoverable',
              icon: Icons.copy_rounded,
              startColor: AppColors.duplicateCardStart, 
              endColor: AppColors.duplicateCardEnd,
              previewImages: provider.isLoading ? null : duplicatePreviews,
              onTap: () {
                if (provider.duplicateGroups.isNotEmpty) {
                  context.push('/duplicates');
                } else if (provider.isLoading) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Analyzing duplicate candidates... ready shortly.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No duplicate photos found in this scan area.')),
                  );
                }
              },
            ),
            const Gap(14),
            DashboardCard(
              title: AppStrings.cardSimilar,
              count: provider.isLoading ? 'Scanning...' : '${provider.totalSimilarCount} similar photos',
              size: provider.isLoading ? '-' : '${provider.formattedSimilarSize} to review',
              icon: Icons.layers_outlined,
              startColor: AppColors.similarCardStart,
              endColor: AppColors.similarCardEnd, 
              previewImages: provider.isLoading ? null : similarPreviews,
              onTap: () {
                if (provider.similarGroups.isNotEmpty) {
                  context.push('/similar');
                } else if (provider.isLoading) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Analyzing burst and similar shots... ready shortly.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No visually similar photos found in this scan area.')),
                  );
                }
              },
            ),
            const Gap(14),
            DashboardCard(
              title: 'Large Videos',
              count: provider.isLoading && provider.largeVideos.isEmpty ? 'Scanning...' : '${provider.largeVideos.length} videos found',
              size: provider.isLoading && provider.largeVideos.isEmpty ? '-' : '${provider.formattedLargeVideosSize} total storage',
              icon: Icons.video_library_rounded,
              startColor: const Color(0xFFFF416C),
              endColor: const Color(0xFFFF4B2B),
              previewImages: provider.largeVideos.take(4).toList(),
              onTap: () {
                if (provider.largeVideos.isNotEmpty) {
                  context.push('/large-videos');
                } else if (provider.isLoading) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scanning videos... ready shortly.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No large videos found in this scan area.')),
                  );
                }
              },
            ),
            const Gap(14),
            DashboardCard(
              title: 'Blurry Photos',
              count: provider.isLoading && provider.blurryPhotos.isEmpty ? 'Scanning...' : '${provider.blurryPhotos.length} blurry shots',
              size: provider.isLoading && provider.blurryPhotos.isEmpty ? '-' : '${provider.formattedBlurrySize} to review',
              icon: Icons.blur_on_rounded,
              startColor: const Color(0xFF00B4DB),
              endColor: const Color(0xFF0083B0),
              previewImages: provider.blurryPhotos.take(4).toList(),
              onTap: () {
                if (provider.blurryPhotos.isNotEmpty) {
                  context.push('/blurry-photos');
                } else if (provider.isLoading) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Checking camera photos for blur... ready shortly.')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No blurry photos detected in this scan area.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _DebugLogSection extends StatelessWidget {
  const _DebugLogSection();

  @override
  Widget build(BuildContext context) {
    return Selector<ScanProvider, ({bool isLoading, String logs})>(
      selector: (_, p) => (isLoading: p.isLoading, logs: p.debugLogs),
      builder: (context, data, _) {
        if (!data.isLoading && data.logs.isNotEmpty) {
            return Padding(
             padding: const EdgeInsets.symmetric(vertical: 20),
             child: Center(
               child: TextButton.icon(
                  icon: const Icon(Icons.bug_report, size: 16),
                  label: const Text("View Scan Stats"),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Scan Diagnostics"),
                        content: SingleChildScrollView(
                          child: SelectableText(data.logs), 
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                        ],
                      ),
                    );
                  },
               ),
             ),
           );
        }
        return const SizedBox.shrink();
      }
    );
  }
}
