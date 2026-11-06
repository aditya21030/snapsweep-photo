import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String count;
  final String? size;
  final AssetEntity? thumbnail;
  final int index;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.count,
    this.size,
    this.thumbnail,
    required this.index,
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
      case 'Downloads':
      case 'Memes & Graphics':
        return Icons.download_rounded;
      case 'Personal & Portraits':
        return Icons.portrait_rounded;
      case 'Nature & Landscapes':
        return Icons.landscape_rounded;
      case 'Travel & Places':
        return Icons.travel_explore_rounded;
      case 'Pets & Animals':
        return Icons.pets_rounded;
      case 'Vehicles':
        return Icons.directions_car_rounded;
      case 'Shopping & Products':
        return Icons.shopping_bag_rounded;
      case 'Events & Celebrations':
        return Icons.celebration_rounded;
      case 'Sports & Fitness':
        return Icons.sports_basketball_rounded;
      case 'Art & Design':
        return Icons.palette_rounded;
      case 'Photo Library':
        return Icons.photo_library_rounded;
      case 'Videos':
        return Icons.video_library_rounded;
      default:
        return Icons.folder_special_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 4-color cycling system per PDF design: Violet, Ink, Gold, Lilac
    final (
      Color cardBg,
      Color textColor,
      Color mutedColor,
      Color iconBg,
    ) = switch (index % 4) {
      0 => (
        AppColors.violet,
        Colors.white,
        AppColors.lilac,
        Colors.white.withValues(alpha: 0.2),
      ),
      1 => (
        isDark ? AppColors.ink2 : AppColors.ink,
        Colors.white,
        AppColors.lilac,
        Colors.white.withValues(alpha: 0.2),
      ),
      2 => (
        AppColors.gold,
        AppColors.ink,
        AppColors.ink.withValues(alpha: 0.7),
        AppColors.ink.withValues(alpha: 0.12),
      ),
      _ => (
        isDark ? AppColors.violetDeep : AppColors.lilac,
        isDark ? Colors.white : AppColors.ink,
        isDark ? AppColors.lilac : AppColors.ink.withValues(alpha: 0.7),
        isDark
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.ink.withValues(alpha: 0.08),
      ),
    };

    return RepaintBoundary(
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section: Prominent, edge-to-edge photo preview (never small or boxed)
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      thumbnail != null
                          ? AssetEntityImage(
                              thumbnail!,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(256),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: iconBg.withValues(alpha: 0.18),
                                    child: Center(
                                      child: Icon(
                                        _getCategoryIcon(title),
                                        size: 42,
                                        color: textColor.withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                            )
                          : Container(
                              color: iconBg.withValues(alpha: 0.18),
                              child: Center(
                                child: Icon(
                                  _getCategoryIcon(title),
                                  size: 42,
                                  color: textColor.withValues(alpha: 0.4),
                                ),
                              ),
                            ),

                      // Gradient overlay for contrast
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.15),
                              ],
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Top Row: Category Icon Pill (Left) & Size Pill (Right)
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getCategoryIcon(title),
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            if (size != null && size!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.50),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  size!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Section: Clean, non-overflowing Title and Count
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.15,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      count,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption11(
                        color: mutedColor,
                        letterSpacing: 0,
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
    );
  }
}
