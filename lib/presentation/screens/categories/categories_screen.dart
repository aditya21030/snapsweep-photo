import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_strings.dart';
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
      body: Selector<ScanProvider, List<String>>(
        selector: (_, provider) => provider.categories.keys.toList(),
        shouldRebuild: (prev, next) => prev.length != next.length,
        builder: (context, keys, child) {
          if (keys.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return GridView.builder(
            cacheExtent: 2000,
            padding: EdgeInsets.fromLTRB(20, 16, 20, 90 + MediaQuery.paddingOf(context).bottom),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final categoryName = keys[index];

              return Selector<ScanProvider, ({int count, AssetEntity? thumb})>(
                selector: (_, provider) {
                  final list = provider.categories[categoryName] ?? [];
                  return (count: list.length, thumb: list.isNotEmpty ? list.first : null);
                },
                builder: (context, data, _) {
                  return CategoryCard(
                    title: categoryName,
                    count: '${data.count} items',
                    thumbnail: data.thumb,
                    onTap: () {
                      context.push(
                        '/category-cleaner',
                        extra: {
                          'title': categoryName,
                          'assets': context.read<ScanProvider>().categories[categoryName] ?? [],
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
