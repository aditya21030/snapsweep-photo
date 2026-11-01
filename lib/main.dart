import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/scan_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/permission/permission_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/swipe/swipe_cleaner_screen.dart';
import 'presentation/screens/preview/duplicate_preview_screen.dart';
import 'presentation/screens/settings/legal_screen.dart';
import 'presentation/screens/cleaner/messaging_cleaner_screen.dart';
import 'presentation/screens/cleaner/smart_clean_preview_screen.dart';

import 'presentation/screens/categories/category_cleaner_screen.dart';
import 'package:flutter/services.dart';
import 'core/services/ad_service.dart';
import 'core/services/billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Optimize image cache for buttery smooth photo grid scrolling
  PaintingBinding.instance.imageCache.maximumSize = 2500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 250 << 20; // 250 MB

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Default to dark icons
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  
  // Initialize billing & ads safely
  await BillingService.initialize();
  await AdService.initialize();
  
  runApp(const SnapSweepApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/permission',
      builder: (context, state) => const PermissionScreen(),
    ),
     GoRoute(
       path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/duplicates',
      builder: (context, state) => const DuplicatePreviewScreen(), // Defaults to duplicate
    ),
    GoRoute(
       path: '/similar',
       builder: (context, state) => const DuplicatePreviewScreen(isSimilar: true), 
    ),
    GoRoute(
      path: '/smart-clean',
      builder: (context, state) => const SmartCleanPreviewScreen(),
    ),
    GoRoute(
      path: '/swipe-clean',
      builder: (context, state) => const SwipeCleanerScreen(),
    ),
    GoRoute(
      path: '/messaging-cleaner',
      builder: (context, state) => const MessagingCleanerScreen(),
    ),
    GoRoute(
      path: '/large-videos',
      builder: (context, state) {
        final provider = context.read<ScanProvider>();
        return CategoryCleanerScreen(
          title: 'Large Videos',
          assets: provider.largeVideos,
        );
      },
    ),
    GoRoute(
      path: '/blurry-photos',
      builder: (context, state) {
        final provider = context.read<ScanProvider>();
        return CategoryCleanerScreen(
          title: 'Blurry Photos',
          assets: provider.blurryPhotos,
        );
      },
    ),
    GoRoute(
      path: '/category-cleaner',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return CategoryCleanerScreen(
          title: extra['title'] as String,
          assets: extra['assets'] as List<AssetEntity>,
        );
      },
    ),
    GoRoute(
      path: '/legal',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return LegalScreen(
          title: extra['title'] as String,
          content: extra['content'] as String,
        );
      },
    ),
  ],
);

class SnapSweepApp extends StatelessWidget {
  const SnapSweepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'SnapSweep',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
