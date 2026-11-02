import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../utils/app_utils.dart';
import '../../presentation/providers/scan_provider.dart';

class WidgetService {
  WidgetService._();

  static const String appWidgetProvider = 'SnapSweepWidgetProvider';

  static Future<void> syncWithProvider(ScanProvider provider) async {
    try {
      final int reclaimableBytes = provider.smartCleanSize + provider.similarSize + provider.blurrySize;
      final int itemCount = provider.totalDuplicateCount + provider.totalSimilarCount + provider.blurryPhotos.length;

      final String status = itemCount > 0 ? 'Cleanup Needed' : 'Optimized';
      final String reclaimable = itemCount > 0
          ? '${AppUtils.formatBytes(reclaimableBytes)} Reclaimable'
          : 'Storage Healthy';
      final String countText = itemCount > 0
          ? '$itemCount items to review'
          : 'All clean and fast';

      await HomeWidget.saveWidgetData<String>('widget_status', status);
      await HomeWidget.saveWidgetData<String>('widget_reclaimable', reclaimable);
      await HomeWidget.saveWidgetData<String>('widget_count', countText);

      await HomeWidget.updateWidget(
        name: appWidgetProvider,
        androidName: appWidgetProvider,
      );
    } catch (e) {
      debugPrint('[WidgetService Sync Error] $e');
    }
  }
}
