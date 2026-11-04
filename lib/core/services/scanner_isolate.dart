import 'dart:typed_data';
import 'dart:isolate';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Commands sent to the isolate
enum ScannerCommand {
  processBatch,
  finalize,
  clear,
  dispose,
}

/// Commands sent from the isolate
enum ScannerResponse {
  batchProcessed,
  finalResult,
  error,
  log,
}

class ScanItem {
  final String id;
  final String path;
  final Uint8List? thumbBytes;
  final String? cachedMd5;
  final String? cachedDHash;
  final bool? cachedIsBlurry;
  final bool needsDHash;
  final bool needsMd5;
  final bool checkBlur;
  final String? clusterId;

  ScanItem({
    required this.id,
    required this.path,
    this.thumbBytes,
    this.cachedMd5,
    this.cachedDHash,
    this.cachedIsBlurry,
    this.needsDHash = true,
    this.needsMd5 = true,
    this.checkBlur = false,
    this.clusterId,
  });
}

class ScanBatch {
  final List<ScanItem> items;
  ScanBatch(this.items);
}

class ProcessedItem {
  final String id;
  final String? dHash;
  final String? md5;
  final bool isBlurry;
  final String? clusterId;
  final int dHashHigh;
  final int dHashLow;

  ProcessedItem({
    required this.id,
    this.dHash,
    this.md5,
    this.isBlurry = false,
    this.clusterId,
    this.dHashHigh = 0,
    this.dHashLow = 0,
  });
}

class ScanResult {
  final List<List<String>> duplicateGroupIds;
  final List<List<String>> similarGroupIds;
  final List<String> blurryPhotoIds;

  ScanResult(this.duplicateGroupIds, this.similarGroupIds, this.blurryPhotoIds);
}

/// 64-bit Population Count (Hamming weight) using SWAR algorithm.
/// Executes in 12 clock cycles without loops or memory dereferences.
int _popcount64(int x) {
  x = x - ((x >> 1) & 0x5555555555555555);
  x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333);
  x = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0F;
  return ((x * 0x0101010101010101) >> 56) & 0xFF;
}

/// Converts a 128-char binary string into two 64-bit integers.
(int, int) _stringToBits128(String hash) {
  if (hash.length != 128) return (0, 0);
  int high = 0;
  int low = 0;
  for (int i = 0; i < 64; i++) {
    if (hash.codeUnitAt(i) == 49) { // '1'
      high |= (1 << i);
    }
  }
  for (int i = 0; i < 64; i++) {
    if (hash.codeUnitAt(64 + i) == 49) { // '1'
      low |= (1 << i);
    }
  }
  return (high, low);
}

/// Constant-time Hamming distance between two 128-bit hashes.
int _hammingDistanceFast(int h1High, int h1Low, int h2High, int h2Low) {
  return _popcount64(h1High ^ h2High) + _popcount64(h1Low ^ h2Low);
}

