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
        selector: (_, p) => Object.hash(
          p.categorizationProcessed,
          p.isCategorizing,
          p.isLoading,
          Object.hashAll(
            p.categories.entries.map(
              (e) =>
                  Object.hash(e.key, e.value.length, p.getCategorySize(e.key)),
            ),
          ),
        ),
        builder: (context, _, child) {
          final provider = context.read<ScanProvider>();
          final categories = provider.categories;
          if (categories.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.violet),
            );
          }

          // Sort category keys: categories with largest total size / count first
          final sortedKeys = categories.keys.toList()
            ..sort((a, b) {
              final sizeA = provider.getCategorySize(a);
              final sizeB = provider.getCategorySize(b);
              if (sizeA != sizeB) return sizeB.compareTo(sizeA);
              return (categories[b]?.length ?? 0).compareTo(
                categories[a]?.length ?? 0,
              );
            });

          final uniqueIds = categories.values
              .expand((assets) => assets)
              .map((asset) => asset.id)
              .toSet();
          final totalCategorizedCount = uniqueIds.length;
          final totalCategorizedBytes = uniqueIds.fold<int>(
            0,
            (total, id) => total + (provider.assetSizes[id] ?? 0),
          );

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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                provider.isCategorizing || provider.isLoading
                                    ? 'ORGANIZING GALLERY'
                                    : 'ORGANIZED GALLERY',
                                style: AppTypography.caption11(
                                  color: AppColors.ink,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (provider.isCategorizing || provider.isLoading) ...[
                          const Gap(12),
                          const LinearProgressIndicator(color: AppColors.gold),
                        ],
                        const Gap(12),
                        Text(
                          provider.isCategorizing
                              ? 'Organizing library ${provider.categorizationProcessed} / ${provider.categorizationTotal}'
                              : '${categories.length} Categories Organized',
                          style: AppTypography.title30(color: Colors.white),
                        ),
                        const Gap(4),
                        Text(
                          '$totalCategorizedCount unique items | ${AppUtils.formatBytes(totalCategorizedBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body15(color: AppColors.lilac),
                        ),
                        const Gap(8),
                        Text(
                          'Each image belongs to one category.',
                          style: AppTypography.caption11(
                            color: AppColors.lilac,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Categories Grid
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  124 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.76,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final categoryName = sortedKeys[index];
                    final list = categories[categoryName] ?? [];
                    final thumb = list.isNotEmpty ? list.first : null;
                    final sizeStr = provider.getFormattedCategorySize(
                      categoryName,
                    );

                    return CategoryCard(
                      title: categoryName,
                      count: '${list.length} items',
                      size: sizeStr,
                      thumbnail: thumb,
                      index: index,
                      onTap: () {
                        context.push(
                          '/category-cleaner',
                          extra: {'title': categoryName, 'assets': list},
                        );
                      },
                    );
                  }, childCount: sortedKeys.length),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
