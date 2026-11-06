import 'dart:typed_data';
import 'dart:isolate';
import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Commands sent to the isolate
enum ScannerCommand { processBatch, finalize, clear, dispose }

/// Commands sent from the isolate
enum ScannerResponse { batchProcessed, progress, finalResult, error, log }

class ScanItem {
  final String id;
  final String path;
  final Uint8List? thumbBytes;
  final String? cachedMd5;
  final String? verifiedMd5;
  final String? cachedDHash;
  final bool? cachedIsBlurry;
  final double? cachedSharpness;
  final String? cachedBlurType;
  final bool needsDHash;
  final bool needsMd5;
  final bool checkBlur;
  final String? clusterId;
  final double aspectRatio;

  ScanItem({
    required this.id,
    required this.path,
    this.thumbBytes,
    this.cachedMd5,
    this.verifiedMd5,
    this.cachedDHash,
    this.cachedIsBlurry,
    this.cachedSharpness,
    this.cachedBlurType,
    this.needsDHash = true,
    this.needsMd5 = true,
    this.checkBlur = false,
    this.clusterId,
    this.aspectRatio = 1.0,
  });
}

class ScanBatch {
  final List<ScanItem> items;
  ScanBatch(this.items);
}

class ProcessedItem {
  final String id;
  final String path;
  final String? dHash;
  final String? md5;
  final String? verifiedMd5;
  final bool isBlurry;
  final bool blurChecked;
  final String? clusterId;
  final int dHashHigh;
  final int dHashLow;
  final double sharpnessScore;
  final String? blurType;
  final double aspectRatio;

  ProcessedItem({
    required this.id,
    this.path = '',
    this.dHash,
    this.md5,
    this.verifiedMd5,
    this.isBlurry = false,
    this.blurChecked = false,
    this.clusterId,
    this.dHashHigh = 0,
    this.dHashLow = 0,
    this.sharpnessScore = 85.0,
    this.blurType,
    this.aspectRatio = 1.0,
  });
}

class ScanResult {
  final List<List<String>> duplicateGroupIds;
  final List<List<String>> similarGroupIds;
  final List<String> blurryPhotoIds;
  final Map<String, double> sharpnessScores;
  final Map<String, String> blurTypes;