/// The entry point for the background isolate
void scannerIsolateEntry(SendPort sendPort) {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final List<ProcessedItem> processedItems = [];

  receivePort.listen((message) async {
    if (message is ScanBatch) {
      try {
        final List<ProcessedItem> results = [];
        for (final item in message.items) {
          String? dHash = item.cachedDHash;
          int dHashHigh = 0;
          int dHashLow = 0;

          if (dHash != null && dHash.length == 128) {
            final bits = _stringToBits128(dHash);
            dHashHigh = bits.$1;
            dHashLow = bits.$2;
          }

          String? md5Hash = item.cachedMd5;
          bool isBlurry = item.cachedIsBlurry ?? false;

          // Compute dHash & check sharpness if needed
          if (item.needsDHash && item.thumbBytes != null) {
            final analysis = _analyzeImage(item.thumbBytes!, sendPort, checkBlur: item.checkBlur);
            dHash ??= analysis.$1;
            if (analysis.$2 != null) {
              dHashHigh = analysis.$2!.$1;
              dHashLow = analysis.$2!.$2;
            }
            isBlurry = analysis.$3;
          } else if (item.checkBlur && item.thumbBytes != null) {
            final analysis = _analyzeImage(item.thumbBytes!, sendPort, checkBlur: true);
            isBlurry = analysis.$3;
          }

          // Sparse Fast-Hash (Tier 2.5) for duplicate verification
          if (item.needsMd5 && md5Hash == null && item.path.isNotEmpty) {
            md5Hash = await _computeFastMd5(item.path);
          }

          final result = ProcessedItem(
            id: item.id,
            dHash: dHash,
            md5: md5Hash,
            isBlurry: isBlurry,
            clusterId: item.clusterId,
            dHashHigh: dHashHigh,
            dHashLow: dHashLow,
          );
          results.add(result);
          processedItems.add(result);
        }

        sendPort.send({
          'type': ScannerResponse.batchProcessed,
          'count': results.length,
          'results': results,
        });
      } catch (e) {
        sendPort.send({'type': ScannerResponse.error, 'message': e.toString()});
      }
    } else if (message == ScannerCommand.finalize) {
      try {
        _log(sendPort, "Grouping ${processedItems.length} items by exact and visual matches...");
        final result = _computeGroups(processedItems);
        sendPort.send({
          'type': ScannerResponse.finalResult,
          'duplicates': result.duplicateGroupIds,
          'similar': result.similarGroupIds,
          'blurry': result.blurryPhotoIds,
        });
      } catch (e) {
        sendPort.send({'type': ScannerResponse.error, 'message': 'Grouping Error: $e'});
      }
    } else if (message == ScannerCommand.clear) {
      processedItems.clear();
      _log(sendPort, "Isolate memory cleared.");
    } else if (message == ScannerCommand.dispose) {
      receivePort.close();
    }
  });
}

(String?, (int, int)?, bool) _analyzeImage(Uint8List bytes, SendPort p, {bool checkBlur = false}) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return (null, null, false);
    }

    // 1. Dual-Axis dHash (9x9 downscaled for horizontal and vertical gradients)
    final resized = img.copyResize(image, width: 9, height: 9);
    final StringBuffer hashBuffer = StringBuffer();
    int hHigh = 0;
    int hLow = 0;

    // Horizontal gradients (8x8 = 64 bits -> fits in 64-bit int hHigh)
    int bitIndex = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final left = resized.getPixel(x, y).luminance;
        final right = resized.getPixel(x + 1, y).luminance;
        final isGreater = left > right;
        hashBuffer.write(isGreater ? '1' : '0');
        if (isGreater) {
          hHigh |= (1 << bitIndex);
        }
        bitIndex++;
      }
    }

    // Vertical gradients (8x8 = 64 bits -> fits in 64-bit int hLow)
    bitIndex = 0;
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final top = resized.getPixel(x, y).luminance;
        final bottom = resized.getPixel(x, y + 1).luminance;
        final isGreater = top > bottom;
        hashBuffer.write(isGreater ? '1' : '0');
        if (isGreater) {
          hLow |= (1 << bitIndex);
        }
        bitIndex++;
      }
    }

    final hash = hashBuffer.toString();

    // 2. Zero-Allocation Laplacian Variance for Blurry / Out-of-Focus Detection
    bool isBlurry = false;
    if (checkBlur) {
      isBlurry = _checkIsBlurry(image);
    }

    return (hash, (hHigh, hLow), isBlurry);
  } catch (e) {
    _log(p, "Image Analysis Error: $e");
    return (null, null, false);
  }
}

/// Zero-heap-allocation Laplacian variance.
/// Eliminates calling img.grayscale() which copies the entire image.
bool _checkIsBlurry(img.Image image) {
  final w = image.width;
  final h = image.height;
  if (w < 4 || h < 4) return false;

  num minVal = 255;
  num maxVal = 0;
  double sum = 0.0;
  double sumSq = 0.0;
  int count = 0;

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final center = image.getPixel(x, y).luminance;
      if (center < minVal) minVal = center;
      if (center > maxVal) maxVal = center;

      final top = image.getPixel(x, y - 1).luminance;
      final bottom = image.getPixel(x, y + 1).luminance;
      final left = image.getPixel(x - 1, y).luminance;
      final right = image.getPixel(x + 1, y).luminance;

      final lap = (top + bottom + left + right) - (4.0 * center);
      sum += lap;
      sumSq += lap * lap;
      count++;
    }
  }

  if (count == 0) return false;

  // Dynamic Range Guard: if contrast is too low (e.g. plain blue sky, dark night photo),
  // it is not an out-of-focus photo, it is a uniform or minimalist scene.
  if ((maxVal - minVal) < 35) {
    return false;
  }

  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);
  return variance < 80.0; // Sharpness threshold for low variance / blurry shots
}

