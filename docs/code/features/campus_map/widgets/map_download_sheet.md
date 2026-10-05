# lib/features/campus_map/widgets/map_download_sheet.dart

## Purpose
A modal bottom sheet that lets the user pre-fetch (and later delete) all campus map tiles for offline use, with real download progress.

## Key members
- `showMapDownloadSheet(context)` — opens the non-dismissible modal sheet.
- `_MapDownloadSheet` / `_MapDownloadSheetState` — loads `TileCache` on init, shows current cached tile count/size, runs `cache.prefetchCampus(...)` with progress callback and a cancel flag, and shows a result message (completed vs. stopped early). Also offers "Delete saved map" to clear the cache.

## Dependencies & relationships
Uses `TileCache` (`core/services/tile_cache.dart`), `remoteConfigValueProvider` for the tile URL template, `Fmt.fileSize` for byte formatting, and `CButton`. Invoked from `map_home_screen.dart`'s download button.

## Notable behavior / gotchas
The sheet is `isDismissible: false` specifically to avoid a stray tap outside killing an in-progress download. Progress bar is indeterminate (`value: null`) until `_total` is known. Cancelling mid-download still reports how many new tiles were saved rather than discarding partial progress. Tile URL template comes from remote config, not a hardcoded constant, so it can be updated without an app release.