  ScanResult(
    this.duplicateGroupIds,
    this.similarGroupIds,
    this.blurryPhotoIds, {
    this.sharpnessScores = const {},
    this.blurTypes = const {},
  });
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
    if (hash.codeUnitAt(i) == 49) {
      // '1'
      high |= (1 << i);
    }
  }
  for (int i = 0; i < 64; i++) {
    if (hash.codeUnitAt(64 + i) == 49) {
      // '1'
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
Future<void> scannerIsolateEntry(SendPort sendPort) async {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final List<ProcessedItem> processedItems = [];

  await for (final message in receivePort) {
    if (message is ScanBatch) {
      try {
        final List<ProcessedItem> results = [];
        for (final item in message.items) {
          String? dHash = item.cachedDHash;
          int dHashHigh = 0;
          int dHashLow = 0;
          double sharpness = item.cachedSharpness ?? 85.0;
          String? blurType = item.cachedBlurType;
          final double aspectRatio = item.aspectRatio;

          if (dHash != null && dHash.length == 128) {
            final bits = _stringToBits128(dHash);
            dHashHigh = bits.$1;
            dHashLow = bits.$2;
          }

          String? md5Hash = item.cachedMd5;
          bool isBlurry = item.cachedIsBlurry ?? false;

          // Compute dHash & check sharpness if needed
          if (item.needsDHash && item.thumbBytes != null) {
            final analysis = _analyzeImage(
              item.thumbBytes!,
              sendPort,
              checkBlur: item.checkBlur,
            );
            dHash ??= analysis.hash;
            if (analysis.bits != null) {
              dHashHigh = analysis.bits!.$1;
              dHashLow = analysis.bits!.$2;
            }
            isBlurry = analysis.isBlurry;
            sharpness = analysis.sharpnessScore;
            blurType = analysis.blurType;
          } else if (item.checkBlur && item.thumbBytes != null) {
            final analysis = _analyzeImage(
              item.thumbBytes!,
              sendPort,
              checkBlur: true,
            );
            isBlurry = analysis.isBlurry;
            sharpness = analysis.sharpnessScore;
            blurType = analysis.blurType;
          }

          // Sparse Fast-Hash (Tier 2.5) for duplicate verification
          if (item.needsMd5 && md5Hash == null && item.path.isNotEmpty) {
            md5Hash = await _computeFastMd5(item.path);
          }

          final result = ProcessedItem(
            id: item.id,
            path: item.path,
            dHash: dHash,
            md5: md5Hash,
            verifiedMd5: item.verifiedMd5,
            isBlurry: isBlurry,
            blurChecked: item.checkBlur || item.cachedIsBlurry != null,
            clusterId: item.clusterId,
            dHashHigh: dHashHigh,
            dHashLow: dHashLow,
            sharpnessScore: sharpness,
            blurType: blurType,
            aspectRatio: aspectRatio,
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
        _log(
          sendPort,
          "Grouping ${processedItems.length} items by exact and visual matches...",
        );
        final result = await _computeGroups(
          processedItems,
          onProgress: (value, status) {
            sendPort.send({
              'type': ScannerResponse.progress,
              'value': value,
              'status': status,
            });
          },
        );
        sendPort.send({
          'type': ScannerResponse.finalResult,
          'duplicates': result.duplicateGroupIds,
          'similar': result.similarGroupIds,
          'blurry': result.blurryPhotoIds,
          'sharpness': result.sharpnessScores,
          'blurTypes': result.blurTypes,
        });
      } catch (e) {
        sendPort.send({
          'type': ScannerResponse.error,
          'message': 'Grouping Error: $e',
        });
      }
    } else if (message == ScannerCommand.clear) {
      processedItems.clear();
      _log(sendPort, "Isolate memory cleared.");
    } else if (message == ScannerCommand.dispose) {
      receivePort.close();
    }
  }
}

class _ImageAnalysisResult {
  final String? hash;
  final (int, int)? bits;
  final bool isBlurry;
  final double sharpnessScore;
  final String? blurType;

  const _ImageAnalysisResult({
    this.hash,
    this.bits,
    this.isBlurry = false,
    this.sharpnessScore = 85.0,
    this.blurType,
  });
}

class _BlurAnalysisResult {
  final bool isBlurry;
  final double sharpness;
  final String? blurType;

  const _BlurAnalysisResult({
    required this.isBlurry,
    required this.sharpness,
    this.blurType,
  });
}

_ImageAnalysisResult _analyzeImage(
  Uint8List bytes,
  SendPort p, {
  bool checkBlur = false,
}) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return const _ImageAnalysisResult();
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

    // 2. Center-Weighted Laplacian Variance & Sharpness Engine
    bool isBlurry = false;
    double sharpness = 85.0;
    String? blurType;

    if (checkBlur) {
      final blurAnalysis = _checkBlurAndSharpness(image);
      isBlurry = blurAnalysis.isBlurry;
      sharpness = blurAnalysis.sharpness;
      blurType = blurAnalysis.blurType;
    }

    return _ImageAnalysisResult(
      hash: hash,
      bits: (hHigh, hLow),
      isBlurry: isBlurry,
      sharpnessScore: sharpness,
      blurType: blurType,
    );
  } catch (e) {
    _log(p, "Image Analysis Error: $e");
    return const _ImageAnalysisResult();
  }
}

/// Zero-heap-allocation Center-Weighted Laplacian variance and motion blur detector.
/// Eliminates calling img.grayscale() which copies the entire image.
_BlurAnalysisResult _checkBlurAndSharpness(img.Image image) {
  final w = image.width;
  final h = image.height;
  if (w < 4 || h < 4) {
    return const _BlurAnalysisResult(isBlurry: false, sharpness: 100.0);
  }

  final centerX = w / 2.0;
  final centerY = h / 2.0;
  final halfW = w / 2.0;
  final halfH = h / 2.0;

  num minVal = 255;
  num maxVal = 0;
  double sumLap = 0.0;
  double sumSqLap = 0.0;
  double sumWeight = 0.0;

  double sumLapX = 0.0;
  double sumSqLapX = 0.0;
  double sumLapY = 0.0;
  double sumSqLapY = 0.0;
  int count = 0;

  for (int y = 1; y < h - 1; y++) {
    final dy = (y - centerY) / halfH;
    final dySq = dy * dy;

    for (int x = 1; x < w - 1; x++) {
      final center = image.getPixel(x, y).luminance;
      if (center < minVal) minVal = center;
      if (center > maxVal) maxVal = center;

      final top = image.getPixel(x, y - 1).luminance;
      final bottom = image.getPixel(x, y + 1).luminance;
      final left = image.getPixel(x - 1, y).luminance;
      final right = image.getPixel(x + 1, y).luminance;

      // Center-weighting: Subject in center gets 2.5x weight to prevent portrait bokeh from being flagged
      final dx = (x - centerX) / halfW;
      final rSq = dx * dx + dySq;
      final double weight = (rSq <= 0.36) ? 2.5 : ((rSq <= 0.75) ? 1.5 : 1.0);

      final lap = (top + bottom + left + right) - (4.0 * center);
      sumLap += lap * weight;
      sumSqLap += lap * lap * weight;
      sumWeight += weight;

      final lapX = (left + right) - (2.0 * center);
      final lapY = (top + bottom) - (2.0 * center);
      sumLapX += lapX;
      sumSqLapX += lapX * lapX;
      sumLapY += lapY;
      sumSqLapY += lapY * lapY;

      count++;
    }
  }

  if (count == 0 || sumWeight == 0) {
    return const _BlurAnalysisResult(isBlurry: false, sharpness: 100.0);
  }

  // Dynamic Range Guard: uniform or night scenes
  if ((maxVal - minVal) < 35) {
    return const _BlurAnalysisResult(isBlurry: false, sharpness: 100.0);
  }

  final meanLap = sumLap / sumWeight;
  final varianceLap = (sumSqLap / sumWeight) - (meanLap * meanLap);

  final meanX = sumLapX / count;
  final varX = (sumSqLapX / count) - (meanX * meanX);
  final meanY = sumLapY / count;
  final varY = (sumSqLapY / count) - (meanY * meanY);

  String? blurType;
  if (varianceLap < 95.0) {
    if (varX > 3.0 * (varY + 1.0) || varY > 3.0 * (varX + 1.0)) {
      blurType = 'motion';
    } else {
      blurType = 'out_of_focus';
    }
  }

  final rawScore = math.min(100.0, (varianceLap / 3.0));
  final sharpness = double.parse(rawScore.toStringAsFixed(1));
  final isBlurry = varianceLap < 85.0;

  return _BlurAnalysisResult(
    isBlurry: isBlurry,
    sharpness: sharpness,
    blurType: blurType,
  );
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

Future<ScanResult> _computeGroups(
  List<ProcessedItem> items, {
  void Function(double, String)? onProgress,
}) async {
  final List<List<String>> duplicateGroups = [];
  final List<List<String>> similarGroups = [];
  final List<String> blurryPhotoIds = [];
  final Map<String, double> sharpnessScores = {};
  final Map<String, String> blurTypes = {};
  // An asset can arrive in both the hash and image-analysis streams. Combine
  // those results before grouping so one asset cannot form a group with itself.
  final itemMap = <String, ProcessedItem>{};
  for (final item in items) {
    final previous = itemMap[item.id];
    if (previous == null) {
      itemMap[item.id] = item;
      continue;
    }
    final imageResult = item.dHash != null ? item : previous;
    itemMap[item.id] = ProcessedItem(
      id: item.id,
      path: item.path.isNotEmpty ? item.path : previous.path,
      dHash: item.dHash ?? previous.dHash,
      md5: item.md5 ?? previous.md5,
      verifiedMd5: item.verifiedMd5 ?? previous.verifiedMd5,
      isBlurry: item.isBlurry || previous.isBlurry,
      clusterId: item.clusterId ?? previous.clusterId,
      dHashHigh: imageResult.dHashHigh,
      dHashLow: imageResult.dHashLow,
      sharpnessScore: imageResult.sharpnessScore,
      blurType: item.blurType ?? previous.blurType,
      aspectRatio: imageResult.aspectRatio,
    );
  }
  final uniqueItems = itemMap.values.toList();

  // 1. Exact duplicates: initial group by fast/complete hash
  final exactByHash = <String, List<String>>{};
  final groupedIds = <String>{};

  for (final item in uniqueItems) {
    sharpnessScores[item.id] = item.sharpnessScore;
    if (item.blurType != null) {
      blurTypes[item.id] = item.blurType!;
    }
    final exactHash = item.verifiedMd5 ?? item.md5;
    if (exactHash != null && exactHash.isNotEmpty) {
      exactByHash.putIfAbsent(exactHash, () => []).add(item.id);
    }
    if (item.isBlurry) {
      blurryPhotoIds.add(item.id);
    }
  }

  // Verify against current file contents. Cached hashes can be stale after an
  // edit, and sparse hashes can collide.
  final verificationGroups = exactByHash.values
      .where((group) => group.length > 1)
      .toList();
  var verifiedFiles = 0;
  final totalFiles = verificationGroups.fold<int>(
    0,
    (total, group) => total + group.length,
  );
  for (final group in verificationGroups) {
    final verifiedGroups = <String, List<String>>{};
    for (var start = 0; start < group.length; start += 4) {
      final ids = group.sublist(start, math.min(start + 4, group.length));
      final hashes = await Future.wait(
        ids.map((id) async {
          final it = itemMap[id];
          if (it == null) return null;
          if (it.verifiedMd5 != null) return (id, it.verifiedMd5!);
          if (it.path.isEmpty) return null;
          try {
            final digest = await md5.bind(File(it.path).openRead()).first;
            return (id, digest.toString());
          } catch (_) {
            return null;
          }
        }),
      );
      for (final hash in hashes) {
        if (hash != null) {
          verifiedGroups.putIfAbsent(hash.$2, () => []).add(hash.$1);
        }
      }
      verifiedFiles += ids.length;
      onProgress?.call(
        0.75 * verifiedFiles / math.max(1, totalFiles),
        'Verifying exact copies: $verifiedFiles / $totalFiles',
      );
    }
    for (final verifiedGroup in verifiedGroups.values) {
      if (verifiedGroup.length > 1) {
        duplicateGroups.add(verifiedGroup);
        groupedIds.addAll(verifiedGroup);
      }
    }
  }

  // 1.5 Suggest visually similar, recompressed copies for manual review.
  // These are not byte-for-byte duplicates, even at a low dHash distance.
  final candidateReplicas = uniqueItems
      .where((it) => it.dHash?.length == 128 && !groupedIds.contains(it.id))
      .toList();
  final replicaGroupedIds = <String>{};

  // Group candidate replicas by aspect ratio bucket to make comparison fast O(N * bucketSize)
  final aspectBuckets = <int, List<ProcessedItem>>{};
  for (final it in candidateReplicas) {
    final bucketKey = (it.aspectRatio * 20).round();
    aspectBuckets.putIfAbsent(bucketKey, () => []).add(it);
  }

  onProgress?.call(0.76, 'Matching similar photos...');
  for (final bucketItems in aspectBuckets.values) {
    if (bucketItems.length < 2) continue;
    // With at most six differing bits, one of seven disjoint hash segments
    // must match exactly. Index those segments instead of comparing every pair.
    final signatures = <String, List<int>>{};
    List<String> keys(ProcessedItem item) {
      final hash = item.dHash!;
      return [
        for (var segment = 0; segment < 7; segment++)
          '$segment:${hash.substring(128 * segment ~/ 7, 128 * (segment + 1) ~/ 7)}',
      ];
    }

    for (var index = 0; index < bucketItems.length; index++) {
      for (final key in keys(bucketItems[index])) {
        signatures.putIfAbsent(key, () => []).add(index);
      }
    }
    for (int i = 0; i < bucketItems.length; i++) {
      final a = bucketItems[i];
      if (replicaGroupedIds.contains(a.id) || groupedIds.contains(a.id)) {
        continue;
      }
      final candidates = <int>{};
      for (final key in keys(a)) {
        candidates.addAll(signatures[key]!);
      }
      final indexes = candidates.where((index) => index > i).toList()..sort();
      final List<String> currentReplicaGroup = [];
      for (final j in indexes) {
        final b = bucketItems[j];
        if (replicaGroupedIds.contains(b.id) || groupedIds.contains(b.id)) {
          continue;
        }

        if ((a.aspectRatio - b.aspectRatio).abs() > 0.035) continue;

        final dist = _hammingDistanceFast(
          a.dHashHigh,
          a.dHashLow,
          b.dHashHigh,
          b.dHashLow,
        );
        if (dist <= 6) {
          currentReplicaGroup.add(b.id);
          replicaGroupedIds.add(b.id);
        }
      }

      if (currentReplicaGroup.isNotEmpty) {
        replicaGroupedIds.add(a.id);
        groupedIds.add(a.id);
        groupedIds.addAll(currentReplicaGroup);
        currentReplicaGroup.insert(0, a.id);
        similarGroups.add(currentReplicaGroup);
      }
    }
  }

  // 2. Similar / Burst groups: group within temporal clusters using 64-bit bitwise popcount
  // Threshold <= 12 (>= 90.6% visual similarity) with transitive drift guard
  final clusterMap = <String, List<ProcessedItem>>{};
  for (final item in uniqueItems) {
    if (item.dHash != null && !groupedIds.contains(item.id)) {
      final cluster = item.clusterId;
      if (cluster == null) continue;
      clusterMap.putIfAbsent(cluster, () => []).add(item);
    }
  }

  onProgress?.call(0.90, 'Reviewing burst groups...');
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

        // Distance <= 12 corresponds to >= 90.6% visual similarity
        if (distance <= 12) {
          // Transitive drift guard: ensure itemB is reasonably similar (<= 14) to all members in currentSimilar
          bool passesClusterDrift = true;
          for (final existingId in currentSimilar) {
            final existingItem = itemMap[existingId];
            if (existingItem != null) {
              final d = _hammingDistanceFast(
                itemB.dHashHigh,
                itemB.dHashLow,
                existingItem.dHashHigh,
                existingItem.dHashLow,
              );
              if (d > 14) {
                passesClusterDrift = false;
                break;
              }
            }
          }

          if (passesClusterDrift) {
            currentSimilar.add(itemB.id);
            processedInCluster.add(itemB.id);
          }
        }
      }

      if (currentSimilar.isNotEmpty) {
        processedInCluster.add(itemA.id);
        currentSimilar.insert(0, itemA.id);
        similarGroups.add(currentSimilar);
      }
    }
  }

  return ScanResult(
    duplicateGroups,
    similarGroups,
    blurryPhotoIds,
    sharpnessScores: sharpnessScores,
    blurTypes: blurTypes,
  );
}

void _log(SendPort port, String msg) {
  port.send({'type': ScannerResponse.log, 'message': msg});
}
