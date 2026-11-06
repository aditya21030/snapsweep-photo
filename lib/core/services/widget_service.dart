import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import '../utils/app_utils.dart';
import '../../presentation/providers/scan_provider.dart';

class WidgetService {
  WidgetService._();

  static const String appWidgetProvider = 'SnapSweepWidgetProvider';
  static const String reviewWidgetProvider = 'SnapSweepReviewWidgetProvider';
  static const String swipeWidgetProvider = 'SnapSweepSwipeWidgetProvider';
  static String? pendingWidgetRoute;

  static String? routeForUri(Uri uri) {
    if (uri.scheme != 'snapsweep') return null;
    final destination = uri.host.isNotEmpty
        ? uri.host
        : uri.path.replaceFirst(RegExp(r'^/'), '');
    return switch (destination) {
      'clean' || 'smart-clean' => '/smart-clean',
      'swipe' || 'swipe-clean' => '/swipe-clean',
      _ => null,
    };
  }

  static ({int bytes, int count}) summarizeCandidates(
    Iterable<AssetEntity> candidates,
    Map<String, int> sizes,
  ) {
    final ids = candidates.map((asset) => asset.id).toSet();
    return (
      bytes: ids.fold<int>(0, (total, id) => total + (sizes[id] ?? 0)),
      count: ids.length,
    );
  }

  static Future<void> _syncWork = Future.value();

  static Future<void> syncWithProvider(ScanProvider provider) {
    if (provider.isLoading) return Future.value();
    final summary = summarizeCandidates(
      provider.smartCleanCandidates,
      provider.assetSizes,
    );
    // Serialize snapshots so an older update cannot overwrite a newer deletion.
    return _syncWork = _syncWork.then((_) => _saveSummary(summary));
  }

  static Future<void> _saveSummary(({int bytes, int count}) summary) async {
    try {
      final reclaimableBytes = summary.bytes;
      final itemCount = summary.count;

      final formatter = NumberFormat('#,###');
      final String label = itemCount > 0 ? 'RECLAIMABLE' : 'STORAGE';
      final String reclaimable = itemCount > 0
          ? AppUtils.formatBytes(reclaimableBytes)
          : '0 B';
      final String countText = itemCount > 0
          ? '${formatter.format(itemCount)} ITEMS'
          : 'OPTIMIZED';

      await HomeWidget.saveWidgetData<String>('widget_label', label);
      await HomeWidget.saveWidgetData<String>(
        'widget_reclaimable',
        reclaimable,
      );
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
