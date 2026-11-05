import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_utils.dart';
import '../../providers/scan_provider.dart';
import 'widgets/category_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.ink : AppColors.lavender;
    final textColor = isDark ? Colors.white : AppColors.ink;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Smart Categories',
          style: AppTypography.heading20(color: textColor),
        ),
      ),
      body: Selector<ScanProvider, int>(
        selector: (_, p) => Object.hashAll(
          p.categories.entries.map((e) => Object.hash(e.key, e.value.length, p.getCategorySize(e.key))),
        ),
        builder: (context, _, child) {
          final provider = context.read<ScanProvider>();
          final categories = provider.categories;
          if (categories.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.violet));
          }

          // Sort category keys: categories with largest total size / count first
          final sortedKeys = categories.keys.toList()
            ..sort((a, b) {
              final sizeA = provider.getCategorySize(a);
              final sizeB = provider.getCategorySize(b);
              if (sizeA != sizeB) return sizeB.compareTo(sizeA);
              return (categories[b]?.length ?? 0).compareTo(categories[a]?.length ?? 0);
            });

          int totalCategorizedBytes = 0;
          int totalCategorizedCount = 0;
          for (final entry in categories.entries) {
            totalCategorizedCount += entry.value.length;
            totalCategorizedBytes += provider.getCategorySize(entry.key);
          }

          return CustomScrollView(
            cacheExtent: 2000,
            slivers: [
              // Summary Header Banner (Pages 22 & 52)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.ink2 : AppColors.ink,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ORGANIZED GALLERY',
                                style: AppTypography.caption11(color: AppColors.ink, letterSpacing: 0.8),
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        Text(
                          '${categories.length} Categories Organized',
                          style: AppTypography.title30(color: Colors.white),
                        ),
                        const Gap(4),
                        Text(
                          '$totalCategorizedCount items | ${AppUtils.formatBytes(totalCategorizedBytes)} classified',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body15(color: AppColors.lilac),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Categories Grid
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 100 + MediaQuery.paddingOf(context).bottom),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.76,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final categoryName = sortedKeys[index];
                      final list = categories[categoryName] ?? [];
                      final thumb = list.isNotEmpty ? list.first : null;
                      final sizeStr = provider.getFormattedCategorySize(categoryName);

                      return CategoryCard(
                        title: categoryName,
                        count: '${list.length} items',
                        size: sizeStr,
                        thumbnail: thumb,
                        index: index,
                        onTap: () {
                          if (categoryName == 'Social & WhatsApp') {
                            context.push('/messaging-cleaner');
                          } else if (categoryName == 'Screenshots') {
                            context.push('/screenshot-cleaner');
                          } else {
                            context.push(
                              '/category-cleaner',
                              extra: {
                                'title': categoryName,
                                'assets': list,
                              },
                            );
                          }
                        },
                      );
                    },
                    childCount: sortedKeys.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
