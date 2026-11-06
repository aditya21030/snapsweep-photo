import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snapsweep/data/services/media_service.dart';
import 'package:snapsweep/presentation/providers/scan_provider.dart';

Future<Directory> fixture({bool pending = false}) async {
  final directory = await Directory.systemTemp.createTemp('snapsweep_scope_');
  await File('${directory.path}/scan_results.json').writeAsString(
    jsonEncode({
      'version': 1,
      'analysisVersion': 2,
      'scope': 'fullGallery',
      'assets': [
        for (final id in ['1', '2', '3', '4'])
          {
            'id': id,
            'type': 1,
            'width': 100,
            'height': 100,
            'modified': 1,
            'path': id == '2' ? 'DCIM/Camera/' : 'Pictures/Screenshots/',
          },
      ],
      'duplicates': [
        ['1', '2'],
      ],
      'similar': [
        ['3', '4'],
      ],
    }),
  );
  await File('${directory.path}/scan_cache.json').writeAsString(
    jsonEncode({
      for (final id in ['1', '2', '3', '4'])
        id: {
          'modified': 1,
          'size': 100,
          'category': pending ? 'Photo Library' : 'Documents & IDs',
          'category_done': !pending,
        },
    }),
  );
  return directory;
}

class UnchangedGallery extends MediaService {
  int reads = 0;
  @override
  Future<ScanResult> fetchAllAssets({
    ScanScope scope = ScanScope.screenshots,
  }) async {
    reads++;
    return ScanResult(
      [
        for (final id in ['1', '2', '3', '4'])
          AssetEntity(
            id: id,
            typeInt: 1,
            width: 100,
            height: 100,
            modifiedDateSecond: 1,
            relativePath: id == '2' ? 'DCIM/Camera/' : 'Pictures/Screenshots/',
          ),
      ],
      {},
      'fixture',
    );
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchMediaFacts() async => {
    for (final id in ['1', '2', '3', '4']) id: {'size': 100, 'modified': 1},
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'scope is an instant saved-result filter and survives reopening',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await fixture();
      final provider = ScanProvider(getDirectory: () async => directory);
      try {
        await provider.openGallery();
        expect(provider.reviewGroupCount, 2);
        expect(provider.reviewGroupSummary, '1 exact / 1 similar groups');
        await provider.setScanScope(ScanScope.screenshots);
        expect(provider.isLoading, false);
        expect(provider.allScreenshots, hasLength(3));
        expect(provider.duplicateGroups, isEmpty);
        expect(provider.similarGroups, hasLength(1));
        expect(provider.reviewGroupCount, 1);
        expect(provider.preferSimilarReview, true);
        expect(provider.totalSize, 300);
        expect(
          provider.categories.values.expand((assets) => assets),
          hasLength(3),
        );
        expect(provider.debugLogs, isEmpty);
        final restored = ScanProvider(getDirectory: () async => directory);
        try {
          await restored.openGallery();
          expect(restored.scanScope, ScanScope.screenshots);
          expect(restored.allScreenshots, hasLength(3));
          expect(restored.isLoading, false);
          await restored.setScanScope(ScanScope.fullGallery);
          expect(restored.allScreenshots, hasLength(4));
          expect(restored.reviewGroupCount, 2);
          expect(restored.debugLogs, isEmpty);
        } finally {
          restored.dispose();
        }
        await provider.setScanScope(ScanScope.fullGallery);
        expect(provider.allScreenshots, hasLength(4));
        expect(provider.reviewGroupCount, 2);
      } finally {
        provider.dispose();
        await Future<void>.delayed(Duration.zero);
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'changing scope during classification neither cancels nor repeats the batch',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await fixture(pending: true);
      const channel = MethodChannel('com.yousful.snapsweep/classifier');
      final started = Completer<void>();
      final result = Completer<List<Map<String, dynamic>>>();
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) {
            calls++;
            if (!started.isCompleted) started.complete();
            return result.future;
          });
      final gallery = UnchangedGallery();
      final provider = ScanProvider(
        getDirectory: () async => directory,
        mediaService: gallery,
      );
      try {
        await provider.openGallery();
        await started.future;
        await provider.setScanScope(ScanScope.screenshots);
        expect(provider.isCategorizing, true);
        expect(provider.isLoading, false);
        expect(calls, 1);
        await provider.scan(force: true);
        expect(gallery.reads, 1);
        expect(provider.isCategorizing, true);
        expect(provider.debugLogs, contains('reused saved groups'));
        expect(calls, 1);
        result.complete([
          for (final id in ['1', '2', '3', '4'])
            {
              'id': id,
              'ok': true,
              'labels': {'Dog': 0.97},
              'text': '',
            },
        ]);
        await provider.categorizationComplete;
        expect(provider.categories['Pets & Animals'], hasLength(3));
        await provider.setScanScope(ScanScope.fullGallery);
        await provider.openGallery();
        expect(provider.categories['Pets & Animals'], hasLength(4));
        expect(provider.isCategorizing, false);
        expect(calls, 1);
      } finally {
        provider.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await Future<void>.delayed(Duration.zero);
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'switching scope prioritizes queued images without analyzing any image twice',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await Directory.systemTemp.createTemp(
        'snapsweep_priority_',
      );
      final ids = List.generate(17, (i) => '${i + 1}');
      await File('${directory.path}/scan_results.json').writeAsString(
        jsonEncode({
          'version': 1,
          'analysisVersion': 2,
          'scope': 'fullGallery',
          'assets': [
            for (final id in ids)
              {
                'id': id,
                'type': 1,
                'width': 100,
                'height': 100,
                'path': id == '17' ? 'Pictures/Screenshots/' : 'DCIM/Camera/',
              },
          ],
        }),
      );
      await File('${directory.path}/scan_cache.json').writeAsString(
        jsonEncode({
          for (final id in ids)
            id: {
              'size': 100,
              'category': 'Photo Library',
              'category_done': false,
            },
        }),
      );
      const channel = MethodChannel('com.yousful.snapsweep/classifier');
      final started = Completer<void>();
      final release = Completer<void>();
      final batches = <List<String>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            final chunk = (call.arguments['items'] as List)
                .map((row) => row['id'] as String)
                .toList();
            batches.add(chunk);
            if (batches.length == 1) {
              started.complete();
              await release.future;
            }
            return [
              for (final id in chunk)
                {
                  'id': id,
                  'ok': true,
                  'labels': {'Dog': 0.97},
                  'text': '',
                },
            ];
          });
      final provider = ScanProvider(getDirectory: () async => directory);
      try {
        await provider.openGallery();
        await started.future;
        await provider.setScanScope(ScanScope.screenshots);
        release.complete();
        await provider.categorizationComplete;
        expect(batches, hasLength(3));
        expect(batches[1].first, '17');
        expect(batches.expand((batch) => batch).length, 17);
        expect(batches.expand((batch) => batch).toSet(), ids.toSet());
        expect(provider.categories['Pets & Animals'], hasLength(1));
      } finally {
        provider.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        await Future<void>.delayed(Duration.zero);
        await directory.delete(recursive: true);
      }
    },
  );
}
