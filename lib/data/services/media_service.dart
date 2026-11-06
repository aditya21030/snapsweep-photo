import 'dart:io';
import 'package:flutter/services.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

/// The part of the gallery a user has explicitly asked SnapSweep to inspect.
enum ScanScope {
  fullGallery,
  screenshots,
  messaging,
  camera,
  downloads,
  videos,
}

extension ScanScopeLabel on ScanScope {
  String get label => switch (this) {
    ScanScope.fullGallery => 'Full gallery',
    ScanScope.screenshots => 'Screenshots',
    ScanScope.messaging => 'WhatsApp & Social',
    ScanScope.camera => 'Camera Roll',
    ScanScope.downloads => 'Downloads',
    ScanScope.videos => 'Videos',
  };

  IconData get icon => switch (this) {
    ScanScope.fullGallery => Icons.photo_library_rounded,
    ScanScope.screenshots => Icons.screenshot_rounded,
    ScanScope.messaging => Icons.chat_rounded,
    ScanScope.camera => Icons.camera_alt_rounded,
    ScanScope.downloads => Icons.download_rounded,
    ScanScope.videos => Icons.video_library_rounded,
  };
}

class ScanResult {
  final List<AssetEntity> screenshots;
  final Map<String, String> assetAlbumMap;
  final String debugInfo;
  final bool hasReadPermission;

  ScanResult(
    this.screenshots,
    this.assetAlbumMap,
    this.debugInfo, {
    this.hasReadPermission = true,
  });
}

class MediaService {
  Future<Map<String, Map<String, dynamic>>> fetchMediaFacts() async {
    if (!Platform.isAndroid) return {};
    try {
      final data = await const MethodChannel('com.yousful.snapsweep/classifier')
          .invokeMapMethod<String, dynamic>('mediaFacts')
          .timeout(const Duration(seconds: 15));
      return (data ?? {}).map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  /// Android's recoverable MediaStore Trash is available from API 30 onward.
  static Future<bool> supportsTrash() async {
    if (!Platform.isAndroid) return false;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt >= 30;
  }

  /// Removes media using Trash when possible. On older Android versions the
  /// platform only supports permanent deletion through photo_manager.
  static Future<List<String>> removeAssetsWithIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    if (!await supportsTrash()) {
      return PhotoManager.editor.deleteWithIds(ids);
    }

    final assets = (await Future.wait(
      ids.map(AssetEntity.fromId),
    )).whereType<AssetEntity>().toList();
    if (assets.isEmpty) return [];
    return PhotoManager.editor.android.moveToTrash(assets);
  }

  static String _folderFromPath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return 'Others';
    final segments = relativePath
        .split(RegExp(r'[\\/]'))
        .where((s) => s.isNotEmpty)
        .toList();
    return segments.isNotEmpty ? segments.last : 'Others';
  }

  Future<ScanResult> fetchAllAssets({
    ScanScope scope = ScanScope.screenshots,
  }) async {
    StringBuffer log = StringBuffer();

    // Request permission for both photos & videos
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    log.writeln('Auth: ${ps.isAuth}, State: ${ps.name}');

    if (!ps.isAuth && ps != PermissionState.limited) {
      return ScanResult([], {}, log.toString(), hasReadPermission: false);
    }

    // Determine request type
    final reqType = scope == ScanScope.videos
        ? RequestType.video
        : (scope == ScanScope.screenshots
              ? RequestType.image
              : RequestType.common);

    // Get all albums (both Recent and specific folders like Camera, Screenshots, WhatsApp, etc.)
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: reqType,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        videoOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
      ),
    );

    log.writeln('Albums found: ${albums.length}');

    List<AssetEntity> allAssets = [];
    Set<String> processedIds = {};
    Map<String, String> assetAlbumMap = {};

    // Specific albums retain folder names even when MediaStore omits relativePath.
    // Use the aggregate album only when the provider exposes no specific albums.
    final specificAlbums = albums.where((album) => !album.isAll).toList();
    final sources = specificAlbums.isEmpty ? albums : specificAlbums;
    for (final album in sources) {
      final count = await album.assetCountAsync;
      const pageSize = 500;
      for (int start = 0; start < count; start += pageSize) {
        final end = (start + pageSize < count) ? start + pageSize : count;
        final items = await album.getAssetListRange(start: start, end: end);
        for (final asset in items) {
          final folder = album.isAll
              ? _folderFromPath(asset.relativePath)
              : album.name;
          if (matchesScope(asset, scope, folder) &&
              processedIds.add(asset.id)) {
            allAssets.add(asset);
            assetAlbumMap[asset.id] = folder;
          }
        }
      }
    }

    log.writeln(
      'Found ${allAssets.length} items for scope ${scope.label}. Mapped ${assetAlbumMap.length} to albums.',
    );
    return ScanResult(allAssets, assetAlbumMap, log.toString());
  }

  Future<List<AssetEntity>> fetchVideos() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth && ps != PermissionState.limited) return [];

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      filterOption: FilterOptionGroup(
        videoOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
      ),
    );

    if (albums.isEmpty) return [];

    final List<AssetEntity> allVideos = [];
    final Set<String> seenIds = {};
    final master = albums.where((album) => album.isAll).firstOrNull;
    final paths = master == null
        ? albums.where((album) => !album.isAll)
        : <AssetPathEntity>[master];

    for (final album in paths) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      const pageSize = 500;
      for (int start = 0; start < count; start += pageSize) {
        final end = start + pageSize < count ? start + pageSize : count;
        final items = await album.getAssetListRange(start: start, end: end);
        for (final item in items) {
          if (item.type == AssetType.video && seenIds.add(item.id)) {
            allVideos.add(item);
          }
        }
      }
    }
    return allVideos;
  }

  bool matchesScope(AssetEntity asset, ScanScope scope, String? albumName) {
    if (scope == ScanScope.fullGallery) return true;
    if (scope == ScanScope.videos) return asset.type == AssetType.video;

    final searchable =
        '${asset.title ?? ''} ${asset.relativePath ?? ''} ${albumName ?? ''}'
            .toLowerCase();
    switch (scope) {
      case ScanScope.screenshots:
        return searchable.contains('screenshot') ||
            searchable.contains('screen_shot') ||
            searchable.contains('screen shot') ||
            searchable.contains('screencapture');
      case ScanScope.messaging:
        return searchable.contains('whatsapp') ||
            searchable.contains('telegram') ||
            searchable.contains('messenger') ||
            searchable.contains('signal') ||
            searchable.contains('instagram') ||
            searchable.contains('facebook') ||
            searchable.contains('discord') ||
            searchable.contains('snapchat');
      case ScanScope.camera:
        return searchable.contains('camera') ||
            searchable.contains('dcim') ||
            searchable.contains('100and') ||
            searchable.startsWith('img_') ||
            searchable.startsWith('pasp_');
      case ScanScope.downloads:
        return searchable.contains('download') ||
            searchable.contains('browser');
      case ScanScope.videos:
        return asset.type == AssetType.video;
      case ScanScope.fullGallery:
        return true;
    }
  }
}
