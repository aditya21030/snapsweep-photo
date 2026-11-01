import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String count;
  final String size;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final VoidCallback onTap;
  final List<AssetEntity>? previewImages;

  const DashboardCard({
    super.key,
    required this.title,
    required this.count,
    required this.size,
    required this.icon,
    required this.startColor,
    required this.endColor,
    required this.onTap,
    this.previewImages,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: startColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Gap(4),
                          Text(
                            count, // Expected format: "X items found"
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 16,
                    ),
                  ],
                ),
                
                const Gap(20),
                
                // Preview Images
                if (previewImages != null && previewImages!.isNotEmpty) ...[
                  SizedBox(
                    height: 70, // Slightly taller for better visibility
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: previewImages!.take(4).length,
                      separatorBuilder: (c, i) => const Gap(12),
                      itemBuilder: (context, index) {
                        final asset = previewImages![index];
                         return Container(
                            width: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AssetEntityImage(
                                    asset,
                                    isOriginal: false,
                                    thumbnailSize: const ThumbnailSize.square(200),
                                    fit: BoxFit.cover,
                                  ),
                                  // Optional: Add size overlay or checkmark if needed later
                                ],
                              ),
                            ),
                          );
                      },
                    ),
                  ),
                  const Gap(20),
                ],

                // Footer Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      size, // Expected format: "X MB to clean"
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap to preview',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
