# lib/features/campus_map/widgets/campus_map_view.dart

## Purpose
The reusable `flutter_map`-based widget that renders the campus map itself: cached tiles, location pins, GPS position, route polylines, and (for the survey/admin use case) the raw walking graph nodes/edges.

## Key members
- `CampusMapView` (`StatelessWidget`) — configures `FlutterMap` with campus bounds constraints, tile layer backed by `CachedTileProvider`, optional `CampusGraph` polyline/node overlay, optional `NavigationRoute` polyline, GPS accuracy circle, and location marker pins.
- `_LocationPin` — a circular marker icon for a `CampusLocation`, highlighted when selected.
- `_PathNodeDot` — small dot marker for a walking-graph node (survey screen only), sized/colored by selected/highlighted state.
- `_PositionDot` — the "you are here" GPS dot.

## Dependencies & relationships
Depends on `TileCache`/`CachedTileProvider`, `AppConfig` (zoom/bounds/tile URL), `AppColors`, `CampusLocation`, `CampusPath` (`CampusGraph`/`PathNode`), and `NavigationRoute` (from `navigation_providers.dart`). Reused by `map_home_screen.dart` (via `CampusMapWithMarkers`) and `navigate_screen.dart`.

## Notable behavior / gotchas
Tiles come from `CachedTileProvider`, so anything already downloaded renders offline; uncached tiles stay blank (`errorTileCallback` is a no-op) rather than showing an error glyph — this is deliberate, not a bug. The map view is bounded to campus (`CameraConstraint.contain`). A direct-line route is drawn dashed and in a neutral color; a real path is solid and primary-colored, so the drawing itself communicates route confidence. Graph nodes/edges are indexed into a map once per build (not per edge) for pan/zoom performance, and a dangling edge silently draws nothing instead of crashing. Includes the required OSM attribution widget.