/// High-Performance Sparse Fast-Hasher for instant duplicate candidate matching.
/// Reads 16KB from head, 16KB from mid, 16KB from tail instead of streaming 20MB.
Future<String?> _computeFastMd5(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final length = await file.length();
    if (length == 0) return null;

    // Small files <= 64KB are hashed entirely
    if (length <= 64 * 1024) {
      final digest = await md5.bind(file.openRead()).first;
      return digest.toString();
    }

    // Sparse sample hash: head (16KB) + mid (16KB) + tail (16KB) + length
    final raf = await file.open(mode: FileMode.read);
    try {
      final sampleBuffer = BytesBuilder(copy: false);

      // Head 16KB
      final headLen = math.min(16384, length);
      sampleBuffer.add(await raf.read(headLen));

      // Mid 16KB
      if (length > 32768) {
        final midPos = (length ~/ 2) - 8192;
        await raf.setPosition(midPos);
        sampleBuffer.add(await raf.read(16384));
      }

      // Tail 16KB
      if (length > 49152) {
        final tailPos = length - 16384;
        await raf.setPosition(tailPos);
        sampleBuffer.add(await raf.read(16384));
      }

      final sampleDigest = md5.convert(sampleBuffer.takeBytes());
      return 'fast_${sampleDigest}_$length';
    } finally {
      await raf.close();
    }
  } catch (_) {
    return null;
  }
}

ScanResult _computeGroups(List<ProcessedItem> items) {
  final List<List<String>> duplicateGroups = [];
  final List<List<String>> similarGroups = [];
  final List<String> blurryPhotoIds = [];

  // 1. Exact duplicates: group by fast/complete hash
  final exactByHash = <String, List<String>>{};
  for (final item in items) {
    if (item.md5 != null && item.md5!.isNotEmpty) {
      exactByHash.putIfAbsent(item.md5!, () => []).add(item.id);
    }
    if (item.isBlurry) {
      blurryPhotoIds.add(item.id);
    }
  }

  final exactIds = <String>{};
  for (final group in exactByHash.values) {
    if (group.length > 1) {
      duplicateGroups.add(group);
      exactIds.addAll(group);
    }
  }

  // 2. Similar groups: group within temporal clusters using 64-bit bitwise popcount
  final clusterMap = <String, List<ProcessedItem>>{};
  for (final item in items) {
    if (item.dHash != null && !exactIds.contains(item.id)) {
      final cluster = item.clusterId ?? 'global';
      clusterMap.putIfAbsent(cluster, () => []).add(item);
    }
  }

  for (final clusterItems in clusterMap.values) {
    if (clusterItems.length < 2) continue;
    final processedInCluster = <String>{};

    for (int i = 0; i < clusterItems.length; i++) {
      final itemA = clusterItems[i];
      if (processedInCluster.contains(itemA.id)) continue;

      final List<String> currentSimilar = [];
      for (int j = i + 1; j < clusterItems.length; j++) {
        final itemB = clusterItems[j];
        if (processedInCluster.contains(itemB.id)) continue;

        final int distance = _hammingDistanceFast(
          itemA.dHashHigh,
          itemA.dHashLow,
          itemB.dHashHigh,
          itemB.dHashLow,
        );

        // Distance <= 16 corresponds to >= 87.5% visual similarity
        if (distance <= 16) {
          currentSimilar.add(itemB.id);
          processedInCluster.add(itemB.id);
        }
      }

      if (currentSimilar.isNotEmpty) {
        processedInCluster.add(itemA.id);
        currentSimilar.insert(0, itemA.id);
        similarGroups.add(currentSimilar);
      }
    }
  }

  return ScanResult(duplicateGroups, similarGroups, blurryPhotoIds);
}

void _log(SendPort port, String msg) {
  port.send({'type': ScannerResponse.log, 'message': msg});
}
