import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/media_service.dart';
import '../../data/services/categorization_service.dart';
import '../../core/utils/app_utils.dart';
import '../../core/services/scanner_isolate.dart';

// Standalone functions for compute
Future<Map<String, dynamic>> _loadCacheCompute(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    }
  } catch (e) {
    debugPrint('[CACHE COMPUTE ERROR] $e');
  }
  return {};
}

Future<void> _saveCacheCompute(Map<String, dynamic> data) async {
  try {
    final path = data['path'] as String;
    final cache = data['cache'] as Map;
    final file = File(path);
    final jsonStr = jsonEncode(cache);
    await file.writeAsString(jsonStr);
  } catch (e) {
    debugPrint('[CACHE COMPUTE SAVE ERROR] $e');
  }
}

class ScanProvider extends ChangeNotifier {
  ScanProvider() {
    _initFuture = _initialize();
  }

  Future<void>? _initFuture;
  final MediaService _mediaService = MediaService();
  final CategorizationService _categorizationService = CategorizationService();

  ScanScope _scanScope = ScanScope.fullGallery;
  ScanScope get scanScope => _scanScope;

  Future<void> _initialize() async {
    await Future.wait([_loadCache(), _loadScanScope()]);
  }

  Future<void> _loadScanScope() async {
    final prefs = await SharedPreferences.getInstance();
    final storedScope = prefs.getString('scan_scope');
    if (storedScope == null) return;
    _scanScope = ScanScope.values.firstWhere(
      (scope) => scope.name == storedScope,
      orElse: () => ScanScope.fullGallery,
    );
  }

  Future<void> setScanScope(ScanScope scope) async {
    if (_scanScope == scope) return;
    _scanScope = scope;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('scan_scope', scope.name);
    notifyListeners();
    await scan(force: true);
  }

  int _scanSessionId = 0;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isCategorizing => false;

  String _debugLogs = '';
  String get debugLogs => _debugLogs;

  String _scanStatusMessage = '';
  String get scanStatusMessage => _scanStatusMessage;

  List<AssetEntity> _allScreenshots = [];
  List<AssetEntity> get allScreenshots => _allScreenshots;

  Map<String, String> _assetAlbumMap = {};
  Map<String, String> get assetAlbumMap => _assetAlbumMap;

  // Duplicates: Lists of assets that are duplicates (grouped)
  List<List<AssetEntity>> _duplicateGroups = [];
  List<List<AssetEntity>> get duplicateGroups => _duplicateGroups;

  // Similar: Lists of assets that are similar (grouped)
  List<List<AssetEntity>> _similarGroups = [];
  List<List<AssetEntity>> get similarGroups => _similarGroups;

  // Modern Clean Categories
  Map<String, List<AssetEntity>> _categories = {
    'Screenshots': [],
    'Screen Recordings': [],
    'Social & WhatsApp': [],
    'Bills & Finance': [],
    'Documents & IDs': [],
    'Food & Dining': [],
    'Memes & Downloads': [],
    'Personal & Portraits': [],
    'Others': [],
  };
  Map<String, List<AssetEntity>> get categories => _categories;

  final Map<String, int> _categorySizes = {};

  int getCategorySize(String category) => _categorySizes[category] ?? 0;

  String getFormattedCategorySize(String category) {
    final size = getCategorySize(category);
    if (size <= 0) return '';
    return AppUtils.formatBytes(size);
  }

  void _recalculateCategorySizes() {
    _categorySizes.clear();
    for (final entry in _categories.entries) {
      int total = 0;
      for (final a in entry.value) {
        total += _assetSizes[a.id] ?? 0;
      }
      _categorySizes[entry.key] = total;
    }
  }

  int _totalSize = 0;
  int get totalSize => _totalSize;

  int _duplicateSize = 0;
  int get duplicateSize => _duplicateSize;

  int _similarSize = 0;
  int get similarSize => _similarSize;

  // Cache for file sizes
  final Map<String, int> _assetSizes = {};
  Map<String, int> get assetSizes => _assetSizes;

  // Blurry Photos
  List<AssetEntity> _blurryPhotos = [];
  List<AssetEntity> get blurryPhotos => _blurryPhotos;
  int _blurrySize = 0;
  int get blurrySize => _blurrySize;
  String get formattedBlurrySize => AppUtils.formatBytes(_blurrySize);

