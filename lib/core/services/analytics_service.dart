import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static bool _initialized = false;

  /// Returns the FirebaseAnalyticsObserver instance to attach to GoRouter/Navigator.
  static final FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Initialize Firebase and Analytics
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;
      // Enable analytics collection
      await _analytics.setAnalyticsCollectionEnabled(true);
      await logAppOpen();
      debugPrint('[AnalyticsService] Firebase Analytics initialized successfully');
    } catch (e) {
      debugPrint('[AnalyticsService] Firebase init error: $e');
    }
  }

  /// Log when user opens the app
  static Future<void> logAppOpen() async {
    if (!_initialized) return;
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      debugPrint('[AnalyticsService] logAppOpen error: $e');
    }
  }

  /// Log screen/view change
  static Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logScreenView error: $e');
    }
  }

  /// Log when gallery scan starts
  static Future<void> logScanStarted({String? scope}) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'scan_started',
        parameters: {
          'scope': scope ?? 'full_gallery',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logScanStarted error: $e');
    }
  }

  /// Log when gallery scan completes
  static Future<void> logScanCompleted({
    required int totalAssets,
    required int duplicatesFound,
    required int similarFound,
    required int blurryFound,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'scan_completed',
        parameters: {
          'total_assets': totalAssets,
          'duplicates_found': duplicatesFound,
          'similar_found': similarFound,
          'blurry_found': blurryFound,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logScanCompleted error: $e');
    }
  }

  /// Log when clean/deletion action is completed
  static Future<void> logCleanAction({
    required String cleanType,
    required int itemCount,
    required int bytesSaved,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'clean_action_completed',
        parameters: {
          'clean_type': cleanType,
          'item_count': itemCount,
          'mb_saved': (bytesSaved / (1024 * 1024)).round(),
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logCleanAction error: $e');
    }
  }

  /// Log category interactions
  static Future<void> logCategoryViewed({
    required String categoryName,
    required int itemCount,
  }) async {
    if (!_initialized) return;
    try {
      await _analytics.logEvent(
        name: 'category_viewed',
        parameters: {
          'category_name': categoryName,
          'item_count': itemCount,
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] logCategoryViewed error: $e');
    }
  }
}
