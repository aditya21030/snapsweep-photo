import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import 'package:flutter_test/flutter_test.dart';
import 'package:snapsweep/core/services/scanner_isolate.dart';

Future<Map> _scan(List<ScanBatch> batches) async {
  final receivePort = ReceivePort();
  final result = Completer<Map>();
  final isolate = await Isolate.spawn(
    scannerIsolateEntry,
    receivePort.sendPort,
  );
  var batchesProcessed = 0;
  final processed = <ProcessedItem>[];
  SendPort? commandPort;
  final subscription = receivePort.listen((message) {
    if (message is SendPort) {
      commandPort = message;
      for (final batch in batches) {
        message.send(batch);
      }
    } else if (message is Map) {
      if (message['type'] == ScannerResponse.batchProcessed) {
        processed.addAll((message['results'] as List).cast<ProcessedItem>());
        batchesProcessed++;
        if (batchesProcessed == batches.length) {
          commandPort!.send(ScannerCommand.finalize);
        }
      } else if (message['type'] == ScannerResponse.error) {
        if (!result.isCompleted) result.completeError(message['message']);
      } else if (message['type'] == ScannerResponse.finalResult) {
        if (!result.isCompleted) {
          result.complete({...message, 'processed': processed});
        }
      }
    }
  });

  try {
    return await result.future.timeout(const Duration(seconds: 10));
  } finally {
    await subscription.cancel();
    receivePort.close();
    isolate.kill(priority: Isolate.immediate);
  }
}

void main() {
  test('exact groups require full-file proof and unique asset IDs', () async {
    final directory = await Directory.systemTemp.createTemp('snapsweep_scan_');
    try {
      final first = File('${directory.path}/first.bin')
        ..writeAsStringSync('same bytes');
      final second = File('${directory.path}/second.bin')
        ..writeAsStringSync('same bytes');
      final different = File('${directory.path}/different.bin')
        ..writeAsStringSync('different bytes');

      ScanItem candidate(String id, String path) => ScanItem(
        id: id,
        path: path,
        cachedMd5: 'fast_stale_or_colliding_hash',
        needsMd5: false,
        needsDHash: false,
      );

      final result = await _scan([
        ScanBatch([
          candidate('first', first.path),
          candidate('second', second.path),
          candidate('different', different.path),
          candidate('missing', ''),
        ]),
        ScanBatch([
          ScanItem(
            id: 'first',
            path: '',
            cachedDHash: '0' * 128,
            needsMd5: false,
            needsDHash: false,
            clusterId: 'burst',
          ),
        ]),
      ]);

      final duplicates = (result['duplicates'] as List).cast<List<String>>();
      expect(duplicates, hasLength(1));
      expect(duplicates.single.toSet(), {'first', 'second'});
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('visual matches are suggestions, not exact duplicates', () async {
    final result = await _scan([
      ScanBatch([
        for (final id in ['a', 'b'])
          ScanItem(
            id: id,
            path: '',
            cachedDHash: '0' * 128,
            aspectRatio: 1.5,
            needsMd5: false,
            needsDHash: false,
          ),
      ]),
    ]);

    expect(result['duplicates'], isEmpty);
    final similar = (result['similar'] as List).cast<List<String>>();
    expect(similar, hasLength(1));
    expect(similar.single.toSet(), {'a', 'b'});
  });
  test(
    'blur analysis separates smooth gradients from detailed images',
    () async {
      Uint8List thumbnail(bool detailed) {
        final image = img.Image(width: 128, height: 128);
        for (var y = 0; y < 128; y++) {
          for (var x = 0; x < 128; x++) {
            final value = detailed ? (((x ~/ 4 + y ~/ 4) % 2) * 255) : x * 2;
            image.setPixelRgb(x, y, value, value, value);
          }
        }
        return Uint8List.fromList(img.encodePng(image));
      }

      final result = await _scan([
        ScanBatch([
          ScanItem(
            id: 'smooth',
            path: '',
            thumbBytes: thumbnail(false),
            checkBlur: true,
            needsMd5: false,
          ),
          ScanItem(
            id: 'detailed',
            path: '',
            thumbBytes: thumbnail(true),
            checkBlur: true,
            needsMd5: false,
          ),
        ]),
      ]);
      expect(result['blurry'], contains('smooth'));
      expect(result['blurry'], isNot(contains('detailed')));
    },
  );
  test(
    'indexed visual matching finds two changed bits across hash segments',
    () async {
      String bits(Set<int> positions) =>
          List.generate(128, (i) => positions.contains(i) ? '1' : '0').join();
      final hashes = {
        'base': bits({}),
        'near': bits({10, 90}),
        'different': bits({0, 1, 2, 3, 4, 5, 6, 7}),
      };
      final result = await _scan([
        ScanBatch([
          for (final entry in hashes.entries)
            ScanItem(
              id: entry.key,
              path: '',
              cachedDHash: entry.value,
              needsMd5: false,
              needsDHash: false,
              aspectRatio: 1.5,
            ),
        ]),
      ]);
      final similar = (result['similar'] as List).cast<List<String>>();
      expect(similar, hasLength(1));
      expect(similar.single.toSet(), {'base', 'near'});
      expect(result['duplicates'], isEmpty);
    },
  );
  test(
    'hash-only batches do not mark photos as already blur-analyzed',
    () async {
      final result = await _scan([
        ScanBatch([
          ScanItem(
            id: 'hash-only',
            path: '',
            needsMd5: false,
            needsDHash: false,
          ),
        ]),
        ScanBatch([
          ScanItem(
            id: 'cached-blur',
            path: '',
            needsMd5: false,
            needsDHash: false,
            cachedIsBlurry: true,
          ),
        ]),
      ]);
      final processed = result['processed'] as List<ProcessedItem>;
      expect(processed.first.blurChecked, false);
      expect(processed.last.blurChecked, true);
      expect(result['blurry'], contains('cached-blur'));
    },
  );
  test(
    'current native byte proof works without raw filesystem paths',
    () async {
      final result = await _scan([
        ScanBatch([
          ScanItem(
            id: 'a',
            path: '',
            verifiedMd5: 'same-current-proof',
            needsMd5: false,
            needsDHash: false,
          ),
          ScanItem(
            id: 'b',
            path: '',
            verifiedMd5: 'same-current-proof',
            needsMd5: false,
            needsDHash: false,
          ),
          ScanItem(
            id: 'unverified',
            path: '',
            cachedMd5: 'same-current-proof',
            needsMd5: false,
            needsDHash: false,
          ),
        ]),
      ]);
      final groups = (result['duplicates'] as List).cast<List<String>>();
      expect(groups.single.toSet(), {'a', 'b'});
    },
  );
  test(
    'cached burst sharpness survives a refresh without reanalyzing thumbnails',
    () async {
      final result = await _scan([
        ScanBatch([
          ScanItem(
            id: 'sharp',
            path: '',
            needsMd5: false,
            needsDHash: false,
            cachedIsBlurry: false,
            cachedSharpness: 94,
          ),
          ScanItem(
            id: 'soft',
            path: '',
            needsMd5: false,
            needsDHash: false,
            cachedIsBlurry: true,
            cachedSharpness: 22,
            cachedBlurType: 'motion',
          ),
        ]),
      ]);
      expect((result['sharpness'] as Map)['sharp'], 94);
      expect((result['sharpness'] as Map)['soft'], 22);
      expect((result['blurTypes'] as Map)['soft'], 'motion');
    },
  );
}
