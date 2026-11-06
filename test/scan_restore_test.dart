import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapsweep/presentation/providers/scan_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'reopening restores completed scan without starting another scan',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await Directory.systemTemp.createTemp(
        'snapsweep_restore_',
      );
      final assets = [
        for (final id in ['one', 'two'])
          {
            'id': id,
            'type': 1,
            'width': 100,
            'height': 100,
            'created': 1,
            'modified': 1,
            'path': 'Pictures/Screenshots/',
          },
      ];
      await File('${directory.path}/scan_cache.json').writeAsString(
        jsonEncode({
          for (final id in ['one', 'two'])
            id: {
              'size': 100,
              'modified': 1,
              'category': 'Bills & Finance',
              'category_done': true,
            },
        }),
      );
      await File('${directory.path}/scan_results.json').writeAsString(
        jsonEncode({
          'version': 1,
          'analysisVersion': 2,
          'scope': 'fullGallery',
          'assets': assets,
          'duplicates': [
            ['one', 'two'],
          ],
          'similar': [],
          'blurry': [],
          'videos': [],
          'albums': {},
        }),
      );
      final provider = ScanProvider(getDirectory: () async => directory);
      try {
        await provider.openGallery();
        expect(provider.isLoading, false);
        expect(provider.allScreenshots.map((a) => a.id), ['one', 'two']);
        expect(provider.duplicateGroups.single.map((a) => a.id), [
          'one',
          'two',
        ]);
        expect(provider.duplicateSize, 100);
        expect(provider.categories['Screenshots'], isEmpty);
        expect(provider.screenshotAssets, hasLength(2));
        expect(
          provider.categories.values
              .expand((list) => list)
              .map((a) => a.id)
              .toSet()
              .length,
          2,
        );
        expect(provider.categories.values.expand((list) => list).length, 2);
        expect(provider.categories['Bills & Finance'], hasLength(2));
        expect(provider.totalSize, 200);
        expect(provider.isCategorizing, false);
        await provider.openGallery();
        expect(provider.duplicateGroups, hasLength(1));
        expect(provider.debugLogs, isEmpty);
      } finally {
        provider.dispose();
        await Future<void>.delayed(Duration.zero);
        await directory.delete(recursive: true);
      }
    },
  );
}
