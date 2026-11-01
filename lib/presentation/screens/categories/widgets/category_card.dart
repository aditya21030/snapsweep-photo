import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String count;
  final String? size;
  final AssetEntity? thumbnail;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.count,
    this.size,
    this.thumbnail,
    required this.onTap,
  });

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Screenshots':
        return Icons.screenshot_rounded;
      case 'Screen Recordings':
        return Icons.videocam_rounded;
      case 'Social & WhatsApp':
        return Icons.forum_rounded;
      case 'Bills & Finance':
        return Icons.receipt_long_rounded;
      case 'Documents & IDs':
        return Icons.badge_rounded;
      case 'Food & Dining':
        return Icons.restaurant_rounded;
      case 'Memes & Downloads':
        return Icons.download_rounded;
      case 'Personal & Portraits':
        return Icons.portrait_rounded;
      default:
        return Icons.folder_special_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Image
                  if (thumbnail != null)
                    AssetEntityImage(
                      thumbnail!,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(250),
                      fit: BoxFit.cover,
                    )
                  else
                    const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),

                  // Gradient Overlay
                  const _GradientOverlay(),

                  // Top Category Icon Pill
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCategoryIcon(title),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                  // Text Content
                  Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                        const Gap(4),
                        Text(
                          size != null && size!.isNotEmpty ? '$count   $size' : count,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.15),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
    );
  }
}
