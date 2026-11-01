import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String count;
  final AssetEntity? thumbnail;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.count,
    this.thumbnail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05), width: 1), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), // Reduced opacity for performance
              blurRadius: 5, // Reduced blur radius
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.grey[200], 
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
                      thumbnailSize: const ThumbnailSize.square(250), // Reduced thumb size slightly
                      fit: BoxFit.cover,
                    )
                  else
                    const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
  
                  // Gradient Overlay
                  const _GradientOverlay(), // Extracted to const widget
  
                  // Text Content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                        const Gap(4),
                        Text(
                          count,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
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
            Colors.transparent,
            Colors.black, 
          ],
          stops: const [0.3, 1.0], 
        ),
      ),
    );
  }
}
