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
import '../../core/services/widget_service.dart';
import '../../core/services/analytics_service.dart';

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
    final fileTmp = File('$path.tmp');
    final jsonStr = jsonEncode(cache);
    await fileTmp.writeAsString(jsonStr, flush: true);
    if (await fileTmp.exists()) {
      await fileTmp.rename(path);
    }
  } catch (e) {
    debugPrint('[CACHE COMPUTE SAVE ERROR] $e');
    rethrow;
  }
}

class ScanProvider extends ChangeNotifier {
  ScanProvider({
    Future<Directory> Function()? getDirectory,
    MediaService? mediaService,
  }) : _getDirectory = getDirectory ?? getApplicationDocumentsDirectory,
       _mediaService = mediaService ?? MediaService() {
    _initFuture = _initialize();
  }

  final Future<Directory> Function() _getDirectory;
  Future<void>? _initFuture;
  final MediaService _mediaService;
  final CategorizationService _categorizationService = CategorizationService();

  ScanScope _scanScope = ScanScope.fullGallery;
  ScanScope get scanScope => _scanScope;

  Future<void> _initialize() async {
    await Future.wait([_loadCache(), _loadScanScope()]);
    await _restoreResults();
  }

  static const int analysisVersion = 2;
  bool _analysisCurrent = false;
  bool _resumeAvailable = false;
  String? _checkpointGeneration;
  int _checkpointSequence = 0;
  Future<void> _journalWrite = Future.value();

  Future<void> _saveBatchCheckpoint(List<AssetEntity> assets) {
    final generation = _checkpointGeneration;
    if (generation == null) return Future.value();
    final record = jsonEncode({
      'generation': generation,
      'sequence': ++_checkpointSequence,
      'entries': {
        for (final asset in assets)
          if (_scanCache.containsKey(asset.id))
            asset.id: {
              ..._scanCache[asset.id]!,
              if (_assetSizes.containsKey(asset.id))
                'size': _assetSizes[asset.id],
            },
      },
    });
    return _journalWrite = _journalWrite.catchError((Object _) {}).then((
      _,
    ) async {
      final directory = await _getDirectory();
      await File(
        '${directory.path}/scan_journal.jsonl',
      ).writeAsString('\n$record\n', mode: FileMode.append, flush: true);
    });
  }

  Future<void> _compactJournal() {
    final sequence = _checkpointSequence;
    final generation = _checkpointGeneration;
    return _journalWrite = _journalWrite.then((_) async {
      if (_checkpointSequence != sequence ||
          _checkpointGeneration != generation) {
        return;
      }
      final directory = await _getDirectory();
      await File(
        '${directory.path}/scan_journal.jsonl',
      ).writeAsString('', flush: true);
    });
  }

