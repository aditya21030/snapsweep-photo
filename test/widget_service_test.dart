import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snapsweep/core/services/widget_service.dart';

void main() {
  test('widget totals count each review candidate once', () {
    AssetEntity asset(String id) =>
        AssetEntity(id: id, typeInt: 1, width: 10, height: 10);
    final summary = WidgetService.summarizeCandidates(
      [asset('duplicate'), asset('blurry'), asset('duplicate'), asset('video')],
      {'duplicate': 20, 'blurry': 30, 'video': 50},
    );
    expect(summary.count, 3);
    expect(summary.bytes, 100);
    expect(WidgetService.summarizeCandidates([], {}).count, 0);
  });

  test('widget links choose exact destinations', () {
    expect(
      WidgetService.routeForUri(Uri.parse('snapsweep://clean')),
      '/smart-clean',
    );
    expect(
      WidgetService.routeForUri(Uri.parse('snapsweep://swipe')),
      '/swipe-clean',
    );
    expect(
      WidgetService.routeForUri(Uri.parse('snapsweep:///swipe-clean')),
      '/swipe-clean',
    );
    expect(WidgetService.routeForUri(Uri.parse('https://clean')), isNull);
    expect(
      WidgetService.routeForUri(Uri.parse('snapsweep://unknown/clean')),
      isNull,
    );
  });
}