  // Large Videos
  List<AssetEntity> _largeVideos = [];
  List<AssetEntity> get largeVideos => _largeVideos;
  int _largeVideosSize = 0;
  int get largeVideosSize => _largeVideosSize;
  String get formattedLargeVideosSize => AppUtils.formatBytes(_largeVideosSize);

  // Persistent Cache: key = asset.id, value = {category, md5, dHash, size, is_blurry}
  Map<String, Map<String, dynamic>> _scanCache = {};

  // Progress: Live continuous animated ticker
  double _progress = 0.0;
  double get progress => _progress;
  double _targetProgress = 0.0;
  Timer? _progressTicker;

  // UX: Live Scanning Feedback
  List<AssetEntity> _recentScanned = [];
  List<AssetEntity> get recentScanned => _recentScanned;

  bool _isFirstScan = false;
  bool get isFirstScan => _isFirstScan;

  final Stopwatch _scanTimer = Stopwatch();
  String get formattedScanDuration {
    if (_progress <= 0 || _progress >= 1.0) return '00:00 left';

    final elapsedMilliseconds = _scanTimer.elapsedMilliseconds;
    if (elapsedMilliseconds == 0) return '00:00 left';

    if (_progress < 0.05) return 'Calculating...';

    final remainingMillis = (elapsedMilliseconds / _progress) - elapsedMilliseconds;
    if (remainingMillis < 0) return '00:00 left';

    final duration = Duration(milliseconds: remainingMillis.toInt());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds left';
  }

  int get totalDuplicateCount => _duplicateGroups.fold(0, (sum, group) => sum + group.length);
  int get totalSimilarCount => _similarGroups.fold(0, (sum, group) => sum + group.length);

  Future<void> _loadCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/scan_cache.json';

      final rawCache = await compute(_loadCacheCompute, path);
      _scanCache = rawCache.map((key, value) {
        return MapEntry(key, Map<String, dynamic>.from(value as Map));
      });

