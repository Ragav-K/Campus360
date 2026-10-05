import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Codec, ImmutableBuffer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../constants/app_config.dart';

/// On-device tile store, so the campus map works with no network.
///
/// Written by hand rather than using `flutter_map_tile_caching`, which is
/// GPL-3.0 and would impose that licence on the whole app. What we actually
/// need is a directory of PNGs and a cache-first image provider.
class TileCache {
  TileCache._(this._directory);

  /// A cache over a directory chosen by the caller.
  ///
  /// Exists for tests: [instance] asks `path_provider` for the app's support
  /// directory, which in a widget test means a plugin channel that isn't there,
  /// so any screen showing a map would hang on its spinner forever.
  @visibleForTesting
  factory TileCache.forDirectory(Directory directory) => TileCache._(directory);

  final Directory _directory;
  static TileCache? _instance;

  /// One client for every tile request.
  ///
  /// Creating a client per tile opens a fresh connection each time; a screenful
  /// of tiles then exhausts sockets and most of them fail, leaving the map
  /// permanently patchy. A shared client pools connections instead.
  static final http.Client sharedClient = http.Client();

  /// Caps simultaneous tile downloads. Tile servers throttle aggressive
  /// clients, and a phone gains nothing from 40 parallel requests.
  static int _inFlight = 0;
  static const _maxInFlight = 6;

  static Future<T> withSlot<T>(Future<T> Function() body) async {
    while (_inFlight >= _maxInFlight) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    _inFlight++;
    try {
      return await body();
    } finally {
      _inFlight--;
    }
  }

  static Future<TileCache> instance() async {
    if (_instance != null) return _instance!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/map_tiles');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _instance = TileCache._(dir);
  }

  File fileFor(int z, int x, int y) => File('${_directory.path}/${z}_${x}_$y.png');

  Future<bool> has(int z, int x, int y) => fileFor(z, x, y).exists();

  Future<void> write(int z, int x, int y, Uint8List bytes) async {
    try {
      await fileFor(z, x, y).writeAsBytes(bytes, flush: false);
    } catch (_) {
      // A full disk must degrade to "no cache", never crash the map.
    }
  }

  Future<Uint8List?> read(int z, int x, int y) async {
    try {
      final file = fileFor(z, x, y);
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  /// Total bytes on disk, for the settings screen.
  Future<int> sizeBytes() async {
    var total = 0;
    try {
      await for (final entity in _directory.list()) {
        if (entity is File) total += await entity.length();
      }
    } catch (_) {
      // Best effort.
    }
    return total;
  }

  Future<int> tileCount() async {
    try {
      return await _directory.list().where((e) => e is File).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      await for (final entity in _directory.list()) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {}
  }

  // ---- prefetch ------------------------------------------------------------

  /// Downloads every tile covering the campus for the configured zoom levels.
  ///
  /// The campus is ~600 m across, so this is a couple of hundred tiles — a few
  /// MB. [onProgress] reports (done, total) so the UI can show real progress
  /// rather than an indeterminate spinner.
  Future<int> prefetchCampus({
    required String urlTemplate,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final jobs = <({int z, int x, int y})>[];

    for (var z = AppConfig.prefetchMinZoom; z <= AppConfig.prefetchMaxZoom; z++) {
      final topLeft = _toTile(AppConfig.campusNorth, AppConfig.campusWest, z);
      final bottomRight = _toTile(AppConfig.campusSouth, AppConfig.campusEast, z);

      for (var x = topLeft.x; x <= bottomRight.x; x++) {
        for (var y = topLeft.y; y <= bottomRight.y; y++) {
          jobs.add((z: z, x: x, y: y));
        }
      }
    }

    var done = 0;
    var fetched = 0;
    onProgress?.call(0, jobs.length);

    for (final job in jobs) {
      if (isCancelled?.call() ?? false) break;

      if (!await has(job.z, job.x, job.y)) {
        try {
          final url = urlTemplate
              .replaceAll('{z}', '${job.z}')
              .replaceAll('{x}', '${job.x}')
              .replaceAll('{y}', '${job.y}');

          final response = await withSlot(
            () => sharedClient.get(
              Uri.parse(url),
              // Tile servers require a real identifying agent; a default Dart
              // one gets blocked.
              headers: const {'User-Agent': AppConfig.tileUserAgent},
            ).timeout(const Duration(seconds: 20)),
          );

          if (response.statusCode == 200) {
            await write(job.z, job.x, job.y, response.bodyBytes);
            fetched++;
          }
        } catch (_) {
          // Skip this tile; a partial map is more useful than a failed one.
        }
      }

      onProgress?.call(++done, jobs.length);
    }

    return fetched;
  }

  /// Slippy-map tile index for a coordinate at a zoom level.
  ({int x, int y}) _toTile(double lat, double lng, int zoom) {
    final n = math.pow(2, zoom).toDouble();
    final latRad = lat * math.pi / 180.0;
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n).floor();
    return (x: x.clamp(0, n.toInt() - 1), y: y.clamp(0, n.toInt() - 1));
  }
}

/// Serves tiles from the cache first, falling back to the network and storing
/// what it fetches. Offline, cached tiles render and the rest stay blank —
/// which is the correct behaviour, not an error.
class CachedTileProvider extends TileProvider {
  CachedTileProvider(this._cache);

  final TileCache _cache;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _CachedTileImage(
      cache: _cache,
      coordinates: coordinates,
      url: getTileUrl(coordinates, options),
    );
  }
}

class _CachedTileImage extends ImageProvider<_CachedTileImage> {
  const _CachedTileImage({required this.cache, required this.coordinates, required this.url});

  final TileCache cache;
  final TileCoordinates coordinates;
  final String url;

  @override
  Future<_CachedTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_CachedTileImage>(this);

  @override
  ImageStreamCompleter loadImage(_CachedTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<Codec> _load(ImageDecoderCallback decode) async {
    final z = coordinates.z;
    final x = coordinates.x;
    final y = coordinates.y;

    final cached = await cache.read(z, x, y);
    if (cached != null && cached.isNotEmpty) {
      return decode(await ImmutableBuffer.fromUint8List(cached));
    }

    // Retry a couple of times: flutter_map does not re-request a tile whose
    // image provider threw, so one transient failure would leave that square
    // blank until the map is rebuilt.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final bytes = await TileCache.withSlot(() async {
          final response = await TileCache.sharedClient
              .get(Uri.parse(url), headers: const {'User-Agent': AppConfig.tileUserAgent})
              .timeout(const Duration(seconds: 20));

          if (response.statusCode != 200) {
            throw NetworkImageLoadException(
              statusCode: response.statusCode,
              uri: Uri.parse(url),
            );
          }
          return response.bodyBytes;
        });

        await cache.write(z, x, y, bytes);
        return decode(await ImmutableBuffer.fromUint8List(bytes));
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
        }
      }
    }

    throw lastError ?? Exception('Tile $z/$x/$y failed');
  }

  @override
  bool operator ==(Object other) =>
      other is _CachedTileImage &&
      other.coordinates.z == coordinates.z &&
      other.coordinates.x == coordinates.x &&
      other.coordinates.y == coordinates.y;

  @override
  int get hashCode => Object.hash(coordinates.z, coordinates.x, coordinates.y);
}
