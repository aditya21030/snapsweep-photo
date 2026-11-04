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

  ScanResult(this.screenshots, this.assetAlbumMap, this.debugInfo);
}

class MediaService {
  static String _folderFromPath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return 'Camera';
    final segments = relativePath.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : 'Camera';
  }

  Future<ScanResult> fetchAllAssets({ScanScope scope = ScanScope.screenshots}) async {
    StringBuffer log = StringBuffer();

    // Request permission for both photos & videos
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    log.writeln('Auth: ${ps.isAuth}, State: ${ps.name}');

    if (!ps.isAuth && ps != PermissionState.limited) {
      return ScanResult([], {}, log.toString());
    }

    // Determine request type
    final reqType = scope == ScanScope.videos
        ? RequestType.video
        : (scope == ScanScope.fullGallery ? RequestType.common : RequestType.image);

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

    // 1. First fetch master assets from the "Recent" / "All" album
    AssetPathEntity? recentAlbum;
    for (final album in albums) {
      if (album.isAll) {
        recentAlbum = album;
        break;
      }
    }

    if (recentAlbum != null) {
      final count = await recentAlbum.assetCountAsync;
      final limit = count > 15000 ? 15000 : count;
      const pageSize = 1500;
      for (int start = 0; start < limit; start += pageSize) {
        final end = (start + pageSize < limit) ? start + pageSize : limit;
        final items = await recentAlbum.getAssetListRange(start: start, end: end);
        for (var asset in items) {
          if (_matchesScope(asset, scope, null) && !processedIds.contains(asset.id)) {
            allAssets.add(asset);
            processedIds.add(asset.id);
            assetAlbumMap[asset.id] = _folderFromPath(asset.relativePath);
          }
        }
      }
    } else {
      // Fallback only if recentAlbum is not supported by Android provider
      for (final album in albums) {
        if (album.isAll) continue;
        final count = await album.assetCountAsync;
        if (count == 0) continue;

        final limit = count > 10000 ? 10000 : count;
        const pageSize = 1500;
        for (int start = 0; start < limit; start += pageSize) {
          final end = (start + pageSize < limit) ? start + pageSize : limit;
          final items = await album.getAssetListRange(start: start, end: end);

          for (var asset in items) {
            assetAlbumMap[asset.id] = album.name;
            if (_matchesScope(asset, scope, album.name) && !processedIds.contains(asset.id)) {
              allAssets.add(asset);
              processedIds.add(asset.id);
            }
          }
        }
      }
    }

    log.writeln('Found ${allAssets.length} items for scope ${scope.label}. Mapped ${assetAlbumMap.length} to albums.');
    return ScanResult(allAssets, assetAlbumMap, log.toString());
  }

  Future<List<AssetEntity>> fetchVideos({int limit = 100}) async {
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

    // Fast-path: check master videos album first
    for (final album in albums) {
      if (album.isAll) {
        final count = await album.assetCountAsync;
        final fetchCount = count > limit ? limit : count;
        return await album.getAssetListRange(start: 0, end: fetchCount);
      }
    }

    final List<AssetEntity> allVideos = [];
    final Set<String> seenIds = {};

    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count == 0) continue;
      final fetchCount = count > limit ? limit : count;
      final items = await album.getAssetListRange(start: 0, end: fetchCount);
      for (final item in items) {
        if (item.type == AssetType.video && !seenIds.contains(item.id)) {
          seenIds.add(item.id);
          allVideos.add(item);
        }
      }
      if (allVideos.length >= limit) break;
    }
    return allVideos;
  }

  bool _matchesScope(AssetEntity asset, ScanScope scope, String? albumName) {
    if (scope == ScanScope.fullGallery) return true;
    if (scope == ScanScope.videos) return asset.type == AssetType.video;

    final searchable = '${asset.title ?? ''} ${asset.relativePath ?? ''} ${albumName ?? ''}'.toLowerCase();
    switch (scope) {
      case ScanScope.screenshots:
        return searchable.contains('screenshot') ||
            searchable.contains('screen_shot') ||
            searchable.contains('screen shot') ||
            searchable.contains('capture');
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
        return searchable.contains('download') || searchable.contains('browser');
      case ScanScope.videos:
        return asset.type == AssetType.video;
      case ScanScope.fullGallery:
        return true;
    }
  }
}
