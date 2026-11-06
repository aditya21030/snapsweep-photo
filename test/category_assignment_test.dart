import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapsweep/presentation/providers/scan_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'batch moves and deletion preserve exclusive membership and accurate sizes',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await Directory.systemTemp.createTemp(
        'snapsweep_categories_',
      );
      const channel = MethodChannel('com.yousful.snapsweep/classifier');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => [
              {
                'id': '1',
                'ok': true,
                'labels': {'Dog': 0.97},
                'text': '',
              },
              {
                'id': '2',
                'ok': true,
                'labels': {'Receipt': 0.99},
                'text': 'Grand total Rs 500',
              },
            ],
          );
      final assets = [
        for (final id in ['1', '2', '3'])
          {
            'id': id,
            'type': 1,
            'width': 100,
            'height': 100,
            'path': 'Pictures/Screenshots/',
          },
      ];
      await File('${directory.path}/scan_results.json').writeAsString(
        jsonEncode({
          'version': 1,
          'analysisVersion': 2,
          'scope': 'fullGallery',
          'assets': assets,
        }),
      );
      await File('${directory.path}/scan_cache.json').writeAsString(
        jsonEncode({
          for (final id in ['1', '2', '3'])
            id: {
              'size': 100,
              'category': id == '3' ? 'Pets & Animals' : 'Photo Library',
              'category_done': id == '3',
            },
        }),
      );
      final provider = ScanProvider(getDirectory: () async => directory);
      try {
        await provider.openGallery();
        await provider.categorizationComplete;
        expect(provider.categories['Photo Library'], isEmpty);
        expect(
          provider.categories['Pets & Animals']!.map((a) => a.id).toSet(),
          {'1', '3'},
        );
        expect(provider.categories['Bills & Finance']!.single.id, '2');
        expect(provider.categories['Screenshots'], isEmpty);
        expect(provider.screenshotAssets, hasLength(3));
        expect(provider.getCategorySize('Pets & Animals'), 200);
        expect(provider.categories.values.expand((list) => list), hasLength(3));
        await provider.removeAssets(['1']);
        expect(provider.categories['Pets & Animals']!.single.id, '3');
        expect(provider.getCategorySize('Pets & Animals'), 100);
        expect(provider.categories.values.expand((list) => list), hasLength(2));
        expect(provider.screenshotAssets, hasLength(2));
      } finally {
        provider.dispose();
        await Future<void>.delayed(Duration.zero);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      }
    },
  );
}
