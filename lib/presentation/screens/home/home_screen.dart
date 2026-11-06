import 'package:go_router/go_router.dart';
import '../../../core/services/widget_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/scan_provider.dart';
import '../categories/categories_screen.dart';
import '../settings/settings_screen.dart';
import '../swipe/swipe_cleaner_screen.dart';
import 'widgets/cleaner_tab.dart';
import 'widgets/floating_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    // Start scanning when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Small delay to allow UI to settle/animate before heavy lifting
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        context.read<ScanProvider>().openGallery();
        final pending = WidgetService.pendingWidgetRoute;
        if (pending != null) {
          WidgetService.pendingWidgetRoute = null;
          context.push(pending);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Define screens as const widgets to prevent rebuilding
    final List<Widget> screens = const [
      CleanerTab(),
      SwipeCleanerScreen(),
      CategoriesScreen(),
      SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true, // Important for floating effect
      body: IndexedStack(
        index: _currentIndex,
        children: [
          for (var index = 0; index < screens.length; index++)
            _visitedTabs.contains(index)
                ? TickerMode(
                    enabled: index == _currentIndex,
                    child: screens[index],
                  )
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _visitedTabs.add(index);
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
