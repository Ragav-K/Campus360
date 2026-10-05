# lib/core/services/tile_cache.dart

## Purpose
Hand-rolled on-device map tile cache (avoiding the GPL-3.0-licensed `flutter_map_tile_caching`) enabling the campus map to work fully offline, plus a `flutter_map` `TileProvider` that serves cached tiles first.

## Key members
- `TileCache` — manages a directory of PNG tile files:
  - `TileCache.instance()` — singleton using the app support directory.
  - `TileCache.forDirectory(Directory)` — test-only factory (`@visibleForTesting`) avoiding `path_provider` plugin channel in widget tests.
  - `has`/`read`/`write`/`fileFor` — per-tile file access.
  - `sizeBytes()` / `tileCount()` / `clear()` — cache stats and eviction for settings UI.
  - `prefetchCampus({urlTemplate, onProgress, isCancelled})` — downloads every tile covering the campus bounds for configured zoom levels.
  - `withSlot` (static) — caps concurrent downloads (`_maxInFlight = 6`) via a busy-wait semaphore.
  - `sharedClient` (static) — single pooled `http.Client` for all tile requests.
  - `_toTile(lat, lng, zoom)` — slippy-map tile index conversion.
- `CachedTileProvider` (extends `TileProvider`) — flutter_map image provider that returns `_CachedTileImage`.
- `_CachedTileImage` (extends `ImageProvider`) — reads from cache first, else fetches from network (with retry), writes back to cache.

## Dependencies & relationships
Imports `flutter_map`, `http`, `path_provider`, `core/constants/app_config.dart` (zoom bounds, tile URL template, user agent). Used by the campus map feature's `TileLayer`.

## Notable behavior / gotchas
Licensing rationale documented: avoids GPL-3.0 dependency entirely. Uses a shared `http.Client` because per-tile clients would exhaust sockets on a screenful of tiles, leaving the map patchy. Tile downloads require a custom `User-Agent` header or the tile server blocks the request. `_CachedTileImage._load` retries network fetch up to 3 times with increasing delay because flutter_map does not re-request a tile whose image provider threw — a transient failure would otherwise leave that tile permanently blank. Write/read/clear failures are swallowed (best-effort) so a full disk degrades gracefully rather than crashing the map.
