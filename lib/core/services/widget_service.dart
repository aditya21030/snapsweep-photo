import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../utils/app_utils.dart';
import '../../presentation/providers/scan_provider.dart';

class WidgetService {
  WidgetService._();

  static const String appWidgetProvider = 'SnapSweepWidgetProvider';
  static const String reviewWidgetProvider = 'SnapSweepReviewWidgetProvider';
  static const String swipeWidgetProvider = 'SnapSweepSwipeWidgetProvider';
  static String? pendingWidgetRoute;

  static Future<void> syncWithProvider(ScanProvider provider) async {
    if (provider.isLoading) return;
    try {
      final int reclaimableBytes = provider.smartCleanSize + provider.similarSize + provider.blurrySize;
      final int itemCount = provider.totalDuplicateCount + provider.totalSimilarCount + provider.blurryPhotos.length;

      final formatter = NumberFormat('#,###');
      final String label = itemCount > 0 ? 'RECLAIMABLE' : 'STORAGE';
      final String reclaimable = itemCount > 0
          ? AppUtils.formatBytes(reclaimableBytes)
          : '0 B';
      final String countText = itemCount > 0
          ? '${formatter.format(itemCount)} ITEMS'
          : 'OPTIMIZED';

      await HomeWidget.saveWidgetData<String>('widget_label', label);
      await HomeWidget.saveWidgetData<String>('widget_reclaimable', reclaimable);
      await HomeWidget.saveWidgetData<String>('widget_count', countText);

      // Update 4x2 Reclaimable Widget (Page 31/61)
      await HomeWidget.updateWidget(
        name: appWidgetProvider,
        androidName: appWidgetProvider,
        qualifiedAndroidName: 'com.yousful.snapsweep.$appWidgetProvider',
      );

      // Update 2x2 To Review Widget (Page 31/61)
      await HomeWidget.updateWidget(
        name: reviewWidgetProvider,
        androidName: reviewWidgetProvider,
        qualifiedAndroidName: 'com.yousful.snapsweep.$reviewWidgetProvider',
      );

      // Update 2x2 Swipe Widget (Page 31/61)
      await HomeWidget.updateWidget(
        name: swipeWidgetProvider,
        androidName: swipeWidgetProvider,
        qualifiedAndroidName: 'com.yousful.snapsweep.$swipeWidgetProvider',
      );
    } catch (e) {
      debugPrint('[WidgetService Sync Error] $e');
    }
  }
}
