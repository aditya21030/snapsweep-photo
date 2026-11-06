import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapsweep/data/services/media_service.dart';
import 'package:snapsweep/presentation/providers/scan_provider.dart';

class ResumeCatalog extends MediaService {
  int fetches = 0;
  bool edited = false;
  bool resized = false;
  @override
  Future<ScanResult> fetchAllAssets({
    ScanScope scope = ScanScope.fullGallery,
  }) async {
    fetches++;
    return ScanResult(
      [
        for (var id = 1; id <= 12; id++)
          AssetEntity(
            id: '$id',
            typeInt: 1,
            width: 100,
            height: 100,
            relativePath: 'Download/',
            createDateSecond: id * 86400,
            modifiedDateSecond: edited && id == 1 ? 2 : 1,
          ),
      ],
      {},
      'checkpoint fixture',
    );
  }

  @override
  Future<Map<String, Map<String, dynamic>>> fetchMediaFacts() async => {
    for (var id = 1; id <= 12; id++)
      '$id': {
        'size': resized && id == 1 ? 101 : 100,
        'modified': edited && id == 1 ? 2 : 1,
      },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.yousful.snapsweep/classifier');
  for (final change in ['none', 'edited', 'resized', 'failed-category']) {
    final edited = change == 'edited' || change == 'resized';
    final pets = change == 'failed-category' ? 10 : 12;
    test(
      'restart resumes unfinished work with $change image changes',
      () async {
        SharedPreferences.setMockInitialValues({
          'scan_cache_schema_version': 10,
        });
        final directory = await Directory.systemTemp.createTemp(
          'snapsweep_checkpoint_',
        );
        final catalog = ResumeCatalog();
        final blocked = Completer<void>();
        final release = Completer<void>();
        var calls = 0;
        var retrySucceeds = false;
        final requestsAfterRestart = <Map>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls++;
              final items = (call.arguments['items'] as List).cast<Map>();
              if (calls == 2) {
                blocked.complete();
                await release.future;
              }
              if (calls > 2) requestsAfterRestart.addAll(items);
              return [
                for (final row in items)
                  {
                    'id': row['id'],
                    'ok': true,
                    'verifiedMd5': catalog.edited && row['id'] == '1'
                        ? 'edited-content'
                        : ['1', '2'].contains(row['id'])
                        ? 'same-proof'
                        : 'unique-${row['id']}',
                    'dHash': ['1', '2'].contains(row['id'])
                        ? '0' * 128
                        : '1' * 128,
                    if (change != 'failed-category' ||
                        retrySucceeds ||
                        !['7', '8'].contains(row['id']))
                      'labels': {'Dog': .98},
                    'text': '',
                  },
              ];
            });
        final first = ScanProvider(
          getDirectory: () async => directory,
          mediaService: catalog,
        );
        final firstScan = first.openGallery();
        await blocked.future;
        final partial =
            jsonDecode(
                  await File(
                    '${directory.path}/scan_results.json',
                  ).readAsString(),
                )
                as Map;
        expect(partial['analysisVersion'], 0);
        final journal = File('${directory.path}/scan_journal.jsonl');
        expect(
          (jsonDecode(
                (await journal.readAsLines())
                    .where((line) => line.trim().isNotEmpty)
                    .single,
              )
              as Map)['entries'],
          hasLength(8),
        );
        first.dispose();
        release.complete();
        await firstScan;
        // Simulate a torn final append from an OS process kill.
        await journal.writeAsBytes([123, 34, 0xE2], mode: FileMode.append);
        catalog.edited = change == 'edited';
        catalog.resized = change == 'resized';
        final reopened = ScanProvider(
          getDirectory: () async => directory,
          mediaService: catalog,
        );
        try {
          await reopened.openGallery();
          final requestedIds = requestsAfterRestart
              .map((row) => row['id'])
              .toSet();
          expect(requestedIds, {'9', '10', '11', '12', if (edited) '1'});
          expect(reopened.categories['Pets & Animals'], hasLength(pets));
          expect(reopened.categorizationTotal, edited ? 5 : 4);
          expect(reopened.totalSize, catalog.resized ? 1201 : 1200);
          if (!edited) {
            expect(
              reopened.duplicateGroups.single.map((asset) => asset.id).toSet(),
              {'1', '2'},
            );
          }
          expect(reopened.scanErrorMessage, isNull);
          final completed =
              jsonDecode(
                    await File(
                      '${directory.path}/scan_results.json',
                    ).readAsString(),
                  )
                  as Map;
          expect(completed['analysisVersion'], ScanProvider.analysisVersion);
        } finally {
          reopened.dispose();
        }
        final before = calls;
        final fetches = catalog.fetches;
        // The atomic result snapshot contains category/cache data too: recovery
        // must not depend on a separate cache file being present or current.
        final cache = File('${directory.path}/scan_cache.json');
        if (await cache.exists()) await cache.delete();
        final completedReopen = ScanProvider(
          getDirectory: () async => directory,
          mediaService: catalog,
        );
        try {
          await completedReopen.openGallery();
          await completedReopen.categorizationComplete;
          expect(
            calls,
            before,
            reason: 'A completed restart must not analyze any image again',
          );
          expect(
            catalog.fetches,
            fetches,
            reason: 'A completed restart must not enumerate the gallery again',
          );
          expect(completedReopen.categories['Pets & Animals'], hasLength(pets));
          expect(completedReopen.totalSize, catalog.resized ? 1201 : 1200);
          expect(completedReopen.isLoading, isFalse);
          if (change == 'failed-category') {
            final retryStart = requestsAfterRestart.length;
            retrySucceeds = true;
            await completedReopen.scan(force: true);
            await completedReopen.categorizationComplete;
            expect(
              requestsAfterRestart
                  .skip(retryStart)
                  .map((row) => row['id'])
                  .toSet(),
              {'7', '8'},
            );
            expect(completedReopen.categories['Pets & Animals'], hasLength(12));
          }
        } finally {
          completedReopen.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          await directory.delete(recursive: true);
        }
      },
    );
  }
}
