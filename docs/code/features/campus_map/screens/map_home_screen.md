# lib/features/campus_map/screens/map_home_screen.dart

## Purpose
The Campus Map tab: an interactive offline-capable map with search/filter overlay, location pins, GPS "centre on me", and an entry point to download map tiles for offline use.

## Key members
- `MapHomeScreen` (`ConsumerStatefulWidget`) — owns the `MapController`, a lazily-loaded `TileCache`, and UI state (`_showList`, `_selectedId`). Shows the map full-screen with a floating search bar, category chips, and a results sheet that takes over when searching/filtering.
- `CampusMapWithMarkers` — thin wrapper around `CampusMapView` so the navigate screen can reuse the same marker rendering.
- `_ResultsSheet` — scrollable bottom panel of matching `LocationTile`s, with empty states for "no matches" vs. "no data yet".
- `_MapChip` / `_MapButton` — category filter chip and floating round icon buttons (download, centre-on-me).

## Dependencies & relationships
Watches `filteredLocationsProvider`, `mappedLocationsProvider`, `availableLocationCategoriesProvider`, `locationCategoryFilterProvider`, `locationFilterActiveProvider`, `locationSearchProvider`, and `positionStreamProvider`. Renders `CampusMapView`, `LocationTile`, and opens `map_download_sheet.dart`'s `showMapDownloadSheet`. Navigates to `Routes.locationDetail` via go_router.

## Notable behavior / gotchas
`TileCache.instance()` is awaited in `initState`, so the map area shows a spinner until the cache is ready. GPS position streaming (`positionStreamProvider`) is only active while this screen is mounted (autoDispose). "Centre on me" with no GPS fix calls `ensurePermission()` and surfaces the real failure reason via `describeFailure` rather than a generic error. Search/list toggle and category filters combine into one `showResults` flag that swaps the map for a results list.
