# lib/features/campus_map/providers/navigation_providers.dart

## Purpose
Providers and pure helpers for GPS tracking, the offline tile cache, the campus walking graph, and computing/formatting a walking route to a destination.

## Key members
- `locationServiceProvider` — exposes `LocationService` (GPS/permission handling).
- `tileCacheProvider` (`FutureProvider<TileCache>`) — the on-device map tile store, behind a provider so widget tests can avoid touching `path_provider`.
- `pathRepositoryProvider` / `campusGraphProvider` (`StreamProvider<CampusGraph>`) — the campus walking network, served from Firestore (including its offline cache).
- `positionStreamProvider` (`StreamProvider.autoDispose<Position>`) — live GPS position; autoDispose so GPS polling stops once no map screen is open.
- `NavigationRoute` — holds computed route `points`, `metres`, `isDirectLine`, and a derived `eta`.
- `RouteRequest` — typedef `({double fromLat, fromLng, CampusLocation to})`, the input to `routeProvider`.
- `routeProvider` (`Provider.autoDispose.family<NavigationRoute?, RouteRequest>`) — computes a route over `campusGraphProvider`, falling back to a straight line when no path connects the endpoints.
- `mappedLocationsProvider` / `unmappedCountProvider` — locations with/without recorded coordinates.
- `formatDistance`, `formatEta` — human-readable distance/time strings.
- `walkingSpeedMetresPerSecond` — walking pace constant re-exported from `AppConfig`.

## Dependencies & relationships
Imports `LocationService`, `TileCache`, `PathRepository`, `CampusLocation`/`CampusPath` models, and `AppConfig`. Used by `map_home_screen.dart`, `navigate_screen.dart`, and `campus_map_view.dart`.

## Notable behavior / gotchas
`routeProvider` is a pure function of the graph and the two endpoints, so it recomputes automatically as the user walks. When no graph is loaded or the endpoints aren't connected, it returns a direct (`isDirectLine: true`) straight-line route rather than silently fabricating a path — callers must label this distinctly in the UI. GPS streaming is autoDispose specifically to limit battery use to when a map screen is visible.
