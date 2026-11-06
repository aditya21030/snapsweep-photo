import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapsweep/data/services/media_service.dart';
import 'package:snapsweep/presentation/providers/scan_provider.dart';

class TestCatalog extends MediaService {
  @override
  Future<ScanResult> fetchAllAssets({
    ScanScope scope = ScanScope.screenshots,
  }) async => ScanResult(
    [
      for (final id in ['1', '2', '3', '4'])
        AssetEntity(
          id: id,
          typeInt: 1,
          width: 100,
          height: 100,
          modifiedDateSecond: 1,
          createDateSecond: int.parse(id) * 86400,
          relativePath: 'Download/',
        ),
    ],
    {},
    'native fixture',
  );
  @override
  Future<Map<String, Map<String, dynamic>>> fetchMediaFacts() async => {
    for (final id in ['1', '2', '3', '4']) id: {'size': 100, 'modified': 1},
  };
}

class DeniedCatalog extends TestCatalog {
  @override
  Future<ScanResult> fetchAllAssets({
    ScanScope scope = ScanScope.screenshots,
  }) async => ScanResult([], {}, 'denied', hasReadPermission: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'repairs old empty results and finds exact and visual copies outside camera bursts',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await Directory.systemTemp.createTemp(
        'snapsweep_detection_',
      );
      final catalog = TestCatalog();
      final media = (await catalog.fetchAllAssets()).screenshots;
      await File('${directory.path}/scan_results.json').writeAsString(
        jsonEncode({
          'version': 1,
          'scope': 'fullGallery',
          'assets': [
            for (final a in media)
              {
                'id': a.id,
                'type': 1,
                'width': 100,
                'height': 100,
                'path': a.relativePath,
                'modified': 1,
              },
          ],
          'duplicates': [],
          'similar': [],
        }),
      );
      const channel = MethodChannel('com.yousful.snapsweep/classifier');
      late final ScanProvider provider;
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'analyzeBatch');
            calls++;
            if (calls == 2) {
              expect(
                provider.duplicateGroups,
                hasLength(1),
                reason:
                    'Saved exact matches must stay visible during a recheck',
              );
              expect(
                provider.similarGroups,
                hasLength(1),
                reason:
                    'Saved similar matches must stay visible during a recheck',
              );
            }
            final rows = call.arguments['items'] as List;
            expect(
              rows.every(
                (row) => row['verifyBytes'] == true && row['hash'] == true,
              ),
              true,
            );
            return [
              for (final row in rows)
                {
                  'id': row['id'],
                  'ok': true,
                  'verifiedMd5': ['1', '2'].contains(row['id'])
                      ? 'identical-current-byte-proof'
                      : 'unique-${row['id']}',
                  'dHash': ['1', '2'].contains(row['id'])
                      ? '0' * 128
                      : '1' * 128,
                  'labels': {'Dog': 0.98},
                  'text': '',
                },
            ];
          });
      provider = ScanProvider(
        getDirectory: () async => directory,
        mediaService: catalog,
      );
      try {
        await provider.openGallery();
        expect(provider.duplicateGroups.single.map((a) => a.id).toSet(), {
          '1',
          '2',
        });
        expect(provider.similarGroups.single.map((a) => a.id).toSet(), {
          '3',
          '4',
        });
        expect(provider.categories['Pets & Animals'], hasLength(4));
        expect(provider.isLoading, false);
        expect(provider.isCategorizing, false);
        expect(provider.categorizationProcessed, 4);
        expect(
          calls,
          1,
          reason: 'Detection and classification must share one native batch',
        );
        await provider.scan(force: true);
        expect(calls, 1, reason: 'Unchanged media must reuse verified results');
        await provider.recheckMatches();
        expect(calls, 2);
        expect(
          provider.categorizationTotal,
          0,
          reason: 'Rechecking matches must keep completed semantic categories',
        );
        expect(provider.duplicateGroups, hasLength(1));
        final saved = jsonDecode(
          await File('${directory.path}/scan_results.json').readAsString(),
        );
        expect(saved['analysisVersion'], ScanProvider.analysisVersion);
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
    'unreadable media reports an error instead of persisting an empty successful scan',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await Directory.systemTemp.createTemp(
        'snapsweep_unreadable_',
      );
      const channel = MethodChannel('com.yousful.snapsweep/classifier');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => [
              for (final row in call.arguments['items'] as List)
                {'id': row['id'], 'ok': false},
            ],
          );
      final provider = ScanProvider(
        getDirectory: () async => directory,
        mediaService: TestCatalog(),
      );
      try {
        await provider.scan();
        expect(provider.isLoading, false);
        expect(provider.scanErrorMessage, isNotNull);
        final checkpoint =
            jsonDecode(
                  await File(
                    '${directory.path}/scan_results.json',
                  ).readAsString(),
                )
                as Map;
        expect(
          checkpoint['analysisVersion'],
          0,
          reason: 'Unreadable media must never be marked as a completed scan',
        );
        expect(checkpoint['duplicates'], isEmpty);
        expect(checkpoint['similar'], isEmpty);
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
    'deletion during a batch does not resurrect images or persist partial analysis as complete',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await Directory.systemTemp.createTemp(
        'snapsweep_live_delete_',
      );
      const channel = MethodChannel('com.yousful.snapsweep/classifier');
      final started = Completer<void>();
      final release = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            started.complete();
            await release.future;
            return [
              for (final row in call.arguments['items'] as List)
                {
                  'id': row['id'],
                  'ok': true,
                  'verifiedMd5': ['1', '2'].contains(row['id'])
                      ? 'proof'
                      : 'proof-${row['id']}',
                  'dHash': ['1', '2'].contains(row['id'])
                      ? '0' * 128
                      : '1' * 128,
                  'labels': {'Dog': 0.98},
                  'text': '',
                },
            ];
          });
      final provider = ScanProvider(
        getDirectory: () async => directory,
        mediaService: TestCatalog(),
      );
      try {
        final scanning = provider.scan();
        await started.future;
        await provider.removeAssets(['1']);
        final partial = jsonDecode(
          await File('${directory.path}/scan_results.json').readAsString(),
        );
        expect(partial['analysisVersion'], 0);
        release.complete();
        await scanning;
        expect(provider.duplicateGroups, isEmpty);
        expect(
          provider.categories.values
              .expand((assets) => assets)
              .map((a) => a.id),
          isNot(contains('1')),
        );
        final cache =
            jsonDecode(
                  await File(
                    '${directory.path}/scan_cache.json',
                  ).readAsString(),
                )
                as Map;
        expect(cache.containsKey('1'), false);
        final complete = jsonDecode(
          await File('${directory.path}/scan_results.json').readAsString(),
        );
        expect(complete['analysisVersion'], ScanProvider.analysisVersion);
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
    'permission denial is not saved as a successful empty gallery',
    () async {
      SharedPreferences.setMockInitialValues({'scan_cache_schema_version': 10});
      final directory = await Directory.systemTemp.createTemp(
        'snapsweep_denied_',
      );
      final provider = ScanProvider(
        getDirectory: () async => directory,
        mediaService: DeniedCatalog(),
      );
      try {
        await provider.scan();
        expect(provider.scanErrorMessage, isNotNull);
        expect(
          await File('${directory.path}/scan_results.json').exists(),
          false,
        );
      } finally {
        provider.dispose();
        await Future<void>.delayed(Duration.zero);
        await directory.delete(recursive: true);
      }
    },
  );
}
