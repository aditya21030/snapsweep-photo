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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 4-color cycling system per PDF design: Violet, Ink, Gold, Lilac
    final (Color cardBg, Color textColor, Color mutedColor, Color iconBg) = switch (index % 4) {
      0 => (AppColors.violet, Colors.white, AppColors.lilac, Colors.white.withValues(alpha: 0.2)),
      1 => (isDark ? AppColors.ink2 : AppColors.ink, Colors.white, AppColors.lilac, Colors.white.withValues(alpha: 0.2)),
      2 => (AppColors.gold, AppColors.ink, AppColors.ink.withValues(alpha: 0.7), AppColors.ink.withValues(alpha: 0.12)),
      _ => (isDark ? AppColors.violetDeep : AppColors.lilac, isDark ? Colors.white : AppColors.ink, isDark ? AppColors.lilac : AppColors.ink.withValues(alpha: 0.7), isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.ink.withValues(alpha: 0.08)),
    };

    return RepaintBoundary(
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Icon + Size Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCategoryIcon(title),
                        color: textColor,
                        size: 16,
                      ),
                    ),
                    if (size != null && size!.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: iconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            size!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption11(color: textColor, letterSpacing: 0, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
                const Gap(10),

                // Generous, prominent photo preview
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      color: iconBg.withValues(alpha: 0.12),
                      child: thumbnail != null
                          ? AssetEntityImage(
                              thumbnail!,
                              isOriginal: false,
                              thumbnailSize: const ThumbnailSize.square(320),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Center(
                              child: Icon(
                                _getCategoryIcon(title),
                                size: 36,
                                color: textColor.withValues(alpha: 0.35),
                              ),
                            ),
                    ),
                  ),
                ),
                const Gap(10),

                // Bottom Titles: Clean 2-line wrapping so full name is visible
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body15(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ).copyWith(height: 1.15),
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
        ),
      ),
    );
  }
}