  Future<void> _restoreCheckpoint(
    Map<String, dynamic> data,
    Directory directory,
  ) async {
    if (data['cacheSchema'] == _currentCacheSchemaVersion &&
        data['cache'] is Map) {
      _scanCache = (data['cache'] as Map).map(
        (key, value) =>
            MapEntry(key as String, Map<String, dynamic>.from(value as Map)),
      );
    }
    _checkpointGeneration = data['checkpointGeneration'] as String?;
    _checkpointSequence = (data['checkpointSequence'] as num?)?.toInt() ?? 0;
    _resumeAvailable =
        data['checkpointEngine'] == analysisVersion && !_analysisCurrent;
    final journal = File('${directory.path}/scan_journal.jsonl');
    if (_checkpointGeneration != null && await journal.exists()) {
      final lines = (await journal.readAsString(
        encoding: const Utf8Codec(allowMalformed: true),
      )).split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final record = jsonDecode(line) as Map;
          final sequence = (record['sequence'] as num).toInt();
          if (record['generation'] != _checkpointGeneration ||
              sequence <= _checkpointSequence) {
            continue;
          }
          (record['entries'] as Map).forEach((id, entry) {
            _scanCache[id as String] = Map<String, dynamic>.from(entry as Map);
          });
          _checkpointSequence = sequence;
        } catch (_) {
          // A process kill can leave only the final journal line incomplete.
        }
      }
    }
    _assetSizes.clear();
    for (final entry in _scanCache.entries) {
      final size = entry.value['size'] as num?;
      if (size != null) _assetSizes[entry.key] = size.toInt();
    }
  }

  bool _recheckVisual = false;
  Future<void> recheckMatches() {
    _analysisCurrent = false;
    _recheckVisual = true;
    return scan(force: true);
  }

  bool _hasSavedResults = false;
  ScanScope _catalogScope = ScanScope.fullGallery;
  String? get catalogNotice =>
      _hasSavedResults && _catalogScope != ScanScope.fullGallery
      ? 'Saved results cover ${_catalogScope.label}. Refresh once for your full gallery.'
      : null;
  Future<void> _resultsWrite = Future.value();

  Future<void> openGallery() async {
    await _initFuture;
    if (_hasSavedResults && _analysisCurrent) {
      notifyListeners();
      final pending = _allScreenshots
          .where(
            (asset) =>
                asset.type == AssetType.image &&
                _scanCache[asset.id]?['category_done'] != true &&
                _scanCache[asset.id]?['category_attempted'] != true,
          )
          .toList();
      if (pending.isNotEmpty && !_isCategorizing) {
        unawaited(_refineCategoriesWithML(pending, _scanSessionId));
      }
    } else {
      await scan(resume: _resumeAvailable);
    }
  }

  Future<void> _restoreResults() async {
    try {
      final directory = await _getDirectory();
      final data = await compute(
        _loadCacheCompute,
        '${directory.path}/scan_results.json',
      );
      if (data['version'] != 1) return;
      _analysisCurrent = data['analysisVersion'] == analysisVersion;
      await _restoreCheckpoint(data, directory);
      _catalogScope = ScanScope.values.firstWhere(
        (scope) => scope.name == data['scope'],
        orElse: () => ScanScope.fullGallery,
      );
      _allScreenshots = (data['assets'] as List).map((raw) {
        final a = Map<String, dynamic>.from(raw as Map);
        return AssetEntity(
          id: a['id'],
          typeInt: a['type'],
          width: a['width'],
          height: a['height'],
          duration: a['duration'] ?? 0,
          orientation: a['orientation'] ?? 0,
          title: a['title'],
          relativePath: a['path'],
          createDateSecond: a['created'],
          modifiedDateSecond: a['modified'],
        );
      }).toList();
      final byId = {for (final asset in _allScreenshots) asset.id: asset};
      List<AssetEntity> resolve(dynamic ids) => (ids as List? ?? [])
          .map((id) => byId[id])
          .whereType<AssetEntity>()
          .toList();
      _assetAlbumMap = Map<String, String>.from(data['albums'] as Map? ?? {});
      _duplicateGroups = (data['duplicates'] as List? ?? [])
          .map(resolve)
          .where((group) => group.length > 1)
          .toList();
      _similarGroups = (data['similar'] as List? ?? [])
          .map(resolve)
          .where((group) => group.length > 1)
          .toList();
      _blurryPhotos = resolve(data['blurry']);
      _largeVideos = resolve(data['videos']);
      for (final asset in _allScreenshots) {
        _registerAssetSource(asset);
        final category = _scanCache[asset.id]?['category'] as String?;
        _addAssetToCategory(
          category != null && _categories.containsKey(category)
              ? category
              : CategorizationService.fallbackCategory(asset),
          asset,
        );
      }
      _blurrySize = _blurryPhotos.fold(
        0,
        (total, asset) => total + (_assetSizes[asset.id] ?? 0),
      );
      _largeVideosSize = _largeVideos.fold(
        0,
        (total, asset) => total + (_assetSizes[asset.id] ?? 0),
      );
      _calculateSmartCleanData();
      _recalculateTotalSize();
      _recalculateCategorySizes();
      _hasSavedResults = true;
    } catch (error) {
      debugPrint('[Results restore] $error');
    }
  }

  Future<void> _saveResults() {
    final data = <String, dynamic>{
      'version': 1,
      'cacheSchema': _currentCacheSchemaVersion,
      'cache': {
        for (final entry in _scanCache.entries)
          entry.key: {
            ...entry.value,
            if (_assetSizes.containsKey(entry.key))
              'size': _assetSizes[entry.key],
          },
      },
      'checkpointGeneration': _checkpointGeneration,
      'checkpointSequence': _checkpointSequence,
      'checkpointEngine': analysisVersion,
      'analysisVersion': _analysisCurrent ? analysisVersion : 0,
      'scope': _catalogScope.name,
      'assets': [
        for (final a in _allScreenshots)
          {
            'id': a.id,
            'type': a.typeInt,
            'width': a.width,
            'height': a.height,
            'duration': a.duration,
            'orientation': a.orientation,
            'title': a.title,
            'path': a.relativePath,
            'created': a.createDateSecond,
            'modified': a.modifiedDateSecond,
          },
      ],
      'albums': Map<String, String>.of(_assetAlbumMap),
      'duplicates': _duplicateGroups
          .map((group) => group.map((a) => a.id).toList())
          .toList(),
      'similar': _similarGroups
          .map((group) => group.map((a) => a.id).toList())
          .toList(),
      'blurry': _blurryPhotos.map((a) => a.id).toList(),
      'videos': _largeVideos.map((a) => a.id).toList(),
    };
    return _resultsWrite = _resultsWrite.catchError((Object _) {}).then((
      _,
    ) async {
      try {
        final directory = await _getDirectory();
        await compute(_saveCacheCompute, {
          'path': '${directory.path}/scan_results.json',
          'cache': data,
        });
      } catch (error) {
        debugPrint('[Results save] $error');
        rethrow;
      }
    });
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
    _invalidateScopeView();
    _prioritizeCategoryScope();
    notifyListeners();
  }

  int _scanSessionId = 0;
  final Set<String> _removedAssetIds = {};

  bool _rescanRequested = false;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCategorizing = false;
  bool get isCategorizing => _isCategorizing;
  int categorizationProcessed = 0;
  int categorizationTotal = 0;

  String? scanErrorMessage;
  String _debugLogs = '';
  String get debugLogs => _debugLogs;

  String _scanStatusMessage = '';
  String get scanStatusMessage => _scanStatusMessage;

  List<AssetEntity> _allScreenshots = [];
  List<AssetEntity>? _scopeAssets;
  Set<String>? _scopeIds;
  void _invalidateScopeView() {
    _scopeAssets = null;
    _scopeIds = null;
  }

  List<AssetEntity> get allScreenshots {
    if (_scanScope == ScanScope.fullGallery) return _allScreenshots;
    return _scopeAssets ??= _allScreenshots
        .where(
          (asset) => _mediaService.matchesScope(
            asset,
            _scanScope,
            _assetAlbumMap[asset.id],
          ),
        )
        .toList();
  }

  Set<String> get _visibleIds =>
      _scopeIds ??= allScreenshots.map((asset) => asset.id).toSet();
  List<AssetEntity> _scopeFilter(List<AssetEntity> assets) =>
      _scanScope == ScanScope.fullGallery
      ? assets
      : assets.where((asset) => _visibleIds.contains(asset.id)).toList();
  List<List<AssetEntity>> _scopeGroups(List<List<AssetEntity>> groups) =>
      _scanScope == ScanScope.fullGallery
      ? groups
      : groups.map(_scopeFilter).where((group) => group.length > 1).toList();
  int _sumSizes(Iterable<AssetEntity> assets) =>
      assets.fold(0, (total, asset) => total + (_assetSizes[asset.id] ?? 0));

  Map<String, String> _assetAlbumMap = {};
  Map<String, String> get assetAlbumMap => _assetAlbumMap;

  // Duplicates: Lists of assets that are duplicates (grouped)
  List<List<AssetEntity>> _duplicateGroups = [];
  List<List<AssetEntity>> get duplicateGroups => _scopeGroups(_duplicateGroups);

  // Similar: Lists of assets that are similar (grouped)
  List<List<AssetEntity>> _similarGroups = [];
  List<List<AssetEntity>> get similarGroups => _scopeGroups(_similarGroups);

  // Modern Clean Categories
  Map<String, List<AssetEntity>> _categories = {
    for (final category in CategorizationService.availableCategories)
      category: <AssetEntity>[],
  };
  Map<String, List<AssetEntity>> get categories =>
      _scanScope == ScanScope.fullGallery
      ? _categories
      : _categories.map((key, assets) => MapEntry(key, _scopeFilter(assets)));

  final Map<String, int> _categorySizes = {};

  int getCategorySize(String category) => _scanScope == ScanScope.fullGallery
      ? _categorySizes[category] ?? 0
      : _sumSizes(_scopeFilter(_categories[category] ?? []));

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
  int get totalSize => _scanScope == ScanScope.fullGallery
      ? _totalSize
      : _sumSizes(allScreenshots);

  void _recalculateTotalSize() {
    _totalSize = 0;
    for (final asset in _allScreenshots) {
      _totalSize += _assetSizes[asset.id] ?? 0;
    }
  }

  int _duplicateSize = 0;
  int get duplicateSize => _scanScope == ScanScope.fullGallery
      ? _duplicateSize
      : _sumSizes(duplicateGroups.expand((group) => group.skip(1)));

  int _similarSize = 0;
  int get similarSize => _scanScope == ScanScope.fullGallery
      ? _similarSize
      : _sumSizes(similarGroups.expand((group) => group.skip(1)));

  // Cache for file sizes
  final Map<String, int> _assetSizes = {};
  Map<String, Map<String, dynamic>> _mediaFacts = {};
  Map<String, int> get assetSizes => _assetSizes;

  // Blurry Photos
  List<AssetEntity> _blurryPhotos = [];
  List<AssetEntity> get blurryPhotos => _scopeFilter(_blurryPhotos);
  int _blurrySize = 0;
  int get blurrySize => _scanScope == ScanScope.fullGallery
      ? _blurrySize
      : _sumSizes(blurryPhotos);
  String get formattedBlurrySize => AppUtils.formatBytes(blurrySize);

  // Large Videos
  List<AssetEntity> _largeVideos = [];
  List<AssetEntity> get largeVideos => _scopeFilter(_largeVideos);
  int _largeVideosSize = 0;
  int get largeVideosSize => _scanScope == ScanScope.fullGallery
      ? _largeVideosSize
      : _sumSizes(largeVideos);
  String get formattedLargeVideosSize => AppUtils.formatBytes(largeVideosSize);

  // Trashed items tracking for this session
  int _sessionTrashedCount = 0;
  int get sessionTrashedCount => _sessionTrashedCount;

  int _sessionTrashedBytes = 0;
  int get sessionTrashedBytes => _sessionTrashedBytes;
  String get formattedSessionTrashedBytes =>
      AppUtils.formatBytes(_sessionTrashedBytes);

  final List<Map<String, dynamic>> _sessionTrashedItems = [];
  List<Map<String, dynamic>> get sessionTrashedItems =>
      List.unmodifiable(_sessionTrashedItems);

  // Persistent Cache: key = asset.id, value = {category, md5, dHash, size, is_blurry}
  Map<String, Map<String, dynamic>> _scanCache = {};
  Future<void> _cacheWrite = Future.value();

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

    final remainingMillis =
        (elapsedMilliseconds / _progress) - elapsedMilliseconds;
    if (remainingMillis < 0) return '00:00 left';

    final duration = Duration(milliseconds: remainingMillis.toInt());
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds left';
  }

  int get reviewGroupCount => duplicateGroups.length + similarGroups.length;
  bool get preferSimilarReview =>
      duplicateGroups.isEmpty && similarGroups.isNotEmpty;
  String get reviewGroupSummary =>
      '${duplicateGroups.length} exact / ${similarGroups.length} similar groups';

  int get totalDuplicateCount =>
      duplicateGroups.fold(0, (sum, group) => sum + group.length);
  int get totalSimilarCount =>
      similarGroups.fold(0, (sum, group) => sum + group.length);

  static const int _currentCacheSchemaVersion = 10;

  Future<void> _loadCache() async {
    try {
      final directory = await _getDirectory();
      final path = '${directory.path}/scan_cache.json';

      final rawCache = await compute(_loadCacheCompute, path);
      _scanCache = rawCache.map((key, value) {
        return MapEntry(key, Map<String, dynamic>.from(value as Map));
      });

      final prefs = await SharedPreferences.getInstance();
      final int savedVersion = prefs.getInt('scan_cache_schema_version') ?? 1;

      if (savedVersion < _currentCacheSchemaVersion) {
        // Discard legacy buggy category tags from previous algorithmic versions
        for (var key in _scanCache.keys) {
          _scanCache[key]!.remove('category');
          _scanCache[key]!.remove('category_done');
          _scanCache[key]!.remove('category_attempted');
        }
        await prefs.setInt(
          'scan_cache_schema_version',
          _currentCacheSchemaVersion,
        );
        debugPrint(
          '[CACHE UPGRADE] Discarded legacy category tags, upgraded to v$_currentCacheSchemaVersion',
        );
      }

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

  Future<void> _saveCache() {
    // Several scan stages may finish together. Serialize writes to the same
    // temporary path so a later result cannot race an earlier cache save.
    _cacheWrite = _cacheWrite.then((_) => _writeCache());
    return _cacheWrite;
  }

  Future<void> _writeCache() async {
    try {
      _assetSizes.forEach((id, size) {
        if (_scanCache.containsKey(id)) {
          _scanCache[id]!['size'] = size;
        }
      });

      final directory = await _getDirectory();
      final path = '${directory.path}/scan_cache.json';

      await compute(_saveCacheCompute, {
        'path': path,
        'cache': Map<String, Map<String, dynamic>>.from(_scanCache),
      });
    } catch (e) {
      debugPrint('[CACHE ERROR] Error saving cache: $e');
    }
  }

  // --- ISOLATE LOGIC ---
  Isolate? _scannerIsolate;
  ReceivePort? _scannerReceivePort;
  SendPort? _isolateSendPort;
  Completer<void>? _isolateReadyCompleter;

  Future<void> _spawnIsolate() async {
    if (_scannerIsolate != null) return;

    final receivePort = ReceivePort();
    _scannerReceivePort = receivePort;
    _isolateReadyCompleter = Completer<void>();

    _scannerIsolate = await Isolate.spawn(
      scannerIsolateEntry,
      receivePort.sendPort,
    );

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
        final sharpness = ((message['sharpness'] as Map?) ?? {})
            .cast<String, double>();
        final blurTypes = ((message['blurTypes'] as Map?) ?? {})
            .cast<String, String>();
        _handleFinalResults(
          duplicates,
          similar,
          blurry,
          sharpnessScores: sharpness,
          blurTypes: blurTypes,
        );
        break;
      case ScannerResponse.progress:
        _setTargetProgress(
          0.94 + 0.05 * (message['value'] as double),
          status: message['status'] as String,
        );
        break;
      case ScannerResponse.log:
        _debugLogs += '\n[Isolate] ${message['message']}';
        notifyListeners();
        break;
      case ScannerResponse.error:
        _scannerError = message['message'].toString();
        for (final waiter in _batchWaiters) {
          if (!waiter.isCompleted) waiter.complete();
        }
        _debugLogs += '\n[Isolate Error] ${message['message']}';
        if (_allBatchesProcessedCompleter != null &&
            !_allBatchesProcessedCompleter!.isCompleted) {
          _allBatchesProcessedCompleter!.complete();
        }
        if (_finalResultsCompleter != null &&
            !_finalResultsCompleter!.isCompleted) {
          _finalResultsCompleter!.complete();
        }
        notifyListeners();
        break;
    }
  }

  int _batchesSent = 0;
  int _batchesProcessed = 0;
  bool _allBatchesDispatched = false;
  Completer<void>? _allBatchesProcessedCompleter;

  final List<Completer<void>> _batchWaiters = [];
  String? _scannerError;

  Future<void> _streamBatchToIsolate(List<ScanItem> chunk) async {
    if (chunk.isEmpty || _isolateSendPort == null) return;
    final waiter = Completer<void>();
    _batchWaiters.add(waiter);
    _batchesSent++;
    _isolateSendPort!.send(ScanBatch(List.of(chunk)));
    try {
      await waiter.future.timeout(const Duration(seconds: 45));
      if (_scannerError != null) throw StateError(_scannerError!);
    } on TimeoutException {
      _killIsolate();
      throw StateError(
        'A scan batch stopped responding. Please retry the scan.',
      );
    } finally {
      _batchWaiters.remove(waiter);
    }
  }

  void _handleBatchResults(List<ProcessedItem> results) {
    for (var item in results) {
      if (_removedAssetIds.contains(item.id)) continue;
      if (!_scanCache.containsKey(item.id)) {
        _scanCache[item.id] = {};
      }

      if (item.dHash != null) {
        _scanCache[item.id]!['dHash'] = item.dHash;
      }
      if (item.md5 != null) {
        _scanCache[item.id]!['md5'] = item.md5;
      }
      if (item.blurChecked) {
        _scanCache[item.id]!['is_blurry'] = item.isBlurry;
        _scanCache[item.id]!['sharpness'] = item.sharpnessScore;
      }
      if (item.blurType != null) {
        _scanCache[item.id]!['blur_type'] = item.blurType;
      }
    }

    _batchesProcessed++;
    if (_batchWaiters.isNotEmpty && !_batchWaiters.first.isCompleted) {
      _batchWaiters.first.complete();
    }
    if (_allBatchesDispatched &&
        _batchesSent > 0 &&
        _batchesProcessed >= _batchesSent) {
      if (_allBatchesProcessedCompleter != null &&
          !_allBatchesProcessedCompleter!.isCompleted) {
        _allBatchesProcessedCompleter!.complete();
      }
    }
  }

  Completer<void>? _finalResultsCompleter;

  void _handleFinalResults(
    List<List<String>> duplicates,
    List<List<String>> similar,
    List<String> blurry, {
    Map<String, double> sharpnessScores = const {},
    Map<String, String> blurTypes = const {},
  }) {
    for (final entry in sharpnessScores.entries) {
      if (_removedAssetIds.contains(entry.key)) continue;
      if (!_scanCache.containsKey(entry.key)) {
        _scanCache[entry.key] = {};
      }
      _scanCache[entry.key]!['sharpness'] = entry.value;
    }
    for (final entry in blurTypes.entries) {
      if (_removedAssetIds.contains(entry.key)) continue;
      if (!_scanCache.containsKey(entry.key)) {
        _scanCache[entry.key] = {};
      }
      _scanCache[entry.key]!['blur_type'] = entry.value;
    }

    _duplicateGroups = [];
    _similarGroups = [];
    _blurryPhotos = [];
    _blurrySize = 0;

    Map<String, AssetEntity> assetMap = {
      for (var a in _allScreenshots) a.id: a,
    };

    for (var group in duplicates) {
      List<AssetEntity> assets = group
          .map((id) => assetMap[id])
          .whereType<AssetEntity>()
          .toList();
      if (assets.length > 1) {
        assets.sort(_compareAssetsForKeeping);
        _duplicateGroups.add(assets);
      }
    }

    for (var group in similar) {
      List<AssetEntity> assets = group
          .map((id) => assetMap[id])
          .whereType<AssetEntity>()
          .toList();
      if (assets.length > 1) {
        assets.sort(_compareBurstAssetsForKeeping);
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
    final sessionId = _scanSessionId;
    try {
      final videos = _allScreenshots
          .where((asset) => asset.type == AssetType.video)
          .toList();
      if (_scanSessionId != sessionId) return;
      final List<AssetEntity> resolvedVideos = [];
      int totalVideoSize = 0;

      for (int i = 0; i < videos.length; i += 30) {
        if (_scanSessionId != sessionId) return;
        final chunk = videos.sublist(
          i,
          (i + 30 < videos.length) ? i + 30 : videos.length,
        );
        final results = await Future.wait(
          chunk.map((v) async {
            final knownSize =
                (_mediaFacts[v.id]?['size'] as num?)?.toInt() ?? 0;
            if (knownSize > 0) return (v, knownSize);
            final modified =
                (_mediaFacts[v.id]?['modified'] as num?)?.toInt() ??
                v.modifiedDateSecond;
            if (modified != null &&
                modified > 0 &&
                _scanCache[v.id]?['modified'] == modified &&
                _assetSizes.containsKey(v.id)) {
              return (v, _assetSizes[v.id]!);
            }
            try {
              final file = await v.file.timeout(const Duration(seconds: 8));
              if (file != null) {
                final len = await file.length();
                return (v, len);
              }
            } catch (_) {}
            return (v, 0);
          }),
        );
        if (_scanSessionId != sessionId) return;

        for (final r in results) {
          final v = r.$1;
          final len = r.$2;
          if (len > 0 && !_removedAssetIds.contains(v.id)) {
            _assetSizes[v.id] = len;
            final modified =
                (_mediaFacts[v.id]?['modified'] as num?)?.toInt() ??
                v.modifiedDateSecond;
            if (modified != null && modified > 0) {
              final entry = _scanCache.putIfAbsent(v.id, () => {});
              entry['modified'] = modified;
              entry['size'] = len;
            }
            resolvedVideos.add(v);
            totalVideoSize += len;
          }
        }
      }
      resolvedVideos.removeWhere(
        (asset) => _removedAssetIds.contains(asset.id),
      );
      totalVideoSize = resolvedVideos.fold(
        0,
        (total, asset) => total + (_assetSizes[asset.id] ?? 0),
      );
      resolvedVideos.sort(
        (a, b) => (_assetSizes[b.id] ?? 0).compareTo(_assetSizes[a.id] ?? 0),
      );
      _largeVideos = resolvedVideos;
      _largeVideosSize = totalVideoSize;
      _calculateSmartCleanData();
      _recalculateTotalSize();
      _recalculateCategorySizes();
      notifyListeners();
      unawaited(_saveCache());
    } catch (e) {
      debugPrint('Error scanning videos: $e');
    }
  }

  void _killIsolate() {
    _isolateSendPort?.send(ScannerCommand.dispose);
    _scannerIsolate?.kill();
    _scannerIsolate = null;
    _scannerReceivePort?.close();
    _scannerReceivePort = null;
    _isolateSendPort = null;
  }

  @override
  void dispose() {
    _scanSessionId++;
    _progressTicker?.cancel();
    _killIsolate();
    _categorizationService.dispose();
    super.dispose();
  }

  // Smooth continuous progress ticker (advances 1%..2% continuously)
  void _startProgressTicker() {
    _progressTicker?.cancel();
    _progress = 0.01;
    _targetProgress = 0.08;
    _scanStatusMessage = 'Scanning media albums...';

    _progressTicker = Timer.periodic(const Duration(milliseconds: 150), (
      timer,
    ) {
      if (!_isLoading) {
        timer.cancel();
        return;
      }

      if (_progress < _targetProgress) {
        final diff = _targetProgress - _progress;
        final step = diff > 0.15 ? 0.03 : 0.015;
        _progress = (_progress + step).clamp(0.0, _targetProgress);
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

  Future<void> scan({bool force = false, bool resume = false}) async {
    if (_isLoading) {
      if (force) _rescanRequested = true;
      return;
    }
    if (_initFuture != null) await _initFuture;

    _isLoading = true;
    int mySessionId = _scanSessionId;

    _isFirstScan = _scanCache.isEmpty;
    _scanTimer.reset();
    _scanTimer.start();

    _recentScanned = [];
    scanErrorMessage = null;
    _debugLogs = 'Starting Fast Scan...';
    _startProgressTicker();
    unawaited(AnalyticsService.logScanStarted(scope: _scanScope.name));
    notifyListeners();

    bool completed = false;
    bool ownsCategoryJob = false;
    try {
      // 1. Fetch Assets and Authoritative Folder / Album Mappings
      _setTargetProgress(0.15, status: 'Scanning media albums...');
      final scanResult = await _mediaService.fetchAllAssets(
        scope: ScanScope.fullGallery,
      );
      if (_scanSessionId != mySessionId) return;
      if (!scanResult.hasReadPermission) {
        throw StateError('Gallery permission was denied');
      }

      final uniqueAssets = {for (var a in scanResult.screenshots) a.id: a};
      final previousIds = _allScreenshots.map((asset) => asset.id).toSet();
      bool mediaChanged =
          !_hasSavedResults ||
          !_analysisCurrent ||
          previousIds.length != uniqueAssets.length ||
          uniqueAssets.keys.any((id) => !previousIds.contains(id));
      _catalogScope = ScanScope.fullGallery;
      _allScreenshots = uniqueAssets.values.toList();
      _invalidateScopeView();
      _assetAlbumMap = scanResult.assetAlbumMap;
      _mediaFacts = await _mediaService.fetchMediaFacts();
      if (_scanSessionId != mySessionId) return;
      _debugLogs +=
          '\nFound ${_allScreenshots.length} assets across ${_assetAlbumMap.length} folder tags.';

      // Cached sizes and hashes are valid only for the version of the asset
      // that produced them. MediaStore IDs can survive in-place edits.
      final changedAssetIds = <String>{};
      for (final asset in _allScreenshots) {
        final modified =
            (_mediaFacts[asset.id]?['modified'] as num?)?.toInt() ??
            asset.modifiedDateSecond;
        final metadata =
            '${asset.typeInt}:${asset.width}:${asset.height}:${asset.duration}:${asset.createDateSecond}:${asset.title}:${asset.relativePath}';
        final unchanged = modified != null && modified > 0
            ? (_scanCache[asset.id]?['modified'] == modified)
            : (_scanCache[asset.id]?['metadata'] == metadata);
        final previousMetadata = _scanCache[asset.id]?['metadata'];
        final previousSize = (_scanCache[asset.id]?['size'] as num?)?.toInt();
        final currentSize = (_mediaFacts[asset.id]?['size'] as num?)?.toInt();
        final sizeChanged =
            previousSize != null &&
            previousSize > 0 &&
            currentSize != null &&
            currentSize > 0 &&
            previousSize != currentSize;
        if (!unchanged ||
            sizeChanged ||
            (previousMetadata != null && previousMetadata != metadata)) {
          mediaChanged = true;
          changedAssetIds.add(asset.id);
          _scanCache.remove(asset.id);
          _assetSizes.remove(asset.id);
        }
        final entry = _scanCache.putIfAbsent(asset.id, () => {});
        entry['metadata'] = metadata;
        if (modified != null && modified > 0) entry['modified'] = modified;
        final size = (_mediaFacts[asset.id]?['size'] as num?)?.toInt();
        if (size != null && size > 0) _assetSizes[asset.id] = size;
      }
      if (!mediaChanged) {
        _recalculateTotalSize();
        _recalculateCategorySizes();
        if (force && !_isCategorizing) {
          final retry = _allScreenshots
              .where(
                (asset) =>
                    asset.type == AssetType.image &&
                    _scanCache[asset.id]?['category_done'] != true,
              )
              .toList();
          if (retry.isNotEmpty) {
            unawaited(_refineCategoriesWithML(retry, _scanSessionId));
          }
        }
        _debugLogs +=
            '\nGallery unchanged; reused saved groups and category work.';
        completed = true;
      unawaited(AnalyticsService.logScanCompleted(
        totalAssets: _allScreenshots.length,
        duplicatesFound: _duplicateGroups.length,
        similarFound: _similarGroups.length,
        blurryFound: _blurryPhotos.length,
      ));
        return;
      }
      _analysisCurrent = false;
      final recheckVisual = _recheckVisual;
      _recheckVisual = false;
      _scanSessionId++;
      mySessionId = _scanSessionId;
      _removedAssetIds.clear();
      _isCategorizing = false;
      _largeVideos = [];
      _largeVideosSize = 0;
      final videoScan = scanLargeVideos();

      // Keep still-valid saved matches visible while replacement analysis runs.
      // Resolve against the fresh catalog and discard removed or edited assets.
      List<List<AssetEntity>> retainMatches(List<List<AssetEntity>> groups) =>
          groups
              .map(
                (group) => group
                    .where((asset) => !changedAssetIds.contains(asset.id))
                    .map((asset) => uniqueAssets[asset.id])
                    .whereType<AssetEntity>()
                    .toList(),
              )
              .where((group) => group.length > 1)
              .toList();
      _duplicateGroups = retainMatches(_duplicateGroups);
      _similarGroups = retainMatches(_similarGroups);
      _blurryPhotos = [];
      _blurrySize = 0;
      _totalSize = 0;
      _calculateSmartCleanData();

      _categories = {
        for (final category in CategorizationService.availableCategories)
          category: <AssetEntity>[],
      };
      _assetCategoryMap.clear();
      _assetSourceMap.clear();
      _sourceMedia.clear();
      _categoryPositions.clear();

      _setTargetProgress(0.28, status: 'Organizing smart categories...');

      // 2. Authoritative Categorization Pass using Album Names + Path + Title + ML Refinement
      final List<AssetEntity> assetsNeedingML = [];

      for (final asset in _allScreenshots) {
        _registerAssetSource(asset);
        final cachedCat = _scanCache[asset.id]?['category'] as String?;
        if (cachedCat != null &&
            cachedCat.isNotEmpty &&
            _categories.containsKey(cachedCat)) {
          _addAssetToCategory(cachedCat, asset);
          if (asset.type == AssetType.image &&
              _scanCache[asset.id]?['category_done'] != true &&
              (!resume ||
                  _scanCache[asset.id]?['category_attempted'] != true)) {
            assetsNeedingML.add(asset);
          }
        } else {
          final albumName = _assetAlbumMap[asset.id];
          final quickCat = _categorizationService.quickCategorize(
            asset,
            albumName: albumName,
          );
          if (quickCat != null &&
              !CategorizationService.sourceCategories.contains(quickCat)) {
            _addAssetToCategory(quickCat, asset);
            if (!_scanCache.containsKey(asset.id)) _scanCache[asset.id] = {};
            _scanCache[asset.id]!['category'] = quickCat;
            _scanCache[asset.id]!['category_done'] = true;
          } else {
            _addAssetToCategory(
              CategorizationService.fallbackCategory(asset),
              asset,
            );
            if (asset.type == AssetType.image) {
              assetsNeedingML.add(asset);
            } else {
              _scanCache.putIfAbsent(asset.id, () => {})['category_done'] =
                  true;
            }
          }
        }

        if (_scanCache[asset.id]?['is_blurry'] == true) {
          _blurryPhotos.add(asset);
          _blurrySize += _assetSizes[asset.id] ?? 0;
        }
      }

      _recalculateTotalSize();
      _recalculateCategorySizes();

      ownsCategoryJob = true;
      _isCategorizing = assetsNeedingML.isNotEmpty;
      categorizationProcessed = 0;
      categorizationTotal = assetsNeedingML.length;
      _setTargetProgress(0.38, status: 'Identifying candidate duplicates...');

      if (!resume || _checkpointGeneration == null) {
        _checkpointGeneration = DateTime.now().microsecondsSinceEpoch
            .toString();
        _checkpointSequence = 0;
      }
      _resumeAvailable = true;
      await _saveResults();
      _hasSavedResults = true;

      // 3. Spawn Background Isolate
      await _spawnIsolate();
      if (_scanSessionId != mySessionId) return;
      _isolateSendPort!.send(ScannerCommand.clear);

      // 4. CANDIDATE IDENTIFICATION WITHOUT FILE I/O
      // A) Duplicate Candidates: exact same pixel dimensions
      final Map<String, List<AssetEntity>> dimensionGroups = {};
      for (final asset in _allScreenshots) {
        if (asset.type == AssetType.image &&
            asset.width > 0 &&
            asset.height > 0) {
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

      // B) Similar / Burst photo candidates: consecutive camera shots within 4 seconds
      final List<AssetEntity> temporalAssets = _allScreenshots
          .where(
            (a) => a.type == AssetType.image && _isCameraOrGalleryCapture(a),
          )
          .toList();

      temporalAssets.sort((a, b) {
        final dateA =
            a.createDateSecond ??
            (a.createDateTime.millisecondsSinceEpoch ~/ 1000);
        final dateB =
            b.createDateSecond ??
            (b.createDateTime.millisecondsSinceEpoch ~/ 1000);
        return dateA.compareTo(dateB);
      });

      final Map<String, List<AssetEntity>> burstClusters = {};
      int clusterIndex = 0;
      for (int i = 0; i < temporalAssets.length - 1; i++) {
        final a = temporalAssets[i];
        final b = temporalAssets[i + 1];

        final dateA =
            a.createDateSecond ??
            (a.createDateTime.millisecondsSinceEpoch ~/ 1000);
        final dateB =
            b.createDateSecond ??
            (b.createDateTime.millisecondsSinceEpoch ~/ 1000);
        final diffSec = (dateB - dateA).abs();

        if (diffSec <= 30 &&
            a.width > 0 &&
            a.height > 0 &&
            b.width > 0 &&
            b.height > 0) {
          final ratioA = a.width / a.height;
          final ratioB = b.width / b.height;
          if ((ratioA - ratioB).abs() < 0.08) {
            if ((burstClusters['cluster_$clusterIndex']?.length ?? 0) >= 20) {
              clusterIndex++;
            }
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
        final path =
            '${a.title ?? ''} ${a.relativePath ?? ''} ${_assetAlbumMap[a.id] ?? ''}'
                .toLowerCase();
        return path.contains('dcim') ||
            path.contains('camera') ||
            path.contains('img_');
      }).toList());

      // 5. TARGETED BATCH RESOLUTION WITH PIPELINED STREAMING
      _setTargetProgress(0.48, status: 'Analyzing duplicate file sizes...');

      // Step A: Stat file sizes for every scanned photo in parallel chunks of 60
      final photosToMeasure = _allScreenshots
          .where((asset) => asset.type == AssetType.image)
          .toList();
      final Map<String, String> resolvedPaths = {};
      for (int i = 0; i < photosToMeasure.length; i += 60) {
        if (_scanSessionId != mySessionId) return;
        final chunk = photosToMeasure.sublist(
          i,
          (i + 60 < photosToMeasure.length) ? i + 60 : photosToMeasure.length,
        );

        final results = await Future.wait(
          chunk.map((asset) async {
            if (_assetSizes.containsKey(asset.id)) {
              return (asset, _assetSizes[asset.id]!, '');
            }
            try {
              final file = await asset.file.timeout(const Duration(seconds: 8));
              if (file != null) {
                final len = await file.length();
                return (asset, len, file.path);
              }
            } catch (_) {}
            return (asset, 0, '');
          }),
        );

        if (_scanSessionId != mySessionId) return;
        for (final r in results) {
          final asset = r.$1;
          final size = r.$2;
          final path = r.$3;
          if (path.isNotEmpty) {
            resolvedPaths[asset.id] = path;
          }
          if (size > 0) {
            _assetSizes[asset.id] = size;
            if (!_scanCache.containsKey(asset.id)) _scanCache[asset.id] = {};
            _scanCache[asset.id]!['size'] = size;
          }
        }

        final ratio = (i + chunk.length) / max(1, photosToMeasure.length);
        if (i % 180 == 0 || i + chunk.length >= photosToMeasure.length) {
          _setTargetProgress(
            0.48 + 0.12 * ratio,
            status: 'Analyzing duplicate file sizes...',
          );
        }
      }

      _recalculateTotalSize();

      // Group candidate duplicates by (dimension, size)
      final Map<String, List<AssetEntity>> exactCandidateGroups = {};
      for (final asset in duplicateCandidates) {
        final size = _assetSizes[asset.id] ?? 0;
        if (size > 0) {
          final groupKey = '${asset.width}x${asset.height}_$size';
          exactCandidateGroups.putIfAbsent(groupKey, () => []).add(asset);
        }
      }

      _scannerError = null;
      _batchesSent = 0;
      _batchesProcessed = 0;
      _allBatchesDispatched = false;
      _allBatchesProcessedCompleter = Completer<void>();

      // A single media pass returns current content hashes, visual signatures
      // and pending semantic categories without reopening files through Dart.
      final verifyIds = {
        for (final group in exactCandidateGroups.values.where(
          (group) => group.length > 1,
        ))
          ...group.map((a) => a.id),
      };
      final clusterById = {
        for (final entry in burstClusters.entries)
          for (final asset in entry.value) asset.id: entry.key,
      };
      final blurIds = cameraPhotos.map((asset) => asset.id).toSet();
      final classifyIds = assetsNeedingML.map((asset) => asset.id).toSet();
      final photos = List<AssetEntity>.of(photosToMeasure);
      if (_scanScope != ScanScope.fullGallery) {
        photos.sort(
          (a, b) => (_visibleIds.contains(b.id) ? 1 : 0).compareTo(
            _visibleIds.contains(a.id) ? 1 : 0,
          ),
        );
      }
      final resumedCount = resume
          ? photos
                .where(
                  (asset) =>
                      _scanCache[asset.id]?['analysis_done_version'] ==
                      analysisVersion,
                )
                .length
          : 0;
      if (resumedCount > 0) {
        _setTargetProgress(
          0.60 + 0.32 * resumedCount / max(1, photos.length),
          status:
              'Resuming saved scan: $resumedCount / ${photos.length} images already analyzed',
        );
      }
      int readableSignatures = 0;
      for (var start = 0; start < photos.length; start += 8) {
        if (_scanSessionId != mySessionId) return;
        final chunk = photos.sublist(start, min(start + 8, photos.length));
        final requests = <Map<String, dynamic>>[];
        for (final asset in chunk) {
          final cache = _scanCache[asset.id] ?? {};
          final needsHash =
              recheckVisual ||
              cache['visual_version'] != 2 ||
              (cache['dHash'] as String?)?.length != 128;
          final needsProof =
              verifyIds.contains(asset.id) &&
              !(resume &&
                  !recheckVisual &&
                  cache['proof_version'] == analysisVersion &&
                  cache['verified_md5'] is String);
          if (needsHash || classifyIds.contains(asset.id) || needsProof) {
            requests.add({
              'id': asset.id,
              'hash': needsHash,
              'verifyBytes': needsProof,
              'classify': classifyIds.contains(asset.id),
              'readText': CategorizationService.needsTextFromName(asset),
            });
          }
        }
        Map<String, Map<String, dynamic>> rows = {};
        if (requests.isNotEmpty) {
          rows = await _categorizationService.analyzeMediaBatch(requests);
        }
        if (_scanSessionId != mySessionId) return;
        final batch = await Future.wait(
          chunk.map((asset) async {
            if (_removedAssetIds.contains(asset.id)) {
              return ScanItem(
                id: asset.id,
                path: '',
                needsMd5: false,
                needsDHash: false,
              );
            }
            final row = rows[asset.id];
            final cache = _scanCache.putIfAbsent(asset.id, () => {});
            if (row?['verifiedMd5'] is String) {
              cache['verified_md5'] = row!['verifiedMd5'];
              cache['proof_version'] = analysisVersion;
            }
            if (row?['dHash'] is String) {
              cache['dHash'] = row!['dHash'];
              cache['visual_version'] = 2;
            }
            if (classifyIds.contains(asset.id)) {
              cache['category_attempted'] = true;
              cache['category'] = _assetCategoryMap[asset.id];
              if (row?['ok'] == true && row?['labels'] is Map) {
                final category = _categorizationService.categoryFromNative(
                  asset,
                  row!,
                  albumName: _assetAlbumMap[asset.id],
                );
                _addAssetToCategory(category, asset);
                cache['category'] = category;
                cache['category_done'] = true;
              }
              categorizationProcessed++;
            }
            if ((cache['dHash'] as String?)?.length == 128 &&
                cache['visual_version'] == 2) {
              readableSignatures++;
            }
            final checkBlur =
                blurIds.contains(asset.id) && cache['is_blurry'] == null;
            Uint8List? thumbnail;
            if (checkBlur) {
              try {
                thumbnail = await asset
                    .thumbnailDataWithSize(const ThumbnailSize.square(128))
                    .timeout(const Duration(seconds: 5));
              } catch (_) {}
            }
            if (cache['visual_version'] == 2 &&
                cache['category_done'] == true &&
                (!verifyIds.contains(asset.id) ||
                    cache['proof_version'] == analysisVersion)) {
              cache['analysis_done_version'] = analysisVersion;
            }
            return ScanItem(
              id: asset.id,
              path: '',
              cachedDHash: cache['visual_version'] == 2
                  ? cache['dHash'] as String?
                  : null,
              verifiedMd5:
                  row?['verifiedMd5'] as String? ??
                  (resume &&
                          !recheckVisual &&
                          cache['proof_version'] == analysisVersion
                      ? cache['verified_md5'] as String?
                      : null),
              needsMd5: false,
              needsDHash: false,
              thumbBytes: thumbnail,
              checkBlur: checkBlur,
              cachedIsBlurry: cache['is_blurry'] as bool?,
              cachedSharpness: (cache['sharpness'] as num?)?.toDouble(),
              cachedBlurType: cache['blur_type'] as String?,
              clusterId: clusterById[asset.id],
              aspectRatio: asset.height > 0 ? asset.width / asset.height : 1,
            );
          }),
        );
        await _streamBatchToIsolate(batch);
        _setTargetProgress(
          0.60 + 0.32 * (start + chunk.length) / max(1, photos.length),
          status:
              '${resume ? 'Resuming saved scan' : 'Analyzing media'} ${start + chunk.length} / ${photos.length}',
        );
        await _saveBatchCheckpoint(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      _isCategorizing = false;
      if (photos.isNotEmpty && readableSignatures == 0) {
        throw StateError('Gallery images could not be read');
      }

      // Mark all batches dispatched
      _allBatchesDispatched = true;
      if (_batchesProcessed >= _batchesSent) {
        if (_allBatchesProcessedCompleter != null &&
            !_allBatchesProcessedCompleter!.isCompleted) {
          _allBatchesProcessedCompleter!.complete();
        }
      }

      // Await completion of all pipelined batches (the isolate has already finished most work!)
      _setTargetProgress(0.93, status: 'Finalizing grouping...');
      if (_batchesSent > 0) {
        await _allBatchesProcessedCompleter!.future;
      }

      // Finalize Result in Isolate
      if (_isolateSendPort != null) {
        _finalResultsCompleter = Completer<void>();
        _isolateSendPort!.send(ScannerCommand.finalize);
        await _finalResultsCompleter!.future.timeout(
          const Duration(seconds: 120),
        );
        if (_scannerError != null) throw StateError(_scannerError!);
      }

      _recalculateCategorySizes();

      await videoScan;
      if (_scanSessionId != mySessionId) return;

      _resumeAvailable = false;
      _analysisCurrent = true;
      _hasSavedResults = true;
      await _saveCache();
      await _saveResults();
      completed = true;
      unawaited(AnalyticsService.logScanCompleted(
        totalAssets: _allScreenshots.length,
        duplicatesFound: _duplicateGroups.length,
        similarFound: _similarGroups.length,
        blurryFound: _blurryPhotos.length,
      ));
      await _compactJournal();
      // Finish progress smoothly to 100%
      _finishProgress();
    } catch (e) {
      if (ownsCategoryJob && !completed) {
        _analysisCurrent = false;
        _resumeAvailable = true;
      }
      scanErrorMessage =
          'Gallery analysis could not finish. Check photo access in Android Settings, then retry.';
      debugPrint('Scan Error: $e');
      _debugLogs += '\nCritical Error: $e';
    } finally {
      if (_scanSessionId == mySessionId) {
        _isLoading = false;
        if (ownsCategoryJob) _isCategorizing = false;
        if (completed) {
          _finishProgress();
        } else {
          _progressTicker?.cancel();
          _scanStatusMessage = 'Scan interrupted. Tap Scan to retry.';
          _killIsolate();
          notifyListeners();
        }
        unawaited(WidgetService.syncWithProvider(this));
        if (_rescanRequested) {
          _rescanRequested = false;
          unawaited(forceRescan());
        }
      }
    }
  }

  String get formattedTotalSize => AppUtils.formatBytes(totalSize);
  String get formattedDuplicateSize => AppUtils.formatBytes(duplicateSize);
  String get formattedSimilarSize => AppUtils.formatBytes(similarSize);

  bool _isCameraOrGalleryCapture(AssetEntity asset) {
    final path =
        '${asset.title ?? ''} ${asset.relativePath ?? ''} ${_assetAlbumMap[asset.id] ?? ''}'
            .toLowerCase();
    if (path.contains('screenshot') ||
        path.contains('whatsapp') ||
        path.contains('download')) {
      return false;
    }
    return true;
  }

  int _getFolderAuthorityScore(AssetEntity asset) {
    final path =
        '${asset.title ?? ''} ${asset.relativePath ?? ''} ${_assetAlbumMap[asset.id] ?? ''}'
            .toLowerCase();
    if (path.contains('whatsapp') ||
        path.contains('telegram') ||
        path.contains('download')) {
      return 0; // Low authority - forwarded/cached copies
    }
    if (path.contains('dcim') || path.contains('camera')) {
      return 3; // Highest authority - original camera capture
    }
    if (path.contains('screenshot') || path.contains('pictures')) {
      return 2; // Medium-high authority
    }
    return 1; // Default
  }

  int _compareAssetsForKeeping(AssetEntity a, AssetEntity b) {
    // 1. Prefer original camera photos over forwarded/downloaded copies
    final authorityA = _getFolderAuthorityScore(a);
    final authorityB = _getFolderAuthorityScore(b);
    final authComp = authorityB.compareTo(authorityA);
    if (authComp != 0) return authComp;

    // 2. Prefer higher resolution
    final resolutionA = a.width * a.height;
    final resolutionB = b.width * b.height;
    final resolutionComparison = resolutionB.compareTo(resolutionA);
    if (resolutionComparison != 0) return resolutionComparison;

    // 3. Prefer larger file size (uncompressed)
    final sizeComparison = (_assetSizes[b.id] ?? 0).compareTo(
      _assetSizes[a.id] ?? 0,
    );
    if (sizeComparison != 0) return sizeComparison;

    // 4. Prefer original earlier capture timestamp (fast integer comparison)
    final dateA =
        a.createDateSecond ?? (a.createDateTime.millisecondsSinceEpoch ~/ 1000);
    final dateB =
        b.createDateSecond ?? (b.createDateTime.millisecondsSinceEpoch ~/ 1000);
    final dateComp = dateA.compareTo(dateB);
    if (dateComp != 0) return dateComp;

    // 5. Deterministic tie-breaker for reproducible sorting
    return a.id.compareTo(b.id);
  }

  int _compareBurstAssetsForKeeping(AssetEntity a, AssetEntity b) {
    // 1. Non-blurry comes before blurry
    final aBlurry = _scanCache[a.id]?['is_blurry'] == true;
    final bBlurry = _scanCache[b.id]?['is_blurry'] == true;
    if (aBlurry != bBlurry) {
      return aBlurry ? 1 : -1;
    }

    // 2. Rank by sharpness score (highest score first)
    final aSharpness = (_scanCache[a.id]?['sharpness'] as double?) ?? 0.0;
    final bSharpness = (_scanCache[b.id]?['sharpness'] as double?) ?? 0.0;
    final sharpComp = bSharpness.compareTo(aSharpness);
    if (sharpComp != 0) return sharpComp;

    // 3. Fallback to general authority comparison
    return _compareAssetsForKeeping(a, b);
  }

  double getAssetSharpness(String assetId) =>
      (_scanCache[assetId]?['sharpness'] as double?) ?? 85.0;

  String? getAssetBlurType(String assetId) =>
      _scanCache[assetId]?['blur_type'] as String?;

  // --- Smart Clean Logic ---
  int _smartCleanSize = 0;
  List<String> _smartCleanIds = [];
  List<AssetEntity> _smartCleanPreviews = [];
  List<AssetEntity> _smartCleanCandidates = [];

  int get smartCleanSize => _scanScope == ScanScope.fullGallery
      ? _smartCleanSize
      : _sumSizes(smartCleanCandidates);
  String get formattedSmartCleanSize => AppUtils.formatBytes(smartCleanSize);
  List<AssetEntity> get smartCleanPreviews =>
      _scanScope == ScanScope.fullGallery
      ? _smartCleanPreviews
      : smartCleanCandidates.take(4).toList();
  List<AssetEntity> get smartCleanCandidates {
    if (_scanScope == ScanScope.fullGallery) return _smartCleanCandidates;
    return {
      for (final asset in [
        ...duplicateGroups.expand((group) => group.skip(1)),
        ...largeVideos,
        ...blurryPhotos,
        ...similarGroups.expand((group) => group.skip(1)),
      ])
        asset.id: asset,
    }.values.toList();
  }

  void _calculateSmartCleanData() {
    _smartCleanSize = 0;
    _smartCleanIds = [];
    _smartCleanPreviews = [];
    _smartCleanCandidates = [];
    _duplicateSize = 0;
    _similarSize = 0;

    final candidateIds = <String>{};
    final duplicateIds = <String>{};
    final similarIds = <String>{};
    void addCandidate(AssetEntity asset) {
      if (!candidateIds.add(asset.id)) return;
      _smartCleanCandidates.add(asset);
      _smartCleanSize += _assetSizes[asset.id] ?? 0;
      if (_smartCleanPreviews.length < 4) _smartCleanPreviews.add(asset);
    }

    for (final group in _duplicateGroups) {
      for (final asset in group.skip(1)) {
        if (duplicateIds.add(asset.id)) {
          _smartCleanIds.add(asset.id);
          _duplicateSize += _assetSizes[asset.id] ?? 0;
          addCandidate(asset);
        }
      }
    }
    for (final asset in _largeVideos) {
      addCandidate(asset);
    }
    for (final asset in _blurryPhotos) {
      addCandidate(asset);
    }
    for (final group in _similarGroups) {
      for (final asset in group.skip(1)) {
        if (similarIds.add(asset.id)) {
          _similarSize += _assetSizes[asset.id] ?? 0;
        }
        addCandidate(asset);
      }
    }
  }

  Future<int> smartClean({List<String>? specificIds}) async {
    final idsToDelete =
        specificIds ??
        duplicateGroups
            .expand((group) => group.skip(1))
            .map((asset) => asset.id)
            .toList();
    if (idsToDelete.isEmpty) return 0;

    try {
      final List<String> result = await MediaService.removeAssetsWithIds(
        idsToDelete,
      );
      if (result.isNotEmpty) {
        int bytesFreed = 0;
        for (final id in result) {
          bytesFreed += _assetSizes[id] ?? 0;
        }
        await removeAssets(result);
        unawaited(AnalyticsService.logCleanAction(
          cleanType: 'smart_clean',
          itemCount: result.length,
          bytesSaved: bytesFreed,
        ));
        return result.length;
      }
    } catch (e) {
      debugPrint('[SmartClean] Critical Deletion Error: $e');
    }
    return 0;
  }

  Future<void> removeAssets(List<String> ids) async {
    if (ids.isEmpty) return;
    final Set<String> idsToRemove = ids.toSet();
    _removedAssetIds.addAll(idsToRemove);

    for (final id in ids) {
      final size = _assetSizes[id] ?? 0;
      _sessionTrashedBytes += size;
      _sessionTrashedCount++;
      _sessionTrashedItems.insert(0, {
        'id': id,
        'size': size,
        'time': DateTime.now(),
      });
      if (_sessionTrashedItems.length > 100) {
        _sessionTrashedItems.removeLast();
      }
    }

    _allScreenshots.removeWhere((a) => idsToRemove.contains(a.id));
    _invalidateScopeView();

    for (var id in idsToRemove) {
      _assetCategoryMap.remove(id);
      _assetSourceMap.remove(id);
      if (_scanCache.containsKey(id)) _scanCache.remove(id);
      if (_assetSizes.containsKey(id)) {
        _totalSize -= _assetSizes[id]!;
        _assetSizes.remove(id);
      }
    }
    if (_totalSize < 0) _totalSize = 0;

    _categories.forEach((key, list) {
      list.removeWhere((a) => idsToRemove.contains(a.id));
      _categories[key] = List.from(list);
    });

    _categoryPositions.clear();
    for (final list in _categories.values) {
      for (var i = 0; i < list.length; i++) {
        _categoryPositions[list[i].id] = i;
      }
    }
    for (final list in _sourceMedia.values) {
      list.removeWhere((a) => idsToRemove.contains(a.id));
    }

    for (var group in _duplicateGroups) {
      group.removeWhere((a) => idsToRemove.contains(a.id));
    }
    _duplicateGroups.removeWhere((group) => group.length < 2);
    _duplicateGroups = List.from(_duplicateGroups);

    for (var group in _similarGroups) {
      group.removeWhere((a) => idsToRemove.contains(a.id));
    }
    _similarGroups.removeWhere((group) => group.length < 2);
    _similarGroups = List.from(_similarGroups);

    _blurryPhotos.removeWhere((a) => idsToRemove.contains(a.id));
    _blurryPhotos = List.from(_blurryPhotos);
    _blurrySize = 0;
    for (var a in _blurryPhotos) {
      _blurrySize += _assetSizes[a.id] ?? 0;
    }

    _largeVideos.removeWhere((a) => idsToRemove.contains(a.id));
    _largeVideos = List.from(_largeVideos);
    _largeVideosSize = 0;
    for (var v in _largeVideos) {
      _largeVideosSize += _assetSizes[v.id] ?? 0;
    }

    _calculateSmartCleanData();
    _recalculateCategorySizes();
    notifyListeners();
    await _saveCache();
    await _saveResults();
    unawaited(WidgetService.syncWithProvider(this));
  }

  Future<void> forceRescan() => scan(force: true);

  final Map<String, String> _assetCategoryMap = {};

  List<AssetEntity>? _categoryPending;
  int _categoryNextIndex = 0;
  void _prioritizeCategoryScope() {
    final queue = _categoryPending;
    if (queue == null ||
        _categoryNextIndex >= queue.length ||
        _scanScope == ScanScope.fullGallery) {
      return;
    }
    final remaining = queue.sublist(_categoryNextIndex);
    final preferred = remaining.where(
      (asset) => _visibleIds.contains(asset.id),
    );
    final rest = remaining.where((asset) => !_visibleIds.contains(asset.id));
    queue.setRange(_categoryNextIndex, queue.length, [...preferred, ...rest]);
  }

  Future<void> _categoryWork = Future.value();
  Future<void> get categorizationComplete => _categoryWork;
  Future<void> _refineCategoriesWithML(List<AssetEntity> items, int sessionId) {
    return _categoryWork = _categoryWork.then(
      (_) => _runCategoryBatches(items, sessionId),
    );
  }

  Future<void> _runCategoryBatches(
    List<AssetEntity> items,
    int sessionId,
  ) async {
    if (items.isEmpty || _scanSessionId != sessionId) return;
    if (_checkpointGeneration == null) {
      _checkpointGeneration = DateTime.now().microsecondsSinceEpoch.toString();
      _checkpointSequence = 0;
      await _saveResults();
    }
    final queue = List<AssetEntity>.of(items);
    _categoryPending = queue;
    _categoryNextIndex = 0;
    _prioritizeCategoryScope();
    categorizationProcessed = 0;
    categorizationTotal = queue.length;
    _isCategorizing = true;
    notifyListeners();
    final publishClock = Stopwatch()..start();
    try {
      for (var start = 0; start < queue.length; start += 8) {
        if (_scanSessionId != sessionId) return;
        final chunk = queue.sublist(start, min(start + 8, queue.length));
        _categoryNextIndex = start + chunk.length;
        Map<String, String> results;
        try {
          results = await _categorizationService.categorizeBatch(
            chunk,
            albums: _assetAlbumMap,
          );
        } catch (error) {
          debugPrint('[Category batch] $error');
          results = {};
        }
        if (_scanSessionId != sessionId) return;
        for (final asset in chunk) {
          if (_assetCategoryMap.containsKey(asset.id)) {
            final attempted = _scanCache.putIfAbsent(asset.id, () => {});
            attempted['category_attempted'] = true;
            attempted['category'] = _assetCategoryMap[asset.id];
          }
          final category = results[asset.id];
          if (category == null || !_assetCategoryMap.containsKey(asset.id)) {
            continue;
          }
          _addAssetToCategory(category, asset);
          final entry = _scanCache.putIfAbsent(asset.id, () => {});
          entry['category'] = category;
          entry['category_done'] = true;
        }
        categorizationProcessed = start + chunk.length;
        if (publishClock.elapsedMilliseconds >= 500) {
          publishClock.reset();
          notifyListeners();
        }
        await _saveBatchCheckpoint(chunk);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      await _saveCache();
      await _saveResults();
      await _compactJournal();
    } finally {
      if (identical(_categoryPending, queue)) {
        _categoryPending = null;
        _categoryNextIndex = 0;
      }
      if (_scanSessionId == sessionId) {
        _isCategorizing = false;
        notifyListeners();
      }
    }
  }

  final Map<String, String> _assetSourceMap = {};
  final Map<String, List<AssetEntity>> _sourceMedia = {};
  final Map<String, int> _categoryPositions = {};
  List<AssetEntity> get screenshotAssets =>
      _scopeFilter(_sourceMedia['Screenshots'] ?? const []);
  List<AssetEntity> get socialMediaAssets =>
      _scopeFilter(_sourceMedia['Social & WhatsApp'] ?? const []);
  int getSourceSize(String source) => _scopeFilter(
    _sourceMedia[source] ?? const <AssetEntity>[],
  ).fold(0, (sum, asset) => sum + (_assetSizes[asset.id] ?? 0));

  void _registerAssetSource(AssetEntity asset) {
    if (_assetSourceMap.containsKey(asset.id)) return;
    final category = _categorizationService.quickCategorize(
      asset,
      albumName: _assetAlbumMap[asset.id],
    );
    if (category != null &&
        CategorizationService.sourceCategories.contains(category)) {
      _assetSourceMap[asset.id] = category;
      _sourceMedia.putIfAbsent(category, () => []).add(asset);
    }
  }

  void _addAssetToCategory(String category, AssetEntity asset) {
    final oldCat = _assetCategoryMap[asset.id];
    if (oldCat == category) return;
    final size = _assetSizes[asset.id] ?? 0;
    if (oldCat != null) {
      final old = _categories[oldCat]!;
      final index = _categoryPositions[asset.id]!;
      final last = old.last;
      old[index] = last;
      _categoryPositions[last.id] = index;
      old.removeLast();
      _categorySizes[oldCat] = max(0, (_categorySizes[oldCat] ?? 0) - size);
    }
    final target = _categories.putIfAbsent(category, () => []);
    _categoryPositions[asset.id] = target.length;
    target.add(asset);
    _categorySizes[category] = (_categorySizes[category] ?? 0) + size;
    _assetCategoryMap[asset.id] = category;
  }

  String getFormattedAssetSize(String id) {
    if (_assetSizes.containsKey(id)) {
      return AppUtils.formatBytes(_assetSizes[id]!);
    }
    return '';
  }
}
