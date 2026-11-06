import 'presentation/common/online_gate.dart';
import 'presentation/common/update_gate.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/services/widget_service.dart';
import 'presentation/providers/scan_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/permission/permission_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/swipe/swipe_cleaner_screen.dart';
import 'presentation/screens/preview/duplicate_preview_screen.dart';
import 'presentation/screens/settings/legal_screen.dart';
import 'presentation/screens/cleaner/messaging_cleaner_screen.dart';
import 'presentation/screens/compressor/media_compressor_screen.dart';
import 'presentation/screens/cleaner/smart_clean_preview_screen.dart';
import 'presentation/screens/burst/burst_cleaner_screen.dart';
import 'presentation/screens/cleaner/screenshot_cleaner_screen.dart';
import 'presentation/screens/timeline/timeline_cleaner_screen.dart';
import 'package:home_widget/home_widget.dart';

import 'presentation/screens/categories/category_cleaner_screen.dart';
import 'package:flutter/services.dart';
import 'core/services/ad_service.dart';
import 'core/services/billing_service.dart';
import 'core/services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AnalyticsService.initialize();

  // Bound thumbnail memory so gallery views leave room for background analysis.
  PaintingBinding.instance.imageCache.maximumSize = 300;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 64 << 20; // 64 MB

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Default to dark icons
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const SnapSweepApp());
}

final _router = GoRouter(
  initialLocation: '/',
  observers: [AnalyticsService.observer],
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/permission',
      builder: (context, state) => const PermissionScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/duplicates',
      builder: (context, state) =>
          const DuplicatePreviewScreen(), // Defaults to duplicate
    ),
    GoRoute(
      path: '/similar',
      builder: (context, state) =>
          const DuplicatePreviewScreen(isSimilar: true),
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
      path: '/burst-cleaner',
      builder: (context, state) => const BurstCleanerScreen(),
    ),
    GoRoute(
      path: '/screenshot-cleaner',
      builder: (context, state) => const ScreenshotCleanerScreen(),
    ),
    GoRoute(
      path: '/storage-timeline',
      builder: (context, state) => const TimelineCleanerScreen(),
    ),
    GoRoute(
      path: '/messaging-cleaner',
      builder: (context, state) => const MessagingCleanerScreen(),
    ),
    GoRoute(
      path: '/media-compressor',
      builder: (context, state) {
        final asset = state.extra as AssetEntity?;
        return MediaCompressorScreen(initialAsset: asset);
      },
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

class SnapSweepApp extends StatefulWidget {
  const SnapSweepApp({super.key});

  @override
  State<SnapSweepApp> createState() => _SnapSweepAppState();
}

class _SnapSweepAppState extends State<SnapSweepApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleWidgetLaunch();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(BillingService.reconcileOnResume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetSub?.cancel();
    BillingService.dispose();
    super.dispose();
  }

  void _handleWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then((uri) {
          if (uri != null) _navigateForUri(uri);
        })
        .catchError((Object error) {
          debugPrint('Widget launch lookup failed: $error');
        });

    _widgetSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) _navigateForUri(uri);
    });
  }

  void _navigateForUri(Uri uri) {
    if (!mounted) return;
    final targetRoute = WidgetService.routeForUri(uri);

    if (targetRoute != null) {
      final currentLoc = _router.routerDelegate.currentConfiguration.uri
          .toString();
      if (currentLoc == '/' || currentLoc == '/permission') {
        WidgetService.pendingWidgetRoute = targetRoute;
      } else {
        _router.push(targetRoute);
      }
    }
  }

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
            builder: (context, child) => UpdateGate(
              onAccessGranted: () => unawaited(
                BillingService.initialize().then((_) => AdService.initialize()),
              ),
              child: OnlineGate(child: child ?? const SizedBox.shrink()),
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