      for (var entry in _scanCache.entries) {
        if (entry.value.containsKey('size')) {
          _assetSizes[entry.key] = entry.value['size'] as int;
        }
      }
      _recalculateCategorySizes();
    } catch (e) {
      debugPrint('[CACHE ERROR] Error loading cache: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      _assetSizes.forEach((id, size) {
        if (_scanCache.containsKey(id)) {
          _scanCache[id]!['size'] = size;
        }
      });

      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/scan_cache.json';

      await compute(_saveCacheCompute, {
        'path': path,
        'cache': Map<String, Map<String, dynamic>>.from(_scanCache)
      });
    } catch (e) {
      debugPrint('[CACHE ERROR] Error saving cache: $e');
    }
  }

  // --- ISOLATE LOGIC ---
  Isolate? _scannerIsolate;
  SendPort? _isolateSendPort;
  Completer<void>? _isolateReadyCompleter;

  Future<void> _spawnIsolate() async {
    if (_scannerIsolate != null) return;

    final receivePort = ReceivePort();
    _isolateReadyCompleter = Completer<void>();

    _scannerIsolate = await Isolate.spawn(scannerIsolateEntry, receivePort.sendPort);

    receivePort.listen((message) {
      if (message is SendPort) {
        _isolateSendPort = message;
        _isolateReadyCompleter?.complete();
      } else if (message is Map) {
        _handleIsolateMessage(message);
      }
    });

    await _isolateReadyCompleter?.future;
  }

  void _handleIsolateMessage(Map message) {
    final type = message['type'] as ScannerResponse;
    switch (type) {
      case ScannerResponse.batchProcessed:
        final results = message['results'] as List<ProcessedItem>;
        _handleBatchResults(results);
        break;
      case ScannerResponse.finalResult:
        final duplicates = (message['duplicates'] as List).cast<List<String>>();
        final similar = (message['similar'] as List).cast<List<String>>();
        final blurry = ((message['blurry'] as List?) ?? []).cast<String>();
        _handleFinalResults(duplicates, similar, blurry);
        break;
      case ScannerResponse.log:
        _debugLogs += '\n[Isolate] ${message['message']}';
        notifyListeners();
        break;
      case ScannerResponse.error:
        _debugLogs += '\n[Isolate Error] ${message['message']}';
        notifyListeners();
        break;
    }
  }

  int _batchesSent = 0;
  int _batchesProcessed = 0;
  Completer<void>? _allBatchesProcessedCompleter;

  void _handleBatchResults(List<ProcessedItem> results) {
    for (var item in results) {
      if (!_scanCache.containsKey(item.id)) {
        _scanCache[item.id] = {};
      }

      if (item.dHash != null) {
        _scanCache[item.id]!['dHash'] = item.dHash;
      }
      if (item.md5 != null) {
        _scanCache[item.id]!['md5'] = item.md5;
      }
      _scanCache[item.id]!['is_blurry'] = item.isBlurry;
    }

    _batchesProcessed++;
    if (_batchesSent > 0 && _batchesProcessed >= _batchesSent) {
      if (_allBatchesProcessedCompleter != null && !_allBatchesProcessedCompleter!.isCompleted) {
        _allBatchesProcessedCompleter!.complete();
      }
    }
  }

  Completer<void>? _finalResultsCompleter;

  void _handleFinalResults(List<List<String>> duplicates, List<List<String>> similar, List<String> blurry) {
    _duplicateGroups = [];
    _similarGroups = [];
    _blurryPhotos = [];
    _blurrySize = 0;

    Map<String, AssetEntity> assetMap = {for (var a in _allScreenshots) a.id: a};

    for (var group in duplicates) {
      List<AssetEntity> assets = group.map((id) => assetMap[id]).whereType<AssetEntity>().toList();
      if (assets.length > 1) {
        assets.sort(_compareAssetsForKeeping);
        _duplicateGroups.add(assets);
      }
    }

    for (var group in similar) {
      List<AssetEntity> assets = group.map((id) => assetMap[id]).whereType<AssetEntity>().toList();
      if (assets.length > 1) {
        assets.sort(_compareAssetsForKeeping);
        _similarGroups.add(assets);
      }
    }

    for (var id in blurry) {
      final asset = assetMap[id];
      if (asset != null && !_blurryPhotos.any((a) => a.id == id)) {
        _blurryPhotos.add(asset);
        _blurrySize += _assetSizes[id] ?? 0;
      }
    }

    _calculateSmartCleanData();
    _recalculateCategorySizes();
    _finalResultsCompleter?.complete();
  }

  Future<void> scanLargeVideos() async {
    try {
      final videos = await _mediaService.fetchVideos(limit: 100);
      _largeVideos = [];
      _largeVideosSize = 0;

      for (int i = 0; i < videos.length; i += 15) {
        final chunk = videos.sublist(i, (i + 15 < videos.length) ? i + 15 : videos.length);
        final results = await Future.wait(chunk.map((v) async {
          if (_assetSizes.containsKey(v.id)) {
            return (v, _assetSizes[v.id]!);
          }
          try {
            final file = await v.file;
            if (file != null) {
              final len = await file.length();
              return (v, len);
            }
          } catch (_) {}
          return (v, 0);
        }));

        for (final r in results) {
          final v = r.$1;
          final len = r.$2;
          if (len > 0) {
            _assetSizes[v.id] = len;
            _largeVideos.add(v);
            _largeVideosSize += len;
          }
        }
      }
      _largeVideos.sort((a, b) => (_assetSizes[b.id] ?? 0).compareTo(_assetSizes[a.id] ?? 0));
      _recalculateCategorySizes();
      notifyListeners();
    } catch (e) {
      debugPrint('Error scanning videos: $e');
    }
  }

  void _killIsolate() {
    _isolateSendPort?.send(ScannerCommand.dispose);
    _scannerIsolate?.kill();
    _scannerIsolate = null;
    _isolateSendPort = null;
  }

  @override
  void dispose() {
    _progressTicker?.cancel();
    _killIsolate();
    super.dispose();
  }

  // Smooth continuous progress ticker (advances 1%..2% continuously)
  void _startProgressTicker() {
    _progressTicker?.cancel();
    _progress = 0.01;
    _targetProgress = 0.08;
    _scanStatusMessage = 'Scanning media albums...';

    _progressTicker = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isLoading) {
        timer.cancel();
        return;
      }

      if (_progress < _targetProgress) {
        final diff = _targetProgress - _progress;
        final step = diff > 0.15 ? 0.02 : 0.01;
        _progress = (_progress + step).clamp(0.0, _targetProgress);
        notifyListeners();
      } else if (_progress < 0.99) {
        // Continuous steady tick while processing so user never sees freeze
        _progress = (_progress + 0.0012).clamp(0.0, 0.99);
        notifyListeners();
      }
    });
  }

  void _setTargetProgress(double target, {String? status}) {
    _targetProgress = target.clamp(0.0, 1.0);
    if (status != null && status.isNotEmpty) {
      _scanStatusMessage = status;
    }
    notifyListeners();
  }

  void _finishProgress() {
    _progressTicker?.cancel();
    _targetProgress = 1.0;
    _progress = 1.0;
    _scanStatusMessage = 'Scan completed';
    notifyListeners();
  }

  Future<void> scan({bool force = false}) async {
    if (_isLoading) return;
    if (_initFuture != null) await _initFuture;

    _isLoading = true;
    _scanSessionId++;
    final int mySessionId = _scanSessionId;

    _isFirstScan = _scanCache.isEmpty;
    _scanTimer.reset();
    _scanTimer.start();

    _recentScanned = [];
    _debugLogs = 'Starting Fast Scan...';
    _startProgressTicker();
    notifyListeners();

    // Parallel background video scan
    scanLargeVideos();

    try {
      // 1. Fetch Assets and Authoritative Folder / Album Mappings
      _setTargetProgress(0.15, status: 'Scanning media albums...');
      final scanResult = await _mediaService.fetchAllAssets(scope: _scanScope);
      if (_scanSessionId != mySessionId) return;

      final uniqueAssets = {for (var a in scanResult.screenshots) a.id: a};
      _allScreenshots = uniqueAssets.values.toList();
      _assetAlbumMap = scanResult.assetAlbumMap;
      _debugLogs += '\nFound ${_allScreenshots.length} assets across ${_assetAlbumMap.length} folder tags.';

      // Reset Collections
      _duplicateGroups = [];
      _similarGroups = [];
      _blurryPhotos = [];
      _blurrySize = 0;
      _totalSize = 0;
      _duplicateSize = 0;
      _similarSize = 0;

      _categories = {
        'Screenshots': [],
        'Screen Recordings': [],
        'Social & WhatsApp': [],
        'Bills & Finance': [],
        'Documents & IDs': [],
        'Food & Dining': [],
        'Memes & Downloads': [],
        'Personal & Portraits': [],
        'Others': [],
      };
      _assetCategoryMap.clear();

      _setTargetProgress(0.28, status: 'Organizing smart categories...');

      // 2. Authoritative Categorization Pass using Album Names + Path + Title + ML Refinement
      final List<AssetEntity> assetsNeedingML = [];

      for (final asset in _allScreenshots) {
        final cachedCat = _scanCache[asset.id]?['category'] as String?;
        if (cachedCat != null && cachedCat.isNotEmpty && _categories.containsKey(cachedCat)) {
          _addAssetToCategory(cachedCat, asset);
        } else {
          final albumName = _assetAlbumMap[asset.id];
          final quickCat = _categorizationService.quickCategorize(asset, albumName: albumName);
          if (quickCat != null) {
            _addAssetToCategory(quickCat, asset);
            if (!_scanCache.containsKey(asset.id)) _scanCache[asset.id] = {};
            _scanCache[asset.id]!['category'] = quickCat;
          } else {
            _addAssetToCategory('Others', asset);
            assetsNeedingML.add(asset);
          }
        }

        if (_scanCache[asset.id]?['is_blurry'] == true) {
          _blurryPhotos.add(asset);
          _blurrySize += _assetSizes[asset.id] ?? 0;
        }

        if (_assetSizes.containsKey(asset.id)) {
          _totalSize += _assetSizes[asset.id]!;
        }
      }

      _recalculateCategorySizes();

      // Trigger asynchronous ML visual refinement in background
      if (assetsNeedingML.isNotEmpty) {
        _refineCategoriesWithML(assetsNeedingML, mySessionId);
      }
      _setTargetProgress(0.38, status: 'Identifying candidate duplicates...');

      // 3. Spawn Background Isolate
      await _spawnIsolate();
      if (_scanSessionId != mySessionId) return;
      _isolateSendPort!.send(ScannerCommand.clear);

      // 4. CANDIDATE IDENTIFICATION WITHOUT FILE I/O
      // A) Duplicate Candidates: exact same pixel dimensions
      final Map<String, List<AssetEntity>> dimensionGroups = {};
      for (final asset in _allScreenshots) {
        if (asset.type == AssetType.image && asset.width > 0 && asset.height > 0) {
          final dimKey = '${asset.width}x${asset.height}';
          dimensionGroups.putIfAbsent(dimKey, () => []).add(asset);
        }
      }

      final List<AssetEntity> duplicateCandidates = [];
      for (final group in dimensionGroups.values) {
        if (group.length > 1) {
          duplicateCandidates.addAll(group);
        }
      }

      // B) Similar / Burst photo candidates: consecutive camera shots within 45 seconds
      final List<AssetEntity> temporalAssets = _allScreenshots
          .where((a) => a.type == AssetType.image)
          .toList();

      temporalAssets.sort((a, b) {
        final dateA = a.createDateSecond ?? (a.createDateTime.millisecondsSinceEpoch ~/ 1000);
        final dateB = b.createDateSecond ?? (b.createDateTime.millisecondsSinceEpoch ~/ 1000);
        return dateA.compareTo(dateB);
      });

      final Map<String, List<AssetEntity>> burstClusters = {};
      int clusterIndex = 0;
      for (int i = 0; i < temporalAssets.length - 1; i++) {
        final a = temporalAssets[i];
        final b = temporalAssets[i + 1];

        final dateA = a.createDateSecond ?? (a.createDateTime.millisecondsSinceEpoch ~/ 1000);
        final dateB = b.createDateSecond ?? (b.createDateTime.millisecondsSinceEpoch ~/ 1000);
        final diffSec = (dateB - dateA).abs();

        if (diffSec <= 45 && a.width > 0 && a.height > 0 && b.width > 0 && b.height > 0) {
          final ratioA = a.width / a.height;
          final ratioB = b.width / b.height;
          if ((ratioA - ratioB).abs() < 0.08) {
            final currentClusterKey = 'cluster_$clusterIndex';
            burstClusters.putIfAbsent(currentClusterKey, () => []).add(a);
            if (!burstClusters[currentClusterKey]!.contains(b)) {
              burstClusters[currentClusterKey]!.add(b);
            }
          } else {
            clusterIndex++;
          }
        } else {
          clusterIndex++;
        }
      }

      // C) Blurry Candidates: camera shots
      final List<AssetEntity> cameraPhotos = (_allScreenshots.where((a) {
        if (a.type != AssetType.image) return false;
        final path = '${a.title ?? ''} ${a.relativePath ?? ''} ${_assetAlbumMap[a.id] ?? ''}'.toLowerCase();
        return path.contains('dcim') || path.contains('camera') || path.contains('img_');
      }).take(60).toList());

      // 5. TARGETED BATCH RESOLUTION
      _setTargetProgress(0.48, status: 'Analyzing duplicate file sizes...');

      // Step A: Stat file sizes for duplicate candidates in parallel chunks of 20
      for (int i = 0; i < duplicateCandidates.length; i += 20) {
        if (_scanSessionId != mySessionId) return;
        final chunk = duplicateCandidates.sublist(
          i,
          (i + 20 < duplicateCandidates.length) ? i + 20 : duplicateCandidates.length,
        );

        final results = await Future.wait(chunk.map((asset) async {
          if (_assetSizes.containsKey(asset.id)) {
            return (asset, _assetSizes[asset.id]!, '');
          }
          try {
            final file = await asset.file;
            if (file != null) {
              final len = await file.length();
              return (asset, len, file.path);
            }
          } catch (_) {}
          return (asset, 0, '');
        }));

        for (final r in results) {
          final asset = r.$1;
          final size = r.$2;
          if (size > 0) {
            _assetSizes[asset.id] = size;
            _totalSize += size;
            if (!_scanCache.containsKey(asset.id)) _scanCache[asset.id] = {};
            _scanCache[asset.id]!['size'] = size;
          }
        }

        final ratio = (i + chunk.length) / max(1, duplicateCandidates.length);
        _setTargetProgress(0.48 + 0.12 * ratio, status: 'Analyzing duplicate file sizes...');
      }

      // Group candidate duplicates by (dimension, size)
      final Map<String, List<AssetEntity>> exactCandidateGroups = {};
      for (final asset in duplicateCandidates) {
        final size = _assetSizes[asset.id] ?? 0;
        if (size > 0) {
          final groupKey = '${asset.width}x${asset.height}_$size';
          exactCandidateGroups.putIfAbsent(groupKey, () => []).add(asset);
        }
      }

      // Collect all scan items for Isolate processing in one clean, structured batch
      List<ScanItem> allScanItems = [];

      // A) MD5 items
      for (final group in exactCandidateGroups.values) {
        if (group.length > 1) {
          for (final asset in group) {
            final cachedMd5 = _scanCache[asset.id]?['md5'] as String?;
            String path = '';
            if (cachedMd5 == null) {
              try {
                final file = await asset.file;
                if (file != null) path = file.path;
              } catch (_) {}
            }
            allScanItems.add(ScanItem(
              id: asset.id,
              path: path,
              cachedMd5: cachedMd5,
              needsMd5: cachedMd5 == null,
              needsDHash: false,
              checkBlur: false,
            ));
          }
        }
      }

      // B) Burst items (Similar Photos)
      _setTargetProgress(0.62, status: 'Reviewing burst sequences...');
      final List<({AssetEntity asset, String clusterId})> burstTasks = [];
      final Set<String> processedSimilarIds = {};
      for (final entry in burstClusters.entries) {
        for (final asset in entry.value) {
          if (!processedSimilarIds.contains(asset.id)) {
            processedSimilarIds.add(asset.id);
            burstTasks.add((asset: asset, clusterId: entry.key));
          }
        }
      }

      for (int i = 0; i < burstTasks.length; i += 16) {
        if (_scanSessionId != mySessionId) return;
        final chunk = burstTasks.sublist(i, min(i + 16, burstTasks.length));

        final chunkResults = await Future.wait(chunk.map((item) async {
          final cachedDHash = _scanCache[item.asset.id]?['dHash'] as String?;
          Uint8List? thumb;
          if (cachedDHash == null) {
            try {
              thumb = await item.asset.thumbnailDataWithSize(const ThumbnailSize.square(64));
            } catch (_) {}
          }
          return ScanItem(
            id: item.asset.id,
            path: '',
            thumbBytes: thumb,
            cachedDHash: cachedDHash,
            needsDHash: cachedDHash == null,
            needsMd5: false,
            checkBlur: false,
            clusterId: item.clusterId,
          );
        }));

        allScanItems.addAll(chunkResults);
        final ratio = (i + chunk.length) / max(1, burstTasks.length);
        _setTargetProgress(0.62 + 0.18 * ratio, status: 'Reviewing burst sequences...');
      }

      // C) Blurry Photo Checks on Camera Photos
      _setTargetProgress(0.82, status: 'Checking photo sharpness...');
      final List<AssetEntity> blurCandidates = cameraPhotos
          .where((a) => _scanCache[a.id]?['is_blurry'] == null)
          .toList();

      for (int i = 0; i < blurCandidates.length; i += 12) {
        if (_scanSessionId != mySessionId) return;
        final chunk = blurCandidates.sublist(i, min(i + 12, blurCandidates.length));

        final chunkResults = await Future.wait(chunk.map((asset) async {
          Uint8List? thumb;
          try {
            thumb = await asset.thumbnailDataWithSize(const ThumbnailSize.square(96));
          } catch (_) {}

          if (thumb == null) return null;
          return ScanItem(
            id: asset.id,
            path: '',
            thumbBytes: thumb,
            needsDHash: false,
            needsMd5: false,
            checkBlur: true,
          );
        }));

        allScanItems.addAll(chunkResults.whereType<ScanItem>());
        final ratio = (i + chunk.length) / max(1, blurCandidates.length);
        _setTargetProgress(0.82 + 0.10 * ratio, status: 'Checking photo sharpness...');
      }

      // 6. Send Items to Isolate and Await Completion
      _setTargetProgress(0.93, status: 'Finalizing grouping...');
      if (allScanItems.isNotEmpty) {
        _batchesSent = 1;
        _batchesProcessed = 0;
        _allBatchesProcessedCompleter = Completer<void>();
        _isolateSendPort!.send(ScanBatch(allScanItems));
        await _allBatchesProcessedCompleter!.future;
      }

      // Finalize Result in Isolate
      _finalResultsCompleter = Completer<void>();
      _isolateSendPort!.send(ScannerCommand.finalize);
      await _finalResultsCompleter!.future;

      _recalculateCategorySizes();

      // Finish progress smoothly to 100%
      _finishProgress();

      // Save cache in background without freezing UI
      unawaited(_saveCache());
    } catch (e) {
      debugPrint('Scan Error: $e');
      _debugLogs += '\nCritical Error: $e';
    } finally {
      _isLoading = false;
      _finishProgress();
    }
  }

  String get formattedTotalSize => AppUtils.formatBytes(_totalSize);
  String get formattedDuplicateSize => AppUtils.formatBytes(_duplicateSize);
  String get formattedSimilarSize => AppUtils.formatBytes(_similarSize);

  int _compareAssetsForKeeping(AssetEntity a, AssetEntity b) {
    final resolutionA = a.width * a.height;
    final resolutionB = b.width * b.height;
    final resolutionComparison = resolutionB.compareTo(resolutionA);
    if (resolutionComparison != 0) return resolutionComparison;

    final sizeComparison = (_assetSizes[b.id] ?? 0).compareTo(_assetSizes[a.id] ?? 0);
    if (sizeComparison != 0) return sizeComparison;

    final dateA = a.createDateTime;
    final dateB = b.createDateTime;
    return dateB.compareTo(dateA);
  }

  // --- Smart Clean Logic ---
  int _smartCleanSize = 0;
  List<String> _smartCleanIds = [];
  List<AssetEntity> _smartCleanPreviews = [];
  List<AssetEntity> _smartCleanCandidates = [];

  int get smartCleanSize => _smartCleanSize;
  String get formattedSmartCleanSize => AppUtils.formatBytes(_smartCleanSize);
  List<AssetEntity> get smartCleanPreviews => _smartCleanPreviews;
  List<AssetEntity> get smartCleanCandidates => _smartCleanCandidates;

  void _calculateSmartCleanData() {
    _smartCleanSize = 0;
    _smartCleanIds = [];
    _smartCleanPreviews = [];
    _smartCleanCandidates = [];
    _duplicateSize = 0;
    _similarSize = 0;

    for (var group in _duplicateGroups) {
      if (group.length < 2) continue;
      final sorted = List<AssetEntity>.from(group);
      for (int i = 1; i < sorted.length; i++) {
        final a = sorted[i];
        _smartCleanIds.add(a.id);
        _smartCleanCandidates.add(a);
        final size = _assetSizes[a.id] ?? 0;
        _smartCleanSize += size;
        _duplicateSize += size;
        if (_smartCleanPreviews.length < 4) {
          _smartCleanPreviews.add(a);
        }
      }
    }

    for (final group in _similarGroups) {
      for (final a in group) {
        _similarSize += _assetSizes[a.id] ?? 0;
      }
    }
  }

  Future<int> smartClean({List<String>? specificIds}) async {
    final idsToDelete = specificIds ?? _smartCleanIds;
    if (idsToDelete.isEmpty) return 0;

    try {
      final List<String> result = await PhotoManager.editor.deleteWithIds(idsToDelete);
      if (result.isNotEmpty) {
        await removeAssets(result);
        return result.length;
      }
    } catch (e) {
      debugPrint('[SmartClean] Critical Deletion Error: $e');
    }
    return 0;
  }

  Future<void> removeAssets(List<String> ids) async {
    final Set<String> idsToRemove = ids.toSet();

    _allScreenshots.removeWhere((a) => idsToRemove.contains(a.id));

    for (var id in idsToRemove) {
      if (_scanCache.containsKey(id)) _scanCache.remove(id);
      if (_assetSizes.containsKey(id)) {
        _totalSize -= _assetSizes[id]!;
        _assetSizes.remove(id);
      }
    }

    _categories.forEach((key, list) {
      list.removeWhere((a) => idsToRemove.contains(a.id));
    });

    for (var group in _duplicateGroups) {
      group.removeWhere((a) => idsToRemove.contains(a.id));
    }
    _duplicateGroups.removeWhere((group) => group.length < 2);

    for (var group in _similarGroups) {
      group.removeWhere((a) => idsToRemove.contains(a.id));
    }
    _similarGroups.removeWhere((group) => group.length < 2);

    _duplicateSize = 0;
    for (var group in _duplicateGroups) {
      for (var asset in group) {
        _duplicateSize += _assetSizes[asset.id] ?? 0;
      }
    }

    _similarSize = 0;
    for (var group in _similarGroups) {
      for (var asset in group) {
        _similarSize += _assetSizes[asset.id] ?? 0;
      }
    }

    _blurryPhotos.removeWhere((a) => idsToRemove.contains(a.id));
    _blurrySize = 0;
    for (var a in _blurryPhotos) {
      _blurrySize += _assetSizes[a.id] ?? 0;
    }

    _largeVideos.removeWhere((a) => idsToRemove.contains(a.id));
    _largeVideosSize = 0;
    for (var v in _largeVideos) {
      _largeVideosSize += _assetSizes[v.id] ?? 0;
    }

    _calculateSmartCleanData();
    _recalculateCategorySizes();
    notifyListeners();
    unawaited(_saveCache());
  }

  Future<void> forceRescan() async {
    _categories = {
      'Screenshots': [],
      'Screen Recordings': [],
      'Social & WhatsApp': [],
      'Bills & Finance': [],
      'Documents & IDs': [],
      'Food & Dining': [],
      'Memes & Downloads': [],
      'Personal & Portraits': [],
      'Others': [],
    };
    _assetCategoryMap.clear();
    _assetAlbumMap.clear();

    for (var key in _scanCache.keys) {
      _scanCache[key]!.remove('category');
      _scanCache[key]!.remove('is_blurry');
    }

    notifyListeners();

    if (_isolateSendPort != null) {
      _isolateSendPort!.send(ScannerCommand.clear);
    }

    scan(force: true);
  }

  final Map<String, String> _assetCategoryMap = {};

  Future<void> _refineCategoriesWithML(List<AssetEntity> items, int sessionId) async {
    if (items.isEmpty) return;

    const int batchSize = 10;
    for (int i = 0; i < items.length; i += batchSize) {
      if (_scanSessionId != sessionId) return;

      final end = min(i + batchSize, items.length);
      final batch = items.sublist(i, end);

      bool changed = false;
      await Future.wait(batch.map((asset) async {
        final albumName = _assetAlbumMap[asset.id];
        final detectedCat = await _categorizationService.categorizeWithML(asset, albumName: albumName);

        if (_scanSessionId != sessionId) return;

        if (detectedCat != 'Others') {
          _addAssetToCategory(detectedCat, asset);
          changed = true;
        }

        if (!_scanCache.containsKey(asset.id)) _scanCache[asset.id] = {};
        _scanCache[asset.id]!['category'] = detectedCat;
      }));

      if (_scanSessionId != sessionId) return;

      if (changed) {
        _recalculateCategorySizes();
        notifyListeners();
      }
    }

    unawaited(_saveCache());
  }

  void _addAssetToCategory(String category, AssetEntity asset) {
    final oldCat = _assetCategoryMap[asset.id];
    if (oldCat == category) return;

    if (oldCat != null && _categories.containsKey(oldCat)) {
      _categories[oldCat]!.removeWhere((a) => a.id == asset.id);
    }

    if (!_categories.containsKey(category)) {
      _categories[category] = [];
    }

    if (!_categories[category]!.any((a) => a.id == asset.id)) {
      _categories[category]!.add(asset);
    }

    _assetCategoryMap[asset.id] = category;
  }

  String getFormattedAssetSize(String id) {
    if (_assetSizes.containsKey(id)) {
      return AppUtils.formatBytes(_assetSizes[id]!);
    }
    return '';
  }
}
