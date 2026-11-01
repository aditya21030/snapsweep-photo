import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../providers/scan_provider.dart';
import 'widgets/category_card.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.tabCategories),
      ),
      body: Selector<ScanProvider, int>(
        selector: (_, p) => Object.hashAll(
          p.categories.entries.map((e) => Object.hash(e.key, e.value.length, p.getCategorySize(e.key))),
        ),
        builder: (context, _, child) {
          final provider = context.read<ScanProvider>();
          final categories = provider.categories;
          if (categories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
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
              // Summary Header Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${categories.length} Smart Categories',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                totalCategorizedBytes > 0
                                    ? '$totalCategorizedCount items   ${AppUtils.formatBytes(totalCategorizedBytes)} organized'
                                    : '$totalCategorizedCount items organized',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

              // Categories Grid
              SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 90 + MediaQuery.paddingOf(context).bottom),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
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
                        onTap: () {
                          if (categoryName == 'Social & WhatsApp') {
                            context.push('/messaging-cleaner');
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
