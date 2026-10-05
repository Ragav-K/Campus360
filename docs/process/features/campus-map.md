# Campus Map

Screens: `lib/features/campus_map/screens/{map_home_screen,location_detail_screen,navigate_screen}.dart`
Widgets: `lib/features/campus_map/widgets/{campus_map_view,map_download_sheet,location_tile}.dart`
Providers: `lib/features/campus_map/providers/{location_providers,navigation_providers}.dart`
Repositories: `lib/repositories/{location_repository,path_repository}.dart`
Models: `lib/models/{campus_location,campus_path}.dart`, `lib/models/enums/location_enums.dart`
Services: `lib/core/services/{tile_cache,location_service}.dart`
Firestore: `campusLocations/{id}`, plus a single campus graph document via `PathRepository`

Map is the second tab (`Routes.map`, `/map`).

## Browsing locations

1. **List/search.** `MapHomeScreen` reads `allLocationsProvider`
   (`StreamProvider` over `LocationRepository.watchAll()`, kept alive rather
   than `autoDispose` since the whole app links into locations). Typed
   search (`locationSearchProvider`) and a category chip
   (`locationCategoryFilterProvider`) narrow `filteredLocationsProvider`,
   which also ranks prefix matches first (e.g. typing "lib" ranks "Library"
   above "Digital Library Annexe").
2. **Detail.** Tapping a location goes to `Routes.locationDetail(id)` →
   `LocationDetailScreen`, backed by `locationDetailProvider.family(id)`.
   It also shows that location's live Pulse status via
   `locationPulseProvider` (see `campus-pulse.md`).

## Downloading offline map tiles

3. `map_download_sheet.dart` lets a user pre-fetch the tile set for an area
   so the map keeps working with no network. Tiles are written to disk via
   `TileCache` (`lib/core/services/tile_cache.dart`) as plain PNGs under the
   app's support directory (`<support>/map_tiles`), not via a third-party
   GPL-licensed tile-caching package — written by hand specifically to keep
   the app's licence clean. Downloads share a single `http.Client` and are
   capped at 6 concurrent requests (`TileCache._maxInFlight`) so a screenful
   of tiles doesn't exhaust sockets or trip a tile server's throttling.
4. `connectivity_plus` informs the UI whether the device is online, so the
   map can decide between fetching a fresh tile and serving straight from
   the cache.

## Navigating between two points

5. `NavigateScreen` (`Routes.navigate(id)`) uses `navigation_providers.dart`
   together with `PathRepository.fetchGraph()` — a single `CampusGraph`
   document of nodes (surveyed GPS points) and edges (walkable connections
   between them, recorded by the admin Survey tool, see `admin.md`).
   Routing walks this graph from the user's current position
   (`LocationService.currentPosition()`, GPS-based so it works with no
   network) to the destination location's node.
6. `unmappedCountProvider` (used by the admin survey UI) reports how many
   `campusLocations` still lack coordinates — until a location is surveyed,
   nothing can route to it.
