import 'dart:typed_data';
import 'dart:isolate';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Commands sent to the isolate
enum ScannerCommand {
  processBatch,
  finalize,
  clear,
  dispose
}

/// Commands sent from the isolate
enum ScannerResponse {
  batchProcessed,
  finalResult,
  error,
  log
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

  ProcessedItem({
    required this.id, 
    this.dHash, 
    this.md5,
    this.isBlurry = false,
    this.clusterId,
  });
}

class ScanResult {
  final List<List<String>> duplicateGroupIds;
  final List<List<String>> similarGroupIds;
  final List<String> blurryPhotoIds;

  ScanResult(this.duplicateGroupIds, this.similarGroupIds, this.blurryPhotoIds);
}

/// The entry point for the isolate
void scannerIsolateEntry(SendPort sendPort) {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  final List<ProcessedItem> processedItems = [];

  receivePort.listen((message) async {
    if (message is ScanBatch) {
      try {
        List<ProcessedItem> results = [];
        for (var item in message.items) {
          String? dHash = item.cachedDHash;
          String? md5Hash = item.cachedMd5;
          bool isBlurry = item.cachedIsBlurry ?? false;
          
          // Compute dHash & check sharpness if needed
          if (item.needsDHash && item.thumbBytes != null) {
             final analysis = _analyzeImage(item.thumbBytes!, sendPort, checkBlur: item.checkBlur);
             dHash ??= analysis.$1;
             isBlurry = analysis.$2;
          } else if (item.checkBlur && item.thumbBytes != null) {
             final analysis = _analyzeImage(item.thumbBytes!, sendPort, checkBlur: true);
             isBlurry = analysis.$2;
          }

          if (item.needsMd5 && md5Hash == null && item.path.isNotEmpty) {
             md5Hash = await _computeMd5(item.path);
          }
          
          final result = ProcessedItem(
            id: item.id, 
            dHash: dHash, 
            md5: md5Hash, 
            isBlurry: isBlurry,
            clusterId: item.clusterId,
          );
          results.add(result);
          processedItems.add(result);
        }
        sendPort.send({
           'type': ScannerResponse.batchProcessed, 
           'count': results.length,
           'results': results
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

(String?, bool) _analyzeImage(Uint8List bytes, SendPort p, {bool checkBlur = false}) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) {
       return (null, false);
    }

    // 1. dHash (9x8 downscaled)
    final resized = img.copyResize(image, width: 9, height: 8);
    String hash = '';

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final left = resized.getPixel(x, y).luminance;
        final right = resized.getPixel(x + 1, y).luminance;
        hash += (left > right) ? '1' : '0';
      }
    }

    // 2. Laplacian Variance for Blurry / Out-of-Focus Detection
    bool isBlurry = false;
    if (checkBlur) {
      isBlurry = _checkIsBlurry(image);
    }

    return (hash, isBlurry);
  } catch (e) {
    _log(p, "Image Analysis Error: $e");
    return (null, false);
  }
}

bool _checkIsBlurry(img.Image image) {
  final w = image.width;
  final h = image.height;
  if (w < 4 || h < 4) return false;

  final gray = (image.numChannels == 1) ? image : img.grayscale(image);

  double sum = 0.0;
  double sumSq = 0.0;
  int count = 0;

  for (int y = 1; y < h - 1; y++) {
    for (int x = 1; x < w - 1; x++) {
      final center = gray.getPixel(x, y).getChannel(img.Channel.red);
      final top = gray.getPixel(x, y - 1).getChannel(img.Channel.red);
      final bottom = gray.getPixel(x, y + 1).getChannel(img.Channel.red);
      final left = gray.getPixel(x - 1, y).getChannel(img.Channel.red);
      final right = gray.getPixel(x + 1, y).getChannel(img.Channel.red);

      final lap = (top + bottom + left + right) - (4.0 * center);
      sum += lap;
      sumSq += lap * lap;
      count++;
    }
  }

  if (count == 0) return false;
  final mean = sum / count;
  final variance = (sumSq / count) - (mean * mean);
  return variance < 80.0; // Sharpness threshold for low variance / blurry shots
}

Future<String?> _computeMd5(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final digest = await md5.bind(file.openRead()).first;
    return digest.toString();
  } catch (_) {
    return null;
  }
}

ScanResult _computeGroups(List<ProcessedItem> items) {
  List<List<String>> duplicateGroups = [];
  List<List<String>> similarGroups = [];
  List<String> blurryPhotoIds = [];

  // Exact duplicates: complete file MD5
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

  // Similar groups: group within temporal clusters
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

      List<String> currentSimilar = [];
      for (int j = i + 1; j < clusterItems.length; j++) {
        final itemB = clusterItems[j];
        if (processedInCluster.contains(itemB.id)) continue;

        int distance = _hammingDistance(itemA.dHash!, itemB.dHash!);
        if (distance <= 8) {
          currentSimilar.add(itemB.id);
          processedInCluster.add(itemB.id);
        }
      }

      if (currentSimilar.isNotEmpty) {
        currentSimilar.insert(0, itemA.id);
        similarGroups.add(currentSimilar);
      }
    }
  }
  
  return ScanResult(duplicateGroups, similarGroups, blurryPhotoIds);
}

int _hammingDistance(String hash1, String hash2) {
  if (hash1.length != hash2.length) return 100;
  int dist = 0;
  for (int i = 0; i < hash1.length; i++) {
    if (hash1.codeUnitAt(i) != hash2.codeUnitAt(i)) {
      dist++;
    }
  }
  return dist;
}

void _log(SendPort port, String msg) {
  port.send({'type': ScannerResponse.log, 'message': msg});
}
